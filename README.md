# GitHub Data Migration Without Downtime - Local Reproduction

This project reproduces GitHub's approach to partitioning their relational databases for scale without downtime, as described in their [engineering blog](https://github.blog/engineering/infrastructure/partitioning-githubs-relational-databases-scale/).

## Overview

This implementation demonstrates GitHub's partitioning strategy:
- **Functional Partitioning**: Breaking monolithic database into logical domains
- **SQL Proxy Layer**: Custom routing with gradual migration phases
- **Zero-Downtime Migration**: Seamless transition from monolith to partitions
- **Dual-Write Strategy**: Ensuring data consistency during migration
- **Cross-partition Query Handling**: Managing relationships across domains

## Architecture Evolution

### Phase 1: Proxy Setup (Initial State)
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Application   │────│   SQL Proxy  │────│   Monolithic    │
│                 │    │   (Router)   │    │    Database     │
└─────────────────┘    └──────────────┘    └─────────────────┘
```

### Phase 2-4: Dual-Write & Read Migration
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Application   │────│   SQL Proxy  │────│   Monolithic    │
│                 │    │   (Router)   │    │    Database     │
└─────────────────┘    └──────────────┘    └─────────────────┘
                              │                       
                              │            ┌─────────────────┐
                              └────────────│   Partitioned   │
                                           │   Databases     │
                                           │ (users, repos,  │
                                           │ issues, gists)  │
                                           └─────────────────┘
```

### Phase 5: Final State (Partitions Only)
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Application   │────│   SQL Proxy  │────│   Partitioned   │
│                 │    │   (Router)   │    │   Databases     │
└─────────────────┘    └──────────────┘    └─────────────────┘
```

## Migration Strategy (GitHub's Approach)

### Phase 1: Proxy Setup
- Deploy SQL Proxy in front of monolithic database
- **All reads and writes go to monolith**
- Establish monitoring and query pattern analysis
- Zero application changes required

### Phase 2: Partition Creation
- Create partitioned databases (initially empty)
- **Partitions are clones of monolith schema** (subset of tables per domain)
- Set up replication infrastructure
- Validate schema compatibility

### Phase 3: Data Replication & Dual-Write Phase
- **Phase 3a**: Replicate existing data from monolith to partitions
- **Phase 3b**: Enable dual-write mode after data synchronization
- **Writes go to BOTH monolith and partitions**
- **Reads still come from monolith**
- Data consistency validation and monitoring

### Phase 4: Read Migration
- **Writes continue to both monolith and partitions**
- **Gradually migrate reads to partitions** (domain by domain)
- Cross-partition queries handled by proxy
- Performance testing and validation

### Phase 5: Write Migration & Monolith Removal
- **Switch writes exclusively to partitions**
- **Reads exclusively from partitions**
- Monolith becomes obsolete
- **Remove monolithic database**

## Schema Domains (Functional Partitions)

### 1. Users Domain (Port 3307)
- **users**: User accounts, profiles, authentication
- **user_settings**: User preferences and configurations

### 2. Repositories Domain (Port 3308)
- **repositories**: Repository metadata and settings
- **repository_collaborators**: Access permissions
- **stars**: Repository stars and watches

### 3. Issues Domain (Port 3309)
- **issues**: Issues and pull requests
- **issue_comments**: Comments and discussions

### 4. Gists Domain (Port 3310)
- **gists**: Gist metadata
- **gist_files**: Gist file contents

## Quick Start (PowerShell Commands)

### Prerequisites
- Docker Desktop installed and running
- PowerShell execution policy set to allow scripts

### 1. Phase 1: Setup Proxy and Monolithic Database
```powershell
# Start monolithic database and SQL proxy
.\scripts\start.ps1

# Test the setup
.\scripts\test-setup.ps1
```

### 2. Phase 2: Create Partition Databases
```powershell
# Create empty partition databases with domain-specific schemas
.\scripts\start-phase2.ps1
```

### 3. Phase 3a: Data Replication
```powershell
# Replicate existing data from monolith to partitions
.\scripts\start-data-replication.ps1
```

### 4. Phase 3b: Enable Dual-Write Mode
```powershell
# Enable dual-write after data synchronization
.\scripts\start-phase3.ps1
```

### 5. Test Dual-Write Functionality
```powershell
# Test that writes go to both monolith and partitions
$body = @{ query = "INSERT INTO users (username, email, password_hash, full_name) VALUES ('testuser2', 'test2@example.com', 'hashed', 'Test User 2')" } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:5000/query" -Method Post -ContentType "application/json" -Body $body
```

### 6. Monitor Migration Status
```powershell
# Check proxy health and current phase
Invoke-RestMethod -Uri "http://localhost:5000/health" -Method Get

