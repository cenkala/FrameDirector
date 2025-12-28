//
//  FrameDirectorApp.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import SwiftData

@main
struct FrameDirectorApp: App {
    @State private var languageManager = LanguageManager.shared
    @State private var entitlementService = EntitlementService.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MovieProject.self,
            FrameAsset.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        EntitlementService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.locale, languageManager.locale)
        }
        .modelContainer(sharedModelContainer)
    }
}
