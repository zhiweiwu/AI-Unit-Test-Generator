<# 
.SYNOPSIS
    Discovers all types (classes, interfaces) in a project and builds type registry
.DESCRIPTION
    Creates a comprehensive type registry with constructors, methods, and dependencies
    CRITICAL: Must run before test generation to prevent compilation errors
    Supports both full-repo and file-specific modes
.PARAMETER ProjectPath
    Path to the source project directory
.PARAMETER TargetFiles
    (Optional) Array of specific files to process. If provided, only these files and their dependencies are included.
.EXAMPLE
    .\Build-TypeRegistry.ps1 -ProjectPath "./src/MyProject"
.EXAMPLE
    .\Build-TypeRegistry.ps1 -ProjectPath "./src" -TargetFiles @("./src/Services/PaymentService.cs")
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,
    
    [Parameter(Mandatory=$false)]
    [string[]]$TargetFiles,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "./TestResults/type-registry.json"
)

# Determine mode
$isFileSpecific = $TargetFiles -and $TargetFiles.Count -gt 0

if ($isFileSpecific) {
    Write-Host "Building type registry (FILE-SPECIFIC MODE)" -ForegroundColor Yellow
    Write-Host "Target files: $($TargetFiles.Count)" -ForegroundColor Cyan
} else {
    Write-Host "Building type registry (FULL-REPO MODE)" -ForegroundColor Cyan
}

