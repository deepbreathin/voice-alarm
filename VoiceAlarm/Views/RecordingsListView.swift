import SwiftUI
import UniformTypeIdentifiers

struct RecordingsListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showingRecorder = false
    @State private var showingImporter = false
    @State private var renameTarget: Recording?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if model.recordingStore.recordings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Recordings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Import Audio")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingRecorder = true
                    } label: {
                        Image(systemName: "mic.circle.fill")
                    }
                    .accessibilityLabel("Record")
                    .accessibilityIdentifier("recordButton")
                }
            }
            .sheet(isPresented: $showingRecorder) {
                RecorderView()
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls { model.importFile(at: url) }
                case .failure:
                    model.lastErrorMessage = "Could not open the selected file."
                }
            }
            .alert("Rename Recording", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    if let target = renameTarget {
                        model.recordingStore.rename(target, to: renameText)
                    }
                    renameTarget = nil
                }
                Button("Cancel", role: .cancel) { renameTarget = nil }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(model.recordingStore.recordings) { recording in
                HStack {
                    Button {
                        model.playback.toggle(model.previewURL(for: recording))
                    } label: {
                        Image(systemName: isPlaying(recording) ? "stop.circle.fill" : "play.circle")
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recording.title)
                        HStack(spacing: 6) {
                            Text(Formatters.duration(recording.duration))
                            Text(recording.source == .imported ? "Imported" : "Recorded")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        model.deleteRecording(recording)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        renameText = recording.title
                        renameTarget = recording
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Recordings", systemImage: "waveform")
        } description: {
            Text("Record a new voice clip, or import one from Files. To use a Voice Memo, open it in the Voice Memos app, tap Share, then \"Save to Files\" or \"VoiceAlarm\".")
        } actions: {
            Button("Record") { showingRecorder = true }
                .buttonStyle(.borderedProminent)
            Button("Import from Files") { showingImporter = true }
        }
    }

    private func isPlaying(_ recording: Recording) -> Bool {
        model.playback.isPlaying && model.playback.playingURL == model.previewURL(for: recording)
    }
}
