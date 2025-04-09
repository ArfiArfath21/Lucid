//
//  AlarmListView.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import SwiftUI

struct AlarmListView: View {
    @ObservedObject var viewModel: AlarmViewModel
    @State private var showingAddAlarm = false
    @State private var editingAlarm: Alarm?
    
    var body: some View {
        VStack(spacing: 16) {
            // Next alarm display
            if let nextAlarmTime = viewModel.nextAlarmTime {
                NextAlarmView(nextAlarmTime: nextAlarmTime)
            }
            
            List {
                ForEach(viewModel.alarms) { alarm in
                    AlarmRowView(
                        alarm: alarm,
                        isEnabled: alarm.isEnabled,
                        onToggle: { isEnabled in
                            viewModel.toggleAlarm(id: alarm.id, isEnabled: isEnabled)
                        },
                        onTap: {
                            editingAlarm = alarm
                        }
                    )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteAlarm(id: viewModel.alarms[index].id)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            Button(action: {
                showingAddAlarm = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Alarm")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingAddAlarm) {
            NavigationView {
                AlarmEditView(viewModel: viewModel, isPresented: $showingAddAlarm)
                    .navigationTitle("Add Alarm")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            showingAddAlarm = false
                        },
                        trailing: EmptyView()
                    )
            }
        }
        .sheet(item: $editingAlarm) { alarm in
            NavigationView {
                AlarmEditView(viewModel: viewModel, alarm: alarm, isPresented: Binding<Bool>(
                    get: { editingAlarm != nil },
                    set: { if !$0 { editingAlarm = nil } }
                ))
                .navigationTitle("Edit Alarm")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        editingAlarm = nil
                    },
                    trailing: EmptyView()
                )
            }
        }
    }
}

struct NextAlarmView: View {
    let nextAlarmTime: Date
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Next Alarm")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(nextAlarmTimeText)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private var nextAlarmTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let calendar = Calendar.current
        if calendar.isDateInToday(nextAlarmTime) {
            return "Today, \(formatter.string(from: nextAlarmTime))"
        } else if calendar.isDateInTomorrow(nextAlarmTime) {
            return "Tomorrow, \(formatter.string(from: nextAlarmTime))"
        } else {
            formatter.dateFormat = "E, h:mm a"
            return formatter.string(from: nextAlarmTime)
        }
    }
}

struct AlarmRowView: View {
    let alarm: Alarm
    @State var isEnabled: Bool
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeText)
                        .font(.title)
                        .fontWeight(.medium)
                    
                    Text(repeatText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .onChange(of: isEnabled) { oldValue, newValue in
                        onToggle(newValue)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: alarm.time)
    }
    
    private var repeatText: String {
        alarm.repeatPattern.description
    }
}

struct AlarmListView_Previews: PreviewProvider {
    static var previews: some View {
        AlarmListView(viewModel: AlarmViewModel())
    }
}
