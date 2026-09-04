import AVFoundation
import CallKit
import CryptoKit
import Flutter
import PushKit
import UIKit
import UserNotifications

/// Does one delivered notification belong to a given Aura call?
///
/// Pure, and deliberately at file scope so it can be tested without a
/// notification centre. The three shapes are not hypothetical: an APNs alert
/// built by `buildBody` nests the payload under `data`, an FCM message places
/// its data map at the top level, and FCM also surfaces that map flattened
/// under `gcm.notification.*`. A matcher that knew only one of them would
/// leave the other transport's banner on screen after the call ended.
///
/// Matching is on the canonical call identity, so it can only ever select the
/// call it was asked about — two simultaneous calls carry two session ids.
func notificationBelongsToCall(
  _ info: [AnyHashable: Any],
  sessionId: String
) -> Bool {
  guard !sessionId.isEmpty else { return false }
  if let direct = info["sessionId"] as? String, direct == sessionId { return true }
  if let nested = info["data"] as? [AnyHashable: Any],
     let inner = nested["sessionId"] as? String, inner == sessionId {
    return true
  }
  if let flattened = info["gcm.notification.sessionId"] as? String,
     flattened == sessionId {
    return true
  }
  return false
}

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
///
/// EXCEPT WHERE THE JURISDICTION FORBIDS IT.
///
/// CallKit is a jurisdiction-constrained capability. In the China mainland App
/// Store storefront it may not be active at all (see CallCapabilityPolicy.swift
/// for the finding and the authority). This class therefore has two shapes:
///
///   available   the architecture described above, unchanged
///   prohibited  no CXProvider, no VoIP registration, no CallKit reporting;
///   withheld    Aura's own in-app incoming-call surface carries the call
///
/// The second shape is not a degraded call experience — Aura calling continues
/// in full through `incomingCallBridgeProvider`, the same socket-delivered path
/// every platform without CallKit already uses. What is removed is the SYSTEM
/// integration: the lock-screen call sheet, the system call log, and the VoIP
/// push that exists only to feed them.
///
/// THE PAIRING IS NOT OPTIONAL. Registering for VoIP pushes obliges this app to
/// report every one of them to CallKit. So the gate is placed at REGISTRATION,
/// not at reporting: in a prohibited jurisdiction Aura never asks for a VoIP
/// token, the backend therefore never sends a VoIP push, and the obligation
/// never arises. Gating only the report would have left the app receiving
/// pushes it was forbidden to answer — terminated by iOS, or in breach.
@main
@objc class AppDelegate: FlutterAppDelegate {
  private var voipRegistry: PKPushRegistry?
  private var provider: CXProvider?
  private let callController = CXCallController()
  private var channel: FlutterMethodChannel?

  /// The one place the jurisdiction question is asked. Every CallKit path in
  /// this file consults `callKitAllowed`; none of them compares a country code.
  private let storefrontAuthority = StorefrontAuthority()

  /// STARTS WITHHELD. The CallKit stack is built only when an established,
  /// permitted storefront says so — never as the default, never as a fallback.
  private var callCapability: CallKitCapability = .withheld

  private var callKitAllowed: Bool { callCapability.allowsCallKit }

  /// sessionId → the CallKit UUID we reported it under. CallKit is addressed
  /// by UUID and Aura by sessionId; without this map an "answered elsewhere"
  /// arriving from Dart cannot find the call it must end.
  private var uuidBySession: [String: UUID] = [:]
  private var sessionByUuid: [UUID: String] = [:]

  /// Calls this app answered ITSELF, via CXAnswerCallAction, because the
  /// person tapped Accept on an Aura surface rather than the CallKit screen.
  ///
  /// The answer action still runs through the provider delegate — that is how
  /// CallKit works — but re-emitting `answer` to Dart from it would ask Aura to
  /// join a call it is already joining. This remembers which answers we
  /// originated so the delegate can fulfil them without echoing.
  private var answeringLocally: Set<UUID> = []

