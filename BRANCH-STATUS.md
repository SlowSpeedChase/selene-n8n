# Branch: phase-7.2d/ai-provider-toggle

## Status: dev

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
- [ ] Manual testing of toggle flow
- [ ] Test local-only mode
- [ ] Test cloud mode with API key
- [ ] Test missing API key error

### Documentation
- [ ] Update SeleneChat README if needed
- [ ] Update CLAUDE.md context files if needed

### Review
- [ ] Code review complete
- [ ] All tests passing

## Files Changed
- `SeleneChat/Sources/Models/AIProvider.swift` (new)
- `SeleneChat/Sources/Services/AIProviderService.swift` (new)
- `SeleneChat/Sources/Views/AIProviderSettings.swift` (new)
- `SeleneChat/Sources/Views/PlanningView.swift` (modified)
- `SeleneChat/Tests/AIProviderTests.swift` (new)
