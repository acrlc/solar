import Foundation

/// source: https://github.com/ceeK/Solar
public extension Solar {
 struct PhasePredictions {
  public let x: Double
  public let y: Double
  public let date: Date
  public let sunrise: Date
  public let sunset: Date

  init(x: Double, y: Double, date: Date, sunrise: Date, sunset: Date) {
   self.x = x
   self.y = y
   self.date = date
   self.sunrise = sunrise
   self.sunset = sunset
  }

  public init?(
   for date: Date = Date(), x: Double, y: Double,
   with zenith: Zenith = .official
  ) {
   assert(
    x >= -90 && x <= 90 && y >= -180 && y <= 180,
    "coordinates for \(#function) must be valid"
   )

   guard let utcTimezone = TimeZone(identifier: "UTC") else {
    fatalError("timezone with identifier UTC doesn't exist")
   }

   let calendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = utcTimezone
    return cal
   }()

   guard
    var sunrise =
    Self.calculate(
     true, for: date, calendar: calendar, x: x, y: y, with: zenith
    ),
    var sunset =
    Self.calculate(
     false, for: date, calendar: calendar, x: x, y: y, with: zenith
    )
   else {
    return nil
   }

   if date >= sunset {
    sunrise.addTimeInterval(86400)
    sunset.addTimeInterval(86400)
   }
   self.init(x: x, y: y, date: date, sunrise: sunrise, sunset: sunset)
  }
  
  
  public var isDaytime: Bool { date > sunrise && date < sunset }
  public var isNighttime: Bool { !isDaytime }

  /// Used for generating several of the possible sunrise / sunset times
  public enum Zenith: Double {
   case official = 90.83
   case civil = 96
   case nautical = 102
   case astronimical = 108
  }

  public static func calculate(
   _ isSunrise: Bool,
   for date: Date,
   calendar: Calendar,
   x: Double, y: Double,
   with zenith: Zenith
  ) -> Date? {
   let date = calendar.startOfDay(for: date)
   // Get the day of the year
   guard let dayInt = calendar.ordinality(of: .day, in: .year, for: date)
   else { return nil }
   let day = Double(dayInt)

   // Convert longitude to hour value and calculate an approx. time
   let lngHour = y / 15

   let hourTime: Double = isSunrise ? 6 : 18
   let t = day + ((hourTime - lngHour) / 24)

   // Calculate the suns mean anomaly
   let M = (0.9856 * t) - 3.289

   // Calculate the sun's true longitude
   let expr1 = 1.916 * sin(M.degreesToRadians)
   let expr2 = 0.020 * sin(2 * M.degreesToRadians)
   // Normalise L into [0, 360] range
   let L = normalise(M + expr1 + expr2 + 282.634, withMaximum: 360)

   // Calculate the Sun's right ascension
   let RA = {
    var RA = atan(0.91764 * tan(L.degreesToRadians)).radiansToDegrees
    
    // Normalise RA into [0, 360] range
    RA = normalise(RA, withMaximum: 360)
    
    // Right ascension value needs to be in the same quadrant as L...
    let Lquadrant = floor(L / 90) * 90
    let RAquadrant = floor(RA / 90) * 90
    RA += (Lquadrant - RAquadrant)
    
    // Convert RA into hours
    return RA / 15
   }()

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

   // No sunrise, No sunset
   guard cosH < 1, cosH > -1 else { return nil }

   // Finish calculating H and convert into hours
   let tempH = isSunrise
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
   lngHour > 0 && UT > 12 && isSunrise
   let shouldBeTomorrow =
   lngHour < 0 && UT < 12 && !isSunrise

   let setDate: Date = if shouldBeYesterday {
    Date(timeInterval: -86400, since: date)
   } else if shouldBeTomorrow {
    Date(timeInterval: 86400, since: date)
   } else {
    date
   }

   var components =
    calendar.dateComponents([.day, .month, .year], from: setDate)
   components.hour = Int(hour)
   components.minute = Int(minute)
   components.second = Int(second)

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
