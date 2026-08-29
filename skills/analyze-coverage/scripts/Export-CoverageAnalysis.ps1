<# 
.SYNOPSIS
    Exports comprehensive coverage analysis to JSON file for use by subsequent skills
.DESCRIPTION
    Combines coverage metrics, risk scores, edge cases, and uncovered methods into a single
    coverage-analysis.json file that can be consumed by plan-tests skill.
    
    This ensures data persistence across Copilot sessions and provides a clear contract
    between analyze-coverage and plan-tests skills.
.PARAMETER CoverageXmlPath
    Path to the coverage.cobertura.xml file. Defaults to latest GUID folder.
.PARAMETER TypeRegistryPath
    Path to type-registry.json. Defaults to ./TestResults/type-registry.json
.PARAMETER OutputPath
    Path to save coverage-analysis.json. Defaults to ./TestResults/coverage-analysis.json
.EXAMPLE
    .\Export-CoverageAnalysis.ps1
.EXAMPLE
    .\Export-CoverageAnalysis.ps1 -CoverageXmlPath "./TestResults/abc123/coverage.cobertura.xml"
.NOTES
    Author: AI Unit Test Generator
    Dependencies: Calculate-CoverageMetrics.ps1, type-registry.json
    Data Source: Coverlet XML + Type Registry
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$TestResultsDir = "./TestResults",

    [Parameter(Mandatory=$false)]
    [string]$CoverageXmlPath = $null,
    
    [Parameter(Mandatory=$false)]
    [string]$TypeRegistryPath = $null,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = $null
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve defaults from TestResultsDir
if (-not $TypeRegistryPath) { $TypeRegistryPath = "$TestResultsDir/type-registry.json" }
if (-not $OutputPath)       { $OutputPath = "$TestResultsDir/coverage-analysis.json" }

Write-Host "`n?? Exporting Coverage Analysis..." -ForegroundColor Cyan

# ============================================================
# Step 1: Locate Coverage XML
# ============================================================

if (-not $CoverageXmlPath) {
    # Find latest coverage file (exclude BASELINE)
    $coverageFile = Get-ChildItem $TestResultsDir -Recurse -Filter "coverage.cobertura.xml" -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notmatch "BASELINE" } |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
    
    if (-not $coverageFile) {
        throw "ERROR: No coverage file found in $TestResultsDir. Run 'dotnet test --collect:`"XPlat Code Coverage`"' first."
    }
    
    $CoverageXmlPath = $coverageFile.FullName
}

if (-not (Test-Path $CoverageXmlPath)) {
    throw "ERROR: Coverage XML not found at: $CoverageXmlPath"
}

Write-Host "? Using coverage file: $CoverageXmlPath" -ForegroundColor Gray

# ============================================================
# Step 2: Load Baseline Coverage Metrics
# ============================================================

$baselineMetadataPath = "$TestResultsDir/BASELINE/metadata.json"
if (-not (Test-Path $baselineMetadataPath)) {
    throw "ERROR: Baseline metadata not found at: $baselineMetadataPath. Run Lock-Baseline.ps1 first."
}

$baselineMetrics = Get-Content $baselineMetadataPath -Raw | ConvertFrom-Json
$baselinePercent = $baselineMetrics.OverallCoveragePercent
Write-Host "✓ Baseline metrics loaded ($baselinePercent`%)" -ForegroundColor Green

# ============================================================
# Step 3: Calculate Current Coverage Metrics
# ============================================================

$metricsScript = Join-Path $PSScriptRoot "Calculate-CoverageMetrics.ps1"
if (-not (Test-Path $metricsScript)) {
    throw "ERROR: Calculate-CoverageMetrics.ps1 not found at: $metricsScript"
}

$currentMetrics = & $metricsScript -CoverageXmlPath $CoverageXmlPath

if (-not $currentMetrics) {
    throw "ERROR: Failed to calculate coverage metrics"
}

$currentPercent = $currentMetrics.LineCoverage
Write-Host "✓ Current coverage metrics calculated ($currentPercent`%)" -ForegroundColor Green

# ============================================================
# Step 4: Load Type Registry
# ============================================================

if (-not (Test-Path $TypeRegistryPath)) {
    throw "ERROR: Type registry not found at: $TypeRegistryPath. Run scan-repository skill first."
}

