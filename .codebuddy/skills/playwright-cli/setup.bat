@echo off
echo ========================================
echo   playwright-cli Project Setup Script
echo ========================================
echo.

:: Check Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed. Please install Node.js first:
    echo         https://nodejs.org/
    exit /b 1
)
echo [OK] Node.js found: 
node --version

:: Check npm
where npm >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] npm is not installed.
    exit /b 1
)
echo [OK] npm found:
npm --version

echo.
echo [1/2] Installing playwright-cli globally...
call npm install -g @playwright/cli@latest
if %errorlevel% neq 0 (
    echo.
    echo [WARNING] Installation failed. Trying with admin privileges...
    echo           Please approve the UAC prompt if shown...
    powershell -Command "Start-Process powershell -Verb runAs -ArgumentList '-Command', 'npm install -g @playwright/cli@latest' -Wait"
)

echo.
echo [2/2] Verifying installation...
playwright-cli --version
if %errorlevel% equ 0 (
    echo.
    echo [OK] playwright-cli installed successfully!
    echo.
    echo To install browsers, run:
    echo     playwright-cli install-browser
) else (
    echo.
    echo [ERROR] Installation verification failed.
    echo Please try running manually: npm install -g @playwright/cli@latest
    exit /b 1
)

echo.
echo ========================================
echo   Setup Complete!
echo ========================================
