import CommenterDomain
import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

struct SQLiteProjectIndex {
    let indexURL: URL

    func initialize() throws {
        try withDatabase { db in
            try execute(db, """
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
            try execute(db, """
            CREATE TABLE IF NOT EXISTS usage_ledger (
              project_id TEXT NOT NULL,
              key_id TEXT NOT NULL,
              used_variant_ids_json TEXT NOT NULL,
              PRIMARY KEY (project_id, key_id)
            );
            """)
        }
    }

    func upsert(project: Project, projectPath: URL, usedVariantIds: [String]) throws {
        try initialize()
        try withDatabase { db in
            try execute(db, "BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute(
                    db,
                    """
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
                    [
                        .text(project.metadata.id),
                        .text(project.metadata.name),
                        .text(project.metadata.term),
                        .text(project.metadata.yearLevel.rawValue),
                        .int(project.metadata.updatedAt),
                        .int(Int64(project.metadata.persistence?.revision ?? 0)),
                        .text(project.metadata.persistence?.fingerprint ?? ""),
                        .text(projectPath.path)
                    ]
                )
                let ledgerData = try JSONEncoder().encode(usedVariantIds)
                let ledgerJSON = String(decoding: ledgerData, as: UTF8.self)
                try execute(
                    db,
                    """
                    INSERT INTO usage_ledger (project_id, key_id, used_variant_ids_json)
                    VALUES (?, ?, ?)
                    ON CONFLICT(project_id, key_id) DO UPDATE SET
                      used_variant_ids_json=excluded.used_variant_ids_json;
                    """,
                    [.text(project.metadata.id), .text("all-variants"), .text(ledgerJSON)]
                )
                try execute(db, "COMMIT;")
            } catch {
                try? execute(db, "ROLLBACK;")
                throw error
            }
        }
    }

    func deleteProject(id: String) throws {
        try initialize()
        try withDatabase { db in
            try execute(db, "BEGIN IMMEDIATE TRANSACTION;")
            do {
                try execute(db, "DELETE FROM usage_ledger WHERE project_id = ?;", [.text(id)])
                try execute(db, "DELETE FROM projects WHERE id = ?;", [.text(id)])
                try execute(db, "COMMIT;")
            } catch {
                try? execute(db, "ROLLBACK;")
                throw error
            }
        }
    }

    private enum SQLValue {
        case text(String)
        case int(Int64)
    }

    private func withDatabase<T>(_ body: (OpaquePointer?) throws -> T) throws -> T {
        #if canImport(SQLite3)
        var db: OpaquePointer?
        guard sqlite3_open(indexURL.path, &db) == SQLITE_OK else {
            let message = db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unable to open SQLite index."
            if db != nil { sqlite3_close(db) }
            throw ProjectStoreError.sqlite(message)
        }
        defer { sqlite3_close(db) }
        return try body(db)
        #else
        throw ProjectStoreError.sqlite("SQLite3 is not available in this build.")
        #endif
    }

    private func execute(_ db: OpaquePointer?, _ sql: String, _ values: [SQLValue] = []) throws {
        #if canImport(SQLite3)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw ProjectStoreError.sqlite(errorMessage(db))
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case let .text(text):
                sqlite3_bind_text(statement, position, text, -1, sqliteTransient)
            case let .int(int):
                sqlite3_bind_int64(statement, position, int)
            }
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw ProjectStoreError.sqlite(errorMessage(db))
        }
        #else
        throw ProjectStoreError.sqlite("SQLite3 is not available in this build.")
        #endif
    }

    private func errorMessage(_ db: OpaquePointer?) -> String {
        #if canImport(SQLite3)
        db.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "SQLite operation failed."
        #else
        "SQLite3 is not available in this build."
        #endif
    }
}

#if canImport(SQLite3)
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
#endif
