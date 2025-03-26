import UIKit
@preconcurrency import WebKit

// Main OnboardingViewController
class OnboardingViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var appId: String
    private var onComplete: ((_ result: [String: Any]?) -> Void)
    private var usingPreloadedWebView: Bool = false

    // Standard initializer
    init(appId: String, onComplete: @escaping (_ result: [String: Any]?) -> Void) {
        self.appId = appId
        self.onComplete = onComplete
        self.usingPreloadedWebView = false
        
        // Configure WebView before view is loaded for faster startup
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptEnabled = true
        
        // Create content controller without adding self yet
        let contentController = WKUserContentController()
        config.userContentController = contentController
        
        // Pre-initialize WebView with configuration
        webView = WKWebView(frame: .zero, configuration: config)
        
        super.init(nibName: nil, bundle: nil)
        
        // Now it's safe to add self as a message handler
        contentController.add(self, name: "onboardingComplete")
    }
    
    // Initializer with preloaded WebView
    init(appId: String, onComplete: @escaping (_ result: [String: Any]?) -> Void, preloadedWebView: WKWebView) {
        self.appId = appId
        self.onComplete = onComplete
        self.webView = preloadedWebView
        self.usingPreloadedWebView = true
        
        super.init(nibName: nil, bundle: nil)
        
        // Add JavaScript message handler for communication after super.init
        webView.configuration.userContentController.add(self, name: "onboardingComplete")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        // Use loadView to set the webView as the main view
        // This is faster than setting it in viewDidLoad
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up webView configuration
        webView.navigationDelegate = self
        
        // Set background to match web content for smoother appearance
        webView.backgroundColor = .white
        webView.isOpaque = false
        
        // Disable features we don't need
        webView.allowsBackForwardNavigationGestures = false
        
        // Improve performance with these settings
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Start loading immediately if not using preloaded WebView
        if !usingPreloadedWebView {
            loadOnboardingContent()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Load content if not loaded yet (belt and suspenders approach)
        if webView.url == nil {
            loadOnboardingContent()
        }
    }
    
    private func loadOnboardingContent() {
        let urlString = "https://onboardzy.com/onboarding/\(appId)"
        print("Loading onboarding content from URL: \(urlString)")
        if let url = URL(string: urlString) {
            // Use a cached request to speed up loading
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            request.timeoutInterval = 30
            webView.load(request)
        }
    }

    // Handle JavaScript messages from WebView
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "onboardingComplete" {
            // Process the completion data
            var resultData: [String: Any]? = nil
            
            if let messageBody = message.body as? [String: Any] {
                resultData = messageBody
            }
            
            // Dismiss and call completion handler with data
            dismiss(animated: true) {
                self.onComplete(resultData)
            }
        }
    }

    // Détection de fin d'onboarding (via redirection) - keep as fallback
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        if let url = navigationAction.request.url?.absoluteString,
            url.contains("onboarding-complete") {
            dismiss(animated: true) {
                self.onComplete(nil)
            }
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
    
    // Check for load completion
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Inject script to capture completion
        let script = """
        if (window.onboardingCompleteHandlerAdded !== true) {
            window.onboardingCompleteHandlerAdded = true;
            
            // Function to extract all form input data from the page
            window.extractUserData = function() {
                try {
                    const userData = {};
                    
                    // Extract all input fields from forms
                    const inputs = document.querySelectorAll('input, select, textarea');
                    inputs.forEach(input => {
                        if (input.name && input.value) {
                            userData[input.name] = input.value;
                        }
                    });
                    
                    // Extract any data stored in data attributes
                    const dataElements = document.querySelectorAll('[data-onboardzy]');
                    dataElements.forEach(element => {
                        if (element.dataset) {
                            Object.keys(element.dataset).forEach(key => {
                                if (key !== 'onboardzy') {
                                    userData[key] = element.dataset[key];
                                }
                            });
                        }
                    });
                    
                    // Try to find any global onboarding data object
                    if (window.onboardingData && typeof window.onboardingData === 'object') {
                        Object.keys(window.onboardingData).forEach(key => {
                            userData[key] = window.onboardingData[key];
                        });
                    }
                    
                    return userData;
                } catch (e) {
                    console.error('Error extracting user data:', e);
                    return {};
                }
            };
            
            // Primary function to complete onboarding
            window.completeOnboarding = function(result) {
                // If result is provided directly, use it
                const userData = result || window.extractUserData();
                
                // Send the data to the native app
                window.webkit.messageHandlers.onboardingComplete.postMessage(userData);
            };
        }
        """
        webView.evaluateJavaScript(script)
    }
    
    // Handle errors
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView load failed: \(error.localizedDescription)")
    }
    
    // Clean up when view is being removed
    deinit {
        // Remove message handler to prevent memory leaks
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "onboardingComplete")
    }
}
