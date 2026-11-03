import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  private let sigManager = CLLocationManager()
  private var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    sigManager.delegate = self
    // 被系统因「显著位置变化」重新拉起时，launchOptions 含 .location；
    // Dart 端 main() 随后会检查 tracking_enabled 并恢复连续定位。
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let ch = FlutterMethodChannel(name: "couple/location", binaryMessenger: messenger)
    ch.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "startSignificant":
        // 需要「始终」授权；被终止后由系统在位置显著变化（约 500 米）时唤醒 App
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
          self.sigManager.allowsBackgroundLocationUpdates = true
          self.sigManager.pausesLocationUpdatesAutomatically = false
          self.sigManager.startMonitoringSignificantLocationChanges()
          result(true)
        } else { result(false) }
      case "stopSignificant":
        self.sigManager.stopMonitoringSignificantLocationChanges()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    channel = ch
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // 仅用于唤醒；真正的上报由 Dart 端 geolocator 连续定位完成。
    channel?.invokeMethod("significantChange", arguments: nil)
  }
}
