# Workflow Naming Convention

## Overview

As of 2025-11-01, all Selene n8n workflows follow a consistent naming convention for easy identification, sorting, and management.

## Format

**Production workflows:**
```
##-Name | Selene
```

**Test/development workflows:**
```
TEST-##-Name | Selene
```

## Components

1. **`TEST-` prefix** (optional)
   - Used for test, development, or experimental versions
   - Clearly identifies non-production workflows
   - Example: `TEST-02-LLM-Processing-Apple`

2. **`##`** - Two-digit workflow number
   - Corresponds to the workflow directory number
   - Range: 01-99
   - Examples: `01`, `02`, `05`

3. **`Name`** - Descriptive workflow name
   - Uses kebab-case (hyphens between words)
   - Clear, concise description of the workflow purpose
   - Examples: `Note-Ingestion`, `LLM-Processing`, `Sentiment-Analysis`

4. **` | Selene`** - System identifier suffix
   - Appears at the end of all workflow names
   - Helps group related workflows in n8n UI
   - Maintains consistency across the system

## Current Workflows

| Directory | Workflow Name | Type |
|-----------|---------------|------|
| `01-ingestion/` | `01-Note-Ingestion \| Selene` | Production |
| `02-llm-processing/` | `02-LLM-Processing \| Selene` | Production |
| `02-llm-processing_apple/` | `TEST-02-LLM-Processing-Apple \| Selene` | Test |
| `03-pattern-detection/` | `03-Pattern-Detection \| Selene` | Production |
| `04-obsidian-export/` | `04-Obsidian-Export \| Selene` | Production |
| `05-sentiment-analysis/` | `05-Sentiment-Analysis \| Selene` | Production |
| `06-connection-network/` | `06-Connection-Network \| Selene` | Production |

## Future Extensions (Optional)

The naming convention can be extended with version tags and management labels:

```
[TEST-]##-Name[-v#.#][-tag] | Selene
```

**Optional version tags:**
- `-v1.0` - Semantic versioning
- `-v2.1` - Version updates

**Optional management tags:**
- `-stable` - Production-ready, well-tested
- `-beta` - Testing phase, may change
- `-alpha` - Early development
- `-wip` - Work in progress
- `-deprecated` - Being phased out
- `-experimental` - Experimental feature
- `-hotfix` - Bug fix in progress

**Examples with extensions:**
```
01-Note-Ingestion-v1.2-stable | Selene
TEST-05-Sentiment-Analysis-v3.0-beta | Selene
02-LLM-Processing-v2.0-deprecated | Selene
```

## Benefits

1. **Consistent sorting** - Workflows appear in logical order in n8n UI
2. **Clear identification** - Easy to distinguish production from test workflows
3. **Searchable** - The `| Selene` suffix groups all workflows together
4. **Scalable** - Room for 99 workflows with clear numbering
5. **Flexible** - Can add versioning and tags when needed

## Migration Notes

- **Changed from:** `Selene: {Description}` format
- **Changed to:** `##-Name | Selene` format
- **Migration date:** 2025-11-01
- **Affected files:** All `workflow.json` files in workflow directories
- **Node names:** Unchanged - only workflow-level names updated

## Examples

**Before migration:**
```
Selene: Note Ingestion
Selene: LLM Processing
Selene: Sentiment Analysis (Enhanced v2)
Selene: Connection Network Analysis (Advanced)
```

**After migration:**
```
01-Note-Ingestion | Selene
02-LLM-Processing | Selene
05-Sentiment-Analysis | Selene
06-Connection-Network | Selene
```

## Updating Workflow Names

To update a workflow name:

1. **Edit the workflow.json file:**
   ```bash
   # Edit the "name" field at the top of the file
   vim workflows/##-name/workflow.json
   ```

2. **Update the name field:**
   ```json
   {
     "name": "##-Name | Selene",
     "active": true,
     ...
   }
   ```

3. **Re-import into n8n (if already imported):**
   - Delete the old workflow in n8n UI
   - Import the updated workflow.json file
   - Reactivate the workflow

## Best Practices

1. **Use TEST- prefix** for all non-production workflows
2. **Keep names concise** - Focus on the primary function
3. **Use kebab-case** - Hyphens between words (e.g., `LLM-Processing` not `LLM_Processing`)
4. **Match directory numbers** - Workflow `02-Name` should be in `02-name/` directory
5. **Avoid special characters** - Stick to letters, numbers, and hyphens
6. **Don't embed versions** in names unless using the extended format consistently

## Maintenance

- Review workflow names quarterly for consistency
- Update this document when new patterns emerge
- Ensure all new workflows follow this convention from creation
- Document any deviations in workflow-specific README files
