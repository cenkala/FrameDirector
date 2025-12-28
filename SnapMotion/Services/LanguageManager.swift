//
//  LanguageManager.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"
    case german = "de"
    case spanish = "es"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        }
    }
}

@Observable
final class LanguageManager {
    static let shared = LanguageManager()
    
    private let userDefaultsKey = "selectedLanguage"
    
    var currentLanguage: SupportedLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
        }
    }
    
    var locale: Locale {
        Locale(identifier: currentLanguage.rawValue)
    }
    
    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = SupportedLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = Self.detectSystemLanguage()
        }
    }
    
    private static func detectSystemLanguage() -> SupportedLanguage {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2))
        
        return SupportedLanguage(rawValue: languageCode) ?? .english
    }
}

