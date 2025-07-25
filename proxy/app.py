from flask import Flask, request, jsonify
import mysql.connector
import os
import logging
import time
import yaml

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GitHubSQLProxy:
    def __init__(self):
        self.migration_phase = int(os.getenv('MIGRATION_PHASE', '1'))
        self.dual_write_enabled = False
        self.load_schema_domains()
        self.setup_connections()
        
    def load_schema_domains(self):
        """Load schema domain definitions from YAML file"""
        try:
            with open('/app/domains/schema_domains.yml', 'r') as file:
                domains_config = yaml.safe_load(file)
                
            # Extract just the domain -> tables mapping
            self.schema_domains = {}
            self.domain_configs = {}
            
            for domain, config in domains_config.items():
                if isinstance(config, dict) and 'tables' in config:
                    self.schema_domains[domain] = {'tables': config['tables']}
                    self.domain_configs[domain] = config
                    
            self.cross_domain_relationships = domains_config.get('cross_domain_relationships', [])
            self.migration_config = domains_config.get('migration_config', {})
            
            logger.info(f"Loaded domains: {list(self.schema_domains.keys())}")
            
        except FileNotFoundError:
            logger.warning("schema_domains.yml not found, using default mapping")
            self.schema_domains = {
                'users': {'tables': ['users', 'user_settings']},
                'repositories': {'tables': ['repositories', 'repository_collaborators', 'stars']},
                'issues': {'tables': ['issues', 'issue_comments']},
                'gists': {'tables': ['gists', 'gist_files']}
            }
            self.domain_configs = {}
            self.cross_domain_relationships = []
    
    def setup_connections(self):
        """Setup database connection configurations using schema domains"""
        self.db_configs = {
            'monolith': {
                'host': 'mysql-monolith', 'port': 3306, 'user': 'github_user',
                'password': 'github_pass', 'database': 'github_monolith'
            }
        }
        
        # Add partition connections based on schema domains
        for domain, config in self.domain_configs.items():
            container_host = f"mysql-{domain}"
            db_name = config.get('database_name', f'github_{domain}')
            
            self.db_configs[domain] = {
                'host': container_host,
                'port': 3306,  # Internal container port
                'user': 'github_user',
                'password': 'github_pass',
                'database': db_name
            }
            
        logger.info(f"Configured connections for: {list(self.db_configs.keys())}")
    
    def get_table_domain(self, table_name):
        """Determine which domain a table belongs to using schema_domains.yml"""
        for domain, config in self.schema_domains.items():
            if table_name in config['tables']:
                return domain
        return None
    
    def get_migration_order(self):
        """Get migration order based on dependencies in schema_domains.yml"""
        ordered_domains = []
        
        # Sort by migration_priority if available
        domain_priorities = []
        for domain, config in self.domain_configs.items():
            priority = config.get('migration_priority', 999)
            domain_priorities.append((priority, domain))
        
        domain_priorities.sort()
        return [domain for _, domain in domain_priorities]
    
    def validate_cross_domain_query(self, tables):
        """Validate if cross-domain query is allowed"""
        domains = set()
        for table in tables:
            domain = self.get_table_domain(table)
            if domain:
                domains.add(domain)
        
        if len(domains) > 1:
            logger.warning(f"Cross-domain query detected: {domains}")
            # Check if this cross-domain relationship is defined
            # For now, we'll allow it but log it
            return True
        return True
    
    def parse_query_tables(self, query):
        """Extract table names from SQL query"""
        import re
        pattern = r'\b(?:FROM|JOIN|INTO|UPDATE)\s+([a-zA-Z_][a-zA-Z0-9_]*)'
        tables = re.findall(pattern, query, re.IGNORECASE)
        return tables
    
    def is_write_query(self, query):
        """Check if query is a write operation"""
        query_upper = query.strip().upper()
        return query_upper.startswith(('INSERT', 'UPDATE', 'DELETE'))
    
    def execute_query(self, query):
        """Execute query based on migration phase and schema domains"""
        tables = self.parse_query_tables(query)
        domain = None
        
        if tables:
            primary_table = tables[0]
            domain = self.get_table_domain(primary_table)
            logger.info(f"Query table: {primary_table} -> domain: {domain}")
            
            # Validate cross-domain queries
            self.validate_cross_domain_query(tables)
        
        if self.migration_phase <= 2:
            # Phase 1-2: All queries to monolith
            return self._execute_on_monolith(query)
        elif self.migration_phase == 3:
            # Phase 3: Dual-write only if enabled and it's a write query
            if self.dual_write_enabled and self.is_write_query(query) and domain:
                return self._execute_dual_write(query, domain)
            else:
                return self._execute_on_monolith(query)
        else:
            return {'status': 'error', 'message': f'Unsupported migration phase: {self.migration_phase}'}
    
    def _execute_dual_write(self, query, domain):
        """Execute write operation on both monolith and specific partition"""
        results = []
        
        # Write to monolith first (primary source of truth)
        try:
            monolith_result = self._execute_on_monolith(query)
            results.append({'target': 'monolith', 'result': monolith_result})
            
            if monolith_result['status'] != 'success':
                return monolith_result
                
        except Exception as e:
            logger.error(f"Monolith write failed: {e}")
            return {'status': 'error', 'message': f'Monolith write failed: {e}'}
        
        # Write to partition (secondary)
        try:
            partition_result = self._execute_on_partition(query, domain)
            results.append({'target': domain, 'result': partition_result})
        except Exception as e:
            logger.error(f"Partition {domain} write failed: {e}")
            results.append({'target': domain, 'result': {'status': 'error', 'message': str(e)}})
        
        return {
            'status': 'success',
            'phase': self.migration_phase,
            'dual_write': True,
            'domain': domain,
            'primary_success': monolith_result['status'] == 'success',
            'results': results
        }
    
    def _execute_on_monolith(self, query):
        """Execute query on monolithic database"""
        try:
            conn = self.get_connection('monolith')
            cursor = conn.cursor(dictionary=True)
            cursor.execute(query)
            
            if self.is_write_query(query):
                conn.commit()
                return {
                    'status': 'success', 
                    'affected_rows': cursor.rowcount, 
                    'target': 'monolith',
                    'phase': self.migration_phase
                }
            else:
                results = cursor.fetchall()
                return {
                    'status': 'success', 
                    'data': results, 
                    'target': 'monolith',
                    'phase': self.migration_phase,
                    'row_count': len(results)
                }
                
        except Exception as e:
            logger.error(f"Monolith query failed: {e}")
            return {'status': 'error', 'message': str(e)}
        finally:
            if 'conn' in locals() and conn.is_connected():
                conn.close()
    
    def _execute_on_partition(self, query, domain):
        """Execute query on specific partition"""
        try:
            conn = self.get_connection(domain)
            cursor = conn.cursor(dictionary=True)
            cursor.execute(query)
            
            if self.is_write_query(query):
                conn.commit()
                return {
                    'status': 'success', 
                    'affected_rows': cursor.rowcount, 
                    'target': domain
                }
            else:
                results = cursor.fetchall()
                return {
                    'status': 'success', 
                    'data': results, 
                    'target': domain,
                    'row_count': len(results)
                }
                
        except Exception as e:
            logger.error(f"Partition {domain} query failed: {e}")
            raise
        finally:
            if 'conn' in locals() and conn.is_connected():
                conn.close()
    
    def get_connection(self, target='monolith'):
        """Get database connection"""
        config = self.db_configs[target]
        return mysql.connector.connect(**config)