$typeRegistry = Get-Content $TypeRegistryPath -Raw | ConvertFrom-Json
Write-Host "? Type registry loaded" -ForegroundColor Green

# ============================================================
# Step 5: Parse Coverage XML for Method-Level Details
# ============================================================

[xml]$coverageXml = Get-Content $CoverageXmlPath

$uncoveredMethods = @()
$partiallyTestedMethods = @()
$fullyCoveredMethods = @()

foreach ($package in $coverageXml.coverage.packages.package) {
    foreach ($class in $package.classes.class) {
        $className = ($class.name -split '\.')[-1]  # Get class name without namespace
        
        # Check if class is in type registry and testable
        $typeInfo = $typeRegistry.PSObject.Properties[$className]
        if (-not $typeInfo) { continue }  # Skip classes not in registry
        
        $classValue = $typeInfo.Value
        if (-not $classValue.isTestable) { continue }  # Skip non-testable classes
        
        foreach ($method in $class.methods.method) {
            $methodName = $method.name
            $lineRate = [double]$method.'line-rate'
            $branchRate = [double]$method.'branch-rate'
            
            # Handle nullable lines property
            $lines = @($method.lines.line)
            $linesCovered = @($lines | Where-Object { [int]$_.hits -gt 0 }).Count
            $totalLines = $lines.Count
            
            $methodData = @{
                className = $className
                methodName = $methodName
                lineCoverage = [math]::Round($lineRate * 100, 1)
                branchCoverage = [math]::Round($branchRate * 100, 1)
                linesCovered = $linesCovered
                totalLines = $totalLines
            }
            
            # Categorize by coverage status
            if ($lineRate -eq 0) {
                $uncoveredMethods += $methodData
            } elseif ($lineRate -eq 1.0 -and $branchRate -eq 1.0) {
                $fullyCoveredMethods += $methodData
            } else {
                $uncoveredBranchCount = @($lines | Where-Object { [int]$_.hits -eq 0 }).Count
                $methodData['uncoveredBranches'] = $uncoveredBranchCount
                $partiallyTestedMethods += $methodData
            }
        }
    }
}

Write-Host "? Method-level coverage analyzed" -ForegroundColor Green
Write-Host "   Uncovered: $(@($uncoveredMethods).Count) methods" -ForegroundColor Gray
Write-Host "   Partial: $(@($partiallyTestedMethods).Count) methods" -ForegroundColor Gray
Write-Host "   Full: $(@($fullyCoveredMethods).Count) methods" -ForegroundColor Gray

# ============================================================
# Step 6: Calculate Risk Scores
# ============================================================

Write-Host "`n?? Calculating risk scores..." -ForegroundColor Cyan

$riskScores = @()

# Combine uncovered and partially tested methods for risk scoring
$methodsToScore = $uncoveredMethods + $partiallyTestedMethods

foreach ($method in $methodsToScore) {
    $className = $method.className
    $methodName = $method.methodName
    
    # Get type info from registry
    $typeInfo = $typeRegistry.PSObject.Properties[$className]
    if (-not $typeInfo) { continue }
    
    $classValue = $typeInfo.Value
    
    # Calculate complexity (estimate from line count)
    $complexity = [math]::Max(1, [math]::Floor($method.totalLines / 3))
    
    # Count dependencies from constructor
    $dependencies = 0
    if ($classValue.constructor -and $classValue.constructor -is [string]) {
        $dependencies = ([regex]::Matches($classValue.constructor, ',').Count) + 1
    }
    
    # Detect async operations (method name ends with Async)
    $asyncOps = if ($methodName -like "*Async") { 1 } else { 0 }
    
    # Detect external calls (heuristic - methods with certain patterns)
    $externalCalls = 0
    if ($methodName -match "Process|Send|Post|Get|Call|Invoke|Execute") {
        $externalCalls = 1
    }
    
    # Detect exception handling (estimate)
    $exceptionThrows = if ($complexity -gt 5) { 1 } else { 0 }
    
    # Current coverage
    $currentCoverage = $method.lineCoverage
    
    # Calculate risk score
    $riskScore = ($complexity * 2) + 
                 ($dependencies * 1.5) + 
                 ($asyncOps * 1.2) + 
                 ($externalCalls * 3) + 
                 ($exceptionThrows * 1.5) - 
                 ($currentCoverage * 0.5)
    
    # Determine priority
    $priority = if ($riskScore -gt 30) { "CRITICAL" }
                elseif ($riskScore -gt 20) { "HIGH" }
                elseif ($riskScore -gt 10) { "MEDIUM" }
                else { "LOW" }
    
    $riskScores += @{
        className = $className
        method = $methodName
        riskScore = [math]::Round($riskScore, 1)
        priority = $priority
        complexity = $complexity
        dependencies = $dependencies
        asyncOps = $asyncOps
        externalCalls = $externalCalls
        currentCoverage = $currentCoverage
    }
}

