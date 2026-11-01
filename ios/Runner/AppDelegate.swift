import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var eventSink: FlutterEventSink?
  private var initialUrl: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let deviceChannel = FlutterMethodChannel(name: "com.iris.app/device", binaryMessenger: controller.binaryMessenger)
      deviceChannel.setMethodCallHandler { call, result in
        if call.method == "timeZone" { result(TimeZone.current.identifier) }
        else { result(FlutterMethodNotImplemented) }
      }
      let methodChannel = FlutterMethodChannel(
        name: "com.iris.app/deep_link",
        binaryMessenger: controller.binaryMessenger
      )

      if let url = launchOptions?[.url] as? URL {
        initialUrl = url.absoluteString
      }

      methodChannel.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "getInitialUrl" {
          result(self?.initialUrl)
          self?.initialUrl = nil
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      let eventChannel = FlutterEventChannel(
        name: "com.iris.app/deep_link_events",
        binaryMessenger: controller.binaryMessenger
      )
      eventChannel.setStreamHandler(self)
    }

    UNUserNotificationCenter.current().delegate = self
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let sink = eventSink { sink(url.absoluteString) }
    else { initialUrl = url.absoluteString }
    _ = super.application(app, open: url, options: options)
    return true
  }

}

extension AppDelegate: FlutterStreamHandler {
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}

