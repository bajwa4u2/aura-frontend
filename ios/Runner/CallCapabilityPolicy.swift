import Foundation
import StoreKit
import UIKit

/// WHERE AURA IS DISTRIBUTED — NOT WHERE THE PHONE HAPPENS TO BE.
///
/// The Chinese Ministry of Industry and Information Technology requires that
/// CallKit be inactive in apps distributed through the China mainland App Store.
/// Apple enforced this against Aura Platform 1.4.0 (35) under Guideline 5 —
/// Legal, submission `472dba81-4065-4648-8a29-12ff48549ce4`: the binary shipped
/// an unconditional CallKit integration into a territory list that includes
/// China mainland.
///
/// The obligation attaches to the STOREFRONT the app was distributed through.
/// It does not attach to the device, and the device cannot establish it:
/// `Locale.current`, the keyboard language, the SIM's MCC, the timezone and the
/// IP address all describe where a handset currently is, which is a different
/// question with a different answer. A Beijing storefront account travelling in
/// Berlin is still bound; a German account visiting Shanghai is not. Only the
/// App Store knows which one Aura came from.
///
/// This file is the single place that decision is made. Nothing else in the
/// app compares a country code.

// MARK: - The capability

/// What the current jurisdiction permits of CallKit.
///
/// Three states, not two. "We have not established the storefront yet" is a
/// real and common condition — StoreKit populates asynchronously, and a device
/// with no App Store account never populates at all — and collapsing it into
/// "not China" is exactly the accident this type exists to prevent.
enum CallKitCapability: String, Equatable {
  /// Storefront established, and it is not one where CallKit is prohibited.
  case available

  /// Storefront established, and CallKit is prohibited there.
  case prohibited

  /// Storefront not established. Treated as prohibited.
  case withheld

  /// The only property any caller should branch on.
  ///
  /// `withheld` deliberately answers `false`. CallKit is enabled by an
  /// affirmative, established, permitted storefront — never by the absence of
  /// evidence that it is forbidden.
  var allowsCallKit: Bool { self == .available }
}

// MARK: - The policy

/// The decision table. Pure, total, and the only thing that names a country.
enum CallCapabilityPolicy {
  /// ISO 3166-1 alpha-3, which is the shape `SKStorefront.countryCode` reports.
  static let chinaMainlandStorefront = "CHN"

  /// Storefronts where CallKit may not be active.
  ///
  /// China mainland only, and deliberately so. Hong Kong (`HKG`), Macau
  /// (`MAC`) and Taiwan (`TWN`) are separate App Store storefronts outside
  /// MIIT's instruction, and Apple's finding names the China App Store. Adding
  /// them would remove a system call experience from three territories nobody
  /// asked us to remove it from. If Apple ever extends the instruction, this
  /// set is the one line that changes.
  static let callKitProhibitedStorefronts: Set<String> = [chinaMainlandStorefront]

  /// Map an App Store storefront country code to a CallKit capability.
  ///
  /// A nil, empty or whitespace-only code is `withheld`, never `available`.
  static func capability(forStorefront raw: String?) -> CallKitCapability {
    guard
      let code = raw?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased(),
      !code.isEmpty
    else {
      return .withheld
    }
    return callKitProhibitedStorefronts.contains(code) ? .prohibited : .available
  }
}

// MARK: - Reading the storefront

/// Seam for tests. The production implementation reads StoreKit; the tests
/// drive the authority through every storefront, absence and transition
/// without an App Store account.
protocol StorefrontSource: AnyObject {
  var storefrontCountryCode: String? { get }
}

/// THE SUPPORTED API FOR THIS DEPLOYMENT TARGET.
///
/// `SKPaymentQueue.storefront` is the App Store storefront API, and its
/// `countryCode` is the three-letter code.
///
/// CORRECTED 2026-08-31. This used to justify the choice by Aura's floor being
/// 13.0, which `project.pbxproj` claimed. The real floor is 15.0 — the Flutter
/// toolchain raises it and rewrites the project files on every build — so
/// StoreKit 2's `Storefront.current` WOULD have been reachable.
///
/// StoreKit 1 is kept for the reason that actually holds: it is synchronous,
/// needs no `@available` guard and no Swift concurrency, and this value is read
/// on the launch path where a legally consequential gate must resolve without
/// awaiting anything. An async hop here would widen the `withheld` window that
/// costs rings.
///
/// The value is nil until StoreKit has reached the App Store, and stays nil on
/// a device with no App Store account. Both are `withheld`, which is the safe
/// side.
final class StoreKitStorefrontSource: StorefrontSource {
  var storefrontCountryCode: String? {
    SKPaymentQueue.default().storefront?.countryCode
  }
}