function Test-IsTestable {
    param(
        $ClassName, 
        $Constructor,
        $Methods,
        $FileName,
        $ClassBody
    )
    
    # ❌ Skip: Entry points
    if ($FileName -match "^(Program|Startup)\.cs$") {
        return @{ IsTestable = $false; SkipReason = "Application entry point" }
    }
    
    # ❌ Skip: Abstract classes (cannot be instantiated directly)
    if ($ClassBody -match "public\s+abstract\s+class\s+$ClassName") {
        return @{ IsTestable = $false; SkipReason = "Abstract class - cannot instantiate directly" }
    }
    
    # ❌ Skip: Internal/private classes (test project cannot access)
    if ($ClassBody -match "(internal|private)\s+class\s+$ClassName" -or 
        $ClassBody -match "(internal|private)\s+sealed\s+class\s+$ClassName") {
        return @{ IsTestable = $false; SkipReason = "Internal/private class - not accessible from test project" }
    }
    
    # ❌ Skip: Azure Function with triggers (integration test level)
    if ($ClassBody -match "\[(ServiceBusTrigger|BlobTrigger|QueueTrigger|EventGridTrigger|TimerTrigger|HttpTrigger|EventHubTrigger|CosmosDBTrigger)\]") {
        return @{ IsTestable = $false; SkipReason = "Azure Function with trigger - requires integration test" }
    }
    
    # ❌ Skip: Azure Functions (isolated worker model) - detected by class name and [Function] attribute
    if ($ClassName -match "Function$" -and $ClassBody -match "\[Function\(") {
        return @{ IsTestable = $false; SkipReason = "Azure Function class - requires integration test" }
    }
    
    # ❌ Skip: Azure SDK types in CONSTRUCTOR (can't mock constructor injection)
    # ✅ Allow: Azure SDK types as METHOD parameters (can mock when calling methods)
    if ($Constructor -and $Constructor.Parameters) {
        foreach ($param in $Constructor.Parameters) {
            if ($param.Type -match "(ServiceBusMessageActions|BlobClient|TableClient|QueueClient|ServiceBusClient|EventHubClient|EventGridEvent)") {
                return @{ IsTestable = $false; SkipReason = "Azure SDK type in constructor: $($param.Type) - cannot mock constructor" }
            }
        }
    }
    
    # ❌ Skip: Controllers (API controllers - integration test territory)
    if ($ClassName -match "Controller$" -or $ClassBody -match ":\s*(ControllerBase|Controller)\s*$" -or $ClassBody -match "\[ApiController\]") {
        return @{ IsTestable = $false; SkipReason = "API Controller - requires integration test" }
    }
    
    # ❌ Skip: Middleware classes
    if ($ClassName -match "Middleware$" -or $ClassBody -match "IMiddleware|RequestDelegate") {
        return @{ IsTestable = $false; SkipReason = "Middleware - requires integration test" }
    }
    
    # ❌ Skip: Background/Hosted Services
    if ($ClassBody -match ":\s*(BackgroundService|IHostedService)") {
        return @{ IsTestable = $false; SkipReason = "Background/Hosted Service - requires integration test" }
    }
    
    # ❌ Skip: DbContext classes (EF Core)
    if ($ClassName -match "DbContext$" -or $ClassBody -match ":\s*DbContext") {
        return @{ IsTestable = $false; SkipReason = "EF DbContext - requires integration test with database" }
    }
    
    # ❌ Skip: Direct Azure SDK instantiation without abstraction
    if ($ClassBody -match "new\s+(TableClient|BlobClient|QueueClient|ServiceBusClient|EventHubClient)" -and 
        $ClassBody -notmatch "I(Table|Blob|Queue|ServiceBus|EventHub)") {
        return @{ IsTestable = $false; SkipReason = "Direct Azure SDK instantiation - needs repository/interface wrapper" }
    }
    
    # ❌ Skip: Classes implementing ITableEntity (generic constraint issues)
    if ($ClassBody -match ":\s*ITableEntity") {
        return @{ IsTestable = $false; SkipReason = "ITableEntity implementation - complex SDK constraints" }
    }
    
    # ❌ Skip: Static classes (no instance constructor, has static keyword)
    if ($ClassBody -match "public\s+static\s+class\s+$ClassName") {
        return @{ IsTestable = $false; SkipReason = "Static class - not mockable" }
    }
    
    # ❌ Skip: Helper/Extension/Utility classes (naming pattern)
    if ($ClassName -match "(Helper|Extensions?|Utils?|Utilities)$") {
        return @{ IsTestable = $false; SkipReason = "Utility/Helper class - typically static or no business logic" }
    }
    
    # ✅ ALWAYS TESTABLE: FluentValidation validators (HIGH PRIORITY - contains business rules)
    # Must check BEFORE Configuration/DTO checks to prevent false negatives
    # Validators contain business logic in constructors (RuleFor, Must, custom validation methods)
    if ($ClassName -match "Validator$" -or 
        $ClassBody -match ":\s*(AbstractValidator|ModelValidatorBase)" -or
        $ClassBody -match "(RuleFor|RuleForEach)\s*\(") {
        return @{ IsTestable = $true; SkipReason = $null }
    }
    
    # ❌ Skip: Configuration/Options classes (POCO for settings)
    if ($ClassName -match "(Options|Settings|Configuration|Config)$" -and $ClassBody -notmatch "public\s+\w+\s+\w+\s*\(") {
        return @{ IsTestable = $false; SkipReason = "Configuration/Options class - POCO with no logic" }
    }
    
    # ❌ Skip: Attribute classes (metadata only, no business logic)
    if ($ClassName -match "Attribute$" -or $ClassBody -match ":\s*Attribute\s*$|:\s*System\.Attribute") {
        return @{ IsTestable = $false; SkipReason = "Attribute class - metadata only" }
    }
    
    # ❌ Skip: Exception classes (typically just definitions)
    if ($ClassName -match "Exception$" -or $ClassBody -match ":\s*Exception\s*$|:\s*System\.Exception") {
        return @{ IsTestable = $false; SkipReason = "Exception class - typically just definition" }
    }
    
    # ❌ Skip: Models/DTOs (only properties, no methods with logic)
    $hasLogicMethods = $false
    if ($Methods -and $Methods.Count -gt 0) {
        foreach ($method in $Methods) {
            # Ignore property getters/setters, ToString, Equals, GetHashCode
            if ($method.Name -notmatch "^(get_|set_|ToString|Equals|GetHashCode)") {
                $hasLogicMethods = $true
                break
            }
        }
    }
    
    # If no constructor and no logic methods → it's a model/DTO
    if (-not $Constructor.Parameters -and -not $hasLogicMethods) {
        return @{ IsTestable = $false; SkipReason = "Model/DTO - no business logic" }
    }
    
    # ❌ Skip: No public constructor (but has methods → abstract or special case)
    if (-not $Constructor.Parameters -and $hasLogicMethods) {
        return @{ IsTestable = $false; SkipReason = "No public constructor" }
    }
    
    # ❌ Skip: Constructor has concrete dependencies (not interfaces)
    if ($Constructor.Parameters) {
        foreach ($param in $Constructor.Parameters) {
            $type = $param.Type
            
            # ✅ Allow: Interfaces
            if ($type -match '^I[A-Z]') {
                continue
            }
            
            # ✅ Allow: Primitives and common value types
            if ($type -match '^(string|int|long|short|byte|bool|decimal|double|float|char|DateTime|DateTimeOffset|TimeSpan|Guid)') {
                continue
            }
            
            # ✅ Allow: Collections and arrays
            if ($type -match '^(List|Dictionary|Array|IEnumerable|ICollection|IList|IDictionary|HashSet|Queue|Stack)') {
                continue
            }
            
            # ✅ Allow: Framework types (commonly used, mockable or simple)
            if ($type -match '^(HttpClient|ILogger|IConfiguration|CancellationToken|IServiceProvider|IOptions|IOptionsSnapshot|IOptionsMonitor|IMemoryCache|IDistributedCache)') {
                continue
            }
            
            # ✅ Allow: Options/Settings/Configuration classes (POCO, can be instantiated)
            if ($type -match '(Options|Settings|Config|Configuration)(\`|<|$)') {
                continue
            }
            
            # ✅ Allow: DTOs/Requests/Responses/Commands/Queries (data transfer objects)
            if ($type -match '(Dto|Request|Response|Command|Query|Event|Message|Notification)(\`|<|$)') {
                continue
            }
            
            # ✅ Allow: Models/Entities (if used as POCOs, e.g., method parameters)
            # Note: DbContext usage already caught earlier, so entities here are OK
            if ($type -match '(Model|Entity|Aggregate|ValueObject)(\`|<|$)') {
                continue
            }
            
            # ✅ Allow: Simple utility classes (Validators, Mappers, Converters without dependencies)
            # These are often simple enough to instantiate
            if ($type -match '(Validator|Mapper|Converter|Builder|Factory)(\`|<|$)') {
                # Note: If these have complex dependencies, they'll be caught in their own analysis
                continue
            }
            
            # ❌ Reject: Everything else (concrete service classes, repositories, etc.)
            Write-Warning "⚠️ $ClassName has concrete dependency: $type (hard to mock)"
            return @{ IsTestable = $false; SkipReason = "Concrete dependency: $type - cannot mock" }
        }
    }
    
    # ✅ Testable: Has logic, mockable dependencies
    return @{ IsTestable = $true; SkipReason = $null }
}

