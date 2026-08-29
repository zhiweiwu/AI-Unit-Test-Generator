<# 
.SYNOPSIS
    Detects if a file is a simple DTO with no testable logic
.DESCRIPTION
    Checks if file contains only auto-properties and no methods, logic, or validation rules.
    IMPORTANT: Files with FluentValidation rules, extension methods with logic, 
    or AutoMapper type converters are NOT DTOs even if they have few public methods.
.PARAMETER FilePath
    Path to the C# file to analyze
.EXAMPLE
    .\Test-IsSimpleDto.ps1 -FilePath "./src/Models/UserDto.cs"
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
# PHASE 1: Explicit NOT-DTO patterns (never classify these as DTOs)
# ═══════════════════════════════════════════════════════════

# FluentValidation validators have business logic in constructors
if ($content -match "AbstractValidator<|ModelValidatorBase<|RuleFor\(|RuleForEach\(") {
    Write-Host "  NOT a DTO: $($file.Name) - contains FluentValidation rules" -ForegroundColor Green
    return $false
}

# AutoMapper type converters with transformation logic
if ($content -match "ITypeConverter<") {
    Write-Host "  NOT a DTO: $($file.Name) - AutoMapper type converter" -ForegroundColor Green
    return $false
}

# Extension methods with any logic
if ($content -match "public\s+static\s+\w+\s+\w+\s*(<\w+>)?\s*\(this\s+") {
    Write-Host "  NOT a DTO: $($file.Name) - extension methods" -ForegroundColor Green
    return $false
}

# Service classes with dependencies
if ($content -match "class\s+\w+Service\s*:") {
    Write-Host "  NOT a DTO: $($file.Name) - service class" -ForegroundColor Green
    return $false
}

# ═══════════════════════════════════════════════════════════
# PHASE 2: DTO detection heuristics
# ═══════════════════════════════════════════════════════════

# Check for auto-properties
$hasAutoProperties = $content -match "\{\s*get;\s*set;\s*\}"

# Check for public methods (including constructors with body containing logic)
# Detect: public ReturnType MethodName(params) { ... }
$hasPublicMethods = $content -match "public\s+\w+\s+\w+\s*\([^\)]*\)\s*\{"

# Detect constructor with logic (if/switch/RuleFor/etc. inside constructor body)
$hasConstructorLogic = $content -match "public\s+\w+\s*\([^\)]*\)\s*\{[^}]*(if\s*\(|switch\s*\(|RuleFor|for\s*\(|foreach|throw\s+new)"

# Detect private/protected methods (common in validators)
$hasPrivateMethods = $content -match "(private|protected)\s+\w+\s+\w+\s*\([^\)]*\)\s*\{"

# Check for conditional logic anywhere in the file
$hasConditionalLogic = $content -match "(if\s*\(|switch\s*\(|try\s*\{|\?\s*:|throw\s+new)"

# Model/DTO directory hint (not decisive on its own)
$isInModelsDir = $file.Directory.Name -match "^(Models?|DTOs?|Requests?|Responses?)$"

# ═══════════════════════════════════════════════════════════
# PHASE 3: Decision
# ═══════════════════════════════════════════════════════════

# A file is a simple DTO if:
# 1. It has auto-properties AND no methods/logic, OR
# 2. It's in a Models directory, is small, AND has no conditional logic
$isSimpleDto = ($hasAutoProperties -and -not $hasPublicMethods -and -not $hasPrivateMethods -and -not $hasConstructorLogic -and -not $hasConditionalLogic) -or 
               ($isInModelsDir -and $content.Split("`n").Count -lt 30 -and -not $hasConditionalLogic)

if ($isSimpleDto) {
    Write-Host "  DTO detected: $($file.Name)" -ForegroundColor Yellow
}

return $isSimpleDto
