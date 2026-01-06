//
//  SplashView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalılar on 29.12.2025.
//  Copyright © 2025 Cenk Alasonyalılar. All rights reserved.
//

import SwiftUI

struct SplashView: View {
    @Bindable var viewModel: SplashViewModel

    var body: some View {
        VStack(spacing: 18) {
            Image("ic_app_icon")
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(AppTheme.Colors.separator.opacity(0.25), lineWidth: 1)
                }

            Text(LocalizedStringKey("app.name"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            ProgressView()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
        .task {
            await viewModel.start()
        }
    }
}



