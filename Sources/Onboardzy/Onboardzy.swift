import UIKit
import WebKit
import SwiftUI

/// Represents user data from the onboarding process
public struct OnboardzyUserData: Codable {
    // Store all user data as a dictionary of string key-value pairs
    public var data: [String: String]
    
    public init(data: [String: String] = [:]) {
        self.data = data
    }
    
    /// Access data values using subscript syntax
    public subscript(key: String) -> String? {
        get {
            return data[key]
        }
        set {
            data[key] = newValue
        }
    }
    
    /// Create user data from a dictionary
    internal static func from(dictionary: [String: Any]) -> OnboardzyUserData {
        var userData = OnboardzyUserData()
        
        // Convert all values to strings
        for (key, value) in dictionary {
            if let stringValue = value as? String {
                userData.data[key] = stringValue
            } else {
                // Convert non-string values to string
                userData.data[key] = "\(value)"
            }
        }
        
        return userData
    }
}

/// Observable object that provides access to Onboardzy data
public class OnboardzyStore: ObservableObject {
    @Published public private(set) var userData: OnboardzyUserData?
    @Published public private(set) var hasCompletedOnboarding: Bool = false
    
    public static let shared = OnboardzyStore()
    
    private init() {
        // Initialize with current values
        userData = Onboardzy.userData
        hasCompletedOnboarding = Onboardzy.hasCompletedOnboarding
        
        // Listen for changes
        NotificationCenter.default.addObserver(self, 
            selector: #selector(onboardingCompleted), 
            name: NSNotification.Name("OnboardzyCompletedNotification"), 
            object: nil)
    }
    
    @objc private func onboardingCompleted() {
        DispatchQueue.main.async {
            self.userData = Onboardzy.userData
            self.hasCompletedOnboarding = Onboardzy.hasCompletedOnboarding
        }
    }
}

public class Onboardzy {
    // MARK: - Properties
    
    /// User data from the onboarding process
    public static var userData: OnboardzyUserData?
    
    /// Whether the user has completed the onboarding process
    public static var hasCompletedOnboarding: Bool = false
    
    // Private storage for preloaded WebView
    private static var preloadedWebView: WKWebView?
    private static var isPreloading = false
    private static var onCompletionCallback: (([String: Any]?) -> Void)?
    
    // State management for SwiftUI
    private static var isOnboardingActive = false
    public static var isDataReady = false
    
    // UserDefaults keys
    private static let userDataKey = "onboardzy.userData"
    private static let hasCompletedOnboardingKey = "onboardzy.hasCompletedOnboarding"
    
    // MARK: - Public Methods
    
    /// Configure the SDK with your API key and optional callback
    public static func configure(appId: String, onCompletionCallback: (([String: Any]?) -> Void)? = nil) {
        OnboardzyConfig.shared.configure(appId: appId)
        self.onCompletionCallback = onCompletionCallback
        
        // Load saved state
        loadSavedState()
        
        // If we already have completed onboarding, mark data as ready
        if hasCompletedOnboarding {
            isDataReady = true
            
            // Debug log to verify the state is loaded correctly
            print("📱 Onboardzy: Onboarding previously completed, skipping")
        } else {
            print("📱 Onboardzy: Onboarding not completed yet, will show")
        }
        
        // Start preloading the WebView and content in the background
        preloadOnboardingContent()
        
        // Set onboarding active state if not completed
        if !hasCompletedOnboarding {
            isOnboardingActive = true
        }
        
        // Check if we need to show onboarding automatically
        DispatchQueue.main.async {
            if !hasCompletedOnboarding {
                showOnboarding()
            }
        }
    }
    
    /// Reset the onboarding state to force it to show again
    public static func resetOnboarding() {
        hasCompletedOnboarding = false
        userData = nil
        isOnboardingActive = true
        isDataReady = false
        saveSavedState()
        
        // Show onboarding again
        showOnboarding()
    }
    
