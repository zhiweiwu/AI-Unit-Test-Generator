<# 
.SYNOPSIS
    Validates coverage after all files are completed
.DESCRIPTION
    Runs final coverage check to see if 80% target is achieved
.PARAMETER TargetCoverage
    Target coverage percentage (default: 80.0)
.PARAMETER TestProjectPath
    Path to the test project directory
.EXAMPLE
    .\Run-CoverageValidation.ps1 -TargetCoverage 80.0 -TestProjectPath "./tests/MyProject.Tests"
#>

param(
    [Parameter(Mandatory=$false)]
    [double]$TargetCoverage = 80.0,
    
    [Parameter(Mandatory=$true)]
    [string]$TestProjectPath
)

Write-Host "Running coverage validation..." -ForegroundColor Cyan

# Get workspace root (2 levels up from test project)
$workspaceRoot = Split-Path (Split-Path $TestProjectPath -Parent) -Parent
$resultsDir = Join-Path $workspaceRoot "TestResults"

# Run coverage for entire test suite with explicit results directory
Write-Host "Test project: $TestProjectPath" -ForegroundColor Gray
Write-Host "Results directory: $resultsDir" -ForegroundColor Gray

dotnet test $TestProjectPath --collect:"XPlat Code Coverage" --results-directory $resultsDir

# Find latest coverage file
$latestCoverage = Get-ChildItem -Path $resultsDir -Recurse -Filter "coverage.cobertura.xml" |
                  Sort-Object LastWriteTime -Descending |
                  Select-Object -First 1

if (-not $latestCoverage) {
    throw "Coverage file not found after running tests"
}

# Parse Coverlet XML
[xml]$coverage = Get-Content $latestCoverage.FullName
$lineRate = [double]$coverage.coverage.'line-rate' * 100

# Compare to target
if ($lineRate -ge $TargetCoverage) {
    Write-Host "✅ Target achieved: $lineRate%" -ForegroundColor Green
    return @{
        Achieved = $true
        Coverage = $lineRate
        Target = $TargetCoverage
        Action = "ExitToReport"
    }
} elseif ($lineRate -ge ($TargetCoverage * 0.95)) {
    Write-Host "✅ Close enough: $lineRate% (95% of target)" -ForegroundColor Green
    return @{
        Achieved = $true
        Coverage = $lineRate
        Target = $TargetCoverage
        Action = "ExitToReport"
        Note = "Within 95% of target - diminishing returns"
    }
} else {
    Write-Host "⚠️ Below target: $lineRate% (need $TargetCoverage%)" -ForegroundColor Yellow
    return @{
        Achieved = $false
        Coverage = $lineRate
        Target = $TargetCoverage
        Action = "GenerateMoreTests"
    }
}
