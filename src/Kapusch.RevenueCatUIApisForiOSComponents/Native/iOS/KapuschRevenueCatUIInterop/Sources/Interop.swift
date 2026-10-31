import Foundation
import ObjectiveC
import RevenueCat
import RevenueCatUI
import UIKit

/// Receives every `PaywallViewControllerDelegate` call and the dismiss request, as one C callback.
/// `first` and `second` are unretained Objective-C objects that are valid only during the call.
/// `token` is non-zero for the two events that wait for `krcui_resume`.
public typealias KrcuiEventCallback = @convention(c) (
    _ context: UnsafeMutableRawPointer?,
    _ event: Int32,
    _ first: UnsafeMutableRawPointer?,
    _ second: UnsafeMutableRawPointer?,
    _ token: Int64
) -> Void

// Keep in sync with include/KapuschRevenueCatUIInterop.h.
private enum Event: Int32 {
    case purchaseStarted = 1
    case purchaseInitiated = 2
    case purchaseCompleted = 3
    case purchaseCancelled = 4
    case purchaseFailed = 5
    case restoreStarted = 6
    case restoreInitiated = 7
    case restoreCompleted = 8
    case restoreFailed = 9
    case dismissRequested = 10
    case dismissed = 11
    case released = 12
}

private final class ResumeStore {
    static let shared = ResumeStore()
    private let lock = NSLock()
    private var next: Int64 = 0
    private var pending: [Int64: (Bool) -> Void] = [:]

    func add(_ resume: @escaping (Bool) -> Void) -> Int64 {
        lock.lock(); defer { lock.unlock() }
        next += 1
        pending[next] = resume
        return next
    }

    func take(_ token: Int64) -> ((Bool) -> Void)? {
        lock.lock(); defer { lock.unlock() }
        return pending.removeValue(forKey: token)
    }
}

private var forwarderKey: UInt8 = 0

private func object(_ value: AnyObject?) -> UnsafeMutableRawPointer? {
    value.map { Unmanaged.passUnretained($0).toOpaque() }
}

private func text(_ p: UnsafePointer<CChar>?) -> String? {
    guard let p else { return nil }
    return String(validatingCString: p)
}

private func paywall(_ p: UnsafeMutableRawPointer?) -> PaywallViewController? {
    guard let p else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue() as? PaywallViewController
}

/// Forwards delegate calls to the C callback. The paywall's `delegate` is weak, so each paywall
/// that uses a forwarder also keeps it alive through an associated object.
private final class Forwarder: NSObject, PaywallViewControllerDelegate {
    private let callback: KrcuiEventCallback
    private let context: UnsafeMutableRawPointer?

    init(callback: KrcuiEventCallback, context: UnsafeMutableRawPointer?) {
        self.callback = callback
        self.context = context
    }

    deinit {
        callback(context, Event.released.rawValue, nil, nil, 0)
    }

