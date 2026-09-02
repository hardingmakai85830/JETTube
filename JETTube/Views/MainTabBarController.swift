import UIKit

class MainTabBarController: UITabBarController {

    private var youtubeVC: YouTubeViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
    }

    private func setupTabs() {
        // Home — YouTube main page
        youtubeVC = YouTubeViewController()
        youtubeVC.initialURL = Constants.youtubeBaseURL
        let homeNav = UINavigationController(rootViewController: youtubeVC)
        homeNav.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: Constants.TabIcons.home),
            tag: 0
        )
        homeNav.isNavigationBarHidden = true

        // Search
        let searchVC = YouTubeViewController()
        searchVC.initialURL = Constants.youtubeBaseURL + "/feed/explore"
        let searchNav = UINavigationController(rootViewController: searchVC)
        searchNav.tabBarItem = UITabBarItem(
            title: "Explore",
            image: UIImage(systemName: Constants.TabIcons.search),
            tag: 1
        )
        searchNav.isNavigationBarHidden = true

        // Library
        let libraryVC = YouTubeViewController()
        libraryVC.initialURL = Constants.youtubeBaseURL + "/feed/library"
        let libraryNav = UINavigationController(rootViewController: libraryVC)
        libraryNav.tabBarItem = UITabBarItem(
            title: "Library",
            image: UIImage(systemName: Constants.TabIcons.library),
            tag: 2
        )
        libraryNav.isNavigationBarHidden = true

        // Settings
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: Constants.TabIcons.settings),
            tag: 3
        )

        viewControllers = [homeNav, searchNav, libraryNav, settingsNav]
    }

    /// Open a YouTube URL from deep link
    func openYouTubeURL(_ urlString: String) {
        selectedIndex = 0
        youtubeVC.loadURL(urlString)
    }
}


// MARK: - Settings View Controller

class SettingsViewController: UITableViewController {

    private let sections = ["Ad Blocker", "Playback", "About"]
    private let items: [[SettingsItem]] = [
        [
            SettingsItem(title: "Block Ads", key: Constants.Defaults.adBlockEnabled, defaultValue: true),
            SettingsItem(title: "SponsorBlock", key: Constants.Defaults.sponsorBlockEnabled, defaultValue: true),
        ],
        [
            SettingsItem(title: "Background Play", key: Constants.Defaults.backgroundPlayEnabled, defaultValue: true),
        ],
        []
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.backgroundColor = UIColor(named: "Background") ?? .systemBackground
        view.overrideUserInterfaceStyle = .dark
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 2 { return 2 } // About section: version + credits
        return items[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 2 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "about")
            cell.backgroundColor = .secondarySystemGroupedBackground
            if indexPath.row == 0 {
                cell.textLabel?.text = "Version"
                cell.detailTextLabel?.text = Constants.version
            } else {
                cell.textLabel?.text = "Developer"
                cell.detailTextLabel?.text = "JET ⚡"
                cell.detailTextLabel?.textColor = UIColor(red: 1, green: 0.27, blue: 0.34, alpha: 1)
            }
            cell.selectionStyle = .none
            return cell
        }

        let item = items[indexPath.section][indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: "toggle")
        cell.textLabel?.text = item.title
        cell.backgroundColor = .secondarySystemGroupedBackground
        cell.selectionStyle = .none

        let toggle = UISwitch()
        toggle.isOn = UserDefaults.standard.object(forKey: item.key) as? Bool ?? item.defaultValue
        toggle.tag = indexPath.section * 100 + indexPath.row
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        toggle.onTintColor = UIColor(red: 1, green: 0.27, blue: 0.34, alpha: 1)
        cell.accessoryView = toggle

        return cell
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        let section = sender.tag / 100
        let row = sender.tag % 100
        let item = items[section][row]
        UserDefaults.standard.set(sender.isOn, forKey: item.key)
    }
}

struct SettingsItem {
    let title: String
    let key: String
    let defaultValue: Bool
}
