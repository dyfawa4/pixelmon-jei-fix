[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $LibrariesDirectory,

    [Parameter(Mandatory = $true)]
    [string] $JeiJar,

    [string] $ForgeClientJar,
    [string] $JdkDirectory,
    [string] $OutputDirectory
)

$ErrorActionPreference = 'Stop'

function Get-RequiredPath {
    param([string] $Path, [bool] $Directory)
    $taskItem = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($taskItem.PSIsContainer -ne $Directory) {
        throw "Unexpected path type: $Path"
    }
    return $taskItem.FullName
}

$taskLibraries = Get-RequiredPath $LibrariesDirectory $true
$taskJei = Get-RequiredPath $JeiJar $false

if ($ForgeClientJar) {
    $taskForgeClient = Get-RequiredPath $ForgeClientJar $false
} else {
    $taskCandidates = @(Get-ChildItem -LiteralPath $taskLibraries -Filter 'forge-1.16.5-36.2.*-client.jar' -Recurse)
    if ($taskCandidates.Count -ne 1) {
        throw 'Expected exactly one Forge 1.16.5 / 36.2.x client jar. Pass -ForgeClientJar explicitly when multiple versions are cached.'
    }
    $taskForgeClient = $taskCandidates[0].FullName
}

if ($JdkDirectory) {
    $taskJdk = Get-RequiredPath $JdkDirectory $true
    $taskJavac = Get-RequiredPath (Join-Path $taskJdk 'bin/javac.exe') $false
    $taskJar = Get-RequiredPath (Join-Path $taskJdk 'bin/jar.exe') $false
} elseif ($env:JAVA_HOME -and (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME 'bin/javac.exe'))) {
    $taskJavac = Get-RequiredPath (Join-Path $env:JAVA_HOME 'bin/javac.exe') $false
    $taskJar = Get-RequiredPath (Join-Path $env:JAVA_HOME 'bin/jar.exe') $false
} else {
    $taskJavac = (Get-Command javac.exe -CommandType Application -ErrorAction Stop).Source
    $taskJar = (Get-Command jar.exe -CommandType Application -ErrorAction Stop).Source
}

$taskMetadata = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'resources/META-INF/mods.toml') -Raw
$taskVersionMatch = [regex]::Match($taskMetadata, '(?m)^version\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"\s*$')
if (-not $taskVersionMatch.Success) { throw 'Missing semantic version in mods.toml' }
$taskVersion = $taskVersionMatch.Groups[1].Value

if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot 'dist' }
$taskOutputDir = (New-Item -ItemType Directory -Force -Path $OutputDirectory).FullName
$taskOutput = Join-Path $taskOutputDir ("pixelmon-jei-fix-1.16.5-{0}.jar" -f $taskVersion)
$taskClasses = Join-Path $PSScriptRoot ('build/' + [guid]::NewGuid().ToString('N') + '/classes')
New-Item -ItemType Directory -Force -Path $taskClasses | Out-Null

# Put the patched Forge client first; caches can also contain vanilla classes.
$taskClasspath = (@($taskForgeClient, $taskJei) + (Get-ChildItem -LiteralPath $taskLibraries -Filter '*.jar' -Recurse).FullName) -join [IO.Path]::PathSeparator
$taskSources = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src') -Filter '*.java' -Recurse | ForEach-Object { $_.FullName })
if ($taskSources.Count -eq 0) { throw 'No Java sources found' }

& $taskJavac --release 11 -proc:none -encoding UTF-8 -cp $taskClasspath -d $taskClasses @taskSources
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed. Use JDK 11 or newer and the supported Forge/JEI dependencies.' }
& $taskJar cf $taskOutput -C $taskClasses . -C (Join-Path $PSScriptRoot 'resources') .
if ($LASTEXITCODE -ne 0) { throw 'Packaging failed' }

$taskHash = Get-FileHash -LiteralPath $taskOutput -Algorithm SHA256
Set-Content -LiteralPath (Join-Path $taskOutputDir 'SHA256SUMS.txt') -Encoding ascii -Value ($taskHash.Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($taskOutput))
Write-Output ("Built: {0}" -f $taskOutput)
Write-Output ("SHA256: {0}" -f $taskHash.Hash)
