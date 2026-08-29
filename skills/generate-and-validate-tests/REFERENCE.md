# Generate & Validate Tests — Reference Guide

> This file contains error patterns, examples, and batch sizing guidance.  
> The main workflow lives in [SKILL.md](./SKILL.md). This file is for lookup during error fixing.

---

## ⛔ Secret Scanning — Avoid Push Protection Failures

**GitHub push protection scans test files for secrets exactly like production code.**

> **Authoritative rules live in [SKILL.md — Secret Scanning Gate](./SKILL.md).** This section only adds concrete examples, forbidden patterns, and proven failure evidence to support those rules. If this file conflicts with SKILL.md, SKILL.md takes precedence.

### Examples and Evidence for the Required Format

For every test constant that contains a credential field (`AccountKey=`, `AccountSecret=`, `Password=`, `SharedAccessKey=`, `client_secret=`), you **MUST** use this exact format:

```
"<field1>=<minimal-test-value>;<field2>=TEST-ONLY-VALUE;"
```

**Rules:**
1. **Include ONLY the fields the code-under-test actually reads** — nothing more
2. **Credential field values MUST be `TEST-ONLY-VALUE`** (or `PLACEHOLDER-VALUE`) — no base64 characters, no `=` or `==` suffix
3. **Each field MUST end with `;`** so regex-based parsers can match correctly

**Examples:**

| Scenario | Required format |
|---|---|
| Code parses `AccountName` and `AccountKey` | `"AccountName=testaccount;AccountKey=TEST-ONLY-VALUE;"` |
| Code parses `AccountKey` only | `"AccountKey=TEST-ONLY-VALUE;"` |
| Code parses `client_secret` | `"client_secret=TEST-ONLY-VALUE"` |
| Code parses `password` | `"password=TEST-ONLY-VALUE"` |

**What NOT to do:**

1. Do NOT add provider-specific wrapper fields around credential values (endpoint protocol, endpoint suffix, service-specific format fields) — it is the full service connection string *structure* that triggers detection, not the credential value itself
2. Do NOT use values ending in `=` or `==` (base64 padding characters)
3. Do NOT include more fields than the code-under-test actually reads

> **Proven failure (2026-07-03):** A test constant using a placeholder key value inside a full Azure Storage connection string (containing endpoint protocol, account name, account key, and endpoint suffix fields all together) triggered GitHub push protection even with a clearly fake key value. Stripping the constant down to only the `AccountName=` and `AccountKey=` fields that the constructor regex reads fixed it.

---

## Common Compilation Error Patterns

### Pattern 1: Sealed/Non-Virtual Class Mock

**Error**: `NotSupportedException: Cannot create Mock for sealed class 'BlobClient'`

**Fix**:
1. Check if the class has an interface — mock the interface instead
2. If no interface: mark class as untestable, skip
3. Never try to `Mock<ConcreteAzureSdkClass>()`

**Common sealed classes** (Azure SDK):
- `BlobClient`, `TableClient`, `ServiceBusClient`, `ServiceBusSender`
- `HttpClient` (use `HttpMessageHandler` mock instead)
- `BlobServiceClient`, `TableServiceClient`

---

### Pattern 2: Wrong Data Structure

**Error**: `CS0117: 'ClassName' does not contain definition for 'PropertyName'`

**Fix**:
1. Read source: `grep_search` or `read_file` to find actual properties
2. Update test to use correct property/method name
3. Never guess — always verify against source

---

### Pattern 3: Wrong JSON Library

**Error**: `Cannot deserialize using System.Text.Json` or wrong serializer

**Fix**:
1. Check existing tests/source for which JSON library is used
2. Look for `Newtonsoft.Json` vs `System.Text.Json` imports in the project
3. Match the project's convention

---

### Pattern 4: Namespace/Type Ambiguity

**Error**: `CS0234: The type or namespace 'X' does not exist` or ambiguous reference

**Fix**:
1. Test file namespace causes conflict (e.g., `Tests.Services.Core` resolves as sub-namespace)
2. Add explicit `using Full.Namespace.Path;` at top of test file
3. Use the short type name in code after the using statement

---

### Pattern 5: Azure SDK Mock Returns Null

**Error**: Test passes compilation but `Value.Content` or `Value.Property` is null at runtime

**Cause**: Azure SDK factory methods don't always populate all properties in mock scenarios

**Fix**:
1. For download operations: test only exception paths (reliable)
2. For success paths requiring real SDK objects: mark as integration test territory
3. Document: "Success path requires integration test"

---

### Pattern 6: Logger Verify Fails

**Error**: `Mock verification failed: Expected invocation on logger.Error(...)`

**Cause**: Serilog/ILogger generic method signatures don't match simple Moq setups

**Fix**:
- Option A: Remove logger verification (it's not critical to test)
- Option B: Use `It.IsAny<>()` with correct arity matching the actual call
- Option C: Use a custom logger wrapper that's easier to verify

---

## Batch Sizing Strategy

| Class Complexity | Tests Per Batch | Rationale |
|------------------|-----------------|-----------|
| Simple (DTOs, extensions) | 6–8 | Quick, low risk |
| Standard (services with 2-3 deps) | 8–12 | Normal complexity |
| Complex (many deps, branching) | 10–15 | Needs more scenarios |
| Mappers/Validators | 8–10 | Many input variations |

**Checkpoint threshold**: 25 tests max before compile+test.

---

## Learning Loop Pattern

```
Batch N discovers a pattern:
  → Record: "Mock<SealedClass> fails — use interface or skip"
  
Batch N+1 applies learning:
  → Don't attempt Mock<SealedClass>
  → Use interface mock from start
  → Result: Compiles on first try ✅
```

**Track these patterns per session**:
- Mock limitations (sealed classes, no interfaces)
- JSON library used in project (Newtonsoft vs STJ)
- Data structure conventions (dictionary access vs properties)
- Assertion patterns (FluentAssertions style)
- Namespace conventions (affects using statements)

---

## Checkpoint Examples

**Small file** (3 methods → 12 tests):
```
Checkpoint 1: All 12 tests → Compile → Test → ✅ Done
```

**Medium file** (8 methods → 22 tests):
```
Checkpoint 1: All 22 tests → Compile → Test → ✅ Done
```

**Large file** (15 methods → 42 tests):
```
Checkpoint 1: HTTP operations (25 tests) → Compile → Test → ✅
Checkpoint 2: Auth & errors (17 tests) → Compile → Test → ✅ Done
```

---

## Escalation: When to Mark Untestable

Mark a class untestable after **3 failed attempts** if:
- Sealed Azure SDK class with no interface wrapper
- Constructor directly creates real Azure clients (`new TableServiceClient(...)`)
- Requires real HTTP endpoints / Azure infrastructure
- Static class with no injectable dependencies
- Generated code (auto-generated metadata providers)

**Document each escalation**:
```
Class: RuleService
Status: UNTESTABLE
Reason: Constructor creates real TableServiceClient — no interface abstraction
Recommendation: Refactor to accept ITableServiceClient or test via integration tests
```

---

## Evidence-Based Testing Rule

**ALWAYS read source before writing tests**:

```
❌ WRONG: Assume a null-check exists → write null test
✅ RIGHT: Read source → see no null-check → test actual behavior (may not throw)

❌ WRONG: Assume method returns Result.Failure on error
✅ RIGHT: Read source → see it throws exception → test for exception
```

Never modify production code to make tests pass. Tests must reflect actual behavior.
