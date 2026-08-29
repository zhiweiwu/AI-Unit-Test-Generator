<# 
.SYNOPSIS
    Enumerates all testable C# source files in a project
.DESCRIPTION
    Recursively scans project directory for .cs files and filters to testable files only
.PARAMETER ProjectPath
    Path to the source project directory
.EXAMPLE
    .\Enumerate-SourceFiles.ps1 -ProjectPath "./src/MyProject"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath
)

Write-Host "Enumerating source files in: $ProjectPath" -ForegroundColor Cyan

# 1. Find source project directory (non-test project)
$sourceProjects = Get-ChildItem -Path $ProjectPath -Recurse -Filter "*.csproj" -File | Where-Object {
    $_.Name -notmatch "\.Tests\." -and
    $_.Name -notmatch "\.UnitTests\." -and
    $_.Name -notmatch "\.IntegrationTests\."
}

if ($sourceProjects.Count -eq 0) {
    throw "No source projects found in: $ProjectPath"
}

Write-Host "Found $($sourceProjects.Count) source project(s)" -ForegroundColor Green

$allTestableFiles = @()

# 2. For each source project, enumerate ALL .cs files recursively
foreach ($project in $sourceProjects) {
    $projectDir = $project.Directory.FullName
    Write-Host "  Scanning: $($project.Name)" -ForegroundColor Cyan
    
    # Get ALL C# files under this project
    $allCsFiles = Get-ChildItem -Path $projectDir -Recurse -Filter "*.cs" -File
    
    # 3. Filter to testable files only
    $testableFiles = $allCsFiles | Where-Object {
        # Exclude directories
        $_.Directory.Name -notmatch "^obj$|^bin$|^node_modules$" -and
        
        # Exclude non-testable file patterns
        $_.Name -notmatch "^I[A-Z].*\.cs$" -and  # Interfaces (IService.cs)
        $_.Name -notmatch "Program\.cs$" -and    # Entry points
        $_.Name -notmatch "Startup\.cs$" -and    # Startup files
        $_.Name -notmatch "AssemblyInfo\.cs$"
    }
    
    Write-Host "    Found $($testableFiles.Count) potentially testable files" -ForegroundColor Green
    $allTestableFiles += $testableFiles
}

Write-Host "`n✅ Total testable files found: $($allTestableFiles.Count)" -ForegroundColor Green

return $allTestableFiles
