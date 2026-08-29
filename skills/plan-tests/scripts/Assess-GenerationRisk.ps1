<# 
.SYNOPSIS
    Assesses the risk level of test generation based on planned test count
.DESCRIPTION
    Calculates risk level (LOW/MEDIUM/HIGH) and estimates batch count based on the number of planned tests.
    Uses dynamic batch sizing: starts at 10, scales to max 15 based on success rate.
.PARAMETER PlannedTestCount
    The number of tests planned to be generated
.EXAMPLE
    .\Assess-GenerationRisk.ps1 -PlannedTestCount 82
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$PlannedTestCount
)

# Dynamic batch sizing: Start=10, scales to Max=15 based on success rate
# See generate-unit-tests/SKILL.md for full algorithm
$initialBatchSize = 10
$maxBatchSize = 15

$riskLevel = switch ($PlannedTestCount) {
    {$_ -le 20} { "LOW" }
    {$_ -le 50} { "MEDIUM" }
    default { "HIGH" }
}

# Calculate estimated batches (conservative: assumes no scaling up)
$estimatedBatches = [Math]::Ceiling($PlannedTestCount / $initialBatchSize)

$message = switch ($riskLevel) {
    "LOW" {
        "✅ Low risk: $PlannedTestCount tests planned. Safe for automatic generation."
    }
    "MEDIUM" {
        "⚠️ Medium risk: $PlannedTestCount tests planned. Will generate in ~$estimatedBatches batches (starting at $initialBatchSize, scaling to max $maxBatchSize)."
    }
    "HIGH" {
        "🚨 High risk: $PlannedTestCount tests planned. Will generate in ~$estimatedBatches batches (starting at $initialBatchSize, scaling to max $maxBatchSize).
        
        Consider:
        - Approving only high-priority tests first (reduce count)
        - Reviewing testability flags
        - Expected time: ~$($estimatedBatches * 2) minutes (with potential speedup as batch size scales)
        
        Recommendation: Start with 20-30 tests, then iterate."
    }
}

Write-Host $message

# Return structured object for programmatic use
return @{
    RiskLevel = $riskLevel
    PlannedTestCount = $PlannedTestCount
    InitialBatchSize = $initialBatchSize
    MaxBatchSize = $maxBatchSize
    EstimatedBatches = $estimatedBatches
    EstimatedMinutes = $estimatedBatches * 2
}
