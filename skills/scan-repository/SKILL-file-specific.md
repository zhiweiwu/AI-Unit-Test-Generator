# File-Specific Test Generation Mode

## Overview
This reference describes the **file-specific workflow** when users request tests for specific files rather than the entire repository.

**Use this workflow when**:
- User mentions specific file names (e.g., "PaymentService.cs")
- User lists multiple files explicitly
- User wants targeted coverage improvement

**Instead of**: Full repository scan (see main SKILL.md)

---

## Modified Workflow

### Step 0: Parse User Intent

**Extract target files from user prompt**:
```powershell
# Example user prompt: "Generate tests for PaymentService.cs and AuthService.cs to 80% coverage"

$userPrompt = "Generate tests for PaymentService.cs and AuthService.cs to 80% coverage"

# Parse file names (look for .cs extensions or known class names)
$filePattern = '(\w+\.cs)'
$matches = [regex]::Matches($userPrompt, $filePattern)
$targetFiles = $matches | ForEach-Object { $_.Value }

# Extract coverage goal
$coveragePattern = '(\d+)%'
$coverageMatch = [regex]::Match($userPrompt, $coveragePattern)
$coverageGoal = if ($coverageMatch.Success) { [int]$coverageMatch.Groups[1].Value } else { $null }

Write-Host "Detected mode: FILE-SPECIFIC" -ForegroundColor Yellow
Write-Host "Target files: $($targetFiles -join ', ')" -ForegroundColor Cyan
if ($coverageGoal) {
    Write-Host "Coverage goal: $coverageGoal%" -ForegroundColor Cyan
}
```

### Step 1: Save Workflow State

**Create workflow-state.json**:
```powershell
# Save mode for all subsequent skills
& "./skills/scan-repository/scripts/Save-WorkflowMode.ps1" `
    -Mode "file-specific" `
    -TargetFiles $targetFiles `
    -CoverageGoal $coverageGoal

# Creates: TestResults/workflow-state.json
```

**Result**:
```json
{
  "mode": "file-specific",
  "targetFiles": [
    "./src/Services/PaymentService.cs",
    "./src/Services/AuthService.cs"
  ],
  "coverageGoal": 80,
  "timestamp": "2026-02-12T10:30:00Z"
}
```

### Step 2: Validate Target Files Exist

```powershell
# Locate actual file paths (user may only provide file name)
$projectRoot = Get-Location
$resolvedFiles = @()

