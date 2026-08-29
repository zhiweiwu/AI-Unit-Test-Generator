<# 
.SYNOPSIS
    Verifies the integrity of coverage comparison data
.DESCRIPTION
    Validates baseline and final coverage data for accuracy and consistency
.PARAMETER ComparisonData
    The comparison data object from Load-CoverageComparison
.EXAMPLE
    $data = .\Load-CoverageComparison.ps1
    .\Verify-CoverageData.ps1 -ComparisonData $data
#>

param(
    [Parameter(Mandatory=$true)]
    [hashtable]$ComparisonData
)

Write-Host "Verifying coverage data integrity..." -ForegroundColor Cyan

$baseline = $ComparisonData.Baseline
$final = $ComparisonData.Final

# Verify data integrity
if ($baseline.LineRate -lt 0 -or $baseline.LineRate -gt 1) {
    throw "Invalid baseline line rate: $($baseline.LineRate) (expected 0.0-1.0)"
}

if ($final.LineRate -lt 0 -or $final.LineRate -gt 1) {
    throw "Invalid final line rate: $($final.LineRate) (expected 0.0-1.0)"
}

if ($final.LineRate -lt $baseline.LineRate) {
    Write-Warning "⚠️ Coverage DECREASED: $($final.LinePercent)% < $($baseline.LinePercent)%"
}

# Ensure we're comparing same codebase
if ($baseline.TotalLines -ne $final.TotalLines) {
    Write-Warning "⚠️ Total lines changed: $($baseline.TotalLines) → $($final.TotalLines) (codebase modified)"
}

Write-Host "✅ Coverage data verified" -ForegroundColor Green

return $true
