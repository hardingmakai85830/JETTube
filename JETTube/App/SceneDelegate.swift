import UIKit
import AVFoundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = MainTabBarController()
        self.window = window
        window.makeKeyAndVisible()
        
        // Handle URL if app launched from link
        if let urlContext = connectionOptions.urlContexts.first {
            handleURL(urlContext.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleURL(url)
        }
    }
    
    func scene(
        _ scene: UIScene,
        continue userActivity: NSUserActivity
    ) {
        if let url = userActivity.webpageURL {
            handleURL(url)
        }
    }

    private func handleURL(_ url: URL) {
        // Handle YouTube URLs opened from other apps
        let urlString = url.absoluteString
        if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
            if let tabBar = window?.rootViewController as? MainTabBarController {
                tabBar.openYouTubeURL(urlString)
            }
        }
    }

    // MARK: - Background Audio Support

    func sceneWillResignActive(_ scene: UIScene) {
        // Re-activate audio session before going to background
        try? AVAudioSession.sharedInstance().setActive(true)
        injectBackgroundAudioScript()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Ensure audio keeps playing after entering background
        try? AVAudioSession.sharedInstance().setActive(true)
        // Delayed re-play to catch cases where YouTube pauses after visibility change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.injectBackgroundAudioScript()
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func injectBackgroundAudioScript() {
        guard let tabBar = window?.rootViewController as? MainTabBarController else { return }
        
        let bgScript = """
        (function() {
            // Re-override visibility (safety net)
            Object.defineProperty(document, 'hidden', { get: function() { return false; }, configurable: true });
            Object.defineProperty(document, 'visibilityState', { get: function() { return 'visible'; }, configurable: true });
            
            // Resume video if paused
            var videos = document.querySelectorAll('video');
            videos.forEach(function(v) {
                if (v.paused && v.src) {
                    v.play().catch(function() {});
                }
            });
        })();
        """
        
        if let navControllers = tabBar.viewControllers {
            for nav in navControllers {
                if let navVC = nav as? UINavigationController,
                   let ytVC = navVC.viewControllers.first as? YouTubeViewController {
                    ytVC.evaluateBackgroundScript(bgScript)
                }
            }
        }
    }
}
