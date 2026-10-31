using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using Foundation;
using Maui.RevenueCat.iOS;
using ObjCRuntime;
using UIKit;

namespace Kapusch.RevenueCatUI.iOS;

/// <summary>
/// Creates RevenueCatUI paywalls (<c>RCPaywallViewController</c>) and forwards their delegate calls.
/// Configure the core SDK (<c>RCPurchases</c>) before creating a paywall. Main thread only.
/// </summary>
public static unsafe partial class RevenueCatPaywall
{
	private const int PurchaseStartedEvent = 1;
	private const int PurchaseInitiatedEvent = 2;
	private const int PurchaseCompletedEvent = 3;
	private const int PurchaseCancelledEvent = 4;
	private const int PurchaseFailedEvent = 5;
	private const int RestoreStartedEvent = 6;
	private const int RestoreInitiatedEvent = 7;
	private const int RestoreCompletedEvent = 8;
	private const int RestoreFailedEvent = 9;
	private const int DismissRequestedEvent = 10;
	private const int DismissedEvent = 11;
	private const int ReleasedEvent = 12;

	/// <summary>
	/// Creates a paywall view controller, to embed as a child controller or to present.
	/// </summary>
	/// <param name="delegate">Receives the paywall events. Kept alive as long as the controller.</param>
	/// <param name="offering">The offering whose paywall to show; <see langword="null"/> uses the current offering.</param>
	/// <param name="displayCloseButton">Adds the paywall's own close button.</param>
	/// <remarks>
	/// The paywall never dismisses itself: handle <see cref="IPaywallViewControllerDelegate.DismissRequested"/>.
	/// </remarks>
	public static UIViewController CreateViewController(
		IPaywallViewControllerDelegate @delegate,
		RCOffering? offering = null,
		bool displayCloseButton = false
	)
	{
		ArgumentNullException.ThrowIfNull(@delegate);
		UIApplication.EnsureUIThread();
		var handle = GCHandle.Alloc(@delegate);
		var controller = PaywallNew(
			offering?.Handle ?? IntPtr.Zero,
			displayCloseButton ? 1 : 0,
			&OnEvent,
			GCHandle.ToIntPtr(handle)
		);
		if (controller == IntPtr.Zero)
		{
			handle.Free();
			throw new InvalidOperationException("RevenueCatUI did not create a paywall.");
		}
		return Runtime.GetNSObject<UIViewController>(controller, owns: true)!;
	}

	/// <summary><c>updateWithOffering:</c></summary>
	public static bool UpdateOffering(UIViewController paywall, RCOffering offering)
	{
		ArgumentNullException.ThrowIfNull(paywall);
		ArgumentNullException.ThrowIfNull(offering);
		return PaywallUpdateOffering(paywall.Handle, offering.Handle) == 0;
	}

	/// <summary><c>updateWithDisplayCloseButton:</c></summary>
	public static bool UpdateDisplayCloseButton(UIViewController paywall, bool display)
	{
		ArgumentNullException.ThrowIfNull(paywall);
		return PaywallUpdateDisplayCloseButton(paywall.Handle, display ? 1 : 0) == 0;
	}

	/// <summary><c>setCustomVariable:forKey:</c>, a value for a <c>{{ custom.key }}</c> paywall variable.</summary>
	public static bool SetCustomVariable(UIViewController paywall, string key, string value)
	{
		ArgumentNullException.ThrowIfNull(paywall);
		ArgumentException.ThrowIfNullOrWhiteSpace(key);
		ArgumentNullException.ThrowIfNull(value);
		return PaywallSetCustomVariable(paywall.Handle, key, value) == 0;
	}

	internal static void Resume(long token, bool proceed) => ResumeNative(token, proceed ? 1 : 0);

	[UnmanagedCallersOnly(CallConvs = [typeof(CallConvCdecl)])]
	private static void OnEvent(IntPtr context, int @event, IntPtr first, IntPtr second, long token)
	{
		var handle = GCHandle.FromIntPtr(context);
		if (@event == ReleasedEvent)
		{
			handle.Free();
			return;
		}
		var resume = token != 0 ? new PaywallResume(token) : null;
		try
		{
			if (handle.Target is IPaywallViewControllerDelegate target)
				Dispatch(target, @event, first, second, resume);
		}
		catch (Exception exception)
		{
			// Nothing may unwind into native code. A failed check must not let a purchase through.
			resume?.Cancel();
			Console.Error.WriteLine($"RevenueCatUI paywall delegate threw: {exception}");
		}
	}

	private static void Dispatch(
		IPaywallViewControllerDelegate target,
		int @event,
		IntPtr first,
		IntPtr second,
		PaywallResume? resume
	)
	{
		switch (@event)
		{
			case PurchaseStartedEvent:
				target.PurchaseStarted(Get<RCPackage>(first));
				break;
			case PurchaseInitiatedEvent:
				target.PurchaseInitiated(Get<RCPackage>(first), resume!);
				break;
			case PurchaseCompletedEvent:
				target.PurchaseCompleted(Get<RCCustomerInfo>(first), Runtime.GetNSObject<RCStoreTransaction>(second));
				break;
			case PurchaseCancelledEvent:
				target.PurchaseCancelled();
				break;
			case PurchaseFailedEvent:
				target.PurchaseFailed(Get<NSError>(first));
				break;
			case RestoreStartedEvent:
				target.RestoreStarted();
				break;
			case RestoreInitiatedEvent:
				target.RestoreInitiated(resume!);
				break;
			case RestoreCompletedEvent:
				target.RestoreCompleted(Get<RCCustomerInfo>(first));
				break;
			case RestoreFailedEvent:
				target.RestoreFailed(Get<NSError>(first));
				break;
			case DismissRequestedEvent:
				target.DismissRequested();
				break;
			case DismissedEvent:
				target.Dismissed();
				break;
		}
	}

	private static T Get<T>(IntPtr handle)
		where T : NSObject =>
		Runtime.GetNSObject<T>(handle) ?? throw new InvalidOperationException($"RevenueCatUI sent no {typeof(T).Name}.");

	[LibraryImport("__Internal", EntryPoint = "krcui_paywall_new")]
	private static partial IntPtr PaywallNew(
		IntPtr offering,
		int displayCloseButton,
		delegate* unmanaged[Cdecl]<IntPtr, int, IntPtr, IntPtr, long, void> callback,
		IntPtr context
	);

	[LibraryImport("__Internal", EntryPoint = "krcui_resume")]
	private static partial int ResumeNative(long token, int proceed);

	[LibraryImport("__Internal", EntryPoint = "krcui_paywall_update_offering")]
	private static partial int PaywallUpdateOffering(IntPtr controller, IntPtr offering);

	[LibraryImport("__Internal", EntryPoint = "krcui_paywall_update_display_close_button")]
	private static partial int PaywallUpdateDisplayCloseButton(IntPtr controller, int display);

	[LibraryImport("__Internal", EntryPoint = "krcui_paywall_set_custom_variable", StringMarshalling = StringMarshalling.Utf8)]
	private static partial int PaywallSetCustomVariable(IntPtr controller, string key, string value);
}
