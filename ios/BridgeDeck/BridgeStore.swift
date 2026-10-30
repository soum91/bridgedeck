import Foundation
import SwiftUI

struct CleanupCandidate: Identifiable, Hashable {
    let id: String
    let title: String
    let group: String
    let explanation: String
}

enum CleanupCatalog {
    // Candidates from Gathin23/cleanyourtv Sony profiles. Not validated on BRAVIA_VH22.
    static let sonyCandidates: [CleanupCandidate] = [
        .init(id: "tv.samba.ssm", title: "Samba TV", group: "Viewing analytics",
              explanation: "Automatic content recognition. Verify whether this package is enabled on your exact TV."),
        .init(id: "tv.samba.ssm.ui", title: "Samba TV interface", group: "Viewing analytics",
              explanation: "Companion interface for Samba TV tracking."),
        .init(id: "com.sonyericsson.idd.agent", title: "Sony usage reporting", group: "Telemetry",
              explanation: "Sony IDD usage data agent."),
        .init(id: "com.sony.dtv.promos", title: "Sony promotions", group: "Promotions",
              explanation: "Sony promotional content."),
        .init(id: "com.sony.dtv.sonyselect", title: "Sony Select", group: "Promotions",
              explanation: "Sony app suggestions and recommendations."),
        .init(id: "com.sony.dtv.sonytab", title: "Sony content tab", group: "Promotions",
              explanation: "Sony partner and content recommendations."),
        .init(id: "com.sony.dtv.demosupport", title: "Demo support", group: "Retail demo",
              explanation: "Store demonstration features; only disable if not in retail/demo mode."),
        .init(id: "com.sony.dtv.demosystemsupport", title: "Demo system", group: "Retail demo",
              explanation: "Support component for retail demonstration mode."),
        .init(id: "com.google.android.feedback", title: "Google feedback", group: "Telemetry",
              explanation: "Crash and feedback reporting. Disabling may affect feedback functions."),
        .init(id: "com.qterics.da.product", title: "Qterics device agent", group: "Advanced review",
              explanation: "Vendor agent. Functionality can vary by firmware; leave enabled unless reviewed.")
    ]

    static func protectionReason(for package: String) -> String? {
        let exact: Set<String> = [
            "android", "android.ext.services", "android.ext.shared",
            "com.android.systemui", "com.android.shell", "com.android.phone",
            "com.android.settings", "com.android.tv.settings",
            "com.google.android.tungsten.setupwraith",
            "com.google.android.apps.tv.launcherx",
            "com.google.android.tvlauncher",
            "com.google.android.leanbacklauncher",
            "com.soum91.bridgedeck.tv",
            "com.sony.dtv.tvx", "com.sony.dtv.tvapi",
            "com.sony.dtv.sonysystemservice", "com.sony.dtv.imeproxy"
        ]
        let prefixes = [
            "com.android.providers.", "com.google.android.overlay.modules",
            "com.google.android.permissioncontroller",
            "com.android.permissioncontroller", "com.android.packageinstaller",
            "com.google.android.packageinstaller", "com.android.ext.",
            "com.google.android.ext.", "com.android.modulemetadata",
            "com.sony.dtv.tvinput.", "com.sony.dtv.braviasync",
            "com.mediatek.", "com.cltv."
        ]
        if exact.contains(package) || prefixes.contains(where: package.hasPrefix) {
            return "TV core, tuner, launcher, input, Wi-Fi or Android infrastructure"
        }
        if package.contains("systemupdate") || package.contains("settingsprovider") {
            return "System update or settings service"
        }
        return nil
    }
}

