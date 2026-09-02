import UIKit
import WebKit
import AVKit

class YouTubeViewController: UIViewController {

    // MARK: - Properties
    var initialURL: String = Constants.youtubeBaseURL
    
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var progressObserver: NSKeyValueObservation?
    private var adBlockEngine: AdBlockEngine!
    
    // PiP
    private var pipController: AVPictureInPictureController?
    private var pipPossibleObserver: NSKeyValueObservation?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        
        adBlockEngine = AdBlockEngine()
        
        setupWebView()
        setupProgressBar()
        loadURL(initialURL)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = view.safeAreaInsets.top
        webView.frame = CGRect(
            x: 0,
            y: top,
            width: view.bounds.width,
            height: view.bounds.height - top
        )
        progressView.frame = CGRect(
            x: 0,
            y: top,
            width: view.bounds.width,
            height: 2
        )
    }

    deinit {
        progressObserver?.invalidate()
        pipPossibleObserver?.invalidate()
    }

    // MARK: - WebView Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        
        // Allow inline media playback (required for YouTube)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        
        // Allow AirPlay
        config.allowsAirPlayForMediaPlayback = true
        
        // Preferences
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        // ============================================================
        // AD BLOCKER JS INJECTION — runs at document-start
        // Same technique as Chrome extension's inject.js (MAIN world)
        // ============================================================
        
        if let jsScript = adBlockEngine.getAdBlockerScript() {
            let userScript = WKUserScript(
                source: jsScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(userScript)
        }
        
        // CSS injection — hide ad elements instantly
        if let cssScript = adBlockEngine.getAdBlockerCSS() {
            let cssInjection = WKUserScript(
                source: cssScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(cssInjection)
        }
        
        // ============================================================
        // NATIVE URL BLOCKING — WKContentRuleList
        // Faster than JS fetch override — blocks at WebKit level
        // ============================================================
        
        adBlockEngine.compileContentRules { ruleList in
            if let ruleList = ruleList {
                config.userContentController.add(ruleList)
            }
        }
        
        // Mobile YouTube user agent (triggers mobile site)
        let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        config.applicationNameForUserAgent = mobileUA
        
        // Create WebView
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        
        // Custom user agent to avoid "Use the app" nag
        webView.customUserAgent = mobileUA
        
        view.addSubview(webView)
        
        // Progress observer
        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
            self?.progressView.progress = Float(webView.estimatedProgress)
            self?.progressView.isHidden = webView.estimatedProgress >= 1.0
        }
    }

    private func setupProgressBar() {
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.progressTintColor = UIColor(red: 1, green: 0.27, blue: 0.34, alpha: 1)
        progressView.trackTintColor = .clear
        view.addSubview(progressView)
        view.bringSubviewToFront(progressView)
    }

    // MARK: - Navigation

    func loadURL(_ urlString: String) {
        var targetURL = urlString
        
        // Convert youtu.be to m.youtube.com
        if targetURL.contains("youtu.be/") {
            if let videoID = targetURL.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first {
                targetURL = "\(Constants.youtubeBaseURL)/watch?v=\(videoID)"
            }
        }
        
        // Convert www.youtube.com to m.youtube.com
        targetURL = targetURL.replacingOccurrences(of: "www.youtube.com", with: "m.youtube.com")
        
        if let url = URL(string: targetURL) {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Pull to Refresh
    
    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(refreshPage), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
    }
    
    @objc private func refreshPage() {
        webView.reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.webView.scrollView.refreshControl?.endRefreshing()
        }
    }
}


// MARK: - WKNavigationDelegate

extension YouTubeViewController: WKNavigationDelegate {
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        let urlString = url.absoluteString
        
        // Block known ad URLs at navigation level
        if adBlockEngine.shouldBlockURL(urlString) {
            decisionHandler(.cancel)
            incrementBlockCount()
            return
        }
        
        // Block "Open in YouTube app" redirects
        if urlString.contains("redirect_to_app") ||
           urlString.contains("intent://") ||
           urlString.hasPrefix("youtube://") ||
           urlString.hasPrefix("vnd.youtube://") {
            decisionHandler(.cancel)
            return
        }
        
        // Handle external links (non-YouTube)
        if !urlString.contains("youtube.com") &&
           !urlString.contains("youtu.be") &&
           !urlString.contains("google.com") &&
           !urlString.contains("googleapis.com") &&
           !urlString.contains("gstatic.com") &&
           !urlString.contains("googlevideo.com") &&
           !urlString.contains("ggpht.com") {
            // Open in Safari
            if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Re-inject ad blocker after page load (safety net)
        let js = adBlockEngine.getPostLoadScript()
        webView.evaluateJavaScript(js, completionHandler: nil)
        
        // Inject script to hide "Use the app" banners
        let hideAppBanner = """
        (function() {
            var style = document.createElement('style');
            style.textContent = `
                .mobile-topbar-header-sign-in-button,
                ytm-banner-promo-renderer,
                .ytm-autonav-bar,
                [class*="companion-ad"],
                .ytm-promoted-sparkles-web-renderer,
                ytm-companion-slot { display: none !important; }
            `;
            document.head.appendChild(style);
        })();
        """
        webView.evaluateJavaScript(hideAppBanner, completionHandler: nil)
    }
    
    private func incrementBlockCount() {
        let current = UserDefaults.standard.integer(forKey: Constants.Defaults.adsBlocked)
        UserDefaults.standard.set(current + 1, forKey: Constants.Defaults.adsBlocked)
    }
}


// MARK: - WKUIDelegate

extension YouTubeViewController: WKUIDelegate {
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Handle target="_blank" links — load in same view
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    // MARK: - Microphone Permission (Voice Search)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        // Auto-grant microphone for YouTube voice search
        if origin.host.contains("youtube.com") || origin.host.contains("google.com") {
            decisionHandler(.grant)
        } else {
            decisionHandler(.deny)
        }
    }
}
