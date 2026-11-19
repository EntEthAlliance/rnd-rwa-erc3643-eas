# Shibui: Public Site (source)

This folder is the source of truth for the Shibui public site, published at
<https://entethalliance.github.io/rnd-rwa-erc3643-eas/>.

## Pages

- `index.html`: the ten-field investor credential, an animated walkthrough of its example
  source records, issuer decisions and the eight-topic reference.
  Uses the shared EEA editorial masthead. The three credential states run
  locally in the browser. The Sepolia demo is a separate application.
- `identity-solutions-map.html`: the identity solutions reference map,
  token-bridged onto the same design system. Must stay a sibling of
  `index.html` so the relative link resolves.

Both pages are self-contained: no build step, no local CSS/JS files. The
only external requests are Google Fonts, the design system's
`editorial.css` and the EEA-PAGES Google tag (GT-PL9524M).

## Publishing

On every push to `main` that touches these pages, the
[`pages-sync` workflow](../../.github/workflows/pages-sync.yml) copies them
to the root of the `gh-pages` branch, which GitHub Pages serves. The demo
app export living under `demo/` on `gh-pages` is deployed separately and is
not touched by the sync.

Edit the pages here: do not edit `gh-pages` directly, or the next sync
will overwrite the change.

## Run locally

```bash
cd demo/shibui-static
python3 -m http.server 8000
```

Then open <http://127.0.0.1:8000/>. The `Live demo` nav link points at the
demo export on the deployed site, so it 404s locally: everything else
works.

## Content rules

- Theme: light only: the editorial family has no dark counterpart and no
  theme toggle.
- Section 07 deliberately does **not** announce a working group: the page
  tests interest. Do not reintroduce a working-group CTA or a placeholder
  mailto.
- The claim-topics table's vendor examples require the accompanying
  neutrality disclaimer (EEA antitrust guidance; see the CHANGELOG entry
  resolving #65). Keep it if you keep the vendor names.
- The EAS network lists come from the
  [EAS deployments page](https://docs.attest.org/docs/quick--start/contracts);
  re-check it before adding or renaming entries.
