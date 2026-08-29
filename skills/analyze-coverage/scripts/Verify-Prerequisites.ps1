<# 
.SYNOPSIS
    Verifies that prerequisites are met before running coverage analysis
.DESCRIPTION
    Checks that type registry exists and scan-repository has completed successfully
.EXAMPLE
    .\Verify-Prerequisites.ps1
#>

Write-Host "Verifying prerequisites for coverage analysis..." -ForegroundColor Cyan

# Verify type registry exists (created by scan-repository)
$typeRegistryPath = "./TestResults/type-registry.json"
if (-not (Test-Path $typeRegistryPath)) {
    throw "🚨 PREREQUISITE FAILED: type-registry.json not found. Run scan-repository first."
}
Write-Host "✅ Type registry found" -ForegroundColor Green

# Verify type registry is not empty
$registrySize = (Get-Item $typeRegistryPath).Length
if ($registrySize -lt 100) {
    throw "🚨 PREREQUISITE FAILED: type-registry.json appears empty or corrupted."
}
Write-Host "✅ Type registry validated ($registrySize bytes)" -ForegroundColor Green

return $true
