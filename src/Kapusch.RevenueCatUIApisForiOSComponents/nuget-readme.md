# Kapusch.RevenueCatUI.iOS

Thin .NET interop for RevenueCat Paywalls (RevenueCatUI 5.83.1) on iOS 15+.
`RevenueCatPaywall.CreateViewController` returns RevenueCatUI's paywall view controller and
forwards its delegate to `IPaywallViewControllerDelegate`, including the purchase and restore
hooks that wait for `PaywallResume.Proceed()` or `Cancel()`. The paywall never closes itself:
handle `DismissRequested`.

Requires `Kebechet.Maui.RevenueCat.iOS` 5.83.1.x (brought in automatically), which ships the
matching RevenueCat.framework. Configure the core SDK before showing a paywall.

See the [integration guide](https://github.com/Kapusch/RevenueCatUIApisForiOSComponents/blob/main/Docs/Integration.md)
and the [changelog](https://github.com/Kapusch/RevenueCatUIApisForiOSComponents/blob/main/CHANGELOG.md).
