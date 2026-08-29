<# 
.SYNOPSIS
    Categorizes a C# file based on its content
.DESCRIPTION
    Analyzes file content to determine category (Service, DataAccess, Extension, etc.)
    NOT based on directory name
.PARAMETER FilePath
    Path to the C# file to analyze
.EXAMPLE
    .\Get-FileCategory.ps1 -FilePath "./src/MyService.cs"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

if (-not (Test-Path $FilePath)) {
    throw "File not found: $FilePath"
}

$content = Get-Content $FilePath -Raw

# Check for service patterns
if ($content -match "class.*Service\s*:" -or 
    $content -match "interface\s+I\w+Service") {
    return "Service"
}

# Check for repository patterns
if ($content -match "class.*Repository\s*:" -or
    $content -match "IQueryHandler|ICommandHandler") {
    return "DataAccess"
}

# Check for extension methods
if ($content -match "static\s+class.*Extensions?" -or
    $content -match "public\s+static\s+\w+\s+\w+\s*\(this\s+") {
    return "Extension"
}

# Check for factory patterns
if ($content -match "class.*Factory\s*:" -or
    $content -match "interface\s+I\w+Factory") {
    return "Factory"
}

# Check for validators
if ($content -match "class.*Validator\s*:" -or
    $content -match "AbstractValidator<") {
    return "Validator"
}

# Check for mappers
if ($content -match "class.*Mapper\s*:" -or
    $content -match "class.*Profile\s*:\s*Profile") {
    return "Mapper"
}

# Check for Azure Functions
if ($content -match "\[Function\(|FunctionName\(") {
    return "Function"
}

# Check for controllers
if ($content -match "class.*Controller\s*:" -or
    $content -match "\[ApiController\]") {
    return "Controller"
}

# Default: classify as utility/helper
return "Utility"