# Sort by risk score (highest first)
$riskScores = $riskScores | Sort-Object { $_.riskScore } -Descending

Write-Host "? Risk scores calculated for @($riskScores).Count methods" -ForegroundColor Green

# ============================================================
# Step 7: Detect Edge Cases (Simplified)
# ============================================================

Write-Host "`n?? Detecting edge cases..." -ForegroundColor Cyan

# Load edge case detector configuration if exists
$edgeCaseConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "analyzers/edge-case-detector.json"
$edgeCasePatterns = @{
    nullHandling = @()
    boundaryConditions = @()
    exceptionPaths = @()
    asyncCancellation = @()
}

# Simple edge case detection based on method characteristics
foreach ($method in $methodsToScore) {
    $methodName = $method.methodName
    $className = $method.className
    
    # Get type info from registry for dependency check
    $typeInfo = $typeRegistry.PSObject.Properties[$className]
    $hasDependencies = $false
    if ($typeInfo) {
        $classValue = $typeInfo.Value
        if ($classValue.constructor -and $classValue.constructor -is [string]) {
            $hasDependencies = $classValue.constructor.Contains(',') -or $classValue.constructor.Length -gt 10
        }
    }
    
    # Null handling (methods with parameters likely need null checks)
    if ($hasDependencies) {
        $edgeCasePatterns.nullHandling += @{
            method = "$className.$methodName"
            testScenario = "${methodName}_NullParameter_ThrowsArgumentNullException"
        }
    }
    
    # Boundary conditions (methods with numeric operations)
    if ($methodName -match "Calculate|Process|Validate|Convert") {
        $edgeCasePatterns.boundaryConditions += @{
            method = "$className.$methodName"
            testScenario = "${methodName}_BoundaryValue_HandledCorrectly"
        }
    }
    
    # Exception paths (complex methods likely throw exceptions)
    $complexity = [math]::Max(1, [math]::Floor($method.totalLines / 3))
    if ($complexity -gt 3) {
        $edgeCasePatterns.exceptionPaths += @{
            method = "$className.$methodName"
            testScenario = "${methodName}_ExceptionCondition_HandlesGracefully"
        }
    }
    
    # Async cancellation (async methods)
    $isAsync = $methodName -like "*Async"
    if ($isAsync) {
        $edgeCasePatterns.asyncCancellation += @{
            method = "$className.$methodName"
            testScenario = "${methodName}_Cancelled_ThrowsOperationCanceledException"
        }
    }
}

Write-Host "? Edge cases detected" -ForegroundColor Green
Write-Host "   Null handling: $($edgeCasePatterns.nullHandling.Count)" -ForegroundColor Gray
Write-Host "   Boundaries: $($edgeCasePatterns.boundaryConditions.Count)" -ForegroundColor Gray
Write-Host "   Exceptions: $($edgeCasePatterns.exceptionPaths.Count)" -ForegroundColor Gray
Write-Host "   Async: $($edgeCasePatterns.asyncCancellation.Count)" -ForegroundColor Gray

# ============================================================
# Step 8: Build Coverage Analysis JSON
# ============================================================

Write-Host "`n?? Building coverage analysis output..." -ForegroundColor Cyan

# Get project name from coverage XML (handle single or multiple packages)
$packages = @($coverageXml.coverage.packages.package)
$projectName = if ($packages.Count -gt 0 -and $packages[0].name) { 
    $packages[0].name 
} else { 
    "Unknown Project" 
}

