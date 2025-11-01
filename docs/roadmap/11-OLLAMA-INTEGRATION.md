# Ollama/LLM Integration

**Model:** mistral:7b
**API Endpoint:** http://localhost:11434/api/generate
**Documentation:** https://github.com/ollama/ollama/blob/main/docs/api.md

## Overview

Ollama provides local LLM inference for concept extraction, theme detection, and sentiment analysis. The n8n approach uses simple HTTP Request nodes instead of complex Python adapters.

## API Configuration

### Base Endpoint
```
POST http://localhost:11434/api/generate
```

### Request Format
```json
{
  "model": "mistral:7b",
  "prompt": "Your prompt here",
  "stream": false,
  "options": {
    "temperature": 0.3
  }
}
```

### Response Format
```json
{
  "model": "mistral:7b",
  "created_at": "2025-10-30T10:00:00Z",
  "response": "The LLM's response text here",
  "done": true,
  "context": [...],
  "total_duration": 1234567890,
  "load_duration": 12345678,
  "prompt_eval_count": 50,
  "eval_count": 100,
  "eval_duration": 1234567890
}
```

## Prompts

### 1. Concept Extraction

**Purpose:** Extract 5-10 key concepts from note content

**Prompt:**
```
Extract 5-10 key concepts from this note. Return ONLY a JSON array of strings, like: ["concept1", "concept2", "concept3"]

Do not include any explanation, just the JSON array.

Note content:
{{ $json.content }}
```

**Options:**
```json
{
  "temperature": 0.3,
  "top_p": 0.9
}
```

**Expected Response:**
```json
["project-planning", "team-meeting", "deadline", "resource-allocation", "risk-management"]
```

**Parsing:**
```javascript
// Function node after HTTP request
const response = $input.item.json.response;
// Extract JSON array from response
const match = response.match(/\[.*\]/s);
if (match) {
  const concepts = JSON.parse(match[0]);
  return {
    json: {
      concepts: concepts,
      concept_count: concepts.length,
      concept_confidence: concepts.length >= 5 ? 0.9 : 0.6
    }
  };
}
return {
  json: {
    concepts: [],
    concept_count: 0,
    concept_confidence: 0.0
  }
};
```

### 2. Theme Detection

**Purpose:** Identify primary and secondary themes

**Prompt:**
```
Identify themes in this note. Return ONLY a JSON object like:
{"primary": "main-theme", "secondary": ["theme1", "theme2"]}

Do not include any explanation, just the JSON object.

Note content:
{{ $json.content }}
```

**Options:**
```json
{
  "temperature": 0.3,
  "top_p": 0.9
}
```

**Expected Response:**
```json
{
  "primary": "work-planning",
  "secondary": ["collaboration", "time-management"]
}
```

**Parsing:**
```javascript
// Function node after HTTP request
const response = $input.item.json.response;
// Extract JSON object from response
const match = response.match(/\{.*\}/s);
if (match) {
  const themeObj = JSON.parse(match[0]);
  const allThemes = [themeObj.primary, ...themeObj.secondary];
  return {
    json: {
      themes: allThemes,
      primary_theme: themeObj.primary,
      theme_confidence: themeObj.primary ? 0.85 : 0.5
    }
  };
}
return {
  json: {
    themes: [],
    primary_theme: null,
    theme_confidence: 0.0
  }
};
```

### 3. Sentiment Analysis

**Purpose:** Analyze emotional tone and energy level

**Prompt:**
```
Analyze the sentiment and emotional tone of this note. Return ONLY a JSON object like:
{
  "overall_sentiment": "positive|negative|neutral",
  "sentiment_score": 0.7,
  "emotional_tone": "excited|calm|anxious|frustrated|content",
  "energy_level": "high|medium|low"
}

Do not include any explanation, just the JSON object.

Note content:
{{ $json.content }}
```

**Options:**
```json
{
  "temperature": 0.2,
  "top_p": 0.8
}
```

**Expected Response:**
```json
{
  "overall_sentiment": "positive",
  "sentiment_score": 0.75,
  "emotional_tone": "excited",
  "energy_level": "high"
}
```

**Parsing:**
```javascript
// Function node after HTTP request
const response = $input.item.json.response;
const match = response.match(/\{.*\}/s);
if (match) {
  const sentiment = JSON.parse(match[0]);
  return {
    json: {
      overall_sentiment: sentiment.overall_sentiment || 'neutral',
      sentiment_score: sentiment.sentiment_score || 0.5,
      emotional_tone: sentiment.emotional_tone || 'calm',
      energy_level: sentiment.energy_level || 'medium',
      sentiment_confidence: sentiment.sentiment_score ? 0.8 : 0.4
    }
  };
}
return {
  json: {
    overall_sentiment: 'neutral',
    sentiment_score: 0.5,
    emotional_tone: 'calm',
    energy_level: 'medium',
    sentiment_confidence: 0.0
  }
};
```

### 4. Entity Extraction (Future)

**Purpose:** Extract people, places, organizations, dates

**Prompt:**
```
Extract named entities from this note. Return ONLY a JSON object like:
{
  "people": ["Alice", "Bob"],
  "places": ["San Francisco", "Office"],
  "organizations": ["Acme Corp"],
  "dates": ["2025-10-30", "next Friday"]
}

Do not include any explanation, just the JSON object.

Note content:
{{ $json.content }}
```

