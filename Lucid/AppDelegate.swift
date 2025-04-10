//
//  AppDelegate.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import UIKit
import UserNotifications
import AVFoundation
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Keep a reference to the alarm manager for background handling
    var alarmManager: AlarmManager?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions with all options
        requestNotificationPermissions()
        
        // Configure audio session for background playback
        setupAudioSession()
        
        // Register background tasks
        registerBackgroundTasks()
        
        // Handle launching from a notification
        if let notification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [String: AnyObject] {
            handleAlarmNotification(notification)
        }
        
        return true
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
            if granted {
                print("All notification permissions granted")
            } else {
                print("Notification permission denied: \(String(describing: error))")
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // Register for background tasks
    private func registerBackgroundTasks() {
        // For iOS 13+, register the refresh task
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.lucid.refresh", using: nil) { task in
                self.handleAppRefresh(task: task as! BGAppRefreshTask)
            }
        }
    }
    
    // Handle background app refresh for iOS 13+
    @available(iOS 13.0, *)
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        scheduleAppRefresh()
        
        // Create a task assertion to prevent premature ending
        let taskAssertionID = UIBackgroundTaskIdentifier.invalid
        
        // Set expiration handler
        task.expirationHandler = {
            // End background task if we're running one
            if taskAssertionID != .invalid {
                UIApplication.shared.endBackgroundTask(taskAssertionID)
            }
            
            // We didn't finish checking alarms
            task.setTaskCompleted(success: false)
        }
        
        // Check if any alarms need to be triggered
        if let alarmManager = self.alarmManager {
            alarmManager.checkPendingAlarms()
            
            // Wait a moment to ensure alarm check completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                // Finish the background task
                task.setTaskCompleted(success: true)
            }
        } else {
            // No alarm manager, complete task immediately
            task.setTaskCompleted(success: false)
        }
    }
    
    // Schedule the next app refresh task (iOS 13+)
    @available(iOS 13.0, *)
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.lucid.refresh")
        // Schedule to refresh within 15 minutes
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    // This is called when a notification is received while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Allow full presentation options
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .list, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
        
        // Also trigger the alarm directly
        let userInfo = notification.request.content.userInfo
        handleAlarmNotification(userInfo)
    }
    
    // This is called when user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle the notification
        handleAlarmNotification(userInfo)
        
        // Complete the response
        completionHandler()
    }
    
    private func handleAlarmNotification(_ userInfo: [AnyHashable: Any]) {
        // Wake up the device if it's locked
        wakeUpDeviceIfNeeded()
        
        // Post notification to be handled by AlarmManager
        NotificationCenter.default.post(
            name: Notification.Name("AlarmFired"),
            object: nil,
            userInfo: userInfo as? [String: Any]
        )
    }
    
    // Try to wake up the device when alarm fires
    private func wakeUpDeviceIfNeeded() {
        // This uses a private API trick that might help wake the screen
        // Alternative approach that's more reliable: use the critical alert permission
        if UIApplication.shared.applicationState != .active {
            // Make sure audio session is active
            try? AVAudioSession.sharedInstance().setActive(true)
            
            // Request the system to pay attention to our app
            UIApplication.shared.beginBackgroundTask(withName: "AlarmWakeTask")
        }
    }
    
    // For older iOS versions - Handle background refresh for checking alarms
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Check if any alarms need to be triggered
        if let alarmManager = self.alarmManager {
            alarmManager.checkPendingAlarms()
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }
    
    // Handle app entering background
    func applicationDidEnterBackground(_ application: UIApplication) {
        // For iOS 13 and later, schedule a BGTask
        if #available(iOS 13.0, *) {
            scheduleAppRefresh()
        } else {
            // For older iOS versions
            UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        }
    }
}
