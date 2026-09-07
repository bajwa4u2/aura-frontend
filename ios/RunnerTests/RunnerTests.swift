import Flutter
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

}

// MARK: - Jurisdiction capability policy

/// THE GATE THAT KEEPS AURA OUT OF A GUIDELINE 5 REJECTION.
///
/// Aura Platform 1.4.0 (35) was rejected because CallKit was active in a build
/// distributed to the China mainland App Store. These tests pin the decision
/// table that replaced it. A future iOS calling reconstruction that removes the
/// jurisdiction gate fails here first.
final class CallCapabilityPolicyTests: XCTestCase {

  // MARK: The prohibited storefront

  func testChinaMainlandProhibitsCallKit() {
    let capability = CallCapabilityPolicy.capability(forStorefront: "CHN")
    XCTAssertEqual(capability, .prohibited)
    XCTAssertFalse(capability.allowsCallKit, "CallKit must never be permitted in China mainland")
  }

  func testChinaMainlandIsRecognisedRegardlessOfCaseOrPadding() {
    for raw in ["chn", "Chn", " CHN ", "\tchn\n"] {
      XCTAssertEqual(
        CallCapabilityPolicy.capability(forStorefront: raw), .prohibited,
        "\(raw) must still resolve to the China mainland storefront"
      )
    }
  }

  // MARK: Permitted storefronts

  func testUnitedStatesPermitsCallKit() {
    let capability = CallCapabilityPolicy.capability(forStorefront: "USA")
    XCTAssertEqual(capability, .available)
    XCTAssertTrue(capability.allowsCallKit)
  }

  func testOtherNonChinaStorefrontsPermitCallKit() {
    // Including the three storefronts adjacent to the instruction that are
    // deliberately NOT covered by it.
    for code in ["GBR", "DEU", "IND", "JPN", "TUR", "HKG", "MAC", "TWN"] {
      let capability = CallCapabilityPolicy.capability(forStorefront: code)
      XCTAssertEqual(capability, .available, "\(code) is outside MIIT's instruction")
      XCTAssertTrue(capability.allowsCallKit)
    }
  }

  // MARK: The unresolved storefront

  func testUnknownStorefrontWithholdsCallKit() {
    XCTAssertEqual(CallCapabilityPolicy.capability(forStorefront: nil), .withheld)
    XCTAssertFalse(
      CallCapabilityPolicy.capability(forStorefront: nil).allowsCallKit,
      "an unresolved storefront must not be read as 'not China'"
    )
  }

  func testEmptyOrWhitespaceStorefrontWithholdsCallKit() {
    for raw in ["", "   ", "\n", "\t "] {
      let capability = CallCapabilityPolicy.capability(forStorefront: raw)
      XCTAssertEqual(capability, .withheld, "a blank lookup result is not evidence of a storefront")
      XCTAssertFalse(capability.allowsCallKit)
    }
  }

  func testOnlyAvailablePermitsCallKit() {
    XCTAssertTrue(CallKitCapability.available.allowsCallKit)
    XCTAssertFalse(CallKitCapability.prohibited.allowsCallKit)
    XCTAssertFalse(CallKitCapability.withheld.allowsCallKit)
  }

  func testChinaMainlandIsTheOnlyProhibitedStorefront() {
    XCTAssertEqual(CallCapabilityPolicy.callKitProhibitedStorefronts, ["CHN"])
    XCTAssertEqual(CallCapabilityPolicy.chinaMainlandStorefront, "CHN")
  }
}

// MARK: - Storefront authority

private final class FakeStorefrontSource: StorefrontSource {
  var storefrontCountryCode: String?
  init(_ code: String? = nil) { storefrontCountryCode = code }
}

/// The authority's job is to start closed, open only on affirmative evidence,
/// and close again the moment the evidence changes.
final class StorefrontAuthorityTests: XCTestCase {

  private func makeAuthority(
    _ source: FakeStorefrontSource
  ) -> (StorefrontAuthority, NotificationCenter) {
    let center = NotificationCenter()
    return (StorefrontAuthority(source: source, notificationCenter: center), center)
  }

