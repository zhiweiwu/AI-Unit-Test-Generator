<# 
.SYNOPSIS
    Verifies that the type registry was created successfully
.DESCRIPTION
    Validates type registry JSON exists, is not empty, and contains expected data
.PARAMETER RegistryPath
    Path to the type registry JSON file
.EXAMPLE
    .\Verify-TypeRegistry.ps1 -RegistryPath "TestResults/type-registry.json"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$RegistryPath = "./TestResults/type-registry.json"
)

Write-Host "Verifying type registry..." -ForegroundColor Cyan

# 1. Check file exists
if (-not (Test-Path $RegistryPath)) {
    throw "🚨 CRITICAL: type-registry.json not found at: $RegistryPath. Cannot proceed without type discovery."
}
Write-Host "✅ Type registry file found" -ForegroundColor Green

# 2. Check file size
$registrySize = (Get-Item $RegistryPath).Length
if ($registrySize -lt 1024) {
    throw "🚨 CRITICAL: type-registry.json is too small ($registrySize bytes). Type discovery may have failed."
}
Write-Host "✅ Type registry file size: $registrySize bytes" -ForegroundColor Green

# 3. Parse JSON
try {
    $registry = Get-Content $RegistryPath | ConvertFrom-Json
} catch {
    throw "🚨 CRITICAL: Failed to parse type-registry.json. Error: $_"
}

# 4. Check class count
$classCount = ($registry.PSObject.Properties | Where-Object { $_.Value.constructor }).Count
if ($classCount -eq 0) {
    throw "🚨 CRITICAL: type-registry.json contains no classes! Type discovery failed."
}
Write-Host "✅ Type registry validated: $classCount classes discovered" -ForegroundColor Green

# 5. Count interfaces
$interfaceCount = ($registry.PSObject.Properties | Where-Object { $_.Value.IsInterface -eq $true }).Count
Write-Host "✅ Interfaces discovered: $interfaceCount" -ForegroundColor Green

# 6. Summary
Write-Host ""
Write-Host "Type Registry Summary:" -ForegroundColor Cyan
Write-Host "   Total types: $($registry.PSObject.Properties.Count)" -ForegroundColor White
Write-Host "   Classes: $classCount" -ForegroundColor White
Write-Host "   Interfaces: $interfaceCount" -ForegroundColor White
$registryFullPath = Resolve-Path $RegistryPath
Write-Host "   Registry file: $registryFullPath" -ForegroundColor White

return @{
    Valid = $true
    Path = $RegistryPath
    Size = $registrySize
    ClassCount = $classCount
    InterfaceCount = $interfaceCount
    TotalTypes = $registry.PSObject.Properties.Count
}