proxy = GitHubSQLProxy()

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy', 
        'migration_phase': proxy.migration_phase,
        'dual_write_enabled': proxy.dual_write_enabled,
        'loaded_domains': list(proxy.schema_domains.keys()),
        'timestamp': time.time()
    })

@app.route('/domains')
def get_domains():
    """Get schema domain information"""
    return jsonify({
        'domains': proxy.schema_domains,
        'cross_domain_relationships': proxy.cross_domain_relationships,
        'migration_order': proxy.get_migration_order()
    })

# ...existing routes...
@app.route('/query', methods=['POST'])
def execute_query():
    data = request.get_json()
    if not data:
        return jsonify({'status': 'error', 'message': 'Invalid JSON'}), 400
        
    query = data.get('query', '')
    if not query:
        return jsonify({'status': 'error', 'message': 'No query provided'}), 400
    
    result = proxy.execute_query(query)
    return jsonify(result)

@app.route('/phase', methods=['GET', 'POST'])
def migration_phase():
    if request.method == 'POST':
        data = request.get_json()
        new_phase = data.get('phase')
        if new_phase:
            proxy.migration_phase = int(new_phase)
            logger.info(f"Migration phase changed to: {new_phase}")
            return jsonify({'status': 'success', 'new_phase': new_phase})
    return jsonify({'current_phase': proxy.migration_phase, 'dual_write_enabled': proxy.dual_write_enabled})

@app.route('/enable-dual-write', methods=['POST'])
def enable_dual_write():
    proxy.dual_write_enabled = True
    logger.info("Dual-write mode enabled")
    return jsonify({'status': 'success', 'dual_write_enabled': True})

@app.route('/disable-dual-write', methods=['POST'])
def disable_dual_write():
    proxy.dual_write_enabled = False
    logger.info("Dual-write mode disabled")
    return jsonify({'status': 'success', 'dual_write_enabled': False})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)