# View domain mappings and migration order
Invoke-RestMethod -Uri "http://localhost:5000/domains" -Method Get
```

## Key Implementation Details

### SQL Proxy Capabilities
- **Phase-aware routing**: Routes queries based on current migration phase and schema domains
- **Domain detection**: Uses [`schema_domains.yml`](domains/schema_domains.yml) to determine table ownership
- **Dual-write coordination**: Ensures consistency between monolith and partitions
- **Cross-domain validation**: Warns about queries spanning multiple domains
- **Emergency controls**: Can disable dual-write mode for rollback

### Schema Domain Configuration
The [`domains/schema_domains.yml`](domains/schema_domains.yml) file defines:
- **Table ownership**: Which domain each table belongs to
- **Migration priorities**: Order of domain migration based on dependencies
- **Cross-domain relationships**: Foreign key relationships across partitions
- **Database configurations**: Connection details for each partition

### Data Consistency & Safety
- **Monolith-first writes**: Monolith remains primary source of truth during dual-write
- **Data replication verification**: Row count validation between monolith and partitions
- **Gradual migration**: One domain at a time to minimize risk
- **Rollback capability**: Can revert to previous phase if issues occur

### Current Database Ports
- **Monolith**: `localhost:3306` (github_monolith)
- **Users Partition**: `localhost:3307` (github_users)
- **Repositories Partition**: `localhost:3308` (github_repositories)
- **Issues Partition**: `localhost:3309` (github_issues)
- **Gists Partition**: `localhost:3310` (github_gists)
- **SQL Proxy**: `localhost:5000` (HTTP API)

## API Endpoints

### Health & Status
```powershell
# Check proxy health
GET http://localhost:5000/health

# View current migration phase
GET http://localhost:5000/phase

# View domain configuration
GET http://localhost:5000/domains
```

### Query Execution
```powershell
# Execute SQL query
POST http://localhost:5000/query
Content-Type: application/json
{
  "query": "SELECT * FROM users LIMIT 5"
}
```

### Migration Controls
```powershell
# Change migration phase
POST http://localhost:5000/phase
Content-Type: application/json
{
  "phase": 3
}

# Enable/disable dual-write
POST http://localhost:5000/enable-dual-write
POST http://localhost:5000/disable-dual-write
```

## Directory Structure

```
├── docker/                           # Docker configurations
│   └── docker-compose.yml           # All database services
├── databases/                        # Database schemas
│   ├── monolith/                    # Original monolithic schema
│   │   └── schema.sql               # Complete GitHub-like schema
│   └── partitions/                  # Domain-specific schemas
│       ├── users_partition.sql      # Users domain tables
│       ├── repositories_partition.sql # Repositories domain tables
│       ├── issues_partition.sql     # Issues domain tables
│       └── gists_partition.sql      # Gists domain tables
├── proxy/                           # SQL Proxy implementation
│   ├── app.py                       # Flask-based proxy with domain routing
│   ├── Dockerfile                   # Proxy container configuration
│   └── requirements.txt             # Python dependencies
├── scripts/                         # PowerShell migration scripts
│   ├── start.ps1                    # Phase 1: Setup proxy and monolith
│   ├── start-phase2.ps1             # Phase 2: Create partitions
│   ├── start-data-replication.ps1   # Phase 3a: Data replication
│   ├── start-phase3.ps1             # Phase 3b: Enable dual-write
│   └── test-setup.ps1               # Test and validation scripts
├── domains/                         # Domain configuration
│   └── schema_domains.yml           # Table-to-domain mappings
└── README.md                        # This file
```

## Monitoring & Validation

### Query Routing Verification
```powershell
# Check which domain a query targets
$body = @{ query = "INSERT INTO repositories (name, owner_id, description) VALUES ('test-repo', 1, 'Test repository')" } | ConvertTo-Json
$response = Invoke-RestMethod -Uri "http://localhost:5000/query" -Method Post -ContentType "application/json" -Body $body
Write-Host "Domain: $($response.domain), Dual-write: $($response.dual_write)"
```

### Data Consistency Checks
```powershell
# Compare row counts between monolith and partitions
foreach ($table in @('users', 'repositories', 'issues', 'gists')) {
    $body = @{ query = "SELECT COUNT(*) as count FROM $table" } | ConvertTo-Json
    $count = (Invoke-RestMethod -Uri "http://localhost:5000/query" -Method Post -ContentType "application/json" -Body $body).data[0].count
    Write-Host "$table : $count rows"
}
```

## Next Phases (To Be Implemented)

### Phase 4: Read Migration
- Implement read routing to partitions
- Gradual migration by domain based on dependency order
- Cross-partition query handling

### Phase 5: Complete Migration
- Switch writes exclusively to partitions
- Remove monolithic database
- Final validation and cleanup

## Troubleshooting

### Common Issues
1. **Proxy connection errors**: Ensure all containers are running with `docker ps`
2. **Data replication failures**: Check database connectivity and credentials
3. **Cross-domain query warnings**: Review [`schema_domains.yml`](domains/schema_domains.yml) configuration

### Emergency Rollback
```powershell
# Disable dual-write and revert to monolith
Invoke-RestMethod -Uri "http://localhost:5000/disable-dual-write" -Method Post
$body = @{ phase = 1 } | ConvertTo-Json
Invoke-RestMethod -Uri "http://localhost:5000/phase" -Method Post -ContentType "application/json" -Body $body
```

## References

This project implements the strategy described in:
- [Partitioning GitHub's relational databases to handle scale](https://github.blog/engineering/infrastructure/partitioning-githubs-relational-databases-scale/)
- [GitHub's Database Migration Strategy - YouTube](https://www.youtube.com/watch?v=Tq1fif3rcnQ)

## License

MIT License - see [`LICENSE`](LICENSE) file for details.