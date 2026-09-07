import XCTest
@testable import Odyssey

final class TranslationCompatibilityTests: XCTestCase {
    private func configuration(_ format: APIFormat, _ base: String, _ model: String) -> APIConfiguration {
        APIConfiguration(apiFormat: format, baseURL: base, modelID: model)
    }

    private func request(_ configuration: APIConfiguration, enabled: Bool = false) throws -> URLRequest {
        try TranslationService.validatedRequest(configuration: configuration, apiKey: TranslationTestFixture.key,
                                                source: "  hello 🌏\n", sourceLanguage: .english, targetLanguage: .chinese,
                                                options: TranslationOptions(thinkingEnabled: enabled))
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }

    private func assertNoControls(_ payload: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        for field in ["enable_thinking", "reasoning", "reasoning_effort", "thinking", "thinking_budget", "extra_body", "output_config"] {
            XCTAssertNil(payload[field], field, file: file, line: line)
        }
    }

    func testOpenAIChatUsesEffortWithoutProviderSpecificFields() throws {
        for model in ["gpt-5.1", "gpt-5.1-2025-11-13", "gpt-5.2", "gpt-5.2-2025-12-11", "gpt-5.4",
                      "gpt-5.5", "gpt-5.6", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna"] {
            let config = configuration(.openAIChatCompletions, "https://api.openai.com/v1", model)
            XCTAssertEqual(TranslationThinkingPolicy.control(for: config), .chatEffort)
            for enabled in [false, true] {
                let payload = try body(request(config, enabled: enabled))
                XCTAssertEqual(payload["reasoning_effort"] as? String, enabled ? "medium" : "none")
                XCTAssertEqual(Set(payload.keys), ["model", "messages", "max_completion_tokens", "stream", "store", "reasoning_effort"])
                XCTAssertEqual(payload["model"] as? String, model)
            }
        }
    }

    func testOpenAIResponsesUsesNestedEffortAndPreservesTranslationBudget() throws {
        let config = configuration(.openAIResponses, "https://api.openai.com/v1", "gpt-5.6-sol")
        for enabled in [false, true] {
            let payload = try body(request(config, enabled: enabled))
            XCTAssertEqual(payload["reasoning"] as? [String: String], ["effort": enabled ? "medium" : "none"])
            XCTAssertEqual(Set(payload.keys), ["model", "input", "instructions", "max_output_tokens", "stream", "store", "reasoning"])
            XCTAssertEqual(payload["max_output_tokens"] as? Int, 8192)
            XCTAssertEqual(payload["input"] as? String, "  hello 🌏\n")
            XCTAssertEqual(payload["store"] as? Bool, false)
        }
    }

    func testDeepSeekChatUsesTypedThinkingAtBothOfficialBasePaths() throws {
        for base in ["https://api.deepseek.com", "https://api.deepseek.com/v1/"] {
            for model in ["deepseek-v4-flash", "deepseek-v4-pro"] {
                let config = configuration(.openAIChatCompletions, base, model)
                for enabled in [false, true] {
                    let payload = try body(request(config, enabled: enabled))
                    XCTAssertEqual(payload["thinking"] as? [String: String], ["type": enabled ? "enabled" : "disabled"])
                    XCTAssertEqual(Set(payload.keys), ["model", "messages", "max_completion_tokens", "stream", "store", "thinking"])
                }
            }
        }
    }

    func testDeepSeekResponsesUsesDocumentedEffortMapping() throws {
        let config = configuration(.openAIResponses, "https://api.deepseek.com/v1", "deepseek-v4-pro")
        for enabled in [false, true] {
            let payload = try body(request(config, enabled: enabled))
            // DeepSeek documents medium as its high effort; none really disables thinking.
            XCTAssertEqual(payload["reasoning"] as? [String: String], ["effort": enabled ? "medium" : "none"])
            XCTAssertNil(payload["thinking"])
            XCTAssertNil(payload["enable_thinking"])
        }
    }

    func testHostedModelsUseHostContractNotModelBrand() throws {
        for model in ["deepseek-v4-flash", "deepseek-v3.2", "glm-5.2", "kimi-k2.5", "qwen3.8-flash", "qwen3.7-flash"] {
            let config = configuration(.openAIChatCompletions, "https://dashscope.aliyuncs.com/compatible-mode/v1", model)
            for enabled in [false, true] {
                let payload = try body(request(config, enabled: enabled))
                XCTAssertEqual(payload["enable_thinking"] as? Bool, enabled)
                XCTAssertNil(payload["thinking"])
                XCTAssertNil(payload["reasoning_effort"])
            }
        }
    }

