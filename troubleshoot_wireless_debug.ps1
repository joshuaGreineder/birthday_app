# Troubleshooting script for wireless debugging
# Usage: .\troubleshoot_wireless_debug.ps1

$ADB = "C:\Users\jgreineder\AppData\Local\Android\sdk\platform-tools\adb.exe"

Write-Host "Wireless Debugging Troubleshooter" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Restart ADB server
Write-Host "Step 1: Restarting ADB server..." -ForegroundColor Yellow
& $ADB kill-server
Start-Sleep -Seconds 1
& $ADB start-server
Write-Host "✓ ADB server restarted" -ForegroundColor Green
Write-Host ""

# Step 2: Check if we can reach the phone
Write-Host "Step 2: Testing network connectivity..." -ForegroundColor Yellow
Write-Host "On your phone, get a NEW pairing code:" -ForegroundColor White
Write-Host "  Settings → Developer Options → Wireless Debugging → Pair device with pairing code" -ForegroundColor White
Write-Host ""

$ip = Read-Host "Enter the IP address from your phone (e.g., 10.0.0.144)"
$port = Read-Host "Enter the pairing port (e.g., 40251)"

Write-Host ""
Write-Host "Testing connection to $ip..." -ForegroundColor Yellow
$ping = Test-Connection -ComputerName $ip -Count 1 -Quiet
if ($ping) {
    Write-Host "✓ Phone is reachable on network" -ForegroundColor Green
} else {
    Write-Host "✗ Cannot reach phone - check Wi-Fi connection" -ForegroundColor Red
    Write-Host "  Make sure phone and computer are on the same Wi-Fi network" -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Step 3: Attempting to pair..." -ForegroundColor Yellow
Write-Host "Enter the 6-digit pairing code when prompted (get a fresh one from your phone!)" -ForegroundColor Cyan
Write-Host ""

& $ADB pair "$ip`:$port"

Write-Host ""
Write-Host "If pairing succeeded, check the Wireless Debugging screen on your phone" -ForegroundColor Yellow
Write-Host "for the connection IP and port (different from pairing port), then run:" -ForegroundColor Yellow
Write-Host "  .\connect_device.ps1" -ForegroundColor White

