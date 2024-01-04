echo off
set GAME_FOLDER=C:\Users\Jezuz\Desktop\BlackOps2
set OAT_BASE=C:\Users\Jezuz\Desktop\OpenAssetTools
set MOD_BASE=%cd%
set MOD_NAME=mp_trophy_wars
"%OAT_BASE%\linker_release.exe" ^
-v ^
--base-folder "%OAT_BASE%" ^
--asset-search-path "%MOD_BASE%" ^
--source-search-path "%MOD_BASE%\zone_source" ^
--output-folder "%MOD_BASE%\zone" mod

set err=%ERRORLEVEL%

if %err% EQU 0 (
XCOPY "%MOD_BASE%\zone\mod.ff" "%LOCALAPPDATA%\Plutonium-staging\storage\t6\mods\%MOD_NAME%\mod.ff" /Y
) ELSE (
COLOR C
echo FAIL!
)
pause