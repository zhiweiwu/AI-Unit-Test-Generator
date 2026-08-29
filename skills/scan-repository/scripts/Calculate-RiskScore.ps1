<# 
.SYNOPSIS
    Calculates risk score for a C# file
.DESCRIPTION
    Analyzes complexity, dependencies, and patterns to calculate a risk priority score
.PARAMETER FilePath
    Path to the C# file to analyze
.EXAMPLE
    .\Calculate-RiskScore.ps1 -FilePath "./src/PaymentService.cs"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

if (-not (Test-Path $FilePath)) {
    throw "File not found: $FilePath"
}

$content = Get-Content $FilePath -Raw
$score = 0

# Cyclomatic complexity estimation (rough)
$ifCount = ([regex]::Matches($content, '\bif\s*\(')).Count
$switchCount = ([regex]::Matches($content, '\bswitch\s*\(')).Count
$forCount = ([regex]::Matches($content, '\b(for|foreach)\s*\(')).Count
$complexity = $ifCount + ($switchCount * 2) + $forCount
$score += $complexity * 2

# Dependency count (constructor parameters)
if ($content -match 'public\s+\w+\s*\(([^)]+)\)') {
    $params = $Matches[1].Split(',').Count
    $score += $params * 1.5
}

# Async operations
$asyncCount = ([regex]::Matches($content, '\basync\s+Task')).Count
$score += $asyncCount * 1.2

# External calls (HTTP, database, Service Bus)
if ($content -match 'HttpClient|ServiceBus|DbContext|IQueryable') {
    $score += 3
}

# Exception throws
$throwCount = ([regex]::Matches($content, '\bthrow\s+new')).Count
$score += $throwCount * 1.5

$finalScore = [Math]::Round($score, 0)

Write-Host "Risk score for $((Get-Item $FilePath).Name): $finalScore" -ForegroundColor $(
    if ($finalScore -gt 30) { "Red" }
    elseif ($finalScore -gt 20) { "Yellow" }
    elseif ($finalScore -gt 10) { "Cyan" }
    else { "Green" }
)

return $finalScore
