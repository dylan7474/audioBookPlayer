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
- **Diagnostics:** Open Logs to review scan/playback events and clear as needed.

## Hosting on Debian with lighttpd

Enable directory listing so the player can scan `./books`:

```bash
sudo lighty-enable-mod dir-listing
sudo systemctl force-reload lighttpd
```

Place your audiobook folders inside a `books/` directory next to `index.html`.

## Roadmap

- Add playlist sorting and custom ordering.
- Add bookmarking and quick chapter navigation.
- Optional theming for light/dark variants.
