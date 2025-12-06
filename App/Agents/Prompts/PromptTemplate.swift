import Foundation
import ARCnetDomain

// MARK: - Prompt Template Engine
// Manages prompt templates with variable substitution.

public struct PromptTemplate: Sendable {
    public let template: String
    public let variables: Set<String>

    public init(template: String) {
        self.template = template
        self.variables = Self.extractVariables(from: template)
    }

    /// Render template with provided values
    public func render(with values: [String: String]) -> String {
        var result = template

        for variable in variables {
            let placeholder = "{{\(variable)}}"
            if let value = values[variable] {
                result = result.replacingOccurrences(of: placeholder, with: value)
            }
        }

        return result
    }

    /// Extract variable names from template (format: {{variableName}})
    private static func extractVariables(from template: String) -> Set<String> {
        var variables: Set<String> = []
        let pattern = #"\{\{(\w+)\}\}"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return variables
        }

        let range = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, range: range)

        for match in matches {
            if let variableRange = Range(match.range(at: 1), in: template) {
                variables.insert(String(template[variableRange]))
            }
        }

        return variables
    }
}

// MARK: - Prompt Templates

public enum PromptTemplates {

    // MARK: - Mission Context Template

    public static let missionContext = PromptTemplate(template: """
        Mission Statement: {{missionStatement}}

        Commander's Intent: {{intent}}

        End State: {{endState}}

        Constraints:
        {{constraints}}

        Acceptance Criteria:
        {{acceptanceCriteria}}
        """)

    // MARK: - Data Snapshot Template

    public static let dataSnapshot = PromptTemplate(template: """
        Current Status as of {{timestamp}}:

        READINESS:
        - Personnel: {{personnelReadiness}}%
        - Equipment: {{equipmentReadiness}}%
        - Training: {{trainingReadiness}}%
        - Overall: {{overallReadiness}}% ({{drrsCategory}})

        FUNDS (FY{{fiscalYear}}):
        - Authorized: ${{authorizedAmount}}
        - Obligated: ${{obligatedAmount}}
        - Remaining: ${{remainingAmount}}
        - Commitment Rate: {{commitmentRate}}%

        EQUIPMENT:
        - Total: {{totalEquipment}}
        - Mission Capable: {{missionCapable}} ({{mcRate}}%)
        - In Maintenance: {{inMaintenance}}
        - Awaiting Parts: {{awaitingParts}}
        - Deadlined: {{deadlined}}
        """)

    // MARK: - Evidence Citation Template

    public static let evidenceCitation = PromptTemplate(template: """
        [{{docId}}] {{section}}
        "{{quote}}"
        """)

    // MARK: - COA Summary Template

    public static let coaSummary = PromptTemplate(template: """
        COA {{coaNumber}}: {{coaName}}

        Description: {{description}}

        Readiness Impact: {{readinessImpact}}
        Funding Required: ${{fundingRequired}}
        Schedule Impact: {{scheduleImpact}} days

        Assumptions:
        {{assumptions}}

        Risks:
        {{risks}}

        Score: {{totalScore}}/10.0
        """)

    // MARK: - Checkpoint Summary Template

    public static let checkpointSummary = PromptTemplate(template: """
        Stage: {{stage}}
        Agent: {{agent}}
        Phase: {{mcppPhase}}
        Gate: {{gate}}

        Summary:
        {{summary}}

        Confidence: {{confidence}}%
        Classification: {{classification}}
        """)
}

// MARK: - Template Builder Helpers

public struct PromptBuilder {

    public static func buildMissionContext(_ context: MissionContext, statement: String) -> String {
        PromptTemplates.missionContext.render(with: [
            "missionStatement": statement,
            "intent": context.intent,
            "endState": context.endState,
            "constraints": context.constraints.map { "- \($0)" }.joined(separator: "\n"),
            "acceptanceCriteria": context.acceptanceCriteria.map { "- \($0)" }.joined(separator: "\n")
        ])
    }

    public static func buildDataSnapshot(_ snapshots: DataSnapshots) -> String {
        var values: [String: String] = [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        if let r = snapshots.readiness {
            values["personnelReadiness"] = String(format: "%.0f", r.personnelReadiness * 100)
            values["equipmentReadiness"] = String(format: "%.0f", r.equipmentReadiness * 100)
            values["trainingReadiness"] = String(format: "%.0f", r.trainingReadiness * 100)
            values["overallReadiness"] = String(format: "%.0f", r.overallReadiness * 100)
            values["drrsCategory"] = r.drrsCategory
        }

        if let f = snapshots.funds {
            values["fiscalYear"] = String(f.fiscalYear)
            values["authorizedAmount"] = String(format: "%.0f", f.authorizedAmount)
            values["obligatedAmount"] = String(format: "%.0f", f.obligatedAmount)
            values["remainingAmount"] = String(format: "%.0f", f.remainingAmount)
            values["commitmentRate"] = String(format: "%.0f", f.commitmentRate * 100)
        }

        if let m = snapshots.maintenance {
            values["totalEquipment"] = String(m.totalEquipment)
            values["missionCapable"] = String(m.missionCapable)
            values["mcRate"] = String(format: "%.0f", m.mcRate * 100)
            values["inMaintenance"] = String(m.inMaintenance)
            values["awaitingParts"] = String(m.awaitingParts)
            values["deadlined"] = String(m.deadlined)
        }

        return PromptTemplates.dataSnapshot.render(with: values)
    }

    public static func buildCOASummary(_ coa: CourseOfAction, number: Int) -> String {
        PromptTemplates.coaSummary.render(with: [
            "coaNumber": String(number),
            "coaName": coa.name,
            "description": coa.description,
            "readinessImpact": String(format: "%.1f%%", coa.readinessImpact * 100),
            "fundingRequired": String(format: "%.0f", coa.fundingRequired),
            "scheduleImpact": String(coa.scheduleImpactDays),
            "assumptions": coa.assumptions.map { "- \($0)" }.joined(separator: "\n"),
            "risks": coa.risks.map { "- \($0.description) (L:\($0.likelihood.rawValue), I:\($0.impact.rawValue))" }.joined(separator: "\n"),
            "totalScore": String(format: "%.1f", coa.totalScore)
        ])
    }
}
