# KitchenOS-Selene Integration ("Kitchen Brain")

**Date:** 2026-02-13
**Status:** Ready
**Topic:** integrations, meal-planning, selenechat

---

## Problem

KitchenOS has a full recipe extraction pipeline, meal plan generator, shopping list system, nutrition tracking, and calendar sync. But the meal planning flow is unused because of friction -- opening Obsidian, filling in templates manually, then running shopping list generation. Meanwhile, Selene's thinking partner pattern proves that conversational interfaces drastically reduce friction for ADHD users.

The two systems are completely siloed. KitchenOS doesn't know about Selene threads or tasks. Selene doesn't know about recipes, meals, or nutrition. Shopping lists live in Apple Reminders disconnected from everything else.

## Solution

Make KitchenOS a first-class data source inside Selene's ecosystem. Selene reads the KitchenOS Obsidian vault, indexes recipes into its database, and provides conversational meal planning through SeleneChat. Planned meals export back to Obsidian in KitchenOS-native format so all existing KitchenOS tools (shopping lists, calendar sync, nutrition dashboard) work unchanged.

**Core principle:** Obsidian is the API. Selene writes KitchenOS-format files. KitchenOS reads them with existing parsers. No server-to-server coupling.

## Architecture

```
KitchenOS (Python)                    Selene (TypeScript)
  extract_recipe.py ──writes──> Obsidian KitchenOS Vault
                                       │
                            index-recipes.ts (reads)
                                       │
                                       v
                              Selene SQLite DB
                              (recipes, meal_plans,
                               shopping_items tables)
                                       │
                              ┌────────┴────────┐
                              │                 │
                    SeleneChat Query      Meal Plan Output
                    "Help me plan         ──writes──> Obsidian
                     next week"                      meal plan
                              │                      + shopping
                              v                      list
                    Thinking Partner
                    (recipe context +
                     nutrition + prefs)
                              │
                              v
                    Actions: Things tasks
                    for meal prep + shopping
```

### What Changes in Each System

| System | Changes | Doesn't Change |
|--------|---------|----------------|
| **KitchenOS** | Nothing | Recipe extraction, API server, all existing functionality |
| **Selene backend** | New workflow `index-recipes.ts`, new DB migration, config for KitchenOS vault path | Existing workflows, server, pipeline |
| **SeleneChat** | New query type, context builder, prompt builder, recipe model | Existing query types, thread system, thinking partner |

### Data Flow (Bidirectional)

```
KitchenOS                    Obsidian Vault                    Selene
                                  │
extract_recipe.py ──writes──> Recipes/*.md ──reads──> index-recipes.ts
                                  │                         │
                                  │                    Selene SQLite
                                  │                         │
                         Meal Plans/*.md <──writes── SeleneChat planning
                                  │                         │
  meal_plan_parser.py ──reads─────┘                         │
  shopping_list.py ──reads────────┘                         │
  sync_calendar.py ──reads────────┘                         │
  nutrition_dashboard.py ──reads──┘                         │
                                                            │
                         Shopping Lists/*.md <──writes───────┘
                                  │
  send-to-reminders ──reads───────┘
```

---

## Database Schema

Four new tables following Selene's existing patterns (content_hash dedup, test_run isolation, status tracking):

