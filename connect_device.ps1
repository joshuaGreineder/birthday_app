# Connect to wirelessly debugged device
# Usage: .\connect_device.ps1

$ADB = "C:\Users\jgreineder\AppData\Local\Android\sdk\platform-tools\adb.exe"

Write-Host "Connect to Wireless Debugging Device" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "On your phone, go to:" -ForegroundColor Yellow
Write-Host "  Settings → Developer Options → Wireless Debugging" -ForegroundColor White
Write-Host "  Note the IP address and port shown (NOT the pairing port)" -ForegroundColor White
Write-Host ""

$ip = Read-Host "Enter the connection IP address (e.g., 10.0.0.144)"
$port = Read-Host "Enter the connection port (e.g., 12345)"

Write-Host ""
Write-Host "Connecting to $ip`:$port..." -ForegroundColor Yellow
& $ADB connect "$ip`:$port"

Write-Host ""
Write-Host "Checking connected devices..." -ForegroundColor Yellow
& $ADB devices

Write-Host ""
Write-Host "If your device appears above, you can now run:" -ForegroundColor Green
Write-Host "  flutter run" -ForegroundColor White

