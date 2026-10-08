import SwiftUI
import PicFacetCore

/// Create or edit a recipe from Settings: a name plus the same options as
/// the Chooser and Batch windows.
struct RecipeEditorSheet: View {
    /// nil creates a new recipe.
    let recipe: Recipe?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var draft: OperationDraft

    init(recipe: Recipe?) {
        self.recipe = recipe
        _name = State(initialValue: recipe?.name ?? "")
        _draft = State(initialValue: recipe.map { OperationDraft(selection: $0.selection) } ?? OperationDraft())
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { draft.selection != nil && !trimmedName.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(recipe == nil ? "New Recipe" : "Edit Recipe")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PFDesign.onSurface)

            VStack(alignment: .leading, spacing: 6) {
                PFSectionLabel(text: "Name")
                TextField("e.g. Blog photos", text: $name)
                    .pfEntryField(isValid: !trimmedName.isEmpty || name.isEmpty)
            }

            VStack(alignment: .leading, spacing: 10) {
                PFSectionLabel(text: "Processing Options")
                ScrollView {
                    OperationMenus(draft: $draft, labelWidth: 150, menuWidth: 220, showsDetails: true)
                        .padding(.trailing, 4)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: 520)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: draft.selection == nil ? "circle.dashed" : "checkmark.circle.fill")
                    .foregroundStyle(draft.selection == nil ? PFDesign.onSurfaceVariant : PFDesign.success)
                Text(draft.summary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PFDesign.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PFDesign.surfaceLow, in: RoundedRectangle(cornerRadius: PFDesign.rInner, style: .continuous))

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(recipe == nil ? "Save Recipe" : "Save Changes", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(PFDesign.canvas)
        .tint(PFDesign.primary)
    }

    private func save() {
        guard let selection = draft.selection, !trimmedName.isEmpty else { return }
        if var existing = recipe {
            existing.name = trimmedName
            existing.selection = selection
            RecipeStore.update(existing)
        } else {
            RecipeStore.add(Recipe(name: trimmedName, selection: selection))
        }
        dismiss()
    }
}
