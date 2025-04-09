//
//  AlarmViewModel.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import SwiftUI
import Combine

class AlarmViewModel: ObservableObject {
    // Reference to the alarm manager
    private let alarmManager: AlarmManager
    
    // Published properties for the view
    @Published var alarms: [Alarm] = []
    @Published var isAlarmActive: Bool = false
    @Published var activeAlarm: Alarm?
    @Published var currentQuestion: Question?
    @Published var userAnswer: String = ""
    @Published var showAnswerResult: Bool = false
    @Published var isAnswerCorrect: Bool = false
    @Published var sampleQuestion: Question?
    @Published var nextAlarmTime: Date?
    
    // UI state properties
    @Published var showingAddAlarm: Bool = false
    @Published var editingAlarm: Alarm?
    
    // Cancellables for subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(alarmManager: AlarmManager = AlarmManager()) {
        self.alarmManager = alarmManager
        
        // Subscribe to alarm manager changes
        alarmManager.$alarms
            .assign(to: \.alarms, on: self)
            .store(in: &cancellables)
        
        alarmManager.$isAlarmActive
            .assign(to: \.isAlarmActive, on: self)
            .store(in: &cancellables)
        
        alarmManager.$activeAlarm
            .assign(to: \.activeAlarm, on: self)
            .store(in: &cancellables)
        
        alarmManager.$currentQuestion
            .assign(to: \.currentQuestion, on: self)
            .store(in: &cancellables)
        
        // Generate sample question
        sampleQuestion = alarmManager.generateSampleQuestion()
        
        // Setup timer to update next alarm time
        setupNextAlarmTimer()
    }
    
    // MARK: - Public Methods
    
    func addAlarm(time: Date, repeatPattern: RepeatPattern = .once) {
        alarmManager.addAlarm(time: time, repeatPattern: repeatPattern)
        updateNextAlarmTime()
    }
    
    func updateAlarm(alarm: Alarm) {
        alarmManager.updateAlarm(alarm: alarm)
        updateNextAlarmTime()
    }
    
    func deleteAlarm(id: UUID) {
        alarmManager.deleteAlarm(id: id)
        updateNextAlarmTime()
    }
    
    func toggleAlarm(id: UUID, isEnabled: Bool) {
        alarmManager.toggleAlarm(id: id, isEnabled: isEnabled)
        updateNextAlarmTime()
    }
    
    func checkAnswer() {
        let isCorrect = alarmManager.checkAlarmAnswer(userAnswer: userAnswer)
        
        isAnswerCorrect = isCorrect
        showAnswerResult = true
        
        // Reset user answer
        userAnswer = ""
        
        // Hide answer result after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showAnswerResult = false
        }
    }
    
    func useEmergencyOverride() {
        if activeAlarm?.hasOverride == true {
            alarmManager.deactivateAlarm()
        }
    }
    
    func updateNextAlarmTime() {
        nextAlarmTime = alarmManager.getNextAlarmTime()
    }
    
    // For testing the sample question
    func checkSampleAnswer(answer: String) -> Bool {
        guard let question = sampleQuestion else { return false }
        return question.isCorrect(userAnswer: answer)
    }
    
    // Generate a new sample question
    func generateNewSampleQuestion() {
        sampleQuestion = alarmManager.generateSampleQuestion()
    }
    
    // Create test alarm for debugging
    func createTestAlarm() {
        // Create alarm that will trigger 10 seconds from now
        let testTime = Date().addingTimeInterval(10)
        let newAlarm = Alarm(time: testTime, sound: alarmManager.soundManager.getDefaultSound())
        alarmManager.updateAlarm(alarm: newAlarm)
        print("Test alarm created for: \(testTime)")
    }
    
    // MARK: - Private Methods
    
    private func setupNextAlarmTimer() {
        // Update next alarm time immediately
        updateNextAlarmTime()
        
        // Set up a timer to update the next alarm time every minute
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateNextAlarmTime()
            }
            .store(in: &cancellables)
    }
}