  /// THE OUTGOING TWIN OF `answeringLocally`.
  ///
  /// `CXStartCallAction` comes back to this delegate whether the system
  /// originated it (a person tapping Aura in Recents or asking Siri) or Aura
  /// requested it because someone pressed Call in a conversation. Only the
  /// first is an instruction to place a call; treating our own request as one
  /// would start a second session for the call already being started.
  ///
  /// Same discipline, same reason, opposite direction.
  private var startingLocally: Set<UUID> = []

  /// Which calls Aura PLACED. `reportOutgoingCall(with:connectedAt:)` is only
  /// meaningful for an outgoing call, and Dart cannot be asked to know the
  /// direction — the media layer that observes "the far side is here" is the
  /// same code for both. Native knows, so native decides.
  private var outgoingCalls: Set<UUID> = []

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

    // THE STACK IS NO LONGER BUILT HERE.
    //
    // Build 35 called `configureCallKit()` and `registerForVoIPPushes()`
    // unconditionally on this line, which is precisely the defect Apple
    // rejected: a jurisdiction-constrained capability introduced globally with
    // no jurisdiction-aware policy in front of it. Construction now waits for
    // the storefront to be established and to be permitted. Until then — and
    // forever, in China mainland — there is no provider and no VoIP
    // registration to gate.
    storefrontAuthority.start { [weak self] capability in
      self?.applyCallCapability(capability)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Jurisdiction capability

  /// Bring the native call stack into line with what the storefront permits.
  ///
  /// Called on every capability TRANSITION, including transitions that happen
  /// while the app is running because the person changed their Apple Account
  /// region. Both directions are supported and neither destroys Aura's own
  /// call state — see the two helpers below.
  private func applyCallCapability(_ capability: CallKitCapability) {
    guard capability != callCapability else { return }
    let previous = callCapability
    callCapability = capability

    if capability.allowsCallKit {
      activateCallKitStack()
    } else {
      retractCallKitStack()
    }

    emit("callCapability", [
      "capability": capability.rawValue,
      "previous": previous.rawValue,
    ])
  }

  /// Idempotent. A second permitted resolution must not build a second
  /// provider or a second registry.
  private func activateCallKitStack() {
    if provider == nil {
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

    // THE ONLY LAPSE SIGNAL THE PLATFORM ACTUALLY GIVES.
    //
    // iOS exposes no callback for "the incoming-call UI stopped being
    // visible". It does expose the call ENDING, through CXCallObserver, and
    // that is the honest proxy: when the system retires an unanswered call
    // after its own ring window — shorter than Aura's 90s invitation TTL and
    // not ours to configure — the observer reports it ended. Nothing else in
    // this file would notice.
    //
    // The delegate is set here rather than at launch because `callObserver`
    // is CallKit, and in a prohibited jurisdiction there is no CallKit stack
    // to observe.
    callController.callObserver.setDelegate(self, queue: nil)

    if voipRegistry == nil {
      let registry = PKPushRegistry(queue: .main)
      registry.delegate = self
      registry.desiredPushTypes = [.voIP]
      voipRegistry = registry
    }
  }

  /// STOP BEING REACHABLE BY VOIP FIRST, THEN STOP BEING ABLE TO REPORT.
  ///
  /// The order matters. Clearing `desiredPushTypes` makes iOS invalidate the
  /// VoIP token, which fires `didInvalidatePushTokenFor`, which tells Dart to
  /// deactivate the backend's VoIP device row — so the server stops sending
  /// VoIP pushes to this device entirely. Only then is the provider taken
  /// down. Reversing the order would leave a window where a push could arrive
  /// with nothing able to report it.
  ///
  /// THE CALL ITSELF IS NOT ENDED. Any live session keeps running on Aura's
  /// in-app surface; what is retracted is the CallKit REPRESENTATION of it.
  /// This is why nothing here emits `end` to Dart — `onEnd` runs
  /// `handleTerminal(reason: "declined")`, which would hang up a call whose
  /// only problem is that the system UI may no longer render it.
  private func retractCallKitStack() {
    voipRegistry?.desiredPushTypes = []
    voipRegistry?.delegate = nil
    voipRegistry = nil

    callController.callObserver.setDelegate(nil as CXCallObserverDelegate?, queue: nil)

    if let p = provider {
      for (_, uuid) in uuidBySession {
        p.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
      }
      p.setDelegate(nil as CXProviderDelegate?, queue: nil)
      p.invalidate()
    }
    provider = nil

    uuidBySession.removeAll()
    sessionByUuid.removeAll()
    answeringLocally.removeAll()
    startingLocally.removeAll()
    outgoingCalls.removeAll()
  }

  // MARK: - CallKit call identity

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
      startingLocally.remove(uuid)
      outgoingCalls.remove(uuid)
    }
  }

