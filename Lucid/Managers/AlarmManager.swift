//
//  AlarmManager.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import UserNotifications
import SwiftUI
import AVFoundation

class AlarmManager: ObservableObject {
    @Published var alarms: [Alarm] = []
    @Published var isAlarmActive: Bool = false
    @Published var activeAlarm: Alarm?
    @Published var currentQuestion: Question?
    
    // Make SoundManager public so ViewModel can access it
    let soundManager = SoundManager()
    private let questionGenerator = QuestionGenerator()
    private let foregroundHelper = ForegroundHelper.shared
    
    private let userDefaultsKey = "LucidAlarmSavedAlarms"
    
    init() {
        loadAlarms()
        setupNotificationHandling()
        
        // Make ourselves available to AppDelegate
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.alarmManager = self
        }
        
        // Listen for app becoming active to check for pending alarms
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Listen for app going to background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appBecameActive() {
        // Check if any alarms should be active when app becomes active
        checkPendingAlarms()
    }
    
    @objc private func appDidEnterBackground() {
        // If we have an active alarm, make sure we keep playing in background
        if isAlarmActive {
            // Wake up the device and try to bring our app to the foreground
            foregroundHelper.bringAppToForeground()
        }
    }
    
    func checkPendingAlarms() {
        // Get current date/time
        let now = Date()
        
        // Check if any alarms should be firing
        for alarm in alarms.filter({ $0.isEnabled }) {
            if let nextOccurrence = calculateNextOccurrence(for: alarm, from: now) {
                // If the next occurrence is within 60 seconds of now, trigger it
                let difference = nextOccurrence.timeIntervalSince(now)
                if difference <= 60 && difference >= -60 {
                    // Activate this alarm - use a local copy to avoid capture warnings
                    let alarmCopy = alarm
                    Task { [weak self] in
                        guard let self = self else { return }
                        await self.activateAlarm(alarm: alarmCopy)
                    }
                    break
                }
            }
        }
    }
    
    private func loadAlarms() {
        if let savedAlarmsData = UserDefaults.standard.data(forKey: userDefaultsKey) {
            if let decodedAlarms = try? JSONDecoder().decode([Alarm].self, from: savedAlarmsData) {
                self.alarms = decodedAlarms
            }
        }
    }
    
