const { createServer } = require('node:http');

const message = 'Hello world';

if (process.argv.includes('--serve')) {
  const server = createServer((_request, response) => {
    response.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end(message);
  });

  server.listen(3000, '127.0.0.1');
} else {
  console.log(message);
}
