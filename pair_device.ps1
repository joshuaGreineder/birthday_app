# Pair device for wireless debugging
# Usage: .\pair_device.ps1

$ADB = "C:\Users\jgreineder\AppData\Local\Android\sdk\platform-tools\adb.exe"
$IP = "10.0.0.144"
$PORT = "40251"

Write-Host "Pairing with device at $IP`:$PORT..." -ForegroundColor Yellow
Write-Host "Enter the 6-digit pairing code from your phone when prompted." -ForegroundColor Cyan
Write-Host ""

& $ADB pair "$IP`:$PORT"

Write-Host ""
Write-Host "If pairing was successful, you can now connect using:" -ForegroundColor Green
Write-Host "  & `"$ADB`" connect <IP>:<CONNECTION_PORT>" -ForegroundColor White
Write-Host ""
Write-Host "Note: The connection port is different from the pairing port!" -ForegroundColor Yellow
Write-Host "Check the main Wireless Debugging screen on your phone for the connection IP and port." -ForegroundColor Yellow

