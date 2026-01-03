# AudioBookPlayer

AudioBookPlayer is a single-page, HTML-based audiobook player that can scan a server-side `books/`
folder or load local folders of MP3s in the browser. It keeps your place per track, offers a
sleep timer, and provides lightweight diagnostics for playback issues.

## Build on Linux

The player is static HTML with no build step. Deploy by serving `index.html` and a `books/`
directory next to it.

## Basic Controls

- **Navigation Tabs:** Use Library, Player, Settings, and Logs to move between app screens.
- **Scan Server (./books):** Load MP3s from a `books/` directory served by your web server.
- **Browse Local Folder:** Select a local directory of MP3s to play in-browser.
- **Playback:** Use the Player screen controls, or drag the seek bar to jump to a timestamp.
- **Sleep Timer:** Use the 15/30 minute buttons on the Player screen to pause playback automatically.
- **Server Sync (optional):** When `/api/bookmarks` is available, playback positions are merged, local playback storage is cleared, and positions are synced across devices.
- **Sync ID (optional):** By default, the app uses a shared sync id derived from the site URL. Append `?user=your-id` (or use the Settings panel) to override it across multiple hosts or incognito windows.
- **Diagnostics:** Open Logs to review scan/playback events and clear as needed.

## Server Deployment Guide (Debian + Lighttpd + Node.js)

This guide describes how to host the player on a clean Debian server. This setup serves the
frontend via **Lighttpd** and runs the backend API via **Node.js** (managed by systemd).

### 1. Install Requirements

Update your system and install the web server, git, and node runtime.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y lighttpd nodejs npm git
```

### 2. Configure Lighttpd

Enable directory listing (for scanning books) and the proxy module (for the API).

```bash
sudo lighty-enable-mod dir-listing
sudo lighty-enable-mod proxy
```

Create a proxy configuration to forward API requests to the backend. We use port 3002 to avoid
conflicts with other services (like Gitea).

Edit `/etc/lighttpd/conf-available/10-proxy.conf`:

```conf
# Forward /api requests to the Node.js backend on port 3002
$HTTP["url"] =~ "^/api/" {
    proxy.server = ( "" => ( ( "host" => "127.0.0.1", "port" => 3002 ) ) )
}
```

Enable the configuration:

```bash
sudo ln -s /etc/lighttpd/conf-available/10-proxy.conf /etc/lighttpd/conf-enabled/
```

### 3. Deploy Application Files

Clone the repository directly into the web root and set up the directory structure.

```bash
cd /var/www/html
sudo rm index.lighttpd.html
# Clone the repo (replace with your repo URL)
sudo git clone https://github.com/dylan7474/audioBookPlayer.git .

# Create required directories for content and data
sudo mkdir books
sudo mkdir data

# Set permissions so the web server can read books and write data
sudo chown -R www-data:www-data /var/www/html
```

### 4. Create Backend Service (Systemd)

Set up the Node.js server to run automatically in the background using port 3002.

Create `/etc/systemd/system/audiobook-backend.service`:

```ini
[Unit]
Description=AudioBook Player Backend
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/var/www/html
ExecStart=/usr/bin/node server.js
Restart=on-failure
# Use port 3002 to avoid conflicts
Environment=PORT=3002
Environment=DATA_DIR=/var/www/html/data

[Install]
WantedBy=multi-user.target
```

### 5. Start Services

Reload systemd, start the backend, and restart the web server.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now audiobook-backend
sudo systemctl force-reload lighttpd
```

### 6. Verify Installation

Access the Player: `http://<YOUR_SERVER_IP>/`

Add Books: Copy your audiobook folders (containing `.mp3s`) into `/var/www/html/books/`.

Check Sync: Open browser logs (F12) to ensure the client connects to `/api/bookmarks`.

The server persists bookmark data at `data/bookmarks.json` (override with `DATA_FILE`).

### To deploy as a container use the script

To use a specific port (e.g., 8080):
```
./deploy_audiobook.sh 8080
```

To use the default port (3000):

```
./deploy_audiobook.sh
```

## Roadmap

- Add playlist sorting and custom ordering.
- Add bookmarking and quick chapter navigation.
- Optional theming for light/dark variants.
