# Analyze Coverage — Reference Guide

> Detailed coverage metric definitions, edge case detection patterns, and risk scoring formula.  
> The main workflow lives in [SKILL.md](./SKILL.md).

---

## Coverage Metrics Explained

### 0. Overall Coverage
Same as Line Coverage. The primary indicator reported first in all outputs.

### 1. Line Coverage
```
Line Coverage = (Covered Lines / Total Executable Lines) × 100%
```
Measures which statements execute. Doesn't verify correctness or all paths.

### 2. Branch Coverage
```
Branch Coverage = (Covered Branches / Total Branches) × 100%
```
Measures if/else, switch, ternary paths. 100% requires testing both true AND false for every condition.

### 3. Method Coverage
```
Method Coverage = (Methods with ≥ 1 Test / Total Methods) × 100%
```
Breadth metric. One call = "covered" (doesn't measure depth).

### 4. Full Method Coverage (Most Important)
```
Full Method Coverage = (Methods with line-rate=1.0 AND branch-rate=1.0) / Total Methods × 100%
```
A method is "fully covered" ONLY when **both** line-rate=1.0 AND branch-rate=1.0. This is the quality metric.

**Common Mistake**: Filtering only by `branch-rate=1.0` is wrong — methods without branches default to 1.0.

---

## Edge Case Detection Patterns

### Null Handling
```csharp
if (param == null)
if (string.IsNullOrEmpty(input))
ArgumentNullException.ThrowIfNull()
```
→ Test scenario: pass null, verify exception or default behavior.

### Boundary Conditions
```csharp
if (value > int.MaxValue)
if (collection.Count == 0)
if (array.Length > 1000)
```
→ Test scenarios: MaxValue, MinValue, 0, empty collection, single item, max size.

### Exception Paths
```csharp
throw new ArgumentException()
throw new InvalidOperationException()
try { } catch (SpecificException e) { }
```
→ Test scenario: trigger each exception path, verify handling.

### Async/Cancellation
```csharp
async Task<T> Method(CancellationToken ct)
ct.ThrowIfCancellationRequested()
```
→ Test scenario: pass cancelled token, verify OperationCanceledException.

### Validation Patterns
```csharp
[Required], [Range(1, 100)], [EmailAddress], [StringLength(50)]
```
→ Test scenarios: null, out-of-range, invalid format, too long.

---

## Risk Score Formula

```
Risk Score = (Cyclomatic Complexity × 2)
           + (Dependency Count × 1.5)
           + (Async Operations × 1.2)
           + (External Calls × 3)
           + (Exception Throws × 1.5)
           - (Current Coverage % × 0.5)
```

### Risk Categories

| Score | Priority | Examples |
|-------|----------|----------|
| > 30 | 🔴 CRITICAL | Payment processing, auth, external APIs |
| 20–30 | 🟠 HIGH | Complex business logic, multi-dep services |
| 10–20 | 🟡 MEDIUM | Standard services, validators |
| < 10 | 🟢 LOW | Utilities, helpers, simple extensions |

### Example Calculation
```
PaymentService.ProcessPayment:
  Cyclomatic Complexity (8) × 2 = 16
  Dependencies (3) × 1.5 = 4.5
  Async Operations (1) × 1.2 = 1.2
  External Calls (2) × 3 = 6
  Exception Throws (3) × 1.5 = 4.5
  Current Coverage (0%) × 0.5 = 0
  ─────────────────────────────
  Total = 32.2 → CRITICAL
```

---

## Output Format (coverage-analysis.json)

```json
{
  "timestamp": "2026-01-31T10:30:00Z",
  "projectName": "ProjectName",
  "baseline": {
    "lineCoverage": 15.5,
    "branchCoverage": 12.3,
    "methodCoverage": 25.0,
    "fullMethodCoverage": 20.0
  },
  "target": {
    "lineCoverage": 80.0,
    "branchCoverage": 70.0,
    "methodCoverage": 85.0,
    "fullMethodCoverage": 60.0
  },
  "gap": {
    "lineCoverage": 64.5,
    "branchCoverage": 57.7
  },
  "uncoveredMethods": [...],
  "partiallyTestedMethods": [...],
  "edgeCases": {
    "nullHandling": [...],
    "boundaryConditions": [...],
    "exceptionScenarios": [...],
    "asyncCancellation": [...]
  },
  "riskScores": {
    "critical": [...],
    "high": [...],
    "medium": [...],
    "low": [...]
  }
}
```

---

## Baseline Locking Rules

- ✅ Save baseline ONLY ONCE (in analyze-coverage step)
- ❌ NEVER overwrite baseline during workflow
- ✅ Use ONLY Coverlet XML data (no estimates)
- ✅ If baseline already exists, preserve original (skip locking)
- ✅ Verify: `TestResults/BASELINE/baseline.xml` + `metadata.json` exist

---

## Validation Checklist

Before proceeding to plan-tests:
- ✅ `TestResults/BASELINE/baseline.xml` exists
- ✅ `TestResults/BASELINE/metadata.json` contains actual Coverlet values
- ✅ `TestResults/coverage-analysis.json` exists and size > 1KB
- ✅ Risk scores calculated only for testable classes
- ✅ Overall Coverage = Line Coverage (same value)
- ✅ Full Method Coverage ≤ Method Coverage