enum ErrorAdvisor {
    static func explain(_ text: String) -> (title: String, steps: [String]) {
        let value = text.uppercased()
        if value.contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
            return ("Signing certificate mismatch", [
                "The installed app and replacement APK have different signing keys.",
                "Find an update signed with the same key.",
                "Only as a last resort: back up accessible data, uninstall, and reinstall. App data may be lost."
            ])
        }
        if value.contains("INSTALL_FAILED_NO_MATCHING_ABIS") {
            return ("Wrong CPU architecture", [
                "The APK does not contain native libraries supported by this TV.",
                "Check the TV's ABI and use a compatible armeabi-v7a or universal APK."
            ])
        }
        if value.contains("INSTALL_FAILED_VERSION_DOWNGRADE") {
            return ("Version downgrade blocked", [
                "The installed application has a higher Android versionCode.",
                "Install a newer version signed with the same key. Downgrading may require removing app data."
            ])
        }
        if value.contains("INSTALL_FAILED_INSUFFICIENT_STORAGE") {
            return ("Not enough storage", [
                "Check available TV storage and remove unused downloads or apps.",
                "Retry the installation after freeing space."
            ])
        }
        if value.contains("UNAUTHORIZED") || value.contains("AUTHENTICATION") {
            return ("ADB authorization needed", [
                "Check the TV screen for the Allow debugging prompt.",
                "If the TV previously forgot this iPhone, approve its RSA key again.",
                "Do not expose ADB port 5555 outside a trusted network."
            ])
        }
        if value.contains("TIMED OUT") || value.contains("NO ROUTE") || value.contains("REFUSED") {
            return ("TV not reachable", [
                "Confirm that network debugging is enabled and a port is actually listening.",
                "Check AP isolation and whether both devices can reach each other.",
                "Android TV 12 may require initial USB authorization to enable TCP ADB."
            ])
        }
        if value.contains("SECURITYEXCEPTION") || value.contains("PERMISSION DENIAL") {
            return ("Operation restricted", [
                "Android or Sony firmware denied this operation.",
                "Check whether a system setting or role controls this action.",
                "BridgeDeck will not bypass protected permissions or silently remove core services."
            ])
        }
        return ("Command output", [
            "Review the exact error text and the command that produced it.",
            "Open ADB Commands for common checks, or copy the result for deeper analysis."
        ])
    }
}

struct RecoverySnapshot: Codable {
    let date: Date
    let model: String
    let build: String
    let targetPackage: String
    let disabledBefore: String
    let homeBefore: String
    let installedPackagePath: String
}

@MainActor
final class BridgeStore: ObservableObject {
    @Published var connected = false
    @Published var connecting = false
    @Published var busy = false
    @Published var model = "Android TV"
    @Published var firmware = ""
    @Published var lastOutput = "Connect to your TV to get started."
    @Published var installedPackages: [String] = []
    @Published var userPackages: [String] = []
    @Published var enabledPackages: Set<String> = []
    @Published var disabledPackages: Set<String> = []
    @Published var mostRecentRecovery = ""
    @Published var recoverablePackages: Set<String> = []
    @Published var lastError = ""
    @Published var actionHistory: [String] = []

    private let adb = ADBClient()

    init() {
        loadRecoverySnapshots()
    }

    func connect(host: String, port: Int) async {
        guard !connecting else { return }
        connecting = true
        defer { connecting = false }
        do {
            try await adb.connect(host: host.trimmingCharacters(in: .whitespacesAndNewlines), port: port)
            connected = true
            lastError = ""
            UserDefaults.standard.set(host, forKey: "lastHost")
            UserDefaults.standard.set(port, forKey: "lastPort")
            model = try await adb.shell("getprop ro.product.model")
            firmware = try await adb.shell("getprop ro.build.display.id")
            lastOutput = "Connected: \(model)\n\(firmware)"
            await refreshPackages()
        } catch {
            connected = false
            report(error)
        }
    }

    func disconnect() async {
        await adb.disconnect()
        connected = false
        lastOutput = "Disconnected."
    }

    func ensureConnection(host: String, port: Int) async {
        guard !busy, !connecting, !host.isEmpty else { return }
        if connected {
            do {
                let response = try await adb.shell("echo BRIDGEDECK_READY")
                if response.contains("BRIDGEDECK_READY") { return }
            } catch {
                // The old TCP session may have expired while iOS was suspended.
            }
            connected = false
        }
        await connect(host: host, port: port)
    }

