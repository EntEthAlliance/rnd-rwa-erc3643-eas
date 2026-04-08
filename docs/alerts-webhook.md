# EEA Agent Alert Webhook (Issues + Comments)

This repository includes a GitHub Actions workflow that acts as a webhook listener for:
- new issues
- new issue comments

Workflow file:
- `.github/workflows/eea-agent-alerts.yml`

## Behavior

When a new issue or comment appears, the workflow sends a Telegram alert to the EEA agent channel with:
1. event context (repo, issue number/title, author)
2. excerpt of issue/comment content
3. a **suggested draft response**
4. explicit note that the response requires human approval before posting

No auto-reply is posted to GitHub.

## Required repository secrets

Set these in **GitHub → Settings → Secrets and variables → Actions**:

- `EEA_AGENT_TELEGRAM_BOT_TOKEN` — Telegram bot token used for alerts
- `EEA_AGENT_TELEGRAM_CHAT_ID` — EEA agent channel chat id (e.g., `-100...`)

## Trigger events

- `issues`: `opened`, `reopened`
- `issue_comment`: `created`

## Validation

1. Add secrets above
2. Open a test issue in the repo
3. Confirm Telegram alert appears in EEA agent channel
4. Add a comment to the issue
5. Confirm second alert appears with new context + suggested draft
