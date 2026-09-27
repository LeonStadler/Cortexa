import AIProcessingCore
import ASRCore
import AudioCore
import Foundation
import SnippetCore

struct SessionConfigurationInput {
    let streamingEnabled: Bool
    let selectedLanguage: DictationLanguage
    let translationOutputMode: TranslationOutputMode
    let performanceProfile: DictationPerformance
    let selectedVoiceProviderID: String
    let selectedVoiceModelID: String
    let voiceLanguageOverrides: [VoiceLanguageOverride]
    let voiceModels: [VoiceModelDescriptor]
    let installedVoiceModelFileNames: Set<String>
    let liveRewriteScope: LiveRewriteScope
    let snippetRules: [SnippetRule]
    let finalResultDeliveryMode: FinalResultDeliveryMode
    let clipboardFallbackWhenNoTarget: Bool
    let simulateKeypresses: Bool
    let restoreClipboardAfterPaste: Bool
    let autoSendAfterPaste: Bool
    let muteMusicWhileDictating: Bool
    let asrInitialPrompt: String?
    let dictionaryTerms: [String]
    let liveContextText: String?
    let finalContextText: String?
    let aiProcessing: AIProcessingConfiguration
    let audioProcessing: AudioProcessingConfiguration
    let soundFeedback: SoundFeedbackConfiguration
}

struct SessionConfigurationBuilder {
    func build(from input: SessionConfigurationInput) -> DictationStartOptions {
        let selectedModel = effectiveVoiceModelDescriptor(for: input.selectedLanguage, input: input)
        let supportsLiveTranscription = selectedModel?.supportsLiveTranscription ?? true
        return DictationStartOptions(
            mode: !supportsLiveTranscription ? .finalize : dictationMode(
                streamingEnabled: input.streamingEnabled,
                deliveryMode: input.finalResultDeliveryMode
            ),
            language: input.selectedLanguage,
            translationOutput: selectedModel?.supportsTranslationToEnglish == false
                ? .original
                : input.translationOutputMode,
            performance: selectedModel?.supportsQualityProfile == false
                ? .auto : input.performanceProfile,
            selectedVoiceProviderID: effectiveVoiceProviderID(
                for: input.selectedLanguage, input: input
            ),
            selectedVoiceModelID: selectedModel?.id ?? input.selectedVoiceModelID,
            liveRewriteScope: input.liveRewriteScope,
            snippetRules: input.snippetRules,
            finalResultDeliveryMode: input.finalResultDeliveryMode,
            clipboardFallbackWhenNoTarget: input.clipboardFallbackWhenNoTarget,
            simulateKeypresses: input.simulateKeypresses,
            restoreClipboardAfterPaste: input.restoreClipboardAfterPaste,
            autoSendAfterPaste: input.autoSendAfterPaste,
            muteMusicWhileDictating: input.muteMusicWhileDictating,
            asrInitialPrompt: input.asrInitialPrompt,
            dictionaryTerms: input.dictionaryTerms,
            liveContextText: input.liveContextText,
            finalContextText: input.finalContextText,
            aiProcessing: input.aiProcessing,
            audioProcessing: input.audioProcessing,
            soundFeedback: input.soundFeedback
        )
    }

    func effectiveVoiceProviderID(
        for language: DictationLanguage,
        input: SessionConfigurationInput
    ) -> String {
        effectiveVoiceModelDescriptor(for: language, input: input)?.providerID
            ?? input.selectedVoiceProviderID
    }

    func effectiveVoiceModelDescriptor(
        for language: DictationLanguage,
        input: SessionConfigurationInput
    ) -> VoiceModelDescriptor? {
        VoiceModelCapabilityPolicy().effectiveModel(
            for: language,
            selectedModelID: input.selectedVoiceModelID,
            overrides: input.voiceLanguageOverrides,
            catalog: input.voiceModels,
            installedFiles: input.installedVoiceModelFileNames
        )
    }

    private func dictationMode(
        streamingEnabled: Bool,
        deliveryMode: FinalResultDeliveryMode
    ) -> DictationMode {
        if deliveryMode == .clipboardOnly {
            return .finalize
        }
        return streamingEnabled ? .streaming : .finalize
    }

}
