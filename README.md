# Shibui — Public Site (GitHub Pages)

This branch is the published site at
<https://entethalliance.github.io/rnd-rwa-erc3643-eas/>.

## Pages

- `index.html` — the Shibui main page. Built on the hosted
  [EEA design system](https://entethalliance.github.io/eea-design-system/)
  (Tier B: `tokens.css`, `base.css`, `nav.css`, `components.css`) with the
  unified EEA nav, a sticky section nav with scroll spy, a light/dark theme
  toggle (`eea-theme` localStorage key, dark default) and print styles.
- `identity-solutions-map.html` — the identity solutions reference map,
  token-bridged onto the same design system. Reads the shared `eea-theme`
  key so the theme carries across pages.
- `demo/` — static export of the Next.js demo app
  (`demo/shibui-app` on `master`), deployed separately.

The source of truth for the two static pages is `demo/shibui-static/` on
`master`; changes land there first and are then published here.

## Run locally

```bash
python3 -m http.server 8000
```

Then open <http://127.0.0.1:8000/>.

## Notes

- Static HTML/CSS/JS — no build step; the only external requests are
  Google Fonts and the design-system stylesheets.
- Analytics: EEA-PAGES Google tag (GT-PL9524M) in both pages' heads.
- Section 07 deliberately does **not** announce a working group — the page
  tests interest. Do not reintroduce a working-group CTA or placeholder
  mailto.
