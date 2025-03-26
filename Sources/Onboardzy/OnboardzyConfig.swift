import Foundation

/// Configuration class for Onboardzy SDK
class OnboardzyConfig {
    /// Shared instance for singleton access
    static let shared = OnboardzyConfig()
    
    /// API key for the Onboardzy service
    var appId: String?
    
    /// Whether to automatically show onboarding on first launch
    var autoShowOnFirstLaunch: Bool = true
    
    /// Whether to store user data in UserDefaults
    var persistUserData: Bool = true
    
    /// Base URL for the onboarding service
    var baseUrl: String = "https://onboardzy.com/onboarding"
    
    /// Private initializer for singleton
    private init() {}
    
    /// Configure the SDK with required settings
    func configure(appId: String) {
        self.appId = appId
    }
    
    /// Configure the SDK with advanced options
    func configure(appId: String, autoShowOnFirstLaunch: Bool = true, persistUserData: Bool = true) {
        self.appId = appId
        self.autoShowOnFirstLaunch = autoShowOnFirstLaunch
        self.persistUserData = persistUserData
    }
}
