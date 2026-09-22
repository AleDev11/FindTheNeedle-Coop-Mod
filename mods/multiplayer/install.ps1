# Installs the multiplayer mod: registers mp.gd as an autoload in the game's
# override.cfg (Godot needs an absolute path there). Run via install.bat.
$ErrorActionPreference = "Stop"
$modDir = $PSScriptRoot
$game = Split-Path -Parent (Split-Path -Parent $modDir)
$exe = Join-Path $game "FindTheNeedle.exe"
if (-not (Test-Path $exe)) {
    Write-Host "No encuentro FindTheNeedle.exe en $game" -ForegroundColor Red
    Write-Host "Copia la carpeta 'mods' dentro de la carpeta del juego (junto a FindTheNeedle.exe)."
    exit 1
}
$cfg = Join-Path $game "override.cfg"
$backup = "$cfg.mp_backup"
if ((Test-Path $cfg) -and -not (Test-Path $backup)) {
    Copy-Item $cfg $backup
}
$base = ""
if (Test-Path $backup) { $base = Get-Content $backup -Raw }
elseif (Test-Path $cfg) { $base = Get-Content $cfg -Raw }
# drop any previous MPMod line, then add ours under [autoload]
$lines = @()
if ($base) { $lines = $base -split "`r?`n" | Where-Object { $_ -notmatch '^\s*MPMod\s*=' } }
$mp = (Join-Path $modDir "mp.gd").Replace('\', '/')
$entry = "MPMod=`"*$mp`""
$out = @()
$added = $false
foreach ($l in $lines) {
    $out += $l
    if ($l -match '^\s*\[autoload\]\s*$') { $out += ""; $out += $entry; $added = $true }
}
if (-not $added) { $out += ""; $out += "[autoload]"; $out += ""; $out += $entry }
$text = ($out -join "`n").Trim() + "`n"
[System.IO.File]::WriteAllText($cfg, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Mod multijugador instalado." -ForegroundColor Green
Write-Host "Abre el juego: en el menu principal aparece MULTIPLAYER (o pulsa F2 dentro de la partida)."
