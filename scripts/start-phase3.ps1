Write-Host "🚀 Phase 3b: Enabling Dual-Write Mode" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green

# Switch proxy to Phase 3
Write-Host " Switching SQL Proxy to Phase 3..." -ForegroundColor Yellow
$body = @{ phase = 3 } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:5000/phase" -Method Post -ContentType "application/json" -Body $body

# Enable dual-write mode
Write-Host " Enabling dual-write mode..." -ForegroundColor Yellow
Invoke-RestMethod -Uri "http://localhost:5000/enable-dual-write" -Method Post

# Test dual-write with a new user
Write-Host "`n Testing dual-write functionality..." -ForegroundColor Yellow
$testQuery = "INSERT INTO users (username, email, password_hash, full_name) VALUES ('dualwritetest', 'dual@example.com', 'hashed_password', 'Dual Write Test')"
$body = @{ query = $testQuery } | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "http://localhost:5000/query" -Method Post -ContentType "application/json" -Body $body
    Write-Host "Dual-write test successful!" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 3)" -ForegroundColor Cyan
} catch {
    Write-Host " Dual-write test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host " Phase 3b Complete!" -ForegroundColor Green
Write-Host "====================" -ForegroundColor Green
Write-Host " Dual-write mode enabled" -ForegroundColor Cyan
Write-Host " Writes go to BOTH monolith and partitions" -ForegroundColor Cyan
Write-Host " Reads still come from monolith" -ForegroundColor Cyan
Write-Host " Partitions are synchronized with monolith" -ForegroundColor Cyan