foreach ($fileName in $targetFiles) {
    # Search for file in project
    $found = Get-ChildItem -Path $projectRoot -Recurse -Filter $fileName -File | 
             Where-Object { $_.FullName -notmatch 'bin|obj|TestResults' } |
             Select-Object -First 1
    
    if ($found) {
        $relativePath = $found.FullName.Replace($projectRoot, ".").Replace("\", "/")
        $resolvedFiles += $relativePath
        Write-Host "✅ Found: $relativePath" -ForegroundColor Green
    } else {
        Write-Warning "⚠️ File not found: $fileName"
    }
}

if ($resolvedFiles.Count -eq 0) {
    throw "ERROR: None of the specified files were found in the repository."
}

# Update workflow-state with resolved paths
& "./skills/scan-repository/scripts/Save-WorkflowMode.ps1" `
    -Mode "file-specific" `
    -TargetFiles $resolvedFiles `
    -CoverageGoal $coverageGoal
```

### Step 3: Build Targeted Type Registry

**Use Build-TypeRegistry.ps1 with -TargetFiles parameter**:
```powershell
# Build type registry for target files + their dependencies
$typeRegistry = & "./skills/scan-repository/scripts/Build-TypeRegistry.ps1" `
    -ProjectPath "./src" `
    -TargetFiles $resolvedFiles

# This creates a SMALLER type-registry.json with:
# - Target files' classes (marked isTarget = true)
# - Their direct dependencies (interfaces, other classes)
# - Excludes unrelated classes
```

**Example type-registry.json** (file-specific mode):
```json
{
  "PaymentService": {
    "filePath": "./src/Services/PaymentService.cs",
    "namespace": "MyApp.Services",
    "isTarget": true,
    "constructor": {
      "parameters": [
        {"type": "IPaymentRepository", "name": "repo"},
        {"type": "ILogger<PaymentService>", "name": "logger"}
      ]
    },
    "methods": ["ProcessPayment", "RefundPayment"],
    "isTestable": true,
    "skipReason": null
  },
  "IPaymentRepository": {
    "filePath": "./src/Repositories/IPaymentRepository.cs",
    "isInterface": true,
    "isTarget": false
  },
  "ILogger<PaymentService>": {
    "isFrameworkType": true,
    "isTarget": false
  },
  "AuthService": {
    "filePath": "./src/Services/AuthService.cs",
    "namespace": "MyApp.Services",
    "isTarget": true,
    "constructor": {
      "parameters": [
        {"type": "IAuthRepository", "name": "authRepo"}
      ]
    },
    "isTestable": true,
    "skipReason": null
  },
  "IAuthRepository": {
    "filePath": "./src/Repositories/IAuthRepository.cs",
    "isInterface": true,
    "isTarget": false
  }
}
```

### Step 4: Project Structure Analysis

**Same as full-repo mode**: Identify framework, packages, test infrastructure.

The only difference is the type registry is focused on target files.

### Step 5: Output Summary

```powershell
Write-Host "`n📊 File-Specific Scan Complete" -ForegroundColor Green
Write-Host "   Mode: FILE-SPECIFIC" -ForegroundColor Cyan
Write-Host "   Target files: $($resolvedFiles.Count)" -ForegroundColor Cyan
foreach ($file in $resolvedFiles) {
    Write-Host "     • $file" -ForegroundColor White
}
Write-Host "   Type registry: $($typeRegistry.Count) types discovered" -ForegroundColor Cyan
if ($coverageGoal) {
    Write-Host "   Coverage goal: $coverageGoal%" -ForegroundColor Cyan
}

Write-Host "`n✅ Workflow state saved to: TestResults/workflow-state.json" -ForegroundColor Green
Write-Host "   Next steps will automatically use file-specific mode." -ForegroundColor Gray
```

---

## Key Differences from Full Repo Mode

| Aspect | Full Repo Mode | File-Specific Mode |
|--------|----------------|-------------------|
| **Scan Time** | ~30-60 seconds | ~5-10 seconds |
| **Files Scanned** | All .cs files in project | Only specified files |
| **Type Registry Size** | 50-200+ classes | 5-20 classes (target + deps) |
| **Subsequent Steps** | Process all files | Process only targets |
| **Coverage Report** | Project-wide metrics | File-level + project impact |

---

## Integration with Subsequent Skills

All subsequent skills (analyze-coverage, plan-tests, generate-and-validate-tests, report-results) will:

1. **Read workflow-state.json** at the start
2. **Detect mode = "file-specific"**
3. **Filter operations** to only target files
4. **Use type-registry.json** as normal (already filtered)

**No extra changes needed** - the workflow state drives everything.

---

## Examples

### Example 1: Single File
**User**: "Generate tests for PaymentService.cs to reach 80% coverage"

**Execution**:
1. Parse: mode=file-specific, files=["PaymentService.cs"], goal=80
2. Locate: ./src/Services/PaymentService.cs
3. Build registry: PaymentService + IPaymentRepository + ILogger
4. Save state → analyze-coverage (file-filtered) → plan-tests (file-filtered) → generate

### Example 2: Multiple Files
**User**: "Add unit tests to AuthService.cs and UserService.cs"

**Execution**:
1. Parse: mode=file-specific, files=["AuthService.cs", "UserService.cs"]
2. Locate both files
3. Build registry: Both services + their dependencies
4. Save state → full workflow (file-filtered)

### Example 3: File Not Found
**User**: "Test PaymentServiceXXX.cs"

**Execution**:
1. Parse: mode=file-specific, files=["PaymentServiceXXX.cs"]
2. Search: ⚠️ File not found
3. **Fallback**: Ask user to clarify or list available files matching pattern

---

## Return to Main Workflow

After completing this targeted scan:
- **workflow-state.json** exists ✅
- **type-registry.json** exists (filtered) ✅
- **Next skill**: analyze-coverage (will auto-detect file-specific mode)

**Trigger**: Automatically proceed to Step 2 (analyze-coverage)
