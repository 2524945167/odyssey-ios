import XCTest
@testable import Odyssey

final class APIFormatMigrationTests: XCTestCase {
    @MainActor
    func testLegacyConfigurationPreservesEndpointModelAndKey() throws {
        let suiteName = "com.kupetis.odyssey.tests.migration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacyData = Data(#"{"apiFormat":"openai_compatible","baseURL":"https://example.com/custom/v1","modelID":"fixture-model"}"#.utf8)
        defaults.set(legacyData, forKey: UserDefaultsConfigurationStorage.defaultStorageKey)
        let storage = UserDefaultsConfigurationStorage(userDefaults: defaults)
        let keychain = MockKeychainService()
        let fakeKey = "odyssey-migration-fixture-not-a-credential"
        try keychain.saveAPIKey(fakeKey)
        let store = APIConfigurationStore(configurationStorage: storage, keychainService: keychain)

        let configuration = try XCTUnwrap(storage.loadConfiguration())
        XCTAssertEqual(configuration.apiFormat, .openAIChatCompletions)
        XCTAssertEqual(configuration.baseURL, "https://example.com/custom/v1")
        XCTAssertEqual(configuration.modelID, "fixture-model")
        XCTAssertEqual(try keychain.readAPIKey(), fakeKey)
        // 加载迁移不写存储、不替换密钥；显式保存才写入新格式标识。
        XCTAssertEqual(defaults.data(forKey: UserDefaultsConfigurationStorage.defaultStorageKey), legacyData)
        let viewModel = APIConfigurationViewModel(store: store)
        XCTAssertEqual(viewModel.apiFormat, .openAIChatCompletions)
        XCTAssertEqual(viewModel.apiKeyInput, "")
        XCTAssertTrue(viewModel.hasSavedAPIKey)
        XCTAssertTrue(viewModel.save())
        let savedData = try XCTUnwrap(defaults.data(forKey: UserDefaultsConfigurationStorage.defaultStorageKey))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: savedData) as? [String: String])
        XCTAssertEqual(json["apiFormat"], "openai_chat_completions")
        XCTAssertEqual(json["baseURL"], configuration.baseURL)
        XCTAssertEqual(json["modelID"], configuration.modelID)
        XCTAssertEqual(try keychain.readAPIKey(), fakeKey)
        XCTAssertEqual(keychain.addCallCount, 1)
        XCTAssertEqual(keychain.updateCallCount, 0)
        XCTAssertEqual(keychain.deleteCallCount, 0)
    }

    func testUnknownFormatFailsDecodingWithoutSelectingAnotherProtocol() {
        let data = Data(#""future_unknown_format""#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(APIFormat.self, from: data)) { error in
            guard case DecodingError.dataCorrupted = error else {
                return XCTFail("Expected unsupported format decoding error")
            }
        }
    }
}