$coverageAnalysis = @{
    timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    projectName = $projectName
    
    baseline = @{
        lineCoverage = $baselineMetrics.LineCoveragePercent
        branchCoverage = $baselineMetrics.BranchCoveragePercent
        methodCoverage = $baselineMetrics.MethodCoveragePercent
        fullMethodCoverage = $baselineMetrics.FullMethodCoveragePercent
    }
    
    current = @{
        lineCoverage = $currentMetrics.LineCoverage
        branchCoverage = $currentMetrics.BranchCoverage
        methodCoverage = $currentMetrics.MethodCoverage
        fullMethodCoverage = $currentMetrics.FullMethodCoverage
    }
    
    target = @{
        lineCoverage = 70.0
        branchCoverage = 70.0
        methodCoverage = 80.0
        fullMethodCoverage = 60.0
    }
    
    gap = @{
        lineCoverage = [math]::Max(0, 70.0 - $currentMetrics.LineCoverage)
        branchCoverage = [math]::Max(0, 70.0 - $currentMetrics.BranchCoverage)
        methodCoverage = [math]::Max(0, 80.0 - $currentMetrics.MethodCoverage)
        fullMethodCoverage = [math]::Max(0, 60.0 - $currentMetrics.FullMethodCoverage)
    }
    
    improvement = @{
        lineCoverage = [math]::Round($currentMetrics.LineCoverage - $baselineMetrics.LineCoveragePercent, 1)
        branchCoverage = [math]::Round($currentMetrics.BranchCoverage - $baselineMetrics.BranchCoveragePercent, 1)
        methodCoverage = [math]::Round($currentMetrics.MethodCoverage - $baselineMetrics.MethodCoveragePercent, 1)
        fullMethodCoverage = [math]::Round($currentMetrics.FullMethodCoverage - $baselineMetrics.FullMethodCoveragePercent, 1)
    }
    
    uncoveredMethods = $uncoveredMethods
    partiallyTestedMethods = $partiallyTestedMethods
    fullyCoveredMethods = $fullyCoveredMethods
    
    riskScores = $riskScores
    
    edgeCases = $edgeCasePatterns
    
    riskAssessment = @{
        critical = @(@($riskScores | Where-Object { $_.priority -eq "CRITICAL" } | ForEach-Object { "$($_.className).$($_.method)" }))
        high = @(@($riskScores | Where-Object { $_.priority -eq "HIGH" } | ForEach-Object { "$($_.className).$($_.method)" }))
        medium = @(@($riskScores | Where-Object { $_.priority -eq "MEDIUM" } | ForEach-Object { "$($_.className).$($_.method)" }))
        low = @(@($riskScores | Where-Object { $_.priority -eq "LOW" } | ForEach-Object { "$($_.className).$($_.method)" }))
    }
    
    estimatedTestsNeeded = (@($uncoveredMethods).Count * 5) + (@($partiallyTestedMethods).Count * 3)
    
    summary = @{
        totalMethods = $currentMetrics.TotalMethods
        uncoveredMethods = @($uncoveredMethods).Count
        partiallyTested = @($partiallyTestedMethods).Count
        fullyCovered = @($fullyCoveredMethods).Count
        criticalRiskMethods = @($riskScores | Where-Object { $_.priority -eq "CRITICAL" }).Count
        highRiskMethods = @($riskScores | Where-Object { $_.priority -eq "HIGH" }).Count
    }
}

# ============================================================
# Step 9: Save to JSON File
# ============================================================

$jsonOutput = $coverageAnalysis | ConvertTo-Json -Depth 10

# Ensure TestResults directory exists
if (-not (Test-Path "./TestResults")) {
    New-Item -ItemType Directory -Path "./TestResults" -Force | Out-Null
}

Set-Content -Path $OutputPath -Value $jsonOutput -Encoding UTF8

Write-Host "? Coverage analysis exported to: $OutputPath" -ForegroundColor Green
Write-Host ""
Write-Host "?? Summary:" -ForegroundColor White
Write-Host "   Total Methods: $($coverageAnalysis.summary.totalMethods)" -ForegroundColor Gray
Write-Host "   Uncovered: $($coverageAnalysis.summary.uncoveredMethods)" -ForegroundColor Gray
Write-Host "   Partial: $($coverageAnalysis.summary.partiallyTested)" -ForegroundColor Gray
Write-Host "   Fully Covered: $($coverageAnalysis.summary.fullyCovered)" -ForegroundColor Gray
Write-Host "   Critical Risk: $($coverageAnalysis.summary.criticalRiskMethods)" -ForegroundColor Red
Write-Host "   High Risk: $($coverageAnalysis.summary.highRiskMethods)" -ForegroundColor Yellow
Write-Host ""
Write-Host "?? File ready for plan-tests skill" -ForegroundColor Cyan

return $coverageAnalysis
