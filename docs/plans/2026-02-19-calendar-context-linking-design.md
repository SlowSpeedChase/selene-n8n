# Calendar Context Linking

**Date:** 2026-02-19
**Status:** Ready
**Topic:** ingestion, calendar, context

---

## Problem

When you capture a quick note, context about *what you were doing* gets lost. You timeboxed cleaning and couldn't finish — but the note "felt tired, overestimated my capacity" doesn't mention cleaning. You jot something at a happy hour — but the note doesn't say which event it was about. Your calendar already has this context; Selene just doesn't know about it.

## Solution

Automatically link notes to calendar events based on timing. When a note arrives, check Apple Calendar for events happening at that time (or that just ended), and attach the event as metadata on the note.

## Architecture

### Swift CLI Tool: `selene-calendar`

New executable target in `SeleneChat/Package.swift`, using EventKit.

**Interface:**
```bash
selene-calendar --at "2026-02-19T17:30:00"
```

**Output (JSON to stdout):**
```json
{
  "events": [
    {
      "title": "Aura Happy Hour",
      "startDate": "2026-02-19T17:00:00-06:00",
      "endDate": "2026-02-19T19:00:00-06:00",
      "calendar": "Social",
      "isAllDay": false
    }
  ],
  "matchType": "during"
}
```

**Matching logic:**
1. Check for events containing the timestamp (note written during event)
2. Check for events that ended within 30 minutes before the timestamp (note written just after)
3. Skip all-day events (not contextual enough)
4. Return all matching events

### Database

One new nullable JSON column on `raw_notes`:

```sql
ALTER TABLE raw_notes ADD COLUMN calendar_event TEXT;
```

Stores the best-matching event as JSON: `{"title", "startDate", "endDate", "calendar"}`.

**Best match selection:** When multiple events overlap, prefer the most specific — shorter timed events over longer ones.

### Ingestion Integration

In `src/workflows/ingest.ts`, after saving the note:

1. Call `selene-calendar --at <created_at>` via `child_process.execFile`
2. Parse JSON response
3. If events found, pick best match and UPDATE the note's `calendar_event` column
4. **Best-effort only** — if CLI fails (no permission, not built, error), log warning and continue. Never block ingestion.

### SeleneChat Display

Subtle metadata tag below the note title when `calendar_event` is non-null:

```
📅 Aura Happy Hour · 5:00–7:00 PM
```

Muted text, small font — context, not the focus.

### AI Context

The conversation context builder includes calendar event info when discussing a note:
- "This note was written during 'Aura Happy Hour' (5-7pm)"
- "You wrote this right after your 'Clean Kitchen' time block"

### SeleneMobile

Gets this for free — `calendar_event` is served via existing `/api/notes` endpoint. Just render the tag.

## TypeScript Types

```typescript
interface CalendarEvent {
  title: string;
  startDate: string;  // ISO 8601
  endDate: string;
  calendar: string;
  isAllDay: boolean;
}
```

## ADHD Check

- **Externalizes context?** Yes — you don't have to remember what you were doing, the calendar tells Selene
- **Reduces friction?** Yes — fully automatic, no user action
- **Makes information visible?** Yes — event context shown directly on the note
- **Realistic?** Yes — leverages data you already maintain (your calendar)

## Acceptance Criteria

- [ ] `selene-calendar` CLI queries EventKit and returns events as JSON
- [ ] Notes ingested during/just after a calendar event get `calendar_event` metadata
- [ ] SeleneChat displays calendar event tag on linked notes
- [ ] AI context builder includes calendar event info
- [ ] SeleneMobile renders the tag via API data
- [ ] Ingestion never fails if calendar lookup fails (best-effort)
- [ ] All-day events are excluded from matching

## Scope

~3–4 days of focused work. Components: Swift CLI target, DB migration, ingestion change, SeleneChat UI tag, AI context update, SeleneMobile tag.

## Explicitly Out of Scope

- Writing to the calendar from Selene
- Calendar view in SeleneChat
- Retroactive enrichment of old notes
- Recurring event special handling
- Google Calendar support
