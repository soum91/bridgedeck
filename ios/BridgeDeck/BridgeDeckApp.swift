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
    @State private var showingHomeResult = false
    @State private var selectedTab: BridgeTab = .home
    @State private var showingConnectionDetails = false
    @FocusState private var editingAddress: Bool

    private enum BridgeTab: Hashable {
        case home, apps, clean, defaults, adb
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        connectionCard
                        if !store.connected || showingConnectionDetails {
                            if !discovery.devices.isEmpty { discoveredCard }
                        }
                        if store.connected { toolsLauncher }
                        if store.connected { quickActions }
                        outputCard
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
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
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { editingAddress = false }
                    }
                }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(BridgeTab.home)

            NavigationStack { AppsScreen() }
                .tabItem { Label("Apps", systemImage: "square.grid.2x2.fill") }
                .tag(BridgeTab.apps)
            NavigationStack { CleanupScreen() }
                .tabItem { Label("Clean", systemImage: "shield.lefthalf.filled") }
                .tag(BridgeTab.clean)
            NavigationStack { DefaultsScreen() }
                .tabItem { Label("Defaults", systemImage: "slider.horizontal.3") }
                .tag(BridgeTab.defaults)
            NavigationStack { DiagnosticsScreen() }
                .tabItem { Label("ADB", systemImage: "terminal.fill") }
                .tag(BridgeTab.adb)
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result {
                Task { await store.installAPK(url) }
            }
        }
        .sheet(isPresented: $showingHomeResult) {
            CommandOutputSheet()
        }
        .onAppear {
            discovery.start()
            if !host.isEmpty {
                Task { await store.ensureConnection(host: host, port: port) }
            }
        }
        .onDisappear { discovery.stop() }
        .onChange(of: store.connected) { _, connected in
            if connected {
                editingAddress = false
                showingConnectionDetails = false
            }
        }
        .onChange(of: phase) { _, next in
            if next == .active, !host.isEmpty {
                Task { await store.ensureConnection(host: host, port: port) }
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
                Text(store.connected ? "ADB connected" : "Offline")
                    .font(.caption.bold())
                    .foregroundStyle(store.connected ? .green : .orange)
            }
            if store.connected {
                Label("Ready to run ADB shell commands", systemImage: "checkmark.circle.fill")
                    .font(.subheadline).foregroundStyle(.green)
                HStack {
                    Button(showingConnectionDetails ? "Hide connection" : "Change TV / address") {
                        editingAddress = false
                        showingConnectionDetails.toggle()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button("Disconnect") {
                        editingAddress = false
                        Task { await store.disconnect() }
                    }
                    .buttonStyle(.bordered)
                }
            }
            if !store.connected || showingConnectionDetails {
                TextField("TV IP or hostname", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .focused($editingAddress)
                HStack {
                    Text("ADB Port")
                    Spacer()
                    TextField("5555", value: $port, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 85)
                        .textFieldStyle(.roundedBorder)
                        .focused($editingAddress)
                }
                Button {
                    editingAddress = false
                    Task { await store.connect(host: host, port: port) }
                } label: {
                    HStack {
                        if store.connecting { ProgressView().tint(.white) }
                        else { Image(systemName: "link") }
                        Text(store.connected ? "Connect to different TV" : "Connect via ADB")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.connecting || host.isEmpty)
            }
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

    private var toolsLauncher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADB Toolbox").font(.title2.bold())
            Text("Choose what you want to do. No commands to type.")
                .font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                toolboxTile("Manage apps", icon: "square.grid.2x2", tab: .apps)
                toolboxTile("Remove bloat", icon: "shield.checkered", tab: .clean)
                toolboxTile("Default apps", icon: "app.badge.checkmark", tab: .defaults)
                toolboxTile("ADB commands & AI", icon: "terminal", tab: .adb)
            }
        }
    }

    private func toolboxTile(_ title: String, icon: String, tab: BridgeTab) -> some View {
        Button {
            editingAddress = false
            selectedTab = tab
        } label: {
            ActionLabel(title: title, icon: icon)
        }
        .buttonStyle(.plain)
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
            Text("One-tap ADB commands").font(.title3.bold())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                commandTile("Installed apps", icon: "square.grid.2x2", command: "pm list packages -3")
                commandTile("Storage", icon: "internaldrive", command: "df -h /data")
                commandTile("System info", icon: "cpu", command: "getprop ro.build.version.release")
                commandTile("Memory", icon: "memorychip", command: "cat /proc/meminfo")
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
            Task {
                await store.run(command, name: title)
                showingHomeResult = true
            }
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

private struct CommandOutputSheet: View {
    @EnvironmentObject private var store: BridgeStore
    @Environment(\.dismiss) private var dismiss
    @State private var aiResponse = ""
    @State private var aiBusy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("ADB command result", systemImage: "terminal")
                        .font(.title2.bold())
                    Text(store.lastOutput.isEmpty ? "The TV returned no output." : store.lastOutput)
                        .font(.system(.subheadline, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    let advice = ErrorAdvisor.explain(store.lastOutput)
                    Label(advice.title, systemImage: "lightbulb")
                        .font(.headline)
                    ForEach(advice.steps, id: \.self) { Text("• " + $0).font(.subheadline) }
                    Button {
                        aiBusy = true
                        Task {
                            aiResponse = await OnDeviceAI.explain(store.lastOutput)
                            aiBusy = false
                        }
                    } label: {
                        Label("Explain error with on-device AI", systemImage: "sparkles")
                    }
                    .disabled(aiBusy)
                    if aiBusy { ProgressView("Analyzing on iPhone…") }
                    if !aiResponse.isEmpty { Text(aiResponse).textSelection(.enabled) }
                }
                .padding()
            }
            .navigationTitle("Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { ShareLink(item: store.lastOutput) }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
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
    @State private var showOtherApps = false
    @State private var searchOther = ""

    private var matchedCandidates: [CleanupCandidate] {
        CleanupCatalog.sonyCandidates.filter { store.installedPackages.contains($0.id) }
    }
    private var otherApps: [String] {
        let reviewed = Set(CleanupCatalog.sonyCandidates.map(\.id))
        return Array(store.userPackages.filter {
            !reviewed.contains($0) &&
            CleanupCatalog.protectionReason(for: $0) == nil &&
            (searchOther.isEmpty || $0.localizedCaseInsensitiveContains(searchOther))
        }.prefix(60))
    }
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
                Text("\(matchedCandidates.count) recognized optional Sony/Google packages found. A package name alone is not evidence of spyware or malware.")
                    .font(.caption).foregroundStyle(.secondary)
                if matchedCandidates.isEmpty && store.connected {
                    Text("No packages from the optional cleanup list were found. You can still review downloaded apps below.")
                        .font(.subheadline)
                }
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
            Section("Other downloaded apps") {
                Button(showOtherApps ? "Hide other apps" : "Review downloaded apps (\(store.userPackages.count))") {
                    showOtherApps.toggle()
                }
                if showOtherApps {
                    Text("Only manually selected, non-protected apps can be disabled. Disabling does not uninstall them; a recovery snapshot is saved first.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Filter package names", text: $searchOther)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    ForEach(otherApps, id: \.self) { package in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(package)
                                .font(.system(.subheadline, design: .monospaced))
                                .textSelection(.enabled)
                            if store.enabledPackages.contains(package) {
                                Button("Review & disable") {
                                    selected = CleanupCandidate(
                                        id: package, title: package,
                                        group: "Downloaded apps",
                                        explanation: "User-selected app; not classified as malicious")
                                }
                                .buttonStyle(.bordered)
                                .disabled(!store.connected || store.busy)
                            } else if store.recoverablePackages.contains(package) {
                                Button("Restore") { Task { await store.restore(package) } }
                                    .buttonStyle(.bordered)
                            } else {
                                Text("Disabled already").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    if otherApps.count == 60 {
                        Text("Showing first 60 results. Filter by package name to narrow the list.")
                            .font(.caption).foregroundStyle(.secondary)
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
    private var browserChoices: [String] {
        store.installedPackages.filter { package in
            ["browser", "firefox", "reynard", "chrome", "brave", "opera", "edge", "vivaldi", "duckduckgo"].contains {
                package.localizedCaseInsensitiveContains($0)
            }
        }
    }
    private var tunerChoices: [String] {
        store.installedPackages.filter { package in
            ["iptv", "tuner", "tvx", "smarters", "live", "television"].contains {
                package.localizedCaseInsensitiveContains($0)
            }
        }
    }
    var body: some View {
        Form {
            Section {
                Text("Android roles and Sony firmware decide what can become a default. BridgeDeck verifies results and does not disable the stock launcher automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Browser") {
                if !browserChoices.isEmpty {
                    Picker("Choose installed browser", selection: $browserPackage) {
                        Text("Choose browser").tag("")
                        ForEach(browserChoices, id: \.self) { Text($0).tag($0) }
                    }
                }
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
                Button("Find available Home activities") {
                    Task { await store.run("cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME", name: "Find Home launchers") }
                }.disabled(!store.connected || store.busy)
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
                if !tunerChoices.isEmpty {
                    Picker("Choose installed TV app", selection: $tunerPackage) {
                        Text("Choose TV app").tag("")
                        ForEach(tunerChoices, id: \.self) { Text($0).tag($0) }
                    }
                }
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

private struct CommandPreset: Identifiable {
    let title: String
    let description: String
    let command: String
    var id: String { command }
}

private struct DiagnosticsScreen: View {
    @EnvironmentObject private var store: BridgeStore
    @State private var command = "getprop ro.product.cpu.abi"
    @State private var advanced = false
    @State private var aiResponse = ""
    @State private var aiBusy = false
    @State private var showingResult = false
    private let deviceCommands = [
        CommandPreset(title: "Android version", description: "OS version and security patch", command: "getprop ro.build.version.release; getprop ro.build.version.security_patch"),
        CommandPreset(title: "Device model & firmware", description: "Identify your Android TV", command: "getprop ro.product.model; getprop ro.build.display.id"),
        CommandPreset(title: "Available storage", description: "Free internal storage", command: "df -h /data"),
        CommandPreset(title: "Memory usage", description: "RAM totals and available memory", command: "cat /proc/meminfo"),
        CommandPreset(title: "CPU architecture", description: "APK compatibility", command: "getprop ro.product.cpu.abi")
    ]
    private let appsCommands = [
        CommandPreset(title: "Downloaded apps", description: "Apps installed by the user", command: "pm list packages -3"),
        CommandPreset(title: "All packages", description: "System and user apps", command: "pm list packages"),
        CommandPreset(title: "Disabled packages", description: "Review packages for restoration", command: "pm list packages -d"),
        CommandPreset(title: "Default browser", description: "Inspect Android's browser role", command: "cmd role holders android.app.role.BROWSER"),
        CommandPreset(title: "Default launcher", description: "Inspect Home activity", command: "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME")
    ]
    private let networkCommands = [
        CommandPreset(title: "Network addresses", description: "IP addresses for TV adapters", command: "ip addr show"),
        CommandPreset(title: "Network routes", description: "Connectivity and default route", command: "ip route"),
        CommandPreset(title: "Wi-Fi state", description: "Inspect Wi-Fi connectivity", command: "dumpsys wifi | head -n 70")
    ]
    private let diagnosticCommands = [
        CommandPreset(title: "Running processes", description: "Current apps and system processes", command: "ps -A"),
        CommandPreset(title: "Recent errors", description: "Latest Android error log messages", command: "logcat -d -t 100 -v brief '*:E'"),
        CommandPreset(title: "TV display", description: "Resolution and display density", command: "wm size; wm density"),
        CommandPreset(title: "Package manager help", description: "Commands available on this TV", command: "cmd package help")
    ]
    var body: some View {
        Form {
            Section {
                Label(store.connected ? "ADB connected to \(store.model)" : "Connect to TV on Home first",
                      systemImage: store.connected ? "checkmark.circle.fill" : "wifi.slash")
                    .foregroundStyle(store.connected ? .green : .orange)
                Text("Tap any command to run it. These presets read information without changing system settings.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Device & system") { commandRows(deviceCommands) }
            Section("Apps & defaults") { commandRows(appsCommands) }
            Section("Network") { commandRows(networkCommands) }
            Section("Troubleshooting") { commandRows(diagnosticCommands) }
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
        .navigationTitle("ADB Commands")
        .sheet(isPresented: $showingResult) { CommandOutputSheet() }
    }

    private func commandRows(_ commands: [CommandPreset]) -> some View {
        ForEach(commands) { preset in
            Button {
                Task {
                    await store.run(preset.command, name: preset.title)
                    showingResult = true
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title).font(.subheadline.weight(.semibold))
                    Text(preset.description).font(.caption).foregroundStyle(.secondary)
                    Text(preset.command).font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.cyan).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(!store.connected || store.busy)
        }
    }
}
