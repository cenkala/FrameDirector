//
//  ProjectLimits.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import Foundation

struct ProjectLimits {
    static let freeMaxProjects = 1
    static let freeMaxDurationSeconds: TimeInterval = 5.0
    
    static func canCreateProject(currentProjectCount: Int, isPro: Bool) -> Bool {
        if isPro {
            return true
        }
        return currentProjectCount < freeMaxProjects
    }
    
    static func canExportVideo(duration: TimeInterval, isPro: Bool) -> Bool {
        if isPro {
            return true
        }
        return duration <= freeMaxDurationSeconds
    }
    
    static func maxAllowedFrames(fps: Int, isPro: Bool) -> Int? {
        if isPro {
            return nil
        }
        return Int(freeMaxDurationSeconds * Double(fps))
    }
}

