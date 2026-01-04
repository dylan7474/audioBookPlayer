#!/usr/bin/env bash

# --- Configuration ---
PORT_ARG=${1:-3000}
REPO_URL="https://github.com/dylan7474/audioBookPlayer.git"
TARGET_DIR="$HOME/audiobookplayer"
BOOKS_DIR="$HOME/my_audiobooks"
DATA_DIR="$HOME/audiobook_data"

echo "=== AudioBookPlayer Automated Update & Deploy ==="

# 1. Clean and Clone
if [ -d "$TARGET_DIR" ]; then
    echo "[1/4] Cleaning old directory and pulling fresh code..."
    rm -rf "$TARGET_DIR"
fi
git clone "$REPO_URL" "$TARGET_DIR"
cd "$TARGET_DIR"

# 2. Create the Patched server.js from scratch
# This version includes the Directory Listing logic required for Server Mode
echo "[2/4] Generating patched server.js..."
cat <<EOF > server.js
const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const PORT = Number(process.env.PORT) || 3000;
const STATIC_ROOT = process.env.STATIC_ROOT || __dirname;
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const DATA_FILE = process.env.DATA_FILE || path.join(DATA_DIR, 'bookmarks.json');

const MIME_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.mp3': 'audio/mpeg',
};

const ensureDataFile = () => {
    if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
    if (!fs.existsSync(DATA_FILE)) fs.writeFileSync(DATA_FILE, JSON.stringify({}, null, 2));
};

const loadBookmarks = () => {
    try { ensureDataFile(); return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8') || '{}'); }
    catch (err) { return {}; }
};

const saveBookmarks = (data) => {
    ensureDataFile();
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
};

const sendJson = (res, code, payload) => {
    const body = JSON.stringify(payload);
    res.writeHead(code, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
    res.end(body);
};

const handleApiBookmarks = (req, res, url) => {
    const user = url.searchParams.get('user');
    if (!user) return sendJson(res, 400, { error: 'Missing user id.' });

    if (req.method === 'GET') {
        const data = loadBookmarks();
        return sendJson(res, 200, data[user] || { playbackPositions: {} });
    }

    if (req.method === 'POST') {
        let body = '';
        req.on('data', chunk => { body += chunk; });
        req.on('end', () => {
            try {
                const data = loadBookmarks();
                data[user] = { playbackPositions: JSON.parse(body).playbackPositions || {}, updatedAt: new Date().toISOString() };
                saveBookmarks(data);
                sendJson(res, 200, { ok: true });
            } catch (err) { sendJson(res, 400, { error: 'Invalid JSON' }); }
        });
        return;
    }
    res.writeHead(405); res.end();
};

const serveStatic = (req, res, url) => {
    const pathname = decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname);
    const filePath = path.join(STATIC_ROOT, path.normalize(pathname).replace(/^\\.+/, ''));

    fs.stat(filePath, (err, stats) => {
        if (err) { res.writeHead(404); return res.end(); }

        if (stats.isDirectory()) {
            const indexPath = path.join(filePath, 'index.html');
            if (fs.existsSync(indexPath)) {
                res.writeHead(200, { 'Content-Type': MIME_TYPES['.html'] });
                return res.end(fs.readFileSync(indexPath));
            }
            // Directory Listing logic for Server Mode scanning
            fs.readdir(filePath, (err, files) => {
                if (err) { res.writeHead(500); return res.end(); }
                const html = files.map(f => {
                    const isDir = fs.statSync(path.join(filePath, f)).isDirectory();
                    return \`<a href="\${isDir ? f + '/' : f}">\${f}</a>\`;
                }).join('<br>');
                res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
                res.end(\`<html><body>\${html}</body></html>\`);
            });
            return;
        }

        const ext = path.extname(filePath).toLowerCase();
        res.writeHead(200, { 'Content-Type': MIME_TYPES[ext] || 'application/octet-stream' });
        fs.createReadStream(filePath).pipe(res);
    });
};

http.createServer((req, res) => {
    const url = new URL(req.url, \`http://\${req.headers.host}\`);
    if (url.pathname.startsWith('/api/bookmarks')) return handleApiBookmarks(req, res, url);
    serveStatic(req, res, url);
}).listen(PORT, () => console.log(\`Server running on port \${PORT}\`));
EOF

# 3. Create Dockerfile
echo "[3/4] Preparing Dockerfile..."
cat <<EOF > Dockerfile
FROM node:20-slim
WORKDIR /app
COPY server.js index.html ./
RUN mkdir books data
EXPOSE $PORT_ARG
ENV PORT=$PORT_ARG
ENV DATA_DIR=/app/data
ENV STATIC_ROOT=/app
CMD ["node", "server.js"]
EOF

# 4. Build and Launch
echo "[4/4] Building and starting container..."
mkdir -p "$BOOKS_DIR" "$DATA_DIR"
docker build -t audiobook-player .
docker stop audiobook-player 2>/dev/null || true
docker rm audiobook-player 2>/dev/null || true

docker run -d \
  --name audiobook-player \
  -p "$PORT_ARG":"$PORT_ARG" \
  -v "$BOOKS_DIR":/app/books \
  -v "$DATA_DIR":/app/data \
  --restart unless-stopped \
  audiobook-player

echo "================================================="
echo "Deployment Successful on port: $PORT_ARG"
echo "================================================="
