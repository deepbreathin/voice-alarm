import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            AlarmsListView()
                .tabItem { Label("Alarms", systemImage: "alarm") }

            RecordingsListView()
                .tabItem { Label("Recordings", systemImage: "waveform") }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.lastErrorMessage != nil },
                set: { if !$0 { model.lastErrorMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(model.lastErrorMessage ?? "") }
        )
    }
}
