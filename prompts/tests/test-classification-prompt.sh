#!/bin/bash

# Test Suite for Classification Prompt (Phase 7.1)
# Following TDD: These tests MUST fail before prompt is created
#
# Prompt: prompts/classification-prompt.txt
# Tests:
#   - File exists
#   - Contains all three classification categories
#   - Contains classification rules from metadata-definitions.md
#   - Specifies JSON output format
#   - Handles edge cases

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PROMPT_PATH="${PROMPT_PATH:-/Users/chaseeasterling/selene-n8n/.worktrees/task-extraction/prompts/classification-prompt.txt}"

PASSED=0
FAILED=0

# Test function
run_test() {
  local test_name="$1"
  local test_command="$2"

  echo -ne "${CYAN}Testing:${NC} $test_name... "

  if eval "$test_command" > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
    return 0
  else
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
    return 1
  fi
}

# =============================================================================
# TEST ASSERTIONS: File Structure
# =============================================================================

assert_file_exists() {
  [ -f "$PROMPT_PATH" ]
}

assert_file_not_empty() {
  [ -s "$PROMPT_PATH" ]
}

# =============================================================================
# TEST ASSERTIONS: Classification Categories
# =============================================================================

assert_contains_actionable_category() {
  grep -qi "actionable" "$PROMPT_PATH"
}

assert_contains_needs_planning_category() {
  grep -qi "needs_planning" "$PROMPT_PATH"
}

assert_contains_archive_only_category() {
  grep -qi "archive_only" "$PROMPT_PATH"
}

# =============================================================================
# TEST ASSERTIONS: Actionable Rules (from metadata-definitions.md)
# =============================================================================

assert_actionable_has_verb_object_rule() {
  # Must mention clear verb + object pattern
  grep -qi "verb" "$PROMPT_PATH" && grep -qi "object" "$PROMPT_PATH"
}

assert_actionable_has_single_session_rule() {
  # Must mention single session / completable
  grep -qi "single session\|one session\|completable" "$PROMPT_PATH"
}

assert_actionable_has_unambiguous_completion() {
  # Must mention unambiguous completion / "done"
  grep -qi "unambiguous\|done\|completion" "$PROMPT_PATH"
}

# =============================================================================
# TEST ASSERTIONS: Needs Planning Rules (from metadata-definitions.md)
# =============================================================================

assert_needs_planning_has_goal_outcome() {
  # Must mention goal or desired outcome
  grep -qi "goal\|outcome" "$PROMPT_PATH"
}

assert_needs_planning_has_multiple_tasks() {
  # Must mention multiple tasks
  grep -qi "multiple.*task\|several.*task" "$PROMPT_PATH"
}

assert_needs_planning_has_scoping() {
  # Must mention scoping or breakdown
  grep -qi "scoping\|breakdown" "$PROMPT_PATH"
}

assert_needs_planning_has_overwhelm_threshold() {
  # Must mention overwhelm > 7 threshold
  grep -qi "overwhelm.*7\|overwhelm factor" "$PROMPT_PATH"
}

assert_needs_planning_has_phrase_indicators() {
  # Must mention "want to", "should", "need to figure out"
  grep -qi "want to\|should\|need to figure out" "$PROMPT_PATH"
}

# =============================================================================
# TEST ASSERTIONS: Archive Only Rules (from metadata-definitions.md)
# =============================================================================

assert_archive_has_reflection() {
  # Must mention reflection/reflective
  grep -qi "reflect" "$PROMPT_PATH"
}

assert_archive_has_observation() {
  # Must mention observation
  grep -qi "observ" "$PROMPT_PATH"
}

assert_archive_has_no_action() {
  # Must mention no implied action
  grep -qi "no.*action\|no implied" "$PROMPT_PATH"
}

# =============================================================================
# TEST ASSERTIONS: Output Format
# =============================================================================

assert_specifies_json_output() {
  # Must specify JSON output format
  grep -qi "json" "$PROMPT_PATH"
}

assert_output_has_classification_field() {
  # Must show classification field in output
  grep -qi '"classification"' "$PROMPT_PATH"
}

assert_output_has_confidence_field() {
  # Must show confidence field in output
  grep -qi '"confidence"' "$PROMPT_PATH"
}

