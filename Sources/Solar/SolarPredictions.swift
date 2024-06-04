import Foundation

/// source: https://github.com/ceeK/Solar
public extension Solar {
 struct PhasePredictions {
  public let x: Double
  public let y: Double

  /// The date to generate sunrise / sunset times for
  public let date: Date

  public let sunrise: Date
  public let sunset: Date

  public init?(
   for date: Date = Date(), x: Double, y: Double,
   with zenith: Zenith = .official
  ) {
   self.date = date

   assert(
    x >= -90 && x <= 90 && y >= -180 && y <= 180,
    "coordinates for \(#function) must be valid"
   )

   guard
    let sunrise =
    Self.calculate(.sunrise, for: date, x: x, y: y, with: zenith),
    let sunset =
    Self.calculate(.sunset, for: date, x: x, y: y, with: zenith)
   else {
    return nil
   }
   self.x = x
   self.y = y
   self.sunrise = sunrise
   self.sunset = sunset
  }

  public var isDaytime: Bool {
   let beginningOfDay = sunrise.timeIntervalSince1970
   let endOfDay = sunset.timeIntervalSince1970
   let currentTime = date.timeIntervalSince1970

   let isSunriseOrLater = currentTime >= beginningOfDay
   let isBeforeSunset = currentTime < endOfDay

   return isSunriseOrLater && isBeforeSunset
  }

  public var isNighttime: Bool { !isDaytime }

  public enum SunriseSunset {
   case sunrise
   case sunset
  }

  /// Used for generating several of the possible sunrise / sunset times
  public enum Zenith: Double {
   case official = 90.83
   case civil = 96
   case nautical = 102
   case astronimical = 108
  }

  public static func calculate(
   _ sunriseSunset: SunriseSunset,
   for date: Date,
   x: Double, y: Double,
   with zenith: Zenith
  ) -> Date? {
   guard let utcTimezone = TimeZone(identifier: "UTC") else { return nil }
   // Get the day of the year
   var calendar = Calendar(identifier: .gregorian)
   calendar.timeZone = utcTimezone

   guard let dayInt = calendar.ordinality(of: .day, in: .year, for: date)
   else { return nil }
   let day = Double(dayInt)

   // Convert longitude to hour value and calculate an approx. time
   let lngHour = y / 15

   let hourTime: Double = sunriseSunset == .sunrise ? 6 : 18
   let t = day + ((hourTime - lngHour) / 24)

   // Calculate the suns mean anomaly
   let M = (0.9856 * t) - 3.289

   // Calculate the sun's true longitude
   let subexpression1 = 1.916 * sin(M.degreesToRadians)
   let subexpression2 = 0.020 * sin(2 * M.degreesToRadians)
   var L = M + subexpression1 + subexpression2 + 282.634

   // Normalise L into [0, 360] range
   L = normalise(L, withMaximum: 360)

   // Calculate the Sun's right ascension
   var RA = atan(0.91764 * tan(L.degreesToRadians)).radiansToDegrees

   // Normalise RA into [0, 360] range
   RA = normalise(RA, withMaximum: 360)

   // Right ascension value needs to be in the same quadrant as L...
   let Lquadrant = floor(L / 90) * 90
   let RAquadrant = floor(RA / 90) * 90
   RA += (Lquadrant - RAquadrant)

   // Convert RA into hours
   RA /= 15

   // Calculate Sun's declination
   let sinDec = 0.39782 * sin(L.degreesToRadians)
   let cosDec = cos(asin(sinDec))

   // Calculate the Sun's local hour angle
   let cosH = (
    cos(zenith.rawValue.degreesToRadians) -
     (sinDec * sin(x.degreesToRadians))
   ) / (
    cosDec * cos(x.degreesToRadians)
   )

   // No sunrise
   guard cosH < 1 else {
    return nil
   }

   // No sunset
   guard cosH > -1 else {
    return nil
   }

   // Finish calculating H and convert into hours
   let tempH = sunriseSunset == .sunrise
    ? 360 - acos(cosH).radiansToDegrees
    : acos(cosH).radiansToDegrees
   let H = tempH / 15.0

   // Calculate local mean time of rising
   let T = H + RA - (0.06571 * t) - 6.622

   // Adjust time back to UTC
   var UT = T - lngHour

   // Normalise UT into [0, 24] range
   UT = normalise(UT, withMaximum: 24)

   // Calculate all of the sunrise's / sunset's date components
   let hour = floor(UT)
   let minute = floor((UT - hour) * 60.0)
   let second = (((UT - hour) * 60) - minute) * 60.0

   let shouldBeYesterday =
    lngHour > 0 && UT > 12 && sunriseSunset == .sunrise
   let shouldBeTomorrow =
    lngHour < 0 && UT < 12 && sunriseSunset == .sunset

   let setDate: Date = if shouldBeYesterday {
    Date(timeInterval: -86400, since: date)
   } else if shouldBeTomorrow {
    Date(timeInterval: 86400, since: date)
   } else {
    date
   }

   var components = calendar.dateComponents(
    [.day, .month, .year],
    from: setDate
   )
   components.hour = Int(hour)
   components.minute = Int(minute)
   components.second = Int(second)

//   calendar.timeZone = utcTimezone

   return calendar.date(from: components)
  }

  /// Normalises a value between 0 and `maximum`, by adding or subtracting
  /// `maximum`
  static func normalise(
   _ value: Double,
   withMaximum maximum: Double
  ) -> Double {
   var value = value

   if value < 0 {
    value += maximum
   }

   if value > maximum {
    value -= maximum
   }

   return value
  }
 }
}

public typealias PhasePredictions = Solar.PhasePredictions

#if canImport(CoreLocation)
import struct CoreLocation.CLLocationCoordinate2D

public extension Solar.PhasePredictions {
 init?(
  for date: Date = Date(),
  location: CLLocationCoordinate2D,
  with zenith: Zenith = .official
 ) {
  self.init(
   for: date,
   x: location.latitude,
   y: location.longitude,
   with: zenith
  )
 }
}
#endif
// MARK: - Extensions
private extension Double {
 var degreesToRadians: Double {
  Double(self) * (Double.pi / 180.0)
 }

 var radiansToDegrees: Double {
  (Double(self) * 180.0) / Double.pi
 }
}
