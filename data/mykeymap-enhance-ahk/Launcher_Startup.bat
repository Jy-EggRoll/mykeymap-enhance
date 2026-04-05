cd /d "%~dp0"

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "EggRollMyKeymapEnhanceLauncher" /t REG_SZ /d "\"%~dp0..\..\AutoHotkey64.exe\" \"%~dp0Launcher.ahk\"" /f

start /b "" "%~dp0..\..\AutoHotkey64.exe" "%~dp0Launcher.ahk"
