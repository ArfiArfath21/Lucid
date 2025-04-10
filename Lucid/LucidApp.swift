//
//  LucidApp.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import SwiftUI
import AVFoundation
import UIKit
import UserNotifications

@main
struct LucidApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // Configure app for audio background mode
        setupAudioSession()
        
        // Configure appearance
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(from: oldPhase, to: newPhase)
                }
        }
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session for background playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Register for audio interruption notifications
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main) { notification in
                    guard let info = notification.userInfo,
                          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                        return
                    }
                    
                    // Handle interruption end - resume audio if needed
                    if type == .ended {
                        try? AVAudioSession.sharedInstance().setActive(true)
                    }
                }
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    private func configureAppearance() {
        // Configure UI appearance
        UINavigationBar.appearance().tintColor = .systemBlue
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            print("App became active")
            // Ensure audio session is active again when app returns to foreground
            try? AVAudioSession.sharedInstance().setActive(true)
            
        case .background:
            print("App went to background")
            // Nothing to do here since our audio session is configured to continue in background
            
        case .inactive:
            print("App became inactive")
            
        @unknown default:
            print("Unknown scene phase change")
        }
    }
}
