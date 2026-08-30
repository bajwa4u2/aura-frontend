import AVFoundation
import CallKit
import CryptoKit
import Flutter
import PushKit
import UIKit

/// APPLE'S INCOMING-CALL ARCHITECTURE. NOT A NOTIFICATION.
///
/// An FCM alert is a banner: it can be swiped away, it cannot ring over the
/// lock screen, and it is not what iOS users understand a call to be. Apple's
/// supported path is a PushKit VoIP push reported immediately to CallKit, and
/// the two halves are not separable — iOS terminates an app that receives a
/// VoIP push and fails to report a call. Every early-return below therefore
/// still reports something.
///
/// AURA REMAINS THE CALL AUTHORITY. CallKit here is a presentation surface and
/// an input device. It never decides that a call is ringing, answered, declined
/// or over; it renders what the backend already decided and hands user intent
/// back to Dart. The backend's session/invite lifecycle stays canonical.
@main
@objc class AppDelegate: FlutterAppDelegate {
  private var voipRegistry: PKPushRegistry?
  private var provider: CXProvider?
  private let callController = CXCallController()
  private var channel: FlutterMethodChannel?

  /// sessionId → the CallKit UUID we reported it under. CallKit is addressed
  /// by UUID and Aura by sessionId; without this map an "answered elsewhere"
  /// arriving from Dart cannot find the call it must end.
  private var uuidBySession: [String: UUID] = [:]
  private var sessionByUuid: [UUID: String] = [:]

  /// A VoIP push can outrun the Flutter engine on a cold start. Anything that
  /// arrives before Dart is listening is held here rather than dropped — the
  /// call is already on screen by then, so losing it would strand the user on a
  /// CallKit sheet that answers into nothing.
  private var pendingEvents: [[String: Any]] = []
  private var dartReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let ch = FlutterMethodChannel(
        name: "org.auraplatform.app/callkit",
        binaryMessenger: controller.binaryMessenger
      )
      channel = ch
      ch.setMethodCallHandler { [weak self] call, result in
        self?.handle(call, result: result)
      }
    }

    configureCallKit()
    registerForVoIPPushes()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - CallKit provider

  private func configureCallKit() {
    let configuration = CXProviderConfiguration(localizedName: "Aura")
    configuration.supportsVideo = true
    configuration.maximumCallsPerCallGroup = 1
    configuration.maximumCallGroups = 1
    // Generic, not phoneNumber/emailAddress: an Aura handle is neither, and
    // mislabelling it puts a fake phone number in the system call log.
    configuration.supportedHandleTypes = [.generic]
    if let icon = UIImage(named: "AppIcon") {
      configuration.iconTemplateImageData = icon.pngData()
    }

    let p = CXProvider(configuration: configuration)
    p.setDelegate(self, queue: nil)
    provider = p
  }

  private func registerForVoIPPushes() {
    let registry = PKPushRegistry(queue: .main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry
  }

  /// CallKit is addressed by UUID; Aura sessions are not UUIDs. Deriving the
  /// UUID from the sessionId makes the mapping deterministic, which is what
  /// gives duplicate suppression for free: a retried VoIP push for the same
  /// session reports the SAME UUID, and CallKit coalesces it instead of
  /// stacking a second incoming-call screen.
  private func callUuid(for sessionId: String) -> UUID {
    if let existing = uuidBySession[sessionId] { return existing }
    var bytes = [UInt8](SHA256.hash(data: Data(sessionId.utf8))).prefix(16).map { $0 }
    bytes[6] = (bytes[6] & 0x0F) | 0x50  // version 5-shaped
    bytes[8] = (bytes[8] & 0x3F) | 0x80  // RFC 4122 variant
    let uuid = NSUUID(uuidBytes: bytes) as UUID
    uuidBySession[sessionId] = uuid
    sessionByUuid[uuid] = sessionId
    return uuid
  }

  private func forget(_ sessionId: String) {
    if let uuid = uuidBySession.removeValue(forKey: sessionId) {
      sessionByUuid.removeValue(forKey: uuid)
    }
  }

  private func emit(_ event: String, _ body: [String: Any]) {
    var payload = body
    payload["event"] = event
    guard dartReady, let channel = channel else {
      pendingEvents.append(payload)
      return
    }
    channel.invokeMethod("onCallEvent", arguments: payload)
  }

  // MARK: - Method channel (Dart → native)

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ready":
      dartReady = true
      let queued = pendingEvents
      pendingEvents = []
      queued.forEach { channel?.invokeMethod("onCallEvent", arguments: $0) }
      result(nil)

    case "endCall":
      // Aura telling CallKit the call is over: answered on another device,
      // caller ended it, invite expired, or the person declined in-app. The
      // reason is carried through so the system call log is truthful.
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String,
            let uuid = uuidBySession[sessionId]
      else {
        result(false)
        return
      }
      let reason = (args["reason"] as? String) ?? "ended"
      provider?.reportCall(with: uuid, endedAt: Date(), reason: Self.endedReason(reason))
      forget(sessionId)
      result(true)

    case "callConnected":
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String,
            let uuid = uuidBySession[sessionId]
      else {
        result(false)
        return
      }
      // An INCOMING CallKit call has no "report connected" API: the system
      // considers it connected the moment CXAnswerCallAction is fulfilled,
      // which the delegate below already does. reportOutgoingCall() used to
      // be called here against an incoming call's UUID — an API mismatch
      // CallKit simply ignores, so it read as a working connection signal
      // while doing nothing at all.
      //
      // Kept as an explicit acknowledgement rather than deleted, because
      // Dart's accept path calls it and the honest answer to "is this call
      // connected" is yes — established at answer time, not here.
      _ = uuid
      result(true)

    case "voipToken":
      result(currentVoipToken)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func endedReason(_ raw: String) -> CXCallEndedReason {
    switch raw.lowercased() {
    case "answeredelsewhere": return .answeredElsewhere
    case "declined": return .declinedElsewhere
    case "expired", "unanswered": return .unanswered
    case "failed": return .failed
    default: return .remoteEnded
    }
  }

  private var currentVoipToken: String?
}

