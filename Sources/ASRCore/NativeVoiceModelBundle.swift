import CryptoKit
import Foundation

public struct NativeVoiceModelFile: Codable, Sendable {
    public let path: String
    public let bytes: Int64
    public let sha256: String
}

public struct NativeVoiceModelBundle: Codable, Sendable {
    public let modelID: String
    public let repository: String
    public let revision: String
    public let bundleName: String
    public let files: [NativeVoiceModelFile]

    public var expectedBytes: Int64 { files.reduce(0) { $0 + $1.bytes } }

    public static func manifest(modelID: String) throws -> NativeVoiceModelBundle {
        guard let result = all.first(where: { $0.modelID == modelID }) else {
            throw VoiceModelInstallerError.modelNotDownloadable(modelID)
        }
        return result
    }

    public func validate(at directory: URL) throws {
        for file in files {
            let url = directory.appendingPathComponent(file.path)
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                values.fileSize.map(Int64.init) == file.bytes else {
                throw VoiceModelInstallerError.runtimeInstallFailed("Invalid model file: \(file.path)")
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard checksum == file.sha256 else {
                throw VoiceModelInstallerError.runtimeInstallFailed("Model checksum mismatch: \(file.path)")
            }
        }
    }

    public static let all: [NativeVoiceModelBundle] = [
        NativeVoiceModelBundle(modelID: "fermion.phonon2", repository: "FluidInference/phonon-2-coreml", revision: "1702fc22e76f203d5ca464cd5d3ef130a45ce2c0", bundleName: "phonon-2-coreml", files: [
            NativeVoiceModelFile(path: "Decoder.mlmodelc/analytics/coremldata.bin", bytes: 243, sha256: "3d1a9cd4d7b7956d20c48d9a8041717f9f02c6db72dfeda565080e1cff1db3a3"),
            NativeVoiceModelFile(path: "Decoder.mlmodelc/coremldata.bin", bytes: 554, sha256: "2590e4588972f8d3d1ddb10ce603decffd2e9bb79a88c6096a58c5732f6369fd"),
            NativeVoiceModelFile(path: "Decoder.mlmodelc/model.mil", bytes: 13110, sha256: "956f600207f88396017ca5c96cfa3acd5bfee60835a5b44b762e033a8fb28955"),
            NativeVoiceModelFile(path: "Decoder.mlmodelc/weights/weight.bin", bytes: 23604992, sha256: "05181616ed1af70b2aad0463d08d1d73a245af4ccb6159df79994f28c135d9d6"),
            NativeVoiceModelFile(path: "Encoder.mlmodelc/analytics/coremldata.bin", bytes: 243, sha256: "3d674b78b1a6916586611089d7ac80b4d20d94f691c0497f92b2a58339c5a0e2"),
            NativeVoiceModelFile(path: "Encoder.mlmodelc/coremldata.bin", bytes: 500, sha256: "4b661445d3e93201e3d70d616eaa9f061117a4ee1e4a6191d18a23dc23068b84"),
            NativeVoiceModelFile(path: "Encoder.mlmodelc/model.mil", bytes: 2734921, sha256: "b8954fb3ef2fedcb9ce01c67f0490cfd905b79862a33912dea12100cd24a5170"),
            NativeVoiceModelFile(path: "Encoder.mlmodelc/weights/weight.bin", bytes: 338391488, sha256: "d6a51593fc07b3c81989d5f871f687e78c52998aae0b06d000faced47313edb0"),
            NativeVoiceModelFile(path: "JointDecisionv3.mlmodelc/analytics/coremldata.bin", bytes: 243, sha256: "7b53f663c4400205f8bc00243076de50f95d8a1a64978dee7232eb0ddc7d683c"),
            NativeVoiceModelFile(path: "JointDecisionv3.mlmodelc/coremldata.bin", bytes: 586, sha256: "8d2170f28b28466476f62484a0c8b07c2d31713ac254d1b7cf80eba8070e9554"),
            NativeVoiceModelFile(path: "JointDecisionv3.mlmodelc/model.mil", bytes: 11777, sha256: "791b3c3cf3eb2079c84623fc880f6bba008d1366e5f8b03e9a8ed8bd4d7194a0"),
            NativeVoiceModelFile(path: "JointDecisionv3.mlmodelc/weights/weight.bin", bytes: 12642764, sha256: "5f922e335bc57174645fd6ede581395f1ae846f7227898301b5a1a7585f4ab45"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/analytics/coremldata.bin", bytes: 243, sha256: "c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/coremldata.bin", bytes: 486, sha256: "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/metadata.json", bytes: 2841, sha256: "2a98699e22d279dd37fa1d238aeb1c6db1df0d6fad687775324157689d8f3acf"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/model.mil", bytes: 28181, sha256: "4b8518a956450fec57f06c2a21bdffc26973f7f1fa6842fb38fe917f896b6b93"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/weights/weight.bin", bytes: 491072, sha256: "129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea"),
            NativeVoiceModelFile(path: "parakeet_vocab.json", bytes: 151122, sha256: "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735"),
        ]),
        NativeVoiceModelBundle(modelID: "moondream.parakeet-redux", repository: "FluidInference/parakeet-redux-coreml", revision: "8c5ef97a29cd120dc76b354b3f22b7fec3b486f9", bundleName: "parakeet-redux-coreml", files: [
            NativeVoiceModelFile(path: "Decoder.mlmodelc/analytics/coremldata.bin", bytes: 243, sha256: "7f24e7248d57024c6f1c5a2ea306f4a6a89db45a363218523bb6410c4b1aecf0"),
            NativeVoiceModelFile(path: "Decoder.mlmodelc/coremldata.bin", bytes: 560, sha256: "422da51d983e93a3e48cd6d46a17d6c32844452414c8e242fb0caaca2b8af5ed"),
            NativeVoiceModelFile(path: "Decoder.mlmodelc/model.mil", bytes: 13110, sha256: "956f600207f88396017ca5c96cfa3acd5bfee60835a5b44b762e033a8fb28955"),
            NativeVoiceModelFile(path: "Decoder.mlmodelc/weights/weight.bin", bytes: 23604992, sha256: "6c6c88c23ee5492a6b229e8cc636ddadb2b01ae0dd559d9cb63123bebf507d77"),
            NativeVoiceModelFile(path: "Encoder.mlmodelc/analytics/coremldata.bin", bytes: 243, sha256: "7862e972e09315df099d4bfd320743bf106acbf7fe4343317f9de45b0635d7b7"),
            NativeVoiceModelFile(path: "Encoder.mlmodelc/coremldata.bin", bytes: 506, sha256: "ca0b212fe3c06c3ccd35e508fa61e4dfaad19dd0c55b82e4f5bf8711e7758fd9"),
            NativeVoiceModelFile(path: "Encoder.mlmodelc/model.mil", bytes: 965906, sha256: "165487e314ed93c4a44dfec99d57be4e436e7c3dba6eef49fd3f0daf9de6d0d4"),
            NativeVoiceModelFile(path: "Encoder.mlmodelc/weights/weight.bin", bytes: 182389312, sha256: "adbb5550dc6488717d3a1407b53122fbdb1af5e99c330ee20f8d8cfd9ec49252"),
            NativeVoiceModelFile(path: "JointDecisionv3.mlmodelc/analytics/coremldata.bin", bytes: 243, sha256: "fc857a756b8c9c9f31aa9e1062766cc0a82ac035ef369d6e1cbe97184921479c"),
            NativeVoiceModelFile(path: "JointDecisionv3.mlmodelc/coremldata.bin", bytes: 592, sha256: "611ea653e2adede7cc1cfe70da36296844f97e95e2c7dd961d45230e5599389d"),
            NativeVoiceModelFile(path: "JointDecisionv3.mlmodelc/model.mil", bytes: 11777, sha256: "791b3c3cf3eb2079c84623fc880f6bba008d1366e5f8b03e9a8ed8bd4d7194a0"),
            NativeVoiceModelFile(path: "JointDecisionv3.mlmodelc/weights/weight.bin", bytes: 12642764, sha256: "73b0288acd115fc4c36038f66b6cbf49233182488febf5d8c787bea4009535f7"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/analytics/coremldata.bin", bytes: 243, sha256: "c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/coremldata.bin", bytes: 486, sha256: "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/metadata.json", bytes: 2841, sha256: "2a98699e22d279dd37fa1d238aeb1c6db1df0d6fad687775324157689d8f3acf"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/model.mil", bytes: 28181, sha256: "4b8518a956450fec57f06c2a21bdffc26973f7f1fa6842fb38fe917f896b6b93"),
            NativeVoiceModelFile(path: "Preprocessor.mlmodelc/weights/weight.bin", bytes: 491072, sha256: "129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea"),
            NativeVoiceModelFile(path: "parakeet_vocab.json", bytes: 151122, sha256: "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735"),
        ]),
    ]
}
