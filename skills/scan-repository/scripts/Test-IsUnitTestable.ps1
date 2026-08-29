<# 
.SYNOPSIS
    Checks if a file is suitable for unit testing
.DESCRIPTION
    Analyzes file to determine if it can be unit tested or needs integration tests.
    Uses a two-phase approach: first check POSITIVE testable patterns, then NEGATIVE skip patterns.
    The key principle: if a class has conditional logic, error handling, or business rules → TESTABLE.
.PARAMETER FilePath
    Path to the C# file to analyze
.EXAMPLE
    .\Test-IsUnitTestable.ps1 -FilePath "./src/MyService.cs"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

if (-not (Test-Path $FilePath)) {
    throw "File not found: $FilePath"
}

$file = Get-Item $FilePath
$content = Get-Content $FilePath -Raw

# ═══════════════════════════════════════════════════════════
# PHASE 0: Absolute skips (no exceptions)
# ═══════════════════════════════════════════════════════════

# ❌ Skip: Entry points
if ($file.Name -match "^(Program|Startup)\.cs$") {
    return @{ Testable = $false; Reason = "Application entry point" }
}

# ❌ Skip: Interface-only files (no implementation)
if ($content -match "^\s*public\s+interface\s+" -and $content -notmatch "^\s*public\s+(abstract\s+)?class\s+") {
    return @{ Testable = $false; Reason = "Interface without implementation" }
}

# ❌ Skip: Pure constants (only const/static readonly fields, no methods)
if ($content -match "static\s+class\s+\w*Constants?" -and
    $content -notmatch "public\s+(static\s+)?\w+\s+\w+\s*\(") {
    return @{ Testable = $false; Reason = "Pure constants class - no logic" }
}

# ❌ Skip: Static factories / logging infrastructure with external package dependencies
# These use types from Serilog, NewRelic, Splunk, etc. that cannot be mocked or instantiated in tests
if ($content -match "public\s+static\s+class" -and
    $content -match "Serilog|NewRelic|EventCollector|SplunkLoggingOptions|NewRelicLoggingOptions|LoggerConfiguration") {
    return @{ Testable = $false; Reason = "Logging/infrastructure class with external package dependencies" }
}

# ═══════════════════════════════════════════════════════════
# PHASE 1: Positive testable patterns (checked BEFORE skip rules)
# Classes with business logic should ALWAYS be testable
# ═══════════════════════════════════════════════════════════

# ✅ Testable: FluentValidation validators (AbstractValidator<T>, ModelValidatorBase<T>)
# These contain business rules in constructors (RuleFor, Must, When, etc.) and private validation methods
if ($content -match "AbstractValidator<|ModelValidatorBase<|IRuleBuilder|RuleFor\(|RuleForEach\(") {
    return @{ Testable = $true; Reason = "FluentValidation validator with business rules"; Priority = "High" }
}

# ✅ Testable: Services with interface dependencies (most common testable pattern)
if ($content -match "class\s+\w+Service\s*:" -and $content -match "I[A-Z]\w+\s+\w+") {
    return @{ Testable = $true; Reason = "Service with mockable interface dependencies"; Priority = "High" }
}

# ✅ Testable: Data access classes with interface dependencies
if ($content -match "class\s+\w+(DataAccess|Repository)\w*\s*:" -and $content -match "I[A-Z]\w+\s+\w+") {
    return @{ Testable = $true; Reason = "Data access with mockable dependencies"; Priority = "High" }
}

# ✅ Testable: AutoMapper type converters with transformation logic
if ($content -match "ITypeConverter<" -and $content -match "(if\s*\(|switch\s*\(|\?\s*:|string\.Equals|string\.IsNullOrWhiteSpace)") {
    return @{ Testable = $true; Reason = "AutoMapper type converter with transformation logic"; Priority = "High" }
}

# ✅ Testable: Extension methods with business logic (branching, error handling, null guards)
if ($content -match "public\s+static\s+\w+\s+\w+\s*(<\w+>)?\s*\(this\s+") {
    # It's an extension method class - check if it has actual logic
    $hasConditionalLogic = $content -match "(if\s*\(|switch\s*\(|try\s*\{|catch\s*\(|\?\s*:|throw\s+new)"
    $hasBranchingLogic = $content -match "(&&|\|\||\.Any\(|\.All\(|\.Where\(|Enum\.TryParse)"
    if ($hasConditionalLogic -or $hasBranchingLogic) {
        return @{ Testable = $true; Reason = "Extension methods with business logic"; Priority = "Medium" }
    }
}