    func run(_ command: String, name: String = "Command") async {
        guard connected, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let output = try await adb.shell(command)
            lastOutput = "$ \(command)\n\(output)"
            lastError = ""
            actionHistory.insert("\(Date.formattedNow) • \(name)", at: 0)
        } catch { report(error) }
    }

    func refreshPackages() async {
        guard connected else { return }
        do {
            let all = try await adb.shell("pm list packages")
            let userInstalled = try await adb.shell("pm list packages -3")
            let enabled = try await adb.shell("pm list packages -e")
            let disabled = try await adb.shell("pm list packages -d")
            installedPackages = parsePackages(all)
            userPackages = parsePackages(userInstalled)
            enabledPackages = Set(parsePackages(enabled))
            disabledPackages = Set(parsePackages(disabled))
            lastError = ""
        } catch { report(error) }
    }

    func disable(_ candidate: CleanupCandidate) async {
        guard connected, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try validatePackage(candidate.id)
            if let reason = CleanupCatalog.protectionReason(for: candidate.id) {
                throw BridgeError.refusedProtectedPackage("\(candidate.id) (\(reason))")
            }
            guard enabledPackages.contains(candidate.id) else {
                lastOutput = "\(candidate.id) is not currently enabled."
                return
            }
            try await saveRecoverySnapshot(for: candidate.id)
            let output = try await adb.shell("pm disable-user --user 0 \(candidate.id)")
            guard output.contains("disabled-user") || output.lowercased().contains("disabled") else {
                lastOutput = output
                throw NSError(domain: "BridgeDeck.Disable", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "TV did not confirm the disable action."])
            }
            lastOutput = output + "\nRecovery snapshot: \(mostRecentRecovery)"
            recoverablePackages.insert(candidate.id)
            actionHistory.insert("\(Date.formattedNow) • Disabled \(candidate.id)", at: 0)
            await refreshPackages()
        } catch { report(error) }
    }

    func restore(_ package: String) async {
        guard connected, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try validatePackage(package)
            let output = try await adb.shell("pm enable \(package)")
            lastOutput = output
            recoverablePackages.remove(package)
            actionHistory.insert("\(Date.formattedNow) • Restored \(package)", at: 0)
            await refreshPackages()
        } catch { report(error) }
    }

    func installAPK(_ url: URL) async {
        guard connected, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            lastOutput = "Installing \(url.lastPathComponent)…"
            lastOutput = try await adb.installAPK(from: url)
            actionHistory.insert("\(Date.formattedNow) • Installed \(url.lastPathComponent)", at: 0)
            await refreshPackages()
        } catch { report(error) }
    }

    func setBrowser(_ package: String) async {
        guard await verifyInstalled(package) else { return }
        await run("cmd role add-role-holder --user 0 android.app.role.BROWSER \(package)",
                  name: "Set browser")
    }

    func setHome(_ component: String) async {
        let package = String(component.split(separator: "/").first ?? "")
        let validComponent = component.range(
            of: #"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+/[A-Za-z0-9_.$]+$"#,
            options: .regularExpression
        ) != nil
        guard validComponent else {
            lastError = "Use an activity component such as com.example.launcher/.MainActivity."
            return
        }
        guard await verifyInstalled(package) else { return }
        await run("cmd package set-home-activity \(component)", name: "Set Home activity")
        // Sony's stock launcher can ignore the preference; check the resolver.
        await run("cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME",
                  name: "Verify Home")
    }

    func launchTuner(_ package: String) async {
        guard await verifyInstalled(package) else { return }
        await run("monkey -p \(package) -c android.intent.category.LAUNCHER 1",
                  name: "Launch TV app")
    }

    private func verifyInstalled(_ package: String) async -> Bool {
        do {
            try validatePackage(package)
            guard installedPackages.contains(package) else {
                lastError = "\(package) is not installed on the connected TV."
                return false
            }
            return true
        } catch {
            report(error)
            return false
        }
    }

    private func validatePackage(_ package: String) throws {
        guard package.range(
            of: #"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#,
            options: .regularExpression
        ) != nil else { throw BridgeError.invalidPackage }
    }

    private func saveRecoverySnapshot(for package: String) async throws {
        let record = RecoverySnapshot(
            date: Date(), model: model, build: firmware, targetPackage: package,
            disabledBefore: try await adb.shell("pm list packages -d"),
            homeBefore: try await adb.shell(
                "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME"),
            installedPackagePath: try await adb.shell("pm path \(package)")
        )
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recovery", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "recovery-\(Int(Date().timeIntervalSince1970))-\(package).json"
        try JSONEncoder().encode(record).write(to: directory.appendingPathComponent(filename),
                                                options: .atomic)
        mostRecentRecovery = filename
    }

    private func loadRecoverySnapshots() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recovery", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let snapshot = try? JSONDecoder().decode(RecoverySnapshot.self, from: data) else {
                continue
            }
            let wasAlreadyDisabled = snapshot.disabledBefore
                .split(separator: "\n").contains("package:\(snapshot.targetPackage)"[...])
            if !wasAlreadyDisabled { recoverablePackages.insert(snapshot.targetPackage) }
        }
    }

    private func parsePackages(_ output: String) -> [String] {
        output.split(separator: "\n").compactMap {
            let value = String($0)
            return value.hasPrefix("package:") ? String(value.dropFirst(8)) : nil
        }.sorted()
    }

    private func report(_ error: Error) {
        lastError = error.localizedDescription
        lastOutput = error.localizedDescription
    }
}

private extension Date {
    static var formattedNow: String {
        Date().formatted(date: .abbreviated, time: .shortened)
    }
}
