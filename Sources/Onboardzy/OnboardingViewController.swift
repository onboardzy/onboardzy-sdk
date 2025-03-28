import UIKit
@preconcurrency import WebKit

// Main OnboardingViewController
class OnboardingViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var appId: String
    private var onComplete: ((_ result: [String: Any]?) -> Void)
    private var welcomeOverlayView: UIView?
    private var containerView: UIView!
    private var skeletonViews: [UIView] = []

    // Standard initializer
    init(appId: String, onComplete: @escaping (_ result: [String: Any]?) -> Void) {
        self.appId = appId
        self.onComplete = onComplete
        
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        // Create a container view instead of using the WebView directly as the main view
        containerView = UIView(frame: UIScreen.main.bounds)
        containerView.backgroundColor = .white
        view = containerView
        
        // Add WebView to the container
        webView.frame = containerView.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(webView)
        
        // Create and add the skeleton loader overlay
        let overlay = createSkeletonLoaderOverlay()
        overlay.frame = containerView.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        containerView.addSubview(overlay)
        welcomeOverlayView = overlay
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
        
        // Make WebView ignore safe areas
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.contentMode = .scaleToFill
        
        // Extend layout beyond safe areas
        edgesForExtendedLayout = .all
        additionalSafeAreaInsets = .zero
        view.insetsLayoutMarginsFromSafeArea = false
        if #available(iOS 13.0, *) {
            webView.insetsLayoutMarginsFromSafeArea = false
        }
        
        // Start loading immediately
        loadOnboardingContent()
        
        // Start pulse animation for skeleton views
        animateSkeletonPulse()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Ensure the WebView and overlay fill the entire screen
        containerView.frame = UIScreen.main.bounds
        webView.frame = containerView.bounds
        welcomeOverlayView?.frame = containerView.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Load content if not loaded yet (belt and suspenders approach)
        if webView.url == nil {
            loadOnboardingContent()
        }
    }
    
    private func createSkeletonLoaderOverlay() -> UIView {
        // Create an overlay with white background to match the web page
        let overlay = UIView(frame: UIScreen.main.bounds)
        overlay.backgroundColor = .white
        
        // Create a container for the skeleton items with proper padding
        // pt-14 is approximately 56 points (14 * 4)
        // px-5 is approximately 20 points (5 * 4)
        let skeletonContainer = UIView()
        skeletonContainer.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(skeletonContainer)
        
        // Position the container with proper padding
        NSLayoutConstraint.activate([
            skeletonContainer.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 56),
            skeletonContainer.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 20),
            skeletonContainer.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -20),
            skeletonContainer.bottomAnchor.constraint(lessThanOrEqualTo: overlay.bottomAnchor)
        ])
        
        // Create 5 skeleton placeholder rectangles
        // gap-6 is approximately 24 points (6 * 4)
        var previousView: UIView? = nil
        
        for i in 1...5 {
            // Create a rounded rectangle placeholder
            let skeletonRect = UIView()
            skeletonRect.backgroundColor = UIColor(red: 229/255, green: 231/255, blue: 235/255, alpha: 1.0) // Equivalent to bg-gray-200
            skeletonRect.layer.cornerRadius = 8 // rounded-lg
            skeletonRect.translatesAutoresizingMaskIntoConstraints = false
            skeletonContainer.addSubview(skeletonRect)
            
            // Position each rectangle
            if let previousView = previousView {
                NSLayoutConstraint.activate([
                    skeletonRect.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 24), // gap-6
                ])
            } else {
                NSLayoutConstraint.activate([
                    skeletonRect.topAnchor.constraint(equalTo: skeletonContainer.topAnchor),
                ])
            }
            
            // Make it full width and h-20 (approximately 80 points)
            NSLayoutConstraint.activate([
                skeletonRect.leadingAnchor.constraint(equalTo: skeletonContainer.leadingAnchor),
                skeletonRect.trailingAnchor.constraint(equalTo: skeletonContainer.trailingAnchor),
                skeletonRect.heightAnchor.constraint(equalToConstant: 80)
            ])
            
            // If it's the last one, connect it to the bottom
            if i == 5 {
                NSLayoutConstraint.activate([
                    skeletonRect.bottomAnchor.constraint(equalTo: skeletonContainer.bottomAnchor)
                ])
            }
            
            // Store for animation
            skeletonViews.append(skeletonRect)
            previousView = skeletonRect
        }
        
        return overlay
    }
    
    private func animateSkeletonPulse() {
        // Create a pulse animation similar to animate-pulse in Tailwind
        // This will animate the opacity to simulate the pulse effect
        
        for skeletonView in skeletonViews {
            UIView.animate(withDuration: 1.5, delay: 0, options: [.autoreverse, .repeat, .curveEaseInOut], animations: {
                skeletonView.alpha = 0.5
            }, completion: nil)
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
        // Fade out the welcome overlay once content is loaded
        UIView.animate(withDuration: 0.3, animations: {
            self.welcomeOverlayView?.alpha = 0
        }, completion: { _ in
            self.welcomeOverlayView?.removeFromSuperview()
            self.welcomeOverlayView = nil
        })
        
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
