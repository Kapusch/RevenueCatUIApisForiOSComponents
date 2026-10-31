# Integration

## Install

```xml
<PackageReference Include="Kapusch.RevenueCatUI.iOS" Version="1.0.0-rc.1" />
```

The package brings `Kebechet.Maui.RevenueCat.iOS` in the matching version range. Configure the core
SDK (`RCPurchases`) as usual before showing a paywall. The paywall uses the offering's paywall as
published in the RevenueCat dashboard; when none is published, RevenueCatUI shows its default
paywall.

## Show a paywall

```csharp
using Kapusch.RevenueCatUI.iOS;
using Maui.RevenueCat.iOS;

sealed class PaywallEvents : IPaywallViewControllerDelegate
{
	public void PurchaseInitiated(RCPackage package, PaywallResume resume)
	{
		// Optional gate before the store sheet, for example a sign-in check.
		resume.Proceed();
	}

	public void PurchaseCompleted(RCCustomerInfo customerInfo, RCStoreTransaction? transaction)
	{
		// Entitlement handling stays in the app.
	}

	public void DismissRequested()
	{
		// Close button or successful purchase: remove or dismiss the controller.
	}
}

var paywall = RevenueCatPaywall.CreateViewController(new PaywallEvents(), offering: null, displayCloseButton: true);
parentViewController.PresentViewController(paywall, true, null);
```

`CreateViewController` returns a regular `UIViewController`: present it, or embed it as a child
view controller. It must be called on the main thread, and every delegate call arrives on the main
thread.

## Behavior

- The paywall never closes itself. `DismissRequested` fires for the close button and after a
  successful purchase; the app decides what happens next.
- `PurchaseInitiated` and `RestoreInitiated` hold the operation until `Proceed()` or `Cancel()` is
  called. The defaults proceed immediately. An exception thrown by either handler cancels the
  operation.
- Exit offers are routed to the same delegate.
- Paywall language follows the core SDK's preferred UI locale
  (`RCPurchases.SharedPurchases.OverridePreferredUILocale`, or the device language).
