# Shibui — Static Positioning Page

This folder contains a **single-page, presentation-ready site** for Shibui.

**Canonical intro (used on the page):**
> "Shibui is an open-source identity standard built on Ethereum Attestation Service (EAS), designed to give tokenized assets a shared, interoperable language for investor eligibility."

It is written for an institutional audience, with concise, low-jargon language and a primary CTA to **join the working group**.

## Visual components (built-in)

The page includes lightweight, responsive diagrams (inline SVG/CSS — no external libraries):
- Compounding network effect timeline
- “Babel of verification” (duplicated onboarding)
- Before/after operational flow
- Working-group governance map
- What vs How architecture separation (standards vs implementations)

It also includes a standalone companion page:
- `identity-solutions-map.html` — "Identity Management Solutions — Reference map" (filterable landscape)

## Run

### Option A — open directly
Open `index.html` in a browser.

### Option B — local server
```bash
cd demo/shibui-static
python3 -m http.server 8000
```
Then open <http://127.0.0.1:8000/>.

## Customize the working-group CTA

The page includes a mailto CTA:
- `mailto:shibui-working-group@yourdomain.tld`

Before external publication, replace this with the working-group contact.

## Export to PDF

This page includes **print styles** (A4/Letter friendly) for clean PDF export.

1. Open the page
2. Browser menu → **Print…**
3. Destination → **Save as PDF**
4. Recommended settings:
   - Paper: **Letter** or **A4**
   - Background graphics: **On** (preserves subtle borders)

## Notes

- Static HTML/CSS/JS (GitHub Pages friendly)
- No wallet connection
- No RPC / chain calls
- No build step
