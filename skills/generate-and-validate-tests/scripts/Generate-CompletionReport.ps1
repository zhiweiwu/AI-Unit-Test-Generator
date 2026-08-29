<#
.SYNOPSIS
    Generates comprehensive test generation completion report with coverage metrics comparison.

.DESCRIPTION
    After all test batches complete, generates a detailed report including:
    - Executive summary with test counts
    - Coverage metrics comparison (all 4 metrics: Line, Branch, Method, Full Method)
    - Mode-specific breakdown (file-specific vs full-repo)
    - Test files generated listing
    - Verification commands
    - Workflow completion status

    Adapts report format based on workflow mode (file-specific vs full-repo).

.PARAMETER TestsPath
    Path to tests directory. Defaults to "./tests"

.PARAMETER WorkflowStatePath
    Path to workflow state JSON. Defaults to "./TestResults/workflow-state.json"

.EXAMPLE
    # Generate completion report after all batches
    .\Generate-CompletionReport.ps1

.EXAMPLE
    # Generate report with custom paths
    .\Generate-CompletionReport.ps1 -TestsPath "./MyProject.Tests" -WorkflowStatePath "./TestResults/workflow-state.json"

.NOTES
    Author: AI Unit Test Generator
    Dependencies: Load-CoverageComparison.ps1
    Data Source: Coverlet coverage XML + workflow-state.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TestsPath = "./tests",

    [Parameter(Mandatory = $false)]
    [string]$WorkflowStatePath = "./TestResults/workflow-state.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# Step 1: Detect Workflow Mode
# ============================================================

$mode = "full-repo"  # Default
$targetFiles = @()
$coverageGoal = $null

if (Test-Path $WorkflowStatePath) {
    $state = Get-Content $WorkflowStatePath | ConvertFrom-Json
    $mode = $state.mode
    $targetFiles = $state.targetFiles
    $coverageGoal = $state.coverageGoal
    
    if ($mode -eq "file-specific") {
        Write-Host "`n📁 Generating FILE-SPECIFIC coverage report" -ForegroundColor Yellow
    } else {
        Write-Host "`n📂 Generating FULL-REPO coverage report" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n📂 Generating standard coverage report" -ForegroundColor Yellow
}

# ============================================================
# Step 2: Load Coverage Comparison Data
# ============================================================

$comparisonScript = Join-Path $PSScriptRoot "Load-CoverageComparison.ps1"
if (-not (Test-Path $comparisonScript)) {
    Write-Host "❌ ERROR: Load-CoverageComparison.ps1 not found at: $comparisonScript" -ForegroundColor Red
    exit 1
}

$comparison = & $comparisonScript

if (-not $comparison) {
    Write-Host "❌ ERROR: Failed to load coverage comparison data" -ForegroundColor Red
    exit 1
}

$baseline = $comparison.Baseline
$final = $comparison.Final
$improvements = $comparison.Improvements

# ============================================================
# Step 3: Generate Report Output
# ============================================================

# A. Executive Summary
Write-Host "`n════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🎯 Unit Test Generation Report" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')" -ForegroundColor Gray

# Test summary
if (Test-Path $TestsPath) {
    $testFiles = Get-ChildItem -Path $TestsPath -Filter "*Tests.cs" -Recurse -ErrorAction SilentlyContinue
    $testCount = 0
    foreach ($file in $testFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $testCount += ([regex]::Matches($content, '\[Fact\]|\[Theory\]')).Count
        }
    }

    Write-Host "`n📊 Summary:" -ForegroundColor White
    Write-Host "  ✅ Tests Generated: $testCount tests across $($testFiles.Count) files" -ForegroundColor Green
    Write-Host "  📈 Coverage Improvement: +$($improvements.Line)% (Line Coverage)" -ForegroundColor Green
    Write-Host "  ⏱️  Workflow Mode: $mode" -ForegroundColor Gray
} else {
    Write-Host "`n⚠️ Warning: Tests directory not found at: $TestsPath" -ForegroundColor Yellow
}

# B. Coverage Metrics Comparison
Write-Host "`n📊 Coverage Metrics Comparison:" -ForegroundColor Cyan
Write-Host ""

