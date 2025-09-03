# -------------------------------------------------------------------
# start-dev.ps1
# Save this file with UTF-8 encoding or ASCII to avoid any emoji issues.
# -------------------------------------------------------------------

# Enable UTF-8 output (if using emojis)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Enable Verbose and Debug streams
$VerbosePreference = 'Continue'
$DebugPreference   = 'Continue'

# Start transcript to capture all output
Start-Transcript -Path "$PSScriptRoot\start-dev.log" -Append

# ----------------------------------------------------
# 1) Logging helper (no emojis)
# ----------------------------------------------------
function Write-Log {
    param(
        [ValidateSet('INFO','WARN','ERROR','DEBUG','VERBOSE')]
        [string]$Level   = 'INFO',
        [string]$Message
    )

    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    switch ($Level) {
        'INFO'    { Write-Host "[$time] [INFO]    $Message" }
        'WARN'    { Write-Host "[$time] [WARNING] $Message" }
        'ERROR'   { Write-Host "[$time] [ERROR]   $Message" }
        'DEBUG'   { Write-Debug   "$Message" }
        'VERBOSE' { Write-Verbose "$Message" }
    }
}

# ----------------------------------------------------
# 2) Port-check function
# ----------------------------------------------------
function Test-PortInUse {
    param([int]$Port)
    Write-Log -Level VERBOSE -Message "Checking if port $Port is in use..."
    try {
        $conn = Test-NetConnection -ComputerName localhost -Port $Port -WarningAction Stop
        Write-Log -Level DEBUG -Message ("Port {0} in use: {1}" -f $Port, $conn.TcpTestSucceeded)
        return $conn.TcpTestSucceeded
    } catch {
        $errorMsg = ("Unable to test port {0}: {1}" -f $Port, $_.Exception.Message)
        Write-Log -Level WARN -Message $errorMsg
        return $false
    }
}

# ----------------------------------------------------
# 3) Directory-check function
# ----------------------------------------------------
function Test-ProjectDirectory {
    param([string]$Dir)
    Write-Log -Level VERBOSE -Message "Checking directory: $Dir"
    if (-not (Test-Path $Dir)) {
        Write-Log -Level ERROR -Message "Directory not found: $Dir"
        return $false
    }
    Write-Log -Level INFO -Message "Directory found: $Dir"
    return $true
}

# ----------------------------------------------------
# 4) Command-invocation wrapper
# ----------------------------------------------------
function Invoke-CommandWithCheck {
    param(
        [string]$Command,
        [string]$ErrorMessage
    )
    Write-Log -Level INFO -Message "Executing: $Command"
    try {
        Invoke-Expression $Command 2>&1 | ForEach-Object { Write-Log -Level DEBUG -Message $_ }
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Level ERROR -Message "$ErrorMessage (Exit code: $LASTEXITCODE)"
            return $false
        }
        Write-Log -Level INFO -Message "Succeeded: $Command"
        return $true
    } catch {
        Write-Log -Level ERROR -Message "$ErrorMessage - $_"
        return $false
    }
}

# ----------------------------------------------------
# Main script
# ----------------------------------------------------

# Store root directory
$rootDir = $PWD.Path
Write-Log -Level INFO -Message "Script started. Root directory: $rootDir"

# Clean previous builds
Write-Log -Level INFO -Message "Cleaning up previous builds..."

# Kill any existing node processes
Write-Log -Level INFO -Message "Checking for existing node processes..."
Get-Process | Where-Object { $_.ProcessName -eq 'node' } | ForEach-Object {
    try {
        Write-Log -Level INFO -Message "Stopping node process: $($_.Id)"
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Log -Level WARN -Message "Could not stop process $($_.Id): $_"
    }
}

# Wait for ports to clear
Start-Sleep -Seconds 2

Write-Host "🚀 Starting development environment..." -ForegroundColor Cyan

# Create logs directory if it doesn't exist
$logsDir = Join-Path $rootDir "blockchain\logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

