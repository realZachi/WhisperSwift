//
//  whisperswiftApp.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import SwiftUI

@main
struct WhisperSwiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window accessible via menu
        Settings {
            SettingsView()
        }
    }
}
