//
//  AlarmEditView.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import SwiftUI

struct AlarmEditView: View {
    @ObservedObject var viewModel: AlarmViewModel
    @Binding var isPresented: Bool
    
    @State private var alarmTime: Date
    @State private var isEnabled: Bool
    @State private var repeatPattern: RepeatPattern
    @State private var sound: Sound
    @State private var hasOverride: Bool
    @State private var selectedQuestionTypes: [QuestionType]
    @State private var showCustomDayPicker = false
    @State private var customDays: [Weekday] = []
    
    private var isEditing: Bool
    private var editingAlarmId: UUID?
    
    // Create new alarm
    init(viewModel: AlarmViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        
        let soundManager = SoundManager()
        let defaultSound = soundManager.getDefaultSound()
        
        self._alarmTime = State(initialValue: Date())
        self._isEnabled = State(initialValue: true)
        self._repeatPattern = State(initialValue: .once)
        self._sound = State(initialValue: defaultSound)
        self._hasOverride = State(initialValue: false)
        self._selectedQuestionTypes = State(initialValue: QuestionType.allCases)
        
        self.isEditing = false
        self.editingAlarmId = nil
    }
    
    // Edit existing alarm
    init(viewModel: AlarmViewModel, alarm: Alarm, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        
        self._alarmTime = State(initialValue: alarm.time)
        self._isEnabled = State(initialValue: alarm.isEnabled)
        self._repeatPattern = State(initialValue: alarm.repeatPattern)
        self._sound = State(initialValue: alarm.sound)
        self._hasOverride = State(initialValue: alarm.hasOverride)
        self._selectedQuestionTypes = State(initialValue: alarm.questionTypes)
        
        self.isEditing = true
        self.editingAlarmId = alarm.id
        
        // Initialize custom days if using a custom repeat pattern
        if case .custom(let days) = alarm.repeatPattern {
            self._customDays = State(initialValue: days)
        }
    }
    
    var body: some View {
        Form {
            // Time picker section
            Section(header: Text("Time")) {
                DatePicker("", selection: $alarmTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Repeat section
            Section(header: Text("Repeat")) {
                Picker("Repeat", selection: $repeatPattern) {
                    Text("Once").tag(RepeatPattern.once)
                    Text("Daily").tag(RepeatPattern.daily)
                    Text("Weekdays").tag(RepeatPattern.weekdays)
                    Text("Weekends").tag(RepeatPattern.weekends)
                    Text("Custom").tag(RepeatPattern.custom(customDays))
                }
                .onChange(of: repeatPattern) { oldValue, newValue in
                    if case .custom = newValue {
                        showCustomDayPicker = true
                    }
                }
                
                if case .custom = repeatPattern {
                    NavigationLink(destination: CustomDayPickerView(selectedDays: $customDays, repeatPattern: $repeatPattern)) {
                        HStack {
                            Text("Custom Days")
                            Spacer()
                            Text(customDaysDescription)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Sounds section
            Section(header: Text("Sound")) {
                let soundManager = SoundManager()
                let sounds = soundManager.getAvailableSounds()
                
                Picker("Sound", selection: $sound) {
                    ForEach(sounds) { sound in
                        Text(sound.name).tag(sound)
                    }
                }
            }
            
            // Question types section
            Section(header: Text("Question Types")) {
                ForEach(QuestionType.allCases) { questionType in
                    Toggle(questionType.rawValue, isOn: Binding(
                        get: { selectedQuestionTypes.contains(questionType) },
                        set: { isSelected in
                            if isSelected {
                                if !selectedQuestionTypes.contains(questionType) {
                                    selectedQuestionTypes.append(questionType)
                                }
                            } else {
                                selectedQuestionTypes.removeAll { $0 == questionType }
                                
                                // Ensure at least one question type is selected
                                if selectedQuestionTypes.isEmpty {
                                    selectedQuestionTypes = [.simpleMath]
                                }
                            }
                        }
                    ))
                }
            }
            
            // Hidden section for emergency override
            Section(footer: Text("Allows alarm to be dismissed without answering questions")) {
                HStack {
                    Text("Emergency Override")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                    Toggle("", isOn: $hasOverride)
                        .labelsHidden()
                }
            }
            
            // Save button
            Section {
                Button(action: saveAlarm) {
                    Text("Save Alarm")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fontWeight(.semibold)
                }
            }
            
            // Delete button (only for editing)
            if isEditing, let id = editingAlarmId {
                Section {
                    Button(action: {
                        viewModel.deleteAlarm(id: id)
                        isPresented = false
                    }) {
                        Text("Delete Alarm")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }
    
    private var customDaysDescription: String {
        if customDays.isEmpty {
            return "None"
        } else {
            return customDays.map { $0.shortName }.joined(separator: ", ")
        }
    }
    
    private func saveAlarm() {
        // Make sure we have at least one question type selected
        if selectedQuestionTypes.isEmpty {
            selectedQuestionTypes = [.simpleMath]
        }
        
        // Update repeat pattern with current custom days if necessary
        if case .custom = repeatPattern {
            repeatPattern = .custom(customDays)
        }
        
        if isEditing, let id = editingAlarmId {
            // Update existing alarm
            var updatedAlarm = viewModel.alarms.first(where: { $0.id == id })!
            updatedAlarm.time = alarmTime
            updatedAlarm.isEnabled = isEnabled
            updatedAlarm.repeatPattern = repeatPattern
            updatedAlarm.sound = sound
            updatedAlarm.questionTypes = selectedQuestionTypes
            updatedAlarm.hasOverride = hasOverride
            
            viewModel.updateAlarm(alarm: updatedAlarm)
        } else {
            // Create new alarm with current settings
            var newAlarm = Alarm(time: alarmTime, sound: sound)
            newAlarm.isEnabled = isEnabled
            newAlarm.repeatPattern = repeatPattern
            newAlarm.questionTypes = selectedQuestionTypes
            newAlarm.hasOverride = hasOverride
            
            viewModel.updateAlarm(alarm: newAlarm)
        }
        
        isPresented = false
    }
}

struct CustomDayPickerView: View {
    @Binding var selectedDays: [Weekday]
    @Binding var repeatPattern: RepeatPattern
    
    var body: some View {
        List {
            ForEach(Weekday.allCases) { day in
                Button(action: {
                    if selectedDays.contains(day) {
                        selectedDays.removeAll { $0 == day }
                    } else {
                        selectedDays.append(day)
                    }
                    repeatPattern = .custom(selectedDays)
                }) {
                    HStack {
                        Text(dayName(day))
                        Spacer()
                        if selectedDays.contains(day) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Select Days")
    }
    
    private func dayName(_ day: Weekday) -> String {
        switch day {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}
