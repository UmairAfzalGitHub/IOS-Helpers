
import Foundation

public extension Date {
    
    static var calendar: Calendar = {
        return Calendar(identifier: .gregorian)
    }()
    
    var weekday: Int {
        return Calendar.current.component(.weekday, from: self)
    }
    
    var firstDayOfTheMonth: Date {
        return Calendar.current.date(from: Calendar.current.dateComponents([.year,.month], from: self))!
    }
    
    var monthMedium: String  { return Formatter.monthMedium.string(from: self) }
    var hour12:  String      { return Formatter.hour12.string(from: self) }
    var minute0x: String     { return Formatter.minute0x.string(from: self) }
    var amPM: String         { return Formatter.amPM.string(from: self) }
    
    /// Returns the amount of years from another date
    func years(from date: Date) -> Int {
        return Calendar.current.dateComponents([.year], from: date, to: self).year ?? 0
    }
    
    /// Returns the amount of months from another date
    func months(from date: Date) -> Int {
        return Calendar.current.dateComponents([.month], from: date, to: self).month ?? 0
    }
    
    /// Returns the amount of weeks from another date
    func weeks(from date: Date) -> Int {
        return Calendar.current.dateComponents([.weekOfMonth], from: date, to: self).weekOfMonth ?? 0
    }
    
    /// Returns the amount of days from another date
    func days(from date: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }
    
    /// Returns the amount of hours from another date
    func hours(from date: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: date, to: self).hour ?? 0
    }
    
    /// Returns the amount of minutes from another date
    func minutes(from date: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0
    }
    
    /// Returns the amount of seconds from another date
    func seconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
    
    func interval(of component: Calendar.Component, from date: Date) -> Int {
        let calendar = Calendar.current
        guard let start = calendar.ordinality(of: component, in: .era, for: date) else { return 0 }
        guard let end = calendar.ordinality(of: component, in: .era, for: self) else { return 0 }
        
        return end - start
    }
    
    /// Returns the a custom time interval description from another date
    func offset(from date: Date) -> String {
        if years(from: date)   > 0 { return "\(years(from: date))y"   }
        if months(from: date)  > 0 { return "\(months(from: date))M"  }
        if weeks(from: date)   > 0 { return "\(weeks(from: date))w"   }
        if days(from: date)    > 0 { return "\(days(from: date))d"    }
        if hours(from: date)   > 0 { return "\(hours(from: date))h"   }
        if minutes(from: date) > 0 { return "\(minutes(from: date))m" }
        if seconds(from: date) > 0 { return "\(seconds(from: date))s" }
        return ""
    }
    
    /// Returns the date in string formate
    func toString() -> String {
        let chatDateFormatter = DateFormatter()
        chatDateFormatter.dateFormat = "dd MMM, hh:mm a"
        return chatDateFormatter.string(from: self)
    }
    
    func toISO8601() -> String {
        iso8601WithMillisecondsFormatter.string(from: self)
    }
    
    func toMMDDYYYY() -> String {
        mmddyyyy.string(from: self)
    }
    
    func toYYYYMMDD() -> String {
        sharedDateFormatter.string(from: self)
    }
    
    
    func toYYYYMMDDSS() -> String {
        yymmddhhss.string(from: self)
    }
    
    func toHhma() -> String {
        hhmma.string(from: self)
    }
    
    func toHhmmaGMT() -> String {
        hhmmaGMT.string(from: self)
    }
    
    func toEEE() -> String {
        eee.string(from: self)
    }
    
    func tommddyyyyhhmma() -> String {
        mmddyyyyhhmma.string(from: self)
    }
    
    func tommddyyyyhhmmaEastren() -> String? {
        mmddyyyyhhmmaEastren.string(from: self)
    }
    
    
    // Function to convert a UTC Date object to the local timezone
    func toLocal() -> Date? {
        // Get the local time zone
        let timeZone = Foundation.TimeZone.current
        let calendar = Calendar.current
        
        // Convert the UTC date to the local time zone
        let localDate = calendar.date(byAdding: .second, value: timeZone.secondsFromGMT(for: self), to: self)
        
        // Return the local date
        return localDate
    }
    
    /// Returns true if the given date is a weekEnd e.g Sat, Sun
    func isWeekend() -> Bool {
        return Date.calendar.isDateInWeekend(self)
    }
    
    static func dayNameFromDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    /// Returns name of the month, Month number should start from 0
    static func monthNameFromMonthNumber(monthNumber: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM"
        return dateFormatter.monthSymbols[monthNumber]
    }
    
    var startOfWeek: Date? {
        let gregorian = Calendar(identifier: .gregorian)
        guard let sunday = gregorian.date(from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)) else { return nil }
        return gregorian.date(byAdding: .day, value: 1, to: sunday)
    }
    
    var endOfWeek: Date? {
        let gregorian = Calendar(identifier: .gregorian)
        guard let sunday = gregorian.date(from: gregorian.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)) else { return nil }
        return gregorian.date(byAdding: .day, value: 7, to: sunday)
    }
    
    static func compareDate(date1:Date, date2:Date) -> Bool {
        let order = NSCalendar.current.compare(date1, to: date2, toGranularity: .day)
        switch order {
        case .orderedSame:
            return true
        default:
            return false
        }
    }
}

let iso8601WithMillisecondsFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    formatter.timeZone = Foundation.TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

let sharedDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = Foundation.TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

let mmddyyyy: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd-yyyy"
    formatter.timeZone = Foundation.TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

let eee: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    formatter.timeZone = Foundation.TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()


let mmddyyyyhhmma: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd-yyyy hh:mm a"
    formatter.timeZone = Foundation.TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

let mmddyyyyhhmmaEastren: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd-yyyy hh:mm a"
    formatter.timeZone = Foundation.TimeZone(identifier: "America/New_York")
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

let hhmma: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "hh:mm a"
    formatter.timeZone = Foundation.TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()


let hhmmaGMT: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "hh:mm a"
    if #available(iOS 16, *) {
        formatter.timeZone = Foundation.TimeZone.gmt
    } else {
        formatter.timeZone = Foundation.TimeZone.current
    }
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()


let yymmddhha: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd hh:mm a"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

let yymmddhhss: DateFormatter = {
    let formatter = DateFormatter()
    if #available(iOS 16, *) {
        formatter.timeZone = Foundation.TimeZone.gmt
    } else {
        formatter.timeZone = Foundation.TimeZone.current
    }
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

