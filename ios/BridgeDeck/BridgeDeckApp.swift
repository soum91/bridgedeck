import SwiftUI
import UniformTypeIdentifiers

@main
struct BridgeDeckApp: App {
    @StateObject private var store = BridgeStore()
    var body: some Scene {
        WindowGroup {
            BridgeDeckView()
                .environmentObject(store)
                .tint(.cyan)
        }
    }
}

struct BridgeDeckView: View {
    @EnvironmentObject private var store: BridgeStore
    @Environment(\.scenePhase) private var phase
    @StateObject private var discovery = TVDiscovery()
    @AppStorage("lastHost") private var host = ""
    @AppStorage("lastPort") private var port = 5555
    @State private var showingImporter = false

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        connectionCard
                        if !discovery.devices.isEmpty { discoveredCard }
                        quickActions
                        outputCard
                    }
                    .padding()
                }
                .navigationTitle("BridgeDeck")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await store.refreshPackages() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(!store.connected)
                    }
                }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { AppsScreen() }
                .tabItem { Label("Apps", systemImage: "square.grid.2x2.fill") }
            NavigationStack { CleanupScreen() }
                .tabItem { Label("Clean", systemImage: "shield.lefthalf.filled") }
            NavigationStack { DefaultsScreen() }
                .tabItem { Label("Defaults", systemImage: "slider.horizontal.3") }
            NavigationStack { DiagnosticsScreen() }
                .tabItem { Label("Diagnose", systemImage: "waveform.path.ecg") }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result {
                Task { await store.installAPK(url) }
            }
        }
        .onAppear { discovery.start() }
        .onDisappear { discovery.stop() }
        .onChange(of: phase) { _, next in
            if next == .active, !store.connected, !host.isEmpty {
                Task { await store.connect(host: host, port: port) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your TV, your rules.")
                    .font(.title2.weight(.bold))
                Text("Friendly controls powered by Android Debug Bridge.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "tv")
                .font(.title)
                .foregroundStyle(.cyan)
                .frame(width: 48, height: 48)
                .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(store.connected ? store.model : "Connect Android TV", systemImage: "tv")
                    .font(.headline)
                Spacer()
                Text(store.connected ? "Connected" : "Offline")
                    .font(.caption.bold())
                    .foregroundStyle(store.connected ? .green : .orange)
            }
            if store.connected {
                Text(store.firmware).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            TextField("TV IP or hostname", text: $host)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("ADB Port")
                Spacer()
                TextField("5555", value: $port, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 85)
                    .textFieldStyle(.roundedBorder)
            }
            Button {
                Task {
                    if store.connected { await store.disconnect() }
                    else { await store.connect(host: host, port: port) }
                }
            } label: {
                HStack {
                    if store.connecting { ProgressView().tint(.white) }
                    else { Image(systemName: store.connected ? "wifi.slash" : "link") }
                    Text(store.connected ? "Disconnect" : "Connect to TV")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.connecting)
            if !store.connected {
                Text("Android TV 12: Enable a supported network ADB mode first. Initial USB setup may be required. Approve the debugging prompt on your TV.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !store.lastError.isEmpty {
                Label(store.lastError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var discoveredCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nearby companions").font(.headline)
            ForEach(discovery.devices) { tv in
                Button {
                    host = tv.host
                    Task { await store.connect(host: tv.host, port: port) }
                } label: {
                    HStack {
                        Image(systemName: "tv")
                        VStack(alignment: .leading) {
                            Text(tv.name).fontWeight(.semibold)
                            Text(tv.host).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(store.connecting)
            }
            Text("Discovery finds the TV companion. Privileged controls still require authorized ADB.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick actions").font(.title3.bold())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                commandTile("Refresh apps", icon: "arrow.clockwise", command: "pm list packages -3")
                commandTile("Storage", icon: "internaldrive", command: "df -h /data")
                commandTile("System info", icon: "cpu", command: "getprop ro.build.version.release")
                Button { showingImporter = true } label: {
                    ActionLabel(title: "Install APK", icon: "square.and.arrow.down")
                }
                .disabled(!store.connected || store.busy)
                .buttonStyle(.plain)
            }
        }
    }

    private func commandTile(_ title: String, icon: String, command: String) -> some View {
        Button {
            Task { await store.run(command, name: title) }
        } label: { ActionLabel(title: title, icon: icon) }
        .disabled(!store.connected || store.busy)
        .buttonStyle(.plain)
    }

    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Latest result").font(.headline)
                Spacer()
                ShareLink(item: store.lastOutput) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            Text(store.lastOutput)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(10)
            if store.busy { ProgressView("Working…") }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct ActionLabel: View {
    let title: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(.cyan)
            Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct AppsScreen: View {
    @EnvironmentObject private var store: BridgeStore
    @State private var search = ""
    @State private var pendingClear: String?
    private var results: [String] {
        search.isEmpty ? store.installedPackages :
            store.installedPackages.filter { $0.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        List {
            Section {
                Text("\(store.installedPackages.count) packages detected")
                    .foregroundStyle(.secondary)
                Button("Refresh installed apps") {
                    Task { await store.refreshPackages() }
                }.disabled(!store.connected)
            }
            Section("Installed packages") {
                ForEach(results, id: \.self) { package in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(package).font(.system(.subheadline, design: .monospaced))
                            .textSelection(.enabled)
                        HStack {
                            Button("Open") {
                                Task {
                                    await store.run("monkey -p \(package) -c android.intent.category.LAUNCHER 1",
                                                    name: "Open app")
                                }
                            }
                            Button("Stop") {
                                Task { await store.run("am force-stop \(package)", name: "Stop app") }
                            }
                            Button("Clear data", role: .destructive) { pendingClear = package }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .disabled(!store.connected || store.busy)
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search packages")
        .navigationTitle("App Manager")
        .alert("Erase all app data?", isPresented: Binding(
            get: { pendingClear != nil },
            set: { if !$0 { pendingClear = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingClear = nil }
            Button("Erase", role: .destructive) {
                if let package = pendingClear {
                    Task { await store.run("pm clear \(package)", name: "Clear app data") }
                }
                pendingClear = nil
            }
        } message: {
            Text("This permanently erases local settings and sign-ins for \(pendingClear ?? "this app").")
        }
    }
}

private struct CleanupScreen: View {
    @EnvironmentObject private var store: BridgeStore
    @State private var selected: CleanupCandidate?
    var body: some View {
        List {
            Section {
                Label("An exact Sony device profile has not been verified.",
                      systemImage: "info.circle")
                Text("Only packages actually installed on your TV are shown. Nothing is removed automatically. Disabling records a recovery snapshot first.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Scan TV packages") {
                    Task { await store.refreshPackages() }
                }.disabled(!store.connected)
            }
            ForEach(Array(Dictionary(grouping: CleanupCatalog.sonyCandidates,
                                     by: \.group).keys).sorted(), id: \.self) { category in
                Section(category) {
                    ForEach(CleanupCatalog.sonyCandidates.filter {
                        $0.group == category && store.installedPackages.contains($0.id)
                    }) { candidate in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(candidate.title).font(.headline)
                            Text(candidate.id).font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(candidate.explanation).font(.caption)
                            if store.enabledPackages.contains(candidate.id) {
                                Button("Review and disable") { selected = candidate }
                                    .buttonStyle(.bordered)
                                    .disabled(!store.connected || store.busy)
                            } else if store.recoverablePackages.contains(candidate.id) {
                                Button("Restore package") {
                                    Task { await store.restore(candidate.id) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(!store.connected || store.busy)
                            } else {
                                Text("Already disabled on this TV")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            Section("Protected components") {
                Text("TV tuner, HDMI input services, Bravia Sync, Android core, Wi-Fi setup, and stock Home cannot be disabled here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Privacy & Debloat")
        .alert("Disable \(selected?.title ?? "package")?", isPresented: Binding(
            get: { selected != nil },
            set: { if !$0 { selected = nil } }
        )) {
            Button("Cancel", role: .cancel) { selected = nil }
            Button("Disable", role: .destructive) {
                if let candidate = selected {
                    Task { await store.disable(candidate) }
                }
                selected = nil
            }
        } message: {
            Text("BridgeDeck will create a local recovery snapshot, then disable only this package for user 0. Test your remote, Wi-Fi, TV inputs, and apps afterward.")
        }
    }
}

private struct DefaultsScreen: View {
    @EnvironmentObject private var store: BridgeStore
    @State private var browserPackage = ""
    @State private var homeComponent = ""
    @State private var tunerPackage = "com.sony.dtv.tvx"
    var body: some View {
        Form {
            Section {
                Text("Android roles and Sony firmware decide what can become a default. BridgeDeck verifies results and does not disable the stock launcher automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Browser") {
                TextField("Browser package", text: $browserPackage)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Request default browser role") {
                    Task { await store.setBrowser(browserPackage) }
                }.disabled(!store.connected || browserPackage.isEmpty)
                Button("Inspect browser role") {
                    Task { await store.run("cmd role holders android.app.role.BROWSER") }
                }.disabled(!store.connected)
            }
            Section("Home launcher") {
                TextField("Package/.Activity", text: $homeComponent)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Request Home activity") {
                    Task { await store.setHome(homeComponent) }
                }.disabled(!store.connected || homeComponent.isEmpty)
                Button("Check current Home") {
                    Task {
                        await store.run("cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME")
                    }
                }.disabled(!store.connected)
            }
            Section("Live TV / Tuner") {
                TextField("TV app package", text: $tunerPackage)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Open preferred TV app") {
                    Task { await store.launchTuner(tunerPackage) }
                }.disabled(!store.connected)
                Text("Android TV 12 has no universal default tuner-app role. This launches your chosen app; remapping Sony's TV button needs firmware-specific support.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Default Apps")
    }
}

private struct DiagnosticsScreen: View {
    @EnvironmentObject private var store: BridgeStore
    @State private var command = "getprop ro.product.cpu.abi"
    @State private var advanced = false
    @State private var aiResponse = ""
    @State private var aiBusy = false
    var body: some View {
        Form {
            Section("AI-style error guidance") {
                let advice = ErrorAdvisor.explain(store.lastOutput)
                Label(advice.title, systemImage: "sparkles")
                    .font(.headline)
                ForEach(advice.steps, id: \.self) { Text("• " + $0).font(.subheadline) }
                Button {
                    aiBusy = true
                    Task {
                        aiResponse = await OnDeviceAI.explain(store.lastOutput)
                        aiBusy = false
                    }
                } label: {
                    Label("Explain with on-device AI", systemImage: "sparkles")
                }
                .disabled(aiBusy)
                if aiBusy { ProgressView("Analyzing on iPhone…") }
                if !aiResponse.isEmpty {
                    Text(aiResponse).textSelection(.enabled)
                }
                Text("On supported iPhones, Apple Intelligence can analyze locally. A rule-based fallback works without it. No logs are uploaded.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Latest output") {
                Text(store.lastOutput).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                ShareLink("Share diagnostics", item: store.lastOutput)
            }
            Section("Common checks") {
                Button("TV version and build") {
                    Task { await store.run("getprop ro.build.fingerprint") }
                }
                Button("Available storage") {
                    Task { await store.run("df -h /data") }
                }
                Button("Default Home resolution") {
                    Task {
                        await store.run("cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME")
                    }
                }
                Button("Recent system errors") {
                    Task { await store.run("logcat -d -t 100 -v brief '*:E'") }
                }
            }.disabled(!store.connected || store.busy)
            Section {
                Toggle("Show raw ADB command field", isOn: $advanced)
                if advanced {
                    Text("Advanced: commands run with the TV's ADB shell permissions. Review carefully.")
                        .font(.caption).foregroundStyle(.orange)
                    TextField("ADB shell command", text: $command, axis: .vertical)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Run shell command") {
                        Task { await store.run(command, name: "Advanced shell") }
                    }.disabled(!store.connected || command.isEmpty || store.busy)
                }
            }
            if !store.mostRecentRecovery.isEmpty {
                Section("Recovery") {
                    Text(store.mostRecentRecovery)
                    Text("Recovery snapshots are saved in Files → On My iPhone → BridgeDeck → Recovery.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Diagnostics")
    }
}
