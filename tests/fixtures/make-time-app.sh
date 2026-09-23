#!/usr/bin/env bash
# Usage: make-time-app.sh <dir> — creates a tiny node:http app with a /health test.
set -euo pipefail
d=${1:?dir}; mkdir -p "$d/test"; cd "$d"
cat >package.json <<'EOF'
{ "name": "time-app", "private": true,
  "scripts": { "dev": "node server.js", "test": "node --test" } }
EOF
cat >server.js <<'EOF'
const http = require('node:http');
function handler(req, res) {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end('{"ok":true}');
  }
  res.writeHead(404); res.end();
}
if (require.main === module) {
  const port = process.env.PORT || 3999;
  http.createServer(handler).listen(port, () => console.log(`listening on ${port}`));
}
module.exports = { handler };
EOF
cat >test/health.test.js <<'EOF'
const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const { handler } = require('../server');
test('GET /health returns 200', async () => {
  const srv = http.createServer(handler).listen(0);
  const { port } = srv.address();
  const r = await fetch(`http://localhost:${port}/health`);
  assert.equal(r.status, 200);
  srv.close();
});
EOF
printf '# time-app\nSingle-file node:http server. Handlers live in server.js; tests in test/ use node:test.\n' >README.md
git init -q -b main && git add -A && git -c user.name=hq -c user.email=hq@local commit -qm init
echo "$d"
