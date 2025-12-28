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
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.mp3': 'audio/mpeg',
};

const ensureDataFile = () => {
    if (!fs.existsSync(DATA_DIR)) {
        fs.mkdirSync(DATA_DIR, { recursive: true });
    }
    if (!fs.existsSync(DATA_FILE)) {
        fs.writeFileSync(DATA_FILE, JSON.stringify({}, null, 2));
    }
};

const loadBookmarks = () => {
    try {
        ensureDataFile();
        const raw = fs.readFileSync(DATA_FILE, 'utf8');
        return raw ? JSON.parse(raw) : {};
    } catch (err) {
        console.error('Failed to load bookmarks:', err);
        return {};
    }
};

const saveBookmarks = (data) => {
    ensureDataFile();
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
};

const sendJson = (res, statusCode, payload) => {
    const body = JSON.stringify(payload);
    res.writeHead(statusCode, {
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Length': Buffer.byteLength(body),
    });
    res.end(body);
};

const handleApiBookmarks = (req, res, url) => {
    const user = url.searchParams.get('user');
    if (!user) {
        sendJson(res, 400, { error: 'Missing user id.' });
        return;
    }

    if (req.method === 'GET') {
        const data = loadBookmarks();
        const entry = data[user] || { playbackPositions: {} };
        sendJson(res, 200, entry);
        return;
    }

    if (req.method === 'POST') {
        let body = '';
        req.on('data', chunk => {
            body += chunk;
            if (body.length > 1024 * 1024) {
                body = '';
                res.writeHead(413);
                res.end();
                req.destroy();
            }
        });
        req.on('end', () => {
            try {
                const payload = body ? JSON.parse(body) : {};
                const playbackPositions = payload.playbackPositions || {};
                if (typeof playbackPositions !== 'object') {
                    sendJson(res, 400, { error: 'Invalid playbackPositions payload.' });
                    return;
                }
                const data = loadBookmarks();
                data[user] = {
                    playbackPositions,
                    updatedAt: new Date().toISOString(),
                };
                saveBookmarks(data);
                sendJson(res, 200, { ok: true });
            } catch (err) {
                sendJson(res, 400, { error: 'Invalid JSON payload.' });
            }
        });
        return;
    }

    res.writeHead(405, { Allow: 'GET, POST' });
    res.end();
};

const serveStatic = (req, res, url) => {
    let pathname = decodeURIComponent(url.pathname);
    if (pathname === '/') {
        pathname = '/index.html';
    }
    const normalizedPath = path.normalize(pathname).replace(/^\.+/, '');
    const filePath = path.join(STATIC_ROOT, normalizedPath);
    if (!filePath.startsWith(path.resolve(STATIC_ROOT))) {
        res.writeHead(403);
        res.end();
        return;
    }

    fs.stat(filePath, (err, stats) => {
        if (err) {
            res.writeHead(404);
            res.end();
            return;
        }
        if (stats.isDirectory()) {
            const indexPath = path.join(filePath, 'index.html');
            fs.readFile(indexPath, (indexErr, indexContent) => {
                if (indexErr) {
                    res.writeHead(403);
                    res.end();
                    return;
                }
                res.writeHead(200, { 'Content-Type': MIME_TYPES['.html'] });
                res.end(indexContent);
            });
            return;
        }

        const ext = path.extname(filePath).toLowerCase();
        const contentType = MIME_TYPES[ext] || 'application/octet-stream';
        fs.readFile(filePath, (readErr, content) => {
            if (readErr) {
                res.writeHead(404);
                res.end();
                return;
            }
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content);
        });
    });
};

const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname.startsWith('/api/bookmarks')) {
        handleApiBookmarks(req, res, url);
        return;
    }
    serveStatic(req, res, url);
});

server.listen(PORT, () => {
    console.log(`AudioBookPlayer server running on http://127.0.0.1:${PORT}`);
});
