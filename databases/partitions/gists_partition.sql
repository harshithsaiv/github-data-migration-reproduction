-- Gists Domain Partition
CREATE DATABASE IF NOT EXISTS github_gists;
USE github_gists;

-- Gists Domain Tables Only
CREATE TABLE gists (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    owner_id BIGINT NOT NULL,  -- References users.id (cross-domain)
    title VARCHAR(255),
    description TEXT,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    -- Note: No FK constraint to users.id since it's in different database
    INDEX idx_owner (owner_id),
    INDEX idx_public (is_public)
);

CREATE TABLE gist_files (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    gist_id BIGINT NOT NULL,
    filename VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    language VARCHAR(100),
    size_bytes BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (gist_id) REFERENCES gists(id) ON DELETE CASCADE,
    INDEX idx_gist (gist_id)
);