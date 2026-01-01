# Branch: phase-7.2d/ai-provider-toggle

## Status: ready

## Checklist

### Planning
- [x] Design document: `docs/plans/2025-12-31-ai-provider-toggle-design.md`
- [x] Implementation plan: `docs/plans/2025-12-31-ai-provider-toggle-implementation.md`

### Development
- [x] AIProvider enum created
- [x] AIProviderService created
- [x] PlanningMessage updated with provider field
- [x] Settings popover created
- [x] Provider toggle in header
- [x] Message sending uses provider
- [x] Visual indicators on messages
- [x] API key error handling

### Testing
- [x] Unit tests for AIProvider
- [x] Manual testing of toggle flow
- [x] Test local-only mode
- [x] Test cloud mode with API key
- [x] Test missing API key error
- [x] Fixed SQLite ambiguous column errors in JOIN queries
- [x] Fixed settings popover crash (removed async task during animation)

### Documentation
- [x] Update SeleneChat README if needed (N/A - internal feature)
- [ ] Update CLAUDE.md context files if needed (deferred)

### Review
- [x] Code review complete
- [x] All tests passing

## Files Changed
- `SeleneChat/Sources/Models/AIProvider.swift` (new)
- `SeleneChat/Sources/Services/AIProviderService.swift` (new)
- `SeleneChat/Sources/Services/DatabaseService.swift` (modified - qualified column refs)
- `SeleneChat/Sources/Views/AIProviderSettings.swift` (new)
- `SeleneChat/Sources/Views/PlanningView.swift` (modified)
- `SeleneChat/Tests/AIProviderTests.swift` (new)
