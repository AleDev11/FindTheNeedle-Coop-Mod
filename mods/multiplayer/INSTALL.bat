@echo off
rem ---------------------------------------------------------------------
rem  Find The Needle - Multiplayer mod installer
rem
rem  All it does: add one line to the game's override.cfg so Godot loads
rem  mp.gd at startup. No files are copied, nothing is downloaded, and the
rem  game's own files are never touched. UNINSTALL.bat undoes it.
rem ---------------------------------------------------------------------
setlocal enabledelayedexpansion

set "MODDIR=%~dp0"
set "MODDIR=%MODDIR:~0,-1%"
for %%I in ("%MODDIR%\..\..") do set "GAME=%%~fI"

if not exist "%GAME%\FindTheNeedle.exe" (
    echo.
    echo   FindTheNeedle.exe not found in:
    echo     %GAME%
    echo.
    echo   Copy the "mods" folder next to FindTheNeedle.exe and run this again.
    echo   ^(Steam: right-click the game, Manage, Browse local files^)
    echo.
    pause
    exit /b 1
)

set "CFG=%GAME%\override.cfg"
set "BAK=%GAME%\override.cfg.mp_backup"
set "LINE=MPMod="*%MODDIR:\=/%/mp.gd""

rem Keep a pristine copy of the game's own override.cfg: take the current
rem one and drop our line. A game update replaces this file, so refreshing
rem the backup here keeps any new settings the developer added.
if exist "%CFG%" (
    findstr /v /b /i "MPMod=" "%CFG%" > "%BAK%.tmp"
    move /y "%BAK%.tmp" "%BAK%" >nul
) else (
    break > "%BAK%"
)

> "%CFG%" (
    type "%BAK%"
    echo.
    echo [autoload]
    echo.
    echo !LINE!
)

echo.
echo   Multiplayer mod installed.  /  Mod multijugador instalado.
echo.
echo   Open the game FROM STEAM: the menu now has MULTIPLAYER (F2 in game).
echo   Abre el juego DESDE STEAM: en el menu aparece MULTIPLAYER (F2 dentro).
echo.
echo   Run this again after every game update: updates remove the mod.
echo   Ejecutalo otra vez tras cada actualizacion del juego.
echo.
pause