  /// A CALL THAT IS STILL "ACTIVE" WHEN THE NEXT ONE ARRIVES IS A LEAK.
  ///
  /// This provider is configured for exactly one call group of one call, which
  /// is Aura's own rule: a person is in one call or none. CallKit enforces it
  /// literally — while a call it believes is active occupies that slot,
  /// `reportNewIncomingCall` is REFUSED, and a refused report is a phone that
  /// does not ring. Silently.
  ///
  /// Build 29 never hit this because its accept path reported every answered
  /// call ended immediately. That was a defect — answering a call ended it —
  /// but it also happened to be the only thing freeing the slot. Fixing the
  /// defect removed the accidental garbage collector, and build 30 stopped
  /// ringing after its first call.
  ///
  /// Ending them here is not a guess. A VoIP push for a NEW session is proof
  /// from the backend that any earlier call is over: both cannot be true at
  /// once under a one-call rule.
  ///
  /// Both ledgers are swept, in that order, because neither alone is enough:
  /// this class's map holds what THIS process reported and is reliably
  /// populated, while `callObserver.calls` can still show a call left behind
  /// by an earlier launch that the map no longer knows about.
  private func endStaleCalls(keeping current: UUID) {
    // Jurisdiction gate. Unreachable while prohibited — the only caller is the
    // VoIP push handler, which is itself gated and cannot run without a
    // registration this jurisdiction never made. Present because
    // `callObserver` and `reportCall` are CallKit, and no CallKit path in this
    // file is left ungated on the assumption that its caller was.
    guard callKitAllowed, let provider = provider else { return }

    // OUR OWN LEDGER FIRST — it is the one that is actually populated.
    //
    // CXCallObserver only reports reliably once it has a delegate, and this
    // process reported these calls itself, so the map is the authority for
    // anything it still holds. Sweeping only the observer meant sweeping an
    // empty list and clearing nothing, which is why the second locked call
    // still found the slot occupied.
    //
    // THE CASE THAT PRODUCES A STALE CALL: the CALLER ends it while this
    // device is locked and backgrounded. There is no local leave, so
    // _terminateSession never runs, and `call:terminal` needs a live socket
    // that a suspended app does not have. The call is genuinely over and only
    // CallKit still believes otherwise.
    for (session, uuid) in uuidBySession where uuid != current {
      provider.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
      emit("end", ["sessionId": session, "reason": "superseded"])
      forget(session)
    }

    // Then anything the system still shows that this process never reported —
    // a call left behind by a previous launch.
    for call in callController.callObserver.calls
    where call.uuid != current && !call.hasEnded {
      provider.reportCall(with: call.uuid, endedAt: Date(), reason: .remoteEnded)
      if let stale = sessionByUuid[call.uuid] { forget(stale) }
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

    case "callCapability":
      // Read-only. Lets Dart describe the surface truthfully rather than
      // inferring "iOS means CallKit", which stopped being true here.
      result(callCapability.rawValue)

    case "endCall":
      // Aura telling CallKit the call is over: answered on another device,
      // caller ended it, invite expired, or the person declined in-app. The
      // reason is carried through so the system call log is truthful.
      //
      // Gated: with no provider there is no system call to end, and the Aura
      // session's own terminal handling is untouched by this returning false.
      guard callKitAllowed, let provider = provider else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String,
            let uuid = uuidBySession[sessionId]
      else {
        result(false)
        return
      }
      let reason = (args["reason"] as? String) ?? "ended"
      provider.reportCall(with: uuid, endedAt: Date(), reason: Self.endedReason(reason))
      forget(sessionId)
      result(true)

    case "callConnected":
      // Gated: `callController.request` IS a CallKit invocation, and this is
      // the one CallKit call site that is driven by Dart rather than by a
      // push. In a prohibited jurisdiction the in-app accept path is already
      // the whole of the accept — there is no system sheet to dismiss.
      guard callKitAllowed else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String,
            let uuid = uuidBySession[sessionId]
      else {
        result(false)
        return
      }
      // ANSWERING IN THE APP MUST ANSWER THE SYSTEM CALL TOO.
      //
      // This was a no-op, and that is why accepting from Aura's own surface
      // left a full-screen CallKit ring on top of the call it had just
      // joined. The session was live, the media was flowing, and the system
      // was still asking whether to answer — so the app's call screen was
      // underneath an incoming-call UI that nothing was ever going to dismiss.
      // The founder saw it as "accept → full screen ring → call surface
      // buried", and as a camera that stayed on after the surface vanished.
      //
      // CallKit has no "report answered" for an incoming call; the supported
      // move is to REQUEST the answer action, exactly as the system would if
      // the person had tapped Answer on the CallKit screen. That dismisses the
      // incoming UI and moves the call to connected — one call, one state,
      // however the person chose to accept it.
      //
      // It deliberately does NOT end the call. Ending is what build 30 did and
      // what tore the call down; this is the opposite operation.
      answeringLocally.insert(uuid)
      let action = CXAnswerCallAction(call: uuid)
      callController.request(CXTransaction(action: action)) { [weak self] error in
        if let error = error {
          // Already answered, or already gone. Not fatal: the app is in the
          // call either way, and saying so beats failing silently.
          self?.answeringLocally.remove(uuid)
          NSLog("[callkit] local answer request failed: \(error.localizedDescription)")
        }
      }
      result(true)

    case "startOutgoingCall":
      // THE MISSING HALF OF CALLKIT PARTICIPATION.
      //
      // Incoming calls have been reported since 1.4.0, so iOS knows about a
      // call Aura received. It has never known about one Aura placed, because
      // nothing requested `CXStartCallAction` — and with no start action there
      // is nothing for the system to log, no entry in Recents, and no system
      // call for audio routing or a cellular call to interact with.
      //
      // Refusing here is NOT a failure. Where CallKit is prohibited by
      // storefront, or has not been activated, the Aura call proceeds exactly
      // as it does today and simply goes unreported. Dart treats `false` as
      // "not reported", never as "not called".
      guard callKitAllowed, let provider = provider else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String,
            !sessionId.isEmpty
      else {
        result(false)
        return
      }
      let calleeName = (args["displayName"] as? String).flatMap {
        $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0
      } ?? "Aura call"
      let isVideo = (args["video"] as? Bool) ?? false

      // Deterministic from the session id, exactly as the incoming path mints
      // it — so one session is one call UUID whichever direction it began in,
      // and a retry cannot produce a second call for the same session.
      let uuid = callUuid(for: sessionId)

      // Generic, never .phoneNumber. The incoming path refuses that already
      // because "mislabelling it puts a fake phone number in the system call
      // log", and an outgoing entry is written into the same log.
      let handle = CXHandle(type: .generic, value: calleeName)
      let action = CXStartCallAction(call: uuid, handle: handle)
      action.isVideo = isVideo
      action.contactIdentifier = calleeName

      startingLocally.insert(uuid)
      callController.request(CXTransaction(action: action)) { [weak self] error in
        guard let self = self else { return }
        if let error = error {
          // The call itself is unaffected — only its system representation is.
          // Drop the guard so a later system-originated start is not mistaken
          // for this one.
          self.startingLocally.remove(uuid)
          self.forget(sessionId)
          NSLog("[callkit] outgoing start request failed: \(error.localizedDescription)")
          result(false)
          return
        }
        // Ringing at the far end, as far as this device can know. Recents
        // needs this to distinguish a call that connected from one that did
        // not, and a duration from a zero.
        self.outgoingCalls.insert(uuid)
        provider.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
        result(true)
      }

    case "callOutgoingConnected":
      // Deliberately NOT folded into `callConnected`. That case requests
      // `CXAnswerCallAction` to dismiss an incoming sheet, which is the
      // opposite operation and is certified working; an outgoing call has no
      // sheet to dismiss and needs a connected timestamp instead.
      guard callKitAllowed, let provider = provider else {
        result(false)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let sessionId = args["sessionId"] as? String,
            let uuid = uuidBySession[sessionId],
            // Only a call Aura placed. Dart calls this from the media layer,
            // which is shared with incoming calls; reporting an outgoing
            // connect for a call that came IN is meaningless to CallKit and
            // would be a lie about direction in the system log.
            outgoingCalls.contains(uuid)
      else {
        result(false)
        return
      }
      provider.reportOutgoingCall(with: uuid, connectedAt: Date())
      outgoingCalls.remove(uuid)
      result(true)

    case "clearCallNotifications":
      // THE BANNER OUTLIVED THE CALL.
      //
      // A ringing call reaches an iPhone twice: CallKit (which retires itself
      // when the call is reported ended) and an ordinary APNs alert, which
      // does not. Nothing in this app ever removed the second one, so after a
      // call was accepted, declined, cancelled, expired or answered on another
      // device, "Incoming call…" stayed in Notification Center — actionable,
      // and about a call that no longer existed. `cancelNativeCallNotifications`
      // did this for Android and had no iOS counterpart. This is it.
      //
      // DELIBERATELY NOT GATED ON `callKitAllowed`. In a prohibited or
      // unresolved jurisdiction the banner is the ONLY incoming-call surface,
      // which makes clearing it more important there, not less.
      guard let args = call.arguments as? [String: Any],
            let sessionId = (args["sessionId"] as? String)?
              .trimmingCharacters(in: .whitespacesAndNewlines),
            !sessionId.isEmpty
      else {
        result(false)
        return
      }
      AppDelegate.clearDeliveredCallNotifications(sessionId: sessionId)
      result(true)

    case "voipToken":
      // Nil in a prohibited or unresolved jurisdiction, because no VoIP
      // registration was ever made. Dart registers no device row, so the
      // backend never targets this device with a VoIP push.
      result(callKitAllowed ? currentVoipToken : nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Remove every delivered or pending notification that belongs to one call.
  ///
  /// Matched on the payload rather than on an identifier we chose, because we
  /// did not choose it: these notifications are delivered by APNs from an FCM
  /// message, and their request identifiers are assigned by the system. What
  /// they do carry is the canonical call identity — `sessionId` — which both
  /// the FCM data map and the APNs body place in the user info, at the top
  /// level or under `data`. Both shapes are read, so neither transport's
  /// banner can survive the call it announced.
  ///
  /// Only this call's notifications are touched. `sessionId` is the canonical
  /// call identity, so two simultaneous calls have two ids and clearing one
  /// can never silence the other.
  /// CALLKIT WINS, AND THE LOSER IS RETRACTED — INCLUDING THE ONE STILL IN
  /// FLIGHT.
  ///
  /// The server sends this phone's ordinary banner silently, waits a bounded
  /// grace period for word that CallKit presented, and presents the fallback if
  /// none comes. That check happens at an instant; presentation can be
  /// established a moment after it. When it is, the server has already
  /// committed to a banner that has not landed yet, and clearing only what is
  /// on screen right now would miss it.
  ///
  /// So establishment clears twice: now, and once more after the grace period
  /// plus a margin, by which time anything the server committed to has either
  /// arrived or never will. This is a bounded reconciliation, not a poll — two
  /// sweeps, then done.
  ///
  /// The precedence itself is not a race: CallKit is the authority whenever it
  /// presents. A notification is only ever the fallback, and a fallback for a
  /// call the system is already showing is by definition the loser.
  private static func reconcilePresentationOwnership(sessionId: String) {
    clearDeliveredCallNotifications(sessionId: sessionId)
    // 3s server grace + margin for the push to travel and render.
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
      clearDeliveredCallNotifications(sessionId: sessionId)
    }
  }

  private static func clearDeliveredCallNotifications(sessionId: String) {
    let centre = UNUserNotificationCenter.current()

    centre.getDeliveredNotifications { notifications in
      let ids = notifications
        .filter { notificationBelongsToCall($0.request.content.userInfo, sessionId: sessionId) }
        .map { $0.request.identifier }
      guard !ids.isEmpty else { return }
      centre.removeDeliveredNotifications(withIdentifiers: ids)
      NSLog("[callkit] cleared \(ids.count) delivered notification(s) for \(sessionId)")
    }

    centre.getPendingNotificationRequests { requests in
      let ids = requests
        .filter { notificationBelongsToCall($0.content.userInfo, sessionId: sessionId) }
        .map { $0.identifier }
      guard !ids.isEmpty else { return }
      centre.removePendingNotificationRequests(withIdentifiers: ids)
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
    // A token that arrives after the jurisdiction turned prohibited — a
    // registration already in flight when the storefront changed — is dropped
    // rather than carried to the backend. Registering it would re-arm the very
    // VoIP delivery `retractCallKitStack()` just disarmed.
    guard callKitAllowed else { return }
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
    // NOT gated. This is the signal that retires the backend's VoIP device
    // row, and it is exactly what `retractCallKitStack()` provokes by clearing
    // `desiredPushTypes`. Suppressing it in a prohibited jurisdiction would
    // leave the server sending VoIP pushes to a device that will never again
    // report them.
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

    // THE LAST LINE OF DEFENCE, AND IT SHOULD NEVER BE REACHED.
    //
    // In a prohibited jurisdiction Aura never registers for VoIP pushes, so
    // iOS delivers none and this handler does not run. Reaching it means a
    // push was already in flight across a storefront transition, or a future
    // change re-registered without consulting the policy.
    //
    // The choice here is between two bad outcomes, and it is not close.
    // Reporting to CallKit would make CallKit active in China, which is the
    // prohibition itself. Not reporting risks iOS terminating the process for
    // an unanswered VoIP push. A terminated process is a recoverable local
    // failure affecting one call; an active CallKit sheet in China is the
    // legal breach the whole of this policy exists to prevent. So the report
    // does not happen, the call is handed to Aura's in-app surface, and the
    // handler completes.
    guard callKitAllowed, let provider = provider else {
      if !sessionId.isEmpty {
        emit("incomingCall", [
          "sessionId": sessionId,
          "callerName": callerName,
          "hasVideo": hasVideo,
          "raw": data.compactMapValues { $0 as? String },
        ])
      }
      completion()
      return
    }

    // MANDATORY AND UNCONDITIONAL — WITHIN A PERMITTED JURISDICTION. iOS kills
    // an app that takes a VoIP push without reporting a call, including when
    // the payload is malformed, which is why the guard above reports a
    // placeholder rather than returning.
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

    // REPORT FIRST. NOTHING MAY COME BEFORE THIS.
    //
    // Build 31 ran the stale-call sweep here, before the report, so that the
    // single call slot was already free. The reasoning was sound and the
    // placement was not: reading `callObserver.calls` inside the PushKit
    // handler on a cold background launch put a non-essential call in front of
    // the one call Apple requires, and a locked iPhone did not ring. Focus was
    // off, the push was delivered, and the app woke — the report simply never
    // reached the system.
    //
    // The obligation is unconditional, so it now runs unconditionally, and the
    // reconciliation becomes what it always should have been: a recovery from
    // a refusal, not a precondition for the attempt. A stale call still cannot
    // block a new one — it is cleared the moment it actually blocks something,
    // which is the only moment the clearing was ever needed.
    var emitAfterReport: (() -> Void)?

    let present = { [weak self] (retrying: Bool, error: Error?) -> Bool in
      guard let self = self else { return true }
      if let error = error {
        if !retrying {
          // The refusal may be the occupied slot. Free it and try once more —
          // once, because a second refusal is a real one (Do Not Disturb, a
          // blocked caller, a call already over) and retrying it would only
          // delay telling Aura the truth.
          return false
        }
        self.emit("callRejectedBySystem", [
          "sessionId": reportedSession,
          "reason": error.localizedDescription,
        ])
        self.forget(reportedSession)
      } else {
        // PRESENTATION IS NOW ESTABLISHED FOR THIS CALL ON THIS PHONE.
        //
        // This is the moment the ambiguity ends. Up to here "will CallKit
        // present?" was a prediction; `reportNewIncomingCall` returning no
        // error is the platform confirming it did. So the other transport's
        // banner — which the server sends whenever it cannot prove the VoIP
        // push was accepted, and which may have arrived anyway — is retracted
        // here rather than suppressed on a guess upstream.
        //
        // That is what makes the redundancy safe in both directions: the
        // banner is always available when CallKit does not present, and never
        // survives once CallKit does.
        AppDelegate.reconcilePresentationOwnership(sessionId: reportedSession)
        self.emit("incomingCall", [
          "sessionId": reportedSession,
          "callerName": callerName,
          "hasVideo": hasVideo,
          "raw": data.compactMapValues { $0 as? String },
        ])
      }
      return true
    }

    // Emitted AFTER the report is issued, never before it — this is a
    // diagnostic and diagnostics do not get to delay a ring. It marks the
    // moment the handler reached the report, which is the one fact the server
    // cannot see: a push accepted by APNs, an app that woke, and then silence
    // looks identical whether the report was refused or never attempted.
    emitAfterReport = { [weak self] in
      self?.emit("voipPushReceived", ["sessionId": reportedSession])
    }

    provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
      if present(false, error) {
        completion()
        return
      }
      guard let self = self else {
        completion()
        return
      }
      self.endStaleCalls(keeping: uuid)
      self.provider?.reportNewIncomingCall(with: uuid, update: update) { retryError in
        _ = present(true, retryError)
        completion()
      }
    }
    emitAfterReport?()
  }
}

// MARK: - System presentation lapse

extension AppDelegate: CXCallObserverDelegate {
  /// The system retired a call this process reported, and we did not ask it to.
  ///
  /// EVERY PATH THAT ENDS A CALL DELIBERATELY FORGETS IT FIRST — `endCall`,
  /// `CXEndCallAction`, the stale sweep, retraction. So a call that is still in
  /// the ledger when CallKit says it has ended was ended by the platform: the
  /// system ring window elapsed. That window is shorter than Aura's 90s
  /// invitation TTL and is not ours to set, which is exactly the gap that left
  /// build 35's locked iPhone with a call it could no longer see and an
  /// invitation the server still considered answerable.
  ///
  /// Aura does not invent a terminal state from this. The invitation's
  /// lifecycle stays the backend's. What this does is tell Dart that the SYSTEM
  /// surface is gone, so the in-app card — which is still live and still
  /// correct — becomes the surface, and any stale banner for the same call is
  /// retracted so nothing competes with it.
  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    guard call.hasEnded else { return }
    guard let sessionId = sessionByUuid[call.uuid] else { return }
    forget(sessionId)
    AppDelegate.clearDeliveredCallNotifications(sessionId: sessionId)
    emit("systemPresentationLapsed", ["sessionId": sessionId])
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
    // We requested this ourselves because the person accepted inside Aura.
    // Fulfil it so the system call moves to connected and the incoming UI
    // goes away, but do not tell Dart to join a call it is already joining.
    if answeringLocally.remove(action.callUUID) != nil {
      action.fulfill()
      return
    }
    // Fulfilled here, joined in Dart. If the join fails, Dart calls endCall
    // with reason "failed" — the sheet never hangs waiting on the network.
    emit("answer", ["sessionId": sessionId])
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    // Reached in two ways, and they mean opposite things.
    //
    // Aura requested it, because someone pressed Call: the session already
    // exists and is being joined. Fulfil so the system call becomes real, and
    // say nothing to Dart — telling it to start a call here would start a
    // second one for the session it is already in.
    if startingLocally.remove(action.callUUID) != nil {
      action.fulfill()
      return
    }

    // The SYSTEM originated it — Recents, Siri, a car. Aura has no session for
    // this yet and cannot invent one, because a call needs a conversation, an
    // acting identity and an invitation that only Aura can author.
    //
    // Failing is the honest answer: it tells the system the call did not
    // start, rather than showing a connected call that exists nowhere. When
    // system-originated calling is wanted it needs its own path, not a
    // silent reinterpretation of this one.
    action.fail()
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
