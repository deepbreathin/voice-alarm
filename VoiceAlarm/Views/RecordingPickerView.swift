import SwiftUI

/// A sheet that lets the user pick which recording an alarm should play, with
/// inline preview playback.
struct RecordingPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if model.recordingStore.recordings.isEmpty {
                    ContentUnavailableView(
                        "No Recordings",
                        systemImage: "waveform",
                        description: Text("Record or import a clip on the Recordings tab first.")
                    )
                } else {
                    List(model.recordingStore.recordings) { recording in
                        Button {
                            selectedID = recording.id
                            dismiss()
                        } label: {
                            HStack {
                                Button {
                                    model.playback.toggle(model.previewURL(for: recording))
                                } label: {
                                    Image(systemName: isPreviewing(recording) ? "stop.circle.fill" : "play.circle")
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isPreviewing(recording) ? "Stop preview" : "Preview")

                                VStack(alignment: .leading) {
                                    Text(recording.title)
                                    Text(Formatters.duration(recording.duration))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedID == recording.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Choose Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onDisappear { model.playback.stop() }
        }
    }

    private func isPreviewing(_ recording: Recording) -> Bool {
        model.playback.isPlaying && model.playback.playingURL == model.previewURL(for: recording)
    }
}
