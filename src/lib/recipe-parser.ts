import { createHash } from 'node:crypto';

// ── Types ─────────────────────────────────────────────────────────

export interface RecipeRow {
  title: string;
  content_hash: string;
  source_url: string | null;
  source_channel: string | null;
  file_path: string;
  servings: number | null;
  prep_time_minutes: number | null;
  cook_time_minutes: number | null;
  difficulty: string | null;
  cuisine: string | null;
  protein: string | null;
  dish_type: string | null;
  meal_occasions: string | null;  // JSON array string
  dietary: string | null;         // JSON array string
  ingredients: string;            // JSON array string of {amount, unit, item}
  calories: number | null;
  nutrition_protein: number | null;
  carbs: number | null;
  fat: number | null;
}

interface Ingredient {
  amount: string;
  unit: string;
  item: string;
}

// ── Content Hash ──────────────────────────────────────────────────

function computeContentHash(content: string): string {
  return createHash('sha256').update(content).digest('hex');
}

// ── Time Parsing ──────────────────────────────────────────────────

/**
 * Parse a human-readable time string into minutes.
 *
 * Supported formats:
 *   "5 min", "5 minutes", "1 hour", "2 hours",
 *   "1 hour 30 min", "2h 15m", "1h", "45m"
 *
 * Returns null if the string cannot be parsed.
 */
export function parseTimeToMinutes(timeStr: string): number | null {
  if (!timeStr || !timeStr.trim()) return null;

  const s = timeStr.trim().toLowerCase();
  let totalMinutes = 0;
  let matched = false;

  // Match hours: "2 hours", "2h", "1 hour", "1.5 hours"
  const hourMatch = s.match(/(?:^|\s)([\d.]+)\s*(?:hours?|h)\b/);
  if (hourMatch) {
    totalMinutes += Math.round(parseFloat(hourMatch[1]) * 60);
    matched = true;
  }

  // Match minutes: "30 min", "30 minutes", "15m", "1.5 min"
  const minMatch = s.match(/(?:^|\s)([\d.]+)\s*(?:minutes?|mins?|m)\b/);
  if (minMatch) {
    totalMinutes += Math.round(parseFloat(minMatch[1]));
    matched = true;
  }

  return matched ? totalMinutes : null;
}

// ── YAML Frontmatter Parsing ──────────────────────────────────────

/**
 * Extract the YAML frontmatter block from a markdown file.
 * Returns the raw YAML string between the first two `---` delimiters.
 */
function extractFrontmatter(content: string): string | null {
  const lines = content.split('\n');
  if (lines[0].trim() !== '---') return null;

  let endIndex = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === '---') {
      endIndex = i;
      break;
    }
  }

  if (endIndex === -1) return null;
  return lines.slice(1, endIndex).join('\n');
}

/**
 * Parse simple YAML key-value pairs and arrays.
 * Returns a map of key -> string | string[].
 *
 * Handles:
 *   key: value           -> { key: "value" }
 *   key:                  -> { key: [] }  (if followed by   - items)
 *     - item1
 *     - item2
 */
function parseSimpleYaml(yaml: string): Record<string, string | string[]> {
  const result: Record<string, string | string[]> = {};
  const lines = yaml.split('\n');
  let currentArrayKey: string | null = null;

  for (const line of lines) {
    // Check for array item (indented with "  - ")
    const arrayItemMatch = line.match(/^\s+-\s+(.+)$/);
    if (arrayItemMatch && currentArrayKey) {
      const arr = result[currentArrayKey];
      if (Array.isArray(arr)) {
        arr.push(arrayItemMatch[1].trim());
      }
      continue;
    }

    // Check for key: value pair
    const kvMatch = line.match(/^([a-z_][a-z0-9_]*)\s*:\s*(.*)$/);
    if (kvMatch) {
      const key = kvMatch[1];
      const value = kvMatch[2].trim();

      if (value === '') {
        // Empty value — could be start of array
        result[key] = [];
        currentArrayKey = key;
      } else {
        result[key] = value;
        currentArrayKey = null;
      }
    } else {
      // Line doesn't match either pattern — reset array context
      currentArrayKey = null;
    }
  }

  return result;
}

/**
 * Parse ingredient table rows from markdown body.
 *
 * Expected format:
 *   | amount | unit | ingredient |
 *   |--------|------|------------|
 *   | 400    | g    | spaghetti  |
 */
function parseIngredientTable(content: string): Ingredient[] {
  const ingredients: Ingredient[] = [];
  const lines = content.split('\n');

  for (const line of lines) {
    // Skip non-table lines
    if (!line.trim().startsWith('|')) continue;
    // Skip separator rows (e.g., |---|---|---|)
    if (/^\s*\|[\s-|]+\|\s*$/.test(line)) continue;

    const cells = line
      .split('|')
      .map(c => c.trim())
      .filter(c => c.length > 0);

    if (cells.length < 3) continue;

    // Skip header row — check if first cell looks like a header word
    const firstLower = cells[0].toLowerCase();
    if (firstLower === 'amount' || firstLower === 'qty' || firstLower === 'quantity') continue;

    ingredients.push({
      amount: cells[0],
      unit: cells[1],
      item: cells[2],
    });
  }

  return ingredients;
}

/**
 * Parse a recipe file with YAML frontmatter (generated by extract_recipe.py).
 */
