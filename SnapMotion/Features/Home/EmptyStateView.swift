//
//  EmptyStateView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI

struct EmptyStateView: View {
    let onCreateProject: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            Label(LocalizedStringKey("home.emptyState.title"), systemImage: "film.stack")
        } actions: {
            Button {
                onCreateProject()
            } label: {
                Label(LocalizedStringKey("home.createStopMotion"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .controlSize(.large)
        }
    }
}

