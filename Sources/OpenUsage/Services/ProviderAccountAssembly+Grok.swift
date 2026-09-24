import Foundation

struct GrokAccountCard: Equatable, Sendable {
    let id: String
    let authEntryKey: String
    let displayName: String
}

extension ProviderAccountAssembly {
    static func makeGrokCards(
        observer: DefaultAccountObserver, accountsStore: ProviderAccountsStore
    ) async -> [GrokAccountCard] {
        let store = GrokAuthStore(files: observer.files)
        guard let candidates = try? store.loadAuthCandidates() else { return [] }
        
        var observations: [ProviderAccountsStore.Observation] = []
        var identities: [String] = []
        
        for state in candidates {
            let email: String?
            if let idToken = state.entry.idToken,
               let payload = ProviderParse.jwtPayload(idToken) {
                email = payload["email"] as? String ?? payload["preferred_username"] as? String
            } else {
                email = nil
            }
            
            let label = email != nil ? "Grok (\(email!))" : "Grok (\(String(state.entryKey.prefix(8))))"
            let source = ProviderAccountSource(kind: .defaultHome, anchor: nil, holdsDefaultSource: false)
            observations.append(.init(family: "grok", identityKey: state.entryKey, label: label, sources: [source]))
            identities.append(state.entryKey)
        }
        
        let records = accountsStore.reconcile(with: observations)
        
        return records.compactMap { record in
            guard record.family == "grok", !record.removedTombstone,
                  let entryKey = identities.first(where: { $0 == record.identityKey })
            else { return nil }
            let observation = observations.first { $0.identityKey == entryKey }
            return GrokAccountCard(id: record.id, authEntryKey: entryKey, displayName: observation?.label ?? "Grok")
        }
    }
}
