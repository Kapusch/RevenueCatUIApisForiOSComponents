using Foundation;
using Maui.RevenueCat.iOS;

namespace Kapusch.RevenueCatUI.iOS;

/// <summary>
/// Mirrors RevenueCatUI's <c>PaywallViewControllerDelegate</c>. Every member is optional and is called on
/// the main thread. The native objects are only guaranteed valid for the duration of the call.
/// </summary>
public interface IPaywallViewControllerDelegate
{
	/// <summary><c>paywallViewController:didStartPurchaseWithPackage:</c></summary>
	void PurchaseStarted(RCPackage package) { }

	/// <summary>
	/// <c>paywallViewController:didInitiatePurchaseWithPackage:resume:</c>. The purchase waits until
	/// <paramref name="resume"/> is answered; the default proceeds immediately.
	/// </summary>
	void PurchaseInitiated(RCPackage package, PaywallResume resume) => resume.Proceed();

	/// <summary>
	/// <c>paywallViewController:didFinishPurchasingWithCustomerInfo:transaction:</c>.
	/// <paramref name="transaction"/> can be <see langword="null"/>.
	/// </summary>
	void PurchaseCompleted(RCCustomerInfo customerInfo, RCStoreTransaction? transaction) { }

	/// <summary><c>paywallViewControllerDidCancelPurchase:</c></summary>
	void PurchaseCancelled() { }

	/// <summary><c>paywallViewController:didFailPurchasingWithError:</c></summary>
	void PurchaseFailed(NSError error) { }

	/// <summary><c>paywallViewControllerDidStartRestore:</c></summary>
	void RestoreStarted() { }

	/// <summary>
	/// <c>paywallViewController:didInitiateRestoreWithResume:</c>. The restore waits until
	/// <paramref name="resume"/> is answered; the default proceeds immediately.
	/// </summary>
	void RestoreInitiated(PaywallResume resume) => resume.Proceed();

	/// <summary><c>paywallViewController:didFinishRestoringWithCustomerInfo:</c></summary>
	void RestoreCompleted(RCCustomerInfo customerInfo) { }

	/// <summary><c>paywallViewController:didFailRestoringWithError:</c></summary>
	void RestoreFailed(NSError error) { }

	/// <summary>
	/// The paywall's dismiss request: its close button, or the end of a successful purchase. The paywall
	/// never closes itself; remove or dismiss the controller here.
	/// </summary>
	void DismissRequested() { }

	/// <summary><c>paywallViewControllerWasDismissed:</c></summary>
	void Dismissed() { }
}
