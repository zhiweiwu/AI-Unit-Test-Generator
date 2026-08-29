<# 
.SYNOPSIS
    Loads the current workflow state
.DESCRIPTION
    Reads the workflow-state.json file to track progress through test generation
.PARAMETER StateFilePath
    Path to the workflow state JSON file
.EXAMPLE
    .\Load-WorkflowState.ps1 -StateFilePath "TestResults/workflow-state.json"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$StateFilePath = "TestResults/workflow-state.json"
)

if (-not (Test-Path $StateFilePath)) {
    Write-Warning "Workflow state file not found. Creating new state."
    $state = @{
        completedClasses = @()
        currentFile = $null
        currentCheckpoint = 0
        totalCheckpoints = 0
        filesCompleted = @()
        totalGenerated = 0
        currentCoverage = 0.0
        lastUpdate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    $state | ConvertTo-Json | Out-File $StateFilePath -Encoding UTF8
    Write-Host "✅ Created new workflow state at: $StateFilePath" -ForegroundColor Green
    return $state
}

# Load workflow state
$state = Get-Content $StateFilePath | ConvertFrom-Json

Write-Host "✅ Workflow state loaded from: $StateFilePath" -ForegroundColor Green
Write-Host "   Completed classes: $($state.completedClasses.Count)" -ForegroundColor Cyan
Write-Host "   Total generated: $($state.totalGenerated)" -ForegroundColor Cyan
Write-Host "   Current coverage: $($state.currentCoverage)%" -ForegroundColor Cyan

return $state
