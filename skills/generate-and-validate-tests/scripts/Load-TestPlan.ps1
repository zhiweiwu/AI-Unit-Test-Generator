<# 
.SYNOPSIS
    Loads and parses the test generation plan
.DESCRIPTION
    Reads the test-generation-plan.md file and extracts the priority-ordered class list
.PARAMETER PlanFilePath
    Path to the test generation plan markdown file
.EXAMPLE
    .\Load-TestPlan.ps1 -PlanFilePath "TestResults/test-generation-plan.md"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$PlanFilePath = "TestResults/test-generation-plan.md"
)

if (-not (Test-Path $PlanFilePath)) {
    throw "Test plan file not found at: $PlanFilePath"
}

# Read test plan (created by plan-tests skill)
$plan = Get-Content $PlanFilePath -Raw

Write-Host "✅ Test plan loaded from: $PlanFilePath" -ForegroundColor Green

# Extract priority-ordered class list
# Example: PaymentService (Risk: 35, Priority: CRITICAL, Tests: 28)

# Return the plan content for further processing
return $plan
