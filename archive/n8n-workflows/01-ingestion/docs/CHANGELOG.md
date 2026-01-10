# Ingestion Workflow - Changelog

## 2025-10-30 - Test Data Management Added

### Added
- **Test Data Marking System**
  - Added `test_run` column to `raw_notes` table
  - Added index on `test_run` for performance
  - Workflow now accepts optional `test_run` parameter

- **New Scripts**
  - `test-with-markers.sh` - Enhanced test script with automatic test data marking
  - `cleanup-tests.sh` - Comprehensive test data cleanup utility

- **Documentation**
  - `TEST-DATA-MANAGEMENT.md` - Complete guide for test data management
  - Updated README.md with new testing workflow
  - Updated STATUS.md with test data management section

### Changed
- **Workflow Updates**
  - Parse Note Data function now extracts `test_run` parameter
  - Insert Note function stores `test_run` in database
  - All test data is now marked for easy identification

- **Testing Workflow**
  - Original `test.sh` marked as deprecated
  - New recommended approach uses `test-with-markers.sh`

### Benefits
- ✅ Easy identification of test vs production data
- ✅ Programmatic cleanup of test data
- ✅ No more manual database cleaning
- ✅ Test run tracking and history
- ✅ Safe bulk operations on test data only

### Migration Required
- Re-import workflow to support `test_run` parameter
- Run database migration to add `test_run` column (already done)
- Update test procedures to use new scripts

## 2025-10-30 - Initial Testing Complete

### Fixed
- **better-sqlite3 Module Loading**
  - Changed from global path to workspace installation
  - Added `NODE_PATH` and `NODE_FUNCTION_ALLOW_EXTERNAL` env vars

- **Switch Node Logic**
  - Changed from `switch` with `notExists` to `if` with explicit null check
  - Fixed issue where notes weren't being inserted

### Testing
- ✅ 6/7 core tests passed (86% success rate)
- ❌ Alternative query format not supported (known limitation)
- All critical functionality verified working

### Status
- Ready for production use
- Test data management system implemented
- Complete documentation provided

## 2025-10-29 - Initial Configuration

### Created
- Workflow structure in `workflows/01-ingestion/`
- Database schema for `raw_notes` table
- Comprehensive test suite
- Documentation (README, TEST, STATUS)

### Features
- Webhook endpoint for note ingestion
- Content hash-based duplicate detection
- Automatic tag extraction (#hashtags)
- Word and character count calculation
- Flexible input format support
- Error handling and validation
