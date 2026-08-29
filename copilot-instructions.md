# .NET Modernisation & Upgrade – Custom Instructions

> **Preparation Required:**
> Before starting, ensure you have completed the steps in [copilot-preparation.md](./copilot-preparation.md) to set up the GitHub MCP Server and prerequisites.
If you want to use the official Copilot extension or alternative upgrade tools, see [copilot-upgrade-tools.md](./copilot-upgrade-tools.md) for guidance before proceeding with these custom instructions.

---

## ⛔ Unit Test Generation — Mandatory 4-Step Workflow

When asked to generate unit tests, create tests, improve coverage, or analyse test coverage, you MUST follow these steps **in strict order**:

1. **Read and execute** the `scan-repository` skill: [.github/skills/scan-repository/SKILL.md](./skills/scan-repository/SKILL.md)
2. **Read and execute** the `analyze-coverage` skill: [.github/skills/analyze-coverage/SKILL.md](./skills/analyze-coverage/SKILL.md)
3. **Read and execute** the `plan-tests` skill: [.github/skills/plan-tests/SKILL.md](./skills/plan-tests/SKILL.md)
   - **OUTPUT THE PLAN AND STOP. Do NOT write any test files.**
   - Ask: *"Do you approve this plan? (Approve / Modify / Stop)"*
   - **Do not proceed until the user explicitly approves.**
4. Only after the user approves — **read and execute** the `generate-and-validate-tests` skill: [.github/skills/generate-and-validate-tests/SKILL.md](./skills/generate-and-validate-tests/SKILL.md)

> **Never skip Step 3 approval. Never generate test files before the user approves the plan.**
> If you are about to create a test file and no plan has been approved in this conversation, stop and present the plan first.

---

## Table of Contents
- [Upgrade .NET Projects](./upgrade-dotnet.md)
- [Saturn Pipeline and Deployment Modernisation](./saturn-pipelines.md)
- [Setup .NET API Projects](./setup-dotnet-api.md)
- [How-to Guides for .NET Modernisation](./how-to-guides.md)

---