//
//  KeyManager.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import Security

enum APIProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case azureOpenAI = "Azure OpenAI"
    
    var id: String { self.rawValue }
}

class KeyManager {
    
    enum KeyError: Error {
        case saveFailure
        case readFailure
        case deleteFailure
    }
    
    // Standard OpenAI
    static let openAIApiKeyIdentifier = "com.lucid.openai.apikey"
    static let openAIBaseUrlIdentifier = "com.lucid.openai.baseurl"
    static let defaultOpenAIBaseUrl = "https://api.openai.com/v1"
    
    // Azure OpenAI
    static let apiProviderIdentifier = "com.lucid.api.provider"
    static let azureResourceNameIdentifier = "com.lucid.azure.resourcename"
    static let azureDeploymentIdIdentifier = "com.lucid.azure.deploymentid"
    static let azureApiVersionIdentifier = "com.lucid.azure.apiversion"
    static let defaultAzureApiVersion = "2023-05-15"
    
    // MARK: - API Provider Methods
    
    static func saveAPIProvider(_ provider: APIProvider) {
        UserDefaults.standard.set(provider.rawValue, forKey: apiProviderIdentifier)
    }
    
    static func getAPIProvider() -> APIProvider {
        if let providerString = UserDefaults.standard.string(forKey: apiProviderIdentifier),
           let provider = APIProvider(rawValue: providerString) {
            return provider
        }
        return .openAI
    }
    
    // MARK: - API Key Methods
    
    static func saveAPIKey(_ key: String) throws {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: openAIApiKeyIdentifier,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add the new key data
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeyError.saveFailure
        }
    }
    
    static func getAPIKey() -> String? {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: openAIApiKeyIdentifier,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let retrievedData = dataTypeRef as? Data {
            return String(data: retrievedData, encoding: .utf8)
        } else {
            return nil
        }
    }
    
    static func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: openAIApiKeyIdentifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyError.deleteFailure
        }
    }
    
    static func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
    
    // MARK: - Base URL Methods (OpenAI)
    
    static func saveBaseURL(_ url: String) throws {
        UserDefaults.standard.set(url, forKey: openAIBaseUrlIdentifier)
    }
    
    static func getBaseURL() -> String {
        return UserDefaults.standard.string(forKey: openAIBaseUrlIdentifier) ?? defaultOpenAIBaseUrl
    }
    
    static func resetBaseURL() {
        UserDefaults.standard.removeObject(forKey: openAIBaseUrlIdentifier)
    }
    
    // MARK: - Azure OpenAI Methods
    
    static func saveAzureResourceName(_ name: String) {
        UserDefaults.standard.set(name, forKey: azureResourceNameIdentifier)
    }
    
    static func getAzureResourceName() -> String? {
        return UserDefaults.standard.string(forKey: azureResourceNameIdentifier)
    }
    
    static func saveAzureDeploymentId(_ id: String) {
        UserDefaults.standard.set(id, forKey: azureDeploymentIdIdentifier)
    }
    
    static func getAzureDeploymentId() -> String? {
        return UserDefaults.standard.string(forKey: azureDeploymentIdIdentifier)
    }
    
    static func saveAzureApiVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: azureApiVersionIdentifier)
    }
    
    static func getAzureApiVersion() -> String {
        return UserDefaults.standard.string(forKey: azureApiVersionIdentifier) ?? defaultAzureApiVersion
    }
    
    // MARK: - Reset All Settings
    
    static func resetAllSettings() throws {
        // Reset API key
        try deleteAPIKey()
        
        // Reset all UserDefaults values
        UserDefaults.standard.removeObject(forKey: openAIBaseUrlIdentifier)
        UserDefaults.standard.removeObject(forKey: apiProviderIdentifier)
        UserDefaults.standard.removeObject(forKey: azureResourceNameIdentifier)
        UserDefaults.standard.removeObject(forKey: azureDeploymentIdIdentifier)
        UserDefaults.standard.removeObject(forKey: azureApiVersionIdentifier)
    }
}
