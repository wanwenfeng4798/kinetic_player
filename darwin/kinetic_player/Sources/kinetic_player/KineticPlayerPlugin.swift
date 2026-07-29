#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import AppKit
import FlutterMacOS
#endif

public class KineticPlayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
#if os(iOS)
    let messenger = registrar.messenger()
#elseif os(macOS)
    let messenger = registrar.messenger
#endif
    registrar.register(
      SgVideoViewFactory(messenger: messenger),
      withId: PlayerConstants.sgViewType
    )
  }
}
