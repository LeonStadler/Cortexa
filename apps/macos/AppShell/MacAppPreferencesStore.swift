import AIProcessingCore
import ASRCore
import Carbon
import Foundation

struct MacAppPreferencesSnapshot {
    let streamingEnabled: Bool
    let selectedLanguage: DictationLanguage
    let translationOutputMode: TranslationOutputMode
    let visibleMenuBarLanguages: [String]
    let performanceProfile: DictationPerformance
    let selectedVoiceProviderID: String
    let selectedVoiceModelID: String
    let voiceLanguageOverrides: [VoiceLanguageOverride]
    let selectedHotkey: HotkeyBinding
    let toggleShortcutEnabled: Bool
    let holdToDictateEnabled: Bool
    let holdShortcut: HotkeyBinding
    let cancelShortcutEnabled: Bool
    let cancelShortcut: HotkeyBinding
    let modeSwitchShortcutEnabled: Bool
    let modeSwitchShortcut: HotkeyBinding
    let showMenuBarShortcutHints: Bool
    let compactMenuBarDesign: Bool
    let showInDock: Bool
    let launchOnLoginEnabled: Bool
    let automaticallyCheckForUpdates: Bool
    let debugModeEnabled: Bool
    let finalResultDeliveryMode: FinalResultDeliveryMode
    let clipboardFallbackWhenNoTarget: Bool
    let liveRewriteScope: LiveRewriteScope
    let aiProcessingEnabled: Bool
    let selectedAIModelID: String?
    let aiProcessingApplyDuringLiveInsertion: Bool
    let aiProcessingApplyToFinalResult: Bool
    let aiTaskCleanupEnabled: Bool
    let aiTaskToneEnabled: Bool
    let aiTaskSalutationEnabled: Bool
    let aiTaskFormatEnabled: Bool
    let aiRevisionGoal: AIRevisionGoal
    let aiFormattingMode: AIFormattingMode
    let aiWritingStyle: AIWritingStyle
    let aiSalutation: AISalutation
    let aiCleanupIntensity: Double
    let voiceModelActiveDuration: VoiceModelActiveDuration
    let automaticMicrophoneGainBoost: Bool
    let silenceRemovalEnabled: Bool
    let dynamicNormalizationEnabled: Bool
    let noiseSuppressionLevel: Double
    let soundEffectsEnabled: Bool
    let soundEffectsVolume: Double
    let historyRetentionPolicy: HistoryRetentionPolicy
    let autoSendAfterPaste: Bool
    let restoreClipboardAfterPaste: Bool
    let simulateKeypresses: Bool
    let muteMusicWhileDictating: Bool
    let contextAwarenessMode: ContextAwarenessMode
    let dictionaryAutoAddEnabled: Bool
    let remoteProviders: [AIRemoteProviderConfiguration]
    let selectedRemoteProviderID: String?
}

