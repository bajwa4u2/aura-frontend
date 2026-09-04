import UIKit
import UniformTypeIdentifiers

/// AURA'S SHARE EXTENSION. IT CAPTURES, AND THAT IS ALL IT DOES.
///
/// ── WHAT THIS PROCESS DELIBERATELY CANNOT DO ─────────────────────────────
///
/// It cannot publish, send, choose a destination, choose an acting identity,
/// or find out who is signed in. It holds no access token and no refresh
/// token, and none is placed in the App Group for it to find — founder ruling:
/// *"Do not place auth secrets into a Share Extension App Group."*
///
/// That is not caution for its own sake. A share extension is a SECOND PROCESS
/// with its own lifetime, launched by another application, running outside the
/// app the person signed into. Giving it a credential would mean Aura could
/// publish from a process the person did not open, and every rule the main app
/// enforces about identity and consequence would need a second implementation
/// here, in a constrained sheet, to be enforced at all. So the extension is
/// given nothing to be trusted with.
///
/// ── WHY IT SHOWS NO COMPOSER ─────────────────────────────────────────────
///
/// `SLComposeServiceViewController` — the familiar text box with a Post button
/// — is the wrong base class for this, because a Post button is a promise to
/// publish and this process must not. Capture is not composition. What the
/// person sees here is a moment of acknowledgement; the choosing happens in
/// Aura, on `/share/incoming`, where the destination, the identity and the
/// consequence are all on screen.
///
/// ── HOW THE CONTENT GETS ACROSS ──────────────────────────────────────────
///
/// Into the App Group container, as files, with a manifest beside them. The
/// group is a TRANSIT AREA and nothing else: the main app moves the files into
/// its own storage and deletes what it found, so content does not accumulate
/// in a place two processes can read.
///
/// ── AND WHY IT DOES NOT INSIST ON OPENING AURA ───────────────────────────
///
/// It asks, through `NSExtensionContext.open` — the documented API — and does
/// not care whether the answer is yes. Share extensions are not guaranteed to
/// be allowed to open their host app, and the usual way round that is to walk
/// the responder chain until `UIApplication` turns up and call `openURL:` on
/// it. That is a trick for getting past a restriction rather than a use of the
/// API, on an app that is currently working through an App Store rejection.
///
/// It is also unnecessary. The main app drains this container every time it
/// becomes active, so the share is waiting whether Aura opens now or in an
/// hour. The worst case is that the person switches to Aura themselves and
/// finds their content already there.
final class ShareViewController: UIViewController {
    /// Shared with the main app. The ONLY thing that ever crosses here is
    /// content the person explicitly shared.
    private static let appGroup = "group.org.auraplatform.app"
    private static let transitDirectory = "share_intake"

