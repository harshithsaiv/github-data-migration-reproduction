-- Issues Domain Partition
CREATE DATABASE IF NOT EXISTS github_issues;
USE github_issues;

-- Issues Domain Tables Only
CREATE TABLE issues (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    repository_id BIGINT NOT NULL,  -- References repositories.id (cross-domain)
    author_id BIGINT NOT NULL,      -- References users.id (cross-domain)
    title VARCHAR(255) NOT NULL,
    body TEXT,
    state ENUM('open', 'closed') DEFAULT 'open',
    is_pull_request BOOLEAN DEFAULT FALSE,
    number INT NOT NULL,
    comments_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    closed_at TIMESTAMP NULL,
    -- Note: No FK constraints to other domains
    UNIQUE KEY unique_repo_number (repository_id, number),
    INDEX idx_repository (repository_id),
    INDEX idx_author (author_id),
    INDEX idx_state (state)
);

CREATE TABLE issue_comments (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    issue_id BIGINT NOT NULL,
    author_id BIGINT NOT NULL,      -- References users.id (cross-domain)
    body TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE,
    -- Note: No FK constraint to users.id since it's in different database
    INDEX idx_issue (issue_id),
    INDEX idx_author (author_id)
);