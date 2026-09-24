import Foundation
import SwiftData

/// First shipped schema. Adding a version here (and a migration stage in `PersistenceMigrationPlan`)
/// is the only supported way to change a `Stored*` model once a build has reached a device, because
/// SwiftData refuses to open a store whose models silently changed shape.
enum PersistenceSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            StoredConversation.self,
            StoredMessage.self,
            StoredContact.self,
            StoredOutboxItem.self,
            StoredSeenCounter.self,
            StoredConversationSettings.self,
            StoredSendCounter.self
        ]
    }
}

/// Ordered list of schema versions and how to move between them. Empty stages today; the plan exists so
/// the store already opens through a migration path and V2 is a one-line addition.
enum PersistenceMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PersistenceSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

/// Builds `ModelContainer`s for a configuration.
enum PersistenceContainerFactory {
    static let schema = Schema(versionedSchema: PersistenceSchemaV1.self)

    static func makeContainer(_ configuration: PersistenceConfiguration) throws(PersistenceError) -> ModelContainer {
        let modelConfiguration: ModelConfiguration
        switch configuration.storage {
        case .inMemory:
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        case .onDisk(let url):
            modelConfiguration = ModelConfiguration(
                CipherPersistence.rootDirectoryName,
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        }
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: PersistenceMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            let account = configuration.accountId?.description ?? "none"
            PersistenceLog.configuration.notice(
                "container opened inMemory=\(configuration.isInMemory, privacy: .public) account=\(account, privacy: .public)"
            )
            return container
        } catch {
            PersistenceLog.configuration.error("container creation failed: \(PersistenceError.typeName(of: error), privacy: .public)")
            throw .containerCreationFailed(PersistenceError.typeName(of: error))
        }
    }
}
