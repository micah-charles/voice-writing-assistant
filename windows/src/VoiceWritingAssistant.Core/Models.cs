using System.Text.Json.Serialization;

namespace VoiceWritingAssistant.Core;

[JsonConverter(typeof(JsonStringEnumConverter<AppMode>))]
public enum AppMode { General, Email, Chat, Technical, Document, Note, SelectedTextTransform }

[JsonConverter(typeof(JsonStringEnumConverter<ProcessingStyle>))]
public enum ProcessingStyle { Automatic, Faithful, Professional, Conversational, Technical, Structured, Concise }

[JsonConverter(typeof(JsonStringEnumConverter<OutputLanguage>))]
public enum OutputLanguage { PreserveSpokenLanguage, English, CantoneseWritten, FormalTraditionalChinese }

[JsonConverter(typeof(JsonStringEnumConverter<ShortcutMode>))]
public enum ShortcutMode { PushToTalk, Toggle }

[JsonConverter(typeof(JsonStringEnumConverter<SpeechToTextProvider>))]
public enum SpeechToTextProvider { Automatic, SherpaOnnx, WhisperCpp }

[JsonConverter(typeof(JsonStringEnumConverter<RecognitionLanguage>))]
public enum RecognitionLanguage { Automatic, English, TraditionalChinese, Cantonese, MixedChineseEnglish }

[JsonConverter(typeof(JsonStringEnumConverter<ChineseOutputStyle>))]
public enum ChineseOutputStyle { Cantonese, FormalTraditional, Preserve }

[JsonConverter(typeof(JsonStringEnumConverter<OpenCcProfile>))]
public enum OpenCcProfile { Preserve, Traditional, TaiwanTraditional }

public enum WorkflowStage
{
    Idle,
    Starting,
    Recording,
    Transcribing,
    CapturingContext,
    Processing,
    Normalizing,
    Pasting,
    AwaitingReview,
    Completed,
    Failed
}

public sealed record CapturedContext
{
    public string? ActiveApplicationName { get; init; }
    public string? ApplicationIdentifier { get; init; }
    public string? ExecutableName { get; init; }
    public string? WindowTitle { get; init; }
    public string? SelectedText { get; init; }
    public string? ClipboardText { get; init; }
    public string? BrowserUrl { get; init; }
    public string? PlatformTargetId { get; init; }
}

public sealed record AppProfileMatch
{
    public IReadOnlyList<string> ApplicationNames { get; init; } = [];
    public IReadOnlyList<string> BundleIdentifiers { get; init; } = [];
    public IReadOnlyList<string> ExecutableNames { get; init; } = [];
}

public sealed record AppProfile
{
    public required string Id { get; init; }
    public required AppProfileMatch Match { get; init; }
    public AppMode Mode { get; init; } = AppMode.General;
    public OutputLanguage OutputLanguage { get; init; } = OutputLanguage.PreserveSpokenLanguage;
    public ProcessingStyle Style { get; init; } = ProcessingStyle.Automatic;
    public bool AutoPaste { get; init; } = true;
    public bool AutoSend { get; init; }
}

public sealed record AppProfileDocument
{
    public int Version { get; init; }
    public IReadOnlyList<AppProfile> Profiles { get; init; } = [];
}

public sealed record AppSettings
{
    public ShortcutMode ShortcutMode { get; init; } = ShortcutMode.PushToTalk;
    public bool AutoPaste { get; init; } = true;
    public bool RestoreClipboard { get; init; } = true;
    public bool ReviewBeforePaste { get; init; }
    public bool ShowFloatingControl { get; init; } = true;
    public bool WarmModelAtLaunch { get; init; } = true;
    public SpeechToTextProvider SpeechToTextProvider { get; init; } = SpeechToTextProvider.Automatic;
    public RecognitionLanguage RecognitionLanguage { get; init; } = RecognitionLanguage.Automatic;
    public ProcessingStyle ProcessingStyle { get; init; } = ProcessingStyle.Automatic;
    public OutputLanguage OutputLanguage { get; init; } = OutputLanguage.PreserveSpokenLanguage;
    public string TextProcessor { get; init; } = "automatic";
    public int ProcessingTimeoutSeconds { get; init; } = 20;
    public string CodexExecutable { get; init; } = "codex";
    public string OllamaEndpoint { get; init; } = "http://127.0.0.1:11434";
    public string OllamaModel { get; init; } = "";
    public string WhisperExecutable { get; init; } = "whisper-cli";
    public string WhisperModelPath { get; init; } = "";
    public string SherpaModelPath { get; init; } = "";
    public string SherpaVadModelPath { get; init; } = "";
    public bool EnableVoiceActivityDetection { get; init; } = true;
    public bool UseActiveAppContext { get; init; } = true;
    public bool UseWindowTitle { get; init; } = true;
    public bool UseSelectedTextContext { get; init; } = true;
    public bool UseClipboardContext { get; init; }
    public int ClipboardCharacterLimit { get; init; } = 2_000;
    public bool UseBrowserUrl { get; init; }
    public bool StoreHistory { get; init; } = true;
    public bool StoreAudioRecordings { get; init; }
    public ChineseOutputStyle ChineseOutput { get; init; } = ChineseOutputStyle.Preserve;
    public OpenCcProfile OpenCcProfile { get; init; } = OpenCcProfile.Preserve;
}

public sealed record ProcessingRequest(
    string RawText,
    CapturedContext Context,
    AppMode Mode,
    ProcessingStyle Style,
    OutputLanguage OutputLanguage);

public sealed record ProcessingResult(string Text, string Provider, TimeSpan Latency, bool UsedFallback = false);

public sealed record TranscriptionMetadata(
    string Provider,
    string Model,
    string Language,
    bool VadEnabled,
    TimeSpan AudioDuration,
    TimeSpan SpeechDuration,
    TimeSpan Latency,
    bool FallbackUsed = false,
    string? FallbackReason = null);

public sealed record WorkflowStatus(
    WorkflowStage Stage,
    string Message,
    string? Text = null,
    string? RawTranscript = null,
    string? Provider = null,
    TimeSpan? Latency = null);

public sealed record PersonalDictionaryEntry
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public required string Term { get; init; }
    public required string PreferredForm { get; init; }
    public IReadOnlyList<string> Aliases { get; init; } = [];
    public string? Category { get; init; }
}

public sealed record HistoryEntry
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public DateTimeOffset Date { get; init; } = DateTimeOffset.Now;
    public required string RawTranscript { get; init; }
    public required string ProcessedText { get; init; }
    public required string Provider { get; init; }
    public AppMode Mode { get; init; } = AppMode.General;
    public string? ActiveApplication { get; init; }
    public TimeSpan? Latency { get; init; }
    public IReadOnlyList<ProcessingResult> AlternativeResults { get; init; } = [];
    public string? AudioPath { get; init; }
    public TranscriptionMetadata? Transcription { get; init; }
}

public sealed record ProviderDiagnostic(string Id, string Name, bool Ready, string Detail);