**Options:**
```json
{
  "temperature": 0.1,
  "top_p": 0.9
}
```

**Not yet implemented** - Planned for Phase 4 or 5.

## HTTP Request Node Configuration

### In n8n Workflow

**Node Type:** HTTP Request

**Method:** POST

**URL:** `http://localhost:11434/api/generate`

**Headers:**
```json
{
  "Content-Type": "application/json"
}
```

**Body (JSON):**
```json
{
  "model": "mistral:7b",
  "prompt": "{{ your prompt here with {{ $json.content }} }}",
  "stream": false,
  "options": {
    "temperature": 0.3
  }
}
```

**Response Format:** JSON

**Timeout:** 60000ms (60 seconds)

## Error Handling

### Common Errors

1. **Connection refused**
   - Ollama not running
   - Check: `curl http://localhost:11434/api/tags`
   - Fix: `ollama serve`

2. **Model not found**
   - Model not downloaded
   - Check: `ollama list`
   - Fix: `ollama pull mistral:7b`

3. **Timeout**
   - First request takes longer (model loading)
   - Increase timeout to 120s for first request
   - Subsequent requests faster (model cached)

4. **Invalid JSON in response**
   - LLM didn't follow instructions
   - Regex extraction handles this
   - Returns empty array/object on parse failure

### Error Handling in n8n

**After HTTP Request node, add IF node:**
```javascript
// Check if response exists and is valid
{{ $json.response !== undefined && $json.response.length > 0 }}
```

**If TRUE:** Parse and continue
**If FALSE:** Set default values and continue

## Performance Tuning

### Temperature Settings

- **Concept Extraction:** 0.3 (low - more consistent)
- **Theme Detection:** 0.3 (low - categorical)
- **Sentiment Analysis:** 0.2 (very low - structured output)
- **Entity Extraction:** 0.1 (very low - factual)

Lower temperature = more consistent, less creative
Higher temperature = more varied, less predictable

### Context Window

Mistral:7b has 8k token context. For most notes this is plenty.

**Rough estimates:**
- 1 token ≈ 4 characters
- Average note: 500 characters = ~125 tokens
- Prompt overhead: ~100 tokens
- Total per request: ~225 tokens

**Batching:** Not necessary for Phase 1, consider for Phase 4 if processing large backlogs.

## Testing Ollama

### Direct API Test
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "mistral:7b",
  "prompt": "Extract key concepts from this text as a JSON array: Project planning meeting about Q4 roadmap and resource allocation",
  "stream": false,
  "options": {"temperature": 0.3}
}'
```

### Check Installed Models
```bash
ollama list
```

### Pull Model
```bash
ollama pull mistral:7b
```

### Test Model
```bash
ollama run mistral:7b "Say hello"
```

## Model Selection

**Current:** mistral:7b (7 billion parameters)

**Why Mistral:**
- Good balance of speed and quality
- Runs on consumer hardware
- Strong instruction following
- Good JSON output

**Alternatives to consider:**
- `llama2:7b` - Similar performance
- `llama2:13b` - Better quality, slower
- `phi:latest` - Faster, lower quality
- `mixtral:8x7b` - Best quality, requires more RAM

**Switching models:**
1. Pull new model: `ollama pull llama2:13b`
2. Update workflow HTTP Request body: `"model": "llama2:13b"`
3. Test and compare quality

## Best Practices

1. **Explicit output format** - Always specify exact JSON structure wanted
2. **No explanation** - Tell LLM to return ONLY JSON
3. **Regex extraction** - Parse response with regex to handle LLM variation
4. **Default values** - Always have fallback if parsing fails
5. **Confidence scoring** - Track quality of extractions
6. **Low temperature** - Use 0.1-0.3 for structured outputs
7. **Timeout handling** - First request slower (model load)
8. **Error propagation** - Don't fail workflow, use defaults

## Prompt Engineering Tips

### Good Prompts
✅ "Return ONLY a JSON array"
✅ "Do not include explanation"
✅ Provide exact example format
✅ Use low temperature (0.1-0.3)

### Bad Prompts
❌ "Extract concepts from this note" (no format specified)
❌ "Explain the themes" (too open-ended)
❌ No example provided
❌ High temperature (>0.7) for structured output

## Troubleshooting

### LLM Returns Explanation Instead of JSON
**Problem:** Response is "Here are the concepts: [...]" instead of just "[]"

**Fix:**
- Make prompt more explicit
- Add "Return ONLY the JSON, nothing else"
- Use lower temperature

### Inconsistent JSON Format
**Problem:** Sometimes returns array, sometimes object

**Fix:**
- Provide exact example in prompt
- Use regex to extract specific format
- Validate and normalize in Function node

### Slow Response
**Problem:** Taking > 30 seconds

**Fix:**
- First request is always slow (model loading)
- Keep Ollama running continuously
- Check system resources
- Consider smaller model

### Poor Quality Extractions
**Problem:** Concepts/themes don't make sense

**Fix:**
- Review prompts - be more specific
- Try different model (mixtral, llama2:13b)
- Increase context by including note title
- Check confidence scores

## Related Documentation

- [03-PHASE-1-CORE.md](./03-PHASE-1-CORE.md) - Uses concept and theme extraction
- [13-N8N-WORKFLOW-SPECS.md](./13-N8N-WORKFLOW-SPECS.md) - Node configurations
- [22-TROUBLESHOOTING.md](./22-TROUBLESHOOTING.md) - Common issues