# Start transcript logging
$logFile = Join-Path $logsDir "deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $logFile -Append

try {
    # Start Hardhat node
    Write-Host "🌐 Starting Hardhat node on port 8547 with chain ID 5777..." -ForegroundColor Cyan
    Push-Location $rootDir\blockchain
    try {
        $hardhatProcess = Start-Process -FilePath "npx" -ArgumentList "hardhat node" -NoNewWindow -PassThru
        Write-Host "📌 Hardhat node started with PID: $($hardhatProcess.Id)" -ForegroundColor Green

        # Wait for node to start
        Write-Host "⏳ Waiting for node to start..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10

        # Deploy contracts
        Write-Host "📦 Deploying smart contracts..." -ForegroundColor Cyan
        npx hardhat run scripts/deploy.ts --network localhost
        if ($LASTEXITCODE -ne 0) {
            throw "Contract deployment failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }

    Write-Host "✅ Development environment started successfully!" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    if ($hardhatProcess -and -not $hardhatProcess.HasExited) {
        Write-Host "🛑 Stopping Hardhat process..." -ForegroundColor Yellow
        Stop-Process -Id $hardhatProcess.Id -Force
    }
    exit 1
}
finally {
    Stop-Transcript
}

# Check app directory
if (-not (Test-ProjectDirectory "app")) {
    Write-Log -Level ERROR -Message "App directory not found. Run from project root."
    if ($hardhatProcess -and -not $hardhatProcess.HasExited) {
        Write-Log -Level WARN -Message "Stopping Hardhat process..."
        Stop-Process -Id $hardhatProcess.Id -Force
    }
    exit 1
}

# Clean Flutter project
Write-Log -Level INFO -Message "Cleaning Flutter project..."
Set-Location "$rootDir\app"
Remove-Item -Path ".dart_tool","build" -Recurse -Force -ErrorAction SilentlyContinue

# Install Flutter dependencies
Write-Log -Level INFO -Message "Installing Flutter dependencies..."
if (-not (Invoke-CommandWithCheck "flutter pub get" "Failed to install Flutter dependencies")) {
    if ($hardhatProcess -and -not $hardhatProcess.HasExited) {
        Write-Log -Level WARN -Message "Stopping Hardhat process..."
        Stop-Process -Id $hardhatProcess.Id -Force
    }
    exit 1
}

# Build generated files
Write-Log -Level INFO -Message "Running build_runner..."
if (-not (Invoke-CommandWithCheck "flutter pub run build_runner build --delete-conflicting-outputs" "Failed to run build_runner")) {
    if ($hardhatProcess -and -not $hardhatProcess.HasExited) {
        Write-Log -Level WARN -Message "Stopping Hardhat process..."
        Stop-Process -Id $hardhatProcess.Id -Force
    }
    exit 1
}

# Start Flutter web app
Write-Log -Level INFO -Message "Starting Flutter web app..."
Write-Log -Level WARN -Message "Ensure MetaMask is connected to http://127.0.0.1:8547 (Chain ID: 5777)"
$chromeUserDataDir = "C:/Users/$env:USERNAME/AppData/Local/Google/Chrome/User Data"
if (-not (Invoke-CommandWithCheck "flutter run -d chrome --web-browser-flag='--user-data-dir=$chromeUserDataDir'" "Failed to start Flutter app")) {
    if ($hardhatProcess -and -not $hardhatProcess.HasExited) {
        Write-Log -Level WARN -Message "Stopping Hardhat process..."
        Stop-Process -Id $hardhatProcess.Id -Force
    }
    exit 1
}

# Cleanup on exit
$OnExit = {
    if ($hardhatProcess -and -not $hardhatProcess.HasExited) {
        Write-Log -Level INFO -Message "Stopping Hardhat process $($hardhatProcess.Id)"
        Stop-Process -Id $hardhatProcess.Id -Force
    }
}
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $OnExit

# Return to root directory
Write-Log -Level INFO -Message "Returning to root directory"
Set-Location $rootDir

