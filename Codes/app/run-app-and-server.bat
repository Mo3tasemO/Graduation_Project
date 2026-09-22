@echo off
REM ============================================
REM Runs the app and the dataset server together
REM Edit the two commands below if your actual
REM npm/python commands are different.
REM ============================================

set APP_DIR=E:\app
set SERVER_DIR=E:\app\server
set APP_CMD=npm start
set SERVER_CMD=npm start

echo Starting dataset server...
start "Dataset Server" cmd /k "cd /d %SERVER_DIR% && %SERVER_CMD%"

echo Starting app...
start "App" cmd /k "cd /d %APP_DIR% && %APP_CMD%"

echo Both processes launched in separate windows.
