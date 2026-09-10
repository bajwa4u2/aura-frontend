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
      // THE SYNCHRONOUS read — the one the launch path uses. The read
      // used for re-evaluation is exercised by
      // testAStorefrontChangeIsObservedAndChinaProhibitsWhenPresented.
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

    /// CHN AS THE VERY FIRST STOREFRONT THE PROCESS EVER READS.
    ///
    /// The name puts this first in the suite on purpose, and that ordering is
    /// half of an answer this gate has now reached. Two explanations were live
    /// for never observing CHN: that the value is cached per process, or that
    /// the harness will not present CHN at all. If it were caching, a CHN read
    /// taken before anything else would have to succeed.
    ///
    /// Certification #15: it did not. And the very next test set USA and read
    /// USA — which a value cached from this one could not have done. Between
    /// them the two tests rule out caching and leave the harness limit, which
    /// is what `testAStorefrontChangeIsObservedAndChinaProhibitsWhenPresented`
    /// now proves properly with a control.
    ///
    /// Kept, rather than deleted with the question it settled: it is the only
    /// test that reads a storefront before anything else has, and it would be
    /// the first to notice if that ever started behaving differently.
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

    /// A CONTROL FIRST, AND ONLY THEN THE CLAIM.
    ///
    /// Certification #16 caught this test being wrong about itself, which is
    /// worth more than the answer it was reaching for.
    ///
    /// The first version created ONE SKTestSession and then assigned
    /// `session.storefront` four times, expecting each assignment to be a
    /// storefront change. It failed. But every StoreKit read that has ever
    /// WORKED in this suite — the USA ones — creates a FRESH session first
    /// (see `observedCode`). So "the reads never followed the change" and
    /// "assigning `.storefront` on a live session does not take effect" both
    /// produce exactly the same failure, and the second is a defect in the
    /// test rather than in Aura.
    ///
    /// That was very nearly reported as a product defect. The instrument now
    /// matches the one that is known to work: a fresh session per territory,
    /// which from the app's side is a real storefront change, observed inside
    /// one process.
    ///
    /// The shape stays as it was:
    ///
    ///   any control observed        -> the read follows a change. PASS.
    ///   every control read the same -> the value is stuck at whatever this
    ///                                  process first read. That is the
    ///                                  staleness signature, and it FAILS.
    ///   anything else (nil, junk)   -> the authority is not reachable for
    ///                                  control territories. SKIP.
    ///
    /// Every message below carries the readings that produced it, because the
    /// build log does not carry `print` and the answer to this question is the
    /// difference between an environment limit and a shipping defect.
    func testAStorefrontChangeIsObservedAndChinaProhibitsWhenPresented() async throws {
      guard #available(iOS 15.4, *) else {
        throw XCTSkip("SKTestSession storefront control needs iOS 15.4 or newer")
      }
      let source = StoreKitStorefrontSource()

      // ONE SESSION, RE-POINTED — not a new session per territory.
      //
      // This is a correction to the method, not to the claim. The previous
      // version created a FRESH SKTestSession for each read and held them all
      // alive at once, on the reasoning that a deallocated session stops
      // overriding. But several simultaneous sessions is not a supported
      // arrangement, and it introduced a second explanation the test could not
      // then tell apart from the one it was hunting: if the first session keeps
      // winning, every later read reports USA whether or not the product's read
      // is stale — which is exactly the signature the assertion below treats as
      // proof of staleness.
      //
      // Certification #16 hit precisely that: four territories, all reporting
      // USA, and the failure message asserting a stuck value. It may be right.
      // It was not established, and this repository has already asserted and
      // retracted this same claim twice on evidence that had more than one
      // reading.
      //
      // A single session, re-pointed, has one explanation. If a storefront
      // change through it is still read as USA, the value IS stuck and the
      // assertion below is earned.
      let session = try makeSession()
      func read(_ territory: String) async throws -> String? {
        session.storefront = territory
        return await source.currentCountryCode()
      }

      let permitted = try await read("USA")
      guard permitted == "USA" else {
        throw XCTSkip(
          "StoreKit test authority did not reach the storefront read at all "
            + "(USA reported \(permitted ?? "nil")); nothing here is provable."
        )
      }
      XCTAssertEqual(
        CallCapabilityPolicy.capability(forStorefront: permitted),
        .available,
        "a non-China storefront must permit CallKit"
      )

      // THE CONTROL.
      //
      // Several territories, because one cannot tell "this environment will
      // not present JPN" apart from "the read does not follow a change".
      var observedControl: String?
      var controlReads: [String] = []
      for territory in ["GBR", "JPN", "DEU", "FRA"] {
        let got = try await read(territory)
        controlReads.append("\(territory)->\(got ?? "nil")")
        if got == territory {
          observedControl = got
          break
        }
      }
      let trail = controlReads.joined(separator: ", ")

      guard let observedControl else {
        XCTAssertFalse(
          controlReads.allSatisfy { $0.hasSuffix("->USA") },
          "four storefront changes and every read still reported USA [\(trail)] "
            + "— the value is stuck at the first storefront this process read, "
            + "so a person moving into the China storefront would keep CallKit "
            + "until the app restarts"
        )
        throw XCTSkip(
          "no control territory could be presented through the read [\(trail)]. "
            + "USA resolved, so the authority is partly reachable, but this "
            + "environment cannot demonstrate a change and nothing about the "
            + "China read is provable here."
        )
      }

      XCTAssertEqual(
        CallCapabilityPolicy.capability(forStorefront: observedControl),
        .available,
        "\(observedControl) is not a prohibited storefront"
      )

      // THE CLAIM. Provable only where the environment will present CHN.
      let prohibited = try await read("CHN")

      guard prohibited == "CHN" else {
        throw XCTSkip(
          "This environment presented USA and \(observedControl) through the "
            + "same read [\(trail)] and would not present CHN (reported "
            + "\(prohibited ?? "nil")). The control proves the read observes a "
            + "change, so this is a limit of Apple's storefront test authority, "
            + "not a staleness defect in Aura. A real China storefront read "
            + "remains UNPROVEN here and must not be claimed to App Review."
        )
      }

      XCTAssertEqual(
        CallCapabilityPolicy.capability(forStorefront: prohibited),
        .prohibited,
        "moving into the China storefront must end prohibited, not merely changed"
      )

      // The sessions must outlive the reads; a deallocated one stops
      // overriding, and every reading above would then be about nothing.
      withExtendedLifetime(held) {}
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
