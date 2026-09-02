import UIKit

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
}
