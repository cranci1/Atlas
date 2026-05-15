//
//  AtlasDate.swift
//  Atlas
//
//  Created by Francesco on 15/05/26.
//

import Foundation

enum AtlasDate {
    private static let gregorianCalendar = Calendar(identifier: .gregorian)
    private static let posixLocale = Locale(identifier: "en_US_POSIX")
    
    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.locale = posixLocale
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let slashDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.locale = posixLocale
        formatter.timeZone = .current
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    private static let isoDayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.locale = posixLocale
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
    
    private static let isoDayTimeSecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.locale = posixLocale
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    private static let slashDayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.locale = posixLocale
        formatter.timeZone = .current
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()
    
    private static let slashDayTimeSecondsFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.locale = posixLocale
        formatter.timeZone = .current
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter
    }()
    
    private static let italianLongDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = gregorianCalendar
        formatter.locale = Locale(identifier: "it_IT")
        formatter.timeZone = .current
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()
    
    static func parseISODate(_ value: String) -> Date? {
        isoDayFormatter.date(from: value)
    }
    
    static func parseSchoolDate(_ value: String) -> Date? {
        parseISODate(value) ?? slashDayFormatter.date(from: value)
    }
    
    static func parseSchoolDateTime(day: String, time: String) -> Date? {
        let dayPart = day.trimmingCharacters(in: .whitespacesAndNewlines)
        let timePart = time.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !dayPart.isEmpty else { return nil }
        guard !timePart.isEmpty else { return parseSchoolDate(dayPart) }
        
        let dateTime = "\(dayPart) \(timePart)"
        
        return isoDayTimeFormatter.date(from: dateTime)
        ?? isoDayTimeSecondsFormatter.date(from: dateTime)
        ?? slashDayTimeFormatter.date(from: dateTime)
        ?? slashDayTimeSecondsFormatter.date(from: dateTime)
        ?? parseSchoolDate(dayPart)
    }
    
    static func dayKey(from date: Date) -> String {
        isoDayFormatter.string(from: date)
    }
    
    static func italianLongDay(from value: String) -> String {
        guard let date = parseSchoolDate(value) else { return value }
        return italianLongDayFormatter.string(from: date)
    }
}
