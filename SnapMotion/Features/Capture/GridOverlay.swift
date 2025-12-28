//
//  GridOverlay.swift
//  SnapMotion
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                let horizontalSpacing = height / 3
                let verticalSpacing = width / 3
                
                path.move(to: CGPoint(x: 0, y: horizontalSpacing))
                path.addLine(to: CGPoint(x: width, y: horizontalSpacing))
                
                path.move(to: CGPoint(x: 0, y: horizontalSpacing * 2))
                path.addLine(to: CGPoint(x: width, y: horizontalSpacing * 2))
                
                path.move(to: CGPoint(x: verticalSpacing, y: 0))
                path.addLine(to: CGPoint(x: verticalSpacing, y: height))
                
                path.move(to: CGPoint(x: verticalSpacing * 2, y: 0))
                path.addLine(to: CGPoint(x: verticalSpacing * 2, y: height))
            }
            .stroke(.white.opacity(0.5), lineWidth: 1)
        }
    }
}

