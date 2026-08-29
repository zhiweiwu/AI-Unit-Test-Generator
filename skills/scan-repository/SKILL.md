---
name: scan-repository
description: "[ENTRY POINT] Start here when user requests unit test generation, test coverage analysis, or wants to analyze project structure. Automatically triggers the full test generation workflow. Keywords: 'generate tests', 'create tests', 'test coverage', 'analyze coverage'."
license: MIT
---

# Scan Repository Skill

## Mode Detection (FIRST)

Detect user intent from prompt:

| User Prompt Pattern | Mode | Action |
|---------------------|------|--------|
| "generate tests" (no files specified) | **Full Repo** | Continue below |
| "generate tests for `X.cs`" | **File-Specific** | Read [SKILL-file-specific.md](./SKILL-file-specific.md) |
| "test coverage for specific files" | **File-Specific** | Read [SKILL-file-specific.md](./SKILL-file-specific.md) |

**Coverage Goal Detection**: Extract percentage if mentioned ("to 80%", "reach 60% coverage").

Save mode using [Save-WorkflowMode.ps1](./scripts/Save-WorkflowMode.ps1).

---

## Purpose

Understand the project structure and testing infrastructure before generating tests. First step in the 4-step workflow.

## Prerequisites

- .NET SDK installed
- Read access to repository

## Critical Output

🚨 **MANDATORY**: This skill MUST generate `$TEST_RESULTS/type-registry.json` before completion.

Without type registry, generate-and-validate-tests will:
- ❌ Guess interface names (causing compilation errors)
- ❌ Guess constructor parameters
- ❌ Invent non-existent types

Build it using [Build-TypeRegistry.ps1](./scripts/Build-TypeRegistry.ps1).

---

## Execution Steps

### Step 1: Locate Solution and Projects

1. Search for `.sln` files
2. Parse for project references (`.csproj`)
3. Handle multi-project solutions
4. Identify test project path → set `$TEST_RESULTS = "<test-project-dir>/TestResults"` (used by all subsequent steps)

### Step 2: Analyze Each Project

For each `.csproj`:

**A. Extract framework** (`<TargetFramework>net8.0</TargetFramework>`)

**B. Determine project type**:
- `Microsoft.NET.Sdk.Web` → ASP.NET Core
- `Microsoft.Azure.Functions.Worker` → Azure Functions (Isolated)
- `Microsoft.NET.Sdk` → Class Library

**C. Catalog testing infrastructure** (if test project exists):
- Framework: xUnit / NUnit / MSTest
- Mocking: Moq / NSubstitute / FakeItEasy
- Assertions: FluentAssertions / Shouldly

**D. Verify version consistency** — Test project `TargetFramework` must match source.

### Step 3: Exhaustive Source File Enumeration

Use [Enumerate-SourceFiles.ps1](./scripts/Enumerate-SourceFiles.ps1) to discover ALL `.cs` files in `src/`.

For each file:
1. **Categorize** using [Get-FileCategory.ps1](./scripts/Get-FileCategory.ps1) (by content, NOT directory name)
2. **Check testability** using [Test-IsUnitTestable.ps1](./scripts/Test-IsUnitTestable.ps1)
3. **Calculate risk** using [Calculate-RiskScore.ps1](./scripts/Calculate-RiskScore.ps1)

**Testability uses a two-phase approach**:
1. Phase 1 (Positive): Check testable patterns first (validators, services, converters)
2. Phase 2 (Negative): Only then check skip rules (triggers, SDK instantiation)
3. Phase 3 (Heuristic): Check for conditional logic as fallback

For full classification tables, see [REFERENCE.md](./REFERENCE.md).

### Step 4: Analyze Existing Tests (If Found)

- Count test files and methods
- Detect naming conventions
- Identify mock/assertion patterns
- Record for pattern matching in later steps

### Step 5: Build Type Registry

**MUST run:**
```bash
pwsh .github/skills/scan-repository/scripts/Build-TypeRegistry.ps1 -ProjectPath "<src-dir>" -OutputPath "$TEST_RESULTS/type-registry.json"
```

Verify with [Verify-TypeRegistry.ps1](./scripts/Verify-TypeRegistry.ps1).

### Step 6: Identify Dependencies

Catalog package references that indicate external dependencies:
- Database: EntityFrameworkCore, Dapper
- HTTP: System.Net.Http, Refit
- Azure: ServiceBus, Storage.Blobs, Data.Tables
- Auth: JwtBearer, Microsoft.Identity.Web

---

## TestResults Management

Before starting, check for existing `$TEST_RESULTS/`:
- If exists with data → ask user: Resume (R) / Restart (N) / Cancel (C)
- If empty or missing → create fresh

Ensure `TestResults/` is in `.gitignore`.

---

## Rules

### Must Do ✅
1. **Read-only analysis** — NEVER modify source files
2. **Exhaustive enumeration** — Scan entire `src/` recursively
3. **Content-based categorization** — Analyze file content, NOT directory names
4. **Risk-based scoring** — Calculate for every testable file
5. **Build type registry** — MANDATORY before completion
6. **Handle edge cases**: No solution file, multiple solutions, multi-target frameworks

### Must Not Do ❌
1. **Never modify** production code
2. **Never assume** directory structure indicates file purpose
3. **Never skip** any `.cs` files during enumeration
4. **Never skip** type registry generation

---

## Next Step

