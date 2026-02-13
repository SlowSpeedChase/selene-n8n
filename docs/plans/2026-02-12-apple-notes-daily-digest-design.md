# Apple Notes Daily Digest

**Date:** 2026-02-12
**Status:** Done
**Topic:** automation

---

## Summary

Replace iMessage delivery in `send-digest.ts` with Apple Notes. A single pinned note called "Selene Daily" gets overwritten each morning at 6am with the processed daily summary. Same data, same schedule, more visible.

---

## ADHD Check

- **Reduces friction?** Yes - Apple Notes is already open/visible on iPhone and Mac. No need to scroll through messages.
- **Makes info visible?** Yes - pinned note is always at the top. In your face, not buried.
- **Externalizes cognition?** Yes - daily themes and patterns surfaced without effort.

---

## Acceptance Criteria

- [ ] `send-digest.ts` creates/updates a note named "Selene Daily" in Apple Notes via AppleScript
- [ ] iMessage sending logic removed
- [ ] `IMESSAGE_DIGEST_TO` env var no longer required
- [ ] Digest content rendered as clean HTML in the note body
- [ ] Date header included so you know when it was last updated
- [ ] First run creates the note; subsequent runs overwrite it
- [ ] Test mode still writes to file (no Apple Notes interaction)
- [ ] Existing launchd schedule (6am) unchanged

---

## Scope Check

**Estimated effort:** < 1 day. Single file modification.

---

## Design

### What changes

**One file modified:** `src/workflows/send-digest.ts`

- Remove `sendIMessage()` function
- Add `updateAppleNote()` function using `osascript` to target Apple Notes
- Convert markdown digest to simple HTML for Apple Notes body
- Keep test mode (`sendDigestToFile`) unchanged
- Remove `IMESSAGE_DIGEST_TO` config dependency

### AppleScript approach

```applescript
tell application "Notes"
  set noteName to "Selene Daily"
  set noteBody to "<html>...</html>"
  try
    -- Find existing note
    set targetNote to first note whose name is noteName
    set body of targetNote to noteBody
  on error
    -- Create new note if doesn't exist
    make new note with properties {name:noteName, body:noteBody}
  end try
end tell
```

### HTML format

```html
<h1>Selene Daily</h1>
<p style="color: #888;">Updated: February 12, 2026</p>
<hr>
<p>[Summary paragraphs from digest]</p>
<h2>Themes</h2>
<ul>
  <li>[theme 1]</li>
  <li>[theme 2]</li>
</ul>
```

### What stays the same

- `daily-summary.ts` generates digest at midnight (no changes)
- Launchd triggers `send-digest.ts` at 6am (no changes)
- Digest file format and location (no changes)
- Test mode writes to file (no changes)

### What gets removed

- `sendIMessage()` function
- iMessage fallback strategy
- `IMESSAGE_DIGEST_TO` env var requirement
- `config.imessageDigestTo` / `config.imessageDigestEnabled` checks

### User setup (one-time)

After first run, pin the "Selene Daily" note in Apple Notes. Pinned status persists across content updates.

---

## Risks

- **Apple Notes AppleScript permissions:** macOS may prompt for automation permission on first run. User approves once.
- **HTML rendering:** Apple Notes HTML support is limited. Keep formatting simple (headers, paragraphs, lists).
