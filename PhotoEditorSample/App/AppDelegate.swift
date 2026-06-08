import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    /// iOS 12에서만 사용되는 window. iOS 13+ 에서는 SceneDelegate가 window를 소유한다.
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // iOS 13+ 는 SceneDelegate.scene(_:willConnectTo:options:) 에서 window를 구성한다.
        // iOS 12 는 Scene을 지원하지 않으므로 여기서 직접 구성한다.
        if #available(iOS 13.0, *) {
            // SceneDelegate가 처리
        } else {
            let window = UIWindow(frame: UIScreen.main.bounds)
            window.rootViewController = EditorViewController()
            window.makeKeyAndVisible()
            self.window = window
        }
        return true
    }

    // MARK: - UISceneSession Lifecycle (iOS 13+)

    @available(iOS 13.0, *)
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
