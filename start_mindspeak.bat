@echo off
setlocal EnableExtensions
title MindSpeak launcher

set "ROOT=%~dp0"
set "BACKEND=%ROOT%mindspeak_backend"
set "FRONTEND=%ROOT%mindspeak_flutter"
set "PYTHON=%BACKEND%\.venv\Scripts\python.exe"
set "API_URL=http://127.0.0.1:8001/api/v1"
set "CHROME="
set "FLUTTER="

echo.
echo Starting MindSpeak...
echo.

if not exist "%PYTHON%" (
    echo ERROR: The backend virtual-environment Python was not found:
    echo   %PYTHON%
    echo Create or restore mindspeak_backend\.venv before running this launcher.
    goto :failure
)

"%PYTHON%" --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python in mindspeak_backend\.venv could not be started.
    goto :failure
)

where flutter.bat >nul 2>&1
if errorlevel 1 (
    echo ERROR: Flutter was not found on PATH.
    echo Install Flutter or add its bin folder to PATH, then open a new terminal.
    goto :failure
)
for /f "delims=" %%F in ('where flutter.bat 2^>nul') do if not defined FLUTTER set "FLUTTER=%%F"
if not defined FLUTTER (
    echo ERROR: Flutter was found but its executable path could not be resolved.
    goto :failure
)
echo Flutter: %FLUTTER%

rem Flutter's bundled Git checkout may not be marked safe on this Windows machine.
rem Keep this override scoped to this launcher process; do not change global Git config.
for %%I in ("%FLUTTER%\..") do set "FLUTTER_ROOT=%%~fI"
set "FLUTTER_GIT_ROOT=%FLUTTER_ROOT:\=/%"
set "GIT_CONFIG_COUNT=1"
set "GIT_CONFIG_KEY_0=safe.directory"
set "GIT_CONFIG_VALUE_0=%FLUTTER_GIT_ROOT%"
set "CI=true"

if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" set "CHROME=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
if not defined CHROME for /f "delims=" %%C in ('where chrome.exe 2^>nul') do if not defined CHROME set "CHROME=%%C"
if not defined CHROME (
    echo ERROR: Google Chrome was not found in its standard install locations or on PATH.
    goto :failure
)
set "CHROME_EXECUTABLE=%CHROME%"

if not exist "%FRONTEND%\pubspec.yaml" (
    echo ERROR: Flutter project was not found at:
    echo   %FRONTEND%
    goto :failure
)
if not exist "%FRONTEND%\.dart_tool\package_config.json" (
    echo ERROR: Flutter dependencies have not been resolved for this checkout.
    echo Run flutter pub get once from mindspeak_flutter, then double-click this launcher again.
    goto :failure
)

netstat -ano | findstr /C:":8001 " | findstr /C:"LISTENING" >nul
if not errorlevel 1 goto :backend_already_running

echo Starting FastAPI with its existing .venv and .env...
start "MindSpeak FastAPI - port 8001" /D "%BACKEND%" "%ComSpec%" /k ""%PYTHON%" -m uvicorn app.main:app --host 127.0.0.1 --port 8001"
goto :wait_for_backend

:backend_already_running
echo Port 8001 is already occupied. Checking the existing service; no duplicate backend will be started.
powershell -NoProfile -Command "try { $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8001/health' -TimeoutSec 3; $schema = Invoke-RestMethod -Uri 'http://127.0.0.1:8001/openapi.json' -TimeoutSec 3; if ($health.status -eq 'ok' -and $schema.info.title -eq 'MindSpeak Backend API') { exit 0 } } catch {}; exit 1" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Port 8001 is occupied, but its service did not pass the MindSpeak health check.
    echo Stop or inspect that service manually; this launcher will not start a second backend.
    goto :failure
)
echo Existing FastAPI service is healthy.
goto :start_flutter

:wait_for_backend
echo Waiting for FastAPI health check...
powershell -NoProfile -Command "$deadline = (Get-Date).AddSeconds(45); $ready = $false; while ((Get-Date) -lt $deadline) { try { $response = Invoke-RestMethod -Uri 'http://127.0.0.1:8001/health' -TimeoutSec 2; if ($response.status -eq 'ok') { $ready = $true; break } } catch {}; Start-Sleep -Seconds 1 }; if ($ready) { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo ERROR: FastAPI did not become healthy within 45 seconds.
    echo Check the MindSpeak FastAPI window for startup errors. The Flutter app was not started.
    goto :failure
)
echo FastAPI is ready.

:start_flutter
echo Starting Flutter in Chrome with API URL:
echo   %API_URL%
echo.
pushd "%FRONTEND%"
call "%FLUTTER%" run -d chrome --no-pub --dart-define=MINDSPEAK_API_URL=%API_URL%
set "FLUTTER_EXIT_CODE=%ERRORLEVEL%"
popd
echo.
if not "%FLUTTER_EXIT_CODE%"=="0" echo Flutter exited with code %FLUTTER_EXIT_CODE%. Check the Flutter output above.
echo To stop Flutter safely, press Ctrl+C in this window. FastAPI remains running in its own window.
echo To stop FastAPI, press Ctrl+C in the FastAPI window started by this launcher.
echo If FastAPI was already running before launch, leave its existing window under your control.
exit /b 0

:failure
echo.
pause
exit /b 1
