---
name: generate-and-validate-tests
description: "[INTERNAL WORKFLOW STEP 4 - FINAL] Generates, compiles, runs, and validates tests per batch with immediate feedback loop. Includes integrated completion report with comprehensive metrics. Automatically triggered after plan-tests approval. Marks workflow completion."
license: MIT
---

# Generate and Validate Tests Skill

---

## ⛔ PRE-FLIGHT GATE — VERIFY BEFORE PROCEEDING

**Before generating ANY test code, confirm ALL of these**:

1. ✅ The user has explicitly said "Approve", "yes", or equivalent in this conversation
2. ✅ A test plan was presented (from plan-tests skill) with priority table
3. ✅ Coverage analysis was completed (baseline numbers exist)

**If ANY of these are false → STOP. Go back to plan-tests and present the plan first.**

---

## Purpose

Generate unit tests following the approved plan. Compile and test each batch immediately. Fix errors within retry limits. Validate coverage improvement.

## Prerequisites

- Test plan approved by user
- Repository scanned (type registry available)
- Coverage analysis complete (baseline locked)

---

## Workflow Mode

Detect mode via `TestResults/workflow-state.json` (see [Load-WorkflowState.ps1](./scripts/Load-WorkflowState.ps1)):
- **Full-repo mode**: Generate tests for all planned classes (priority-ordered)
- **File-specific mode**: Generate tests ONLY for target files (use `IsTarget` flag from type registry)

---

## Processing Order

Load plan using [Load-TestPlan.ps1](./scripts/Load-TestPlan.ps1). Process in strict priority order:

1. 🔴 **CRITICAL** (Risk > 30) → First
2. 🟠 **HIGH** (Risk 20–30)
3. 🟡 **MEDIUM** (Risk 10–20)
4. 🟢 **LOW** (Risk < 10) → Last
5. ⚫ **SKIP** → Ignore entirely

---

## File-by-File Workflow (Repeat Per Class)

### Step 1: Analyze

- Read complete source file (understand methods, dependencies, patterns)
- Read 1–2 existing test files to learn conventions (naming, mocking, assertions)
- Determine checkpoint count: ≤25 tests = 1 checkpoint; >25 = split by 25

### Step 2: Generate Tests (Up to Checkpoint)

- Max 25 tests per checkpoint
- Cover: happy path, null/edge cases, boundaries, exceptions
- Use evidence from source code — **never assume behaviour**
- Match existing test patterns (naming, FluentAssertions, Moq/NSubstitute style)

> **⛔ Secret Scanning Gate — check EVERY test file before writing:**
> 
> For any test constant containing a credential field (`AccountKey=`, `AccountSecret=`, `Password=`, `SharedAccessKey=`, `client_secret=`), use this format:
> ```
> "<field1>=<minimal-test-value>;<credential-field>=TEST-ONLY-VALUE;"
> ```
> **Rules:**
> 1. Include **only** the fields the code-under-test actually reads — nothing more
> 2. Credential values **must** be `TEST-ONLY-VALUE` — no base64 characters, no `=` or `==` suffix
> 3. Do **not** add `DefaultEndpointsProtocol=`, `EndpointSuffix=`, or other cloud provider wrapper fields unless the code explicitly parses them
> 
> See concrete examples and forbidden patterns in [REFERENCE.md — Secret Scanning section](./REFERENCE.md)

### Step 3: Compile

- Run `dotnet build` on test project
- If fails: read errors, read source, fix, recompile
- Max 3 fix attempts per batch
- For common error patterns, see [REFERENCE.md](./REFERENCE.md)

### Step 4: Run Tests

- Run `dotnet test` (optionally filtered to current class)
- All must pass before proceeding

### Step 5: Checkpoint Decision

- More tests remaining for this file? → Return to Step 2
- File complete? → Mark done, proceed to next file in plan
- All files complete? → Proceed to Coverage Validation

---

## Coverage Validation (After All Files)

Run `dotnet test --collect:"XPlat Code Coverage"` and compare to baseline.

**Coverage Loop** (see [Run-CoverageValidation.ps1](./scripts/Run-CoverageValidation.ps1)):
- If below target and more testable classes exist: identify gaps, generate more tests
- Max 5 iterations to prevent infinite loops
- After 5 iterations if still below target: prompt user for override (accept / continue / stop)

---

## Completion Report

**After all batches complete**, output the report using the template in [templates/completion-report.md](./templates/completion-report.md).

**Data source rules**:
- ✅ Use ONLY Coverlet Cobertura XML for coverage numbers
- ✅ Use actual `dotnet test` output for pass/fail counts
- ❌ Never estimate or manually calculate coverage percentages
- ❌ Never inflate numbers or hide gaps

---

## Core Rules

### Must Do ✅

1. **Test each batch immediately** after generation (compile + test before next batch)
2. **Read source code** when fixing errors (evidence-based, never guess)
3. **Learn from Batch N** to improve Batch N+1 (track patterns across batches)
4. **Mark untestable** after 3 failed attempts (document reason, move to next class)
5. **Follow priority order** strictly: Critical → High → Medium → Low
6. **Never modify production code** — only test projects
7. **Use completion report template** — consistent format every run

