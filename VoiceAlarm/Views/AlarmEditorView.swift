import SwiftUI

/// Create / edit an alarm. Holds local editable state and commits an `Alarm`
/// back to the model on save.
struct AlarmEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private let existing: Alarm?

    @State private var label: String
    @State private var timeDate: Date
    @State private var recordingID: UUID?
    @State private var mode: RecurrenceMode
    @State private var selectedDays: Set<Weekday>
    @State private var interval: Int
    @State private var oneOffDay: Date
    @State private var showingRecordingPicker = false

    enum RecurrenceMode: String, CaseIterable, Identifiable {
        case once = "Once"
        case weekly = "Weekly"
        case everyNDays = "Every N days"
        var id: String { rawValue }
    }

    init(alarm: Alarm?) {
        self.existing = alarm
        let calendar = Calendar.current
        let now = Date()

        if let alarm {
            _label = State(initialValue: alarm.label)
            _timeDate = State(initialValue: alarm.time.applied(to: now, calendar: calendar))
            _recordingID = State(initialValue: alarm.recordingID)
            switch alarm.recurrence {
            case .oneOff(let day):
                _mode = State(initialValue: .once)
                _selectedDays = State(initialValue: [])
                _interval = State(initialValue: 2)
                _oneOffDay = State(initialValue: day)
            case .weekly(let days):
                _mode = State(initialValue: .weekly)
                _selectedDays = State(initialValue: days)
                _interval = State(initialValue: 2)
                _oneOffDay = State(initialValue: now)
            case .everyNDays(let n, let anchor):
                _mode = State(initialValue: .everyNDays)
                _selectedDays = State(initialValue: [])
                _interval = State(initialValue: n)
                _oneOffDay = State(initialValue: anchor)
            }
        } else {
            _label = State(initialValue: "")
            _timeDate = State(initialValue: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now)
            _recordingID = State(initialValue: nil)
            _mode = State(initialValue: .once)
            _selectedDays = State(initialValue: [])
            _interval = State(initialValue: 2)
            _oneOffDay = State(initialValue: now)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                timeSection
                recordingSection
                repeatSection
                if existing != nil { deleteSection }
            }
            .navigationTitle(existing == nil ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveAlarmButton")
                }
            }
            .sheet(isPresented: $showingRecordingPicker) {
                RecordingPickerView(selectedID: $recordingID)
            }
        }
    }

    private var timeSection: some View {
        Section {
            DatePicker("Time", selection: $timeDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .center)
            TextField("Label (optional)", text: $label)
        }
    }

    private var recordingSection: some View {
        Section("Sound") {
            Button {
                showingRecordingPicker = true
            } label: {
                HStack {
                    Text("Recording")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedRecordingTitle)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityIdentifier("selectRecordingButton")
            if recordingID != nil, let recording = model.recordingStore.recording(withID: recordingID),
               recording.duration > AudioClipPreparer.maxNotificationSeconds {
                Text("Only the first \(Int(AudioClipPreparer.maxNotificationSeconds))s plays as the alarm sound. The full clip plays when you tap the notification.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var repeatSection: some View {
        Section("Repeat") {
            Picker("Repeat", selection: $mode) {
                ForEach(RecurrenceMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch mode {
            case .once:
                DatePicker("Date", selection: $oneOffDay, in: Date()..., displayedComponents: .date)
            case .weekly:
                WeekdaySelector(selected: $selectedDays)
                quickPicks
            case .everyNDays:
                Stepper("Every \(interval) day\(interval == 1 ? "" : "s")", value: $interval, in: 1...365)
                DatePicker("Starting", selection: $oneOffDay, in: Date()..., displayedComponents: .date)
            }
        }
    }

    private var quickPicks: some View {
        HStack {
            Button("Weekdays") { selectedDays = Weekday.weekdays }
                .buttonStyle(.bordered)
            Button("Weekends") { selectedDays = Weekday.weekend }
                .buttonStyle(.bordered)
            Button("Every day") { selectedDays = Weekday.everyDay }
                .buttonStyle(.bordered)
        }
        .font(.caption)
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Alarm", role: .destructive) {
                if let existing {
                    Task {
                        await model.deleteAlarm(existing)
                        dismiss()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var selectedRecordingTitle: String {
        if let recording = model.recordingStore.recording(withID: recordingID) {
            return recording.title
        }
        return "Choose…"
    }

    private var canSave: Bool {
        guard recordingID != nil else { return false }
        if mode == .weekly { return !selectedDays.isEmpty }
        return true
    }

    private func save() {
        let time = TimeOfDay(date: timeDate)
        let recurrence: Recurrence
        switch mode {
        case .once:
            recurrence = .oneOff(day: oneOffDay)
        case .weekly:
            recurrence = .weekly(days: selectedDays)
        case .everyNDays:
            recurrence = .everyNDays(interval: interval, anchorDay: oneOffDay)
        }

        let alarm = Alarm(
            id: existing?.id ?? UUID(),
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            recordingID: recordingID,
            time: time,
            recurrence: recurrence,
            isEnabled: existing?.isEnabled ?? true,
            createdAt: existing?.createdAt ?? Date()
        )
        Task {
            await model.saveAlarm(alarm)
            dismiss()
        }
    }
}

/// Row of toggle chips for selecting weekdays (Mon-first).
struct WeekdaySelector: View {
    @Binding var selected: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.mondayFirstOrder) { day in
                let isOn = selected.contains(day)
                Button {
                    if isOn { selected.remove(day) } else { selected.insert(day) }
                } label: {
                    Text(day.shortSymbol().prefix(1))
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullSymbol())
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}
