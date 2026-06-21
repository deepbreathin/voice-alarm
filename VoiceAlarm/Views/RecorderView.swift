import SwiftUI

/// A sheet that records a new voice clip with a live level meter and timer.
struct RecorderView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Text(Formatters.duration(model.recorder.elapsed))
                    .font(.system(size: 56, weight: .light, design: .monospaced))
                    .accessibilityIdentifier("recorderTimer")

                LevelMeter(level: model.recorder.currentLevel)
                    .frame(height: 60)
                    .padding(.horizontal)

                TextField("Title (optional)", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                recordButton

                Spacer()
            }
            .navigationTitle("New Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.recorder.cancel()
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled(model.recorder.isRecording)
        }
    }

    private var recordButton: some View {
        Button {
            Task { await toggleRecording() }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.red, lineWidth: 4)
                    .frame(width: 84, height: 84)
                RoundedRectangle(cornerRadius: model.recorder.isRecording ? 6 : 38)
                    .fill(Color.red)
                    .frame(
                        width: model.recorder.isRecording ? 34 : 70,
                        height: model.recorder.isRecording ? 34 : 70
                    )
                    .animation(.easeInOut(duration: 0.2), value: model.recorder.isRecording)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.recorder.isRecording ? "Stop recording" : "Start recording")
        .accessibilityIdentifier("recordToggle")
    }

    private func toggleRecording() async {
        if model.recorder.isRecording {
            await model.finishRecording(title: title)
            dismiss()
        } else {
            do {
                _ = try await model.recorder.start()
                errorText = nil
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? "Could not start recording."
            }
        }
    }
}

/// A simple horizontal audio level meter (0...1).
struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                let count = 30
                ForEach(0..<count, id: \.self) { index in
                    let threshold = Float(index) / Float(count)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level >= threshold ? barColor(for: threshold) : Color.secondary.opacity(0.2))
                }
            }
            .frame(height: geo.size.height)
        }
    }

    private func barColor(for threshold: Float) -> Color {
        if threshold > 0.85 { return .red }
        if threshold > 0.6 { return .yellow }
        return .green
    }
}
