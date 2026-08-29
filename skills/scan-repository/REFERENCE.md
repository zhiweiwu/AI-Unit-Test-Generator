# Scan Repository — Reference Guide

> Detailed testability classification tables, output format examples, and detection patterns.  
> The main workflow lives in [SKILL.md](./SKILL.md).

---

## Testability Classification

### Classes NOT Suitable for Unit Testing (SKIP)

| Category | Detection Pattern | Why Not Testable |
|----------|------------------|------------------|
| **Simple DTOs/Models** | Only auto-properties, no logic | No behavior to test |
| **Azure Function Triggers** | `[Function(` + `ServiceBusTrigger`, `BlobTrigger`, `TimerTrigger` | Require real Azure runtime |
| **Direct Azure SDK Instantiation** | `new TableClient(...)`, `new BlobClient(...)` without interface | Creates real connections |
| **Pure Azure SDK Factories** | Only wrapping SDK constructors | No business logic |
| **Logging/Infrastructure** | Static classes using Serilog, NewRelic, Splunk | External package dependencies |
| **ITableEntity POCOs** | `: ITableEntity` with only properties | Data transfer objects |
| **Entry Points** | `Program.cs`, `Startup.cs`, `Main()` | Application bootstrap |
| **Interfaces** | `IService.cs`, `IRepository.cs` | No implementation |
| **Pure Constants** | Static class with only `const`/`static readonly` | No behavior |
| **Background Services** | `BackgroundService`, `IHostedService` | Require hosted runtime |
| **API Controllers** | `ControllerBase`, `[ApiController]` | Integration test territory |
| **Middleware** | `IMiddleware`, `RequestDelegate` | Requires pipeline context |
| **DbContext** | `: DbContext` | Requires database |
| **Concrete Dependencies** | Constructor takes concrete classes (not interfaces) | Cannot mock |

---

### Classes That MUST Be Tested (Common Misclassifications)

| Category | Detection Pattern | Why Testable | Priority |
|----------|------------------|--------------|----------|
| **Services with DI** | `class XxxService : IXxxService` + constructor injection | Core business logic | 🔴 HIGH |
| **Data Access with DI** | `class XxxDataAccess : IXxxDataAccess` + injection | Error handling logic | 🔴 HIGH |
| **FluentValidation Validators** | `AbstractValidator<T>`, `RuleFor(...)` | Business rules | 🔴 HIGH |
| **AutoMapper Converters** | `ITypeConverter<TSource, TDest>` with conditionals | Transformation rules | 🟡 MEDIUM |
| **Extension Methods with Logic** | `static class` + `this` + `if/try/catch/switch` | Error handling | 🟡 MEDIUM |
| **AutoMapper Profiles** | `: Profile` with `ConvertUsing` | Configuration validation | 🟢 LOW |
| **Result/Monad Patterns** | `Result<T>.Success()` / `.Failure()` | Domain patterns | 🟢 LOW |

---

### Common Misclassification Traps

- **Validators are NOT DTOs** — FluentValidation validators contain business rules. Always testable.
- **Extension methods are NOT "static to skip"** — If they have `if`, `try/catch`, `switch` → testable.
- **AutoMapper converters are NOT "no public constructor"** — `ITypeConverter<,>` has testable `Convert()` method.
- **"Using Azure SDK types" ≠ "Needs integration test"** — A class receiving `ServiceBusReceivedMessage` as parameter is testable. Only skip classes that **instantiate** Azure SDK clients.

---

## Output Format (type-registry.json)

```json
{
  "CallbackService": {
    "isTestable": true,
    "skipReason": null,
    "category": "Service",
    "riskScore": 28,
    "priority": "High",
    "constructor": {
      "parameters": [
        {"type": "IUserResponseService", "name": "userResponseService"},
        {"type": "IDeliveryResponseService", "name": "deliveryResponseService"}
      ]
    },
    "publicMethods": ["ProcessCallback", "ValidateRequest"],
    "estimatedTests": 6
  },
  "UserDto": {
    "isTestable": false,
    "skipReason": "Model/DTO - no business logic",
    "category": "Model"
  }
}
```

---

## File Categorization

Categorize by **content analysis** (NOT directory names):

| Category | Content Indicators |
|----------|--------------------|
| Service | Implements interface, has constructor injection, business logic methods |
| DataAccess | Database/table operations, repository pattern |
| Extension | `static class` + `this` parameters |
| Factory | Creates and returns instances |
| Validator | `AbstractValidator<T>`, `RuleFor`, validation methods |
| Mapper | `ITypeConverter`, `Profile`, mapping expressions |
| Function | `[Function(` attribute, trigger attributes |
| Controller | `ControllerBase`, `[ApiController]` |
| Utility | Static helper methods |

---

## Risk Score Components

Calculated by [Calculate-RiskScore.ps1](./scripts/Calculate-RiskScore.ps1):

| Factor | Weight | Description |
|--------|--------|-------------|
| Cyclomatic complexity | High | if/switch/for/while statements |
| Constructor parameters | Medium | More deps = more integration risk |
| Async operations | Medium | async/await patterns |
| External dependencies | High | HTTP, database, Service Bus |
| Exception handling | Low | try/catch blocks |

---

## Unit Test Principles

**Tests SHOULD:**
- ✅ Mock all external dependencies using interfaces
- ✅ Test business logic in isolation
- ✅ Run fast (milliseconds)
- ✅ Be deterministic (same input → same output)
- ✅ Focus on: Services, Validators, Converters, Extensions with logic

**Tests Should NOT:**
- ❌ Call real external APIs
- ❌ Connect to real Azure services
- ❌ Require Azure runtime or triggers
- ❌ Access real databases or file systems
- ❌ Depend on network availability

---

## Version Consistency Rule

Test projects MUST match source project versions:

```xml
<!-- Source: net8.0 → Test MUST also be net8.0 -->
<TargetFramework>net8.0</TargetFramework>
```

Recommended stable test package versions:
- `xunit`: 2.6.2+
- `Moq`: 4.20.70+
- `FluentAssertions`: 6.12.0+
- `coverlet.collector`: 8.0.0+

Delete auto-generated template files (`UnitTest1.cs`) — they are scaffolding artifacts.
