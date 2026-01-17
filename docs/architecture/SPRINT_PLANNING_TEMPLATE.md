# Sprint Planning - [Sprint Name]

> **Sprint**: [Name/Number]
> **Duration**: [Start Date] - [End Date]
> **Focus**: [Main theme/goal]

---

## Sprint Goals

### Primary Objectives
1. [Goal 1]
2. [Goal 2]
3. [Goal 3]

### Success Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

---

## Work Packages

### Package 1: [Name]
**Team**: [Team name/role]
**Effort**: [X-Y hours]
**Priority**: [HIGH/MEDIUM/LOW]

**Deliverables**:
- [ ] [Deliverable 1]
- [ ] [Deliverable 2]

**Files to Modify**:
- `path/to/file1.gd`
- `path/to/file2.gd`

**Technical Details**:
- [Key implementation detail 1]
- [Key implementation detail 2]

---

### Package 2: [Name]
**Team**: [Team name/role]
**Effort**: [X-Y hours]
**Priority**: [HIGH/MEDIUM/LOW]

**Deliverables**:
- [ ] [Deliverable 1]
- [ ] [Deliverable 2]

**Files to Modify**:
- `path/to/file1.gd`
- `path/to/file2.gd`

**Technical Details**:
- [Key implementation detail 1]
- [Key implementation detail 2]

---

## Architecture Considerations

### Design Decisions
- **Decision 1**: [Description and rationale]
- **Decision 2**: [Description and rationale]

### RNG and Determinism
- [How RNG will be handled]
- [Seed management strategy]
- [Expected RNG consumption patterns]

### Model Extensions
- [New fields or models needed]
- [Changes to existing models]
- [Data migration requirements]

### Risk Assessment
- **Risk 1**: [Description] → [Mitigation strategy]
- **Risk 2**: [Description] → [Mitigation strategy]

---

## Testing Strategy

### Unit Tests
- [ ] [Test area 1 - specific functions/classes]
- [ ] [Test area 2 - specific functions/classes]
- [ ] [Test area 3 - edge cases]

### Integration Tests
- [ ] [Test scenario 1 - end-to-end flow]
- [ ] [Test scenario 2 - system interaction]

### Determinism Tests
- [ ] [Verify same seed produces same results]
- [ ] [Verify RNG propagation through system]

### Manual Testing
- [ ] [User workflow 1]
- [ ] [User workflow 2]

---

## Dependencies

### Prerequisite Work
- [List any work that must be complete before this sprint]

### Blocking Issues
- [List any known blockers or dependencies]

### External Dependencies
- [List any external library or resource needs]

---

## Timeline

| Day | Milestone | Owner |
|-----|-----------|-------|
| Day 1 | [Milestone] | [Role] |
| Day 2 | [Milestone] | [Role] |
| Day 3 | [Milestone] | [Role] |
| Day 4 | [Milestone] | [Role] |
| Day 5 | [Milestone] | [Role] |

---

## Review Criteria

### Code Quality
- [ ] All functions have proper RNG parameter passing
- [ ] No magic numbers (all constants defined)
- [ ] Type safety maintained (no 'any' types)
- [ ] Proper error handling and validation
- [ ] Documentation and comments complete

### Simulation Integrity
- [ ] Determinism verified with multiple seeds
- [ ] No global state modifications
- [ ] Lifecycle transitions properly encoded
- [ ] All probability formulas documented

### User Experience
- [ ] UI responsive and intuitive
- [ ] Error messages clear and helpful
- [ ] Loading states properly handled
- [ ] Edge cases handled gracefully

---

## Definition of Done

Sprint is complete when:
- [ ] All work packages completed and merged
- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] Determinism tests passing
- [ ] Manual playtesting complete
- [ ] Code reviewed and approved
- [ ] Documentation updated
- [ ] PR merged to main branch

---

## Notes

[Additional context, decisions, or information relevant to this sprint]

---

*Template created: 2026-01-17*
*Template version: 1.0*
