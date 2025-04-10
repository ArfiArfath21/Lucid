//
//  NotificationUtils.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import Foundation
import UserNotifications

class NotificationUtils {
    // Get a critical sound, handling API differences across iOS versions
    static func getCriticalSound() -> UNNotificationSound {
        // Use the default sound - iOS will use critical sound patterns
        // when the notification's interruptionLevel is set to critical
        return UNNotificationSound.default
    }
    
    // Configure a notification content for critical alerts
    static func configureCriticalAlert(content: UNMutableNotificationContent) {
        // Set critical interruption level if available (iOS 15+)
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .critical
        }
        
        // Use default sound - will be enhanced by system when marked critical
        content.sound = UNNotificationSound.default
    }
}
