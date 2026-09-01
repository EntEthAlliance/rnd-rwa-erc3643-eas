# CI / CD (GitHub Actions)

This repo contains two kinds of changes:
1) **Smart contract changes** (Foundry build/tests)
2) **Docs / website changes** (markdown, diagrams, story pages)

To keep iteration fast, CI is **path-aware**.

---

## What runs when

### Docs / website-only changes
If a PR only touches docs/site paths (e.g. `docs/**`, `diagrams/**`, `**/*.md`, `demo/**`), CI will:
- ✅ run a lightweight job that reports "skipping Foundry"
- ⏭️ **skip** Foundry build/test/coverage/gas

### Contract-related changes
If a PR touches any contract-related path (e.g. `contracts/**`, `src/**`, `test/**`, `script/**`, `lib/**`, `foundry.toml`), CI will:
- ✅ `forge build`
- ✅ `forge test`
- ✅ `forge fmt --check`
- ✅ gas snapshot (PRs)
- ✅ coverage (pushes to `master/main` only)

---

## Publishing (GitHub Pages)

The public site at <https://entethalliance.github.io/rnd-rwa-erc3643-eas/> is served
from the **`gh-pages` branch**. Two workflows write to it:

- **`pages-sync.yml`**: on pushes to `master` touching `demo/shibui-static/`'s pages,
  copies `index.html` and `identity-solutions-map.html` to the `gh-pages` root.
  `demo/shibui-static/` on `master` is the source of truth; don't edit the pages on
  `gh-pages` directly.
- **`demo-build.yml`**: builds the Next.js demo (`demo/shibui-app`) as a static
  export. The demo lives under `demo/` on `gh-pages`, separate from the synced pages.

---

## Why this exists
Foundry tests are valuable for contract safety, but unnecessary for doc/site-only PRs.
This setup preserves safety while reducing cycle time for publishing and content updates.