    /// Manually show the onboarding flow, even if previously completed
    public static func showOnboarding() {
        guard let key = OnboardzyConfig.shared.appId else {
            print("❌ Onboardzy not configured. Please call Onboardzy.configure(appId:) first.")
            return
        }
        
        // Create the view controller, potentially using the preloaded WebView
        let onboardingVC: OnboardingViewController
        
        if let preloaded = preloadedWebView {
            // Use the preloaded WebView if available
            onboardingVC = OnboardingViewController(appId: key, onComplete: handleOnboardingComplete, preloadedWebView: preloaded)
            preloadedWebView = nil // Clear the reference to prevent reuse
            
            // Start preloading the next one for future use
            DispatchQueue.global(qos: .background).async {
                isPreloading = false
                preloadOnboardingContent()
            }
        } else {
            // Fall back to normal initialization if preloaded WebView isn't ready
            onboardingVC = OnboardingViewController(appId: key, onComplete: handleOnboardingComplete)
        }
        
        onboardingVC.modalPresentationStyle = .fullScreen

        // Present from the root view controller
        if let root = UIApplication.shared.windows.first?.rootViewController {
            root.present(onboardingVC, animated: true)
        } else {
            print("❌ Couldn't find a root view controller.")
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle completion of the onboarding flow
    private static func handleOnboardingComplete(result: [String: Any]?) {
        // Process user data if available
        if let result = result {
            userData = OnboardzyUserData.from(dictionary: result)
        }
        
        // IMPORTANT: Set completion state to true
        hasCompletedOnboarding = true
        isOnboardingActive = false
        isDataReady = true
        
        // Debug log to verify state is updated
        print("📱 Onboardzy: Onboarding completed, setting hasCompletedOnboarding to true")
        
        // Save state to UserDefaults immediately
        saveSavedState()
        
        // Force synchronize to ensure data is saved immediately
        UserDefaults.standard.synchronize()
        
        // Call the completion callback if provided
        onCompletionCallback?(result)
        
        // Post notification to update SwiftUI views
        NotificationCenter.default.post(name: NSNotification.Name("OnboardzyCompletedNotification"), object: nil)
    }
    
    /// Preload the WebView and content for faster display
    private static func preloadOnboardingContent() {
        // Only preload if not already preloading and we have an API key
        guard !isPreloading, let key = OnboardzyConfig.shared.appId else {
            return
        }
        
        isPreloading = true
        
        // All WebKit operations should happen on the main thread
        DispatchQueue.main.async {
            // Configure WebView
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.preferences.javaScriptEnabled = true
            
            // Create content controller
            let contentController = WKUserContentController()
            config.userContentController = contentController
            
            // Create WebView with zero frame (will be resized later)
            let webView = WKWebView(frame: .zero, configuration: config)
            
            // Start loading the content
            let urlString = "https://onboardzy.com/onboarding/\(key)"
            if let url = URL(string: urlString) {
                let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
                webView.load(request)
                
                // Store the preloaded WebView
                preloadedWebView = webView
                isPreloading = false
            } else {
                // Failed to create URL, reset state
                isPreloading = false
                print("❌ Failed to create URL from string: \(urlString)")
            }
        }
    }
    
    /// Load saved state from UserDefaults
    private static func loadSavedState() {
        // Load completion state
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        
        // Load user data if available
        if let savedData = UserDefaults.standard.data(forKey: userDataKey) {
            do {
                userData = try JSONDecoder().decode(OnboardzyUserData.self, from: savedData)
            } catch {
                print("❌ Error decoding saved user data: \(error)")
                userData = nil
            }
        }
    }
    
    /// Save state to UserDefaults
    private static func saveSavedState() {
        // Save completion state
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: hasCompletedOnboardingKey)
        
        // Save user data if available
        if let userData = userData {
            do {
                let encodedData = try JSONEncoder().encode(userData)
                UserDefaults.standard.set(encodedData, forKey: userDataKey)
            } catch {
                print("❌ Error encoding user data: \(error)")
            }
        } else {
            // If no user data, remove any existing data
            UserDefaults.standard.removeObject(forKey: userDataKey)
        }
    }
    
    /// Get a unique ID for the current onboarding session
    /// This is used to force SwiftUI to refresh views when onboarding completes
    public static var refreshId: UUID {
        return isDataReady ? UUID() : UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    }
    
    /// Access to the store for SwiftUI
    public static var store: OnboardzyStore {
        return OnboardzyStore.shared
    }
}

// MARK: - SwiftUI View Modifier

/// View modifier that blocks the main app content until onboarding is completed and data is ready
public struct OnboardzyViewModifier: ViewModifier {
    @ObservedObject private var store = Onboardzy.store
    @State private var refreshID = UUID()
    
    public func body(content: Content) -> some View {
        Group {
            if store.hasCompletedOnboarding {
                // Show the main content when onboarding is complete
                content
                    .id(refreshID) // Force refresh when onboarding completes
            } else {
                // Show a placeholder view while waiting for onboarding
                Color.white
                    .overlay(
                        VStack {
                            Text("Loading...")
                                .font(.headline)
                            ProgressView()
                                .padding()
                        }
                    )
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OnboardzyCompletedNotification"))) { _ in
                        // Update the refresh ID to force the view to refresh
                        refreshID = UUID()
                    }
            }
        }
    }
}

// Extension to make the modifier easier to use
public extension View {
    /// Apply the Onboardzy onboarding flow to this view
    func withOnboarding() -> some View {
        self.modifier(OnboardzyViewModifier())
    }
}
