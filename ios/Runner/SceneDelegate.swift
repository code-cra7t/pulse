import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    NotificationCenter.default.post(name: .jotCueSharedContentAvailable, object: nil)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    if URLContexts.contains(where: { context in
      context.url.scheme == "jotcue" && context.url.host == "share"
    }) {
      NotificationCenter.default.post(name: .jotCueSharedContentAvailable, object: nil)
    }
  }
}
