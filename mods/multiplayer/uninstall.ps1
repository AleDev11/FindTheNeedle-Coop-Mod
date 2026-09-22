# Removes the multiplayer mod's autoload from override.cfg (restores the backup).
$ErrorActionPreference = "Stop"
$game = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$cfg = Join-Path $game "override.cfg"
$backup = "$cfg.mp_backup"
if (Test-Path $backup) {
    Copy-Item $backup $cfg -Force
    Remove-Item $backup
} elseif (Test-Path $cfg) {
    $lines = (Get-Content $cfg) | Where-Object { $_ -notmatch '^\s*MPMod\s*=' }
    [System.IO.File]::WriteAllText($cfg, (($lines -join "`n").Trim() + "`n"), (New-Object System.Text.UTF8Encoding($false)))
}
Write-Host "Mod multijugador desinstalado (la carpeta mods se puede borrar)." -ForegroundColor Green
