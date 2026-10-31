namespace Kapusch.RevenueCatUI.iOS;

/// <summary>
/// The pending answer to <see cref="IPaywallViewControllerDelegate.PurchaseInitiated"/> or
/// <see cref="IPaywallViewControllerDelegate.RestoreInitiated"/>. Only the first answer counts.
/// </summary>
public sealed class PaywallResume
{
	private readonly long _token;
	private int _answered;

	internal PaywallResume(long token) => _token = token;

	/// <summary>Whether <see cref="Proceed"/> or <see cref="Cancel"/> was already called.</summary>
	public bool IsAnswered => Volatile.Read(ref _answered) != 0;

	/// <summary>Lets the purchase or restore continue.</summary>
	public void Proceed() => Answer(true);

	/// <summary>Stops the purchase or restore before it reaches the store.</summary>
	public void Cancel() => Answer(false);

	private void Answer(bool proceed)
	{
		if (Interlocked.Exchange(ref _answered, 1) == 0)
			RevenueCatPaywall.Resume(_token, proceed);
	}
}