// MARK: - PushKit

extension AppDelegate: PKPushRegistryDelegate {
  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate pushCredentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    currentVoipToken = token
    // The VoIP token is NOT the FCM token and must not be registered as one.
    // It is a separate credential with its own rotation, carried to the
    // backend as a distinct APNS device row.
    emit("voipToken", ["token": token])
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard type == .voIP else { return }
    currentVoipToken = nil
    emit("voipTokenInvalidated", [:])
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    let data = payload.dictionaryPayload
    let sessionId = (data["sessionId"] as? String)
      ?? (data["realtimeSessionId"] as? String)
      ?? ""
    let callerName = (data["callerDisplayName"] as? String)
      ?? (data["callerHandle"] as? String)
      ?? "Aura call"
    let hasVideo = ((data["mediaMode"] as? String) ?? "").lowercased().contains("video")

    // MANDATORY AND UNCONDITIONAL. iOS kills an app that takes a VoIP push
    // without reporting a call — including when the payload is malformed, which
    // is why the guard above reports a placeholder rather than returning.
    let reportedSession = sessionId.isEmpty ? "unknown-\(UUID().uuidString)" : sessionId
    let uuid = callUuid(for: reportedSession)

    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: callerName)
    update.localizedCallerName = callerName
    update.hasVideo = hasVideo
    // Nothing about the conversation is projected: a lock screen is a public
    // surface and the caller's name is the whole of what belongs on it.
    update.supportsGrouping = false
    update.supportsUngrouping = false
    update.supportsHolding = false
    update.supportsDTMF = false

    provider?.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
      if let error = error {
        // Reported and immediately refused (Do Not Disturb, a blocked caller,
        // an already-ended call). Tell Aura so the invite is not left pending.
        self?.emit("callRejectedBySystem", [
          "sessionId": reportedSession,
          "reason": error.localizedDescription,
        ])
        self?.forget(reportedSession)
      } else {
        self?.emit("incomingCall", [
          "sessionId": reportedSession,
          "callerName": callerName,
          "hasVideo": hasVideo,
          "raw": data.compactMapValues { $0 as? String },
        ])
      }
      completion()
    }
  }
}

// MARK: - CallKit delegate (user intent → Aura)

extension AppDelegate: CXProviderDelegate {
  func providerDidReset(_ provider: CXProvider) {
    uuidBySession.removeAll()
    sessionByUuid.removeAll()
    emit("providerReset", [:])
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    guard let sessionId = sessionByUuid[action.callUUID] else {
      action.fail()
      return
    }
    // Fulfilled here, joined in Dart. If the join fails, Dart calls endCall
    // with reason "failed" — the sheet never hangs waiting on the network.
    emit("answer", ["sessionId": sessionId])
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    if let sessionId = sessionByUuid[action.callUUID] {
      emit("end", ["sessionId": sessionId])
      forget(sessionId)
    }
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    if let sessionId = sessionByUuid[action.callUUID] {
      emit("muted", ["sessionId": sessionId, "muted": action.isMuted])
    }
    action.fulfill()
  }

  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    emit("audioSessionActivated", [:])
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    emit("audioSessionDeactivated", [:])
  }
}
