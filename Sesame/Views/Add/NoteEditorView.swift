import SwiftData
import SwiftUI

/// Création / édition d'une note texte chiffrée (codes, numéros, mémos).
struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VaultStore.self) private var vault
    @Query(sort: \Category.createdAt) private var categories: [Category]

    /// Note existante à modifier, ou `nil` pour une création.
    let document: Document?
    var onDone: (() -> Void)?

    @State private var name = ""
    @State private var text = ""
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var saveError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 12) {
                    TextField("Titre de la note", text: $name)
                        .appFont(16, .semibold, relativeTo: .headline)
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusField, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )

                    TextEditor(text: $text)
                        .appFont(15, .regular, relativeTo: .body)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )

                    if document == nil {
                        TagSelectionGrid(categories: categories, selection: $selectedTagIDs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .navigationTitle(document == nil ? "Nouvelle note" : "Modifier la note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(name.isEmpty && text.isEmpty)
                }
            }
            .alert("Impossible d'enregistrer la note", isPresented: $saveError) {
                Button("OK", role: .cancel) {}
            }
        }
        .presentationCornerRadius(Theme.radiusSheet)
        .onAppear {
            if let document {
                name = document.name
                text = vault.noteText(for: document)
                selectedTagIDs = Set(document.tagIDs)
            }
        }
    }

    private func save() {
        do {
            if let document {
                document.name = name.isEmpty ? String(localized: "Note") : name
                try vault.updateNote(document, text: text)
            } else {
                try vault.importDocument(
                    data: Data(text.utf8),
                    name: name.isEmpty ? String(localized: "Note") : name,
                    type: .note,
                    fileExtension: "txt",
                    tagIDs: Array(selectedTagIDs)
                )
            }
            dismiss()
            onDone?()
        } catch {
            saveError = true
        }
    }
}
