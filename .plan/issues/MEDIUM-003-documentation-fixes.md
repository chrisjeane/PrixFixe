# MEDIUM-003: Documentation Path and Version Fixes

**Status**: 🟡 Should fix before v0.2.0
**Severity**: MEDIUM
**Created**: 2025-11-28
**Priority**: P1 - Quick wins for release quality
**Assignee**: TBD
**Estimated Effort**: 15-20 minutes total

---

## Summary

Multiple quick-fix documentation issues that should be resolved before v0.2.0 release:
1. Broken TLS-GUIDE.md path references (3 locations)
2. Incorrect version in installation instructions
3. Incorrect test count reporting

## Issues

### Issue A: Broken TLS Guide Path References

**Locations**: README.md lines 98, 210, 322

**Current** (incorrect):
```markdown
See [docs/TLS-GUIDE.md](docs/TLS-GUIDE.md) for detailed TLS configuration options.
```

**Actual path**: `Documentation/TLS-GUIDE.md`

**Impact**: Users clicking documentation links get 404 errors on GitHub

**Fix**:
```diff
- See [docs/TLS-GUIDE.md](docs/TLS-GUIDE.md)
+ See [Documentation/TLS-GUIDE.md](Documentation/TLS-GUIDE.md)
```

**Estimated time**: 3 minutes

---

### Issue B: Version Number in Installation Instructions

**Location**: README.md line 108

**Current** (incorrect):
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/PrixFixe.git", from: "0.1.0")
]
```

**Should be**:
```swift
dependencies: [
    .package(url: "https://github.com/yourusername/PrixFixe.git", from: "0.2.0")
]
```

**Impact**: Users will install old v0.1.0 without TLS support

**Estimated time**: 2 minutes

---

### Issue C: Test Count Reporting

**Locations**: README.md lines 17, 30

**Current** (incorrect):
- Line 17: "243/252 tests passing ✅"
- Line 30: "252 tests covering all modules (243/252 passing, 9 fail only on macOS 26.1 beta)"

**Actual status** (from test run):
- 258 total tests
- 248 passing
- 10 failures (9 expected Network.framework + 1 performance)

**Fix**:
```diff
- **Current Status**: 243/252 tests passing ✅ | Zero warnings ✅
+ **Current Status**: 248/258 tests passing ✅ | Zero warnings ✅

- **Well-Tested**: 252 tests covering all modules (243/252 passing, 9 fail only on macOS 26.1 beta)
+ **Well-Tested**: 258 tests covering all modules (248/258 passing, 9 fail only on macOS 26.1 beta, 1 performance threshold)
```

**Impact**: Inaccurate reporting of project status

**Estimated time**: 3 minutes

---

### Issue D: TLS-GUIDE.md Path in CHANGELOG (Bonus)

**Location**: CHANGELOG.md line 275

**Current**:
```markdown
See [docs/TLS-GUIDE.md](docs/TLS-GUIDE.md) for complete TLS configuration documentation.
```

**Should be**:
```markdown
See [Documentation/TLS-GUIDE.md](Documentation/TLS-GUIDE.md) for complete TLS configuration documentation.
```

**Estimated time**: 2 minutes

---

## Combined Fix Script

All fixes can be done with simple find-replace:

```bash
# Fix 1: TLS-GUIDE.md paths
sed -i '' 's|docs/TLS-GUIDE.md|Documentation/TLS-GUIDE.md|g' README.md
sed -i '' 's|docs/TLS-GUIDE.md|Documentation/TLS-GUIDE.md|g' CHANGELOG.md

# Fix 2: Version number
sed -i '' 's|from: "0.1.0"|from: "0.2.0"|g' README.md

# Fix 3: Test counts (manual review recommended)
# Line 17: 243/252 → 248/258
# Line 30: 252 tests... (243/252 passing → 248/258 passing
```

Or manually edit the files (recommended for accuracy).

## Files to Update

1. `/Users/chris/Code/MCP/PrixFixe/README.md`
   - Line 17: Test count (243/252 → 248/258)
   - Line 30: Test description
   - Line 98: TLS guide path
   - Line 108: Version (0.1.0 → 0.2.0)
   - Line 210: TLS guide path
   - Line 322: TLS guide path

2. `/Users/chris/Code/MCP/PrixFixe/CHANGELOG.md`
   - Line 275: TLS guide path (if present)

## Verification

After fixes:
```bash
# Verify no more references to docs/TLS-GUIDE.md
grep -r "docs/TLS-GUIDE.md" .

# Verify version is 0.2.0
grep -n "from: \"0." README.md

# Verify test counts
grep -n "tests passing" README.md
```

## Acceptance Criteria

- [ ] All TLS-GUIDE.md references point to `Documentation/TLS-GUIDE.md`
- [ ] Installation instructions reference version `0.2.0`
- [ ] Test count shows `248/258` tests passing
- [ ] No broken links when viewing on GitHub
- [ ] Changes committed before release tag

---

**Priority**: P1 - Should definitely fix before v0.2.0
**Effort**: 15-20 minutes
**Risk**: Zero (simple documentation fixes)
**Impact**: High (professional quality, user experience)
