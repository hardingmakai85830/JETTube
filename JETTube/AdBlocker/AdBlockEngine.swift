import WebKit

/// Native ad blocking engine for WKWebView
/// Combines WKContentRuleList (WebKit-level) + JS injection + URL filtering
class AdBlockEngine {

    // MARK: - URL Patterns to Block
    // ONLY external ad domains — do NOT block YouTube internal URLs
    // as they may break video playback
    
    private let adURLPatterns: [String] = [
        "doubleclick.net",
        "googleadservices.com",
        "googlesyndication.com",
        "google.com/pagead",
        "google.com/adsense",
        "fundingchoicesmessages.google.com",
    ]
    
    // MARK: - URL Check (for navigation delegate)
    
    func shouldBlockURL(_ url: String) -> Bool {
        for pattern in adURLPatterns {
            if url.contains(pattern) {
                return true
            }
        }
        return false
    }
    
    // MARK: - WKContentRuleList (Native WebKit URL blocking)
    
    /// Compiles JSON rules into WKContentRuleList — blocks at WebKit level (fastest)
    /// Only blocks external ad servers, NOT YouTube internal URLs
    func compileContentRules(completion: @escaping (WKContentRuleList?) -> Void) {
        let rules: [[String: Any]] = [
            makeBlockRule("*doubleclick.net*"),
            makeBlockRule("*googleadservices.com*"),
            makeBlockRule("*googlesyndication.com*"),
            makeBlockRule("*google.com/pagead/*"),
            makeBlockRule("*google.com/adsense*"),
            makeBlockRule("*fundingchoicesmessages.google.com*"),
            makeBlockRule("*googleads.g.doubleclick.net*"),
            makeBlockRule("*static.doubleclick.net*"),
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: rules),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(nil)
            return
        }
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "JETTubeAdBlock",
            encodedContentRuleList: jsonString
        ) { ruleList, error in
            if let error = error {
                print("[JETTube] Rule compile error: \(error)")
            }
            DispatchQueue.main.async {
                completion(ruleList)
            }
        }
    }
    
    private func makeBlockRule(_ urlFilter: String) -> [String: Any] {
        return [
            "trigger": ["url-filter": urlFilter],
            "action": ["type": "block"]
        ]
    }
    
    // MARK: - JavaScript Injection
    
    /// Load ad blocker JS from bundle
    func getAdBlockerScript() -> String? {
        guard let path = Bundle.main.path(forResource: "AdBlockerScript", ofType: "js"),
              let script = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("[JETTube] Failed to load AdBlockerScript.js")
            return nil
        }
        return script
    }
    
    /// Load CSS and wrap in JS injection
    func getAdBlockerCSS() -> String? {
        guard let path = Bundle.main.path(forResource: "AdBlockerCSS", ofType: "css"),
              let css = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("[JETTube] Failed to load AdBlockerCSS.css")
            return nil
        }
        
        let escapedCSS = css
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return """
        (function() {
            var style = document.createElement('style');
            style.textContent = `\(escapedCSS)`;
            (document.head || document.documentElement).appendChild(style);
        })();
        """
    }
    
    /// Post-load safety scan script
    func getPostLoadScript() -> String {
        return """
        (function() {
            // Re-run ad nuke after page fully loaded
            var player = document.querySelector('.html5-video-player');
            if (player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'))) {
                var video = player.querySelector('video');
                if (video && video.duration && isFinite(video.duration)) {
                    video.currentTime = video.duration;
                    try { video.playbackRate = 16; } catch(e) {}
                    video.muted = true;
                }
                // Click skip
                document.querySelectorAll('.ytp-skip-ad-button,.ytp-ad-skip-button,.ytp-ad-skip-button-modern,[id^="skip-button"]').forEach(function(b) {
                    try { b.click(); } catch(e) {}
                });
            }
            
            // Remove page ads
            document.querySelectorAll('#player-ads,#masthead-ad,ytd-promoted-sparkles-web-renderer,ytd-ad-slot-renderer,ytd-in-feed-ad-layout-renderer,ytd-banner-promo-renderer,ytm-promoted-sparkles-web-renderer').forEach(function(el) {
                el.remove();
            });
            
            // Anti-adblock bypass
            document.querySelectorAll('ytd-enforcement-message-view-model').forEach(function(el) { el.remove(); });
            document.querySelectorAll('tp-yt-paper-dialog').forEach(function(popup) {
                var text = (popup.textContent || '').toLowerCase();
                if (text.includes('ad blocker') || text.includes('adblock')) {
                    popup.remove();
                    document.querySelectorAll('tp-yt-iron-overlay-backdrop').forEach(function(b) { b.remove(); });
                }
            });
        })();
        """
    }
}
