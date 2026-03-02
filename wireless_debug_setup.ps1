# Wireless Debugging Setup Script
# Run this script after enabling wireless debugging on your phone

$ANDROID_HOME = "C:\Users\jgreineder\AppData\Local\Android\sdk"
$ADB = "$ANDROID_HOME\platform-tools\adb.exe"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Wireless Debugging Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Step 1: On your phone:" -ForegroundColor Yellow
Write-Host "  - Go to Settings → Developer Options → Wireless Debugging" -ForegroundColor White
Write-Host "  - Tap 'Pair device with pairing code'" -ForegroundColor White
Write-Host "  - Note the IP address, port, and 6-digit pairing code" -ForegroundColor White
Write-Host ""

$ip = Read-Host "Enter the IP address (e.g., 192.168.1.100)"
$port = Read-Host "Enter the pairing port (e.g., 12345)"

Write-Host ""
Write-Host "Pairing with device..." -ForegroundColor Yellow
& $ADB pair "$ip`:$port"

Write-Host ""
Write-Host "Step 2: After pairing, on your phone:" -ForegroundColor Yellow
Write-Host "  - Go back to Wireless Debugging screen" -ForegroundColor White
Write-Host "  - Note the IP address and port shown (different from pairing port)" -ForegroundColor White
Write-Host ""

$connectIp = Read-Host "Enter the connection IP address"
$connectPort = Read-Host "Enter the connection port"

Write-Host ""
Write-Host "Connecting to device..." -ForegroundColor Yellow
& $ADB connect "$connectIp`:$connectPort"

Write-Host ""
Write-Host "Checking connected devices..." -ForegroundColor Yellow
& $ADB devices

Write-Host ""
Write-Host "Done! You can now run 'flutter run' to deploy to your phone wirelessly." -ForegroundColor Green

