# Completion Report Template

> **FOR AI AGENT**: After all test batches are complete, output the final report in EXACTLY this format. Fill placeholders with actual Coverlet data. Do NOT estimate or guess — use real coverage numbers from the Cobertura XML.

---

```
════════════════════════════════════════════════════════════════════
📊 Unit Test Generation — Completion Report
════════════════════════════════════════════════════════════════════

📋 Summary
──────────────────────────────────────────────────────────────────
  Tests Generated : {{TOTAL_NEW_TESTS}}
  Tests Passing   : {{PASSING_TESTS}} / {{TOTAL_TESTS_IN_PROJECT}}
  Test Files      : {{NEW_FILES_CREATED}} new, {{FILES_MODIFIED}} modified
  Workflow Mode   : {{MODE: full-repo | file-specific}}
  Component       : {{PROJECT_NAME}}

📈 Coverage Comparison (Before → After)
──────────────────────────────────────────────────────────────────
  Metric           │ Before     │ After      │ Change
  ─────────────────┼────────────┼────────────┼────────────
  Line Coverage    │ {{B_LINE}}%  │ {{A_LINE}}%  │ +{{D_LINE}}%
  Branch Coverage  │ {{B_BRANCH}}% │ {{A_BRANCH}}% │ +{{D_BRANCH}}%
  Lines Covered    │ {{B_LC}}/{{B_LV}} │ {{A_LC}}/{{A_LV}} │ +{{NEW_LINES}}

🧪 Test Files
──────────────────────────────────────────────────────────────────
  File                                          │ Tests │ Status
  ──────────────────────────────────────────────┼───────┼────────
  {{TEST_FILE_PATH}}                            │ {{N}}  │ ✅ Pass
  {{TEST_FILE_PATH}}                            │ {{N}}  │ ✅ Pass
  ...

⚫ Untestable (Skipped)
──────────────────────────────────────────────────────────────────
  Class                          │ Reason
  ───────────────────────────────┼─────────────────────────────────
  {{CLASS}}                      │ {{REASON}}
  ...

🔍 Verification Commands
──────────────────────────────────────────────────────────────────
  # Run all tests
  dotnet test {{SLN_PATH}}

  # Run with coverage
  dotnet test {{SLN_PATH}} --collect:"XPlat Code Coverage"

════════════════════════════════════════════════════════════════════
✅ WORKFLOW COMPLETE
════════════════════════════════════════════════════════════════════
```

---

## Template Rules

1. **Data sources**: Use ONLY Coverlet Cobertura XML for coverage numbers
2. **Before metrics**: From the baseline captured at workflow start
3. **After metrics**: From the final `dotnet test --collect` run after all batches
4. **Test counts**: From the actual `dotnet test` output (Passed/Failed/Total)
5. **Never estimate**: If you don't have a number, run the command to get it
6. **Untestable list**: Include ALL classes that were skipped with specific reasons
7. **Verification commands**: Must be copy-pasteable — use actual paths
