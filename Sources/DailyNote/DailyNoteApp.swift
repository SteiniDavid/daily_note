import AppKit
import SwiftUI

@main
struct DailyNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Daily Note", id: "main") {
            ContentView()
                .environmentObject(appDelegate.store)
                .frame(minWidth: 420, minHeight: 300)
        }
        .defaultSize(width: 760, height: 680)
        .commands { NoteCommands(store: appDelegate.store) }

        Settings {
            SettingsView()
                .environmentObject(appDelegate.store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = NoteStore()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationDidBecomeActive(_ notification: Notification) { store.refresh() }
    func applicationWillResignActive(_ notification: Notification) { store.flush() }
    func applicationWillTerminate(_ notification: Notification) { store.flush() }
}

struct NoteCommands: Commands {
    @ObservedObject var store: NoteStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Show in Finder") { store.reveal(store.day) }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .saveItem) {
            // Notes autosave; this just forces it.
            Button("Save", action: store.flush)
                .keyboardShortcut("s")
        }
        SidebarCommands()
        CommandMenu("Go") {
            Button("Today", action: store.goToToday)
                .keyboardShortcut("t")
                .disabled(store.day == store.today)
            Divider()
            Button("Previous Day", action: store.goToPrevious)
                .keyboardShortcut("[")
                .disabled(store.previousDay == nil)
            Button("Next Day", action: store.goToNext)
                .keyboardShortcut("]")
                .disabled(store.nextDay == nil)
        }
    }
}
