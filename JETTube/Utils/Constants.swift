import Foundation

enum Constants {
    static let appName = "JET Tube"
    static let version = "1.0.0"
    static let youtubeBaseURL = "https://m.youtube.com"
    static let youtubeSearchURL = "https://m.youtube.com/results?search_query="
    
    // Tab bar icons (SF Symbols)
    enum TabIcons {
        static let home = "house.fill"
        static let search = "magnifyingglass"
        static let library = "play.square.stack.fill"
        static let settings = "gearshape.fill"
    }
    
    // Colors
    enum Colors {
        static let background = "#0a0a0f"
        static let accent = "#ff4757"
        static let accentGradientEnd = "#ee5a24"
        static let textPrimary = "#ffffff"
        static let textSecondary = "#888888"
        static let tabBar = "#0a0a0f"
    }
    
    // UserDefaults keys
    enum Defaults {
        static let adBlockEnabled = "adblock_enabled"
        static let sponsorBlockEnabled = "sponsorblock_enabled"
        static let backgroundPlayEnabled = "background_play_enabled"
        static let darkModeEnabled = "dark_mode_enabled"
        static let adsBlocked = "ads_blocked_count"
    }
}
