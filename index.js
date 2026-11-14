const { createServer } = require('node:http');
const { Pool } = require('pg');

const message = 'Hello world';

if (process.argv.includes('--serve')) {
  const database = process.env.PGHOST
    ? new Pool({ connectionTimeoutMillis: 4000, query_timeout: 4000 })
    : null;

  database?.on('error', (error) => {
    console.error('PostgreSQL connection error:', error.message);
  });

  const server = createServer(async (request, response) => {
    response.setHeader('Content-Type', 'text/plain; charset=utf-8');

    if (request.url !== '/health') {
      response.end(message);
      return;
    }

    try {
      await database?.query('SELECT 1');
      response.end(database ? 'PostgreSQL connected' : 'OK');
    } catch (error) {
      console.error('PostgreSQL health check failed:', error.message);
      response.statusCode = 503;
      response.end('PostgreSQL unavailable');
    }
  });

  async function start() {
    if (database) {
      await database.query('SELECT 1');
      console.log('PostgreSQL connected');
    }

    server.listen(3000, process.env.HOST || '127.0.0.1');
  }

  start().catch((error) => {
    console.error('Application startup failed:', error.message);
    process.exit(1);
  });
} else {
  console.log(message);
}