    /// The same ceiling as every other door into Aura, mirroring
    /// `MediaCapacity` and the backend's `maxBytesFor`. A second, smaller
    /// number here would mean a file Aura accepts from the picker is refused
    /// from the share sheet, for a reason nobody could work out.
    private static let maxItemBytes = 150 * 1024 * 1024

    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        presentAcknowledgement()
        capture()
    }

    // MARK: - Capture

    private func capture() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let attachments = items.flatMap { $0.attachments ?? [] }

        guard !attachments.isEmpty else {
            finish()
            return
        }

        let subject = items.compactMap { $0.attributedContentText?.string }
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let directory = makeTransitDirectory()
        guard let directory else {
            finish()
            return
        }

        var payloads: [[String: Any]] = []
        var refusals: [String] = []
        let group = DispatchGroup()
        let lock = NSLock()

        for provider in attachments {
            group.enter()
            load(provider, into: directory) { payload, refusal in
                lock.lock()
                if let payload { payloads.append(payload) }
                if let refusal { refusals.append(refusal) }
                lock.unlock()
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else {
                // Torn down mid-capture. The request is still completed, so
                // the sharing app is not left waiting on a sheet that will
                // never answer.
                return
            }
            self.writeManifest(
                in: directory,
                payloads: payloads,
                refusals: refusals,
                subject: subject
            )
            self.askToOpenAura()
            self.finish()
        }
    }

    /// Resolve one shared item into a file, or into a reason it could not be.
    ///
    /// EVERYTHING RECORDED HERE IS A CLAIM. The type identifier is what the
    /// sending application said, the filename is what it called the file, and
    /// neither is checked. Aura decides what something is by reading the
    /// bytes, in Dart, through the same intake door a picker or a paste uses —
    /// so this process classifies nothing.
    private func load(
        _ provider: NSItemProvider,
        into directory: URL,
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        // Text and URLs first: they are values rather than files, and asking
        // for them as files produces a temporary file wrapper nobody wants.
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                if let url = item as? URL, !url.isFileURL {
                    completion(["kind": "url", "text": url.absoluteString], nil)
                } else if let url = item as? URL {
                    self.copyFile(at: url, into: directory, completion: completion)
                } else {
                    completion(nil, nil)
                }
            }
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                guard let text = item as? String,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    completion(nil, nil)
                    return
                }
                completion(["kind": "text", "text": text], nil)
            }
            return
        }

        // Everything else is content. `loadFileRepresentation` hands over a
        // file that exists only for the duration of the callback, which is
        // exactly why it is copied inside it rather than remembered.
        let identifier = provider.registeredTypeIdentifiers.first
            ?? UTType.data.identifier
        provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, _ in
            guard let url else {
                completion(nil, "One item could not be read from the app that shared it.")
                return
            }
            self.copyFile(at: url, into: directory, completion: completion)
        }
    }

    private func copyFile(
        at source: URL,
        into directory: URL,
        completion: @escaping ([String: Any]?, String?) -> Void
    ) {
        let name = source.lastPathComponent
        let attributes = try? FileManager.default.attributesOfItem(atPath: source.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0

        // Refused before it is copied. An enormous file should cost a message
        // rather than fill someone's device on the way to being rejected.
        if size > Self.maxItemBytes {
            completion(nil, "\(name) is too large to share into Aura.")
            return
        }

        let copyURL = directory.appendingPathComponent(
            "\(UUID().uuidString)-\(Self.safeName(name))"
        )
        do {
            try FileManager.default.copyItem(at: source, to: copyURL)
        } catch {
            completion(nil, "\(name) could not be read from the app that shared it.")
            return
        }

        completion(
            [
                "kind": "file",
                "filePath": copyURL.path,
                "fileName": name,
                // What the sending application claimed. A hint, never the
                // answer.
                "declaredMimeType": Self.mimeHint(for: source) as Any,
                "sizeBytes": size,
            ],
            nil
        )
    }

    // MARK: - Handoff

    private func makeTransitDirectory() -> URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
        else { return nil }

        let directory = container
            .appendingPathComponent(Self.transitDirectory, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            return nil
        }
        return directory
    }

    /// The manifest is written LAST, and it is what makes the share visible.
    ///
    /// The main app looks for `manifest.json` and ignores a directory without
    /// one, so a share that is still being written — or one this process was
    /// killed in the middle of — is never picked up half-finished.
    private func writeManifest(
        in directory: URL,
        payloads: [[String: Any]],
        refusals: [String],
        subject: String?
    ) {
        // Nothing survived. The directory is removed rather than left behind:
        // the app only reads directories that have a manifest, so an empty one
        // would sit in the shared container forever, accumulating one per
        // share that produced nothing.
        guard !payloads.isEmpty || !refusals.isEmpty else {
            try? FileManager.default.removeItem(at: directory)
            return
        }

        var manifest: [String: Any] = [
            "platform": "ios",
            "payloads": payloads,
            "refusals": refusals,
            "receivedAt": Int(Date().timeIntervalSince1970 * 1000),
        ]
        if let subject, !subject.isEmpty { manifest["subject"] = subject }

        guard let data = try? JSONSerialization.data(withJSONObject: manifest) else {
            return
        }
        try? data.write(to: directory.appendingPathComponent("manifest.json"))
    }

    /// Ask, once, through the documented API, and carry on either way.
    private func askToOpenAura() {
        // Three slashes on purpose: an EMPTY host, so the path is exactly
        // `/share/incoming`. With a host ("aura://share/incoming") Flutter
        // reports the route as `/incoming` and the person lands nowhere.
        guard let url = URL(string: "aura:///share/incoming") else { return }
        extensionContext?.open(url, completionHandler: nil)
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    // MARK: - Presentation

    /// A moment of acknowledgement, and no controls.
    ///
    /// There is nothing to decide here, so there is nothing to press. Offering
    /// a button in this sheet would be offering a decision this process is not
    /// allowed to carry out.
    private func presentAcknowledgement() {
        view.backgroundColor = UIColor(red: 0.051, green: 0.082, blue: 0.125, alpha: 1)

        label.text = "Saved for Aura"
        label.textColor = UIColor(red: 0.886, green: 0.925, blue: 0.961, alpha: 1)
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(
                greaterThanOrEqualTo: view.leadingAnchor, constant: 24
            ),
            label.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor, constant: -24
            ),
        ])
    }

    // MARK: - Helpers

    private static func safeName(_ name: String) -> String {
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-"
        )
        let cleaned = String(name.unicodeScalars.filter { allowed.contains($0) })
        return cleaned.isEmpty ? "item" : String(cleaned.prefix(80))
    }

    /// The system's own guess from the extension, passed on as a hint.
    private static func mimeHint(for url: URL) -> String? {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return nil
        }
        return type.preferredMIMEType
    }
}