export function parseRecipeFrontmatter(content: string, filePath: string): RecipeRow {
  const yamlStr = extractFrontmatter(content);
  const yaml = yamlStr ? parseSimpleYaml(yamlStr) : {};

  const getString = (key: string): string | null => {
    const val = yaml[key];
    return typeof val === 'string' && val.length > 0 && val !== 'null' ? val : null;
  };

  const getNumber = (key: string): number | null => {
    const val = yaml[key];
    if (typeof val !== 'string' || val === 'null') return null;
    const n = parseFloat(val);
    return isNaN(n) ? null : n;
  };

  const getArray = (key: string): string[] | null => {
    const val = yaml[key];
    if (Array.isArray(val) && val.length > 0) return val;
    return null;
  };

  const ingredients = parseIngredientTable(content);
  const mealOccasions = getArray('meal_occasion');
  const dietaryItems = getArray('dietary');

  return {
    title: getString('title') || filePath,
    content_hash: computeContentHash(content),
    source_url: getString('source_url'),
    source_channel: getString('source_channel'),
    file_path: filePath,
    servings: getNumber('servings'),
    prep_time_minutes: parseTimeToMinutes(getString('prep_time') || ''),
    cook_time_minutes: parseTimeToMinutes(getString('cook_time') || ''),
    difficulty: getString('difficulty'),
    cuisine: getString('cuisine'),
    protein: getString('protein'),
    dish_type: getString('dish_type'),
    meal_occasions: mealOccasions ? JSON.stringify(mealOccasions) : null,
    dietary: dietaryItems ? JSON.stringify(dietaryItems) : null,
    ingredients: JSON.stringify(ingredients),
    calories: getNumber('calories'),
    nutrition_protein: getNumber('nutrition_protein'),
    carbs: getNumber('carbs'),
    fat: getNumber('fat'),
  };
}

// ── Cooking Mode Parsing ──────────────────────────────────────────

/**
 * Parse ingredients from Cooking Mode format.
 *
 * Pattern: `- *amount unit* item`
 * Example: `- *2 cups* all-purpose flour`
 */
function parseCookingModeIngredients(content: string): Ingredient[] {
  const ingredients: Ingredient[] = [];
  const lines = content.split('\n');

  for (const line of lines) {
    // Match: - *amount unit* item
    const match = line.match(/^-\s+\*([^*]+)\*\s+(.+)$/);
    if (!match) continue;

    const amountUnit = match[1].trim();
    const item = match[2].trim();

    // Split amount from unit: "2 cups" -> ["2", "cups"], "1/2 tsp" -> ["1/2", "tsp"]
    const auMatch = amountUnit.match(/^(\S+)\s+(.+)$/);
    if (auMatch) {
      ingredients.push({
        amount: auMatch[1],
        unit: auMatch[2].trim(),
        item,
      });
    } else {
      // No unit, just amount
      ingredients.push({
        amount: amountUnit,
        unit: '',
        item,
      });
    }
  }

  return ingredients;
}

/**
 * Parse a Cooking Mode recipe (plain markdown, no frontmatter).
 * Title comes from the H1 heading. Most metadata fields will be null.
 */
export function parseRecipeCookingMode(content: string, filePath: string): RecipeRow {
  // Extract title from H1
  let title = filePath;
  const h1Match = content.match(/^#\s+(.+)$/m);
  if (h1Match) {
    title = h1Match[1].trim();
  }

  const ingredients = parseCookingModeIngredients(content);

  // Extract servings: **4 servings** or **8 servings**
  let servings: number | null = null;
  const servingsMatch = content.match(/\*\*(\d+)\s+servings?\*\*/);
  if (servingsMatch) {
    servings = parseInt(servingsMatch[1], 10);
  }

  // Extract source: *Source: [Title](URL) by Channel*
  let sourceUrl: string | null = null;
  let sourceChannel: string | null = null;
  const sourceMatch = content.match(/\*Source:\s*\[([^\]]*)\]\(([^)]+)\)(?:\s+by\s+(.+?))?\*/);
  if (sourceMatch) {
    sourceUrl = sourceMatch[2] || null;
    sourceChannel = sourceMatch[3]?.trim() || null;
  }

  // Extract tags: first italic line that isn't a source line or ingredient
  // Pattern: *tag1, tag2, tag3* (standalone italic, not **bold** or *Source:*)
  let mealOccasions: string | null = null;
  const lines = content.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    // Match standalone italic text: *words* but not **bold** and not *Source:*
    const tagsMatch = trimmed.match(/^\*([^*]+)\*(?:\s|$)/);
    if (tagsMatch && !trimmed.startsWith('*Source:') && !trimmed.startsWith('**')) {
      const tagText = tagsMatch[1].trim();
      // Must contain a comma (multi-tag) or look like a tag category
      if (tagText.includes(',')) {
        const tags = tagText.split(',').map(t => t.trim()).filter(t => t.length > 0);
        if (tags.length > 0) {
          mealOccasions = JSON.stringify(tags);
        }
        break;
      }
    }
  }

  return {
    title,
    content_hash: computeContentHash(content),
    source_url: sourceUrl,
    source_channel: sourceChannel,
    file_path: filePath,
    servings,
    prep_time_minutes: null,
    cook_time_minutes: null,
    difficulty: null,
    cuisine: null,
    protein: null,
    dish_type: null,
    meal_occasions: mealOccasions,
    dietary: null,
    ingredients: JSON.stringify(ingredients),
    calories: null,
    nutrition_protein: null,
    carbs: null,
    fat: null,
  };
}
