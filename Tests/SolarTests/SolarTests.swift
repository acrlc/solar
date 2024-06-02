@testable import Solar
import XCTest

final class SolarTests: XCTestCase {
 func testHours() {
  print("current clock cycle is", Locale.current.hoursPerCycle, "hours")
 }
}
