import CommenterDomain
import Foundation
import GRDB

struct SQLiteProjectIndex {
    let indexURL: URL

    func initialize() throws {
        try withDatabaseQueue { queue in
            try queue.write { db in
                try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS projects (
                  id TEXT PRIMARY KEY NOT NULL,
                  name TEXT NOT NULL,
                  term TEXT NOT NULL,
                  year_level TEXT NOT NULL,
                  updated_at INTEGER NOT NULL,
                  revision INTEGER NOT NULL,
                  fingerprint TEXT,
                  path TEXT NOT NULL
                );
                """)
                try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS usage_ledger (
                  project_id TEXT NOT NULL,
                  key_id TEXT NOT NULL,
                  used_variant_ids_json TEXT NOT NULL,
                  PRIMARY KEY (project_id, key_id)
                );
                """)
            }
        }
    }

    func upsert(project: Project, projectPath: URL, usedVariantIds: [String]) throws {
        try initialize()
        let ledgerData = try JSONEncoder().encode(usedVariantIds)
        let ledgerJSON = String(decoding: ledgerData, as: UTF8.self)

        try withDatabaseQueue { queue in
            try queue.inTransaction(.immediate) { db in
                try db.execute(
                    sql: """
                    INSERT INTO projects (id, name, term, year_level, updated_at, revision, fingerprint, path)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                      name=excluded.name,
                      term=excluded.term,
                      year_level=excluded.year_level,
                      updated_at=excluded.updated_at,
                      revision=excluded.revision,
                      fingerprint=excluded.fingerprint,
                      path=excluded.path;
                    """,
                    arguments: [
                        project.metadata.id,
                        project.metadata.name,
                        project.metadata.term,
                        project.metadata.yearLevel.rawValue,
                        project.metadata.updatedAt,
                        project.metadata.persistence?.revision ?? 0,
                        project.metadata.persistence?.fingerprint ?? "",
                        projectPath.path
                    ]
                )
                try db.execute(
                    sql: """
                    INSERT INTO usage_ledger (project_id, key_id, used_variant_ids_json)
                    VALUES (?, ?, ?)
                    ON CONFLICT(project_id, key_id) DO UPDATE SET
                      used_variant_ids_json=excluded.used_variant_ids_json;
                    """,
                    arguments: [project.metadata.id, "all-variants", ledgerJSON]
                )
                return .commit
            }
        }
    }

    func deleteProject(id: String) throws {
        try initialize()
        try withDatabaseQueue { queue in
            try queue.inTransaction(.immediate) { db in
                try db.execute(sql: "DELETE FROM usage_ledger WHERE project_id = ?;", arguments: [id])
                try db.execute(sql: "DELETE FROM projects WHERE id = ?;", arguments: [id])
                return .commit
            }
        }
    }

    private func withDatabaseQueue<T>(_ body: (DatabaseQueue) throws -> T) throws -> T {
        do {
            let queue = try DatabaseQueue(path: indexURL.path)
            return try body(queue)
        } catch let error as ProjectStoreError {
            throw error
        } catch {
            throw ProjectStoreError.sqlite(sqliteMessage(error))
        }
    }

    private func sqliteMessage(_ error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "SQLite operation failed." : message
    }
}
