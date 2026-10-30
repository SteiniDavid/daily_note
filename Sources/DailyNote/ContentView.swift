import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NoteStore
    @AppStorage("showSidebar") private var showSidebar = false
    @AppStorage("fontSize") private var fontSize = 15.0
    @AppStorage("monospaced") private var monospaced = false

    var body: some View {
        NavigationSplitView(columnVisibility: sidebarVisibility) {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 230, max: 360)
        } detail: {
            NoteEditor(text: $store.text, day: store.day, font: font)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(store.day.date.formatted(.dateTime.weekday(.wide)))
                .navigationSubtitle(store.day.date.formatted(.dateTime.month(.wide).day().year()))
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        ControlGroup {
                            Button(action: store.goToPrevious) {
                                Label("Previous Day", systemImage: "chevron.left")
                            }
                            .help("Previous day (⌘[)")
                            .disabled(store.previousDay == nil)

                            Button(action: store.goToNext) {
                                Label("Next Day", systemImage: "chevron.right")
                            }
                            .help("Next day (⌘])")
                            .disabled(store.nextDay == nil)
                        }
                        Button("Today", action: store.goToToday)
                            .help("Go to today (⌘T)")
                            .disabled(store.day == store.today)
                    }
                }
        }
        .alert("Something went wrong", isPresented: errorShown) {
            Button("OK") {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var font: NSFont {
        monospaced
            ? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
            : .systemFont(ofSize: fontSize)
    }

    private var sidebarVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { showSidebar ? .all : .detailOnly },
            set: { showSidebar = $0 != .detailOnly }
        )
    }

    private var errorShown: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

private struct Sidebar: View {
    @EnvironmentObject private var store: NoteStore

    var body: some View {
        List(selection: selection) {
            ForEach(store.sections) { section in
                Section(section.title) {
                    ForEach(section.days) { day in
                        row(for: day)
                            .tag(day)
                            .contextMenu {
                                Button("Show in Finder") { store.reveal(day) }
                                if store.hasNote(day) {
                                    Divider()
                                    Button("Move to Trash", role: .destructive) { store.moveToTrash(day) }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var selection: Binding<Day?> {
        Binding(
            get: { store.day },
            set: { if let day = $0 { store.open(day) } }
        )
    }

    private func row(for day: Day) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label(for: day))
            if let preview = store.preview(for: day), !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func label(for day: Day) -> String {
        if day == store.today { return "Today" }
        if day == store.today.adding(days: -1) { return "Yesterday" }
        return day.date.formatted(.dateTime.weekday(.wide).day())
    }
}
