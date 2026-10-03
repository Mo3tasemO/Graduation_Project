@echo off
setlocal EnableExtensions DisableDelayedExpansion
REM Double-click to check SQL, start the API and open the app and dashboard.
REM Use --check to validate setup without launching windows or browsers.
set "APP_DIR=%~dp0"
set "SERVER_DIR=%~dp0server"

where node >nul 2>&1
if errorlevel 1 (
  echo ERROR: Node.js is not installed or is not on PATH. Install Node.js 24 LTS.
  goto :failed
)
where npm >nul 2>&1
if errorlevel 1 (
  echo ERROR: npm is not available on PATH. Reinstall Node.js with npm.
  goto :failed
)
if not exist "%APP_DIR%node_modules\expo\package.json" (
  echo ERROR: App dependencies are missing. Run npm install in "%APP_DIR%" first.
  goto :failed
)
if not exist "%SERVER_DIR%\node_modules\express\package.json" (
  echo ERROR: Server dependencies are missing. Run npm install in "%SERVER_DIR%" first.
  goto :failed
)

pushd "%SERVER_DIR%"
if errorlevel 1 goto :failed
echo Checking the local SQL database and applying any pending migrations...
call npm run db:setup
if errorlevel 1 (
  echo ERROR: Database setup or integrity checks failed. See the details above.
  popd
  goto :failed
)
REM Existing duplicate-phone warnings are shown but do not prevent startup.
set "SERVER_ENV="
if exist ".env" set "SERVER_ENV=--env-file=.env"
set "SERVER_PORT="
for /f "delims=" %%P in ('node %SERVER_ENV% -e "const p = Number(process.env.PORT || 4000); if (!Number.isInteger(p)) process.exit(1); if (Math.max(1, Math.min(65535, p)) !== p) process.exit(1); console.log(p);"') do set "SERVER_PORT=%%P"
if not defined SERVER_PORT (
  echo ERROR: Set PORT to a valid port number in server\.env.
  popd
  goto :failed
)

if /i "%~1"=="--check" (
  call :server_is_ready
  if errorlevel 1 (
    echo API on port %SERVER_PORT% is not running yet. Normal startup will launch it.
  ) else (
    echo API health check passed on port %SERVER_PORT%.
  )
  popd
  echo Setup check passed. No services or browsers were launched.
  exit /b 0
)

call :server_is_ready
if errorlevel 1 (
  echo Starting the MindSpeak API on port %SERVER_PORT%...
  start "MindSpeak API and SQL database" /D "%SERVER_DIR%" cmd /d /k "npm start"
  call :wait_for_server
  if errorlevel 1 (
    echo ERROR: The API did not become ready. Check the MindSpeak API window for errors.
    popd
    goto :failed
  )
) else (
  echo The MindSpeak API is already running on port %SERVER_PORT%.
)
popd

echo Opening the database dashboard and starting Expo...
start "" "http://localhost:%SERVER_PORT%"
start "MindSpeak Expo App" /D "%APP_DIR%" cmd /d /k "npm run web"
echo The app opens in your browser. The Expo window also provides the phone QR code.
echo Keep the API and Expo windows open while using the app.
exit /b 0

:server_is_ready
node -e "fetch('http://127.0.0.1:%SERVER_PORT%/health', {signal: AbortSignal.timeout(1500)}).then(r => r.json()).then(h => process.exit(h.ok === true && ['smtp', 'console'].includes(h.mail) && typeof h.devShowCode === 'boolean' ? 0 : 1)).catch(() => process.exit(1));" >nul 2>&1
exit /b %errorlevel%

:wait_for_server
for /l %%I in (1,1,20) do (
  call :server_is_ready
  if not errorlevel 1 exit /b 0
  timeout /t 1 /nobreak >nul 2>&1
)
exit /b 1

:failed
if /i not "%~1"=="--check" pause
exit /b 1
