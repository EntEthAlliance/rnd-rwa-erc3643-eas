# Shibui — Static Positioning Page

This folder contains a **single-page, presentation-ready site** for Shibui.

**Canonical intro (used on the page):**
> "Shibui is an open-source identity standard built on Ethereum Attestation Service (EAS), designed to give tokenized assets a shared, interoperable language for investor eligibility."

It is written for a **broad bank / TradFi audience** (institutional, concise, low-jargon), with a primary CTA to **join the working group**.

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

Before publishing externally, replace this with the real working-group contact.

## Export to PDF

This page includes **print styles** (A4/Letter friendly) for clean PDF export.

1. Open the page
2. Browser menu → **Print…**
3. Destination → **Save as PDF**
4. Recommended settings:
   - Paper: **Letter** or **A4**
   - Background graphics: **On** (keeps subtle borders)

## Notes

- Static HTML/CSS/JS (GitHub Pages friendly)
- No wallet connection
- No RPC / chain calls
- No build step