```sql
-- Recipes indexed from KitchenOS vault
CREATE TABLE recipes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  content_hash TEXT UNIQUE NOT NULL,
  source_url TEXT,
  source_channel TEXT,
  file_path TEXT NOT NULL,
  -- Structured data (from frontmatter)
  servings INTEGER,
  prep_time_minutes INTEGER,
  cook_time_minutes INTEGER,
  difficulty TEXT,
  cuisine TEXT,
  protein TEXT,
  dish_type TEXT,
  meal_occasions TEXT,      -- JSON: ["weeknight-dinner","meal-prep"]
  dietary TEXT,             -- JSON: ["gluten-free","vegetarian"]
  ingredients TEXT NOT NULL, -- JSON: [{amount, unit, item}]
  calories INTEGER,
  nutrition_protein INTEGER,
  carbs INTEGER,
  fat INTEGER,
  -- Workflow tracking
  indexed_at DATETIME NOT NULL,
  updated_at DATETIME,
  status TEXT DEFAULT 'active',
  test_run TEXT DEFAULT NULL
);

-- Weekly meal plans (written by SeleneChat, exported to Obsidian)
CREATE TABLE meal_plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  week TEXT NOT NULL UNIQUE,    -- ISO: "2026-W07"
  status TEXT DEFAULT 'draft',  -- draft/active/completed
  created_at DATETIME NOT NULL,
  updated_at DATETIME,
  exported_at DATETIME,
  test_run TEXT DEFAULT NULL
);

-- Individual meal slots in a plan
CREATE TABLE meal_plan_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  meal_plan_id INTEGER NOT NULL,
  day TEXT NOT NULL,             -- "monday","tuesday"...
  meal TEXT NOT NULL,            -- "breakfast","lunch","dinner"
  recipe_id INTEGER,            -- FK to recipes (NULL = manual entry)
  recipe_title TEXT NOT NULL,   -- Denormalized for display
  notes TEXT,
  FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id),
  FOREIGN KEY (recipe_id) REFERENCES recipes(id),
  UNIQUE(meal_plan_id, day, meal)
);

-- Shopping list items aggregated from meal plan
CREATE TABLE shopping_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  meal_plan_id INTEGER NOT NULL,
  ingredient TEXT NOT NULL,
  amount REAL,
  unit TEXT,
  category TEXT,                -- produce/dairy/meat/pantry
  checked INTEGER DEFAULT 0,
  created_at DATETIME NOT NULL,
  FOREIGN KEY (meal_plan_id) REFERENCES meal_plans(id)
);
```

**Key decisions:**
- `recipes` stores parsed frontmatter, not raw markdown
- `meal_plan_items` links to `recipes` by ID but denormalizes title (plans survive if recipe file moves)
- `shopping_items` belong to a meal plan, not individual recipes (aggregated)
- No embedding table yet -- add later if semantic recipe search proves valuable

---

## Recipe Indexer Workflow

New TypeScript workflow `src/workflows/index-recipes.ts`:

1. **Scan** KitchenOS vault `Recipes/` directory for `.md` files
2. **Parse** each file: YAML frontmatter (structured recipes) or plain markdown (Cooking Mode format)
3. **Hash** content for dedup -- skip unchanged files on re-index
4. **Upsert** into `recipes` table -- new files inserted, changed files updated
5. **Log** results via Pino

**Schedule:** Every 30 minutes via WorkflowScheduler

**Config:**
```typescript
kitchenOsVaultPath: process.env.KITCHENOS_VAULT_PATH
  || path.join(homedir(), 'Library/Mobile Documents/iCloud~md~obsidian/Documents/KitchenOS')
```

**Parsing strategy:**
- Files with YAML frontmatter: parse frontmatter for all structured fields
- Cooking Mode files (no frontmatter): parse `*amount unit* ingredient` format, title from H1
- Both: content_hash from full file for change detection

**Also indexes existing meal plans** from `Meal Plans/` into `meal_plans` + `meal_plan_items` to seed history.

---

## SeleneChat Meal Planning Chat

### Query Detection

New case in `QueryAnalyzer`:

```swift
case mealPlanning
```

Detection patterns: `"meal plan"`, `"what should i cook"`, `"dinner ideas"`, `"plan next week"`, `"meal prep"`, `"what to eat"`, `"grocery list"`, `"shopping list"`

### Context Building

New `MealPlanContextBuilder` assembles context from Selene DB:

- **Recipe library** -- all active recipes: title, cuisine, protein, prep time, meal occasions, dietary tags (~50 tokens per recipe)
- **Recent meal plans** -- last 2-3 weeks to avoid repetition
- **Nutrition targets** -- from KitchenOS `My Macros.md`
- **Token budget:** ~2,500 tokens

### Prompt Building

New `MealPlanPromptBuilder` system prompt:

- You're a meal planning assistant for someone with ADHD
- Suggest concrete recipes from their library (not generic ideas)
- Keep plans realistic -- don't over-schedule complex meals
- Use structured action markers for output

### Action Markers

Two new marker types (extends existing `ActionExtractor`):

```
[MEAL: monday | dinner | Pasta Carbonara | recipe_id: 42]
[SHOP: eggs | 6 | count | dairy]
```

Parsed into pending actions, displayed in confirmation banner (same pattern as thread workspace).

### Conversation Flow

1. User: "Help me plan next week's meals"
2. SeleneChat builds context (recipes + recent meals + nutrition) -> Ollama
3. LLM suggests a week from the recipe library with reasoning
4. User: "Swap Tuesday dinner, I don't feel like chicken"
5. Multi-turn refinement
6. User: "Looks good, save it"
7. Actions fire: write meal_plan_items, aggregate shopping_items, export to Obsidian

