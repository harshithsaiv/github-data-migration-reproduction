-- Repositories Domain Partition  
CREATE DATABASE IF NOT EXISTS github_repositories;
USE github_repositories;

-- Repositories Domain Tables Only
CREATE TABLE repositories (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    owner_id BIGINT NOT NULL,  -- References users.id (cross-domain)
    description TEXT,
    is_private BOOLEAN DEFAULT FALSE,
    is_fork BOOLEAN DEFAULT FALSE,
    parent_id BIGINT NULL,
    language VARCHAR(100),
    stars_count INT DEFAULT 0,
    forks_count INT DEFAULT 0,
    watchers_count INT DEFAULT 0,
    size_kb BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- Note: No FK constraint to users.id since it's in different database
    INDEX idx_owner (owner_id),
    INDEX idx_name (name),
    INDEX idx_language (language)
);

CREATE TABLE repository_collaborators (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    repository_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,  -- References users.id (cross-domain)
    permission ENUM('read', 'write', 'admin') DEFAULT 'read',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (repository_id) REFERENCES repositories(id) ON DELETE CASCADE,
    -- Note: No FK constraint to users.id since it's in different database
    UNIQUE KEY unique_repo_user (repository_id, user_id)
);

CREATE TABLE stars (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL,      -- References users.id (cross-domain)
    repository_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Note: No FK constraints to other domains
    FOREIGN KEY (repository_id) REFERENCES repositories(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_repo_star (user_id, repository_id)
);