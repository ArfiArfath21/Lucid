//
//  MainView.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = AlarmViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Home tab with clock and alarms
                NavigationView {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 20) {
                                // Top section - Clock (fixed size)
                                AnalogClockView()
                                    .frame(height: 250)
                                    .padding(.top)
                                
                                // Middle section - Add Alarm button
                                Button(action: {
                                    // Show add alarm sheet
                                    viewModel.showingAddAlarm = true
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
                                }
                                .padding(.horizontal)
                                
                                // Alarm list (if any)
                                if !viewModel.alarms.isEmpty {
                                    ForEach(viewModel.alarms) { alarm in
                                        AlarmRowView(
                                            alarm: alarm,
                                            isEnabled: alarm.isEnabled,
                                            onToggle: { isEnabled in
                                                viewModel.toggleAlarm(id: alarm.id, isEnabled: isEnabled)
                                            },
                                            onTap: {
                                                viewModel.editingAlarm = alarm
                                            }
                                        )
                                        .padding(.horizontal)
                                        .background(Color(.systemBackground))
                                        .cornerRadius(10)
                                        .padding(.horizontal)
                                    }
                                }
                                
                            }
                            // Add extra padding at the bottom to prevent tab overlap
                            .padding(.bottom, 20)
                        }
                        .navigationTitle("Lucid")
                        .navigationBarTitleDisplayMode(.inline) // This centers the title
                    }
                }
                .tabItem {
                    Label("Alarm", systemImage: "alarm")
                }
                .tag(0)
                
                // Settings tab
                NavigationView {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
            }
            .edgesIgnoringSafeArea(.bottom) // This helps with tab bar layout
            
            // Overlay active alarm when needed
            if viewModel.isAlarmActive {
                QuestionView(viewModel: viewModel)
                    .transition(.opacity)
                    .zIndex(1) // Ensure it's on top
                    .edgesIgnoringSafeArea(.all) // Make sure it covers everything
            }
        }
        .animation(.easeInOut, value: viewModel.isAlarmActive)
        .sheet(isPresented: $viewModel.showingAddAlarm) {
            NavigationView {
                AlarmEditView(viewModel: viewModel, isPresented: $viewModel.showingAddAlarm)
                    .navigationTitle("Add Alarm")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            viewModel.showingAddAlarm = false
                        },
                        trailing: EmptyView()
                    )
            }
        }
        .sheet(item: $viewModel.editingAlarm) { alarm in
            NavigationView {
                AlarmEditView(viewModel: viewModel, alarm: alarm, isPresented: Binding<Bool>(
                    get: { viewModel.editingAlarm != nil },
                    set: { if !$0 { viewModel.editingAlarm = nil } }
                ))
                .navigationTitle("Edit Alarm")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        viewModel.editingAlarm = nil
                    },
                    trailing: EmptyView()
                )
            }
        }
        .onAppear {
            // Request notification permissions when app first appears
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if !granted {
                    print("Notification permission denied")
                }
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
