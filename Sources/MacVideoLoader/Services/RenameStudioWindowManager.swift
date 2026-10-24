import SwiftUI
import AppKit

// MARK: - Window Drag Handle for macOS

public struct WindowDragHandle: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> DragView {
        DragView()
    }

    public func updateNSView(_ nsView: DragView, context: Context) {}

    public class DragView: NSView {
        public override var mouseDownCanMoveWindow: Bool { true }

        public override func mouseDown(with event: NSEvent) {
            self.window?.performDrag(with: event)
        }
    }
}

// MARK: - Dedicated Standalone Window Manager for Rename Studio

@MainActor
public final class RenameStudioWindowManager: NSObject, NSWindowDelegate {
    public static let shared = RenameStudioWindowManager()

    private var window: NSWindow?

    public var isWindowOpen: Bool {
        return window != nil
    }

    private override init() {
        super.init()
    }

    public func show(
        downloadManager: DownloadManager,
        items: [DownloadItem]? = nil,
        standaloneFolder: URL? = nil
    ) {
        // If window already exists, NEVER create a second window!
        // Simply bring the existing window to front and focus it.
        if let existing = self.window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = RenameStudioSheet(
            downloadManager: downloadManager,
            items: items,
            standaloneFolder: standaloneFolder,
            onDismiss: { [weak self] in
                self?.close()
            }
        )

        let hostingView = NSHostingView(rootView: contentView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.minSize = NSSize(width: 960, height: 580)
        newWindow.center()
        newWindow.title = "Rename Studio"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        // CRITICAL: Disable window background dragging so TextFields, Pickers, and buttons
        // retain first-responder status and never lose focus or jitter during mouse clicks/typing!
        newWindow.isMovableByWindowBackground = false
        newWindow.backgroundColor = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        newWindow.contentView = hostingView
        newWindow.delegate = self
        newWindow.setFrameAutosaveName("MacVideoLoader_RenameStudioWindow")
        newWindow.isReleasedWhenClosed = false

        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        if let win = window {
            win.close()
        }
        self.window = nil
        DownloadManager.shared.renameStudioItems = nil
        DownloadManager.shared.renameStudioFolder = nil
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        self.window = nil
        DownloadManager.shared.renameStudioItems = nil
        DownloadManager.shared.renameStudioFolder = nil
    }
}
