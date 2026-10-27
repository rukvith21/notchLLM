import Foundation
import SQLite3

/// Best-effort Cursor IDE session reader.
///
/// Assumptions (documented):
/// - Cursor stores auth in `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
/// - Useful non-secret keys: `cursorAuth/stripeMembershipType`, `stripeSubscriptionStatus`, `cachedEmail`
/// - Access/refresh tokens exist but are only used for optional live usage API calls
struct CursorSessionDetector: Sendable {
    struct Snapshot: Sendable {
        let isSignedIn: Bool
        let email: String?
        let membershipType: String?
        let subscriptionStatus: String?
        let accessToken: String?
    }

    private let dbURL: URL

    init(
        dbURL: URL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    ) {
        self.dbURL = dbURL
    }

    func detect() -> Snapshot {
        guard FileManager.default.fileExists(atPath: dbURL.path) else {
            return Snapshot(
                isSignedIn: false,
                email: nil,
                membershipType: nil,
                subscriptionStatus: nil,
                accessToken: nil
            )
        }

        let email = readString(key: "cursorAuth/cachedEmail")
        let membership = readString(key: "cursorAuth/stripeMembershipType")
        let status = readString(key: "cursorAuth/stripeSubscriptionStatus")
        let token = readString(key: "cursorAuth/accessToken")
        let signedIn = email != nil || token != nil || membership != nil

        return Snapshot(
            isSignedIn: signedIn,
            email: email,
            membershipType: membership,
            subscriptionStatus: status,
            accessToken: token
        )
    }

    private func readString(key: String) -> String? {
        var db: OpaquePointer?
        let path = dbURL.path
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        let bindOK: Bool = key.withCString { cKey in
            sqlite3_bind_text(statement, 1, cKey, -1, nil) == SQLITE_OK
        }
        guard bindOK else { return nil }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let cString = sqlite3_column_text(statement, 0) else { return nil }
        let value = String(cString: cString)
        return value.isEmpty ? nil : value
    }
}
