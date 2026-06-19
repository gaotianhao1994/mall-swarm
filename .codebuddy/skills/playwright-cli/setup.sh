#!/bin/bash

set -e

echo "========================================"
echo "  playwright-cli Project Setup Script"
echo "========================================"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "[ERROR] Node.js is not installed. Please install Node.js first:"
    echo "        https://nodejs.org/"
    exit 1
fi
echo "[OK] Node.js found:"
node --version

# Check npm
if ! command -v npm &> /dev/null; then
    echo "[ERROR] npm is not installed."
    exit 1
fi
echo "[OK] npm found:"
npm --version

echo ""
echo "[1/2] Installing playwright-cli globally..."
npm install -g @playwright/cli@latest

echo ""
echo "[2/2] Verifying installation..."
playwright-cli --version

echo ""
echo "[OK] playwright-cli installed successfully!"
echo ""
echo "To install browsers, run:"
echo "    playwright-cli install-browser"

echo ""
echo "========================================"
echo "  Setup Complete!"
echo "========================================"
