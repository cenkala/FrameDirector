//
//  IDFVManager.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation
import UIKit

final class IDFVManager {
    static let shared = IDFVManager()

    private(set) var idfv: String?

    private init() {
        // IDFV is available after the app launches, so we'll get it lazily
    }

    func getIDFV() -> String {
        if let idfv = idfv {
            return idfv
        }

        // Get IDFV from UIDevice
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString {
            self.idfv = vendorID
            return vendorID
        }

        // Fallback if IDFV is not available (shouldn't happen in normal cases)
        let fallbackID = "unknown_idfv_\(Date().timeIntervalSince1970)"
        self.idfv = fallbackID
        return fallbackID
    }
}
