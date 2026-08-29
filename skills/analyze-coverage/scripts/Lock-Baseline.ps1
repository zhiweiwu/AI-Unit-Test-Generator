<# 
.SYNOPSIS
    Locks the baseline coverage for before/after comparison
.DESCRIPTION
    Saves baseline coverage XML and metadata to BASELINE folder
    STRICT RULES: Save ONLY ONCE, never overwrite, use ONLY Coverlet XML data
.PARAMETER CoverageXmlPath
    Path to the current coverage.cobertura.xml file
.EXAMPLE
    .\Lock-Baseline.ps1 -CoverageXmlPath "./TestResults/coverage.cobertura.xml"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CoverageXmlPath,

    [Parameter(Mandatory=$false)]
    [string]$TestResultsDir = "./TestResults"
)

if (-not (Test-Path $CoverageXmlPath)) {
    throw "Coverage XML file not found: $CoverageXmlPath"
}

Write-Host "Locking baseline coverage..." -ForegroundColor Cyan

$baselineDir = Join-Path $TestResultsDir "BASELINE"

# Check if baseline already exists
if (Test-Path $baselineDir) {
    Write-Host "Baseline already exists - preserving original" -ForegroundColor Yellow
    $existingMeta = Get-Content (Join-Path $baselineDir "metadata.json") | ConvertFrom-Json
    Write-Host "   Locked at: $($existingMeta.Timestamp)" -ForegroundColor Cyan
    Write-Host "   Overall Coverage: $($existingMeta.OverallCoveragePercent)%" -ForegroundColor Cyan
    Write-Host "   Line Coverage: $($existingMeta.LineCoveragePercent)%" -ForegroundColor Cyan
    Write-Host "   Branch Coverage: $($existingMeta.BranchCoveragePercent)%" -ForegroundColor Cyan
    Write-Host "   Method Coverage: $($existingMeta.MethodCoveragePercent)%" -ForegroundColor Cyan
    Write-Host "   Full Method Coverage: $($existingMeta.FullMethodCoveragePercent)%" -ForegroundColor Cyan
    return $existingMeta
}

# Create baseline directory
New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null

# Copy coverage XML to locked location
$baselineXmlPath = Join-Path $baselineDir "baseline.xml"
Copy-Item $CoverageXmlPath $baselineXmlPath -Force

# Parse all metrics from Coverlet XML
[xml]$coverageXml = Get-Content $CoverageXmlPath
$lineRate = [double]$coverageXml.coverage.'line-rate'
$branchRate = [double]$coverageXml.coverage.'branch-rate'
$linesCovered = [int]$coverageXml.coverage.'lines-covered'
$linesValid = [int]$coverageXml.coverage.'lines-valid'
$branchesCovered = [int]$coverageXml.coverage.'branches-covered'
$branchesValid = [int]$coverageXml.coverage.'branches-valid'

# Calculate method-level metrics
$allMethods = $coverageXml.coverage.packages.package.classes.class.methods.method
$totalMethods = $allMethods.Count
$methodsWithCoverage = ($allMethods | Where-Object { [double]$_.'line-rate' -gt 0 }).Count
$methodsFullyCovered = ($allMethods | Where-Object { 
    ([double]$_.'line-rate' -eq 1.0) -and ([double]$_.'branch-rate' -eq 1.0)
}).Count

$methodCoverage = if ($totalMethods -gt 0) { ($methodsWithCoverage / $totalMethods) * 100 } else { 0 }
$fullMethodCoverage = if ($totalMethods -gt 0) { ($methodsFullyCovered / $totalMethods) * 100 } else { 0 }

# Create metadata file with ALL 5 metrics
$metadata = @{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    CoverageDate = $coverageXml.coverage.timestamp
    OverallCoveragePercent = [math]::Round($lineRate * 100, 1)
    LineCoveragePercent = [math]::Round($lineRate * 100, 1)
    BranchCoveragePercent = [math]::Round($branchRate * 100, 1)
    MethodCoveragePercent = [math]::Round($methodCoverage, 1)
    FullMethodCoveragePercent = [math]::Round($fullMethodCoverage, 1)
    LinesCovered = $linesCovered
    LinesValid = $linesValid
    BranchesCovered = $branchesCovered
    BranchesValid = $branchesValid
    MethodsCovered = $methodsWithCoverage
    MethodsFullyCovered = $methodsFullyCovered
    TotalMethods = $totalMethods
    LockedBy = "analyze-coverage skill"
    LockedAt = $PWD.Path
    CoverageFile = $CoverageXmlPath
}

$metadataPath = Join-Path $baselineDir "metadata.json"
$metadata | ConvertTo-Json | Out-File $metadataPath -Encoding UTF8

Write-Host "Baseline locked with ALL 5 metrics:" -ForegroundColor Green
Write-Host "   Overall: $([math]::Round($lineRate * 100, 1))%" -ForegroundColor White
Write-Host "   Line: $([math]::Round($lineRate * 100, 1))%" -ForegroundColor White
Write-Host "   Branch: $([math]::Round($branchRate * 100, 1))%" -ForegroundColor White
Write-Host "   Method: $([math]::Round($methodCoverage, 1))%" -ForegroundColor White
Write-Host "   Full Method: $([math]::Round($fullMethodCoverage, 1))%" -ForegroundColor White

return $metadata
