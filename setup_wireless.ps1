# Complete wireless debugging setup
# Run this script: .\setup_wireless.ps1

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Wireless Debugging Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Pair
Write-Host "STEP 1: PAIR YOUR DEVICE" -ForegroundColor Yellow
Write-Host "------------------------" -ForegroundColor Yellow
Write-Host "On your phone:" -ForegroundColor White
Write-Host "  1. Settings → Developer Options → Wireless Debugging" -ForegroundColor Gray
Write-Host "  2. Tap 'Pair device with pairing code'" -ForegroundColor Gray
Write-Host "  3. Note the IP address, port, and 6-digit code" -ForegroundColor Gray
Write-Host ""

$pairIp = Read-Host "Enter the pairing IP address (e.g., 10.0.0.144)"
$pairPort = Read-Host "Enter the pairing port (e.g., 40251)"

Write-Host ""
Write-Host "Pairing with $pairIp`:$pairPort..." -ForegroundColor Yellow
Write-Host "Enter the 6-digit code from your phone when prompted" -ForegroundColor Cyan
Write-Host ""

$pairResult = adb pair "$pairIp`:$pairPort" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Pairing successful!" -ForegroundColor Green
} else {
    Write-Host "✗ Pairing failed. Error:" -ForegroundColor Red
    Write-Host $pairResult -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Make sure you got a FRESH pairing code (they expire quickly)" -ForegroundColor Gray
    Write-Host "  - Ensure phone and computer are on the same Wi-Fi" -ForegroundColor Gray
    Write-Host "  - Try restarting ADB: adb kill-server && adb start-server" -ForegroundColor Gray
    exit
}

Write-Host ""
Write-Host "STEP 2: CONNECT TO YOUR DEVICE" -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow
Write-Host "On your phone:" -ForegroundColor White
Write-Host "  Go back to Wireless Debugging screen" -ForegroundColor Gray
Write-Host "  Note the IP address and port shown (DIFFERENT from pairing port!)" -ForegroundColor Gray
Write-Host ""

$connectIp = Read-Host "Enter the connection IP address"
$connectPort = Read-Host "Enter the connection port"

Write-Host ""
Write-Host "Connecting to $connectIp`:$connectPort..." -ForegroundColor Yellow

$connectResult = adb connect "$connectIp`:$connectPort" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Connection successful!" -ForegroundColor Green
} else {
    Write-Host "✗ Connection failed. Error:" -ForegroundColor Red
    Write-Host $connectResult -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "Checking connected devices..." -ForegroundColor Yellow
adb devices

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now deploy your app with:" -ForegroundColor Cyan
Write-Host "  flutter run" -ForegroundColor White
Write-Host ""
Write-Host "To see logs, the terminal will show them automatically when you run 'flutter run'" -ForegroundColor Gray

