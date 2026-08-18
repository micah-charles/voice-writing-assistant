namespace VoiceWritingAssistant.Core;

public sealed class ModeClassifier(ProfileCatalog profiles)
{
    public AppMode Classify(CapturedContext context, bool transform = false)
    {
        if (transform)
            return AppMode.SelectedTextTransform;

        return profiles.Resolve(context)?.Mode ?? AppMode.General;
    }
}
