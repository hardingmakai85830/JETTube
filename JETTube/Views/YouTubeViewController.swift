import UIKit
import WebKit
import AVKit
import MediaPlayer

class YouTubeViewController: UIViewController {

    // MARK: - Properties
    var initialURL: String = Constants.youtubeBaseURL
    
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var progressObserver: NSKeyValueObservation?
    private var urlObserver: NSKeyValueObservation?
    
    // PiP
    private var pipController: AVPictureInPictureController?
    private var pipPossibleObserver: NSKeyValueObservation?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        
        setupWebView()
        setupProgressBar()
        setupNowPlaying()
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
        urlObserver?.invalidate()
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
        
        // IMPORTANT: Do NOT inject any scripts at page load
        // YouTube's player must initialize without interference
        // Ad blocker is injected AFTER page fully loads (see didFinish)
        
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
        
        // URL observer — detect video page vs home page for tab bar visibility
        urlObserver = webView.observe(\.url, options: .new) { [weak self] webView, _ in
            guard let self = self, let url = webView.url?.absoluteString else { return }
            let isVideoPage = url.contains("/watch?v=") || url.contains("/watch?") || url.contains("/shorts/")
            DispatchQueue.main.async {
                self.tabBarController?.tabBar.isHidden = isVideoPage
            }
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

    // MARK: - Ad Blocker + Auto-Continue + Background Audio (delayed injection)
    
    /// Inject all scripts ONLY after page fully loads
    /// Waits 2 seconds after didFinish to ensure YouTube player is ready
    private func injectAllScripts() {
        let script = """
        (function() {
            if (window._jetTubeInjected) return;
            window._jetTubeInjected = true;
            
            // ============================================================
            // 1. CSS: Hide ad UI elements
            // ============================================================
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
            
            // ============================================================
            // 2. Skip video ads instantly
            // ============================================================
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
            
            // ============================================================
            // 3. Remove page ad elements
            // ============================================================
            function removeAds() {
                document.querySelectorAll('#player-ads,#masthead-ad,ytd-ad-slot-renderer,ytd-in-feed-ad-layout-renderer,ytm-promoted-sparkles-web-renderer,ytm-companion-slot').forEach(function(el) {
                    el.remove();
                });
            }
            
            // ============================================================
            // 4. AUTO-DISMISS "Are you still watching?" popup
            // YouTube shows this after ~30min of inactivity
            // ============================================================
            function dismissStillWatching() {
                // Desktop popup
                document.querySelectorAll('yt-confirm-dialog-renderer').forEach(function(dialog) {
                    var btn = dialog.querySelector('#confirm-button button, a.yt-simple-endpoint, tp-yt-paper-button#confirm-button');
                    if (btn) { btn.click(); return; }
                });
                
                // Mobile popup
                document.querySelectorAll('ytm-popup-container, ytm-upsell-dialog-renderer').forEach(function(popup) {
                    var btn = popup.querySelector('button, .dialog-confirm-button, [class*="confirm"]');
                    if (btn) { btn.click(); return; }
                });
                
                // Generic: look for any popup with "still watching" / "continue watching" text
                document.querySelectorAll('tp-yt-paper-dialog, ytd-popup-container, [role="dialog"]').forEach(function(popup) {
                    var text = (popup.textContent || '').toLowerCase();
                    if (text.includes('still watching') || text.includes('continue watching') || 
                        text.includes('video has been paused') || text.includes('bạn vẫn đang xem') ||
                        text.includes('tiếp tục xem') || text.includes('muốn nghe tiếp')) {
                        // Find and click the confirm/yes button
                        var buttons = popup.querySelectorAll('button, a[role="button"], tp-yt-paper-button, ytm-button-renderer button');
                        for (var i = 0; i < buttons.length; i++) {
                            var btnText = (buttons[i].textContent || '').toLowerCase();
                            if (btnText.includes('yes') || btnText.includes('ok') || btnText.includes('có') || 
                                btnText.includes('continue') || btnText.includes('tiếp') || btnText.includes('confirm') ||
                                btnText.includes('dismiss')) {
                                buttons[i].click();
                                break;
                            }
                        }
                        // If no text match, click first button as fallback
                        if (buttons.length > 0 && !popup.classList.contains('_jet_dismissed')) {
                            popup.classList.add('_jet_dismissed');
                            buttons[0].click();
                        }
                    }
                });
                
                // Also: if video is paused and no user interaction, auto-resume
                var v = document.querySelector('video');
                if (v && v.paused && v.src && !v.ended && v.readyState > 2) {
                    // Check if pause is from YouTube popup, not user
                    var popup = document.querySelector('yt-confirm-dialog-renderer, [role="dialog"]');
                    if (popup) {
                        v.play().catch(function(){});
                    }
                }
            }
            
            // ============================================================
            // 5. Background Audio: Override visibility API
            // ============================================================
            Object.defineProperty(document, 'hidden', {
                get: function() { return false; },
                configurable: true
            });
            Object.defineProperty(document, 'visibilityState', {
                get: function() { return 'visible'; },
                configurable: true
            });
            document.addEventListener('visibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);
            
            // ============================================================
            // 6. Main loop — runs every 500ms
            // ============================================================
            setInterval(function() {
                skipAd();
                removeAds();
                dismissStillWatching();
            }, 500);
            
            // Watch for ad-showing class changes
            var obs = new MutationObserver(function() { skipAd(); });
            var player = document.querySelector('.html5-video-player');
            if (player) {
                obs.observe(player, { attributes: true, attributeFilter: ['class'] });
            }
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: - Now Playing (Lock Screen Controls)
    
    private func setupNowPlaying() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.webView?.evaluateJavaScript("document.querySelector('video')?.play()") { _, _ in }
            return .success
        }
        
        // Pause
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.webView?.evaluateJavaScript("document.querySelector('video')?.pause()") { _, _ in }
            return .success
        }
        
        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.webView?.evaluateJavaScript("""
                (function() {
                    var v = document.querySelector('video');
                    if (v) { v.paused ? v.play() : v.pause(); }
                })();
            """) { _, _ in }
            return .success
        }
        
        // Skip forward 10s
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.webView?.evaluateJavaScript("var v=document.querySelector('video'); if(v) v.currentTime+=10;") { _, _ in }
            return .success
        }
        
        // Skip backward 10s
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.webView?.evaluateJavaScript("var v=document.querySelector('video'); if(v) v.currentTime-=10;") { _, _ in }
            return .success
        }
    }
    
    /// Update Now Playing info from current video
    private func updateNowPlayingInfo() {
        let js = """
        (function() {
            var v = document.querySelector('video');
            var title = '';
            // Try different selectors for video title
            var titleEl = document.querySelector('.slim-video-information-title, .ytm-slim-video-information-renderer .title, h1.title, [class*="title"] yt-formatted-string');
            if (titleEl) title = titleEl.textContent.trim();
            if (!title) title = document.title.replace(' - YouTube', '').trim();
            
            var channel = '';
            var channelEl = document.querySelector('.slim-owner-channel-name, .ytm-slim-owner-renderer .channel-name, #channel-name a, ytd-channel-name a');
            if (channelEl) channel = channelEl.textContent.trim();
            
            return JSON.stringify({
                title: title,
                channel: channel,
                duration: v ? v.duration : 0,
                currentTime: v ? v.currentTime : 0,
                paused: v ? v.paused : true
            });
        })();
        """
        
        webView?.evaluateJavaScript(js) { [weak self] result, error in
            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            let title = info["title"] as? String ?? "JET Tube"
            let channel = info["channel"] as? String ?? ""
            let duration = info["duration"] as? Double ?? 0
            let currentTime = info["currentTime"] as? Double ?? 0
            let paused = info["paused"] as? Bool ?? true
            
            var nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyTitle: title,
                MPMediaItemPropertyArtist: channel,
                MPMediaItemPropertyPlaybackDuration: duration,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
                MPNowPlayingInfoPropertyPlaybackRate: paused ? 0.0 : 1.0
            ]
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
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
        
        // Allow everything else
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait 2 seconds for YouTube player to fully initialize
        // THEN inject all scripts — safe, won't break playback
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.injectAllScripts()
        }
        
        // Update now playing info periodically
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.updateNowPlayingInfo()
            // Keep updating every 5 seconds
            self?.startNowPlayingTimer()
        }
    }
    
    private func startNowPlayingTimer() {
        // Update now playing info every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.updateNowPlayingInfo()
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
