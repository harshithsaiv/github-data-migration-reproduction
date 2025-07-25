# GitHub Data Migration Without Downtime - Local Reproduction

This project reproduces GitHub's approach to breaking up their single MySQL cluster and migrating tables/schema domains without downtime.

## Overview

This implementation demonstrates:
- Virtual partitioning with schema domains
- Physical migration using Vitess VReplication
- Zero-downtime cutover procedures
- Cross-domain query/transaction linting
- Proxy-based routing with VTGate

## Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Application   │────│   VTGate     │────│  MySQL Shards   │
│   (Rails-like)  │    │   (Proxy)    │    │                 │
└─────────────────┘    └──────────────┘    └─────────────────┘
                              │
                       ┌──────────────┐
                       │  VTTablet    │
                       │ (Per Shard)  │
                       └──────────────┘
```

## Components

### 1. Schema Domains
- **users**: User accounts, profiles, settings
- **repositories**: Repos, collaborators, stars, forks
- **issues**: Issues, comments, labels, milestones
- **gists**: Gists, gist comments, starred gists

### 2. Migration Tools
- **Vitess VReplication**: Online table migration
- **Custom cutover script**: Manual migration approach
- **Linters**: Cross-domain validation

## Quick Start

1. Start the environment:
   ```bash
   docker-compose up -d
   ```

2. Initialize schema domains:
   ```bash
   ./scripts/init-domains.sh
   ```

3. Load sample data:
   ```bash
   ./scripts/load-sample-data.sh
   ```

4. Run a migration:
   ```bash
   ./scripts/migrate-domain.sh gists
   ```

## Directory Structure

```
├── docker/              # Docker configurations
├── schemas/             # Database schemas per domain
├── domains/             # Schema domain definitions
├── scripts/             # Migration and utility scripts
├── linters/             # Cross-domain validation tools
├── playbooks/           # Migration playbooks
└── examples/            # Sample applications and queries
```
