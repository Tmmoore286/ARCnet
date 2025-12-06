import Foundation
import ARCnetDomain
import ARCnetLLM
import ARCnetAgents

// MARK: - LLM-Based COA Generator
// Generates candidate COAs using LLM analysis of the integrated assessment.

public final class LLMCOAGenerator: COAGenerator, @unchecked Sendable {
    private let llmClient: LLMClient
    private let config: LLMConfig

    public init(llmClient: LLMClient, config: LLMConfig = LLMConfig()) {
        self.llmClient = llmClient
        self.config = config
    }

    public func generateCOAs(
        assessment: IntegratedAssessment,
        context: MissionContext,
        count: Int
    ) async throws -> [CourseOfAction] {
        let systemPrompt = buildSystemPrompt()
        let userPrompt = buildUserPrompt(assessment: assessment, context: context, count: count)

        let messages = [
            LLMMessage(role: .system, content: systemPrompt),
            LLMMessage(role: .user, content: userPrompt)
        ]

        let response = try await llmClient.complete(messages: messages, config: config)
        return parseCOAs(from: response.text, count: count)
    }

    private func buildSystemPrompt() -> String {
        """
        You are a military Course of Action (COA) development expert. Your role is to generate \
        distinct, viable courses of action based on the integrated staff assessment.

        Each COA must:
        1. Be feasible given available resources
        2. Be acceptable in terms of risk
        3. Be suitable for accomplishing the mission
        4. Be distinguishable from other COAs (not just variations)
        5. Include clear decision points

        For each COA, provide:
        - Name (creative, memorable designation)
        - Description (2-3 sentences)
        - Key tasks and phases
        - Resource requirements
        - Estimated timeline
        - Assumptions made
        - Key risks with likelihood and impact

        Output format for each COA:
        COA [NUMBER]: [NAME]
        DESCRIPTION: [Brief description]
        TASKS:
        - [Task 1]
        - [Task 2]
        RESOURCES:
        - Personnel: [requirement]
        - Equipment: [requirement]
        - Funds: [requirement]
        TIMELINE: [days/weeks]
        READINESS_IMPACT: [percentage]
        ASSUMPTIONS:
        - [Assumption 1]
        RISKS:
        - [Risk]: L=[H/M/L], I=[H/M/L]
        """
    }

    private func buildUserPrompt(
        assessment: IntegratedAssessment,
        context: MissionContext,
        count: Int
    ) -> String {
        var prompt = """
        Generate \(count) distinct Courses of Action for the following mission:

        MISSION: \(assessment.missionStatement)

        COMMANDER'S INTENT: \(context.intent)
        END STATE: \(context.endState)

        CONSTRAINTS:
        \(context.constraints.map { "- \($0)" }.joined(separator: "\n"))

        ACCEPTANCE CRITERIA:
        \(context.acceptanceCriteria.map { "- \($0)" }.joined(separator: "\n"))

        SPECIALIST ASSESSMENTS:
        """

        for assessment in assessment.specialistAssessments {
            prompt += """

            [\(assessment.shop ?? "Staff")]:
            \(assessment.summary)
            Recommendations: \(assessment.recommendations.joined(separator: "; "))
            """
        }

        if !assessment.conflicts.isEmpty {
            prompt += "\n\nIDENTIFIED CONFLICTS:"
            for conflict in assessment.conflicts {
                prompt += "\n- \(conflict.shopA) vs \(conflict.shopB): \(conflict.description)"
            }
        }

        prompt += "\n\nRESOURCE IMPACTS:"
        prompt += "\n- Personnel: \(String(format: "%.1f%%", assessment.resourceImpacts.personnel))"
        prompt += "\n- Equipment: \(String(format: "%.1f%%", assessment.resourceImpacts.equipment))"
        prompt += "\n- Funds: $\(String(format: "%.0f", assessment.resourceImpacts.funds))"
        prompt += "\n- Schedule: \(assessment.resourceImpacts.schedule) days"

        prompt += "\n\nGenerate \(count) distinct COAs. Ensure they represent meaningfully different approaches."

        return prompt
    }

