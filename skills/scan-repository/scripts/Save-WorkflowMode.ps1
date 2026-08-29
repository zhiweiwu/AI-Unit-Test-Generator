<# 
.SYNOPSIS
    Saves workflow mode and scope to persistent state file
.DESCRIPTION
    Creates TestResults/workflow-state.json to persist mode decision across all skills
    This ensures subsequent skills know whether to process full repo or specific files
.PARAMETER Mode
    Workflow mode: "full-repo" or "file-specific"
.PARAMETER TargetFiles
    Array of target file paths (optional, only for file-specific mode)
.PARAMETER CoverageGoal
    Target coverage percentage (optional)
.EXAMPLE
    .\Save-WorkflowMode.ps1 -Mode "full-repo"
.EXAMPLE
    .\Save-WorkflowMode.ps1 -Mode "file-specific" -TargetFiles @("./src/PaymentService.cs") -CoverageGoal 80
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("full-repo", "file-specific")]
    [string]$Mode,
    
    [Parameter(Mandatory=$false)]
    [string[]]$TargetFiles,
    
    [Parameter(Mandatory=$false)]
    [int]$CoverageGoal,

    [Parameter(Mandatory=$false)]
    [string]$TestResultsDir = "./TestResults"
)

Write-Host "Saving workflow state..." -ForegroundColor Cyan

# Validate parameters
if ($Mode -eq "file-specific" -and (-not $TargetFiles -or $TargetFiles.Count -eq 0)) {
    throw "ERROR: file-specific mode requires TargetFiles parameter"
}

# Create TestResults directory if not exists
$testResultsDir = $TestResultsDir
if (-not (Test-Path $testResultsDir)) {
    New-Item -ItemType Directory -Path $testResultsDir | Out-Null
}

# Build state object
$state = @{
    mode = $Mode
    timestamp = (Get-Date).ToString("o")
}

if ($Mode -eq "file-specific") {
    $state.targetFiles = $TargetFiles
    
    if ($CoverageGoal) {
        $state.coverageGoal = $CoverageGoal
    }
}

# Save to JSON
$statePath = Join-Path $testResultsDir "workflow-state.json"
$state | ConvertTo-Json -Depth 10 | Out-File $statePath -Encoding UTF8

Write-Host "✅ Workflow state saved" -ForegroundColor Green
Write-Host "   Mode: $Mode" -ForegroundColor Cyan
if ($Mode -eq "file-specific") {
    Write-Host "   Target files: $($TargetFiles.Count)" -ForegroundColor Cyan
    foreach ($file in $TargetFiles) {
        Write-Host "     • $file" -ForegroundColor Gray
    }
    if ($CoverageGoal) {
        Write-Host "   Coverage goal: $CoverageGoal%" -ForegroundColor Cyan
    }
}
Write-Host "   Saved to: $statePath" -ForegroundColor Gray

return $state
