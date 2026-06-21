import SwiftUI
import UserNotifications

struct AlarmsListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingAlarm: Alarm?
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if model.alarmStore.alarms.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editingAlarm = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Alarm")
                    .accessibilityIdentifier("addAlarmButton")
                }
            }
            .sheet(isPresented: $showingEditor) {
                AlarmEditorView(alarm: editingAlarm)
            }
        }
    }

    private var permissionBanner: some View {
        Group {
            if model.notifications.authorizationStatus == .denied {
                banner(
                    text: "Notifications are off. Alarms can't sound until you enable them in Settings.",
                    systemImage: "bell.slash"
                )
            } else if model.notifications.authorizationStatus == .notDetermined {
                Button {
                    Task { await model.requestNotificationAuthorization() }
                } label: {
                    banner(
                        text: "Tap to allow notifications so your alarms can sound.",
                        systemImage: "bell.badge"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func banner(text: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
            Text(text).font(.footnote)
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var list: some View {
        List {
            Section {
                permissionBanner
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            ForEach(model.alarmStore.alarms) { alarm in
                AlarmRowView(alarm: alarm)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingAlarm = alarm
                        showingEditor = true
                    }
            }
            .onDelete { offsets in
                let toDelete = offsets.map { model.alarmStore.alarms[$0] }
                Task {
                    for alarm in toDelete { await model.deleteAlarm(alarm) }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Alarms", systemImage: "alarm")
        } description: {
            Text("Add an alarm to play one of your recordings at a time you choose.")
        } actions: {
            Button("Add Alarm") {
                editingAlarm = nil
                showingEditor = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct AlarmRowView: View {
    @EnvironmentObject private var model: AppModel
    let alarm: Alarm

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Formatters.time(alarm.time))
                    .font(.system(size: 34, weight: .light, design: .rounded))
                    .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                if !alarm.label.isEmpty {
                    Text(alarm.label).font(.subheadline)
                }
                Text(Formatters.recurrenceDescription(alarm.recurrence))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { newValue in Task { await model.setAlarm(alarm, enabled: newValue) } }
            ))
            .labelsHidden()
            .accessibilityLabel("Enable \(alarm.label.isEmpty ? "alarm" : alarm.label)")
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        guard let recordingID = alarm.recordingID,
              let recording = model.recordingStore.recording(withID: recordingID) else {
            return "⚠︎ No recording selected"
        }
        if alarm.isEnabled, let next = model.nextFireDate(for: alarm) {
            return "🔊 \(recording.title) · \(Formatters.nextFireDescription(next))"
        }
        return "🔊 \(recording.title)"
    }
}