    func testClaudeAdaptiveControlDoesNotAddManualBudgetOrEffort() throws {
        for model in ["claude-opus-4-6", "claude-sonnet-4-6", "claude-opus-4-7", "claude-opus-4-8", "claude-sonnet-5"] {
            let config = configuration(.anthropicMessages, "https://api.anthropic.com/v1", model)
            for enabled in [false, true] {
                let built = try request(config, enabled: enabled)
                let payload = try body(built)
                XCTAssertEqual(payload["thinking"] as? [String: String], ["type": enabled ? "adaptive" : "disabled"])
                XCTAssertEqual(Set(payload.keys), ["model", "messages", "system", "max_tokens", "stream", "thinking"])
                XCTAssertEqual(built.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
                XCTAssertNil(built.value(forHTTPHeaderField: "Authorization"))
            }
        }
    }

    func testGeminiFlashUsesOpenAICompatibleEffort() throws {
        for model in ["gemini-2.5-flash", "gemini-2.5-flash-lite"] {
            let config = configuration(.openAIChatCompletions, "https://generativelanguage.googleapis.com/v1beta/openai/", model)
            for enabled in [false, true] {
                let built = try request(config, enabled: enabled)
                let payload = try body(built)
                XCTAssertEqual(payload["reasoning_effort"] as? String, enabled ? "medium" : "none")
                XCTAssertEqual(built.url?.path, "/v1beta/openai/chat/completions")
                XCTAssertNil(payload["thinking"])
                XCTAssertNil(payload["extra_body"])
            }
        }
    }

    func testMandatoryThinkingAndSpecialConfigurationModelsRemainUnmanaged() throws {
        let cases = [
            configuration(.openAIResponses, "https://api.openai.com/v1", "gpt-6-astra"),
            configuration(.openAIChatCompletions, "https://api.openai.com/v1", "gpt-5"),
            configuration(.openAIChatCompletions, "https://api.openai.com/v1", "o3"),
            configuration(.anthropicMessages, "https://api.anthropic.com/v1", "claude-sonnet-4-5"),
            configuration(.anthropicMessages, "https://api.anthropic.com/v1", "claude-opus-5"),
            configuration(.anthropicMessages, "https://api.anthropic.com/v1", "claude-mythos-5"),
            configuration(.openAIChatCompletions, "https://generativelanguage.googleapis.com/v1beta/openai", "gemini-2.5-pro"),
            configuration(.openAIChatCompletions, "https://generativelanguage.googleapis.com/v1beta/openai", "gemini-3-pro-preview"),
            configuration(.openAIChatCompletions, "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen3.8-2.4t-a95b")
        ]
        for config in cases {
            XCTAssertFalse(TranslationThinkingPolicy.supports(config), config.modelID)
            for enabled in [false, true] {
                let payload = try body(request(config, enabled: enabled))
                assertNoControls(payload)
                XCTAssertEqual(payload["model"] as? String, config.modelID)
            }
        }
    }

    func testUnknownProxyStillBuildsUnchangedRequestsWithoutGuessingControls() throws {
        for format in APIFormat.allCases {
            for model in ["gpt-5.6-sol", "claude-sonnet-4-6", "qwen3.7-flash", "deepseek-v4-flash", "gemini-2.5-flash", "my-custom-model"] {
                let config = configuration(format, "https://example.invalid/custom/v1", model)
                for enabled in [false, true] {
                    let built = try request(config, enabled: enabled)
                    let payload = try body(built)
                    XCTAssertFalse(TranslationThinkingPolicy.supports(config))
                    assertNoControls(payload)
                    XCTAssertEqual(payload["model"] as? String, model)
                    XCTAssertEqual(built.url?.host, "example.invalid")
                    XCTAssertTrue(try XCTUnwrap(built.url?.path).hasPrefix("/custom/v1/"))
                    XCTAssertEqual(payload["stream"] as? Bool, true)
                    XCTAssertEqual(built.timeoutInterval, 60)
                }
            }
        }
    }

    func testCapabilityRequiresExactHostModelPathAndProtocol() {
        for base in ["https://api.openai.com.example.invalid/v1", "https://api.openai.com/wrong/v1",
                     "http://api.openai.com/v1", "https://user:password@api.openai.com/v1",
                     "https://api.openai.com:444/v1", "https://api.openai.com/v1?x=1", "https://api.openai.com/v1#x"] {
            XCTAssertNil(TranslationThinkingPolicy.control(for: configuration(.openAIResponses, base, "gpt-5.6-sol")))
        }
        XCTAssertNotNil(TranslationThinkingPolicy.control(for: configuration(.openAIResponses, "https://API.OPENAI.COM:443/v1/", " gpt-5.6-sol ")))
        for config in [configuration(.anthropicMessages, "https://api.openai.com/v1", "gpt-5.6-sol"),
                       configuration(.openAIResponses, "https://api.anthropic.com/v1", "claude-sonnet-4-6"),
                       configuration(.openAIChatCompletions, "https://api.openai.com/v1", "gpt-5.6-sol-new"),
                       configuration(.openAIResponses, "https://dashscope.aliyuncs.com/compatible-mode/v1", "kimi-k2.5")] {
            XCTAssertNil(TranslationThinkingPolicy.control(for: config))
        }
    }

    func testProbesAndUnspecifiedStreamingThinkingAreUnchangedForAllAdapters() throws {
        let cases = [configuration(.openAIChatCompletions, "https://api.openai.com/v1", "gpt-5.6-sol"),
                     configuration(.openAIResponses, "https://api.openai.com/v1", "gpt-5.6-sol"),
                     configuration(.anthropicMessages, "https://api.anthropic.com/v1", "claude-sonnet-4-6"),
                     configuration(.openAIChatCompletions, "https://api.deepseek.com/v1", "deepseek-v4-flash"),
                     configuration(.openAIChatCompletions, "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen3.7-flash")]
        for config in cases {
            let probe = try APIProbeRequestBuilder.build(configuration: config, apiKey: TranslationTestFixture.key, outputLimit: 256)
            assertNoControls(try body(probe))
            XCTAssertEqual(try body(probe)["stream"] as? Bool, false)
            XCTAssertEqual(probe.timeoutInterval, 30)
            let generic = try StreamingRequestBuilder.build(configuration: config, apiKey: TranslationTestFixture.key, input: "hello", outputLimit: 512)
            assertNoControls(try body(generic))
        }
    }

    @MainActor
    func testGamingRenamePreservesOldSelectionCustomTemplateAndOtherSettings() throws {
        let fixture = try TranslationTestFixture()
        defer { fixture.cleanUp() }
        let originalConfig = fixture.storage.loadConfiguration()
        try fixture.preferences.save(TranslationOptions(outputLimit: 16384, idleTimeoutSeconds: 120, thinkingEnabled: true))
        let saved = Data(#"{"selectedStyle":"gaming","overrides":{"gaming":"旧版用户自己编辑的游戏术语要求","business":"保留合同条款"}}"#.utf8)
        fixture.defaults.set(saved, forKey: TranslationPreferences.stylesKey)
        let reloaded = TranslationPreferences(defaults: fixture.defaults)
        XCTAssertEqual(reloaded.styles.selectedStyle.title, "网络聊天")
        XCTAssertEqual(reloaded.styles.selectedStyle.rawValue, "gaming")
        XCTAssertEqual(reloaded.options.styleInstructions, "旧版用户自己编辑的游戏术语要求")
        XCTAssertEqual(reloaded.styles.instructions(for: .business), "保留合同条款")
        XCTAssertEqual(fixture.defaults.data(forKey: TranslationPreferences.stylesKey), saved)
        XCTAssertEqual(reloaded.options.outputLimit, 16384)
        XCTAssertEqual(reloaded.options.idleTimeoutSeconds, 120)
        XCTAssertTrue(reloaded.options.thinkingEnabled)
        XCTAssertEqual(fixture.storage.loadConfiguration(), originalConfig)
        XCTAssertEqual(try fixture.keychain.readAPIKey(), TranslationTestFixture.key)
    }

    @MainActor
    func testUneditedGamingSelectionReceivesBroaderDefaultWithoutStorageRewrite() throws {
        let fixture = try TranslationTestFixture()
        defer { fixture.cleanUp() }
        let saved = Data(#"{"selectedStyle":"gaming","overrides":{}}"#.utf8)
        fixture.defaults.set(saved, forKey: TranslationPreferences.stylesKey)
        let reloaded = TranslationPreferences(defaults: fixture.defaults)
        XCTAssertEqual(reloaded.options.styleInstructions, TranslationStyle.gaming.defaultInstructions)
        XCTAssertTrue(reloaded.options.styleInstructions.contains("社交平台、群聊、私信"))
        XCTAssertFalse(reloaded.styles.isModified(.gaming))
        XCTAssertEqual(fixture.defaults.data(forKey: TranslationPreferences.stylesKey), saved)
    }

    @MainActor
    func testSettingsSelectionDuringRequestAffectsOnlyNextRequest() async throws {
        let service = ControlledTranslationService()
        addTeardownBlock { await service.finishAll() }
        let fixture = try TranslationTestFixture(service: service)
        defer { fixture.cleanUp() }
        let first = try XCTUnwrap(fixture.model.startTranslation())
        let previous = fixture.preferences.styles
        // This is the settings Picker's binding, not the removed homepage action.
        fixture.preferences.selectStyle(.gaming)
        fixture.model.stylePreferencesDidChange(from: previous)
        try await waitForCalls(service, count: 1)
        let old = await service.calls[0]
        XCTAssertEqual(old.options.style, .natural)
        try await service.emit("旧风格译文", call: 0)
        await service.finish(.completed, call: 0)
        await first.value
        XCTAssertEqual(fixture.model.translatedText, "旧风格译文")
        XCTAssertEqual(fixture.model.state, .styleChanged)
        let count = await service.callCount
        XCTAssertEqual(count, 1)
        let second = try XCTUnwrap(fixture.model.startTranslation())
        try await waitForCalls(service, count: 2)
        let new = await service.calls[1]
        XCTAssertEqual(new.options.style, .gaming)
        XCTAssertEqual(new.options.styleInstructions, TranslationStyle.gaming.defaultInstructions)
        await service.finish(.noText, call: 1)
        await second.value
    }

    @MainActor
    private func waitForCalls(_ service: ControlledTranslationService, count: Int) async throws {
        for _ in 0..<200 {
            if await service.callCount >= count { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Expected translation call did not arrive")
        throw StreamingError.timedOut
    }
}
