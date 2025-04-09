//
//  AlarmModels.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var id: Int { self.rawValue }
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

enum RepeatPattern: Codable, Equatable, Hashable {
    case once
    case daily
    case weekdays
    case weekends
    case custom([Weekday])
    
    // Add this method to make it properly Hashable
    func hash(into hasher: inout Hasher) {
        switch self {
        case .once:
            hasher.combine(0)
        case .daily:
            hasher.combine(1)
        case .weekdays:
            hasher.combine(2)
        case .weekends:
            hasher.combine(3)
        case .custom(let days):
            hasher.combine(4)
            hasher.combine(days.map { $0.rawValue })
        }
    }
    
    // Add custom equatable implementation to properly compare custom days
    static func == (lhs: RepeatPattern, rhs: RepeatPattern) -> Bool {
        switch (lhs, rhs) {
        case (.once, .once), (.daily, .daily), (.weekdays, .weekdays), (.weekends, .weekends):
            return true
        case (.custom(let lhsDays), .custom(let rhsDays)):
            return lhsDays.sorted(by: { $0.rawValue < $1.rawValue }) ==
                   rhsDays.sorted(by: { $0.rawValue < $1.rawValue })
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .once: return "Once"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .custom(let days):
            if days.isEmpty {
                return "Never"
            } else if days.count == 7 {
                return "Every day"
            } else {
                return days.map { $0.shortName }.joined(separator: ", ")
            }
        }
    }
}

struct Sound: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
}

struct Alarm: Identifiable, Codable {
    var id = UUID()
    var time: Date
    var isEnabled: Bool = true
    var repeatPattern: RepeatPattern = .once
    var sound: Sound
    var questionTypes: [QuestionType] = [.simpleMath, .wordScramble, .readingComprehension, .verbalMath]
    var hasOverride: Bool = false
    
    init(time: Date, sound: Sound) {
        self.time = time
        self.sound = sound
    }
}