After successful scan → **automatically trigger `analyze-coverage` skill**.

---

## References

- **Testability tables & classification details**: [REFERENCE.md](./REFERENCE.md)
- **File-specific workflow**: [SKILL-file-specific.md](./SKILL-file-specific.md)
- **Scripts**: [scripts/](./scripts/) (Build-TypeRegistry, Enumerate-SourceFiles, Get-FileCategory, Calculate-RiskScore, Test-IsUnitTestable, Test-IsSimpleDto, Save-WorkflowMode, Verify-TypeRegistry)
  "ProcessServiceBusMessage": {
    "isTestable": false,
    "skipReason": "Azure Function with trigger - requires integration test",
    "constructor": {
      "parameters": [
        {"type": "ServiceBusMessageActions", "name": "messageActions"}
      ]
    },
    "recommendation": "SKIP or create integration test"
  },
  "UserController": {
    "isTestable": false,
    "skipReason": "API Controller - requires integration test",
    "recommendation": "SKIP unit test, use WebApplicationFactory for integration test"
  },
  "ExternalTokenSyncService": {
    "isTestable": false,
    "skipReason": "Concrete dependency: CryptoService - cannot mock",
    "constructor": {
      "parameters": [
        {"type": "CryptoService", "name": "cryptoService"}
      ]
    },
    "recommendation": "SKIP or create ICryptoService interface first"
  }
}
```

### Incremental Test Generation Strategy

**NEW RULE**: Generate in small batches, validate frequently

```python
# OLD (caused 63 errors):
generate_all_tests(82)  # ❌
compile()

# NEW (prevents cascading failures):
for batch in chunks(testable_classes, size=5):  # ✅
    generate_tests(batch)
    compile_result = compile()
    if compile_result.failed:
        fix_errors(compile_result)
    if compile_result.still_failed:
        escalate(batch)
        skip_batch(batch)
    # Only continue if batch compiles
```

**Batch Strategy**:
1. **Batch 1** (5 tests): Validators (easiest, no mocks)
2. **Batch 2** (5 tests): DTOs/Mappers (simple logic)
3. **Batch 3** (5 tests): Services with 0-2 dependencies
4. **Batch 4+** (5 each): Services with 3+ dependencies
5. **Last**: Functions (integration-heavy)

### CRITICAL Rules

**Must Do** ✅:
1. 🚨 **MANDATORY: Generate TestResults/type-registry.json** - Workflow cannot proceed without this file
2. **Run type discovery BEFORE planning tests** - Prevents 63+ compilation errors
3. **Validate type registry has 100% of classes** - Missing types = test generation failures
4. **Save complete constructor signatures** - Exact parameter types and names required
5. **Enumerate all interfaces** - Prevents guessing interface names (ICryptoService vs CryptoService)
6. **Never assume types - always verify from source** - Real data, not assumptions

**Must Not Do** ❌:
1. **Never generate 80+ tests without incremental compilation**
2. **Never assume interface exists without checking registry**
3. **Never guess constructor parameters**
4. **Never test classes with concrete dependencies without user approval**
5. **Never proceed if type registry is incomplete**

### Verification Checklist

Before moving to `analyze-coverage`, run the [Verify-TypeRegistry.ps1](./scripts/Verify-TypeRegistry.ps1) script:

```powershell
# Verify type registry was created successfully
$verification = & "./skills/scan-repository/scripts/Verify-TypeRegistry.ps1"

if ($verification.Valid) {
    Write-Host "✅ Type registry verified: $($verification.ClassCount) classes" -ForegroundColor Green
} else {
    throw "🛑 Type registry validation failed!"
}
```

The script checks:
- [ ] ✅ Type registry JSON created (`TestResults/type-registry.json`)
- [ ] ✅ File size > 1KB (not empty)
- [ ] ✅ All classes have constructor signatures
- [ ] ✅ All interfaces enumerated
- [ ] ✅ Testability flags identified (isTestable + skipReason)
- [ ] ✅ Non-testable classes flagged with reasons
- [ ] ✅ Batch order determined (easy → hard)

**If ANY item fails**: 🛑 HALT and escalate to user

## Performance Considerations

- **Fast scanning**: Use file system searches, not deep parsing
- **Cache results**: Store scan output for subsequent skills
- **Parallel processing**: Scan multiple projects concurrently
- **Limit scope**: Skip bin/, obj/, node_modules/

## Troubleshooting

### Issue: PowerShell execution policy blocking scripts
**Solution**: Always use `-ExecutionPolicy Bypass` when running .ps1 scripts on Windows
```powershell
# ✅ ALWAYS use this method (don't try without bypass first)
powershell.exe -ExecutionPolicy Bypass -File "path/to/script.ps1"

# ❌ DON'T try this first (will fail in corporate environments)
& "path/to/script.ps1"
```
**Why**: Windows systems (especially corporate) have restricted execution policies by default. Using bypass proactively avoids unnecessary failures.

### Issue: Cannot determine framework version
**Solution**: Parse `<TargetFramework>` from .csproj, fall back to SDK version

### Issue: Multiple test frameworks detected
**Solution**: Use most common framework, warn user about inconsistency

### Issue: No package references found
**Solution**: Check for packages.config (older format), warn if using outdated patterns

---

**Automated Workflow Position**: Skill 1 of 4 (Entry Point)
**Triggers Next**: `analyze-coverage`
**User Interaction**: None (fully automated)
