//
//  LucidApp.swift
//  Lucid
//
//  Created by Arfath Ahmed Syed on 10/04/25.
//

import SwiftUI

@main
struct LucidApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
