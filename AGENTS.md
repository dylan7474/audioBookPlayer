# Agent Notes for AudioBookPlayer

## Project overview
- This is a static, single-page HTML app (`index.html`) with inline JavaScript and Tailwind via CDN.
- Server-mode scanning expects a `books/` directory with MP3 files and directory listing enabled.

## Development guidelines
- Keep changes minimal and avoid introducing build tools or frameworks unless explicitly requested.
- Maintain the inline script structure in `index.html`; prefer small, well-scoped functions.
- Do not add try/catch blocks around imports.
- If you introduce new UI behaviors, update user-facing copy in `README.md`.

## Workflow tips
- Use `make build` to produce a deployable `dist/` directory.
- If you change playback behavior or data keys, mention it in the README controls section.
