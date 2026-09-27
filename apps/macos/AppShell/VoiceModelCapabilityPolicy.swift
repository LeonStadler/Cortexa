import ASRCore
import Foundation

enum VoiceModelCapabilityChoice: Equatable {
    case language(DictationLanguage)
    case translation(TranslationOutputMode)
    case liveText
    case quality(DictationPerformance)

    func requiredLanguage(current: DictationLanguage) -> DictationLanguage {
        if case .language(let language) = self { return language }
        return current
    }
}

struct VoiceModelCapabilityPolicy {
    func effectiveModel(
        for language: DictationLanguage,
        selectedModelID: String,
        overrides: [VoiceLanguageOverride],
        catalog: [VoiceModelDescriptor],
        installedFiles: Set<String>
    ) -> VoiceModelDescriptor? {
        let overrideID = language == .auto ? nil : overrides.first {
            $0.languageCode == language.rawValue
        }?.modelID
        let candidateIDs = [overrideID, selectedModelID, LocalVoiceModelCatalog.defaultModelID]
            .compactMap { $0 }
        for id in candidateIDs {
            if let model = catalog.first(where: { $0.id == id }),
                isInstalled(model, files: installedFiles),
                supports(language: language, model: model) {
                return model
            }
        }
        return catalog.first {
            isInstalled($0, files: installedFiles) && supports(language: language, model: $0)
        }
    }

    func isInstalled(_ model: VoiceModelDescriptor, files: Set<String>) -> Bool {
        model.localFileName.map { files.contains($0) } == true
    }

    func supports(
        _ choice: VoiceModelCapabilityChoice,
        model: VoiceModelDescriptor,
        currentLanguage: DictationLanguage
    ) -> Bool {
        let language = choice.requiredLanguage(current: currentLanguage)
        guard supports(language: language, model: model) else { return false }
        switch choice {
        case .language:
            return true
        case .translation(let mode):
            return mode == .original || model.supportsTranslationToEnglish
        case .liveText:
            return model.supportsLiveTranscription
        case .quality:
            return model.supportsQualityProfile
        }
    }

    func supports(language: DictationLanguage, model: VoiceModelDescriptor) -> Bool {
        if language == .auto { return model.supportsAutomaticLanguageDetection }
        guard model.supportsLanguageSelection else { return false }
        if let fixed = model.languageCode, fixed != language.rawValue { return false }
        return model.supportedLanguageCodes?.contains(language.rawValue) ?? true
    }

    func suggestedModel(
        for choice: VoiceModelCapabilityChoice,
        currentModel: VoiceModelDescriptor,
        currentLanguage: DictationLanguage,
        catalog: [VoiceModelDescriptor],
        installedFiles: Set<String>
    ) -> VoiceModelDescriptor? {
        let eligible = catalog.enumerated().filter { _, model in
            model.id != currentModel.id
                && model.installState != .unavailable
                && supports(language: currentLanguage, model: model)
                && supports(choice, model: model, currentLanguage: currentLanguage)
        }
        if let preferredID = currentModel.preferredCompatibleModelID,
            let preferred = eligible.first(where: { $0.element.id == preferredID }) {
            return preferred.element
        }
        return eligible.min { left, right in
            let lhs = rank(left.element, index: left.offset, current: currentModel, installed: installedFiles)
            let rhs = rank(right.element, index: right.offset, current: currentModel, installed: installedFiles)
            return lhs.lexicographicallyPrecedes(rhs)
        }?.element
    }

    private func rank(
        _ model: VoiceModelDescriptor,
        index: Int,
        current: VoiceModelDescriptor,
        installed: Set<String>
    ) -> [Int] {
        let installedRank = model.localFileName.map { installed.contains($0) } == true ? 0 : 1
        let providerRank = model.providerID == current.providerID ? 0 : 1
        let distance = abs(model.speedScore - current.speedScore)
            + abs(model.accuracyScore - current.accuracyScore)
        return [installedRank, providerRank, distance, index]
    }
}
