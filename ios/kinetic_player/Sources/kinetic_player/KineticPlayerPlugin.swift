import Flutter
import UIKit

public class KineticPlayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      SgVideoViewFactory(messenger: registrar.messenger()),
      withId: PlayerConstants.sgViewType
    )
  }
}