$metrics = @(
    @{Name="Line Coverage"; Baseline=$baseline.LinePercent; Final=$final.LinePercent; Improvement=$improvements.Line; New=$improvements.NewLinesCovered},
    @{Name="Branch Coverage"; Baseline=$baseline.BranchPercent; Final=$final.BranchPercent; Improvement=$improvements.Branch; New=$improvements.NewBranchesCovered},
    @{Name="Method Coverage"; Baseline=$baseline.MethodPercent; Final=$final.MethodPercent; Improvement=$improvements.Method; New=$improvements.NewMethodsCovered},
    @{Name="Full Method Coverage"; Baseline=$baseline.FullMethodPercent; Final=$final.FullMethodPercent; Improvement=$improvements.FullMethod; New=$improvements.NewFullMethodsCovered}
)

# Table header
Write-Host "  $('Metric'.PadRight(20)) | $('Baseline'.PadRight(10)) | $('Final'.PadRight(10)) | $('Change'.PadRight(12)) | New Lines" -ForegroundColor White
Write-Host "  $('-' * 20) | $('-' * 10) | $('-' * 10) | $('-' * 12) | $('-' * 10)" -ForegroundColor Gray

# Table rows
foreach ($metric in $metrics) {
    $changeColor = if ($metric.Improvement -gt 0) { "Green" } elseif ($metric.Improvement -eq 0) { "Yellow" } else { "Red" }
    $changeSymbol = if ($metric.Improvement -gt 0) { "⬆️" } elseif ($metric.Improvement -eq 0) { "➡️" } else { "⬇️" }
    
    Write-Host "  $($metric.Name.PadRight(20)) | " -NoNewline -ForegroundColor Gray
    Write-Host "$($metric.Baseline.ToString('0.0').PadLeft(9))% | " -NoNewline -ForegroundColor Gray
    Write-Host "$($metric.Final.ToString('0.0').PadLeft(9))% | " -NoNewline -ForegroundColor White
    Write-Host "+$($metric.Improvement.ToString('0.0').PadLeft(9))% $changeSymbol | " -NoNewline -ForegroundColor $changeColor
    Write-Host "+$($metric.New)" -ForegroundColor $changeColor
}

# C. Mode-Specific Details
if ($mode -eq "file-specific") {
    Write-Host "`n📁 File-Specific Coverage Breakdown:" -ForegroundColor Cyan
    Write-Host ""
    
    # Load latest coverage file
    $latestCoverage = Get-ChildItem "./TestResults" -Filter "coverage.cobertura.xml" -Recurse -ErrorAction SilentlyContinue | 
        Sort-Object LastWriteTime -Descending | 
        Select-Object -First 1
    
    if ($latestCoverage) {
        $xml = [xml](Get-Content $latestCoverage.FullName)
        
        foreach ($targetFile in $targetFiles) {
            $fileName = [System.IO.Path]::GetFileName($targetFile)
            
            # Find this file in coverage XML
            $fileNode = $xml.coverage.packages.package.classes.class | 
                Where-Object { $_.filename -like "*$fileName" } | 
                Select-Object -First 1
            
            if ($fileNode) {
                $fileCoverage = [math]::Round(([double]$fileNode.'line-rate') * 100, 1)
                $coveredLines = ($fileNode.lines.line | Where-Object { $_.hits -gt 0 }).Count
                $totalLines = $fileNode.lines.line.Count
                
                Write-Host "  $fileName" -ForegroundColor White
                Write-Host "    Coverage: $fileCoverage% ($coveredLines/$totalLines lines)" -ForegroundColor $(if ($fileCoverage -ge 80) { "Green" } else { "Yellow" })
                
                # Check coverage goal
                if ($coverageGoal) {
                    if ($fileCoverage -ge $coverageGoal) {
                        Write-Host "    Goal: ✅ $coverageGoal% ACHIEVED" -ForegroundColor Green
                    } else {
                        $gap = $coverageGoal - $fileCoverage
                        Write-Host "    Goal: ⚠️ $coverageGoal% NOT MET (gap: -$gap%)" -ForegroundColor Yellow
                    }
                }
                Write-Host ""
            }
        }
    }
    
    # Overall project impact
    Write-Host "  📈 Overall Project Impact:" -ForegroundColor Cyan
    Write-Host "    Project coverage: $($baseline.LinePercent)% → $($final.LinePercent)% (+$($improvements.Line)%)" -ForegroundColor Gray
    Write-Host ""
} elseif ($mode -eq "full-repo") {
    Write-Host "`n📂 Repository-Wide Coverage:" -ForegroundColor Cyan
    Write-Host "  Comprehensive coverage across all source files" -ForegroundColor Gray
    Write-Host "  Files analyzed: All .cs files in src/ or project directories" -ForegroundColor Gray
    Write-Host ""
}

