@testable import Solar
import XCTest

final class SolarTests: XCTestCase {
 func testPrediction() throws {
  let (x, y) = (37.334606, -122.009102)
  
  let now = Date(timeIntervalSinceReferenceDate: 752284800.0)

  let currentPredictions = try XCTUnwrap(
   Solar.PhasePredictions(for: now, x: x, y: y)
  )

  XCTAssert(currentPredictions.isNighttime)

  let future = now.addingTimeInterval(86400 / 2)
  let laterPredictions = try XCTUnwrap(
   Solar.PhasePredictions(for: future, x: x, y: y)
  )
  
  XCTAssert(laterPredictions.isDaytime)

  let past = now.addingTimeInterval(-86400 / 2)
  let pastPredictions = try XCTUnwrap(
   Solar.PhasePredictions(
    for: past,
    x: x,
    y: y
   )
  )

  XCTAssert(pastPredictions.isNighttime)
 
  let nextDay = now.addingTimeInterval(86400)
  let nextDayPredictions = try XCTUnwrap(
   Solar.PhasePredictions(for: nextDay, x: x, y: y)
  )

  XCTAssert(nextDayPredictions.isNighttime)

  let isDaytime = currentPredictions.isDaytime

  XCTAssert(
   isDaytime
    ? laterPredictions.isNighttime
    : laterPredictions.isDaytime
  )

  let nextDaySunriseAdjusted =
   nextDayPredictions.sunrise.addingTimeInterval(-86400)
  
  // check if difference between next day and current is 175 seconds
  XCTAssertEqual(
   nextDaySunriseAdjusted.timeIntervalSinceReferenceDate,
   currentPredictions.sunrise.timeIntervalSinceReferenceDate, accuracy: 175
  )
 }
}
