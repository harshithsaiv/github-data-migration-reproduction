Write-Host "Starting GitHub Data Migration - Phase 1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

# Navigate to docker directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$dockerPath = Join-Path (Split-Path -Parent $scriptPath) "docker"
Set-Location $dockerPath

Write-Host "Starting Docker containers..." -ForegroundColor Yellow
docker-compose up -d

Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Wait for MySQL to be ready
Write-Host "Waiting for MySQL to be ready..." -ForegroundColor Yellow
do {
    Write-Host "   MySQL is unavailable - sleeping" -ForegroundColor Gray
    Start-Sleep -Seconds 2
    $mysqlReady = docker exec github-monolith mysqladmin ping -h localhost --silent
} while ($LASTEXITCODE -ne 0)
Write-Host "MySQL is ready!" -ForegroundColor Green

# Wait for Proxy to be ready
Write-Host " Waiting for SQL Proxy to be ready..." -ForegroundColor Yellow
do {
    Write-Host "   Proxy is unavailable - sleeping" -ForegroundColor Gray
    Start-Sleep -Seconds 2
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        $proxyReady = $response.StatusCode -eq 200
    } catch {
        $proxyReady = $false
    }
} while (-not $proxyReady)
Write-Host "SQL Proxy is ready!" -ForegroundColor Green

Write-Host ""
Write-Host " Phase 1 Setup Complete!" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host " SQL Proxy: http://localhost:5000" -ForegroundColor Cyan
Write-Host " MySQL: localhost:3306" -ForegroundColor Cyan
Write-Host "All queries are routing to monolithic database" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test the setup:" -ForegroundColor Yellow
Write-Host 'Invoke-RestMethod -Uri "http://localhost:5000/query" -Method Post -ContentType "application/json" -Body ''{"query": "SHOW TABLES"}''' -ForegroundColor White