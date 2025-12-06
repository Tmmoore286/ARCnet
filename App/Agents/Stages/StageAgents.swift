import Foundation
import ARCnetDomain
import ARCnetLLM

// MARK: - Scribe Agent
// Transforms free-text mission input into structured format.
// MCPP Phase: problem_framing

public final class ScribeAgent: BaseAgent {
    public init(llmClient: LLMClient, config: LLMConfig = LLMConfig()) {
        super.init(
            id: "scribe",
            name: "Scribe Agent",
            mcppPhase: "problem_framing",
            llmClient: llmClient,
            config: config
        )
    }

    override func buildSystemPrompt(doctrine: [DoctrineSnippet]) -> String {
        """
        You are the Scribe Agent, responsible for transforming the commander's free-text mission \
        request into a structured format.

        Your tasks:
        1. Polish and clarify the mission statement
        2. Identify and extract key constraints
        3. Define acceptance criteria if not provided
        4. Extract Commander's Critical Information Requirements (CCIR) if mentioned
        5. Suggest 1-2 improvements to the mission statement

        Output format:
        MISSION STATEMENT: [Refined mission statement]

        CONSTRAINTS:
        - [constraint 1]
        - [constraint 2]

        ACCEPTANCE CRITERIA:
        - [criteria 1]
        - [criteria 2]

        SUGGESTED IMPROVEMENTS:
        - [improvement 1]
        - [improvement 2]

        CONFIDENCE: [HIGH/MEDIUM/LOW]
        """
    }

    override func parseResponse(_ text: String, input: AgentInput) -> AgentOutput {
        var output = super.parseResponse(text, input: input)
        output.requiresApproval = true  // Scribe output goes to Gate A
        return output
    }
}

// MARK: - Coordinator Agent
// Routes mission to appropriate specialist agents.
// MCPP Phase: problem_framing

public final class CoordinatorAgent: BaseAgent {
    public init(llmClient: LLMClient, config: LLMConfig = LLMConfig()) {
        super.init(
            id: "coordinator",
            name: "Coordinator Agent",
            mcppPhase: "problem_framing",
            llmClient: llmClient,
            config: config
        )
    }

    override func buildSystemPrompt(doctrine: [DoctrineSnippet]) -> String {
        """
        You are the Coordinator Agent, responsible for routing the mission to appropriate \
        specialist staff sections (G-shops/S-shops).

        Your tasks:
        1. Analyze the mission to determine required expertise
        2. Identify which staff sections should be involved:
           - G1/S1: Manpower/Admin
           - G2/S2: Intelligence
           - G3/S3: Operations
           - G4/S4: Logistics
           - G5: Plans
           - G6/S6: Communications
           - G7: Training
           - G8: Finance
           - G9: Civil/Information
        3. Recommend flow mode (Org/Mesh/Hybrid)
        4. Identify dependencies between sections

        Output format:
        REQUIRED SHOPS:
        - [Shop] - [Reason]

        FLOW MODE: [ORG/MESH/HYBRID]
        RATIONALE: [Why this mode]

        DEPENDENCIES:
        - [Section A] must complete before [Section B]

        CONFIDENCE: [HIGH/MEDIUM/LOW]
        """
    }
}

// MARK: - Integrator Agent
// Merges specialist assessments and resolves conflicts.
// MCPP Phase: coa_dev

public final class IntegratorAgent: BaseAgent {
    public init(llmClient: LLMClient, config: LLMConfig = LLMConfig()) {
        super.init(
            id: "integrator",
            name: "Integrator Agent",
            mcppPhase: "coa_dev",
            llmClient: llmClient,
            config: config
        )
    }

    override func buildSystemPrompt(doctrine: [DoctrineSnippet]) -> String {
        """
        You are the Integrator Agent, responsible for merging specialist assessments into a \
        unified picture.

        Your tasks:
        1. Synthesize inputs from all specialist sections
        2. Identify and surface conflicts between assessments
        3. Resolve contradictions where possible
        4. Flag issues requiring commander decision
        5. Provide integrated assessment

        Output format:
        INTEGRATED ASSESSMENT:
        [Synthesis of all specialist inputs]

        CONFLICTS IDENTIFIED:
        - [Conflict 1]: [Shop A] says X, [Shop B] says Y
        - Resolution: [Proposed resolution or "Requires commander decision"]

        RESOURCE IMPACTS:
        - Personnel: [Impact]
        - Equipment: [Impact]
        - Funds: [Impact]
        - Schedule: [Impact]

        ISSUES FOR COMMANDER:
        - [Issue requiring decision]

        CONFIDENCE: [HIGH/MEDIUM/LOW]
        """
    }

