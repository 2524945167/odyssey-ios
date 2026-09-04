import XCTest
import SwiftUI
@testable import Odyssey

final class OdysseySmokeTests: XCTestCase {

    @MainActor
    func testContentViewImageRenderer() throws {
        let targetWidth: CGFloat = 393
        let targetHeight: CGFloat = 852
        let view = ContentView()
            .frame(width: targetWidth, height: targetHeight)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let uiImage = renderer.uiImage

        let image = try XCTUnwrap(uiImage, "ContentView 必须成功通过 ImageRenderer 渲染出非空 UIImage")
        XCTAssertGreaterThan(image.size.width, 0, "渲染出的 UIImage 宽度必须大于 0")
        XCTAssertGreaterThan(image.size.height, 0, "渲染出的 UIImage 高度必须大于 0")
        XCTAssertEqual(image.size.width, targetWidth, accuracy: 1.0, "渲染出的 UIImage 宽度应与 frame 尺寸匹配")
        XCTAssertEqual(image.size.height, targetHeight, accuracy: 1.0, "渲染出的 UIImage 高度应与 frame 尺寸匹配")
    }
}
