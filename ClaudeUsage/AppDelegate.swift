import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var refreshTimer: Timer?
    private var eventMonitor: Any?
    let usageManager = UsageManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusIcon()

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 440)
        popover.contentViewController = NSHostingController(
            rootView: UsageView(manager: usageManager)
        )

        usageManager.onSnapshotUpdate = { [weak self] in
            self?.updateStatusIcon()
        }

        Task { await usageManager.refresh() }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.usageManager.refresh()
            }
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Show Usage", action: #selector(togglePopover), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: "Quit ClaudeUsage", action: #selector(quit), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            if self?.popover.isShown == true {
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    @objc private func refreshNow() {
        Task { await usageManager.refresh() }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        let percent = Int(usageManager.snapshot?.sessionUtilization ?? 0)
        let color: NSColor
        switch percent {
        case ..<70:
            color = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)
        case ..<90:
            color = NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        default:
            color = NSColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        }
        button.image = makeSparkIcon(color: color)
    }

    private func makeSparkIcon(color: NSColor) -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        let path = NSBezierPath()
        let pts: [NSPoint] = [
            NSPoint(x: 8, y: 1), NSPoint(x: 9, y: 6),
            NSPoint(x: 13, y: 3), NSPoint(x: 10, y: 7),
            NSPoint(x: 15, y: 8), NSPoint(x: 10, y: 9),
            NSPoint(x: 13, y: 13), NSPoint(x: 9, y: 10),
            NSPoint(x: 8, y: 15), NSPoint(x: 7, y: 10),
            NSPoint(x: 3, y: 13), NSPoint(x: 6, y: 9),
            NSPoint(x: 1, y: 8), NSPoint(x: 6, y: 7),
            NSPoint(x: 3, y: 3), NSPoint(x: 7, y: 6)
        ]
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.line(to: p) }
        path.close()
        color.setFill()
        path.fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