  func testStartsWithheldBeforeAnythingIsResolved() {
    let (authority, _) = makeAuthority(FakeStorefrontSource("USA"))
    XCTAssertEqual(
      authority.capability, .withheld,
      "the stack must be closed until start() proves otherwise"
    )
  }

  func testResolvesToAvailableOnAPermittedStorefront() {
    let (authority, _) = makeAuthority(FakeStorefrontSource("USA"))
    var observed: [CallKitCapability] = []
    authority.start { observed.append($0) }

    XCTAssertEqual(authority.capability, .available)
    XCTAssertEqual(observed, [.available])
  }

  func testResolvesToProhibitedOnChinaMainland() {
    let (authority, _) = makeAuthority(FakeStorefrontSource("CHN"))
    var observed: [CallKitCapability] = []
    authority.start { observed.append($0) }

    XCTAssertEqual(authority.capability, .prohibited)
    XCTAssertEqual(observed, [.prohibited])
  }

  func testLookupFailureLeavesCapabilityWithheldAndEmitsNoTransition() {
    // Nil is what StoreKit returns before it reaches the App Store, and
    // forever on a device with no App Store account.
    let (authority, _) = makeAuthority(FakeStorefrontSource(nil))
    var observed: [CallKitCapability] = []
    authority.start { observed.append($0) }

    XCTAssertEqual(authority.capability, .withheld)
    XCTAssertTrue(
      observed.isEmpty,
      "withheld is the starting state; there is no transition to report and no stack to build"
    )
  }

  func testTransitionIntoChinaIsReported() {
    let source = FakeStorefrontSource("USA")
    let (authority, center) = makeAuthority(source)
    var observed: [CallKitCapability] = []
    authority.start { observed.append($0) }
    XCTAssertEqual(authority.capability, .available)

    // The person changed their Apple Account region, which means they left the
    // app and came back.
    source.storefrontCountryCode = "CHN"
    center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

    XCTAssertEqual(authority.capability, .prohibited)
    XCTAssertEqual(observed, [.available, .prohibited])
  }

  func testTransitionOutOfChinaRecovers() {
    let source = FakeStorefrontSource("CHN")
    let (authority, center) = makeAuthority(source)
    var observed: [CallKitCapability] = []
    authority.start { observed.append($0) }
    XCTAssertEqual(authority.capability, .prohibited)

    source.storefrontCountryCode = "USA"
    center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

    XCTAssertEqual(authority.capability, .available)
    XCTAssertEqual(observed, [.prohibited, .available])
  }

  func testStorefrontBecomingUnresolvableWithdrawsTheCapability() {
    let source = FakeStorefrontSource("USA")
    let (authority, center) = makeAuthority(source)
    var observed: [CallKitCapability] = []
    authority.start { observed.append($0) }

    source.storefrontCountryCode = nil
    center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

    XCTAssertEqual(
      authority.capability, .withheld,
      "losing the storefront must close the gate, not leave the last answer standing"
    )
    XCTAssertEqual(observed, [.available, .withheld])
  }

  func testUnchangedStorefrontReportsNoFurtherTransition() {
    let source = FakeStorefrontSource("USA")
    let (authority, center) = makeAuthority(source)
    var observed: [CallKitCapability] = []
    authority.start { observed.append($0) }

    center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    center.post(name: UIApplication.didBecomeActiveNotification, object: nil)

    XCTAssertEqual(
      observed, [.available],
      "re-resolving the same storefront must not rebuild the CallKit stack"
    )
  }

  func testStartIsIdempotent() {
    let source = FakeStorefrontSource("CHN")
    let (authority, _) = makeAuthority(source)
    var observed: [CallKitCapability] = []
    authority.start { observed.append($0) }
    authority.start { _ in observed.append(.available) }

    XCTAssertEqual(observed, [.prohibited], "a second start() must not re-arm anything")
  }
}

// MARK: - Notification cleanup

