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

    private var windowController: NSWindowController?

    public var isWindowOpen: Bool {
        return windowController?.window?.isVisible == true
    }

    private override init() {
        super.init()
    }

    public func show(
        downloadManager: DownloadManager,
        items: [DownloadItem]? = nil,
        standaloneFolder: URL? = nil
    ) {
        if let existingWindow = windowController?.window, existingWindow.isVisible {
            if items != nil || standaloneFolder != nil {
                let view = RenameStudioSheet(
                    downloadManager: downloadManager,
                    items: items,
                    standaloneFolder: standaloneFolder,
                    onDismiss: { [weak self] in
                        self?.close()
                    }
                )
                existingWindow.contentView = NSHostingView(rootView: view)
            }
            existingWindow.makeKeyAndOrderFront(nil)
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

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1040, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 960, height: 580)
        window.center()
        window.title = "Rename Studio"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        window.contentView = hostingView
        window.delegate = self
        window.setFrameAutosaveName("MacVideoLoader_RenameStudioWindow")

        let wc = NSWindowController(window: window)
        self.windowController = wc
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        if let win = windowController?.window {
            win.close()
        }
        windowController = nil
        DownloadManager.shared.renameStudioItems = nil
        DownloadManager.shared.renameStudioFolder = nil
    }

    // MARK: - NSWindowDelegate

    public func windowWillClose(_ notification: Notification) {
        self.windowController = nil
        DownloadManager.shared.renameStudioItems = nil
        DownloadManager.shared.renameStudioFolder = nil
    }
}
