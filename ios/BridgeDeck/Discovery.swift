import Foundation

struct FoundTV: Identifiable, Hashable {
    let id: String
    let name: String
    let host: String
}

// Browses only BridgeDeck TV companions. A discovered TV is not automatically trusted.
final class TVDiscovery: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published private(set) var devices: [FoundTV] = []
    private let browser = NetServiceBrowser()
    private var resolving: [NetService] = []

    func start() {
        browser.delegate = self
        browser.searchForServices(ofType: "_bridgedeck._tcp.", inDomain: "local.")
    }

    func stop() {
        browser.stop()
        resolving.forEach { $0.stop() }
        resolving = []
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        resolving.append(service)
        service.delegate = self
        service.resolve(withTimeout: 8)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        devices.removeAll { $0.id == service.name }
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let name = sender.hostName, !name.isEmpty else { return }
        let host = name.hasSuffix(".") ? String(name.dropLast()) : name
        let entry = FoundTV(id: sender.name, name: sender.name, host: host)
        devices.removeAll { $0.id == entry.id }
        devices.append(entry)
        resolving.removeAll { $0 === sender }
    }
}
