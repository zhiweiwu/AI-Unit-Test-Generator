<# 
.SYNOPSIS
    Loads baseline and final coverage data for comparison
.DESCRIPTION
    Loads locked baseline coverage and latest coverage for before/after comparison
    OPTIMIZED: Prioritizes metadata.json for baseline (fast), falls back to XML if needed
    DATA SOURCE: Locked baseline vs latest coverage (Coverlet XML ONLY - NO manual calculations)
.EXAMPLE
    .\Load-CoverageComparison.ps1
#>

Write-Host "Loading coverage data for comparison..." -ForegroundColor Cyan

# Load LOCKED baseline - METADATA FIRST (fast path)
$baselineDir = Join-Path "TestResults" "BASELINE"
$baselineMetaPath = Join-Path $baselineDir "metadata.json"
$baselineXmlPath = Join-Path $baselineDir "baseline.xml"

if (-not (Test-Path $baselineMetaPath)) {
    throw "ERROR: Baseline metadata not found. Ensure Step 2 (analyze-coverage) completed successfully."
}

# ✅ OPTIMIZATION: Read metadata.json first (it has all the metrics)
$baselineMeta = Get-Content $baselineMetaPath | ConvertFrom-Json

Write-Host "✅ Baseline metadata loaded (fast path)" -ForegroundColor Green
Write-Host "   Locked at: $($baselineMeta.Timestamp)" -ForegroundColor Cyan
Write-Host "   Source: metadata.json (pre-calculated metrics)" -ForegroundColor Gray

# Validate metadata has required fields
$requiredFields = @('LineCoveragePercent', 'BranchCoveragePercent', 'LinesCovered', 'LinesValid', 'BranchesCovered', 'BranchesValid')
$missingFields = $requiredFields | Where-Object { -not $baselineMeta.PSObject.Properties.Name.Contains($_) }

if ($missingFields.Count -gt 0) {
    Write-Warning "⚠️ Metadata incomplete (missing: $($missingFields -join ', ')). Falling back to XML parsing..."
    
    # ⚠️ FALLBACK: Parse baseline.xml if metadata is incomplete
    if (-not (Test-Path $baselineXmlPath)) {
        throw "ERROR: baseline.xml not found and metadata incomplete. Cannot proceed."
    }
    
    [xml]$baselineXml = Get-Content $baselineXmlPath
    $baselineLineRate = [double]$baselineXml.coverage.'line-rate'
    $baselineBranchRate = [double]$baselineXml.coverage.'branch-rate'
    $baselineLinePercent = [math]::Round($baselineLineRate * 100, 2)
    $baselineBranchPercent = [math]::Round($baselineBranchRate * 100, 2)
    $baselineCoveredLines = [int]$baselineXml.coverage.'lines-covered'
    $baselineTotalLines = [int]$baselineXml.coverage.'lines-valid'
    $baselineBranchesCovered = [int]$baselineXml.coverage.'branches-covered'
    $baselineBranchesValid = [int]$baselineXml.coverage.'branches-valid'
    
    Write-Host "✅ Baseline extracted from XML (slow path)" -ForegroundColor Yellow
} else {
    # ✅ FAST PATH: Use pre-calculated values from metadata
    $baselineLinePercent = $baselineMeta.LineCoveragePercent
    $baselineBranchPercent = $baselineMeta.BranchCoveragePercent
    $baselineCoveredLines = $baselineMeta.LinesCovered
    $baselineTotalLines = $baselineMeta.LinesValid
    $baselineBranchesCovered = $baselineMeta.BranchesCovered
    $baselineBranchesValid = $baselineMeta.BranchesValid
    $baselineLineRate = $baselineLinePercent / 100
    $baselineBranchRate = $baselineBranchPercent / 100
    
    Write-Host "   Using pre-calculated metrics (no XML parsing needed)" -ForegroundColor Gray
}

# Load FINAL coverage (must parse XML - no metadata exists yet for final run)
$finalCoverage = Get-ChildItem "./TestResults" -Recurse -Filter "coverage.cobertura.xml" |
                 Where-Object { $_.FullName -notmatch "BASELINE" } |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1

if (-not $finalCoverage) {
    throw "ERROR: No final coverage file found."
}

[xml]$finalXml = Get-Content $finalCoverage.FullName

Write-Host "✅ Final coverage loaded from: $($finalCoverage.FullName)" -ForegroundColor Green

# Extract metrics from final Coverlet XML (must parse - no metadata for final yet)
$finalLineRate = [double]$finalXml.coverage.'line-rate'
$finalBranchRate = [double]$finalXml.coverage.'branch-rate'
$finalLinePercent = [math]::Round($finalLineRate * 100, 2)
$finalBranchPercent = [math]::Round($finalBranchRate * 100, 2)
$finalCoveredLines = [int]$finalXml.coverage.'lines-covered'
$finalTotalLines = [int]$finalXml.coverage.'lines-valid'

# Calculate improvements
$lineImprovement = $finalLinePercent - $baselineLinePercent
$branchImprovement = $finalBranchPercent - $baselineBranchPercent
$newLinesCovered = $finalCoveredLines - $baselineCoveredLines

Write-Host "`n📊 Coverage Comparison:" -ForegroundColor Cyan
Write-Host "   Baseline Line: $baselineLinePercent%" -ForegroundColor White
Write-Host "   Final Line: $finalLinePercent%" -ForegroundColor White
Write-Host "   Improvement: +$lineImprovement%" -ForegroundColor Green
Write-Host "   New lines covered: $newLinesCovered" -ForegroundColor Green

# Return structured data
return @{
    Baseline = @{
        LineRate = $baselineLineRate
        BranchRate = $baselineBranchRate
        LinePercent = $baselineLinePercent
        BranchPercent = $baselineBranchPercent
        CoveredLines = $baselineCoveredLines
        TotalLines = $baselineTotalLines
        Metadata = $baselineMeta
    }
    Final = @{
        LineRate = $finalLineRate
        BranchRate = $finalBranchRate
        LinePercent = $finalLinePercent
        BranchPercent = $finalBranchPercent
        CoveredLines = $finalCoveredLines
        TotalLines = $finalTotalLines
        FilePath = $finalCoverage.FullName
    }
    Improvements = @{
        Line = $lineImprovement
        Branch = $branchImprovement
        NewLinesCovered = $newLinesCovered
    }
}
