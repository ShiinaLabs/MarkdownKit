import AppKit
import XCTest
@testable import MarkdownKit

final class MarkdownRendererTests: XCTestCase {
    func testRendersHeadingParagraphAndUnorderedList() {
        let markdown = """
        # Heading

        Body paragraph.

        - First
        - Second
        """

        let rendered = MarkdownRenderer.render(markdown, pointSize: 13)

        XCTAssertTrue(rendered.string.contains("Heading"))
        XCTAssertTrue(rendered.string.contains("Body paragraph."))
        XCTAssertTrue(rendered.string.contains("•\tFirst"))
        XCTAssertTrue(rendered.string.contains("•\tSecond"))
    }

    func testHeadingUsesLargerBoldFont() throws {
        let rendered = MarkdownRenderer.render("# Heading", pointSize: 12)
        let font = try XCTUnwrap(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        XCTAssertGreaterThan(font.pointSize, 12)
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    func testCodeBlockUsesMonospacedFont() throws {
        let rendered = MarkdownRenderer.render("```\nlet value = 1\n```", pointSize: 13)
        let source = rendered.string as NSString
        let range = source.range(of: "let value = 1")
        XCTAssertNotEqual(range.location, NSNotFound)

        let font = try XCTUnwrap(rendered.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(font.isFixedPitch)
    }

    func testRelativeLinkUsesBaseURL() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://example.com/docs/"))
        let rendered = MarkdownRenderer.render("[Guide](guide)", baseURL: baseURL)
        let link = rendered.attribute(.link, at: 0, effectiveRange: nil)

        XCTAssertEqual((link as? URL)?.absoluteString, "https://example.com/docs/guide")
    }

    func testMeasureHeightReturnsPositiveValue() {
        let height = MarkdownTextView.measureHeight(
            markdown: "# Heading\n\nParagraph",
            width: 400
        )

        XCTAssertGreaterThan(height, 0)
    }
}
