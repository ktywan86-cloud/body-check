@echo off
setlocal
set "BODY_CHECK_ORIGINS=http://localhost:8080,http://127.0.0.1:8080"
if not "%~1"=="" set "BODY_CHECK_ORIGINS=%~1"
echo ====================================================
echo Body Check - Setting up Ollama CORS
echo ====================================================
echo.
echo 1. Setting allowed origins to:
echo    %BODY_CHECK_ORIGINS%
powershell -Command "[System.Environment]::SetEnvironmentVariable('OLLAMA_ORIGINS', '%BODY_CHECK_ORIGINS%', 'User')"

echo 2. Restarting Ollama process...
taskkill /IM ollama.exe /F 2>nul
taskkill /IM "ollama app.exe" /F 2>nul

echo 3. Re-launching Ollama...
timeout /t 2 >nul

if exist "%LOCALAPPDATA%\Programs\Ollama\ollama app.exe" (
    start "" "%LOCALAPPDATA%\Programs\Ollama\ollama app.exe"
    echo Ollama app launched successfully with CORS enabled!
) else (
    start "" ollama serve
    echo Ollama serve launched in background with CORS enabled!
)

echo.
echo ====================================================
echo Setup complete. Please restart any open CMD/PowerShell
echo windows for the change to take effect globally.
echo.
echo For GitHub Pages, run this script with the exact site origin:
echo setup_ollama.bat https://YOUR_NAME.github.io
echo ====================================================
pause
