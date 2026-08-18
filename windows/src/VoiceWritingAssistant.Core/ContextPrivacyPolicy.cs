namespace VoiceWritingAssistant.Core;

public sealed class ContextPrivacyPolicy
{
    public CapturedContext Filter(CapturedContext context, AppSettings settings)
    {
        var limit = Math.Max(0, settings.ClipboardCharacterLimit);
        return context with
        {
            ActiveApplicationName = settings.UseActiveAppContext ? context.ActiveApplicationName : null,
            ApplicationIdentifier = settings.UseActiveAppContext ? context.ApplicationIdentifier : null,
            ExecutableName = settings.UseActiveAppContext ? context.ExecutableName : null,
            WindowTitle = settings.UseWindowTitle ? context.WindowTitle : null,
            SelectedText = settings.UseSelectedTextContext ? Limit(context.SelectedText, limit) : null,
            ClipboardText = settings.UseClipboardContext ? Limit(context.ClipboardText, limit) : null,
            BrowserUrl = settings.UseBrowserUrl ? context.BrowserUrl : null
        };
    }

    private static string? Limit(string? value, int limit) =>
        string.IsNullOrEmpty(value) || limit == 0 ? null : value[..Math.Min(value.Length, limit)];
}