### UI Integration

Works through existing main chat -- no separate view. QueryAnalyzer detects meal planning intent, ChatViewModel routes to `handleMealPlanningQuery()`. Feels natural, not modal.

---

## KitchenOS Awareness (Bidirectional)

Selene writes outputs in KitchenOS-native formats so existing infrastructure picks them up.

### Meal Plans -> KitchenOS Format

Selene exports meal plans in the exact format `meal_plan_parser.py` reads:

```markdown
# Meal Plan - Week 08 (Feb 16 - Feb 22)

## Monday (2026-02-16)
### Breakfast
[[Overnight Oats]]

### Lunch
[[Pasta Carbonara]]

### Dinner
[[Sheet Pan Chicken]]

### Notes
Meal prep carbonara Sunday night
```

This means KitchenOS's `shopping_list.py`, `sync_calendar.py`, and `generate_nutrition_dashboard.py` all work unchanged on Selene-created plans.

### Shopping Lists -> Obsidian

Selene writes aggregated shopping list markdown to Obsidian in KitchenOS format. User triggers Reminders sync via existing button/API. Keeps Selene read-heavy/write-light toward KitchenOS.

### Status File

```
KitchenOS/Selene Integration/Status.md
```

Contains: last indexed timestamp, recipe count, active meal plan, shopping list status. Makes integration visible in Obsidian (ADHD: out of sight = out of mind).

---

## Phasing

### Phase 1: Recipe Indexer (Backend only)
**Scope:** ~2-3 days

- DB migration with 4 new tables
- `index-recipes.ts` workflow -- scan, parse, upsert
- Index existing meal plans into history tables
- Config: `KITCHENOS_VAULT_PATH`
- WorkflowScheduler integration (every 30 min)
- Tests with test_run isolation

**Ship criterion:** `recipes` table populated with all vault recipes, meal plan history indexed.

### Phase 2: SeleneChat Meal Planning Chat
**Scope:** ~3-4 days

- `Recipe` Swift model + `DatabaseService` query methods
- `QueryAnalyzer` -- `.mealPlanning` detection
- `MealPlanContextBuilder` -- recipe library + recent meals + nutrition
- `MealPlanPromptBuilder` -- system prompt, MEAL/SHOP markers
- `ChatViewModel.handleMealPlanningQuery()` routing
- `ActionExtractor` -- parse MEAL and SHOP markers
- Pending action confirmation -> write to DB
- Tests for detection, context, action extraction

**Ship criterion:** Multi-turn meal planning conversation in SeleneChat. Meals and shopping items saved to DB on confirm.

### Phase 3: Obsidian Export + KitchenOS Awareness
**Scope:** ~1-2 days

- Export meal plan to Obsidian in KitchenOS format (wiki links, day structure)
- Export shopping list markdown
- Status file in KitchenOS vault
- Optional: Things tasks for meal prep items
- Integration test: plan in SeleneChat -> Obsidian -> KitchenOS tools work

**Ship criterion:** Full loop. Plan in SeleneChat, shopping list in Obsidian, KitchenOS calendar/nutrition/Reminders work on Selene-created plans.

---

## Acceptance Criteria

- [ ] Recipes from KitchenOS vault indexed into Selene DB (content_hash dedup, incremental updates)
- [ ] SeleneChat detects meal planning queries and routes to specialized handler
- [ ] Multi-turn meal planning conversation suggests recipes from user's library
- [ ] Confirmed meal plan writes to DB and exports to Obsidian in KitchenOS format
- [ ] Shopping list aggregated from plan and written to Obsidian
- [ ] KitchenOS `shopping_list.py` can read Selene-created meal plans
- [ ] KitchenOS `sync_calendar.py` can read Selene-created meal plans
- [ ] No changes required to KitchenOS codebase

## ADHD Check

- [x] **Reduces friction** -- Conversational planning replaces manual template filling
- [x] **Makes time visible** -- Prep times, meal complexity visible in planning chat
- [x] **Externalizes cognition** -- "What have I eaten recently" answered by system, not memory
- [x] **Realistic over idealistic** -- Suggests from existing recipe library, not aspirational cooking
- [x] **Visual** -- Status file in Obsidian, plans visible in vault

## Scope Check

- [x] < 1 week per phase (3 phases, each 1-4 days)
- [x] No KitchenOS changes required
- [x] Each phase independently shippable
