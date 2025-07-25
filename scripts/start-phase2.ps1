Write-Host "Phase 2: Creating Partition Databases" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

# Navigate to docker directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$dockerPath = Join-Path (Split-Path -Parent $scriptPath) "docker"
Set-Location $dockerPath

Write-Host "Starting partition databases..." -ForegroundColor Yellow
docker-compose up -d mysql-users mysql-repositories mysql-issues mysql-gists

Write-Host "Waiting for partition databases to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check each partition database
$partitions = @(
    @{ Name = "Users"; Container = "github-users-db"; Port = "3307" },
    @{ Name = "Repositories"; Container = "github-repos-db"; Port = "3308" },
    @{ Name = "Issues"; Container = "github-issues-db"; Port = "3309" },
    @{ Name = "Gists"; Container = "github-gists-db"; Port = "3310" }
)

foreach ($partition in $partitions) {
    Write-Host "Waiting for $($partition.Name) partition to be ready..." -ForegroundColor Yellow
    
    do {
        Start-Sleep -Seconds 2
        $ready = docker exec $($partition.Container) mysqladmin ping -h localhost --silent
    } while ($LASTEXITCODE -ne 0)

    Write-Host " $($partition.Name) partition is ready!" -ForegroundColor Green
}

Write-Host ""
Write-Host " Phase 2 Complete!" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green
Write-Host "Partition databases created:" -ForegroundColor Cyan
Write-Host "   Users: localhost:3307" -ForegroundColor White
Write-Host "   Repositories: localhost:3308" -ForegroundColor White
Write-Host "   Issues: localhost:3309" -ForegroundColor White
Write-Host "   Gists: localhost:3310" -ForegroundColor White
Write-Host ""
Write-Host "Note: Partitions are empty clones of monolith schema" -ForegroundColor Yellow
Write-Host "Ready for Phase 3: Dual-Write setup" -ForegroundColor Yellow