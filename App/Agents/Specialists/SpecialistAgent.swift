import Foundation
import ARCnetDomain
import ARCnetLLM

// MARK: - Specialist Agent
// Generic specialist agent that can be configured for any G-shop.

public final class SpecialistAgent: BaseAgent {
    private let specialization: String

    public init(
        shop: String,
        mos: String,
        name: String,
        llmClient: LLMClient,
        config: LLMConfig = LLMConfig()
    ) {
        self.specialization = Self.getSpecialization(for: shop)

        super.init(
            id: "specialist-\(shop.lowercased())-\(mos)",
            name: name,
            mosCode: mos,
            shop: shop,
            mcppPhase: "coa_dev",
            llmClient: llmClient,
            config: config
        )
    }

    override func buildSystemPrompt(doctrine: [DoctrineSnippet]) -> String {
        var prompt = """
        You are a \(name) (\(shop ?? "Staff") section specialist) providing expert analysis \
        for military decision support.

        Your expertise: \(specialization)

        Your tasks:
        1. Analyze the mission from your domain perspective
        2. Identify impacts, constraints, and opportunities
        3. Provide specific recommendations
        4. Cite relevant doctrine or regulations
        5. Express confidence in your assessment

        Output format:
        ASSESSMENT:
        [Your domain-specific analysis]

        IMPACTS:
        - [Impact on mission from your domain]

        CONSTRAINTS:
        - [Constraints your domain adds]

        OPPORTUNITIES:
        - [Opportunities your domain can provide]

        RECOMMENDATIONS:
        - [Specific recommendation 1]
        - [Specific recommendation 2]

        RESOURCE REQUIREMENTS:
        - [Resources needed from your domain]

        RISKS:
        - [Risk 1]: Likelihood [H/M/L], Impact [H/M/L]
          Mitigation: [Proposed mitigation]

        CONFIDENCE: [HIGH/MEDIUM/LOW]
        """

        if !doctrine.isEmpty {
            prompt += "\n\nRelevant Doctrine:\n"
            for doc in doctrine.prefix(3) {
                prompt += "[\(doc.docId)] \(doc.title): \(doc.content.prefix(400))\n"
            }
        }

        return prompt
    }

    private static func getSpecialization(for shop: String) -> String {
        switch shop.uppercased() {
        case "G1", "S1":
            return "Personnel, manpower, strength reporting, casualty tracking, promotions, and administrative support"
        case "G2", "S2":
            return "Intelligence collection, analysis, threat assessment, GEOINT, and counterintelligence"
        case "G3", "S3":
            return "Operations planning, COA development, fires coordination, and synchronization"
        case "G4", "S4":
            return "Logistics, supply chain, maintenance, transportation, and sustainment"
        case "G5":
            return "Long-range planning, campaign design, and future operations"
        case "G6", "S6":
            return "Communications, network operations, spectrum management, and cybersecurity"
        case "G7":
            return "Training, readiness reporting, and exercise planning"
        case "G8":
            return "Budget, financial management, funds control, and resource allocation"
        case "G9":
            return "Civil affairs, public affairs, information operations, and community engagement"
        default:
            return "General staff support and coordination"
        }
    }
}

// MARK: - Pre-configured Specialist Agents

public struct SpecialistAgentFactory {
    private let llmClient: LLMClient
    private let config: LLMConfig

    public init(llmClient: LLMClient, config: LLMConfig = LLMConfig()) {
        self.llmClient = llmClient
        self.config = config
    }

    // MARK: - G1/S1 Manpower

    public func createG1Agent() -> SpecialistAgent {
        SpecialistAgent(
            shop: "G1",
            mos: "0102",
            name: "G1 Manpower Specialist",
            llmClient: llmClient,
            config: config
        )
    }

    // MARK: - G2/S2 Intelligence

    public func createG2Agent() -> SpecialistAgent {
        SpecialistAgent(
            shop: "G2",
            mos: "0202",
            name: "G2 Intelligence Specialist",
            llmClient: llmClient,
            config: config
        )
    }

    // MARK: - G3/S3 Operations

    public func createG3Agent() -> SpecialistAgent {
        SpecialistAgent(
            shop: "G3",
            mos: "0302",
            name: "G3 Operations Specialist",
            llmClient: llmClient,
            config: config
        )
    }

    // MARK: - G4/S4 Logistics

    public func createG4Agent() -> SpecialistAgent {
        SpecialistAgent(
            shop: "G4",
            mos: "0402",
            name: "G4 Logistics Specialist",
            llmClient: llmClient,
            config: config
        )
    }

    // MARK: - G5 Plans

    public func createG5Agent() -> SpecialistAgent {
        SpecialistAgent(
            shop: "G5",
            mos: "0505",
            name: "G5 Plans Specialist",
            llmClient: llmClient,
            config: config
        )
    }

    // MARK: - G6/S6 Communications

    public func createG6Agent() -> SpecialistAgent {
        SpecialistAgent(
            shop: "G6",
            mos: "0602",
            name: "G6 Communications Specialist",
            llmClient: llmClient,
            config: config
        )
    }

    // MARK: - G7 Training

    public func createG7Agent() -> SpecialistAgent {
        SpecialistAgent(
            shop: "G7",
            mos: "0370",
            name: "G7 Training Specialist",
            llmClient: llmClient,
            config: config
        )
    }

    // MARK: - G8 Finance

    public func createG8Agent() -> SpecialistAgent {
        SpecialistAgent(
            shop: "G8",
            mos: "3404",
            name: "G8 Finance Specialist",
            llmClient: llmClient,
            config: config
        )
    }

    // MARK: - G9 Civil/Information

    public func createG9Agent() -> SpecialistAgent {
        SpecialistAgent(
            shop: "G9",
            mos: "0530",
            name: "G9 Civil Affairs Specialist",
            llmClient: llmClient,
            config: config
        )
    }

    // MARK: - Create All

    public func createAllSpecialists() -> [SpecialistAgent] {
        [
            createG1Agent(),
            createG2Agent(),
            createG3Agent(),
            createG4Agent(),
            createG5Agent(),
            createG6Agent(),
            createG7Agent(),
            createG8Agent(),
            createG9Agent()
        ]
    }

    // MARK: - Create by Shop

    public func createSpecialist(for shop: String) -> SpecialistAgent? {
        switch shop.uppercased() {
        case "G1", "S1": return createG1Agent()
        case "G2", "S2": return createG2Agent()
        case "G3", "S3": return createG3Agent()
        case "G4", "S4": return createG4Agent()
        case "G5": return createG5Agent()
        case "G6", "S6": return createG6Agent()
        case "G7": return createG7Agent()
        case "G8": return createG8Agent()
        case "G9": return createG9Agent()
        default: return nil
        }
    }
}