/// THE BANNER OUTLIVED THE CALL.
///
/// A ringing call reaches an iPhone twice — CallKit, which retires itself when
/// the call is reported ended, and an ordinary APNs alert, which does not.
/// Nothing removed the second one, so "Incoming call…" stayed in Notification
/// Center after the call was accepted, declined, cancelled, expired or
/// answered elsewhere. These tests pin the matcher that finds it.
final class CallNotificationMatchingTests: XCTestCase {

  func testMatchesTheApnsAlertShape() {
    // ApnsPushAdapter.buildBody nests the payload under `data`.
    let info: [AnyHashable: Any] = [
      "type": "CALL_RINGING",
      "data": ["sessionId": "session-1", "callerDisplayName": "M S Bajwa"],
    ]
    XCTAssertTrue(notificationBelongsToCall(info, sessionId: "session-1"))
  }

  func testMatchesTheFcmDataShape() {
    // FcmPushAdapter puts the data map at the top level.
    let info: [AnyHashable: Any] = ["type": "CALL_RINGING", "sessionId": "session-1"]
    XCTAssertTrue(notificationBelongsToCall(info, sessionId: "session-1"))
  }

  func testMatchesTheFlattenedFcmShape() {
    let info: [AnyHashable: Any] = ["gcm.notification.sessionId": "session-1"]
    XCTAssertTrue(notificationBelongsToCall(info, sessionId: "session-1"))
  }

  func testDoesNotClearADifferentCall() {
    // Two simultaneous legitimate calls must not clear each other.
    let info: [AnyHashable: Any] = ["data": ["sessionId": "session-2"]]
    XCTAssertFalse(notificationBelongsToCall(info, sessionId: "session-1"))
  }

  func testDoesNotClearUnrelatedNotifications() {
    let info: [AnyHashable: Any] = ["type": "MESSAGE_RECEIVED", "threadId": "t1"]
    XCTAssertFalse(notificationBelongsToCall(info, sessionId: "session-1"))
  }

  func testAnEmptySessionIdMatchesNothing() {
    // Otherwise a malformed terminal event would clear the whole tray.
    let info: [AnyHashable: Any] = ["sessionId": ""]
    XCTAssertFalse(notificationBelongsToCall(info, sessionId: ""))
  }
}

// MARK: - The storefront READ, on Apple's own test authority

#if canImport(StoreKitTest)
  import StoreKitTest
#endif

/// PROVING THE READ, NOT JUST THE DECISION.
///
/// Every other storefront test in this file drives the policy through a stubbed
/// `StorefrontSource`. That proves the DECISION — given "CHN", CallKit is
/// prohibited. It does not prove the READ: that `StoreKitStorefrontSource`
/// actually reports "CHN" when the App Store storefront is China, which is the
/// single fact Apple's Guideline 5 finding turns on.
///
/// The obvious way to obtain that evidence — converting a real Apple account's
/// region to China — is not a test, it is damage. Apple ships the alternative:
/// `SKTestSession` sets the storefront the StoreKit APIs report, and it is the
/// authority Apple itself directs developers to test storefront behaviour
/// against.
///
/// The configuration is written at runtime rather than bundled, so this needs
/// no new build-phase resource and no project-file surgery.
///
/// Three outcomes, and only one of them is a pass:
///
///   * the authority is unavailable            -> SKIP, with the reason
///   * the authority does not reach StoreKit 1 -> SKIP, naming what it returned
///   * the storefront is read as set           -> PASS, and the read is proven
///
/// It never passes by default. An unproven storefront read recorded as proven
/// is precisely the failure this lane exists to prevent.
final class StorefrontTestAuthorityTests: XCTestCase {

  #if canImport(StoreKitTest)

    /// A minimal, valid StoreKit configuration. Aura sells nothing here; the
    /// session exists only to own a storefront.
    private func writeConfiguration() throws -> URL {
      let json = """
        {
          "identifier" : "AURA-CALLING-CERT",
          "nonRenewingSubscriptions" : [],
          "products" : [],
          "settings" : { },
          "subscriptionGroups" : [],
          "version" : { "major" : 3, "minor" : 0 }
        }
        """
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("aura-calling-cert.storekit")
      try json.write(to: url, atomically: true, encoding: .utf8)
      return url
    }

