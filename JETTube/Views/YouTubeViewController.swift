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
        
        // Essential: Allow inline media playback for YouTube
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        
        // Preferences
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        // ============================================================
        // AD BLOCKER — Only CSS hiding + skip script
        // NO fetch/XHR/Response interception to avoid breaking playback
        // Injected AFTER document loads (atDocumentEnd), not at start
        // ============================================================
        
        // CSS ad hiding — safe, does not affect playback
        let cssScript = """
        (function() {
            var s = document.createElement('style');
            s.textContent = `
                .video-ads, .ytp-ad-module, .ytp-ad-overlay-container,
                .ytp-ad-text-overlay, .ytp-ad-overlay-slot, .ytp-ad-image-overlay,
                .ytp-ad-player-overlay, .ytp-ad-action-interstitial,
                .ytp-ad-preview-container, .ytp-ad-skip-ad-slot,
                .ytp-ad-message-slot, .ytp-ad-badge,
                #player-ads, #masthead-ad,
                ytd-promoted-sparkles-web-renderer, ytd-ad-slot-renderer,
                ytd-in-feed-ad-layout-renderer, ytd-banner-promo-renderer,
                ytd-display-ad-renderer, ytd-companion-slot-renderer,
                ytm-promoted-sparkles-web-renderer, ytm-companion-slot,
                .ytm-promoted-sparkles-web-renderer, .ytm-companion-ad-renderer {
                    display: none !important;
                    height: 0 !important;
                    opacity: 0 !important;
                }
            `;
            (document.head || document.documentElement).appendChild(s);
        })();
        """
        let cssUserScript = WKUserScript(
            source: cssScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(cssUserScript)
        
        // Ad skip script — runs periodically to catch and skip video ads
        let skipScript = """
        (function() {
            function skipAd() {
                var p = document.querySelector('.html5-video-player');
                if (p && (p.classList.contains('ad-showing') || p.classList.contains('ad-interrupting'))) {
                    var v = p.querySelector('video');
                    if (v && v.duration && isFinite(v.duration)) {
                        v.currentTime = v.duration;
                    }
                    // Click all skip buttons
                    document.querySelectorAll('.ytp-skip-ad-button,.ytp-ad-skip-button,.ytp-ad-skip-button-modern,[id^="skip-button"]').forEach(function(b) {
                        try { b.click(); } catch(e) {}
                    });
                }
                // Remove page ad elements
                document.querySelectorAll('#player-ads,#masthead-ad,ytd-ad-slot-renderer,ytm-promoted-sparkles-web-renderer,ytm-companion-slot').forEach(function(el) {
                    el.remove();
                });
            }
            setInterval(skipAd, 500);
        })();
        """
        let skipUserScript = WKUserScript(
            source: skipScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(skipUserScript)
        
        // ============================================================
        // DO NOT add WKContentRuleList — it can block resources
        // needed for video playback (e.g., googlevideo.com CDN init)
        // ============================================================
        
        // Create WebView — use default user agent (DO NOT override)
        // Overriding UA can trigger YouTube's WebView detection
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        
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

    // MARK: - Background Audio

    /// Called by SceneDelegate when app enters background
    func evaluateBackgroundScript(_ script: String) {
        webView?.evaluateJavaScript(script, completionHandler: nil)
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
        
        // Block "Open in YouTube app" redirects ONLY
        if urlString.contains("redirect_to_app") ||
           urlString.contains("intent://") ||
           urlString.hasPrefix("youtube://") ||
           urlString.hasPrefix("vnd.youtube://") {
            decisionHandler(.cancel)
            return
        }
        
        // Handle external links (non-YouTube) — open in Safari
        if !urlString.contains("youtube.com") &&
           !urlString.contains("youtu.be") &&
           !urlString.contains("google.com") &&
           !urlString.contains("googleapis.com") &&
           !urlString.contains("gstatic.com") &&
           !urlString.contains("googlevideo.com") &&
           !urlString.contains("ggpht.com") &&
           !urlString.contains("ytimg.com") {
            if navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Hide "Use the app" banners
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
