# TRMNL Daily Digest Display

**Date:** 2026-02-13
**Status:** Ready
**Topic:** integrations

---

## Summary

Push the Selene daily digest to a TRMNL e-ink display each morning alongside the existing Apple Notes delivery. The condensed 3-5 bullet digest is ideal for e-ink: scannable at a glance, well under TRMNL's 2kb payload limit.

---

## Approach

Add TRMNL push to the existing `send-digest.ts` workflow. No new files, no new launchd agents. The TRMNL webhook call happens at 6am alongside Apple Notes delivery, sharing the same digest file lookup.

**Why not a separate workflow?** The logic is a single HTTP POST. A standalone workflow + launchd plist would be overengineering.

---

## Design

### Configuration

Two new env vars:

```
TRMNL_WEBHOOK_URL=        # Private plugin webhook URL (includes UUID)
TRMNL_DIGEST_ENABLED=true # Toggle independently from Apple Notes
```

In `config.ts`:

```ts
trmnlWebhookUrl: process.env.TRMNL_WEBHOOK_URL || '',
trmnlDigestEnabled: !isTestEnv && !!process.env.TRMNL_WEBHOOK_URL && process.env.TRMNL_DIGEST_ENABLED !== 'false',
```

Enabled by default when webhook URL is set. Explicitly disableable. Off in test mode.

### Push Logic (`send-digest.ts`)

A `pushToTrmnl()` function that:

1. Reads the same digest file already located by `sendDigest()`
2. Splits digest text into bullet lines
3. POSTs to the TRMNL webhook:

```json
{
  "merge_variables": {
    "title": "Selene Daily",
    "date": "Thursday, February 13, 2026",
    "bullets": ["bullet 1", "bullet 2", "bullet 3"]
  }
}
```

4. Uses native `fetch()` (Node 18+) — no new dependencies
5. Logs success/failure, does not throw (TRMNL failure must not break Apple Notes)

Called inside `sendDigest()` after the Apple Notes push. Skipped in test mode.

### TRMNL Markup Template

Configured in the TRMNL web UI (not in our codebase):

```html
<h1>{{ title }}</h1>
<p style="color: #888;">{{ date }}</p>
<hr>
{% for item in bullets %}
<p>{{ item }}</p>
{% endfor %}
```

### Error Handling

- Fire-and-forget with structured logging
- If `TRMNL_WEBHOOK_URL` is empty or disabled, skip silently
- TRMNL failure does not affect Apple Notes delivery
- Digest content is already under 2kb

---

## Acceptance Criteria

- [ ] `TRMNL_WEBHOOK_URL` env var configures the webhook endpoint
- [ ] `TRMNL_DIGEST_ENABLED` can toggle the feature on/off
- [ ] Digest is POSTed as JSON with `merge_variables` containing title, date, and bullets
- [ ] TRMNL push failure logs an error but does not prevent Apple Notes delivery
- [ ] Test mode skips the HTTP call
- [ ] `.env.example` updated with new vars

## ADHD Check

- **Reduces friction?** Yes — glanceable morning summary on e-ink, zero interaction required
- **Visible?** Yes — always-on display, literally in your field of view
- **Externalizes cognition?** Yes — key themes and action items visible without opening an app

## Scope Check

< 1 hour of implementation. Three small changes: `config.ts`, `send-digest.ts`, `.env.example`.
