import SwiftUI

/// Full settings UI is built in Phase 7.
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("PicFacet")
                .font(.title)
                .fontWeight(.semibold)
            Text("Settings coming in Phase 7")
                .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 300)
        .padding()
    }
}
