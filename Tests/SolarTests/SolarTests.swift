@testable import Solar
import XCTest

final class SolarTests: XCTestCase {
 func testPrediction() throws {
  let now = Date()
  let currentPredictions = try XCTUnwrap(
   Solar.PhasePredictions(for: now, x: 37.334606, y: -122.009102)
  )

  let future = Date().addingTimeInterval(86400 / 2)
  let laterPredictions = try XCTUnwrap(
   Solar.PhasePredictions(
    for: future,
    x: 37.334606,
    y: -122.009102
   )
  )

  XCTAssert(laterPredictions.isNighttime)

  let past = Date().addingTimeInterval(-86400 / 2)
  let pastPredictions = try XCTUnwrap(
   Solar.PhasePredictions(
    for: past,
    x: 37.334606,
    y: -122.009102
   )
  )

  XCTAssert(pastPredictions.isNighttime)

  let nextDay = Date().addingTimeInterval(86400)
  let nextDayPredictions = try XCTUnwrap(
   Solar.PhasePredictions(
    for: nextDay,
    x: 37.334606,
    y: -122.009102
   )
  )

  XCTAssert(nextDayPredictions.isDaytime)

  let isDaytime = currentPredictions.isDaytime

  XCTAssert(
   isDaytime
    ? laterPredictions.isNighttime
    : laterPredictions.isDaytime
  )

  let nextDaySunriseAdjusted =
   nextDayPredictions.sunrise.addingTimeInterval(-86400)

  // check if difference between next day and current is within 60 seconds
  XCTAssertEqual(
   nextDaySunriseAdjusted.timeIntervalSinceReferenceDate,
   currentPredictions.sunrise.timeIntervalSinceReferenceDate, accuracy: 60
  )
 }
}
