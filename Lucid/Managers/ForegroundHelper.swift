//
//  ForegroundHelper.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import UIKit
import AVFoundation

class ForegroundHelper {
    static let shared = ForegroundHelper()
    
    private var window: UIWindow?
    private var alarmActiveWindow: UIWindow?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private init() {}
    
    // Call this when an alarm is triggered
    func bringAppToForeground() {
        // Begin background task to keep app running
        beginBackgroundTask()
        
        // Make sure our app is playing audio to keep the app running
        ensureAudioSessionActive()
        
        // Create a local notification to try to wake the device if locked
        createWakeUpNotification()
        
        // On the main thread, ensure we create our top-level window if needed
        DispatchQueue.main.async { [weak self] in
            self?.createAlarmActiveWindow()
        }
    }
    
    // Call this when an alarm is dismissed
    func releaseAlarmState() {
        // Remove our custom window
        if alarmActiveWindow != nil {
            DispatchQueue.main.async { [weak self] in
                self?.alarmActiveWindow?.isHidden = true
                self?.alarmActiveWindow = nil
            }
        }
        
        // End background task
        endBackgroundTask()
    }
    
    private func createAlarmActiveWindow() {
        // Only create window if it doesn't exist
        guard alarmActiveWindow == nil else { return }
        
        // Get the scene
        if let windowScene = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .first {
            
            // Create window at a higher level than normal windows
            let window = UIWindow(windowScene: windowScene)
            window.windowLevel = .alert + 1 // Higher than alerts
            window.backgroundColor = .clear
            
            // Create a simple view controller with a transparent background
            // that passes touches through to underlying windows
            let viewController = UIViewController()
            viewController.view.backgroundColor = .clear
            viewController.view.isUserInteractionEnabled = false
            window.rootViewController = viewController
            
            // Save reference and make visible
            self.alarmActiveWindow = window
            window.isHidden = false
            
            // Ensure our regular app window is the key window
            if let appDelegate = UIApplication.shared.delegate,
               let appWindow = appDelegate.window as? UIWindow {
                appWindow.makeKey()
            }
        }
    }
    
    private func createWakeUpNotification() {
        // Create a local notification to buzz the device
        let notificationCenter = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Lucid Alarm"
        content.body = "Wake Up! Answer question to dismiss alarm."
        content.sound = UNNotificationSound.default
        
        // Make it a critical alert if possible
        content.categoryIdentifier = "ALARM_WAKE"
        
        // Set up a trigger for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: "wake-up-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        // Add the request
        notificationCenter.add(request)
    }
    
    private func ensureAudioSessionActive() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Could not activate audio session: \(error)")
        }
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        // End any existing background task
        endBackgroundTask()
        
        // Start a new background task
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AlarmActiveForegroundTask") { [weak self] in
            // This is the expiration handler, clean up if the task expires
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