### Must Not Do ❌

1. **Never skip the pre-flight gate** (verify approval happened)
2. **Never exceed 3 retries** per batch (strict limit)
3. **Never generate report mid-batch** (only after ALL batches complete)
4. **Never test assumptions** (test actual code behaviour)
5. **Never skip validation** (must confirm tests pass before moving on)
6. **Never use realistic credential values in test strings** — any `AccountKey=`, `client_secret=`, `Password=`, `SharedAccessKey=` must use a `UPPER-CASE-HYPHENATED-PLACEHOLDER` with no `=` padding. Values ending in `=` or `==` (base64 padding) trigger GitHub push protection even in fake/test strings. See [REFERENCE.md — Secret Scanning](./REFERENCE.md).

---

## When to Mark Untestable

After 3 failed attempts, mark a class as untestable if:
- Sealed Azure SDK class with no interface wrapper
- Constructor directly creates real Azure clients
- Requires real HTTP endpoints / Azure infrastructure
- Generated code or static classes with no injectable dependencies

Document each escalation with: class name, reason, recommendation.

---

## Batch Progress Format (Per Batch)

```
Batch N: ClassName
├─ Generated: X tests
├─ Compiled: ✅ / ❌ (attempt N/3)
├─ Tests Run: ✅ X/X passed
├─ Coverage: XX.X% (+X.X%)
└─ Status: ✅ Complete / ⚠️ Escalated
```

---

## References

- **Error patterns & examples**: [REFERENCE.md](./REFERENCE.md)
- **Report template**: [templates/completion-report.md](./templates/completion-report.md)
- **Scripts**: [scripts/](./scripts/) (Load-TestPlan, Load-WorkflowState, Run-CoverageValidation, Generate-CompletionReport)

Applying learnings to Batch 3...
```

## Next Steps

After all batches complete:
1. **Run final validation** (quick overall coverage check) ✅
2. **Generate completion report** (comprehensive before/after metrics) ✅
3. **Mark workflow complete** - User receives actionable next steps ✅

All steps executed automatically within this skill - no separate report-results skill needed.

---

**Workflow Position**: Step 4 of 4 (Final Step - includes integrated reporting)
**Triggers Next**: None (workflow complete)
**User Interaction**: None (fully automated)
**Key Innovation**: 
- Immediate per-batch validation prevents error accumulation
- Integrated reporting eliminates separate skill and potential data inconsistencies

---

## Test Results Folder Structure & Archiving

### Expected Folder Structure

**During Active Workflow:**
```
TestResults/
├── {guid-1}/                       # First test run (coverlet auto-generated)
│   └── coverage.cobertura.xml
├── {guid-2}/                       # Second test run (coverlet auto-generated)
│   └── coverage.cobertura.xml
├── {guid-n}/                       # Latest test run
│   └── coverage.cobertura.xml
├── BASELINE/                       # Created by analyze-coverage skill
│   ├── baseline.xml
│   └── metadata.json
├── type-registry.json              # Created by scan-repository skill
├── workflow-state.json             # Created by scan-repository skill
└── TestCoverageReport_*.txt        # Final report (saved here by user/copilot)
```

**Important Notes:**
- **Multiple GUID folders are NORMAL** - Coverlet creates a new GUID folder each time tests run
- **Do NOT manually create a "CURRENT" folder** - Use the latest GUID folder by timestamp
- **Final report should be saved in TestResults/** - Not in project root
- All coverage XML files are identical in structure, use the latest one

### Archiving Completed Workflows

**After workflow completes** (all tests generated, report created):

1. **Archive TestResults folder (MOVE, not copy):**
   ```powershell
   $timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
   $mode = "complete"  # or "full-repo" / "file-specific"
   $archivePath = "TestResults-archive/$timestamp-$mode"
   
   New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
   Move-Item -Path "TestResults" -Destination "$archivePath/TestResults" -Force
   Write-Host "✅ Archived to: $archivePath" -ForegroundColor Green
   Write-Host "   Next workflow will start with clean workspace" -ForegroundColor Gray
   ```

2. **Archive folder structure:**
   ```
   TestResults-archive/
   ├── 2026-02-26-20-48-complete/    # Completed workflow
   │   └── TestResults/              # MOVED from workspace root
   │       ├── {guid-folders}/
   │       ├── BASELINE/
   │       ├── TestCoverageReport_*.txt
   │       └── workflow-state.json
   └── 2026-02-25-14-30-incomplete/   # Interrupted workflow (if any)
       └── TestResults/
   ```

3. **Result:** Workspace root is clean, ready for next workflow
   ```powershell
   # After Move-Item, workspace root should NOT have TestResults/
   Test-Path "./TestResults"  # Should return: False
   ```

### Git Configuration

**Automatically exclude test artifacts:**
```bash
# .gitignore
TestResults/
TestResults-archive/
coverage.cobertura.xml
*.Tests/TestResults/
```

**Why**:
- TestResults/ contains intermediate workflow data
- Archive folders preserve history locally but aren't needed in version control
- Coverage files are regenerated on each test run
