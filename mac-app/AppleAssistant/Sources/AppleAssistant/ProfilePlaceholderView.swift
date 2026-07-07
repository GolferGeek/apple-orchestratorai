import SwiftUI

struct ProfilePlaceholderView: View {
    let surface: ModalSurface

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(surface.title, systemImage: surface.symbolName)
                .font(.title.weight(.semibold))

            Text("This profile is registered as part of Apple Assistant, but its dedicated surface is not built yet.")
                .foregroundStyle(.secondary)

            Text("Next step: define the profile surface schema and connect its file-backed effort or memory view.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
