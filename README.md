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

## Hosting on Debian with lighttpd

Enable directory listing so the player can scan `./books`:

```bash
sudo lighty-enable-mod dir-listing
sudo systemctl force-reload lighttpd
```

Place your audiobook folders inside a `books/` directory next to `index.html`.

## Server-side bookmark sync (lighttpd + Node)

The optional server-side sync keeps playback positions in sync across devices by proxying
`/api/bookmarks` to a local Node server.

1. Install Node.js on Debian:

   ```bash
   sudo apt-get update
   sudo apt-get install -y nodejs
   ```

2. Start the API server (listens on localhost only):

   ```bash
   node server.js
   ```

3. Enable proxying in lighttpd (example config):

   ```conf
   server.modules += ( "mod_proxy" )

   $HTTP["url"] =~ "^/api/" {
       proxy.server = ( "" => ( ( "host" => "127.0.0.1", "port" => 3000 ) ) )
   }
   ```

4. Restart lighttpd and load the site. The client will automatically sync when the endpoint is available.

The server persists bookmark data at `data/bookmarks.json` (override with `DATA_FILE`).

## Roadmap

- Add playlist sorting and custom ordering.
- Add bookmarking and quick chapter navigation.
- Optional theming for light/dark variants.
