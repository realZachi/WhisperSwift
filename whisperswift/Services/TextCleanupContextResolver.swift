//
//  TextCleanupContextResolver.swift
//  whisperswift
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Foundation

final class TextCleanupContextResolver {

    func resolveProfile(snapshot: ContextService.Snapshot?) -> TextCleanupProfile {
        guard let snapshot else {
            return .default
        }

        // Try native app matching first (by bundleId, then appName)
        if let profile = matchNativeApp(bundleId: snapshot.bundleId, appName: snapshot.appName) {
            return profile
        }

        // For browsers, inspect windowTitle for known web app keywords
        if isBrowser(bundleId: snapshot.bundleId) {
            if let profile = matchWebApp(windowTitle: snapshot.windowTitle) {
                return profile
            }
        }

        return .default
    }

    // MARK: - Native App Matching

    private func matchNativeApp(bundleId: String?, appName: String?) -> TextCleanupProfile? {
        // Email clients
        let emailBundleIds: Set<String> = [
            "com.apple.mail",
            "com.microsoft.Outlook",
            "com.readdle.smartemail-Mac",    // Spark
            "com.readdle.SparkDesktop",       // Spark for Mac
            "com.freron.MailMate",
            "com.postbox-inc.postbox",
            "it.bloop.airmail2",
            "com.mimestream.Mimestream"
        ]

        // Chat / messaging clients
        let chatBundleIds: Set<String> = [
            "com.apple.MobileSMS",            // Messages
            "com.apple.iChat",                // Messages (older)
            "com.tinyspeck.slackmacgap",      // Slack
            "com.hnc.Discord",                // Discord
            "net.whatsapp.WhatsApp",
            "com.whatsapp.WhatsApp",
            "org.telegram.desktop",
            "ru.keepcoder.Telegram",
            "com.facebook.archon.developerID", // Messenger
            "com.skype.skype",
            "us.zoom.xos",                    // Zoom chat
            "com.microsoft.teams",
            "com.microsoft.teams2"
        ]

        // Markdown / dev tools
        let markdownBundleIds: Set<String> = [
            "com.microsoft.VSCode",
            "com.microsoft.VSCodeInsiders",
            "com.visualstudio.code.oss",
            "com.jetbrains.intellij",
            "com.jetbrains.intellij.ce",
            "com.jetbrains.WebStorm",
            "com.jetbrains.pycharm",
            "com.jetbrains.pycharm.ce",
            "com.jetbrains.CLion",
            "com.jetbrains.goland",
            "com.jetbrains.rider",
            "com.jetbrains.rubymine",
            "com.jetbrains.AppCode",
            "com.jetbrains.datagrip",
            "com.sublimetext.3",
            "com.sublimetext.4",
            "com.github.atom",
            "com.panic.Nova",
            "co.noteplan.NotePlan3",
            "md.obsidian",
            "com.uranusjr.macdown",
            "abnerworks.Typora",
            "com.electron.logseq",
            "com.notion.id"                   // Notion desktop
        ]

        // Document / word processors
        let documentBundleIds: Set<String> = [
            "com.apple.iWork.Pages",
            "com.microsoft.Word",
            "com.google.android.apps.docs",   // Google Docs (unlikely on Mac)
            "org.libreoffice.script",
            "org.openoffice.script",
            "com.bear.app",                   // Bear notes - prose-friendly
            "com.apple.Notes"
        ]

        if let bundleId {
            if emailBundleIds.contains(bundleId) {
                return .email
            }
            if chatBundleIds.contains(bundleId) {
                return .chat
            }
            if markdownBundleIds.contains(bundleId) {
                return .markdown
            }
            if documentBundleIds.contains(bundleId) {
                return .document
            }
        }

        // Fallback: match by app name (case-insensitive)
        if let appName = appName?.lowercased() {
            if appName.contains("mail") || appName.contains("outlook") || appName.contains("spark") {
                return .email
            }
            if appName.contains("slack") || appName.contains("discord") || appName.contains("whatsapp")
                || appName.contains("telegram") || appName.contains("messages") || appName.contains("teams") {
                return .chat
            }
            if appName.contains("code") || appName.contains("obsidian") || appName.contains("notion")
                || appName.contains("typora") || appName.contains("logseq") {
                return .markdown
            }
            if appName.contains("pages") || appName.contains("word") || appName.contains("notes") {
                return .document
            }
        }

        return nil
    }

    // MARK: - Browser Detection

    private func isBrowser(bundleId: String?) -> Bool {
        guard let bundleId else { return false }

        let browserBundleIds: Set<String> = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.google.Chrome.beta",
            "com.google.Chrome.canary",
            "org.mozilla.firefox",
            "org.mozilla.firefoxdeveloperedition",
            "org.mozilla.nightly",
            "company.thebrowser.Browser",     // Arc
            "com.brave.Browser",
            "com.microsoft.edgemac",
            "com.operasoftware.Opera",
            "com.vivaldi.Vivaldi",
            "org.chromium.Chromium"
        ]

        return browserBundleIds.contains(bundleId)
    }

    // MARK: - Web App Matching (via windowTitle)

    private func matchWebApp(windowTitle: String?) -> TextCleanupProfile? {
        guard let title = windowTitle?.lowercased() else { return nil }

        // Email web apps
        let emailKeywords = [
            "gmail", "google mail",
            "outlook", "outlook.com", "outlook.live",
            "proton mail", "protonmail",
            "web.de", "gmx",
            "yahoo mail", "yahoo!",
            "fastmail", "hey.com",
            "mail.com", "zoho mail",
            "icloud mail"
        ]
        for keyword in emailKeywords {
            if title.contains(keyword) {
                return .email
            }
        }

        // Chat web apps
        let chatKeywords = [
            "slack", "discord", "whatsapp", "telegram",
            "messenger", "teams", "google chat",
            "element", "matrix", "signal"
        ]
        for keyword in chatKeywords {
            if title.contains(keyword) {
                return .chat
            }
        }

        // Markdown web apps
        let markdownKeywords = [
            "github", "gitlab", "bitbucket",
            "linear", "jira", "asana",
            "notion", "coda",
            "confluence", "clickup",
            "trello"
        ]
        for keyword in markdownKeywords {
            if title.contains(keyword) {
                return .markdown
            }
        }

        // Document web apps
        let documentKeywords = [
            "google docs", "docs.google",
            "dropbox paper", "paper.dropbox",
            "quip"
        ]
        for keyword in documentKeywords {
            if title.contains(keyword) {
                return .document
            }
        }

        return nil
    }
}
