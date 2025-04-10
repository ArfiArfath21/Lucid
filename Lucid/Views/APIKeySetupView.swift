//
//  APIKeySetupView.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import SwiftUI

struct APIKeySetupView: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = ""
    @State private var baseUrl: String = ""
    @State private var selectedProvider: APIProvider = .openAI
    @State private var azureResourceName: String = ""
    @State private var azureDeploymentId: String = ""
    @State private var azureApiVersion: String = ""
    @State private var showKey: Bool = false
    @State private var isSaving: Bool = false
    @State private var isValidating: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage: Bool = false
    
    // Load any existing API key
    private var existingKeyAvailable: Bool {
        return KeyManager.hasAPIKey()
    }
    
    var body: some View {
        NavigationView {
            Form {
                // API Provider Section
                Section(header: Text("API Provider")) {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(APIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // URL Configuration Section - Changes based on provider
                if selectedProvider == .openAI {
                    Section(header: Text("OpenAI Base URL")) {
                        TextField("Base URL", text: $baseUrl)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                        
                        Button("Reset to Default URL") {
                            baseUrl = KeyManager.defaultOpenAIBaseUrl
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
                    }
                } else {
                    Section(header: Text("Azure OpenAI Configuration")) {
                        TextField("Resource Name", text: $azureResourceName)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.URL)
                        
                        TextField("Deployment ID", text: $azureDeploymentId)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("API Version (optional)", text: $azureApiVersion)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
                
                // API Key Section
                Section(header: Text("API Key")) {
                    if showKey {
                        TextField("API Key", text: $apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.password)
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.password)
                    }
                    
                    Toggle("Show API Key", isOn: $showKey)
                    
                    Link(selectedProvider == .openAI ? "Get API Key from OpenAI" : "Get API Key from Azure",
                         destination: URL(string: selectedProvider == .openAI
                                          ? "https://platform.openai.com/api-keys"
                                          : "https://portal.azure.com/#blade/HubsExtension/BrowseResourceBlade/resourceType/Microsoft.CognitiveServices%2Faccounts")!)
                        .foregroundColor(.blue)
                        .font(.footnote)
                }
                
                if isValidating {
                    Section {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("  Testing connection...")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if existingKeyAvailable {
                    Section {
                        Button(action: {
                            removeKey()
                        }) {
                            Text("Remove API Key and Settings")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                
                if showSuccessMessage {
                    Section {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Settings saved successfully!")
                                .foregroundColor(.green)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("AI API Settings")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button(action: {
                    saveSettings()
                }) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Save")
                            .bold()
                    }
                }
                .disabled(apiKey.isEmpty || isSaving || isValidating)
            )
            .onAppear {
                // Load existing settings
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        // Load API provider
        selectedProvider = KeyManager.getAPIProvider()
        
        // Load provider-specific settings
        if selectedProvider == .openAI {
            baseUrl = KeyManager.getBaseURL()
        } else {
            azureResourceName = KeyManager.getAzureResourceName() ?? ""
            azureDeploymentId = KeyManager.getAzureDeploymentId() ?? ""
            azureApiVersion = KeyManager.getAzureApiVersion()
        }
        
        // Load API key
        if existingKeyAvailable && apiKey.isEmpty {
            apiKey = "••••••••••••••••••••••••"
        }
    }
    
    private func saveSettings() {
        errorMessage = nil
        isSaving = true
        
        // If the user hasn't changed the placeholder asterisks, don't overwrite the existing key
        let shouldSaveKey = !(apiKey == "••••••••••••••••••••••••" && existingKeyAvailable)
        
        // Validate settings based on provider
        if !validateSettings() {
            isSaving = false
            return
        }
        
        // Basic API key validation
        if shouldSaveKey {
            if apiKey.isEmpty {
                errorMessage = "API Key cannot be empty"
                isSaving = false
                return
            }
            
            // Different validation based on provider
            if selectedProvider == .openAI && !apiKey.hasPrefix("sk-") {
                errorMessage = "OpenAI API keys typically start with 'sk-'"
                isSaving = false
                return
            }
        }
        
        // Test the connection before saving
        testConnection(shouldSaveKey: shouldSaveKey)
    }
    
    private func validateSettings() -> Bool {
        // Save the API provider first
        KeyManager.saveAPIProvider(selectedProvider)
        
        switch selectedProvider {
        case .openAI:
            return validateOpenAISettings()
        case .azureOpenAI:
            return validateAzureSettings()
        }
    }
    
    private func validateOpenAISettings() -> Bool {
        // Check if the URL is empty
        if baseUrl.isEmpty {
            baseUrl = KeyManager.defaultOpenAIBaseUrl
            return true
        }
        
        // Basic URL validation
        if !baseUrl.hasPrefix("http://") && !baseUrl.hasPrefix("https://") {
            errorMessage = "Base URL must start with http:// or https://"
            return false
        }
        
        // Check if it's a valid URL
        if URL(string: baseUrl) == nil {
            errorMessage = "Invalid Base URL format"
            return false
        }
        
        // Remove trailing slash if present
        if baseUrl.hasSuffix("/") {
            baseUrl = String(baseUrl.dropLast())
        }
        
        // Save the validated base URL
        try? KeyManager.saveBaseURL(baseUrl)
        return true
    }
    
    private func validateAzureSettings() -> Bool {
        // Check that resource name is provided
        if azureResourceName.isEmpty {
            errorMessage = "Resource Name is required for Azure OpenAI"
            return false
        }
        
        // Check that deployment ID is provided
        if azureDeploymentId.isEmpty {
            errorMessage = "Deployment ID is required for Azure OpenAI"
            return false
        }
        
        // For API version, use default if not provided
        if azureApiVersion.isEmpty {
            azureApiVersion = KeyManager.defaultAzureApiVersion
        }
        
        // Save Azure settings
        KeyManager.saveAzureResourceName(azureResourceName)
        KeyManager.saveAzureDeploymentId(azureDeploymentId)
        KeyManager.saveAzureApiVersion(azureApiVersion)
        
        return true
    }
    
    private func testConnection(shouldSaveKey: Bool) {
        isValidating = true
        
        // Create test key and URL for validation
        let testKey = shouldSaveKey ? apiKey : KeyManager.getAPIKey() ?? ""
        
        // Create a temporary service for testing with the appropriate configuration
        let service: OpenAIService
        
        if selectedProvider == .openAI {
            service = OpenAIService(
                apiKey: testKey,
                provider: .openAI,
                baseUrl: baseUrl
            )
        } else {
            service = OpenAIService(
                apiKey: testKey,
                provider: .azureOpenAI,
                azureResourceName: azureResourceName,
                azureDeploymentId: azureDeploymentId,
                azureApiVersion: azureApiVersion
            )
        }
        
        Task {
            let result = await service.testConnection()
            
            // Back to the main thread
            DispatchQueue.main.async {
                isValidating = false
                
                switch result {
                case .success:
                    // Connection successful, save settings
                    saveValidatedSettings(shouldSaveKey: shouldSaveKey)
                case .failure(let error):
                    errorMessage = "Connection test failed: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
    
    private func saveValidatedSettings(shouldSaveKey: Bool) {
        do {
            // Save API key if needed
            if shouldSaveKey {
                try KeyManager.saveAPIKey(apiKey)
            }
            
            // Show success briefly before dismissing
            showSuccessMessage = true
            
            // Notify any components that depend on these settings
            NotificationCenter.default.post(
                name: Notification.Name("APIKeyChanged"),
                object: nil
            )
            
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isSaving = false
                isPresented = false
            }
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            isSaving = false
        }
    }
    
    private func removeKey() {
        do {
            try KeyManager.resetAllSettings()
            apiKey = ""
            baseUrl = KeyManager.defaultOpenAIBaseUrl
            azureResourceName = ""
            azureDeploymentId = ""
            azureApiVersion = ""
            selectedProvider = .openAI
            
            // Notify any components that depend on these settings
            NotificationCenter.default.post(
                name: Notification.Name("APIKeyChanged"),
                object: nil
            )
            
            // Show confirmation
            showSuccessMessage = true
            errorMessage = nil
            
            // Hide the success message after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSuccessMessage = false
            }
        } catch {
            errorMessage = "Failed to remove settings: \(error.localizedDescription)"
        }
    }
}

struct APIKeySetupView_Previews: PreviewProvider {
    static var previews: some View {
        APIKeySetupView(isPresented: .constant(true))
    }
}
