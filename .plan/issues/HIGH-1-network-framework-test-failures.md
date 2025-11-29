# HIGH-1: Network.framework Tests Failing (9 failures)

**Created:** 2025-11-28
**Severity:** HIGH
**Status:** OPEN
**Blocks:** v0.2.1 release (investigation required)
**Component:** PrixFixeNetworkTests/NetworkFrameworkSocketTests.swift
**Related:** V0.2.1-RELEASE-REVIEW.md, MACOS-BETA-WORKAROUND.md

---

## Problem

All 9 Network.framework socket tests are failing on the current test platform (macOS 25.1.0 beta). This indicates that the Network.framework transport is not working as expected, though the system correctly falls back to FoundationSocket.

**Test Results:**
- Failed Tests: 9/9 (100% failure rate)
- Test Suite: NetworkFrameworkSocketTests
- Platform: macOS 25.1.0 (Darwin 25.1.0)
- Current Transport: FoundationSocket (workaround active)

**Failed Tests:**
1. NetworkFrameworkSocket can bind to ephemeral port
2. NetworkFrameworkSocket can bind to any address
3. NetworkFrameworkSocket supports IPv4-mapped addresses
4. NetworkFrameworkSocket can accept connections
5. NetworkFrameworkSocket supports IPv6 addresses
6. NetworkFrameworkSocket properly cleans up on close
7. NetworkFrameworkSocket connection can read and write data
8. NetworkFrameworkSocket can create and bind to address
9. NetworkFrameworkSocket implements NetworkTransport protocol

---

## Current Status

### What's Working

- ✅ FoundationSocket implementation (8/8 tests passing)
- ✅ SocketFactory correctly detects macOS beta and uses FoundationSocket
- ✅ Production SMTP server works correctly with FoundationSocket
- ✅ All core functionality tests passing

### What's Not Working

- ❌ Network.framework tests all failing
- ❌ Network.framework transport not verified
- ❌ Unknown if Network.framework works on stable macOS versions

---

## Root Cause Analysis

### Known Factors

1. **macOS Beta Platform:**
   - Current platform: macOS 25.1.0 beta (Darwin 25.1.0)
   - Network.framework may have beta-specific bugs
   - Documented in MACOS-BETA-WORKAROUND.md

2. **SocketFactory Behavior:**
   - Correctly detects beta and selects FoundationSocket
   - Network.framework code path not exercised in production
   - Tests explicitly try to test Network.framework

3. **Test Assumptions:**
   - Tests may assume Network.framework is the active transport
   - May not account for SocketFactory workaround logic
   - Tests may need platform-specific skipping

### Investigation Needed

1. **Verify on Stable macOS:**
   - Test on macOS 13.x (Ventura)
   - Test on macOS 14.x (Sonoma)
   - Determine if failures are beta-specific

2. **Review Test Implementation:**
   - Check if tests directly instantiate NetworkFrameworkSocket
   - Check if tests use SocketFactory (which would give FoundationSocket on beta)
   - Verify test setup matches expected behavior

3. **Check Network.framework Availability:**
   - Verify Network.framework is actually available on macOS beta
   - Check for API changes in beta
   - Review Apple documentation for known issues

---

## Impact Assessment

### Production Impact

**Low to Medium**

