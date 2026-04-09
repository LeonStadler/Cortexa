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
    let aiProcessing: AIProcessingConfiguration
    let audioProcessing: AudioProcessingConfiguration
    let soundFeedback: SoundFeedbackConfiguration
}

struct SessionConfigurationBuilder {
    func build(from input: SessionConfigurationInput) -> DictationStartOptions {
        DictationStartOptions(
            mode: dictationMode(
                streamingEnabled: input.streamingEnabled,
                deliveryMode: input.finalResultDeliveryMode
            ),
            language: input.selectedLanguage,
            translationOutput: input.translationOutputMode,
            performance: input.performanceProfile,
            selectedVoiceProviderID: effectiveVoiceProviderID(
                for: input.selectedLanguage,
                input: input
            ),
            selectedVoiceModelID:
                effectiveVoiceModelDescriptor(for: input.selectedLanguage, input: input)?.id
                ?? input.selectedVoiceModelID,
            liveRewriteScope: input.liveRewriteScope,
            snippetRules: input.snippetRules,
            finalResultDeliveryMode: input.finalResultDeliveryMode,
            clipboardFallbackWhenNoTarget: input.clipboardFallbackWhenNoTarget,
            simulateKeypresses: input.simulateKeypresses,
            restoreClipboardAfterPaste: input.restoreClipboardAfterPaste,
            autoSendAfterPaste: input.autoSendAfterPaste,
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
        let overrideDescriptor: VoiceModelDescriptor?
        if language != .auto,
            let overrideID = input.voiceLanguageOverrides.first(where: {
                $0.languageCode == language.rawValue
            })?.modelID
        {
            overrideDescriptor = input.voiceModels.first(where: { $0.id == overrideID })
        } else {
            overrideDescriptor = nil
        }

        if let overrideDescriptor, canUseVoiceModel(overrideDescriptor, for: language, input: input)
        {
            return overrideDescriptor
        }

        if let selectedVoiceModel = selectedVoiceModelDescriptor(input: input),
            canUseVoiceModel(selectedVoiceModel, for: language, input: input)
        {
            return selectedVoiceModel
        }

        if let standard = input.voiceModels.first(where: {
            $0.id == LocalVoiceModelCatalog.defaultModelID
        }),
            canUseVoiceModel(standard, for: language, input: input)
        {
            return standard
        }

        return input.voiceModels.first(where: { canUseVoiceModel($0, for: language, input: input) })
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

    private func selectedVoiceModelDescriptor(
        input: SessionConfigurationInput
    ) -> VoiceModelDescriptor? {
        input.voiceModels.first(where: { $0.id == input.selectedVoiceModelID })
    }

    private func canUseVoiceModel(
        _ descriptor: VoiceModelDescriptor,
        for language: DictationLanguage,
        input: SessionConfigurationInput
    ) -> Bool {
        if !isVoiceModelInstalled(descriptor, input: input) {
            return false
        }
        guard let languageCode = descriptor.languageCode else { return true }
        return language == .auto || language.rawValue == languageCode
    }

    private func isVoiceModelInstalled(
        _ descriptor: VoiceModelDescriptor,
        input: SessionConfigurationInput
    ) -> Bool {
        guard descriptor.providerID == VoiceProviderID.whisperCpp.rawValue else {
            return descriptor.installState == .bundled
        }
        guard let localFileName = descriptor.localFileName else { return false }
        return input.installedVoiceModelFileNames.contains(localFileName)
    }
}
