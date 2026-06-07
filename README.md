# plans-prototype

Static prototype of the OpenCloud pricing page (German). Single-file HTML, no
build step required to view.

**Live preview:** <https://mikebonano.github.io/plans-prototype/>

## Files

- `index.html` — the page. Uses the Tailwind CDN at runtime and loads fonts
  from `fonts/`. Open directly in a browser to view.
- `feature-matrix.md` — source of truth for the **Leistungsübersicht**
  comparison table. The table in `index.html` mirrors this file 1:1.
- `page-content.md` — supporting copy for the page.
- `fonts/` — OpenCloud OTF font files referenced by `@font-face`.
- `build-standalone.sh` — produces `index.standalone.html`, a single
  self-contained file with the Tailwind CDN replaced by a locally-compiled CSS
  bundle (only the classes used) and the fonts embedded as base64 data URIs.
- `index.standalone.html` — the self-contained build output. Open it without
  network access, drop it on a CDN, or email it as a single file.

## Tiers

Three tiers, matching `feature-matrix.md`:

- **Light** — for small teams that need a stable, supported environment.
- **Standard** — recommended. Adds HA, SBOM, password policy, audit logs, etc.
- **Premium** — adds Multi-Tenancy, White-Label/OEM, roadmap influence.

Plus the **HPC** add-on (priced per TB) for research and high-performance
workloads.

## Viewing

Open `index.html` (needs network for the Tailwind CDN and uses local fonts)
or `index.standalone.html` (fully offline) in any modern browser.

## Building the self-contained file

```bash
./build-standalone.sh
```

Requires `curl`, `python3`, and `base64` — all standard on macOS and Linux.

The script:

1. Downloads the Tailwind CLI standalone binary into `./.build/` (cached
   between runs; gitignored).
2. Scans `index.html` for the utility classes actually used and compiles a
   minimal, minified Tailwind bundle.
3. Base64-encodes both OTF fonts.
4. Strips the Tailwind CDN `<script>` and inline config from a copy of
   `index.html`, swaps the `@font-face` URLs for `data:` URIs, inlines the
   compiled CSS, and writes `index.standalone.html`.

Re-run the script after any change to `index.html` to refresh the standalone
output.