- **If beta-specific:** Low impact (production typically runs stable macOS)
- **If general bug:** Medium impact (users on stable macOS won't get Network.framework)

### Risk Analysis

**Primary Risk:** Network.framework may be broken on stable macOS versions without knowing

**Mitigation:**
- FoundationSocket is fully tested and works correctly
- System automatically falls back to FoundationSocket
- Users get working SMTP server regardless

**Secondary Risk:** Network.framework code path is untested

**Mitigation:**
- Network.framework is preferred but not required
- FoundationSocket provides equivalent functionality
- Both implementations tested independently

---

## Scenarios

### Scenario A: Beta-Specific Issue (Most Likely)

**Hypothesis:** Network.framework tests fail only on macOS beta, pass on stable

**Expected Results:**
- macOS 13/14: Tests pass, Network.framework works
- macOS 15 beta: Tests fail, FoundationSocket used (expected)

**Action:**
- Document as known beta issue
- Add platform check to skip tests on beta
- Note in release notes

**Impact:** Low - expected behavior, documented workaround

### Scenario B: Test Implementation Issue

**Hypothesis:** Tests don't account for SocketFactory beta workaround

**Expected Results:**
- Tests try to use Network.framework directly
- SocketFactory would give FoundationSocket on beta
- Test setup doesn't match production usage

**Action:**
- Fix tests to respect SocketFactory logic
- Add platform-aware test setup
- Verify tests pass with correct setup

**Impact:** Low - test issue, not code issue

### Scenario C: Network.framework Broken (Worst Case)

**Hypothesis:** Network.framework implementation has bugs affecting stable macOS

**Expected Results:**
- Tests fail on stable macOS too
- Network.framework code path broken
- Users on stable macOS get broken Network.framework

**Action:**
- Fix Network.framework implementation
- Extend SocketFactory workaround if needed
- Thorough testing on multiple macOS versions

**Impact:** Medium - requires code fix, but fallback works

---

## Investigation Plan

### Phase 1: Determine Scope (30 minutes)

1. **Review Test Implementation:**
   ```bash
   # Check how tests instantiate NetworkFrameworkSocket
   grep -n "NetworkFrameworkSocket(" Tests/PrixFixeNetworkTests/NetworkFrameworkSocketTests.swift

   # Check if tests use SocketFactory
   grep -n "SocketFactory" Tests/PrixFixeNetworkTests/NetworkFrameworkSocketTests.swift
   ```

2. **Review SocketFactory Logic:**
   - Check beta detection logic
   - Verify workaround is active
   - Confirm FoundationSocket is used

3. **Check Platform Version:**
   ```bash
   sw_vers
   uname -a
   ```

### Phase 2: Test on Stable macOS (1-2 hours)

**Required:** Access to stable macOS 13.x or 14.x

1. **Run Network.framework tests on stable macOS:**
   ```bash
   swift test --filter NetworkFrameworkSocketTests
   ```

2. **Compare results:**
   - If tests pass: Beta-specific issue (Scenario A)
   - If tests fail: Broader issue (Scenario B or C)

### Phase 3: Fix or Document (1-2 hours)

**If beta-specific:**
```swift
#if os(macOS)
import Darwin

@Suite("Network.framework Socket Tests")
struct NetworkFrameworkSocketTests {
    init() throws {
        // Skip on macOS beta
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.majorVersion >= 25 {
            throw XCTSkip("Network.framework tests skipped on macOS beta (known issue)")
        }
    }
    // ... tests
}
#endif
```

**If test implementation issue:**
- Fix tests to use SocketFactory correctly
- Add platform-aware test setup
- Document expected behavior

**If Network.framework broken:**
- Fix Network.framework implementation
- Add regression tests
- Consider extending workaround to affected versions

---

## Acceptance Criteria

- [ ] Root cause identified (beta-specific vs general issue)
- [ ] Tests verified on stable macOS 13.x or 14.x
- [ ] If beta-specific: Tests skip gracefully on beta
- [ ] If general issue: Network.framework implementation fixed
- [ ] All Network.framework tests pass on supported platforms
- [ ] Behavior documented in release notes
- [ ] SocketFactory workaround logic validated

---

## Recommended Actions

### Before v0.2.1 Release

**MUST DO:**
1. Identify if issue is beta-specific or general (30 min)
2. Test on stable macOS if available (1 hour)
3. Document findings in release notes

**SHOULD DO:**
4. Add platform check to skip tests on beta (30 min)
5. Verify SocketFactory workaround works as expected (30 min)

**CAN DEFER:**
6. Fix Network.framework if broken (defer to v0.2.2 if FoundationSocket works)

### If No Stable macOS Available

**Option 1: Document and Ship**
- Note in release notes: "Network.framework tests fail on macOS beta"
- Note: "FoundationSocket used as workaround (fully tested)"
- Note: "Please report if issues on stable macOS"
- Risk: Low (fallback works)

**Option 2: Skip Tests on Beta**
- Add platform check to skip tests
- Document in MACOS-BETA-WORKAROUND.md
- Ship with FoundationSocket tested
- Risk: Low (expected behavior)

**Recommendation:** Option 2 (skip tests on beta, document workaround)

---

## Effort Estimate

- **Investigation (review code):** 30 minutes
- **Testing on stable macOS:** 1-2 hours (if available)
- **Add test skipping:** 30 minutes
- **Documentation:** 30 minutes
- **Fix Network.framework (if needed):** 2-4 hours

**Total (without stable macOS):** 1.5 hours
**Total (with stable macOS):** 3-5 hours
**Total (if fix needed):** 5-9 hours

---

## Priority

**HIGH - INVESTIGATE BEFORE RELEASE**

While not blocking (FoundationSocket works), we need to understand:
1. Is this beta-specific or general?
2. Do we ship with failing tests?
3. Should we disable Network.framework on more platforms?

---

## Related Issues

- MACOS-BETA-WORKAROUND.md (SocketFactory beta detection)
- SocketFactory implementation
- Platform detection logic

---

## Resolution

**Status:** OPEN
**Assigned:** TBD
**Target:** Before v0.2.1 release (investigation) or v0.2.2 (fix if needed)
**Estimated Effort:** 1.5-9 hours (depends on findings)
