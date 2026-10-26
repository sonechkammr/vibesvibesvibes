param([Parameter(Mandatory = $true)][string]$Godot)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'check.ps1') -Godot $Godot
$outputDirectory = Join-Path $projectRoot 'builds/android'
New-Item -ItemType Directory -Force $outputDirectory | Out-Null
$output = Join-Path $outputDirectory 'mind-garden-0.0.5-android-arm64.apk'
$log = Join-Path $projectRoot '.local/checks/android-export.log'
& $Godot --headless --path $projectRoot --export-debug 'Android test' $output --log-file $log
if ($LASTEXITCODE -ne 0) { throw "Android export failed: $LASTEXITCODE" }
$contents = Get-Content -Raw -LiteralPath $log
if ($contents -match '(?im)^\s*(?:SCRIPT ERROR|ERROR|WARNING):') {
    throw "Android export reported an error or warning. See $log"
}
if (-not (Test-Path -LiteralPath $output)) { throw 'APK was not created.' }
Get-FileHash -LiteralPath $output -Algorithm SHA256
Write-Output 'APK created. Verify signature, alignment, manifest and contents before publishing.'
