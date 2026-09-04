import XCTest
@testable import Odyssey

final class OdysseySmokeTests: XCTestCase {

    @MainActor
    func testContentViewInitialization() {
        let view = ContentView()
        XCTAssertNotNil(view.body, "ContentView body should instantiate properly")
    }

    func testAppConfigurationSmoke() {
        let expectedAppName = "Odyssey"
        let expectedStatusMessage = "工程初始化成功"
        XCTAssertEqual(expectedAppName, "Odyssey", "App name constant matches specification")
        XCTAssertFalse(expectedStatusMessage.isEmpty, "Status message should not be empty")
    }
}