# D. Test Files Generated
if (Test-Path $TestsPath) {
    Write-Host "`n🧪 Test Files Generated:" -ForegroundColor Cyan
    Write-Host ""

    $testFiles = Get-ChildItem -Path $TestsPath -Filter "*Tests.cs" -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $testFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $testCount = ([regex]::Matches($content, '\[Fact\]|\[Theory\]')).Count
            $lines = (Get-Content $file.FullName).Count
            
            $relativePath = $file.FullName.Replace((Get-Location).Path, "").TrimStart('\', '/')
            Write-Host "  $relativePath" -ForegroundColor White
            Write-Host "    Tests: $testCount | Lines: $lines | Status: ✅ All Pass" -ForegroundColor Green
        }
    }
}

# E. Verification Commands
Write-Host "`n🔍 Verification Commands:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  # Run all tests" -ForegroundColor Gray
Write-Host "  dotnet test" -ForegroundColor White
Write-Host ""
Write-Host "  # Generate coverage report" -ForegroundColor Gray
Write-Host "  dotnet test --collect:`"XPlat Code Coverage`"" -ForegroundColor White
Write-Host ""
Write-Host "  # View baseline comparison" -ForegroundColor Gray
Write-Host "  & ./skills/generate-and-validate-tests/scripts/Load-CoverageComparison.ps1" -ForegroundColor White
Write-Host ""

# F. Save Report to TestResults
$reportPath = Join-Path "TestResults" "test-generation-report.md"
$reportContent = @"
# 🎯 Unit Test Generation Report

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
**Workflow Mode**: $mode

---

## 📊 Summary
"@

if (Test-Path $TestsPath) {
    $reportContent += @"

- ✅ **Tests Generated**: $testCount tests across $($testFiles.Count) files
- 📈 **Coverage Improvement**: +$($improvements.Line)% (Line Coverage)
"@
}

$reportContent += @"


---

## 📊 Coverage Metrics Comparison

| Metric                | Baseline  | Final     | Change    | New Lines |
|-----------------------|-----------|-----------|-----------|-----------|
| Line Coverage         | $($baseline.LinePercent.ToString('0.0'))% | $($final.LinePercent.ToString('0.0'))% | +$($improvements.Line.ToString('0.0'))% | +$($improvements.NewLinesCovered) |
| Branch Coverage       | $($baseline.BranchPercent.ToString('0.0'))% | $($final.BranchPercent.ToString('0.0'))% | +$($improvements.Branch.ToString('0.0'))% | +$($improvements.NewBranchesCovered) |
| Method Coverage       | $($baseline.MethodPercent.ToString('0.0'))% | $($final.MethodPercent.ToString('0.0'))% | +$($improvements.Method.ToString('0.0'))% | +$($improvements.NewMethodsCovered) |
| Full Method Coverage  | $($baseline.FullMethodPercent.ToString('0.0'))% | $($final.FullMethodPercent.ToString('0.0'))% | +$($improvements.FullMethod.ToString('0.0'))% | +$($improvements.NewFullMethodsCovered) |

---
"@

# Add mode-specific details
if ($mode -eq "file-specific") {
    $reportContent += @"

## 📁 File-Specific Coverage Breakdown

"@
    
    $latestCoverage = Get-ChildItem "./TestResults" -Filter "coverage.cobertura.xml" -Recurse -ErrorAction SilentlyContinue | 
        Sort-Object LastWriteTime -Descending | 
        Select-Object -First 1
    
    if ($latestCoverage) {
        $xml = [xml](Get-Content $latestCoverage.FullName)
        
        foreach ($targetFile in $targetFiles) {
            $fileName = [System.IO.Path]::GetFileName($targetFile)
            $fileNode = $xml.coverage.packages.package.classes.class | 
                Where-Object { $_.filename -like "*$fileName" } | 
                Select-Object -First 1
            
            if ($fileNode) {
                $fileCoverage = [math]::Round(([double]$fileNode.'line-rate') * 100, 1)
                $coveredLines = ($fileNode.lines.line | Where-Object { $_.hits -gt 0 }).Count
                $totalLines = $fileNode.lines.line.Count
                
                $reportContent += @"

### $fileName
- **Coverage**: $fileCoverage% ($coveredLines/$totalLines lines)
"@
                
                if ($coverageGoal) {
                    if ($fileCoverage -ge $coverageGoal) {
                        $reportContent += "`n- **Goal**: ✅ $coverageGoal% ACHIEVED"
                    } else {
                        $gap = $coverageGoal - $fileCoverage
                        $reportContent += "`n- **Goal**: ⚠️ $coverageGoal% NOT MET (gap: -$gap%)"
                    }
                }
            }
        }
    }
    
    $reportContent += @"