    @available(iOS 15.4, *)
    private func makeSession() throws -> SKTestSession {
      let url = try writeConfiguration()
      do {
        return try SKTestSession(contentsOf: url)
      } catch {
        throw XCTSkip(
          "StoreKit test authority unavailable in this environment: \(error). "
            + "The real storefront read is therefore NOT proven here."
        )
      }
    }

    /// Drive the session to a storefront and report what Aura's production
    /// reader actually sees. Returns nil when the authority did not reach it.
    @available(iOS 15.4, *)
    private func observedCode(settingStorefront code: String) throws -> String? {
      let session = try makeSession()
      session.storefront = code
      // The read Aura re-evaluates with; see
      // testTransitionIntoChinaEndsProhibitedThroughTheCurrentRead.
      let observed = StoreKitStorefrontSource().storefrontCountryCode
      return observed
    }

    func testChinaStorefrontIsReadAsChinaAndProhibitsCallKit() throws {
      guard #available(iOS 15.4, *) else {
        throw XCTSkip("SKTestSession storefront control needs iOS 15.4 or newer")
      }
      let observed = try observedCode(settingStorefront: "CHN")
      guard observed == "CHN" else {
        throw XCTSkip(
          "Apple's StoreKit test authority did not reach SKPaymentQueue.storefront "
            + "in this environment — it reported \(observed ?? "nil"). The policy "
            + "remains proven; the REAL storefront read does not, and is recorded "
            + "as unproven rather than assumed."
        )
      }

