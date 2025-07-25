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

### Phase 3: Dual-Write Phase
- **Writes go to BOTH monolith and partitions**
- **Reads still come from monolith**
- Data synchronization and consistency validation
- Monitor performance impact of dual writes

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

### 1. Users Domain
- **users**: User accounts, profiles, authentication
- **user_settings**: User preferences and configurations
- **user_profiles**: Extended user information

### 2. Repositories Domain  
- **repositories**: Repository metadata and settings
- **repository_collaborators**: Access permissions
- **stars**: Repository stars and watches
- **repository_forks**: Fork relationships

### 3. Issues Domain
- **issues**: Issues and pull requests
- **issue_comments**: Comments and discussions
- **labels**: Issue labeling system
- **milestones**: Project milestones

### 4. Gists Domain
- **gists**: Gist metadata
- **gist_files**: Gist file contents
- **gist_comments**: Gist discussions
- **starred_gists**: User gist favorites

## Quick Start

1. Start the complete environment:
   ```bash
   docker-compose up -d
   ```

2. **Phase 1**: Initialize monolithic database and proxy:
   ```bash
   ./scripts/phase1-setup-proxy.sh
   ```

3. Load sample GitHub-like data:
   ```bash
   ./scripts/load-sample-data.sh
   ```

4. **Phase 2**: Create partition databases (clones):
   ```bash
   ./scripts/phase2-create-partitions.sh
   ```

5. **Phase 3**: Start dual-write mode:
   ```bash
   ./scripts/phase3-enable-dual-write.sh
   ```

6. **Phase 4**: Migrate reads to partitions:
   ```bash
   ./scripts/phase4-migrate-reads.sh users
   ./scripts/phase4-migrate-reads.sh repositories
   # ... continue for each domain
   ```

7. **Phase 5**: Switch writes and remove monolith:
   ```bash
   ./scripts/phase5-switch-writes.sh
   ./scripts/phase5-remove-monolith.sh
   ```

8. Test the final partitioned setup:
   ```bash
   ./scripts/test-partitioned-queries.sh
   ```

## Key Implementation Details

### SQL Proxy Capabilities
- **Phase-aware routing**: Routes queries based on current migration phase
- **Dual-write coordination**: Ensures consistency between monolith and partitions
- **Cross-partition joins**: Handles relationships across domains
- **Query rewriting**: Modifies queries for partition-specific schemas
- **Monitoring**: Tracks migration progress and performance

### Data Consistency
- **Write validation**: Ensures data written to both monolith and partitions
- **Read verification**: Compares results between monolith and partitions
- **Rollback capability**: Can revert to previous phase if issues occur
- **Incremental migration**: Migrates one domain at a time

## Directory Structure

```
├── docker/                    # Docker configurations
├── databases/                 # Database schemas and migrations
│   ├── monolith/             # Original monolithic schema
│   └── partitions/           # Partitioned schemas per domain
├── proxy/                     # SQL Proxy implementation
├── applications/              # Sample GitHub-like applications
├── scripts/                   # Phase-specific migration scripts
├── monitoring/                # Migration progress tracking
└── docs/                      # Detailed migration documentation
```

## References

This project implements the strategy described in:
- [Partitioning GitHub's relational databases to handle scale](https://github.blog/engineering/infrastructure/partitioning-githubs-relational-databases-scale/)
- [GitHub's Database Migration Strategy - YouTube](https://www.youtube.com/watch?v=Tq1fif3rcnQ)