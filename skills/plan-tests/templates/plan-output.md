# Plan Output Template

> **FOR AI AGENT**: You MUST output the plan in EXACTLY this format. Fill in the placeholders with actual data from the coverage analysis. Do NOT skip any section. After outputting this, STOP and wait for user approval.

---

## 📋 Unit Test Generation Plan

### Coverage Goals

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Line Coverage | {{CURRENT_LINE}}% | {{TARGET_LINE}}% | +{{GAP_LINE}}% |
| Branch Coverage | {{CURRENT_BRANCH}}% | {{TARGET_BRANCH}}% | +{{GAP_BRANCH}}% |

### Test Plan (Priority Order)

| # | Priority | Class/Method | Tests | Risk | Reason |
|---|----------|--------------|-------|------|--------|
| 1 | 🔴 CRITICAL | {{CLASS_NAME}} | {{COUNT}} | {{RISK_SCORE}} | {{REASON}} |
| 2 | 🔴 CRITICAL | {{CLASS_NAME}} | {{COUNT}} | {{RISK_SCORE}} | {{REASON}} |
| ... | 🟠 HIGH | ... | ... | ... | ... |
| ... | 🟡 MEDIUM | ... | ... | ... | ... |
| ... | 🟢 LOW | ... | ... | ... | ... |

### Skip List (Untestable)

| Class | Reason |
|-------|--------|
| {{CLASS_NAME}} | {{REASON: e.g. "Creates real Azure SDK client in constructor"}} |
| {{CLASS_NAME}} | {{REASON}} |

### Summary

| Item | Value |
|------|-------|
| Total tests to generate | {{TOTAL_TESTS}} |
| Files to create/modify | {{FILE_COUNT}} |
| Estimated coverage after | {{ESTIMATED_COVERAGE}}% |
| Classes marked SKIP | {{SKIP_COUNT}} |

### Risks & Limitations

- {{LIST_ANY_RISKS: e.g. "Azure SDK classes cannot be mocked without wrappers"}}
- {{LIST_ANY_LIMITATIONS}}

---

## ⚠️ Approval Required

**Do you approve this plan? (Approve / Modify / Stop)**

- **Approve**: Proceed with test generation in priority order
- **Modify**: Tell me what to change (add/remove classes, adjust scope)
- **Stop**: Cancel test generation

---

> **AGENT RULE**: After outputting this plan, you MUST stop. Do NOT call `create_file`. Do NOT proceed to `generate-and-validate-tests`. Wait for user reply.
