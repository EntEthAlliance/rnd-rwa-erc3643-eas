# Shibui — Static Story Page

This folder contains a **single-page, presentation-ready narrative**:
**“Shibui — A Shared Identity Language for Tokenized Assets.”**

It is designed for **banks, asset managers, transfer agents, and regulators**.

## What changed (vs the earlier demo UI)

- Replaced the step-by-step “scene” walkthrough UI with a **highly visual story page**.
- Structure is now:
  - **Problem**
  - **Act I–V**
  - **The Ask**
  - **Specifications**
  - Optional, collapsed **Appendix** (minimal technical notes)
- Removed the “live state” simulation panel and action log to keep the page **business-first**.
- Kept everything **static HTML/CSS/JS** for GitHub Pages.

## Run

### Option A — open directly
Open `index.html` in a browser.

### Option B — local server
```bash
cd demo/shibui-static
python3 -m http.server 8000
```
Then open <http://127.0.0.1:8000/>.

## Notes

- No wallet connection
- No RPC / chain calls
- No build step
- Safe to host on GitHub Pages (static assets only)