    private func parseCOAs(from text: String, count: Int) -> [CourseOfAction] {
        var coas: [CourseOfAction] = []

        // Split by COA markers
        let coaPattern = #"COA\s*\d+:?\s*(.+?)(?=COA\s*\d+:|$)"#
        guard let regex = try? NSRegularExpression(pattern: coaPattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return generateDefaultCOAs(count: count)
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for (index, match) in matches.enumerated() {
            if let coaRange = Range(match.range, in: text) {
                let coaText = String(text[coaRange])
                if let coa = parseSingleCOA(from: coaText, number: index + 1) {
                    coas.append(coa)
                }
            }
        }

        // If parsing failed, generate defaults
        if coas.isEmpty {
            return generateDefaultCOAs(count: count)
        }

        return coas
    }

    private func parseSingleCOA(from text: String, number: Int) -> CourseOfAction? {
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        // Extract name from first line
        var name = "COA \(number)"
        if let firstLine = lines.first {
            let cleanedLine = firstLine
                .replacingOccurrences(of: #"COA\s*\d+:?\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if !cleanedLine.isEmpty {
                name = cleanedLine
            }
        }

        // Extract description
        var description = ""
        if let descIndex = lines.firstIndex(where: { $0.uppercased().starts(with: "DESCRIPTION:") }) {
            description = lines[descIndex]
                .replacingOccurrences(of: "DESCRIPTION:", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
        }

        // Extract assumptions
        var assumptions: [String] = []
        var inAssumptions = false
        for line in lines {
            if line.uppercased().starts(with: "ASSUMPTIONS:") {
                inAssumptions = true
                continue
            }
            if inAssumptions {
                if line.starts(with: "-") {
                    assumptions.append(line.dropFirst().trimmingCharacters(in: .whitespaces))
                } else if line.uppercased().starts(with: "RISKS:") || line.uppercased().starts(with: "TIMELINE:") {
                    break
                }
            }
        }

        // Extract risks
        var risks: [Risk] = []
        var inRisks = false
        for line in lines {
            if line.uppercased().starts(with: "RISKS:") {
                inRisks = true
                continue
            }
            if inRisks && line.starts(with: "-") {
                if let risk = parseRisk(from: line) {
                    risks.append(risk)
                }
            }
        }

        // Extract numeric values with defaults
        let readinessImpact = extractPercentage(from: text, key: "READINESS_IMPACT") ?? 0.05
        let fundingRequired = extractAmount(from: text, key: "FUNDS") ?? 100000
        let scheduleImpact = extractDays(from: text, key: "TIMELINE") ?? 30

        return CourseOfAction(
            name: name,
            description: description.isEmpty ? "Generated course of action" : description,
            readinessImpact: readinessImpact,
            fundingRequired: fundingRequired,
            scheduleImpactDays: scheduleImpact,
            risks: risks.isEmpty ? [Risk(description: "Execution risk", likelihood: .medium, impact: .medium)] : risks,
            assumptions: assumptions.isEmpty ? ["Standard operating conditions"] : assumptions
        )
    }

    private func parseRisk(from line: String) -> Risk? {
        let cleanLine = line.dropFirst().trimmingCharacters(in: .whitespaces)

        // Parse format: "Risk description: L=H, I=M" or similar
        let parts = cleanLine.components(separatedBy: ":")
        let description = parts.first?.trimmingCharacters(in: .whitespaces) ?? cleanLine

        var likelihood: RiskLevel = .medium
        var impact: RiskLevel = .medium

        if parts.count > 1 {
            let levelStr = parts[1].uppercased()
            if levelStr.contains("L=H") || levelStr.contains("LIKELIHOOD=HIGH") {
                likelihood = .high
            } else if levelStr.contains("L=L") || levelStr.contains("LIKELIHOOD=LOW") {
                likelihood = .low
            }

            if levelStr.contains("I=H") || levelStr.contains("IMPACT=HIGH") {
                impact = .high
            } else if levelStr.contains("I=L") || levelStr.contains("IMPACT=LOW") {
                impact = .low
            }
        }

        return Risk(description: description, likelihood: likelihood, impact: impact)
    }

    private func extractPercentage(from text: String, key: String) -> Double? {
        let pattern = "\(key):?\\s*([\\d.]+)%?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        if let value = Double(text[valueRange]) {
            return value > 1 ? value / 100 : value
        }
        return nil
    }

    private func extractAmount(from text: String, key: String) -> Double? {
        let pattern = "\(key):?\\s*\\$?([\\d,]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let valueStr = text[valueRange].replacingOccurrences(of: ",", with: "")
        return Double(valueStr)
    }

    private func extractDays(from text: String, key: String) -> Int? {
        let pattern = "\(key):?\\s*(\\d+)\\s*(days?|weeks?|months?)?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        var days = Int(text[valueRange]) ?? 30

        // Convert weeks/months to days
        if match.numberOfRanges > 2,
           let unitRange = Range(match.range(at: 2), in: text) {
            let unit = text[unitRange].lowercased()
            if unit.starts(with: "week") {
                days *= 7
            } else if unit.starts(with: "month") {
                days *= 30
            }
        }

        return days
    }

    private func generateDefaultCOAs(count: Int) -> [CourseOfAction] {
        let templates = [
            ("Swift Strike", "Aggressive, fast-paced approach prioritizing speed over caution", 0.08, 120000.0, 14),
            ("Deliberate Advance", "Methodical approach with thorough preparation and risk mitigation", 0.03, 80000.0, 45),
            ("Balanced Response", "Balanced approach trading off speed, cost, and risk", 0.05, 100000.0, 30),
            ("Economy of Force", "Resource-efficient approach minimizing expenditure", 0.02, 50000.0, 60)
        ]

        return templates.prefix(count).enumerated().map { _, template in
            CourseOfAction(
                name: template.0,
                description: template.1,
                readinessImpact: template.2,
                fundingRequired: template.3,
                scheduleImpactDays: template.4,
                risks: [
                    Risk(description: "Execution risk", likelihood: .medium, impact: .medium),
                    Risk(description: "Resource constraints", likelihood: .low, impact: .high)
                ],
                assumptions: ["Standard operating conditions", "No major disruptions"]
            )
        }
    }
}

// MARK: - Deterministic COA Generator (for testing)

/// Generates COAs without LLM (for testing/fallback)
public struct DeterministicCOAGenerator: COAGenerator {
    public init() {}

    public func generateCOAs(
        assessment: IntegratedAssessment,
        context: MissionContext,
        count: Int
    ) async throws -> [CourseOfAction] {
        let baseTemplates = [
            ("Aggressive", "Fast execution prioritizing speed", 0.10, 150000.0, 14),
            ("Deliberate", "Methodical with thorough planning", 0.03, 80000.0, 45),
            ("Balanced", "Moderate pace balancing factors", 0.05, 100000.0, 30),
            ("Economical", "Resource-conservative approach", 0.02, 50000.0, 60)
        ]

        return baseTemplates.prefix(count).map { template in
            CourseOfAction(
                name: template.0,
                description: template.1 + " for: \(assessment.missionStatement.prefix(50))",
                readinessImpact: template.2,
                fundingRequired: template.3,
                scheduleImpactDays: template.4,
                risks: [
                    Risk(description: "Execution risk", likelihood: .medium, impact: .medium)
                ],
                assumptions: context.constraints.isEmpty ? ["Standard conditions"] : context.constraints
            )
        }
    }
}
