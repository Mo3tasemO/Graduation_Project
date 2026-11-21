
@echo off
cd /d "%~dp0mindspeak_backend"

start "MindSpeak Backend" cmd /k "python -m uvicorn app.main:app --reload"

timeout /t 5 /nobreak >nul

start "" "http://127.0.0.1:8000/admin/"

exit
