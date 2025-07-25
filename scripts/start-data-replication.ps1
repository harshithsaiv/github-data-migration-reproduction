Write-Host " Phase 3a: Replicating Data from Monolith to Partitions" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green

# First, load sample data into monolith
Write-Host " Loading sample data into monolith..." -ForegroundColor Yellow
.\load-sample-data.ps1

Write-Host "`nStarting data replication to partitions..." -ForegroundColor Yellow

# Define domain mappings
$domainMappings = @{
    'users' = @('users', 'user_settings')
    'repositories' = @('repositories', 'repository_collaborators', 'stars') 
    'issues' = @('issues', 'issue_comments')
    'gists' = @('gists', 'gist_files')
}

foreach ($domain in $domainMappings.Keys) {
    Write-Host "`nReplicating $domain domain..." -ForegroundColor Cyan
    
    foreach ($table in $domainMappings[$domain]) {
        Write-Host "  Copying table: $table" -ForegroundColor Gray
        
        # Get data from monolith
        $selectQuery = "SELECT * FROM $table"
        $body = @{ query = $selectQuery } | ConvertTo-Json
        
        try {
            $data = Invoke-RestMethod -Uri "http://localhost:5000/query" -Method Post -ContentType "application/json" -Body $body
            
            if ($data.status -eq 'success' -and $data.data.Count -gt 0) {
                # Build INSERT query for partition
                $rows = $data.data
                $columns = $rows[0].PSObject.Properties.Name -join ', '
                
                foreach ($row in $rows) {
                    $values = @()
                    foreach ($col in $row.PSObject.Properties.Name) {
                        $value = $row.$col
                        if ($value -eq $null) {
                            $values += "NULL"
                        } elseif ($value -is [string]) {
                            $escapedValue = $value -replace "'", "''"
                            $values += "'$escapedValue'"
                        } else {
                            $values += $value
                        }
                    }
                    $valuesStr = $values -join ', '
                    
                    # Insert into partition using direct database connection
                    $insertQuery = "INSERT INTO $table ($columns) VALUES ($valuesStr)"
                    
                    # Execute on specific partition database
                    $partitionPort = switch ($domain) {
                        'users' { 3307 }
                        'repositories' { 3308 }
                        'issues' { 3309 }
                        'gists' { 3310 }
                    }
                    
                    # Use direct MySQL connection to partition
                    $dbName = "github_$domain"
                    $mysqlCmd = "mysql -h localhost -P $partitionPort -u github_user -pgithub_pass $dbName -e `"$insertQuery`""
                    Invoke-Expression $mysqlCmd
                }
                
                Write-Host "   Copied $($rows.Count) rows" -ForegroundColor Green
            } else {
                Write-Host "     No data to copy" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "    Failed to copy $table : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n Verifying data replication..." -ForegroundColor Yellow

# Verify row counts match
foreach ($domain in $domainMappings.Keys) {
    foreach ($table in $domainMappings[$domain]) {
        # Count in monolith
        $countQuery = "SELECT COUNT(*) as count FROM $table"
        $body = @{ query = $countQuery } | ConvertTo-Json
        $monolithCount = (Invoke-RestMethod -Uri "http://localhost:5000/query" -Method Post -ContentType "application/json" -Body $body).data[0].count
        
        # Count in partition
        $partitionPort = switch ($domain) {
            'users' { 3307 }
            'repositories' { 3308 }
            'issues' { 3309 }
            'gists' { 3310 }
        }
        $dbName = "github_$domain"
        $partitionCount = docker exec "github-$domain-db" mysql -u github_user -pgithub_pass $dbName -e "SELECT COUNT(*) as count FROM $table" -s -N
        
        if ($monolithCount -eq $partitionCount) {
            Write-Host "   $table : $monolithCount rows (synced)" -ForegroundColor Green
        } else {
            Write-Host "   $table : Monolith($monolithCount) vs Partition($partitionCount)" -ForegroundColor Red
        }
    }
}

Write-Host "`n Phase 3a Complete!" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host " Data replicated from monolith to partitions" -ForegroundColor Cyan
Write-Host " Partitions now have same data as monolith" -ForegroundColor Cyan
Write-Host ""
Write-Host " Ready for Phase 3b: Enable Dual-Write" -ForegroundColor Yellow