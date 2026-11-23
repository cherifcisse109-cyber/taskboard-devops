'use strict';
const http = require('http');
const pkg = require('./package.json');

function createServer() {
  const todos = [];
  let nextId = 1;

  const send = (res, code, body) => {
    res.writeHead(code, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body));
  };

  return http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/health') {
      return send(res, 200, { status: 'UP' });
    }
    if (req.method === 'GET' && req.url === '/version') {
      return send(res, 200, { name: pkg.name, version: pkg.version, node: process.version });
    }
    if (req.method === 'GET' && req.url === '/todos') {
      return send(res, 200, todos);
    }
    if (req.method === 'POST' && req.url === '/todos') {
      let data = '';
      req.on('data', (c) => { data += c; if (data.length > 1e5) req.destroy(); });
      req.on('end', () => {
        try {
          const { title } = JSON.parse(data || '{}');
          if (!title || typeof title !== 'string') return send(res, 400, { error: 'title required' });
          const todo = { id: nextId++, title, done: false };
          todos.push(todo);
          return send(res, 201, todo);
        } catch (e) {
          return send(res, 400, { error: 'invalid JSON' });
        }
      });
      return;
    }
  const m = req.url.match(/^\/todos\/(\d+)$/);
if (req.method === 'DELETE' && m) {
const idx = todos.findIndex((t) => t.id === Number(m[1]));
if (idx === -1) return send(res, 404, { error: 'todo not found' });
todos.splice(idx, 1);
res.writeHead(204);
return res.end();
}
return send(res, 404, { error: 'not found' });
  });
}

module.exports = { createServer };

if (require.main === module) {
  const port = process.env.PORT || 3000;
  createServer().listen(port, '0.0.0.0', () => console.log(`TaskBoard API listening on ${port}`));
}
