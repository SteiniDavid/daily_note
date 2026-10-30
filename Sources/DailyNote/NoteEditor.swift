import AppKit
import SwiftUI

/// A plain-text editor backed by NSTextView: native undo, find (⌘F), spell check,
/// and a centered column of readable width however wide the window gets.
struct NoteEditor: NSViewRepresentable {
    @Binding var text: String
    let day: Day
    let font: NSFont

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = PageTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .controlAccentColor

        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = textView

        // Keep the text view at least as tall as the window so clicking anywhere places the cursor.
        let clipView = scrollView.contentView
        clipView.postsFrameChangedNotifications = true
        context.coordinator.clipObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: clipView, queue: .main
        ) { [weak textView, weak clipView] _ in
            guard let textView, let clipView else { return }
            textView.minSize = NSSize(width: 0, height: clipView.bounds.height)
        }

        context.coordinator.textView = textView
        context.coordinator.apply(font: font)
        context.coordinator.show(text, for: day)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if coordinator.font != font {
            coordinator.apply(font: font)
        }
        if coordinator.day != day {
            coordinator.show(text, for: day)
        } else if let textView = coordinator.textView, textView.string != text {
            // The file changed on disk; keep the cursor roughly where it was.
            let selection = textView.selectedRange()
            coordinator.setContents(text)
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        if let observer = coordinator.clipObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteEditor
        weak var textView: NSTextView?
        var day: Day?
        var font: NSFont?
        var clipObserver: NSObjectProtocol?

        init(_ parent: NoteEditor) { self.parent = parent }

        private var attributes: [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            return [
                .font: font ?? NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraph,
            ]
        }

        func apply(font: NSFont) {
            self.font = font
            guard let textView else { return }
            let attrs = attributes
            textView.typingAttributes = attrs
            textView.defaultParagraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
            if let storage = textView.textStorage {
                storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
            }
        }

        func setContents(_ string: String) {
            textView?.textStorage?.setAttributedString(NSAttributedString(string: string, attributes: attributes))
        }

        /// Swap in a different day's note: fresh undo history, cursor at the end, ready to type.
        func show(_ string: String, for day: Day) {
            self.day = day
            guard let textView else { return }
            setContents(string)
            textView.undoManager?.removeAllActions()
            let end = NSRange(location: (string as NSString).length, length: 0)
            textView.setSelectedRange(end)
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                textView.scrollRangeToVisible(end)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// Centers the text in a column no wider than `maxLineWidth`.
final class PageTextView: NSTextView {
    var maxLineWidth: CGFloat = 680

    override func setFrameSize(_ newSize: NSSize) {
        let horizontal = max(32, (newSize.width - maxLineWidth) / 2).rounded()
        if textContainerInset.width != horizontal {
            textContainerInset = NSSize(width: horizontal, height: 28)
        }
        super.setFrameSize(newSize)
    }
}