$registry = @{
    Classes = @()
    Interfaces = @()
    Enums = @()
    Records = @()
}

# Find files to analyze
if ($isFileSpecific) {
    # File-specific mode: only process target files initially
    $files = $TargetFiles | ForEach-Object {
        $fullPath = if ([System.IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path (Get-Location) $_ }
        if (Test-Path $fullPath) {
            Get-Item $fullPath
        } else {
            Write-Warning "Target file not found: $_"
            $null
        }
    } | Where-Object { $_ -ne $null }
    
    Write-Host "Analyzing $($files.Count) target files" -ForegroundColor Green
} else {
    # Full-repo mode: scan all .cs files
    $files = Get-ChildItem -Path $ProjectPath -Recurse -Filter "*.cs" -File |
             Where-Object { $_.FullName -notmatch "\\obj\\|\\bin\\" }
    
    Write-Host "Found $($files.Count) source files to analyze" -ForegroundColor Green
}

# Track which files are targets (for file-specific mode)
$targetFileSet = @{}
if ($isFileSpecific) {
    foreach ($file in $files) {
        $targetFileSet[$file.FullName] = $true
    }
}

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    
    # Extract class definitions with constructors
    $classMatches = [regex]::Matches($content, 
        'public\s+class\s+(\w+)(?:<[^>]+>)?\s*(?::\s*([^{]+))?\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)\}',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    
    foreach ($match in $classMatches) {
        $className = $match.Groups[1].Value
        $baseTypes = $match.Groups[2].Value
        $classBody = $match.Groups[3].Value
        
        # Extract constructor
        $ctorMatch = [regex]::Match($classBody,
            "public\s+$className\s*\(([^)]*)\)")
        
        $constructor = @{
            Parameters = @()
        }
        
        if ($ctorMatch.Success) {
            $params = $ctorMatch.Groups[1].Value
            if ($params.Trim()) {
                # Parse parameters
                $paramList = $params -split ',' | ForEach-Object {
                    $param = $_.Trim()
                    if ($param -match '(\S+)\s+(\w+)') {
                        @{
                            Type = $matches[1]
                            Name = $matches[2]
                        }
                    }
                }
                $constructor.Parameters = $paramList | Where-Object { $_ }
            }
        }
        
        # Extract public methods
        $methodMatches = [regex]::Matches($classBody,
            'public\s+(?:async\s+)?(\w+(?:<[^>]+>)?)\s+(\w+)\s*\(([^)]*)\)')
        
        $methods = $methodMatches | ForEach-Object {
            @{
                ReturnType = $_.Groups[1].Value.Trim()
                Name = $_.Groups[2].Value.Trim()
                Parameters = $_.Groups[3].Value.Trim()
            }
        }
        
        # Check testability with all context
        $testabilityResult = Test-IsTestable -ClassName $className -Constructor $constructor -Methods $methods -FileName $file.Name -ClassBody $content
        
        $classInfo = @{
            Name = $className
            FilePath = $file.FullName
            Constructor = $constructor
            BaseTypes = ($baseTypes -split ',' | ForEach-Object { $_.Trim() }) | Where-Object { $_ }
            Methods = $methods
            IsTestable = $testabilityResult.IsTestable
            SkipReason = $testabilityResult.SkipReason
        }
        
        # Mark as target if in file-specific mode
        if ($isFileSpecific) {
            $classInfo.IsTarget = $targetFileSet.ContainsKey($file.FullName)
        }
        
        $registry.Classes += $classInfo
    }
    
    # Extract interfaces
    $interfaceMatches = [regex]::Matches($content, 'public\s+interface\s+(I\w+(?:<[^>]+>)?)')
    
    foreach ($match in $interfaceMatches) {
        $interfaceInfo = @{
            Name = $match.Groups[1].Value
            FilePath = $file.FullName
        }
        
        # Mark as target if in file-specific mode
        if ($isFileSpecific) {
            $interfaceInfo.IsTarget = $targetFileSet.ContainsKey($file.FullName)
        }
        
        $registry.Interfaces += $interfaceInfo
    }
}

# FILE-SPECIFIC MODE: Resolve dependencies
if ($isFileSpecific) {
    Write-Host "Resolving dependencies for target files..." -ForegroundColor Yellow
    
    # Collect all dependency types from constructors
    $dependenciesToResolve = @{}
    foreach ($class in $registry.Classes | Where-Object { $targetFileSet.ContainsKey($_.FilePath) }) {
        foreach ($param in $class.Constructor.Parameters) {
            $typeName = $param.Type -replace '<.*>', ''  # Remove generics
            if ($typeName -match '^I[A-Z]') {  # Interface
                $dependenciesToResolve[$typeName] = $true
            }
        }
    }
    
    Write-Host "   Found $($dependenciesToResolve.Count) dependencies to resolve" -ForegroundColor Cyan
    
    # Search for dependency types in project
    $allFiles = Get-ChildItem -Path $ProjectPath -Recurse -Filter "*.cs" -File |
                Where-Object { $_.FullName -notmatch "\\obj\\|\\bin\\" -and -not $targetFileSet.ContainsKey($_.FullName) }
    
    $resolvedCount = 0
    foreach ($typeName in $dependenciesToResolve.Keys) {
        # Skip if already in registry
        if ($registry.Classes | Where-Object { $_.Name -eq $typeName }) { continue }
        if ($registry.Interfaces | Where-Object { $_.Name -eq $typeName }) { continue }
        
        # Search for type definition
        $found = $false
        foreach ($depFile in $allFiles) {
            $content = Get-Content $depFile.FullName -Raw
            
            # Check for interface
            if ($content -match "public\s+interface\s+$typeName\b") {
                $registry.Interfaces += @{
                    Name = $typeName
                    FilePath = $depFile.FullName
                    IsTarget = $false
                }
                $resolvedCount++
                $found = $true
                Write-Host "  • Resolved dependency: $typeName (interface)" -ForegroundColor Gray
                break
            }
            
            # Check for class
            if ($content -match "public\s+class\s+$typeName\b") {
                $registry.Classes += @{
                    Name = $typeName
                    FilePath = $depFile.FullName
                    Constructor = @{ Parameters = @() }
                    BaseTypes = @()
                    Methods = @()
                    IsTestable = $false
                    IsTarget = $false
                }
                $resolvedCount++
                $found = $true
                Write-Host "  • Resolved dependency: $typeName (class)" -ForegroundColor Gray
                break
            }
        }
        
        # If not found, assume framework type
        if (-not $found) {
            Write-Host "  • Framework type: $typeName" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "✅ Resolved $resolvedCount dependencies" -ForegroundColor Green
}

Write-Host "✅ Type registry built:" -ForegroundColor Green
Write-Host "   Classes: $($registry.Classes.Count)" -ForegroundColor Cyan
Write-Host "   Interfaces: $($registry.Interfaces.Count)" -ForegroundColor Cyan

# Build type mapping
$typeMap = @{}

foreach ($class in $registry.Classes) {
    $typeInfo = @{
        FilePath = $class.FilePath
        Constructor = $class.Constructor
        IsInterface = $false
        IsTestable = $class.IsTestable
        SkipReason = $class.SkipReason
        Methods = $class.Methods
    }
    
    # Add IsTarget flag if in file-specific mode
    if ($isFileSpecific -and $class.PSObject.Properties['IsTarget']) {
        $typeInfo.IsTarget = $class.IsTarget
    }
    
    $typeMap[$class.Name] = $typeInfo
}

foreach ($interface in $registry.Interfaces) {
    $typeInfo = @{
        FilePath = $interface.FilePath
        IsInterface = $true
    }
    
    # Add IsTarget flag if in file-specific mode
    if ($isFileSpecific -and $interface.PSObject.Properties['IsTarget']) {
        $typeInfo.IsTarget = $interface.IsTarget
    }
    
    $typeMap[$interface.Name] = $typeInfo
}

# Report file-specific mode statistics
if ($isFileSpecific) {
    $targetCount = ($typeMap.Values | Where-Object { $_.IsTarget -eq $true }).Count
    $depCount = ($typeMap.Values | Where-Object { $_.IsTarget -eq $false -or $null -eq $_.IsTarget }).Count
    Write-Host "   Target types: $targetCount" -ForegroundColor Cyan
    Write-Host "   Dependencies: $depCount" -ForegroundColor Cyan
}

# Save to JSON for next skills
$outputPath = $OutputPath
$outputDir = Split-Path $outputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$typeMap | ConvertTo-Json -Depth 10 | Out-File $outputPath -Encoding UTF8

Write-Host "✅ Type registry saved to: $outputPath" -ForegroundColor Green

return $typeMap
