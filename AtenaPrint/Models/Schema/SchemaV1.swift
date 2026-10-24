import SwiftData

/// First released schema. Model changes must add a new `VersionedSchema` and a migration stage
/// instead of editing these models in place.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Recipient.self, RecipientGroup.self, PrintRecord.self, SenderProfile.self]
    }
}

enum AtenaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum PersistenceController {
    /// Creates the container. The store lives in Application Support (included in device backups)
    /// and is never synced to CloudKit.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            AppConstants.storeName,
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, migrationPlan: AtenaMigrationPlan.self, configurations: [configuration])
    }
}