    private func saveAlarms() {
        if let encodedData = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
        }
    }
    
    func addAlarm(time: Date, repeatPattern: RepeatPattern = .once) {
        let newAlarm = Alarm(time: time, sound: soundManager.getDefaultSound())
        alarms.append(newAlarm)
        scheduleAlarm(alarm: newAlarm)
        saveAlarms()
    }
    
    func updateAlarm(alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
            
            // Cancel existing notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
            
            // Schedule new notification if alarm is enabled
            if alarm.isEnabled {
                scheduleAlarm(alarm: alarm)
            }
            
            saveAlarms()
        } else {
            // If alarm doesn't exist yet, add it
            alarms.append(alarm)
            if alarm.isEnabled {
                scheduleAlarm(alarm: alarm)
            }
            saveAlarms()
        }
    }
    
    func deleteAlarm(id: UUID) {
        if let index = alarms.firstIndex(where: { $0.id == id }) {
            // Cancel notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
            
            // Remove from array
            alarms.remove(at: index)
            saveAlarms()
        }
    }
    
    func toggleAlarm(id: UUID, isEnabled: Bool) {
        if let index = alarms.firstIndex(where: { $0.id == id }) {
            alarms[index].isEnabled = isEnabled
            
            if isEnabled {
                scheduleAlarm(alarm: alarms[index])
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
            }
            
            saveAlarms()
        }
    }
    
    // MARK: - Alarm Scheduling Methods
    func scheduleAlarm(alarm: Alarm) {
        // Create a local copy to avoid capture warnings
        let alarmCopy = alarm
        
        // Request notification permission if needed
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { [weak self] granted, error in
            if granted {
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.scheduleNotification(for: alarmCopy)
                }
            } else {
                print("Notification permission denied: \(String(describing: error))")
            }
        }
    }
    
    private func scheduleNotification(for alarm: Alarm) {
        let content = UNMutableNotificationContent()
        content.title = "Lucid Alarm"
        content.body = "Time to wake up! Answer a question to dismiss."
        
        // Configure the content for critical alerts using our utility
        NotificationUtils.configureCriticalAlert(content: content)
        
        content.userInfo = ["alarmId": alarm.id.uuidString]
        content.categoryIdentifier = "ALARM_CATEGORY"
        
        // Use critical alerts
        content.interruptionLevel = .critical
        
        // Create calendar components from alarm time
        let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.time)
        
        // Create trigger
        var trigger: UNNotificationTrigger
        
        switch alarm.repeatPattern {
        case .once:
            // For a one-time alarm, we need date components including year, month, day
            let fullComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alarm.time)
            trigger = UNCalendarNotificationTrigger(dateMatching: fullComponents, repeats: false)
            
        case .daily:
            // For daily alarms, we only need hour and minute
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            
        case .weekdays:
            // For weekday alarms, we need to schedule 5 different notifications (Mon-Fri)
            scheduleWeekdayAlarms(alarm: alarm, components: components)
            return
            
        case .weekends:
            // For weekend alarms, we need to schedule 2 different notifications (Sat-Sun)
            scheduleWeekendAlarms(alarm: alarm, components: components)
            return
            
        case .custom(let days):
            // For custom day alarms, schedule one notification per selected day
            scheduleCustomDayAlarms(alarm: alarm, components: components, days: days)
            return
        }
        
        // Create request
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
        
        // Add request to notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Scheduled alarm successfully for \(alarm.time)")
            }
        }
    }
    
    // The following scheduling methods remain unchanged from the original implementation
    private func scheduleWeekdayAlarms(alarm: Alarm, components: DateComponents) {
        let weekdays = [2, 3, 4, 5, 6] // Monday = 2, ..., Friday = 6
        scheduleAlarmsForDays(alarm: alarm, components: components, weekdays: weekdays)
    }
    
    private func scheduleWeekendAlarms(alarm: Alarm, components: DateComponents) {
        let weekends = [1, 7] // Sunday = 1, Saturday = 7
        scheduleAlarmsForDays(alarm: alarm, components: components, weekdays: weekends)
    }
    
    private func scheduleCustomDayAlarms(alarm: Alarm, components: DateComponents, days: [Weekday]) {
        let weekdays = days.map { $0.rawValue }
        scheduleAlarmsForDays(alarm: alarm, components: components, weekdays: weekdays)
    }
    
    private func scheduleAlarmsForDays(alarm: Alarm, components: DateComponents, weekdays: [Int]) {
        let content = UNMutableNotificationContent()
        content.title = "Lucid Alarm"
        content.body = "Time to wake up! Answer a question to dismiss."
        content.sound = UNNotificationSound.defaultCritical
        content.userInfo = ["alarmId": alarm.id.uuidString]
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.interruptionLevel = .critical
        
        for weekday in weekdays {
            // Create date components with the specified weekday
            var dayComponents = components
            dayComponents.weekday = weekday
            
            // Create trigger
            let trigger = UNCalendarNotificationTrigger(dateMatching: dayComponents, repeats: true)
            
            // Create a unique identifier for each weekday notification
            let identifier = "\(alarm.id.uuidString)-\(weekday)"
            
            // Create request
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // Add request to notification center
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                } else {
                    print("Scheduled weekday alarm for day \(weekday)")
                }
            }
        }
    }
    
    func cancelAlarm(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
    
    func isAlarmSet(id: UUID) -> Bool {
        if let alarm = alarms.first(where: { $0.id == id }) {
            return alarm.isEnabled
        }
        return false
    }
    
    func getNextAlarmTime() -> Date? {
        let enabledAlarms = alarms.filter { $0.isEnabled }
        guard !enabledAlarms.isEmpty else { return nil }
        
        let now = Date()
        var nextAlarmDate: Date?
        
        for alarm in enabledAlarms {
            let nextOccurrence = calculateNextOccurrence(for: alarm, from: now)
            
            if let next = nextOccurrence {
                if nextAlarmDate == nil || next < nextAlarmDate! {
                    nextAlarmDate = next
                }
            }
        }
        
        return nextAlarmDate
    }
    
    private func calculateNextOccurrence(for alarm: Alarm, from date: Date) -> Date? {
        let calendar = Calendar.current
        
        // Extract hour and minute from alarm time
        let components = calendar.dateComponents([.hour, .minute], from: alarm.time)
        let hour = components.hour!
        let minute = components.minute!
        
        // Create a date for today with the alarm's time
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        todayComponents.hour = hour
        todayComponents.minute = minute
        todayComponents.second = 0
        
        let todayDate = calendar.date(from: todayComponents)!
        
        switch alarm.repeatPattern {
        case .once:
            // For one-time alarms, return the alarm time if it's in the future
            return todayDate > date ? todayDate : nil
            
        case .daily:
            // For daily alarms, return today's time if it's in the future, otherwise tomorrow
            if todayDate > date {
                return todayDate
            } else {
                return calendar.date(byAdding: .day, value: 1, to: todayDate)
            }
            
        case .weekdays:
            // For weekday alarms, find the next weekday
            return findNextOccurrence(for: todayDate, from: date, weekdays: [2, 3, 4, 5, 6])
            
        case .weekends:
            // For weekend alarms, find the next weekend day
            return findNextOccurrence(for: todayDate, from: date, weekdays: [1, 7])
            
        case .custom(let days):
            // For custom alarms, find the next day from the custom days
            let weekdays = days.map { $0.rawValue }
            return findNextOccurrence(for: todayDate, from: date, weekdays: weekdays)
        }
    }
    
    private func findNextOccurrence(for baseDate: Date, from currentDate: Date, weekdays: [Int]) -> Date? {
        let calendar = Calendar.current
        
        // If base date is in the future and its weekday is in the list, return it
        if baseDate > currentDate {
            let weekday = calendar.component(.weekday, from: baseDate)
            if weekdays.contains(weekday) {
                return baseDate
            }
        }
        
        // Check the next 7 days
        for dayOffset in 0..<7 {
            let nextDay = calendar.date(byAdding: .day, value: dayOffset, to: baseDate)!
            let weekday = calendar.component(.weekday, from: nextDay)
            
            if weekdays.contains(weekday) && nextDay > currentDate {
                return nextDay
            }
        }
        
        return nil
    }
    
    // MARK: - Alarm Activation Methods
    
    func activateAlarm(alarm: Alarm) async {
        // Only activate if not already active
        if !isAlarmActive {
            // Ensure the app is in foreground by using ForegroundHelper
            foregroundHelper.bringAppToForeground()
            
            // Play the alarm sound first (don't wait for question generation)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.activeAlarm = alarm
                self.isAlarmActive = true
                self.soundManager.playAlarmSound(sound: alarm.sound)
                print("Alarm activated: \(alarm.time)")
            }
            
            // Generate a question asynchronously
            let question = await questionGenerator.generateRandomQuestion(from: alarm.questionTypes)
            
            // Update the UI on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentQuestion = question
            }
        }
    }
    
    func deactivateAlarm() {
        isAlarmActive = false
        activeAlarm = nil
        currentQuestion = nil
        
        // Stop the alarm sound
        soundManager.stopAlarmSound()
        
        // Release foreground state
        foregroundHelper.releaseAlarmState()
        
        print("Alarm deactivated")
    }
    
    func checkAlarmAnswer(userAnswer: String) async -> Bool {
        guard let question = currentQuestion else { return false }
        
        // Store reference to active alarm to avoid capture issues
        let currentActiveAlarm = activeAlarm
        let questionTypes = currentActiveAlarm?.questionTypes ?? [.simpleMath]
        
        // Use OpenAI to validate the answer
        let isCorrect = await questionGenerator.checkAnswer(question: question, userAnswer: userAnswer)
        
        if isCorrect {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.deactivateAlarm()
            }
        } else {
            // Generate a new question
            let newQuestion = await questionGenerator.generateRandomQuestion(from: questionTypes)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.currentQuestion = newQuestion
            }
        }
        
        return isCorrect
    }
    
    // MARK: - Notification Handling
    
    private func setupNotificationHandling() {
        // Set up notification categories and actions
        let answerAction = UNNotificationAction(
            identifier: "ANSWER_ACTION",
            title: "Answer Question",
            options: .foreground
        )
        
        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM_CATEGORY",
            actions: [answerAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([alarmCategory])
        
        // Set up foreground notification handling
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAlarmNotification),
            name: Notification.Name("AlarmFired"),
            object: nil
        )
    }
    
    @objc private func handleAlarmNotification(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let alarmIdString = userInfo["alarmId"] as? String,
           let alarmId = UUID(uuidString: alarmIdString),
           let alarm = alarms.first(where: { $0.id == alarmId }) {
            
            // Activate the alarm - store a local copy to avoid capture warnings
            let alarmCopy = alarm
            Task { [weak self] in
                guard let self = self else { return }
                await self.activateAlarm(alarm: alarmCopy)
            }
        }
    }
    
    // Generate a sample question for the main screen
    func generateSampleQuestion() -> Question {
        return questionGenerator.generateSampleQuestion()
    }
}
