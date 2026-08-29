---
name: plan-tests
description: "[INTERNAL WORKFLOW STEP 3 - USER APPROVAL REQUIRED] Creates comprehensive test strategy with edge cases and risk prioritization. Automatically triggered after analyze-coverage. MUST pause for user confirmation before proceeding."
license: MIT
---

---

## ⛔ MANDATORY STOP — READ BEFORE DOING ANYTHING ELSE

**You MUST output the full test plan to the user and then STOP completely.**

- ❌ Do NOT call `create_file`, `replace_string_in_file`, or any file-writing tool after this skill.
- ❌ Do NOT generate any test files, test classes, or test methods.
- ❌ Do NOT proceed to the `generate-and-validate-tests` skill.
- ✅ Output the plan using the **exact format** in [templates/plan-output.md](./templates/plan-output.md).
- ✅ End your response by asking: **"Do you approve this plan? (Approve / Modify / Stop)"**
- ✅ Wait for the user to reply with explicit approval before taking any further action.

If you find yourself about to write a test file and the user has not yet approved a plan in this conversation, **STOP**, output the plan, and wait.

---

# Plan Tests Skill

## Purpose

Transform coverage analysis into a prioritized test plan ordered by risk (CRITICAL → HIGH → MEDIUM → LOW). This is the **ONLY manual checkpoint** where user approval is required.

## Prerequisites

- Coverage analysis completed (from `analyze-coverage`)
- Risk scores calculated
- Coverage gaps and edge cases identified

---

## Workflow Mode

Load workflow state via [Load-CoverageAnalysis.ps1](./scripts/Load-CoverageAnalysis.ps1):
- **Full-repo mode**: Plan tests for all uncovered/low-coverage files (prioritized by risk)
- **File-specific mode**: Plan tests ONLY for files specified in `workflow-state.json`

---

## Prioritization Logic

1. Load risk scores from Step 2 output
2. Order classes by risk: Critical (>30) > High (20–30) > Medium (10–20) > Low (<10)
3. Within each priority, order by complexity (highest first)
4. Mark untestable classes as SKIP with reason

**Risk Assessment**: If total planned tests > 50, recommend focusing on HIGH+ priority first (see [Assess-GenerationRisk.ps1](./scripts/Assess-GenerationRisk.ps1)).

---

## Output Format

**You MUST use the template at [templates/plan-output.md](./templates/plan-output.md).**

The template requires:
1. **Coverage Goals table** — Current vs Target vs Gap (Line + Branch)
2. **Priority table** — All classes ordered by priority with test counts and risk scores
3. **Skip list** — All untestable classes with specific reasons
4. **Summary** — Total tests, files, estimated coverage
5. **Risks & Limitations** — Anything that can't be tested and why

---

## What Goes in Each Priority

### 🔴 CRITICAL (Risk > 30)
- Zero coverage + high complexity
- Business-critical logic
- External API calls with error handling

### 🟠 HIGH (Risk 20–30)
- Core business logic with multiple branches
- Services with complex dependency chains

### 🟡 MEDIUM (Risk 10–20)
- Standard services with partial coverage
- Validation logic, mappers

### 🟢 LOW (Risk < 10)
- Simple utilities, extensions, helpers
- Low-complexity code

### ⚫ SKIP (Untestable)
- Azure Function triggers (ServiceBusTrigger, BlobTrigger, etc.)
- Classes that create real Azure SDK clients in constructor
- Generated code (metadata providers, startup code)
- Program.cs, Startup.cs
- Static classes without injectable dependencies
- Pure models/DTOs with no logic

---

## User Response Handling

| User Says | Action |
|-----------|--------|
| "Approve" / "yes" / "y" | Proceed to `generate-and-validate-tests` skill |
| "No" / "cancel" / "stop" | Halt workflow |
| Feedback text | Incorporate feedback, regenerate plan, ask again |

---

## Rules

### Must Do ✅
1. **ALWAYS wait for user approval** before proceeding
2. **Use the plan-output template** — no freeform output
3. **Provide realistic estimates** (tests, coverage gain)
4. **Organize by priority** (CRITICAL first)
5. **Include all edge cases** from coverage analysis
6. **Be transparent** about untestable classes (list them all in Skip)

### Must Not Do ❌
1. **NEVER proceed** without explicit user approval
2. **NEVER auto-approve** the plan
3. **NEVER generate tests** in this skill
4. **NEVER promise 100% coverage** (unrealistic)
5. **NEVER hide limitations** — always show what can't be tested

## Next Steps

**If User Approves**:
1. Store approved plan
2. Trigger `generate-unit-tests` skill
3. Pass plan details forward

**If User Rejects**:
1. Log rejection reason
2. Halt workflow gracefully
3. Provide summary of what was skipped

**If User Requests Changes**:
1. Incorporate feedback
2. Regenerate plan
3. Ask for approval again

## Example Plan Output

```markdown
# 📋 Unit Test Generation Plan
**Project**: ExampleProject.Api
**Generated**: 2026-01-31 10:35:00

## 🎯 Coverage Goals
| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Line Coverage | 0% | 80% | +80% |
| Branch Coverage | 0% | 75% | +75% |
| Method Coverage | 0% | 85% | +85% |
| **Full Method Coverage** | 0% | 80% | +80% |

## 🔴 High Priority (Must Test)

### 1. DeliveryResponseHandlerFunction.Run
- **Risk Score**: 28 (Critical)
- **Tests**: 6
- Scenarios: Happy path, null request, invalid payload, service bus errors, logging verification, cancellation

### 2. CallbackService.ProcessCallbackAsync  
- **Risk Score**: 25 (Critical)
- **Tests**: 7
- Scenarios: Valid callback, null input, invalid type, repository error, mapping error, exception handling, async cancellation

... (continues) ...

## ⚠️ Approval Required
- **Total Tests**: 47
- **Estimated Time**: ~6 minutes
- **Expected Coverage**: 0% → 78%

**Proceed with test generation?** (yes/no)
```

---

**Automated Workflow Position**: Skill 3 of 4
**Triggers Next**: `generate-and-validate-tests` (ONLY if user approves)
**User Interaction**: **REQUIRED** ⚠️ (Only manual checkpoint)