struct MacAppPreferencesStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    func loadInitialState(currentLaunchOnLoginEnabled: @autoclosure () -> Bool) -> MacAppPreferencesSnapshot {
        let remoteProviders = loadRemoteProviders()
        return MacAppPreferencesSnapshot(
            streamingEnabled: bool(Keys.streamingEnabled, default: true),
            selectedLanguage: enumValue(Keys.selectedLanguage, default: .german),
            translationOutputMode: enumValue(Keys.translationOutputMode, default: .original),
            visibleMenuBarLanguages: userDefaults.stringArray(forKey: Keys.visibleMenuBarLanguages)
                ?? DictationLanguage.allCases.filter { $0 != .auto }.map(\.rawValue),
            performanceProfile: enumValue(Keys.performanceProfile, default: .auto),
            selectedVoiceProviderID: userDefaults.string(forKey: Keys.selectedVoiceProviderID)
                ?? LocalVoiceModelCatalog.defaultProviderID,
            selectedVoiceModelID: userDefaults.string(forKey: Keys.selectedVoiceModelID)
                ?? LocalVoiceModelCatalog.defaultModelID,
            voiceLanguageOverrides: decode(
                [VoiceLanguageOverride].self,
                forKey: Keys.voiceLanguageOverrides
            ) ?? [],
            selectedHotkey: hotkeyValue(Keys.selectedHotkey, default: .optionSpace),
            toggleShortcutEnabled: bool(Keys.toggleShortcutEnabled, default: true),
            holdToDictateEnabled: bool(Keys.holdToDictateEnabled, default: false),
            holdShortcut: hotkeyValue(Keys.holdShortcut, default: .optionShiftSpace),
            cancelShortcutEnabled: bool(Keys.cancelShortcutEnabled, default: false),
            cancelShortcut: hotkeyValue(
                Keys.cancelShortcut,
                default: HotkeyBinding(
                    keyCode: UInt32(kVK_Escape),
                    carbonModifiers: UInt32(optionKey)
                )
            ),
            modeSwitchShortcutEnabled: bool(Keys.modeSwitchShortcutEnabled, default: false),
            modeSwitchShortcut: hotkeyValue(
                Keys.modeSwitchShortcut,
                default: HotkeyBinding(
                    keyCode: UInt32(kVK_ANSI_M),
                    carbonModifiers: UInt32(optionKey | shiftKey)
                )
            ),
            showMenuBarShortcutHints: bool(Keys.showMenuBarShortcutHints, default: false),
            compactMenuBarDesign: bool(Keys.compactMenuBarDesign, default: false),
            showInDock: bool(Keys.showInDock, default: false),
            launchOnLoginEnabled: userDefaults.object(forKey: Keys.launchOnLoginEnabled) != nil
                ? userDefaults.bool(forKey: Keys.launchOnLoginEnabled)
                : currentLaunchOnLoginEnabled(),
            automaticallyCheckForUpdates: bool(Keys.automaticallyCheckForUpdates, default: true),
            debugModeEnabled: bool(Keys.debugModeEnabled, default: false),
            finalResultDeliveryMode: enumValue(Keys.finalResultDeliveryMode, default: .insert),
            clipboardFallbackWhenNoTarget: bool(Keys.clipboardFallbackWhenNoTarget, default: false),
            liveRewriteScope: enumValue(Keys.liveRewriteScope, default: .currentSentence),
            aiProcessingEnabled: bool(Keys.aiProcessingEnabled, default: false),
            selectedAIModelID: userDefaults.string(forKey: Keys.selectedAIModelID),
            aiProcessingApplyDuringLiveInsertion: loadApplyDuringLiveInsertion(),
            aiProcessingApplyToFinalResult: bool(Keys.aiProcessingApplyToFinalResult, default: true),
            aiTaskCleanupEnabled: loadTaskCleanupEnabled(),
            aiTaskToneEnabled: loadTaskToneEnabled(),
            aiTaskSalutationEnabled: loadTaskSalutationEnabled(),
            aiTaskFormatEnabled: loadTaskFormatEnabled(),
            aiRevisionGoal: enumValue(Keys.aiRevisionGoal, default: .cleanup),
            aiFormattingMode: enumValue(Keys.aiFormattingMode, default: .asSpoken),
            aiWritingStyle: enumValue(Keys.aiWritingStyle, default: .none),
            aiSalutation: enumValue(Keys.aiSalutation, default: .none),
            aiCleanupIntensity: min(
                1,
                max(0, userDefaults.object(forKey: Keys.aiCleanupIntensity) as? Double ?? 0.5)
            ),
            voiceModelActiveDuration: enumValue(Keys.voiceModelActiveDuration, default: .oneMinute),
            automaticMicrophoneGainBoost: bool(Keys.automaticMicrophoneGainBoost, default: false),
            silenceRemovalEnabled: bool(Keys.silenceRemovalEnabled, default: false),
            dynamicNormalizationEnabled: bool(Keys.dynamicNormalizationEnabled, default: false),
            noiseSuppressionLevel: userDefaults.object(forKey: Keys.noiseSuppressionLevel) as? Double
                ?? 0.35,
            soundEffectsEnabled: bool(Keys.soundEffectsEnabled, default: false),
            soundEffectsVolume: loadSteppedSoundVolume(),
            historyRetentionPolicy: enumValue(Keys.historyRetentionPolicy, default: .forever),
            autoSendAfterPaste: bool(Keys.autoSendAfterPaste, default: false),
            restoreClipboardAfterPaste: bool(Keys.restoreClipboardAfterPaste, default: false),
            simulateKeypresses: bool(Keys.simulateKeypresses, default: false),
            muteMusicWhileDictating: bool(Keys.muteMusicWhileDictating, default: false),
            contextAwarenessMode: enumValue(Keys.contextAwarenessMode, default: .finalOnly),
            dictionaryAutoAddEnabled: bool(Keys.dictionaryAutoAddEnabled, default: false),
            remoteProviders: remoteProviders,
            selectedRemoteProviderID: userDefaults.string(forKey: Keys.selectedRemoteProviderID)
                ?? remoteProviders.first?.id
        )
    }

    func saveRemoteProviders(_ providers: [AIRemoteProviderConfiguration]) {
        guard let data = try? JSONEncoder().encode(providers) else { return }
        userDefaults.set(data, forKey: Keys.remoteProviders)
    }

    func saveVoiceLanguageOverrides(_ overrides: [VoiceLanguageOverride]) {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        userDefaults.set(data, forKey: Keys.voiceLanguageOverrides)
    }

    private func bool(_ key: String, default defaultValue: Bool) -> Bool {
        userDefaults.object(forKey: key) as? Bool ?? defaultValue
    }

    private func enumValue<T: RawRepresentable>(_ key: String, default defaultValue: T) -> T
    where T.RawValue == String {
        guard
            let rawValue = userDefaults.string(forKey: key),
            let value = T(rawValue: rawValue)
        else {
            return defaultValue
        }
        return value
    }

    private func hotkeyValue(_ key: String, default defaultValue: HotkeyBinding) -> HotkeyBinding {
        guard
            let rawValue = userDefaults.string(forKey: key),
            let value = HotkeyBinding.from(rawValue: rawValue)
        else {
            return defaultValue
        }
        return value
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func loadRemoteProviders() -> [AIRemoteProviderConfiguration] {
        decode([AIRemoteProviderConfiguration].self, forKey: Keys.remoteProviders) ?? []
    }

    private func loadApplyDuringLiveInsertion() -> Bool {
        if userDefaults.object(forKey: Keys.aiProcessingApplyDuringLiveInsertion) != nil {
            return userDefaults.bool(forKey: Keys.aiProcessingApplyDuringLiveInsertion)
        }
        return userDefaults.string(forKey: Keys.legacyAIProcessingScope) == "liveAndFinal"
    }

    private func storedAIRevisionGoal() -> AIRevisionGoal? {
        userDefaults.string(forKey: Keys.aiRevisionGoal).flatMap(AIRevisionGoal.init(rawValue:))
    }

    private func loadTaskCleanupEnabled() -> Bool {
        if userDefaults.object(forKey: Keys.aiTaskCleanupEnabled) != nil {
            return userDefaults.bool(forKey: Keys.aiTaskCleanupEnabled)
        }
        let revisionGoal = storedAIRevisionGoal()
        return revisionGoal == nil || revisionGoal == .cleanup
    }

    private func loadTaskToneEnabled() -> Bool {
        if userDefaults.object(forKey: Keys.aiTaskToneEnabled) != nil {
            return userDefaults.bool(forKey: Keys.aiTaskToneEnabled)
        }
        return storedAIRevisionGoal() == .adjustTone
    }

    private func loadTaskSalutationEnabled() -> Bool {
        if userDefaults.object(forKey: Keys.aiTaskSalutationEnabled) != nil {
            return userDefaults.bool(forKey: Keys.aiTaskSalutationEnabled)
        }
        return storedAIRevisionGoal() == .adjustSalutation
    }

    private func loadTaskFormatEnabled() -> Bool {
        if userDefaults.object(forKey: Keys.aiTaskFormatEnabled) != nil {
            return userDefaults.bool(forKey: Keys.aiTaskFormatEnabled)
        }
        return storedAIRevisionGoal() == .adaptFormat
    }

    private func loadSteppedSoundVolume() -> Double {
        let loadedSoundVolume = userDefaults.object(forKey: Keys.soundEffectsVolume) as? Double ?? 50
        let steppedSoundVolume = (loadedSoundVolume / 5).rounded() * 5
        return min(100, max(0, steppedSoundVolume))
    }

    internal enum Keys {
        static let streamingEnabled = "wispr.settings.streamingEnabled"
        static let selectedLanguage = "wispr.settings.selectedLanguage"
        static let translationOutputMode = "wispr.settings.translationOutputMode"
        static let visibleMenuBarLanguages = "wispr.settings.visibleMenuBarLanguages"
        static let performanceProfile = "wispr.settings.performanceProfile"
        static let selectedVoiceProviderID = "wispr.settings.selectedVoiceProviderID"
        static let selectedVoiceModelID = "wispr.settings.selectedVoiceModelID"
        static let voiceLanguageOverrides = "wispr.settings.voiceLanguageOverrides"
        static let selectedHotkey = "wispr.settings.selectedHotkey"
        static let toggleShortcutEnabled = "wispr.settings.toggleShortcutEnabled"
        static let holdToDictateEnabled = "wispr.settings.holdToDictateEnabled"
        static let holdShortcut = "wispr.settings.holdShortcut"
        static let cancelShortcutEnabled = "wispr.settings.cancelShortcutEnabled"
        static let cancelShortcut = "wispr.settings.cancelShortcut"
        static let modeSwitchShortcutEnabled = "wispr.settings.modeSwitchShortcutEnabled"
        static let modeSwitchShortcut = "wispr.settings.modeSwitchShortcut"
        static let finalResultDeliveryMode = "wispr.settings.finalResultDeliveryMode"
        static let clipboardFallbackWhenNoTarget = "wispr.settings.clipboardFallbackWhenNoTarget"
        static let liveRewriteScope = "wispr.settings.liveRewriteScope"
        static let showMenuBarShortcutHints = "wispr.settings.showMenuBarShortcutHints"
        static let compactMenuBarDesign = "wispr.settings.compactMenuBarDesign"
        static let showInDock = "wispr.settings.showInDock"
        static let launchOnLoginEnabled = "wispr.settings.launchOnLoginEnabled"
        static let automaticallyCheckForUpdates = "wispr.settings.automaticallyCheckForUpdates"
        static let debugModeEnabled = "wispr.settings.debugModeEnabled"
        static let aiProcessingEnabled = "wispr.settings.aiProcessingEnabled"
        static let selectedAIModelID = "wispr.settings.selectedAIModelID"
        static let aiProcessingApplyDuringLiveInsertion =
            "wispr.settings.aiProcessing.applyDuringLiveInsertion"
        static let aiProcessingApplyToFinalResult = "wispr.settings.aiProcessing.applyToFinalResult"
        static let aiTaskCleanupEnabled = "wispr.settings.aiProcessing.task.cleanup"
        static let aiTaskToneEnabled = "wispr.settings.aiProcessing.task.tone"
        static let aiTaskSalutationEnabled = "wispr.settings.aiProcessing.task.salutation"
        static let aiTaskFormatEnabled = "wispr.settings.aiProcessing.task.format"
        static let legacyAIProcessingScope = "wispr.settings.aiProcessingScope"
        static let aiRevisionGoal = "wispr.settings.aiProcessing.revisionGoal"
        static let aiFormattingMode = "wispr.settings.aiProcessing.formattingMode"
        static let aiWritingStyle = "wispr.settings.aiWritingStyle"
        static let aiSalutation = "wispr.settings.aiSalutation"
        static let aiCleanupIntensity = "wispr.settings.aiProcessing.cleanupIntensity"
        static let voiceModelActiveDuration = "wispr.settings.voiceModelActiveDuration"
        static let automaticMicrophoneGainBoost = "wispr.settings.automaticMicrophoneGainBoost"
        static let silenceRemovalEnabled = "wispr.settings.silenceRemovalEnabled"
        static let dynamicNormalizationEnabled = "wispr.settings.dynamicNormalizationEnabled"
        static let noiseSuppressionLevel = "wispr.settings.noiseSuppressionLevel"
        static let soundEffectsEnabled = "wispr.settings.soundEffectsEnabled"
        static let soundEffectsVolume = "wispr.settings.soundEffectsVolume"
        static let historyRetentionPolicy = "wispr.settings.historyRetentionPolicy"
        static let autoSendAfterPaste = "wispr.settings.autoSendAfterPaste"
        static let restoreClipboardAfterPaste = "wispr.settings.restoreClipboardAfterPaste"
        static let simulateKeypresses = "wispr.settings.simulateKeypresses"
        static let muteMusicWhileDictating = "wispr.settings.muteMusicWhileDictating"
        static let contextAwarenessMode = "wispr.settings.contextAwarenessMode"
        static let dictionaryAutoAddEnabled = "wispr.settings.dictionaryAutoAddEnabled"
        static let remoteProviders = "wispr.settings.ai.remoteProviders"
        static let selectedRemoteProviderID = "wispr.settings.ai.selectedRemoteProviderID"
    }
}
