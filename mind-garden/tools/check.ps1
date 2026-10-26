param([Parameter(Mandatory = $true)][string]$Godot)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$logRoot = Join-Path $projectRoot '.local/checks'
New-Item -ItemType Directory -Force $logRoot | Out-Null

function Invoke-CheckedGodot {
    param([string]$Name, [string[]]$EngineArguments, [string]$PassMarker = '')
    $log = Join-Path $logRoot "$Name.log"
    & $Godot --headless --path $projectRoot --log-file $log @EngineArguments
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE" }
    $contents = Get-Content -Raw -LiteralPath $log
    if ($contents -match '(?im)^\s*(?:SCRIPT ERROR|ERROR|WARNING):|ObjectDB instances leaked|resources still in use|FAIL:') {
        throw "$Name reported an error or warning. See $log"
    }
    if ($PassMarker -and -not $contents.Contains($PassMarker)) {
        throw "$Name did not report $PassMarker. See $log"
    }
}

Invoke-CheckedGodot 'import' @('--editor', '--import', '--quit')
Invoke-CheckedGodot 'state' @('--script', 'res://tests/test_state.gd') 'STATE PASS:'
Invoke-CheckedGodot 'clock' @('--script', 'res://tests/test_clock.gd') 'CLOCK PASS:'
Invoke-CheckedGodot 'navigation' @('--script', 'res://tests/test_navigation_day.gd') 'NAVIGATION/DAY PASS:'
Invoke-CheckedGodot 'smoke' @('--quit-after', '2400', '--', '--smoke') 'SMOKE PASS:'
Write-Output 'Import, state, clock, navigation/day and UI smoke passed; logs reviewed.'
