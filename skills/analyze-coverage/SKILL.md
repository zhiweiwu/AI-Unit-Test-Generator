---
name: analyze-coverage
description: "[INTERNAL WORKFLOW STEP 2] Performs comprehensive coverage analysis including line, branch, method, and full method coverage with edge case detection. Automatically triggered after scan-repository. Can be used standalone to check current coverage."
license: MIT
---

# Analyze Coverage Skill

## Purpose

Generate coverage analysis with 4 metrics, detect edge case gaps, calculate risk scores for test prioritization, and lock baseline for before/after comparison.

## Prerequisites

- Repository scanned (`scan-repository` completed)
- Type registry exists (`$TEST_RESULTS/type-registry.json`)
- .NET SDK available, project compiles

Verify with [Verify-Prerequisites.ps1](./scripts/Verify-Prerequisites.ps1).

---

## Workflow Mode

Load from `$TEST_RESULTS/workflow-state.json`:
- **Full-repo mode**: Analyze entire project coverage
- **File-specific mode**: Filter analysis to target files only

---

## Execution Steps

### Step 1: Run Tests and Collect Coverage

```bash
# Output goes to <test-project>/TestResults/ automatically — do NOT add --results-directory
dotnet test <path-to-test-project> --collect:"XPlat Code Coverage"
```

After running, set `$TEST_RESULTS = "<test-project-dir>/TestResults"` (the latest GUID subfolder contains `coverage.cobertura.xml`).

If no tests exist: baseline is 0% for all metrics.

### Step 2: Calculate Coverage Metrics

Use [Calculate-CoverageMetrics.ps1](./scripts/Calculate-CoverageMetrics.ps1) to parse Coverlet XML and extract all 4 metrics:
- Line Coverage
- Branch Coverage
- Method Coverage
- Full Method Coverage (line-rate=1.0 AND branch-rate=1.0)

For metric definitions, see [REFERENCE.md](./REFERENCE.md).

### Step 3: Lock Baseline

**MUST run:**
```bash
pwsh .github/skills/analyze-coverage/scripts/Lock-Baseline.ps1 -CoverageXmlPath "<path-to-coverage.cobertura.xml>" -TestResultsDir "$TEST_RESULTS"
```
- Skips if baseline already exists (preserves original)
- ✅ Save baseline ONLY ONCE — ❌ NEVER overwrite

### Step 4: Identify Uncovered Code

**Priority 1**: Completely untested methods (0% coverage)  
**Priority 2**: Partially tested methods (some branches missing)  
**Priority 3**: Specific uncovered branches

### Step 5: Edge Case Detection

Scan source files for patterns that need test coverage:
- **Null handling**: `if (x == null)`, `ArgumentNullException.ThrowIfNull()`
- **Boundaries**: `if (value > max)`, `if (collection.Count == 0)`
- **Exceptions**: `throw new`, `try/catch`
- **Async/Cancellation**: `CancellationToken`, `ThrowIfCancellationRequested()`
- **Validation**: `[Required]`, `[Range]`, `RuleFor`

For full pattern list, see [REFERENCE.md](./REFERENCE.md).

### Step 6: Filter Non-Testable Classes

Using type registry from Step 1 (scan-repository):
- Exclude classes marked as not testable (triggers, SDK wrappers, DTOs, etc.)
- Only calculate risk scores for testable classes
- Log skipped classes for transparency

### Step 7: Calculate Risk Scores

For each **testable** class, compute risk score (see [REFERENCE.md](./REFERENCE.md) for formula):
- ðŸ”´ CRITICAL (> 30): External APIs, payment, auth
- ðŸŸ  HIGH (20â€“30): Complex business logic
- ðŸŸ¡ MEDIUM (10â€“20): Standard services
- ðŸŸ¢ LOW (< 10): Utilities, simple helpers

### Step 8: Export Coverage Analysis

**MUST run:**
```bash
pwsh .github/skills/analyze-coverage/scripts/Export-CoverageAnalysis.ps1 -TestResultsDir "$TEST_RESULTS"
```

Saves `$TEST_RESULTS/coverage-analysis.json` containing: baseline/target metrics, coverage gaps, risk scores, edge cases, estimated tests needed.

---

## Key Outputs

| File | Purpose | Used By |
|------|---------|---------|
| `$TEST_RESULTS/BASELINE/baseline.xml` | Immutable coverage baseline | Final report comparison |
| `$TEST_RESULTS/BASELINE/metadata.json` | Baseline metrics + timestamp | Final report |
| `$TEST_RESULTS/coverage-analysis.json` | Full analysis data | plan-tests skill |

---

## Rules

### Must Do ✅
1. **Use Coverlet XML only** — never estimate or guess coverage numbers
2. **Lock baseline once** — never overwrite
3. **Filter non-testable classes** before risk scoring
4. **Calculate all 4 metrics** (Line, Branch, Method, Full Method)
5. **Export to JSON** for plan-tests consumption
6. **Validate**: Overall = Line, Full Method ≤ Method

### Must Not Do ❌
1. **Never modify** source or test files
2. **Never skip** baseline locking
3. **Never include** untestable classes in risk scores
4. **Never estimate** — always use actual Coverlet data

---

## Next Step

After successful analysis → **automatically trigger `plan-tests` skill**.

---

## References

- **Metric definitions, risk formula, edge case patterns**: [REFERENCE.md](./REFERENCE.md)
- **Scripts**: [scripts/](./scripts/) (Calculate-CoverageMetrics, Lock-Baseline, Export-CoverageAnalysis, Verify-Prerequisites)
- Uncovered/partially-tested method lists
- Risk scores per class (CRITICAL â†’ LOW)
- Edge case patterns detected
- Estimated tests needed

---

## Key Outputs

| File | Purpose | Used By |
|------|---------|---------|
| `TestResults/BASELINE/baseline.xml` | Immutable coverage baseline | Final report comparison |
| `TestResults/BASELINE/metadata.json` | Baseline metrics + timestamp | Final report |
| `TestResults/coverage-analysis.json` | Full analysis data | plan-tests skill |

---

## Rules

### Must Do âœ…
1. **Use Coverlet XML only** â€” never estimate or guess coverage numbers
2. **Lock baseline once** â€” never overwrite
3. **Filter non-testable classes** before risk scoring
4. **Calculate all 4 metrics** (Line, Branch, Method, Full Method)
5. **Export to JSON** for plan-tests consumption
6. **Validate**: Overall = Line, Full Method â‰¤ Method

### Must Not Do âŒ
1. **Never modify** source or test files
2. **Never skip** baseline locking
3. **Never include** untestable classes in risk scores
4. **Never estimate** â€” always use actual Coverlet data

---

## Next Step

After successful analysis â†’ **automatically trigger `plan-tests` skill**.

---

## References

- **Metric definitions, risk formula, edge case patterns**: [REFERENCE.md](./REFERENCE.md)
- **Scripts**: [scripts/](./scripts/) (Calculate-CoverageMetrics, Lock-Baseline, Export-CoverageAnalysis, Verify-Prerequisites)

