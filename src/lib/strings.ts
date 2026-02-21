/**
 * Normalize a thread name by splitting camelCase/PascalCase into separate words.
 * e.g. "SocialInteractionImprovement" -> "Social Interaction Improvement"
 */
export function normalizeThreadName(name: string): string {
  return name
    .replace(/([a-z])([A-Z])/g, '$1 $2')   // camelCase boundaries
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2') // consecutive caps like "HTMLParser" -> "HTML Parser"
    .trim();
}
