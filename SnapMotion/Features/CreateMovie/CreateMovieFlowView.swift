//
//  CreateMovieFlowView.swift
//  Frame Director
//
//  Created by Cenk Alasonyalilar on 28.12.2025.
//

import SwiftUI
import SwiftData

struct CreateMovieFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let onProjectCreated: (MovieProject) -> Void
    
    @State private var projectTitle = ""
    
    var body: some View {
        NavigationStack {
            titleInputView
            .padding()
            .navigationTitle(LocalizedStringKey("create.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("general.cancel"))
                    }
                }
            }
        }
        .tint(.accentColor)
        .appScreenBackground()
    }
    
    private var titleInputView: some View {
        VStack(spacing: 18) {
            AppSectionHeader(LocalizedStringKey("create.title"))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    AppIconBadge(systemImage: "film")
                }

                TextField(LocalizedStringKey("create.title"), text: $projectTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            .appCard()

            Button {
                createProject()
            } label: {
                Text(LocalizedStringKey("general.done"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .disabled(projectTitle.isEmpty)

            Spacer()
        }
    }
    
    private func createProject() {
        let project = MovieProject(title: projectTitle)
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
        onProjectCreated(project)
    }
}