    func attach(to controller: PaywallViewController) {
        controller.delegate = self
        objc_setAssociatedObject(controller, &forwarderKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func emit(_ event: Event, _ first: AnyObject? = nil, _ second: AnyObject? = nil, token: Int64 = 0) {
        callback(context, event.rawValue, object(first), object(second), token)
    }

    func paywallViewController(_ controller: PaywallViewController, didStartPurchaseWith package: Package) {
        emit(.purchaseStarted, package)
    }

    func paywallViewController(_ controller: PaywallViewController,
                               didInitiatePurchaseWith package: Package,
                               resume: @escaping (Bool) -> Void) {
        emit(.purchaseInitiated, package, token: ResumeStore.shared.add(resume))
    }

    func paywallViewController(_ controller: PaywallViewController,
                               didFinishPurchasingWith customerInfo: CustomerInfo,
                               transaction: StoreTransaction?) {
        emit(.purchaseCompleted, customerInfo, transaction)
    }

    func paywallViewControllerDidCancelPurchase(_ controller: PaywallViewController) {
        emit(.purchaseCancelled)
    }

    func paywallViewController(_ controller: PaywallViewController, didFailPurchasingWith error: NSError) {
        emit(.purchaseFailed, error)
    }

    func paywallViewControllerDidStartRestore(_ controller: PaywallViewController) {
        emit(.restoreStarted)
    }

    func paywallViewController(_ controller: PaywallViewController,
                               didInitiateRestoreWith resume: @escaping (Bool) -> Void) {
        emit(.restoreInitiated, token: ResumeStore.shared.add(resume))
    }

    func paywallViewController(_ controller: PaywallViewController,
                               didFinishRestoringWith customerInfo: CustomerInfo) {
        emit(.restoreCompleted, customerInfo)
    }

    func paywallViewController(_ controller: PaywallViewController, didFailRestoringWith error: NSError) {
        emit(.restoreFailed, error)
    }

    func paywallViewControllerWasDismissed(_ controller: PaywallViewController) {
        emit(.dismissed)
    }

    // An exit offer is a second paywall: route its purchases to the same callback.
    func paywallViewController(_ controller: PaywallViewController,
                               willPresentExitOfferController exitOfferController: PaywallViewController) {
        attach(to: exitOfferController)
    }
}

/// Creates a `PaywallViewController` for `offering` (an `RCOffering`, or NULL for the current
/// offering). Always passes a dismiss handler, so the paywall never closes itself and the caller
/// decides what a close or a completed purchase does. Main thread only.
/// Returns a +1 retained controller, or NULL when the callback is missing.
@_cdecl("krcui_paywall_new")
public func paywallNew(_ offering: UnsafeMutableRawPointer?,
                       _ displayCloseButton: Int32,
                       _ callback: KrcuiEventCallback?,
                       _ context: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    guard let callback else { return nil }
    let resolvedOffering = offering.map { Unmanaged<Offering>.fromOpaque($0).takeUnretainedValue() }
    let forwarder = Forwarder(callback: callback, context: context)
    let controller = PaywallViewController(
        offering: resolvedOffering,
        displayCloseButton: displayCloseButton != 0,
        shouldBlockTouchEvents: false,
        dismissRequestedHandler: { [weak forwarder] _ in forwarder?.emit(.dismissRequested) }
    )
    forwarder.attach(to: controller)
    return Unmanaged.passRetained(controller).toOpaque()
}

/// Answers a purchaseInitiated or restoreInitiated event once. Returns -1 for an unknown token.
@_cdecl("krcui_resume")
public func resume(_ token: Int64, _ proceed: Int32) -> Int32 {
    guard let resume = ResumeStore.shared.take(token) else { return -1 }
    DispatchQueue.main.async { resume(proceed != 0) }
    return 0
}

@_cdecl("krcui_paywall_update_offering")
public func paywallUpdateOffering(_ controller: UnsafeMutableRawPointer?, _ offering: UnsafeMutableRawPointer?) -> Int32 {
    guard let controller = paywall(controller), let offering else { return -1 }
    controller.update(with: Unmanaged<Offering>.fromOpaque(offering).takeUnretainedValue())
    return 0
}

@_cdecl("krcui_paywall_update_display_close_button")
public func paywallUpdateDisplayCloseButton(_ controller: UnsafeMutableRawPointer?, _ display: Int32) -> Int32 {
    guard let controller = paywall(controller) else { return -1 }
    controller.update(with: display != 0)
    return 0
}

@_cdecl("krcui_paywall_set_custom_variable")
public func paywallSetCustomVariable(_ controller: UnsafeMutableRawPointer?,
                                     _ key: UnsafePointer<CChar>?,
                                     _ value: UnsafePointer<CChar>?) -> Int32 {
    guard let controller = paywall(controller), let key = text(key), let value = text(value) else { return -1 }
    controller.setCustomVariable(value, forKey: key)
    return 0
}