assert_output_has_reasoning_field() {
  # Must show reasoning field in output
  grep -qi '"reasoning"' "$PROMPT_PATH"
}

# =============================================================================
# TEST ASSERTIONS: Edge Cases
# =============================================================================

assert_handles_mixed_content() {
  # Must address mixed content scenarios
  grep -qi "mixed\|ambiguous\|unclear" "$PROMPT_PATH"
}

assert_has_doubt_handling() {
  # Must provide guidance for when in doubt
  grep -qi "doubt\|uncertain\|unsure" "$PROMPT_PATH"
}

assert_prefers_safer_classification() {
  # Must prefer needs_planning over actionable when in doubt
  grep -qi "doubt.*needs_planning\|safer\|prefer" "$PROMPT_PATH"
}

# =============================================================================
# TEST ASSERTIONS: Input Variables
# =============================================================================

assert_accepts_content_input() {
  grep -qi "content" "$PROMPT_PATH"
}

assert_accepts_concepts_input() {
  grep -qi "concepts" "$PROMPT_PATH"
}

assert_accepts_themes_input() {
  grep -qi "themes" "$PROMPT_PATH"
}

# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

# Header
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}  Classification Prompt - Test Suite${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${YELLOW}Prompt Path: $PROMPT_PATH${NC}"
echo ""

# File structure tests
echo -e "${BLUE}--- File Structure ---${NC}"
run_test "prompt file exists" assert_file_exists
run_test "prompt file is not empty" assert_file_not_empty
echo ""

# Classification categories tests
echo -e "${BLUE}--- Classification Categories ---${NC}"
run_test "contains 'actionable' category" assert_contains_actionable_category
run_test "contains 'needs_planning' category" assert_contains_needs_planning_category
run_test "contains 'archive_only' category" assert_contains_archive_only_category
echo ""

# Actionable rules tests
echo -e "${BLUE}--- Actionable Classification Rules ---${NC}"
run_test "actionable: verb + object rule" assert_actionable_has_verb_object_rule
run_test "actionable: single session rule" assert_actionable_has_single_session_rule
run_test "actionable: unambiguous completion" assert_actionable_has_unambiguous_completion
echo ""

# Needs planning rules tests
echo -e "${BLUE}--- Needs Planning Classification Rules ---${NC}"
run_test "needs_planning: goal/outcome" assert_needs_planning_has_goal_outcome
run_test "needs_planning: multiple tasks" assert_needs_planning_has_multiple_tasks
run_test "needs_planning: scoping/breakdown" assert_needs_planning_has_scoping
run_test "needs_planning: overwhelm > 7 threshold" assert_needs_planning_has_overwhelm_threshold
run_test "needs_planning: phrase indicators" assert_needs_planning_has_phrase_indicators
echo ""

# Archive only rules tests
echo -e "${BLUE}--- Archive Only Classification Rules ---${NC}"
run_test "archive_only: reflection" assert_archive_has_reflection
run_test "archive_only: observation" assert_archive_has_observation
run_test "archive_only: no implied action" assert_archive_has_no_action
echo ""

# Output format tests
echo -e "${BLUE}--- Output Format ---${NC}"
run_test "specifies JSON output" assert_specifies_json_output
run_test "output has 'classification' field" assert_output_has_classification_field
run_test "output has 'confidence' field" assert_output_has_confidence_field
run_test "output has 'reasoning' field" assert_output_has_reasoning_field
echo ""

# Edge cases tests
echo -e "${BLUE}--- Edge Case Handling ---${NC}"
run_test "handles mixed/ambiguous content" assert_handles_mixed_content
run_test "provides guidance when in doubt" assert_has_doubt_handling
run_test "prefers safer classification (needs_planning)" assert_prefers_safer_classification
echo ""

# Input variables tests
echo -e "${BLUE}--- Input Variables ---${NC}"
run_test "accepts content input" assert_accepts_content_input
run_test "accepts concepts input" assert_accepts_concepts_input
run_test "accepts themes input" assert_accepts_themes_input
echo ""

# Summary
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "Total: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}ALL TESTS PASSED - Classification prompt is complete!${NC}"
  exit 0
else
  echo -e "${YELLOW}TESTS FAILING - Expected for RED phase of TDD${NC}"
  echo -e "${YELLOW}Next step: Create classification-prompt.txt to make tests pass${NC}"
  exit 1
fi
