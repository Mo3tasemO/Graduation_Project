@echo off
setlocal EnableExtensions
title MindSpeak dashboard launcher

set "BACKEND=%~dp0mindspeak_backend"
set "PYTHON=%BACKEND%\.venv\Scripts\python.exe"
set "DASHBOARD_URL=http://127.0.0.1:8001/admin/"

if not exist "%PYTHON%" (
    echo ERROR: The backend virtual-environment Python was not found:
    echo   %PYTHON%
    echo Create mindspeak_backend\.venv and install requirements.txt first. See mindspeak_backend\README.md.
    goto :failure
)
if not exist "%BACKEND%\.env" (
    echo ERROR: mindspeak_backend\.env was not found.
    echo Copy .env.example to .env and set JWT_SECRET_KEY. See mindspeak_backend\README.md.
    goto :failure
)

netstat -ano | findstr /C:":8001 " | findstr /C:"LISTENING" >nul
if not errorlevel 1 goto :open_dashboard

echo Starting FastAPI on port 8001...
start "MindSpeak FastAPI - port 8001" /D "%BACKEND%" "%ComSpec%" /k ""%PYTHON%" -m uvicorn app.main:app --host 127.0.0.1 --port 8001"

echo Waiting for FastAPI health check...
powershell -NoProfile -Command "$deadline = (Get-Date).AddSeconds(45); $ready = $false; while ((Get-Date) -lt $deadline) { try { $response = Invoke-RestMethod -Uri 'http://127.0.0.1:8001/health' -TimeoutSec 2; if ($response.status -eq 'ok') { $ready = $true; break } } catch {}; Start-Sleep -Seconds 1 }; if ($ready) { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo ERROR: FastAPI did not become healthy within 45 seconds.
    echo Check the MindSpeak FastAPI window for the error message.
    goto :failure
)

:open_dashboard
start "" "%DASHBOARD_URL%"
exit /b 0

:failure
echo.
pause
exit /b 1
