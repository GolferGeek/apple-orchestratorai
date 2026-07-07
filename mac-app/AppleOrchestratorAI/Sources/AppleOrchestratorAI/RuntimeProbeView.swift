import SwiftUI

struct RuntimeProbeView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let output: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: action) {
                    Label(buttonTitle, systemImage: "waveform.path.ecg")
                }
            }

            Text(output.isEmpty ? "No probe has been run yet." : output)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .background(.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
    }
}
