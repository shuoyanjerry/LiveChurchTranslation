import Foundation
import PersistenceAPI
import SettingsAPI

extension SessionLibraryViewModel {
    public var filteredSessions: [StoredSessionSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        return sessions.filter { summary in
            summary.displayTitle.localizedStandardContains(query)
                || DisplayLanguage.allCases.contains { displayLanguage in
                    summary.recognitionLanguage(displayLanguage: displayLanguage)
                        .localizedStandardContains(query)
                }
        }
    }
}