// MARK: - The authority

/// Establishes the storefront, keeps it current, and reports capability changes.
///
/// A RUNTIME DISTRIBUTION FACT, NOT A PROFILE ATTRIBUTE. The storefront is
/// never persisted, never written to the backend, and never attached to a
/// person. It is re-established from StoreKit on every launch and re-read
/// whenever the app returns to the foreground; nothing carries across a
/// process boundary except the code in this file.
final class StorefrontAuthority {
  /// ESCALATING, AND DELIBERATELY FAST AT THE FRONT.
  ///
  /// Every moment the capability is still `withheld` is a moment with no VoIP
  /// registration, and on a cold launch that is a moment in which a ring can be
  /// missed. The first read is synchronous — see `start()` — so in the normal
  /// case this schedule is never used at all. When StoreKit genuinely has not
  /// answered yet, the first retries are milliseconds apart so the window
  /// closes before it costs a call, and only then does the cadence relax for
  /// the device that is never going to have an App Store account.
  ///
  /// The window is survivable rather than merely short: a ringing call also
  /// reaches the device as an ordinary APNs alert on the separate FCM device
  /// row, which is not gated by any of this. That redundancy is why the gate
  /// can afford to fail closed.
  private static let retrySchedule: [TimeInterval] = [
    0.05, 0.1, 0.2, 0.4, 0.8,
    1.0, 1.0, 1.0, 1.0, 1.0,
    2.0, 2.0, 2.0, 2.0, 2.0,
  ]

  private let source: StorefrontSource
  private let notificationCenter: NotificationCenter
  private var onChange: ((CallKitCapability) -> Void)?
  private var foregroundObserver: NSObjectProtocol?
  private var retryIndex = 0
  private var started = false

  /// STARTS WITHHELD, AND THAT IS THE WHOLE SAFETY ARGUMENT.
  ///
  /// The app boots with CallKit off. It is turned on only by an affirmative
  /// resolution to a permitted storefront. A crash, a hang, a StoreKit outage,
  /// a future refactor that forgets to call `start()` — every one of them
  /// leaves this at `withheld`, and `withheld` does not permit CallKit.
  private(set) var capability: CallKitCapability = .withheld

  init(
    source: StorefrontSource = StoreKitStorefrontSource(),
    notificationCenter: NotificationCenter = .default
  ) {
    self.source = source
    self.notificationCenter = notificationCenter
  }

  deinit {
    if let observer = foregroundObserver {
      notificationCenter.removeObserver(observer)
    }
  }

  /// Begin resolving, and call `onChange` on every capability TRANSITION.
  ///
  /// Not called for the initial `withheld`: that is the state the caller is
  /// already in, and re-applying it would tear down a stack that was never up.
  func start(onChange: @escaping (CallKitCapability) -> Void) {
    guard !started else { return }
    started = true
    self.onChange = onChange

    // A STOREFRONT CHANGE MEANS LEAVING THE APP.
    //
    // Changing an Apple Account's country or region happens in Settings or the
    // App Store, so the app is always backgrounded across the change and
    // always foregrounded after it. Re-reading on `didBecomeActive` therefore
    // catches every real transition. StoreKit 2's `Storefront.updates` would
    // observe it a moment sooner, but it is an async sequence and this gate
    // resolves synchronously on the launch path by design.
    foregroundObserver = notificationCenter.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.resolve()
    }

    resolve()
  }

  /// Re-read the storefront now, and keep retrying while it is unresolved.
  ///
  /// SYNCHRONOUS ON THE FIRST READ, WHICH IS THE ONE THAT MATTERS. `start()`
  /// calls this from `didFinishLaunchingWithOptions`, so when StoreKit can
  /// answer — the normal case, since the storefront is cached on device and
  /// needs no network round trip — the capability is established and the VoIP
  /// registration is made at exactly the same point in launch as before this
  /// policy existed. Nothing about a healthy launch got later.
  func resolve() {
    retryIndex = 0
    step()
  }

  private func step() {
    let next = CallCapabilityPolicy.capability(forStorefront: source.storefrontCountryCode)
    apply(next)

    guard next == .withheld, retryIndex < Self.retrySchedule.count else { return }
    let delay = Self.retrySchedule[retryIndex]
    retryIndex += 1
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.step()
    }
  }

  private func apply(_ next: CallKitCapability) {
    guard next != capability else { return }
    capability = next
    onChange?(next)
  }
}
