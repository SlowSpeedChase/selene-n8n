# TRMNL Integration for Daily Summary

**Date:** 2025-12-30
**Status:** Implemented and deployed

## Goal

Display the daily summary from workflow 08 on a TRMNL e-ink display.

## Design

### Approach

Add two nodes to workflow 08 after the file write:
1. **Code node** — Strip markdown syntax to plain text
2. **HTTP Request node** — POST to TRMNL webhook

### Data Flow

```
[Existing workflow] → Write File → Strip Markdown → POST to TRMNL
```

### Markdown Stripping (Code node)

JavaScript to convert markdown to plain text:

```javascript
const markdown = $input.first().json.summary;

const plainText = markdown
  .replace(/^#{1,6}\s+/gm, '')      // Remove header markers
  .replace(/\*\*(.+?)\*\*/g, '$1')  // Bold → plain
  .replace(/\*(.+?)\*/g, '$1')      // Italic → plain
  .replace(/^---$/gm, '')           // Remove horizontal rules
  .replace(/\n{3,}/g, '\n\n')       // Collapse multiple newlines
  .trim();

return { plainText };
```

### TRMNL Request (HTTP node)

- **Method:** POST
- **URL:** `https://usetrmnl.com/api/custom_plugins/{{$env.TRMNL_WEBHOOK_ID}}`
- **Headers:** `Content-Type: application/json`
- **Body:**
```json
{
  "merge_variables": {
    "text": "{{ $json.plainText }}"
  }
}
```

### Configuration

Add to `.env`:
```
TRMNL_WEBHOOK_ID=<webhook-uuid-from-trmnl>
```

### TRMNL Plugin Setup

1. Go to usetrmnl.com → Plugins → Private Plugin → Create
2. Name: "Selene Daily Summary"
3. Markup template:
```html
<div class="markup markup--default">
  <div class="title title--default">Daily Summary</div>
  <div class="content content--default" style="white-space: pre-wrap;">{{ text }}</div>
</div>
```
4. Copy the Webhook UUID to `.env`

## Error Handling

- If TRMNL POST fails, workflow continues (file is already written)
- Log errors but don't block the main workflow

## Testing

1. Manually trigger workflow 08
2. Verify file is written to Obsidian
3. Verify TRMNL display updates

## Implementation Checklist

- [x] Create TRMNL Private Plugin and get webhook ID
- [x] Add `TRMNL_WEBHOOK_ID` to docker-compose.yml
- [x] Add Code node to workflow 08
- [x] Add HTTP Request node to workflow 08
- [x] Test end-to-end (verified 2025-12-31)
