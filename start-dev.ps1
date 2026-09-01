# Delivery DApp Development Startup Script
# This script starts both Hardhat node and Flutter app

Write-Host "🚀 Starting Delivery DApp Development Environment..." -ForegroundColor Green

# Check if we're in the right directory
if (-not (Test-Path "app" -PathType Container)) {
    Write-Host "❌ Error: Please run this script from the project root directory" -ForegroundColor Red
    exit 1
}

# Check if Hardhat is available
if (-not (Get-Command "npx" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: npx not found. Please install Node.js and npm" -ForegroundColor Red
    exit 1
}

# Check if Flutter is available
if (-not (Get-Command "flutter" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Error: Flutter not found. Please install Flutter SDK" -ForegroundColor Red
    exit 1
}

Write-Host "📦 Starting Hardhat node on port 8545..." -ForegroundColor Yellow
Start-Process -FilePath "npx" -ArgumentList "hardhat", "node", "--port", "8545" -WindowStyle Minimized

# Wait a moment for Hardhat to start
Start-Sleep -Seconds 3

Write-Host "📱 Starting Flutter app..." -ForegroundColor Yellow
Set-Location "app"
flutter run -d chrome

Write-Host "✅ Development environment started!" -ForegroundColor Green
Write-Host "🌐 Hardhat node: http://localhost:8545" -ForegroundColor Cyan
Write-Host "📱 Flutter app: Running in Chrome" -ForegroundColor Cyan
Write-Host "💡 Don't forget to setup MetaMask network and import test accounts!" -ForegroundColor Magenta