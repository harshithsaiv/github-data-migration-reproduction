Write-Host "Testing Phase 1 Setup" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green

# Test proxy health
Write-Host "1. Testing proxy health..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-RestMethod -Uri "http://localhost:5000/health" -Method Get
    Write-Host ($healthResponse | ConvertTo-Json -Depth 3) -ForegroundColor Green
} catch {
    Write-Host "Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test database connection
Write-Host "`n2. Testing database connection..." -ForegroundColor Yellow
try {
    $body = @{
        query = 'SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = "github_monolith"'
    } | ConvertTo-Json

    $dbResponse = Invoke-RestMethod -Uri "http://localhost:5000/query" -Method Post -ContentType "application/json" -Body $body
    Write-Host ($dbResponse | ConvertTo-Json -Depth 3) -ForegroundColor Green
} catch {
    Write-Host "Database test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test table creation
Write-Host "`n3. Testing table creation..." -ForegroundColor Yellow
try {
    $body = @{
        query = "SHOW TABLES"
    } | ConvertTo-Json

    $tablesResponse = Invoke-RestMethod -Uri "http://localhost:5000/query" -Method Post -ContentType "application/json" -Body $body
    Write-Host ($tablesResponse | ConvertTo-Json -Depth 3) -ForegroundColor Green
} catch {
    Write-Host "Tables test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n Phase 1 testing complete!" -ForegroundColor Green