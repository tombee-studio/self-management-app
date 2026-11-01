import XCTest
final class NativeUI: XCTestCase {
  private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
  private func acceptOpenURL() {
    let button = springboard.alerts.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "開く", "Open")).firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 30), "URL confirmation must be presented")
    button.tap()
  }
  func testAcceptOpenURL() { acceptOpenURL() }
  func testAcceptOpenURLAndNotification() {
    acceptOpenURL()
    let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "許可", "Allow")).firstMatch
    XCTAssertTrue(allow.waitForExistence(timeout: 45), "Native notification permission must be requested")
    allow.tap()
    let banner = springboard.staticTexts["支出を記録しました"].firstMatch
    XCTAssertTrue(banner.waitForExistence(timeout: 30), "Notification banner must be delivered")
    banner.tap()
  }
}