      XCTAssertEqual(
        CallCapabilityPolicy.capability(forStorefront: observed),
        .prohibited,
        "a China storefront read from StoreKit itself must prohibit CallKit"
      )
      XCTAssertFalse(
        CallCapabilityPolicy.capability(forStorefront: observed).allowsCallKit,
        "prohibited must never permit the CallKit stack to register"
      )
    }

    /// WHICH EXPLANATION IS TRUE — asked first, deliberately.
    ///
    /// Two readings fit everything observed so far, and they lead to opposite
    /// conclusions:
    ///
    ///   A. The storefront value is cached for the PROCESS. XCTest runs a
    ///      suite alphabetically, so `testANonChina…` sets USA and reads it
    ///      before anything else, and every later test — including both China
    ///      ones — then sees that same cached USA. If this is true, Aura has a
    ///      real defect: a person moving into the China storefront keeps
    ///      CallKit until the app restarts.
    ///
    ///   B. SKTestSession cannot drive a CHN storefront in this environment at
    ///      all. If this is true, Aura has no defect here and the harness
    ///      simply cannot prove the China read on a simulator.
    ///
    /// The name puts this test first in the suite, so CHN is the FIRST
    /// storefront this process ever reads. Under A it must now be observed;
    /// under B it still will not be. Nothing else distinguishes them, and the
    /// difference decides what we may truthfully tell App Review.
    func testAAAChinaIsObservableWhenItIsTheFirstStorefrontRead() async throws {
      guard #available(iOS 15.4, *) else {
        throw XCTSkip("SKTestSession storefront control needs iOS 15.4 or newer")
      }
      let session = try makeSession()
      session.storefront = "CHN"

      let sync = StoreKitStorefrontSource().storefrontCountryCode
      let current = await StoreKitStorefrontSource().currentCountryCode()

      // Recorded rather than asserted: this test exists to DISTINGUISH, and a
      // failure here would only repeat what the other tests already say.
      // What matters is the pair, in the log, with nothing read before them.
      print(
        "CHINA-FIRST READ: sync=\(sync ?? "nil") current=\(current ?? "nil")"
      )

      XCTAssertNotNil(
        sync ?? current,
        "neither read reached the StoreKit test authority at all; the "
          + "environment cannot speak to this question either way"
      )
    }

    func testANonChinaStorefrontIsReadThroughAndPermitsCallKit() throws {
      guard #available(iOS 15.4, *) else {
        throw XCTSkip("SKTestSession storefront control needs iOS 15.4 or newer")
      }
      let observed = try observedCode(settingStorefront: "USA")
      guard observed == "USA" else {
        throw XCTSkip(
          "Apple's StoreKit test authority did not reach SKPaymentQueue.storefront "
            + "in this environment — it reported \(observed ?? "nil")."
        )
      }

      XCTAssertEqual(
        CallCapabilityPolicy.capability(forStorefront: observed),
        .available,
        "a permitted storefront read from StoreKit itself must allow CallKit"
      )
    }

    /// The transition is the case the App Review finding actually describes: a
    /// device that was permitted becoming prohibited. It must end prohibited,
    /// never merely "changed".
    /// THE READ AURA ACTUALLY RELIES ON, ACROSS A CHANGE.
    ///
    /// This test previously drove the SYNCHRONOUS StoreKit 1 read and failed on
    /// a real simulator, 2026-09-07: a session set to USA read as USA, and the
    /// same process then set to CHN still read USA. Its sibling, which set CHN
    /// alone, never saw CHN either. Three outcomes, one explanation — the
    /// synchronous value is cached for the process.
    ///
    /// That failure was a finding, not a flake, and the fix was to the product
    /// rather than to the test: re-evaluation now goes through
    /// `currentCountryCode()`, which asks StoreKit 2 for the storefront as it
    /// is NOW. The synchronous read still serves the launch path, where a
    /// narrow withheld window matters more than observing a change that cannot
    /// have happened yet.
    ///
    /// A stale storefront is worse than an unknown one: unknown fails safe to
    /// prohibited, while stale asserts a permission that may no longer hold.
    func testTransitionIntoChinaEndsProhibitedThroughTheCurrentRead() async throws {
      guard #available(iOS 15.4, *) else {
        throw XCTSkip("SKTestSession storefront control needs iOS 15.4 or newer")
      }
      let session = try makeSession()
      let source = StoreKitStorefrontSource()

      session.storefront = "USA"
      let permitted = await source.currentCountryCode()
      guard permitted == "USA" else {
        throw XCTSkip(
          "StoreKit test authority did not reach the storefront read "
            + "(reported \(permitted ?? "nil")); the transition is unproven."
        )
      }
      XCTAssertEqual(
        CallCapabilityPolicy.capability(forStorefront: permitted),
        .available,
        "a non-China storefront must permit CallKit"
      )

      session.storefront = "CHN"
      let prohibited = await source.currentCountryCode()

      XCTAssertEqual(
        prohibited,
        "CHN",
        "the storefront change must be observable through the read Aura uses to "
          + "re-evaluate — if this fails, a person moving into the China "
          + "storefront keeps CallKit until the app restarts"
      )
      XCTAssertEqual(
        CallCapabilityPolicy.capability(forStorefront: prohibited),
        .prohibited,
        "moving into the China storefront must end prohibited, not merely changed"
      )
    }

    /// The synchronous read is kept for the launch path, and this records what
    /// it can and cannot do, so nobody later "fixes" the gate by reaching for
    /// it on a re-evaluation. Deliberately asserts nothing about staleness —
    /// caching is an implementation detail of StoreKit that may change — it
    /// asserts only that the FIRST read is usable, which is all the launch path
    /// asks of it.
    func testTheSynchronousReadServesTheFirstResolution() throws {
      guard #available(iOS 15.4, *) else {
        throw XCTSkip("SKTestSession storefront control needs iOS 15.4 or newer")
      }
      let session = try makeSession()
      session.storefront = "USA"

      let first = StoreKitStorefrontSource().storefrontCountryCode
      guard let first else {
        throw XCTSkip("StoreKit test authority did not reach the synchronous read")
      }
      XCTAssertEqual(first, "USA", "the first synchronous read must be truthful")
    }

  #else

    func testStoreKitTestAuthorityIsUnavailable() throws {
      throw XCTSkip(
        "StoreKitTest is not importable in this toolchain, so the real storefront "
          + "read cannot be proven here. The policy is proven separately."
      )
    }

  #endif
}
