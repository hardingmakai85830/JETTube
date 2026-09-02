import UIKit
import WebKit
import AVKit

class YouTubeViewController: UIViewController {

    // MARK: - Properties
    var initialURL: String = Constants.youtubeBaseURL
    
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var progressObserver: NSKeyValueObservation?
    
    // PiP
    private var pipController: AVPictureInPictureController?
    private var pipPossibleObserver: NSKeyValueObservation?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        
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
        
        // Essential for YouTube video playback
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        // ============================================================
        // IMPORTANT: Do NOT inject any scripts at page load
        // YouTube's player must initialize without interference
        // Ad blocker is injected AFTER page fully loads (see didFinish)
        // ============================================================
        
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
        
        if targetURL.contains("youtu.be/") {
            if let videoID = targetURL.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first {
                targetURL = "\(Constants.youtubeBaseURL)/watch?v=\(videoID)"
            }
        }
        targetURL = targetURL.replacingOccurrences(of: "www.youtube.com", with: "m.youtube.com")
        
        if let url = URL(string: targetURL) {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Ad Blocker Injection (delayed, safe)
    
    /// Inject ad blocker ONLY after page fully loads
    /// Waits 2 seconds after didFinish to ensure YouTube player is ready
    private func injectAdBlocker() {
        let adBlockScript = """
        (function() {
            // --- CSS: Hide ad UI elements ---
            var s = document.createElement('style');
            s.textContent = `
                .video-ads, .ytp-ad-module, .ytp-ad-overlay-container,
                .ytp-ad-text-overlay, .ytp-ad-image-overlay,
                .ytp-ad-player-overlay, .ytp-ad-action-interstitial,
                .ytp-ad-preview-container, .ytp-ad-skip-ad-slot,
                .ytp-ad-message-slot, .ytp-ad-badge,
                .ytp-ad-persistent-progress-bar-container,
                #player-ads, #masthead-ad,
                ytd-promoted-sparkles-web-renderer, ytd-ad-slot-renderer,
                ytd-in-feed-ad-layout-renderer, ytd-banner-promo-renderer,
                ytd-display-ad-renderer, ytd-companion-slot-renderer,
                ytm-promoted-sparkles-web-renderer, ytm-companion-slot,
                .ytm-promoted-sparkles-web-renderer, .ytm-companion-ad-renderer,
                ytm-banner-promo-renderer, .mobile-topbar-header-sign-in-button,
                [class*="companion-ad"] {
                    display: none !important;
                }
            `;
            document.head.appendChild(s);
            
            // --- Skip video ads instantly ---
            function skipAd() {
                var p = document.querySelector('.html5-video-player');
                if (!p) return;
                if (p.classList.contains('ad-showing') || p.classList.contains('ad-interrupting')) {
                    var v = p.querySelector('video');
                    if (v && v.duration && isFinite(v.duration) && v.duration > 0) {
                        v.currentTime = v.duration;
                    }
                    document.querySelectorAll('.ytp-skip-ad-button,.ytp-ad-skip-button,.ytp-ad-skip-button-modern,[id^="skip-button"]').forEach(function(b) {
                        try { b.click(); } catch(e) {}
                    });
                }
            }
            
            // --- Remove page ad elements ---
            function removeAds() {
                document.querySelectorAll('#player-ads,#masthead-ad,ytd-ad-slot-renderer,ytd-in-feed-ad-layout-renderer,ytm-promoted-sparkles-web-renderer,ytm-companion-slot').forEach(function(el) {
                    el.remove();
                });
            }
            
            // Run every 500ms
            setInterval(function() {
                skipAd();
                removeAds();
            }, 500);
            
            // Watch for ad-showing class
            var obs = new MutationObserver(function() { skipAd(); });
            var player = document.querySelector('.html5-video-player');
            if (player) {
                obs.observe(player, { attributes: true, attributeFilter: ['class'] });
            }
            
            // --- Background Audio: Override visibility API ---
            // Trick YouTube into thinking page is always visible
            // so it won't pause video when app goes to background
            Object.defineProperty(document, 'hidden', {
                get: function() { return false; },
                configurable: true
            });
            Object.defineProperty(document, 'visibilityState', {
                get: function() { return 'visible'; },
                configurable: true
            });
            // Block visibilitychange event from reaching YouTube's listener
            document.addEventListener('visibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);
        })();
        """
        webView.evaluateJavaScript(adBlockScript, completionHandler: nil)
    }

    // MARK: - Background Audio

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
        
        // Only block app-open redirects
        if urlString.hasPrefix("youtube://") ||
           urlString.hasPrefix("vnd.youtube://") ||
           urlString.contains("intent://") {
            decisionHandler(.cancel)
            return
        }
        
        // External links → Safari
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
        
        // Allow everything else — DO NOT block any YouTube/Google URLs
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait 2 seconds for YouTube player to fully initialize
        // THEN inject ad blocker — safe, won't break playback
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.injectAdBlocker()
        }
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
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        if origin.host.contains("youtube.com") || origin.host.contains("google.com") {
            decisionHandler(.grant)
        } else {
            decisionHandler(.deny)
        }
    }
}
