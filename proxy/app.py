from flask import Flask, request, jsonify
import mysql.connector
import os
import logging
import time

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GitHubSQLProxy:
    def __init__(self):
        self.migration_phase = int(os.getenv('MIGRATION_PHASE', '1'))
        self.monolith_config = {
            'host': 'mysql-monolith',
            'port': 3306,
            'user': 'github_user',
            'password': 'github_pass',
            'database': 'github_monolith'
        }
        
    def get_monolith_connection(self):
        """Get connection to monolithic database"""
        max_retries = 5
        for attempt in range(max_retries):
            try:
                return mysql.connector.connect(**self.monolith_config)
            except mysql.connector.Error as e:
                logger.warning(f"Connection attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2)
                else:
                    raise
    
    def execute_query(self, query):
        """Execute query - Phase 1: All queries go to monolith"""
        logger.info(f"Phase {self.migration_phase}: Executing query: {query[:100]}...")
        
        try:
            conn = self.get_monolith_connection()
            cursor = conn.cursor(dictionary=True)
            cursor.execute(query)
            
            query_upper = query.strip().upper()
            if query_upper.startswith(('SELECT', 'SHOW', 'DESCRIBE', 'EXPLAIN')):
                results = cursor.fetchall()
                return {
                    'status': 'success', 
                    'data': results, 
                    'target': 'monolith',
                    'phase': self.migration_phase,
                    'row_count': len(results)
                }
            else:
                conn.commit()
                return {
                    'status': 'success', 
                    'affected_rows': cursor.rowcount, 
                    'target': 'monolith',
                    'phase': self.migration_phase
                }
                
        except mysql.connector.Error as e:
            logger.error(f"Database error: {e}")
            return {'status': 'error', 'message': str(e)}
        except Exception as e:
            logger.error(f"Proxy error: {e}")
            return {'status': 'error', 'message': str(e)}
        finally:
            if 'conn' in locals() and conn.is_connected():
                conn.close()

proxy = GitHubSQLProxy()

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy', 
        'migration_phase': proxy.migration_phase,
        'timestamp': time.time()
    })

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

@app.route('/phase', methods=['GET'])
def migration_phase():
    return jsonify({'current_phase': proxy.migration_phase})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)