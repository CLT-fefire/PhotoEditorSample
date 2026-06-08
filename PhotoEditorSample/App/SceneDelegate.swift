import UIKit

/// iOS 13 이상 전용. Info.plist의 UIApplicationSceneManifest가 이 클래스를 지정한다.
/// iOS 12 에서는 이 클래스가 인스턴스화되지 않으며, AppDelegate가 window를 구성한다.
@available(iOS 13.0, *)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = EditorViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}
