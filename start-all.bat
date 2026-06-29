@echo off
title Panggil-In One-Click System Launcher
color 0B
cd /d "%~dp0"

echo =================================================================
echo                 PANGGIL-IN SYSTEM LAUNCHER
echo =================================================================
echo This script will start all services in the Panggil-In monorepo.
echo.

:: Step 1: Kill Zombie Processes on Port 3001 and 3002
echo [1/6] Cleaning up ports 3001 and 3002...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :3001') do taskkill /F /PID %%a 2>nul
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :3002') do taskkill /F /PID %%a 2>nul
echo Port cleanup done.
echo.

:: Step 2: Start Docker Services
echo [2/6] Starting Docker containers (PostgreSQL, Redis, MQTT)...
call docker-compose up -d
if errorlevel 1 (
    echo [WARNING] Failed to start Docker. Make sure Docker Desktop is running!
) else (
    echo Docker containers started successfully.
)
echo.

:: Step 3: Check and Install Root Dependencies
echo [3/6] Verifying project dependencies...
if not exist "node_modules\" (
    echo Node modules not found. Running npm install...
    call npm install
) else (
    echo Root dependencies verified.
)
echo.

:: Step 4: Backend Setup and Generate Prisma Client
echo [4/6] Initializing Backend database and schema...
cd apps\backend
if not exist "node_modules\" (
    echo Backend Node modules not found. Running npm install...
    call npm install
)
echo Generating Prisma Client...
call npx prisma generate
echo Pushing schema updates to database...
call npx prisma db push --skip-generate
echo Seeding database with initial operator, CCTVs, and patrol units...
call npx prisma db seed
cd /d "%~dp0"
echo Backend setup complete.
echo.

:: Step 5: Start Servers in Background Windows
echo [5/6] Launching Backend API and AI Inference Server...
echo Starting Backend API Gateway on port 3001...
start "Panggil-In Backend API Gateway" cmd /k "cd apps\backend && npm run dev"

echo Starting AI Inference Server on port 3002...
start "Panggil-In AI Server" cmd /k "cd apps\ai_server && run.bat"
echo.

:: Step 6: Start Frontend Applications (Desktop & Mobile)
echo [6/6] Launching Desktop and Mobile Apps...
echo Starting Desktop App (Windows target)...
start "Panggil-In Desktop App" cmd /k "cd apps\desktop_app && flutter run -d windows"

echo Starting Mobile App...
start "Panggil-In Mobile App" cmd /k "cd apps\mobile_app && flutter run"
echo.
echo =================================================================
echo All services have been launched in separate console windows!
echo Keep those windows open to view server logs and app diagnostics.
echo =================================================================
pause
