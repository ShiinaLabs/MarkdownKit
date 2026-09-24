# MarkdownKit

A small native Markdown renderer for macOS, built for release notes and other read-only rich text inside SwiftUI apps.

MarkdownKit uses Foundation's Markdown parser, then reconstructs block-level presentation such as headings, paragraph spacing, lists, block quotes, and code blocks before displaying the result in a native `NSTextView`.

## Requirements

- macOS 12+
- Swift 6+

## Usage

```swift
import MarkdownKit

MarkdownTextView(markdown: markdown)
```

For direct attributed-string rendering:

```swift
let attributed = MarkdownRenderer.render(markdown)
```

You can also measure rendered content before sizing a sheet:

```swift
let height = MarkdownTextView.measureHeight(
    markdown: markdown,
    width: 560
)
```

By default, links are limited to `http`, `https`, and `mailto`. Additional schemes can be explicitly allowed when constructing `MarkdownTextView`.

## Scope

MarkdownKit intentionally focuses on native read-only macOS rendering. It does not load release-note files, manage versions, provide an editor, or implement a general cross-platform Markdown engine.

Supported presentation includes headings, paragraphs, ordered and unordered lists, block quotes, code blocks, Foundation-supported inline emphasis, and links. Tables and thematic-break decoration are intentionally omitted.

## Attribution

The block-level formatting and native text-view approach is derived from Sparkle's `SUTextViewReleaseNotesView`. Sparkle is distributed under an MIT-style license. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT. See [LICENSE](LICENSE).
