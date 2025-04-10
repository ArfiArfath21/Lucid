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
    @AppStorage("preferMultipleChoice") private var preferMultipleChoice: Bool = false
    @AppStorage("useAIValidation") private var useAIValidation: Bool = true
    
    @State private var selectedQuestionTypes: [QuestionType] = QuestionType.allCases
    @State private var showResetConfirmation = false
    @State private var showApiKeySheet = false
    @State private var hasApiKey = false
    @State private var currentProvider: APIProvider = .openAI
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isCheckingConnection = false
    
    enum ConnectionStatus {
        case unknown
        case connected
        case failed(String)
        
        var color: Color {
            switch self {
            case .unknown:
                return .gray
            case .connected:
                return .green
            case .failed:
                return .red
            }
        }
        
        var icon: String {
            switch self {
            case .unknown:
                return "questionmark.circle.fill"
            case .connected:
                return "checkmark.circle.fill"
            case .failed:
                return "xmark.circle.fill"
            }
        }
        
        var description: String {
            switch self {
            case .unknown:
                return "Unknown"
            case .connected:
                return "Connected"
            case .failed(let error):
                return "Failed: \(error)"
            }
        }
    }
    
    var body: some View {
        Form {
            Section(header: Text("AI Features")) {
                HStack {
                    if currentProvider == .openAI {
                        Text("OpenAI API")
                    } else {
                        Text("Azure OpenAI API")
                    }
                    Spacer()
                    if isCheckingConnection {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else if hasApiKey {
                        Image(systemName: connectionStatus.icon)
                            .foregroundColor(connectionStatus.color)
                    }
                    Button(action: {
                        showApiKeySheet = true
                    }) {
                        Text(hasApiKey ? "Configured" : "Configure")
                            .foregroundColor(hasApiKey ? .blue : .blue)
                    }
                }
                
                if case .failed(let errorMessage) = connectionStatus {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
                
                Toggle("Use AI Answer Validation", isOn: $useAIValidation)
                    .onChange(of: useAIValidation) { oldValue, newValue in
                        if newValue && !hasApiKey {
                            // Prompt to set API key if not already set
                            showApiKeySheet = true
                        }
                    }
                
                Toggle("Prefer Multiple-Choice Questions", isOn: $preferMultipleChoice)
                
                Button("Test Connection") {
                    checkAPIConnection()
                }
                .disabled(!hasApiKey || isCheckingConnection)
            }
            
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
                    Text("1.1.1")
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
            checkApiKeyAndProvider()
            
            // Check connection status when view appears
            if hasApiKey {
                checkAPIConnection()
            }
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
        .sheet(isPresented: $showApiKeySheet, onDismiss: {
            // Check API key status again after sheet is dismissed
            checkApiKeyAndProvider()
            
            // Check connection if API key is available
            if hasApiKey {
                checkAPIConnection()
            }
        }) {
            APIKeySetupView(isPresented: $showApiKeySheet)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("APIKeyChanged"))) { _ in
            checkApiKeyAndProvider()
            
            // Check connection if API key is available
            if hasApiKey {
                checkAPIConnection()
            }
        }
    }
    
    private func checkApiKeyAndProvider() {
        hasApiKey = KeyManager.hasAPIKey()
        currentProvider = KeyManager.getAPIProvider()
        
        // If AI validation is enabled but no API key, disable it
        if useAIValidation && !hasApiKey {
            useAIValidation = false
        }
    }
    
    private func checkAPIConnection() {
        guard hasApiKey, let apiKey = KeyManager.getAPIKey() else {
            connectionStatus = .failed("No API key configured")
            return
        }
        
        isCheckingConnection = true
        connectionStatus = .unknown
        
        let service: OpenAIService
        
        if currentProvider == .openAI {
            let baseUrl = KeyManager.getBaseURL()
            service = OpenAIService(apiKey: apiKey, provider: .openAI, baseUrl: baseUrl)
        } else {
            service = OpenAIService(
                apiKey: apiKey,
                provider: .azureOpenAI,
                azureResourceName: KeyManager.getAzureResourceName(),
                azureDeploymentId: KeyManager.getAzureDeploymentId(),
                azureApiVersion: KeyManager.getAzureApiVersion()
            )
        }
        
        Task {
            let result = await service.testConnection()
            
            // Switch back to the main thread
            DispatchQueue.main.async {
                isCheckingConnection = false
                
                switch result {
                case .success:
                    connectionStatus = .connected
                case .failure(let error):
                    connectionStatus = .failed(error.localizedDescription)
                }
            }
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
        preferMultipleChoice = false
        useAIValidation = true
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
