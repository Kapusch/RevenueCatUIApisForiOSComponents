using Foundation;
using Kapusch.RevenueCatUI.iOS;
using Maui.RevenueCat.iOS;
using UIKit;

UIApplication.Main(args, null, typeof(AppDelegate));

[Register("AppDelegate")]
public class AppDelegate : UIApplicationDelegate
{
	public override UIWindow? Window { get; set; }

	public override bool FinishedLaunching(UIApplication application, NSDictionary options)
	{
		var root = new UIViewController();
		Window = new UIWindow(UIScreen.MainScreen.Bounds) { RootViewController = root };
		Window.MakeKeyAndVisible();

		// A placeholder key keeps the sample free of real credentials; offerings then fail to load.
		var apiKey = Environment.GetEnvironmentVariable("REVENUECAT_API_KEY") ?? "appl_placeholder";
		RCPurchases.ConfigureWithAPIKey(apiKey);

		var paywall = RevenueCatPaywall.CreateViewController(new SmokeEvents(root), displayCloseButton: true);
		root.AddChildViewController(paywall);
		paywall.View!.Frame = root.View!.Bounds;
		paywall.View.AutoresizingMask = UIViewAutoresizing.FlexibleDimensions;
		root.View.AddSubview(paywall.View);
		paywall.DidMoveToParentViewController(root);
		Console.WriteLine($"REVENUECATUI_NATIVE_SMOKE_OK {paywall.GetType().Name}");
		return true;
	}
}

sealed class SmokeEvents(UIViewController root) : IPaywallViewControllerDelegate
{
	public void PurchaseInitiated(RCPackage package, PaywallResume resume)
	{
		Console.WriteLine($"REVENUECATUI_EVENT purchase_initiated {package.Identifier}");
		resume.Proceed();
	}

	public void PurchaseCompleted(RCCustomerInfo customerInfo, RCStoreTransaction? transaction) =>
		Console.WriteLine($"REVENUECATUI_EVENT purchase_completed {transaction?.ProductIdentifier}");

	public void PurchaseFailed(NSError error) =>
		Console.WriteLine($"REVENUECATUI_EVENT purchase_failed {error.Code}");

	public void DismissRequested()
	{
		Console.WriteLine("REVENUECATUI_EVENT dismiss_requested");
		foreach (var child in root.ChildViewControllers)
		{
			child.WillMoveToParentViewController(null);
			child.View!.RemoveFromSuperview();
			child.RemoveFromParentViewController();
		}
	}
}
