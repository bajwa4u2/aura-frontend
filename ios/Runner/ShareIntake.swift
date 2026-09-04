import Flutter
import Foundation

/// THE MAIN APP'S SIDE OF THE SHARE HANDOFF.
///
/// The Share Extension captures content into a shared container and stops.
/// This reads what is there, takes it into Aura's own storage, and empties the
/// container. Everything after that is the same path an Android share takes:
/// one channel, one inbox, one governed destination.
///
/// ── THE GROUP IS TRANSIT, NOT STORAGE ────────────────────────────────────
///
/// Content is MOVED out and the transit directory is deleted. Two processes
/// can read that container, so anything left in it stays readable by a process
/// the person did not open — which is exactly the property the extension was
/// designed not to have. Emptying it is part of the handoff rather than
/// housekeeping that can be skipped.
///
/// ── AND IT CARRIES NO CREDENTIAL, IN EITHER DIRECTION ────────────────────
///
/// Nothing is written into the group by this side. The extension is given
/// nothing to act with, so there is nothing here to give it.
enum ShareIntake {
    static let channelName = "org.auraplatform.app/share_intake"

    private static let appGroup = "group.org.auraplatform.app"
    private static let transitDirectory = "share_intake"
    private static let manifestName = "manifest.json"

    /// Aura's own copy of shared content, inside the app container.
    private static let localDirectory = "share_intake"

    static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "consumePendingShare":
            // Drains the container. Returning at most once per share is what
            // stops the same content being presented twice — which on that
            // surface would mean publishing it twice.
            result(consume())

        case "releaseSharedContent":
            clearLocal()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Everything waiting, as one envelope, or nil.
    ///
    /// SEVERAL SHARES CAN BE WAITING. Someone can share twice without opening
    /// Aura in between, and the second must not overwrite the first. Each
    /// transit directory is drained, oldest first, and their payloads are
    /// carried in one envelope so nothing is silently dropped.
    private static func consume() -> [String: Any]? {
        let manager = FileManager.default
        guard let container = manager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        else { return nil }

        let transit = container.appendingPathComponent(transitDirectory, isDirectory: true)
        guard let directories = try? manager.contentsOfDirectory(
            at: transit,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let ordered = directories.sorted { left, right in
            modified(left) < modified(right)
        }

        var payloads: [[String: Any]] = []
        var refusals: [String] = []
        var subject: String?
        var receivedAt: Int?

        for directory in ordered {
            let manifestURL = directory.appendingPathComponent(manifestName)
            // A directory with no manifest is a share still being written, or
            // one the extension was killed in the middle of. It is left alone
            // rather than picked up half-finished.
            guard manager.fileExists(atPath: manifestURL.path),
                  let data = try? Data(contentsOf: manifestURL),
                  let manifest = (try? JSONSerialization.jsonObject(with: data))
                  as? [String: Any]
            else { continue }

            for raw in (manifest["payloads"] as? [[String: Any]]) ?? [] {
                if let payload = adopt(raw) { payloads.append(payload) }
            }
            refusals.append(contentsOf: (manifest["refusals"] as? [String]) ?? [])
            if subject == nil { subject = manifest["subject"] as? String }
            if receivedAt == nil { receivedAt = manifest["receivedAt"] as? Int }

            // The transit copy is gone whether or not every item in it could
            // be adopted. Leaving a partially-drained directory behind would
            // re-present the same content on the next launch.
            try? manager.removeItem(at: directory)
        }

        guard !payloads.isEmpty || !refusals.isEmpty else { return nil }

        return [
            "platform": "ios",
            "payloads": payloads,
            "refusals": refusals,
            "receivedAt": receivedAt ?? Int(Date().timeIntervalSince1970 * 1000),
            "subject": subject as Any,
        ]
    }

    /// Take one payload out of the shared container and into Aura's own.
    private static func adopt(_ raw: [String: Any]) -> [String: Any]? {
        guard let kind = raw["kind"] as? String else { return nil }

        // Text and URLs are values; there is nothing to move.
        if kind != "file" {
            return (raw["text"] as? String)?.isEmpty == false ? raw : nil
        }

        guard let sourcePath = raw["filePath"] as? String else { return nil }
        let source = URL(fileURLWithPath: sourcePath)
        guard let destination = localURL(for: source.lastPathComponent) else {
            return nil
        }

        let manager = FileManager.default
        do {
            if manager.fileExists(atPath: destination.path) {
                try manager.removeItem(at: destination)
            }
            try manager.moveItem(at: source, to: destination)
        } catch {
            // A move that fails leaves the original where it is; the caller
            // deletes the transit directory regardless, so the content is not
            // left readable by the other process.
            return nil
        }

        var adopted = raw
        adopted["filePath"] = destination.path
        return adopted
    }

    private static func localURL(for name: String) -> URL? {
        let manager = FileManager.default
        guard let caches = manager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return nil }

        let directory = caches.appendingPathComponent(localDirectory, isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }

    /// Content someone shared and then abandoned should not sit on their
    /// device. Called once Dart has read the bytes it was given.
    private static func clearLocal() {
        let manager = FileManager.default
        guard let caches = manager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return }
        let directory = caches.appendingPathComponent(localDirectory, isDirectory: true)
        guard let contents = try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        for item in contents { try? manager.removeItem(at: item) }
    }

    private static func modified(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }
}
