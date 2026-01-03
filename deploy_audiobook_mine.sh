#!/usr/bin/env bash

# --- Configuration (Aligned with your Radio Server) ---
PORT_ARG=${1:-3005}
REPO_URL="https://github.com/dylan7474/audioBookPlayer.git"
TARGET_DIR="/mnt/media/docker/audiobookplayer/src"
BOOKS_DIR="/mnt/media/Audio/Audible"  # Updated as per your feedback
DATA_DIR="/mnt/media/docker/audiobookplayer/data"
SERVICE_UID=1002
SERVICE_GID=1002

echo "=== Deploying AudioBookPlayer with Seeking Support ==="

# 1. Clean and Clone
mkdir -p "$DATA_DIR"
mkdir -p "$(dirname "$TARGET_DIR")"
[ -d "$TARGET_DIR" ] && rm -rf "$TARGET_DIR"
git clone "$REPO_URL" "$TARGET_DIR"
cd "$TARGET_DIR"

# 2. Generate the Patched server.js with Range Request support
cat <<EOF > server.js
const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const PORT = Number(process.env.PORT) || 3000;
const STATIC_ROOT = process.env.STATIC_ROOT || __dirname;
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'bookmarks.json');

const MIME_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.mp3': 'audio/mpeg',
    '.m4b': 'audio/mp4',
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
        const contentType = MIME_TYPES[ext] || 'audio/mpeg';
        const range = req.headers.range;

        if (range) {
            const parts = range.replace(/bytes=/, "").split("-");
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : stats.size - 1;
            const chunksize = (end - start) + 1;
            const file = fs.createReadStream(filePath, {start, end});
            const head = {
                'Content-Range': \`bytes \${start}-\${end}/\${stats.size}\`,
                'Accept-Ranges': 'bytes',
                'Content-Length': chunksize,
                'Content-Type': contentType,
            };
            res.writeHead(206, head);
            file.pipe(res);
        } else {
            const head = {
                'Content-Length': stats.size,
                'Content-Type': contentType,
                'Accept-Ranges': 'bytes',
            };
            res.writeHead(200, head);
            fs.createReadStream(filePath).pipe(res);
        }
    });
};

http.createServer((req, res) => {
    const url = new URL(req.url, \`http://\${req.headers.host}\`);
    if (url.pathname.startsWith('/api/bookmarks')) return handleApiBookmarks(req, res, url);
    serveStatic(req, res, url);
}).listen(PORT, () => console.log(\`Server running on port \${PORT}\`));
EOF

# 3. Create Dockerfile
cat <<EOF > Dockerfile
FROM node:20-slim
WORKDIR /app
COPY server.js index.html ./
RUN mkdir books data && chown -R $SERVICE_UID:$SERVICE_GID /app
USER $SERVICE_UID
EXPOSE $PORT_ARG
ENV PORT=$PORT_ARG
ENV DATA_DIR=/app/data
ENV STATIC_ROOT=/app
CMD ["node", "server.js"]
EOF

# 4. Finalize and Launch
sudo chown -R $SERVICE_UID:$SERVICE_GID "$DATA_DIR"
docker build -t audiobook-player .
docker stop audiobook-player 2>/dev/null || true
docker rm audiobook-player 2>/dev/null || true

docker run -d \
--name audiobook-player \
-p "$PORT_ARG":"$PORT_ARG" \
-v "$BOOKS_DIR":/app/books:ro \
-v "$DATA_DIR":/app/data \
--restart unless-stopped \
audiobook-player

echo "Deployed at http://$(hostname -I | awk '{print $1}'):$PORT_ARG"
