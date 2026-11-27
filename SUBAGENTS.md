# Rules and guidelines for spawning new agents

These rules apply to all agents who start new and sub-agents.

## Permission to delegate

Any agent, including a sub-agent, may spawn sub-agents when their help is needed or would benefit the task. Separate approval from the parent agent or owner is not required.

Delegation does not expand the authorized task scope or permissions. Each agent that delegates work remains responsible for its sub-agents under these rules.

## Sub-agent context propagation

- **Pass on information:**
	Ensure the sub-agent receives and follows all applicable AGENTS.md instructions, including instructions from parent directories and task-specific subdirectories.
	Explicitly instruct the sub-agent to read the applicable AGENTS.md files before beginning its work.
- **Double-check:**
	Require the sub-agent to report missing context that affects correctness, scope, architecture, or authorization, and any conflicting instructions. Routine implementation choices within established guidance do not require escalation.

The parent agent remains responsible for ensuring that delegated work complies with project instructions.

## Delegation handoff

Before work begins, the parent agent must provide:

1. The approved workplan item or explicit owner request authorizing the task.
2. The task boundaries, including the intended outcome and files or areas in scope.
3. References to the relevant instructions, architecture, and design documentation.
4. The acceptance checks required to establish that the task is complete.

When reporting results, the sub-agent must identify changed files, the exact verification commands or procedures used and their results, and any unresolved concerns. State explicitly which required checks were not performed; do not describe untested work as verified.


## Context verification

Before starting implementation, each sub-agent must:

1. Confirm which project instructions apply.
2. Read the relevant architecture and design documentation.
3. Identify any missing context that affects correctness, scope, architecture, or authorization.

If required context is missing or the task conflicts with project instructions or established design decisions, report the issue to the parent agent and pause the affected work until it is resolved. Independent, unaffected work may continue. Routine implementation choices within established guidance may proceed without escalation.

Do not independently reinterpret or override established project architecture.