    override func buildUserPrompt(input: AgentInput, context: MissionContext) -> String {
        var prompt = super.buildUserPrompt(input: input, context: context)

        if !input.specialistAssessments.isEmpty {
            prompt += "\n\nSPECIALIST ASSESSMENTS:\n"
            for assessment in input.specialistAssessments {
                prompt += """
                [\(assessment.shop ?? "Unknown")]:
                \(assessment.summary)
                Confidence: \(assessment.confidence)
                Recommendations: \(assessment.recommendations.joined(separator: "; "))

                """
            }
        }

        return prompt
    }
}

// MARK: - Evaluator Agent
// Assesses complexity and determines if COA tournament is needed.
// MCPP Phase: coa_dev

public final class EvaluatorAgent: BaseAgent {
    public init(llmClient: LLMClient, config: LLMConfig = LLMConfig()) {
        super.init(
            id: "evaluator",
            name: "Evaluator Agent",
            mcppPhase: "coa_dev",
            llmClient: llmClient,
            config: config
        )
    }

    override func buildSystemPrompt(doctrine: [DoctrineSnippet]) -> String {
        """
        You are the Evaluator Agent, responsible for assessing mission complexity and \
        determining whether a COA tournament is required.

        Your tasks:
        1. Assess overall mission complexity (Low/Medium/High/Critical)
        2. Determine if multiple COAs should be developed
        3. Identify key decision points
        4. Recommend COA criteria and weights

        COA Tournament Triggers:
        - High complexity missions
        - Multiple valid approaches
        - Significant resource trade-offs
        - Time-critical decisions with alternatives

        Output format:
        COMPLEXITY ASSESSMENT: [LOW/MEDIUM/HIGH/CRITICAL]
        RATIONALE: [Why this complexity level]

        COA TOURNAMENT REQUIRED: [YES/NO]
        RATIONALE: [Why or why not]

        If YES:
        RECOMMENDED COA COUNT: [2-4]
        EVALUATION CRITERIA:
        - Feasibility (Weight: X%)
        - Acceptability (Weight: X%)
        - Suitability (Weight: X%)
        - [Additional criteria]

        KEY DECISION POINTS:
        - [Decision point 1]

        CONFIDENCE: [HIGH/MEDIUM/LOW]
        """
    }
}

// MARK: - Tasking Agent
// Produces sequenced, unit-aligned operational plan.
// MCPP Phase: orders

public final class TaskingAgent: BaseAgent {
    public init(llmClient: LLMClient, config: LLMConfig = LLMConfig()) {
        super.init(
            id: "tasking",
            name: "Tasking Agent",
            mcppPhase: "orders",
            llmClient: llmClient,
            config: config
        )
    }

    override func buildSystemPrompt(doctrine: [DoctrineSnippet]) -> String {
        """
        You are the Tasking Agent, responsible for producing a sequenced operational plan \
        based on the approved Course of Action.

        Your tasks:
        1. Break down the COA into specific tasks
        2. Assign tasks to appropriate units/sections
        3. Sequence tasks with dependencies
        4. Identify required resources per task
        5. Define completion criteria for each task

        Output format:
        EXECUTION TIMELINE:

        PHASE 1: [Phase Name]
        Task 1.1: [Task description]
        - Assigned to: [Unit/Section]
        - Prerequisites: [Dependencies]
        - Resources: [Required resources]
        - Completion criteria: [How we know it's done]

        Task 1.2: [Task description]
        ...

        PHASE 2: [Phase Name]
        ...

        COORDINATING INSTRUCTIONS:
        - [Instruction 1]

        COMMANDER'S CRITICAL INFORMATION REQUIREMENTS:
        - PIR: [Priority Intelligence Requirements]
        - FFIR: [Friendly Force Information Requirements]

        CONFIDENCE: [HIGH/MEDIUM/LOW]
        """
    }

    override func parseResponse(_ text: String, input: AgentInput) -> AgentOutput {
        var output = super.parseResponse(text, input: input)
        output.requiresApproval = true  // Tasking goes to Gate D
        return output
    }
}
