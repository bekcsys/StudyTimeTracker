import SwiftUI
import SwiftData

@main
struct StudyTimeApp: App {
    @State private var themeStore = ThemeStore()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Topic.self, StudySession.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeStore)
                .preferredColorScheme(themeStore.theme.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