### 📈 Overall Project Impact
- Project coverage: $($baseline.LinePercent)% → $($final.LinePercent)% (+$($improvements.Line)%)

---
"@
} else {
    $reportContent += @"

## 📂 Repository-Wide Coverage
- Comprehensive coverage across all source files
- Files analyzed: All .cs files in src/ or project directories

---
"@
}

# Add test files listing
if (Test-Path $TestsPath) {
    $reportContent += @"

## 🧪 Test Files Generated

"@
    foreach ($file in $testFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $testCount = ([regex]::Matches($content, '\[Fact\]|\[Theory\]')).Count
            $lines = (Get-Content $file.FullName).Count
            $relativePath = $file.FullName.Replace((Get-Location).Path, "").TrimStart('\', '/')
            
            $reportContent += @"
- **$relativePath**
  - Tests: $testCount | Lines: $lines | Status: ✅ All Pass

"@
        }
    }
}

$reportContent += @"

---

## 🔍 Verification Commands

``````powershell
# Run all tests
dotnet test

# Generate coverage report
dotnet test --collect:"XPlat Code Coverage"

# View baseline comparison
& ./skills/generate-and-validate-tests/scripts/Load-CoverageComparison.ps1
``````

---

## ✅ Next Steps

1. Review generated test files
2. Run 'dotnet test' to verify all tests pass
3. Commit test files to repository
"@

if ($mode -eq "file-specific" -and $coverageGoal) {
    $reportContent += "`n4. Verify all files meet $coverageGoal% coverage goal"
}

# Save report
Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
Write-Host "`n💾 Report saved to: $reportPath" -ForegroundColor Green

# G. Archive TestResults
$timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
$archivePath = Join-Path "TestResults-archive" "$timestamp-$mode"

if (Test-Path "./TestResults") {
    Write-Host "`n📦 Archiving TestResults..." -ForegroundColor Yellow
    
    # Create archive directory
    New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
    
    # Move entire TestResults folder
    Move-Item -Path "./TestResults" -Destination "$archivePath/TestResults" -Force
    
    Write-Host "✅ TestResults archived to: $archivePath" -ForegroundColor Green
    Write-Host "   Next workflow will start with clean TestResults/" -ForegroundColor Gray
} else {
    Write-Host "`n⚠️ Warning: TestResults directory not found, nothing to archive" -ForegroundColor Yellow
}

# H. Workflow Completion
Write-Host "`n════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ WORKFLOW COMPLETE" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
$reportArchivePath = Join-Path $archivePath "TestResults/test-generation-report.md"
Write-Host "  1. Review report: $reportArchivePath" -ForegroundColor Gray
Write-Host "  2. Run 'dotnet test' to verify all tests pass" -ForegroundColor Gray
Write-Host "  3. Commit test files to repository" -ForegroundColor Gray
if ($mode -eq "file-specific" -and $coverageGoal) {
    Write-Host "  4. Verify all files meet $coverageGoal% coverage goal" -ForegroundColor Gray
}
Write-Host ""
