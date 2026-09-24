// MarkdownKit
//
// Portions of the block-level Markdown formatting approach in this file are
// derived from Sparkle's SUTextViewReleaseNotesView and are used under the
// terms of Sparkle's MIT-style license. See THIRD_PARTY_NOTICES.md.

import AppKit
import Foundation

/// Renders Markdown into an attributed string suitable for native macOS text views.
///
/// Foundation's Markdown parser preserves block structure as presentation intents,
/// but those intents do not automatically become the paragraph spacing, list markers,
/// indentation, and code-block layout expected from a release-notes style renderer.
/// `MarkdownRenderer` rebuilds those block-level details while preserving Foundation's
/// parsed inline attributes such as emphasis and links.
public enum MarkdownRenderer {
    /// Render Markdown into a styled `NSAttributedString`.
    ///
    /// - Parameters:
    ///   - markdown: Markdown source text.
    ///   - pointSize: Base body font size.
    ///   - baseURL: Optional base URL used to resolve relative links.
    /// - Returns: A rendered attributed string. If Markdown parsing fails, the source
    ///   is returned as plain text using the system font.
    public static func render(
        _ markdown: String,
        pointSize: CGFloat = 13,
        baseURL: URL? = nil
    ) -> NSAttributedString {
        do {
            let original = try NSAttributedString(
                markdown: markdown,
                options: .init(),
                baseURL: baseURL
            )
            return formatMarkdown(original, defaultFontPointSize: pointSize)
        } catch {
            return NSAttributedString(
                string: markdown,
                attributes: [.font: NSFont.systemFont(ofSize: pointSize)]
            )
        }
    }

    // NSPresentationIntent is NS_REFINED_FOR_SWIFT, so a few properties are not
    // directly nameable from Swift. Read the documented Objective-C properties
    // through KVC, mirroring the approach already proven in Wi-Fi Lens.

    private static func intValue(_ intent: AnyObject?, _ key: String) -> Int {
        (intent?.value(forKey: key) as? NSNumber)?.intValue ?? 0
    }

    private static func intentKind(_ intent: AnyObject?) -> Int {
        intValue(intent, "intentKind")
    }

    private static func headerLevel(_ intent: AnyObject?) -> Int {
        intValue(intent, "headerLevel")
    }

    private static func indentationLevel(_ intent: AnyObject?) -> Int {
        intValue(intent, "indentationLevel")
    }

    private static func ordinal(_ intent: AnyObject?) -> Int {
        intValue(intent, "ordinal")
    }

    private static func identity(_ intent: AnyObject?) -> Int {
        intValue(intent, "identity")
    }

    private static func parentIntent(_ intent: AnyObject?) -> AnyObject? {
        intent?.value(forKey: "parentIntent") as AnyObject?
    }

    // Raw NSPresentationIntentKind values. These mirror the order documented by
    // Foundation. If Apple changes that enum's ordering, this mapping must change.
    private enum Kind: Int {
        case paragraph = 0
        case header = 1
        case orderedList = 2
        case unorderedList = 3
        case listItem = 4
        case codeBlock = 5
        case blockQuote = 6
        case thematicBreak = 7
        case table = 8
        case tableHeaderRow = 9
        case tableRow = 10
        case tableCell = 11
    }

    private static func formatMarkdown(
        _ original: NSAttributedString,
        defaultFontPointSize pointSize: CGFloat
    ) -> NSAttributedString {
        let paragraphFont = NSFont.systemFont(ofSize: pointSize)
        let monospacedFont = NSFont.monospacedSystemFont(ofSize: pointSize, weight: .regular)
        let output = NSMutableAttributedString()
        let newline = NSAttributedString(string: "\n")

        // The system bullet glyph is visually small at the same nominal point size.
        // Sparkle uses a font with a larger bullet; preserve that behavior here.
        let bulletFont = NSFont(name: "Menlo Regular", size: pointSize) ?? paragraphFont
        let listBullet = NSAttributedString(
            string: "•",
            attributes: [.font: bulletFont]
        )
        let tab = NSAttributedString(
            string: "\t",
            attributes: [.font: paragraphFont]
        )

        var visitedListItemIntents = Set<Int>()
        let intentKey = NSAttributedString.Key("NSPresentationIntent")

        original.enumerateAttribute(
            intentKey,
            in: NSRange(location: 0, length: original.length)
        ) { value, range, _ in
            guard let intent = value as AnyObject? else { return }

            (original.string as NSString).enumerateSubstrings(
                in: range,
                options: .byLines
            ) { _, lineRange, _, _ in
                if output.length > 0 {
                    output.append(newline)
                }

                let fragment = original.attributedSubstring(from: lineRange)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacingBefore = 0
                paragraphStyle.paragraphSpacing = 0
                paragraphStyle.headIndent = 0
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.tabStops = []
                paragraphStyle.defaultTabInterval = paragraphFont.pointSize * 1.38

                let previousLength = output.length

                processFragment(
                    fragment,
                    output: output,
                    paragraphStyle: paragraphStyle,
                    canProcessListItem: true,
                    visitedListItemIntents: &visitedListItemIntents,
                    intent: intent,
                    inputParagraphFont: paragraphFont,
                    monospacedFont: monospacedFont,
                    tab: tab,
                    listBullet: listBullet
                )

                let addedLength = output.length - previousLength
                if addedLength > 0 {
                    output.addAttribute(
                        .paragraphStyle,
                        value: paragraphStyle,
                        range: NSRange(location: previousLength, length: addedLength)
                    )
                }
            }
        }

        // A completely empty intent walk should not make valid source disappear.
        if output.length == 0, !original.string.isEmpty {
            return NSAttributedString(
                string: original.string,
                attributes: [.font: paragraphFont]
            )
        }

        return output
    }

