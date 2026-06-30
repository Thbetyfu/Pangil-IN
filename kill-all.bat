@echo off
title Panggil-In System Cleaner / Killer
color 0C
cd /d "%~dp0"

echo =================================================================
echo                 PANGGIL-IN SYSTEM CLEANER / KILLER
echo =================================================================
echo This script will terminate all running Panggil-In services.
echo.

:: Step 1: Kill Console Windows by Title
echo [1/4] Closing Panggil-In command prompt windows...
taskkill /FI "WINDOWTITLE eq Panggil-In*" /F >nul 2>&1
echo Console windows closed.
echo.

:: Step 2: Kill Zombie Processes on Port 3001 and 3002
echo [2/4] Terminating processes on port 3001 (Backend) and 3002 (AI)...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :3001') do (
    taskkill /F /PID %%a >nul 2>&1
)
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :3002') do (
    taskkill /F /PID %%a >nul 2>&1
)
echo Port processes terminated.
echo.

:: Step 3: Stop Docker Containers
echo [3/4] Stopping Docker containers (PostgreSQL, Redis, MQTT)...
call docker-compose down
if errorlevel 1 (
    echo [WARNING] Failed to stop Docker containers. Check if Docker Desktop is active.
) else (
    echo Docker containers stopped successfully.
)
echo.

:: Step 4: Kill Flutter/Dart processes (optional but recommended for clean slate)
echo [4/4] Cleaning up orphaned Dart / Flutter compiler processes...
taskkill /F /IM dart.exe >nul 2>&1
taskkill /F /IM flutter.exe >nul 2>&1
echo Cleanup complete.
echo.

echo =================================================================
echo All Panggil-In services and applications have been stopped.
echo =================================================================
pause
