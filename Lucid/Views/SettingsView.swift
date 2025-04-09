//
//  SettingsView.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultQuestionTypes") private var defaultQuestionTypesData: Data = Data()
    @AppStorage("defaultHasOverride") private var defaultHasOverride: Bool = false
    
    @State private var selectedQuestionTypes: [QuestionType] = QuestionType.allCases
    @State private var showResetConfirmation = false
    
    var body: some View {
        Form {
            Section(header: Text("Default Question Types")) {
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
                            saveDefaultQuestionTypes()
                        }
                    ))
                }
            }
            
            // Space filler to push override to bottom
            Section(header: Text("App Information")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://example.com/privacy")!) {
                    Text("Privacy Policy")
                }
                
                Link(destination: URL(string: "https://example.com/terms")!) {
                    Text("Terms of Service")
                }
            }
            
            Section {
                Button(action: {
                    showResetConfirmation = true
                }) {
                    Text("Reset All Settings")
                        .foregroundColor(.red)
                }
            }
            
            // Hidden section
            Section(footer: Text("The emergency override allows you to disable an alarm without answering questions. Use only in true emergencies.").font(.caption)) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Emergency Override")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Toggle("Make override available by default", isOn: $defaultHasOverride)
                        .onChange(of: defaultHasOverride) {
                            // Default value is saved automatically through @AppStorage
                        }
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            loadDefaultQuestionTypes()
        }
        .alert(isPresented: $showResetConfirmation) {
            Alert(
                title: Text("Reset Settings"),
                message: Text("Are you sure you want to reset all settings to default values?"),
                primaryButton: .destructive(Text("Reset")) {
                    resetToDefaults()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func loadDefaultQuestionTypes() {
        if let savedTypes = try? JSONDecoder().decode([QuestionType].self, from: defaultQuestionTypesData) {
            selectedQuestionTypes = savedTypes
        } else {
            selectedQuestionTypes = QuestionType.allCases
            saveDefaultQuestionTypes()
        }
    }
    
    private func saveDefaultQuestionTypes() {
        if let encodedData = try? JSONEncoder().encode(selectedQuestionTypes) {
            defaultQuestionTypesData = encodedData
        }
    }
    
    private func resetToDefaults() {
        selectedQuestionTypes = QuestionType.allCases
        defaultHasOverride = false
        saveDefaultQuestionTypes()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
    }
}
