// KeyPair+ADBKeyPair.swift
// SwiftADB — extends KeyPair to conform to ADBKeyPair so it can be used with ADBPairing.

import Foundation
import Security
import ADBPairing

extension KeyPair: ADBKeyPair {
    // MARK: - secIdentity

    public func secIdentity() throws -> sec_identity_t {
        // The stock upstream method references non-public SecIdentityCreate.
        // TLS pairing is deliberately not enabled by the BridgeDeck 0.1 client.
        throw NSError(domain: "KeyPair", code: 11,
                      userInfo: [NSLocalizedDescriptionKey:
                        "TLS client identity unavailable in this legacy-ADB build"])
    }

    // MARK: - encodedPublicKey

    public func encodedPublicKey(deviceName: String) throws -> Data {
        let raw = try AndroidPubkey.encode(publicKey: publicKey)
        let b64 = raw.base64EncodedString()
        let formatted = b64 + " " + deviceName + "\0"
        return Data(formatted.utf8)
    }
}
