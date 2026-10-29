#if os(iOS)
import Flutter
import UIKit
import SgNativePlayerBridge
#elseif os(macOS)
import AppKit
import FlutterMacOS
#endif

public class KineticPlayerPlugin: NSObject, FlutterPlugin {
#if os(iOS)
  public func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) -> Bool {
    SgNativePlayerBridge.handleBackgroundSession(identifier, completion: completionHandler)
  }
#endif

  public static func register(with registrar: FlutterPluginRegistrar) {
#if os(iOS)
    let messenger = registrar.messenger()
    let lifecycleDelegate = KineticPlayerPlugin()
    registrar.addApplicationDelegate(lifecycleDelegate)
    registrar.publish(lifecycleDelegate)
#elseif os(macOS)
    let messenger = registrar.messenger
#endif
    registrar.register(
      SgVideoViewFactory(messenger: messenger),
      withId: PlayerConstants.sgViewType
    )
  }
}
