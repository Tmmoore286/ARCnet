import Foundation
import ARCnetDomain

// MARK: - USMC Org Pack Importer
// Imports organization templates from Ref-Packs into the repository.

public struct OrgImporter: Sendable {
    private let repository: OrgRepository

    public init(repository: OrgRepository) {
        self.repository = repository
    }

    /// Import an organization from JSON data
    public func importOrg(from data: Data) async throws -> OrgUnit {
        let decoder = JSONDecoder()
        let orgSpec = try decoder.decode(OrgSpecJSON.self, from: data)

        let unit = OrgUnit(
            id: orgSpec.unit.uic ?? UUID().uuidString,
            name: orgSpec.unit.name,
            echelon: orgSpec.unit.echelon,
            uic: orgSpec.unit.uic,
            nodes: orgSpec.nodes.map { nodeFromJSON($0) }
        )

        try await repository.saveUnit(unit)
        return unit
    }

    /// Import from a file URL
    public func importOrg(from url: URL) async throws -> OrgUnit {
        let data = try Data(contentsOf: url)
        return try await importOrg(from: data)
    }

    /// Import from bundled resource
    public func importOrg(resourceName: String, bundle: Bundle = .main) async throws -> OrgUnit {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw ImporterError.resourceNotFound(resourceName)
        }
        return try await importOrg(from: url)
    }

    private func nodeFromJSON(_ json: OrgNodeJSON) -> OrgNode {
        OrgNode(
            id: json.id,
            type: OrgNodeType(rawValue: json.type) ?? .unit,
            name: json.name,
            parentId: json.parentId,
            echelon: json.echelon,
            shop: json.shop,
            billet: json.billet,
            mos: json.mos,
            agentTemplates: json.agentTemplates ?? [],
            autonomy: AutonomyMode(rawValue: json.autonomy ?? "HITL") ?? .hitl,
            gateAuthority: json.gateAuthority
        )
    }
}

// MARK: - JSON Decoding Structures

private struct OrgSpecJSON: Codable {
    let version: String?
    let unit: UnitJSON
    let nodes: [OrgNodeJSON]
}

private struct UnitJSON: Codable {
    let name: String
    let echelon: String
    let uic: String?
}

private struct OrgNodeJSON: Codable {
    let id: String
    let type: String
    let name: String
    let parentId: String?
    let echelon: String?
    let shop: String?
    let billet: String?
    let mos: String?
    let agentTemplates: [String]?
    let autonomy: String?
    let gateAuthority: String?
}

// MARK: - Importer Errors

public enum ImporterError: Error, Sendable {
    case resourceNotFound(String)
    case invalidFormat(String)
    case decodingFailed(String)
}
