<# 
.SYNOPSIS
    Calculates all 5 coverage metrics from Coverlet XML
.DESCRIPTION
    Parses coverage.cobertura.xml and calculates: Overall, Line, Branch, Method, and Full Method coverage
    STRICT: Uses only actual Coverlet data, NO manual calculations or estimates
.PARAMETER CoverageXmlPath
    Path to the coverage.cobertura.xml file
.EXAMPLE
    .\Calculate-CoverageMetrics.ps1 -CoverageXmlPath "./TestResults/coverage.cobertura.xml"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CoverageXmlPath
)

if (-not (Test-Path $CoverageXmlPath)) {
    throw "Coverage XML file not found: $CoverageXmlPath"
}

Write-Host "Calculating coverage metrics from: $CoverageXmlPath" -ForegroundColor Cyan

# Parse Coverlet XML
[xml]$xml = Get-Content $CoverageXmlPath

# Extract root-level metrics
$lineRate = [double]$xml.coverage.'line-rate'
$branchRate = [double]$xml.coverage.'branch-rate'
$linesCovered = [int]$xml.coverage.'lines-covered'
$linesValid = [int]$xml.coverage.'lines-valid'
$branchesCovered = [int]$xml.coverage.'branches-covered'
$branchesValid = [int]$xml.coverage.'branches-valid'

# Extract all methods
$allMethods = $xml.coverage.packages.package.classes.class.methods.method
$totalMethods = $allMethods.Count

# Calculate Method Coverage (any method with line-rate > 0)
$methodsWithCoverage = ($allMethods | Where-Object { 
    [double]$_.'line-rate' -gt 0 
}).Count
$methodCoverage = if ($totalMethods -gt 0) { 
    ($methodsWithCoverage / $totalMethods) * 100 
} else { 0 }

# Calculate Full Method Coverage (BOTH line-rate=1.0 AND branch-rate=1.0)
# ⚠️ CRITICAL: Must check BOTH conditions to avoid false positives
$methodsFullyCovered = ($allMethods | Where-Object { 
    ([double]$_.'line-rate' -eq 1.0) -and ([double]$_.'branch-rate' -eq 1.0)
}).Count
$fullMethodCoverage = if ($totalMethods -gt 0) { 
    ($methodsFullyCovered / $totalMethods) * 100 
} else { 0 }

# Calculate percentages
$overallCoverage = [math]::Round($lineRate * 100, 1)  # Same as Line Coverage
$lineCoverage = [math]::Round($lineRate * 100, 1)
$branchCoverage = [math]::Round($branchRate * 100, 1)
$methodCoveragePercent = [math]::Round($methodCoverage, 1)
$fullMethodCoveragePercent = [math]::Round($fullMethodCoverage, 1)

# Display results
Write-Host "`nCoverage Metrics:" -ForegroundColor Green
Write-Host "  Overall Coverage: $overallCoverage%" -ForegroundColor White
Write-Host "  Line Coverage: $lineCoverage% ($linesCovered / $linesValid lines covered)" -ForegroundColor White
Write-Host "  Branch Coverage: $branchCoverage% ($branchesCovered / $branchesValid branches covered)" -ForegroundColor White
Write-Host "  Method Coverage: $methodCoveragePercent% ($methodsWithCoverage / $totalMethods methods covered)" -ForegroundColor White
Write-Host "  Full Method Coverage: $fullMethodCoveragePercent% ($methodsFullyCovered / $totalMethods methods fully covered)" -ForegroundColor White

# Return structured object
return @{
    OverallCoverage = $overallCoverage
    LineCoverage = $lineCoverage
    BranchCoverage = $branchCoverage
    MethodCoverage = $methodCoveragePercent
    FullMethodCoverage = $fullMethodCoveragePercent
    LinesCovered = $linesCovered
    LinesValid = $linesValid
    BranchesCovered = $branchesCovered
    BranchesValid = $branchesValid
    MethodsCovered = $methodsWithCoverage
    MethodsFullyCovered = $methodsFullyCovered
    TotalMethods = $totalMethods
}
