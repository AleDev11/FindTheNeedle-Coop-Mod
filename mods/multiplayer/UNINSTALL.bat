@echo off
rem ---------------------------------------------------------------------
rem  Find The Needle - Multiplayer mod uninstaller
rem
rem  Removes the mod's line from the game's override.cfg, restoring the
rem  file the game shipped with. After this the "mods" folder can be
rem  deleted; nothing else was ever changed.
rem ---------------------------------------------------------------------
setlocal

set "MODDIR=%~dp0"
set "MODDIR=%MODDIR:~0,-1%"
for %%I in ("%MODDIR%\..\..") do set "GAME=%%~fI"

set "CFG=%GAME%\override.cfg"
set "BAK=%GAME%\override.cfg.mp_backup"

if exist "%BAK%" (
    copy /y "%BAK%" "%CFG%" >nul
    del "%BAK%"
) else (
    if exist "%CFG%" (
        findstr /v /b /i "MPMod=" "%CFG%" > "%CFG%.tmp"
        move /y "%CFG%.tmp" "%CFG%" >nul
    )
)

echo.
echo   Mod uninstalled.  /  Mod desinstalado. Ya puedes borrar la carpeta mods.
echo.
pause