    private static func processFragment(
        _ fragment: NSAttributedString,
        output: NSMutableAttributedString,
        paragraphStyle: NSMutableParagraphStyle,
        canProcessListItem: Bool,
        visitedListItemIntents: inout Set<Int>,
        intent: AnyObject,
        inputParagraphFont: NSFont,
        monospacedFont: NSFont,
        tab: NSAttributedString,
        listBullet: NSAttributedString
    ) {
        let kind = Kind(rawValue: intentKind(intent)) ?? .paragraph
        var font = inputParagraphFont
        var isListItem = false

        switch kind {
        case .header:
            switch headerLevel(intent) {
            case 1:
                font = NSFont.boldSystemFont(ofSize: inputParagraphFont.pointSize * 1.5)
            case 2:
                font = NSFont.boldSystemFont(ofSize: inputParagraphFont.pointSize * 1.3)
            case 3:
                font = NSFont.boldSystemFont(ofSize: inputParagraphFont.pointSize * 1.2)
            default:
                font = NSFont.boldSystemFont(ofSize: inputParagraphFont.pointSize * 1.1)
            }
        case .listItem:
            isListItem = true
        default:
            break
        }

        if let parent = parentIntent(intent) {
            processFragment(
                fragment,
                output: output,
                paragraphStyle: paragraphStyle,
                canProcessListItem: canProcessListItem && !isListItem,
                visitedListItemIntents: &visitedListItemIntents,
                intent: parent,
                inputParagraphFont: font,
                monospacedFont: monospacedFont,
                tab: tab,
                listBullet: listBullet
            )
        }

        switch kind {
        case .header:
            let spacing = font.pointSize * 0.8
            paragraphStyle.paragraphSpacingBefore += spacing
            paragraphStyle.paragraphSpacing += spacing

            let header = NSMutableAttributedString(attributedString: fragment)
            header.addAttribute(
                .font,
                value: font,
                range: NSRange(location: 0, length: header.length)
            )
            output.append(header)

        case .paragraph:
            let parentIsListItem = parentIntent(intent)
                .map { intentKind($0) == Kind.listItem.rawValue } ?? false

            if parentIsListItem {
                paragraphStyle.paragraphSpacing += font.pointSize * 0.3
            } else {
                let spacing = font.pointSize * 0.5
                paragraphStyle.paragraphSpacing += spacing
                paragraphStyle.paragraphSpacingBefore += spacing
            }

            let content = NSMutableAttributedString(attributedString: fragment)
            content.addAttribute(
                .font,
                value: font,
                range: NSRange(location: 0, length: content.length)
            )
            output.append(content)

        case .listItem:
            guard canProcessListItem else { break }

            let firstLineIndent = CGFloat(indentationLevel(intent)) * font.pointSize * 1.5
            paragraphStyle.firstLineHeadIndent += firstLineIndent

            let defaultTabInterval = paragraphStyle.defaultTabInterval
            paragraphStyle.headIndent += ceil(firstLineIndent / defaultTabInterval) * defaultTabInterval

            let itemIdentity = identity(intent)
            let alreadyVisited = visitedListItemIntents.contains(itemIdentity)
            let usesBullet = parentIntent(intent)
                .map { intentKind($0) == Kind.unorderedList.rawValue } ?? true

            if !alreadyVisited {
                if usesBullet {
                    output.append(listBullet)
                } else {
                    output.append(NSAttributedString(
                        string: "\(ordinal(intent)).",
                        attributes: [.font: font]
                    ))
                }
                visitedListItemIntents.insert(itemIdentity)
            }

            output.append(tab)

        case .blockQuote:
            paragraphStyle.firstLineHeadIndent += paragraphStyle.defaultTabInterval
            paragraphStyle.headIndent += paragraphStyle.defaultTabInterval

        case .codeBlock:
            paragraphStyle.paragraphSpacing += font.pointSize * 0.25
            output.append(tab)
            paragraphStyle.headIndent += paragraphStyle.defaultTabInterval

            let code = NSMutableAttributedString(attributedString: fragment)
            code.addAttributes(
                [
                    .font: monospacedFont,
                    .foregroundColor: NSColor.labelColor
                ],
                range: NSRange(location: 0, length: code.length)
            )
            output.append(code)

        case .orderedList, .unorderedList, .thematicBreak,
             .table, .tableHeaderRow, .tableRow, .tableCell:
            // List containers drive child layout. Thematic breaks and tables are
            // intentionally not decorated, matching the release-notes scope.
            break
        }
    }
}
