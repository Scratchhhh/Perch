import Foundation
import SwiftData

enum PerchModelContainer {
    static let schema = Schema([AgentSession.self, AgentEvent.self])

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Perch",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
