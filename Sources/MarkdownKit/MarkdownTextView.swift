// MarkdownKit
//
// The native text-view presentation follows the same release-notes rendering
// strategy used by Sparkle. See THIRD_PARTY_NOTICES.md.

import AppKit
import SwiftUI

/// A read-only, selectable native macOS Markdown view for SwiftUI.
public struct MarkdownTextView: NSViewRepresentable {
    public let markdown: String
    public var pointSize: CGFloat
    public var baseURL: URL?
    public var allowedURLSchemes: Set<String>

    public init(
        markdown: String,
        pointSize: CGFloat = 13,
        baseURL: URL? = nil,
        allowedURLSchemes: Set<String> = ["http", "https", "mailto"]
    ) {
        self.markdown = markdown
        self.pointSize = pointSize
        self.baseURL = baseURL
        self.allowedURLSchemes = Set(allowedURLSchemes.map { $0.lowercased() })
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false

        // Use an explicit TextKit 1 stack. It is stable for the paragraph-style
        // attributes used by this renderer across the supported macOS range.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: 360,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.delegate = context.coordinator
        scrollView.documentView = textView

        refresh(textView: textView, coordinator: context.coordinator)
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.allowedURLSchemes = allowedURLSchemes
        guard let textView = scrollView.documentView as? NSTextView else { return }
        refresh(textView: textView, coordinator: context.coordinator)
    }

    private func refresh(textView: NSTextView, coordinator: Coordinator) {
        let key = cacheKey
        guard coordinator.currentState != key else { return }

        let attributed = MarkdownRenderer.render(
            markdown,
            pointSize: pointSize,
            baseURL: baseURL
        )
        textView.textStorage?.setAttributedString(attributed)
        coordinator.currentState = key
        coordinator.allowedURLSchemes = allowedURLSchemes
        textView.scrollToBeginningOfDocument(nil)
    }

    private var cacheKey: String {
        "\(pointSize)|\(baseURL?.absoluteString ?? "")|\(markdown)"
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(allowedURLSchemes: allowedURLSchemes)
    }

    /// Measure the laid-out height required by the given Markdown at a fixed width.
    public static func measureHeight(
        markdown: String,
        width: CGFloat,
        pointSize: CGFloat = 13,
        baseURL: URL? = nil
    ) -> CGFloat {
        let attributed = MarkdownRenderer.render(
            markdown,
            pointSize: pointSize,
            baseURL: baseURL
        )
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: attributed)
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(
            size: NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)
        return layoutManager.usedRect(for: textContainer).height
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        fileprivate var currentState: String?
        fileprivate var allowedURLSchemes: Set<String>

        fileprivate init(allowedURLSchemes: Set<String>) {
            self.allowedURLSchemes = allowedURLSchemes
        }

        public func textView(
            _ textView: NSTextView,
            clickedOnLink link: Any,
            at charIndex: Int
        ) -> Bool {
            let url: URL?
            if let linkURL = link as? URL {
                url = linkURL
            } else if let string = link as? String {
                url = URL(string: string)
            } else {
                url = nil
            }

            guard let url,
                  let scheme = url.scheme?.lowercased(),
                  allowedURLSchemes.contains(scheme)
            else {
                return true
            }

            NSWorkspace.shared.open(url)
            return true
        }
    }
}