# ✅ Testable: AutoMapper Profile with non-trivial mappings (ForMember, ConvertUsing, etc.)
if ($content -match ":\s*Profile" -and $content -match "(ConvertUsing|ForMember|MapFrom|Condition)") {
    return @{ Testable = $true; Reason = "AutoMapper Profile with mapping configuration"; Priority = "Low" }
}

# ✅ Testable: Result/monad pattern classes with factory methods
if ($content -match "class\s+Result" -and $content -match "public\s+static\s+.*\s+(Success|Failure|Ok|Error)\s*\(") {
    return @{ Testable = $true; Reason = "Result pattern with factory methods"; Priority = "Low" }
}

# ═══════════════════════════════════════════════════════════
# PHASE 2: Negative skip rules
# Only reached if no positive pattern matched
# ═══════════════════════════════════════════════════════════

# ❌ Skip: Azure Functions with trigger bindings (integration-level)
# IMPORTANT: Only skip if the class is an actual Azure Function (has [Function()] attribute)
if ($content -match "\[Function\(" -and 
    $content -match "ServiceBusMessageActions|BlobTrigger|QueueTrigger|EventGridTrigger|ServiceBusTrigger|TimerTrigger|HttpTrigger") {
    return @{ Testable = $false; Reason = "Azure Function with trigger binding - requires integration test" }
}

# ❌ Skip: Direct Azure SDK usage without abstraction (only for non-service classes)
# Note: Services that USE Azure SDK through injected interfaces are still testable (caught in Phase 1)
if ($content -match "new\s+(TableClient|BlobClient|QueueClient|BlobServiceClient)" -and 
    $content -notmatch "I[A-Z]\w+(Client|Service|Factory)\s+\w+") {
    return @{ Testable = $false; Reason = "Direct Azure SDK instantiation - needs interface wrapper" }
}

# ❌ Skip: Pure Azure SDK factory/wrapper classes (just return new XxxClient(...))
# These only create SDK client instances - testing them would be testing the SDK itself
if ($content -match "class\s+\w*(Factory|ClientProvider)\w*\s*:" -and
    $content -match "new\s+(BlobServiceClient|TableServiceClient|QueueServiceClient|BlobClient|TableClient)" -and
    $content -notmatch "(if\s*\(.*\.Contains|switch\s*\(|\.Select\(|\.Where\(|for\s*\(|foreach\s*\()") {
    return @{ Testable = $false; Reason = "Pure Azure SDK factory - testing would duplicate SDK tests" }
}

# ❌ Skip: Static factories with internal/unavailable types from external packages
if ($content -match "public\s+static\s+class.*Factory" -and 
    $content -match "SplunkLoggingOptions|NewRelicLoggingOptions|internal\s+") {
    return @{ Testable = $false; Reason = "Static factory with internal/unavailable types" }
}

# ❌ Skip: Classes implementing ITableEntity (Azure Table Storage SDK POCO)
if ($content -match ":\s*ITableEntity" -and $content -notmatch "(if\s*\(|switch\s*\(|try\s*\{)") {
    return @{ Testable = $false; Reason = "ITableEntity POCO - no business logic" }
}

# ═══════════════════════════════════════════════════════════
# PHASE 3: Heuristic fallback
# ═══════════════════════════════════════════════════════════

# Check if the class has any conditional/business logic at all
$hasBusinessLogic = $content -match "(if\s*\(|switch\s*\(|try\s*\{|for\s*\(|foreach\s*\(|while\s*\(|throw\s+new)"
$hasMethodsWithBody = $content -match "public\s+\w+\s+\w+\s*(<\w+>)?\s*\([^\)]*\)\s*\{" -or
                      $content -match "public\s+(override|virtual|async)\s+\w+"

if (-not $hasBusinessLogic -and -not $hasMethodsWithBody) {
    return @{ Testable = $false; Reason = "No business logic detected - likely a data class" }
}

# ⚠️ Low priority: Has logic but concrete dependencies (no interfaces to mock)
if ($hasBusinessLogic -and $content -notmatch "I[A-Z]\w+\s+\w+" -and 
    $content -notmatch "public\s+static\s+") {
    return @{ Testable = $true; Reason = "Has business logic but concrete dependencies"; Priority = "Low" }
}

# ✅ Default: Has methods and some logic
return @{ Testable = $true; Reason = "Suitable for unit testing"; Priority = "Medium" }
