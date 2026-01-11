//
//  FrameDirectorApp.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import SwiftData
import FirebaseCore


@main
struct FrameDirectorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var languageManager = LanguageManager.shared
    @State private var splashViewModel = SplashViewModel(entitlementService: EntitlementService.shared)
    
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
            Group {
                switch splashViewModel.phase {
                case .loading:
                    SplashView(viewModel: splashViewModel)
                case .ready:
                    HomeView()
                }
            }
            .environment(\.locale, languageManager.locale)
            .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
