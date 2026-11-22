'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { createServer } = require('../server');

let server;
let base;

test.before(async () => {
  server = createServer();
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => new Promise((r) => server.close(r)));

test('GET /health retourne UP', async () => {
  const res = await fetch(`${base}/health`);
  assert.strictEqual(res.status, 200);
  assert.deepStrictEqual(await res.json(), { status: 'UP' });
});

test('GET /version retourne la version du package', async () => {
  const res = await fetch(`${base}/version`);
  const body = await res.json();
  assert.strictEqual(res.status, 200);
  assert.match(body.version, /^\d+\.\d+\.\d+$/);
});

test('POST /todos cree une tache puis GET /todos la liste', async () => {
  const post = await fetch(`${base}/todos`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'ecrire le rapport' }),
  });
  assert.strictEqual(post.status, 201);
  const list = await (await fetch(`${base}/todos`)).json();
  assert.strictEqual(list.length, 1);
  assert.strictEqual(list[0].title, 'ecrire le rapport');
});

test('POST /todos sans titre retourne 400', async () => {
  const res = await fetch(`${base}/todos`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{}',
  });
  assert.strictEqual(res.status, 400);
});

test('route inconnue retourne 404', async () => {
  const res = await fetch(`${base}/nope`);
  assert.strictEqual(res.status, 404);
});
