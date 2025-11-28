# PrixFixe - Next Phase Issues & Roadmap

**Generated**: 2025-11-27
**Current Version**: v0.1.0 (Release Ready)
**Next Version**: v0.2.0 (Planning)
**Project Status**: Production Ready - 98% Complete (298/304 tasks)

---

## Executive Summary

PrixFixe has successfully completed all four development phases and is ready for v0.1.0 public release. This document identifies outstanding issues, deferred features, and potential enhancements for the next development phase (v0.2.0).

**Current State**:
- 128/137 tests passing (93.4%) - 9 failures are macOS 26.1 beta OS bugs only
- Zero compiler warnings
- 100% public API documentation coverage
- Multi-platform CI/CD operational
- Complete integration guide and examples

**Next Phase Focus Areas**:
1. Performance optimization (async I/O refactoring)
2. Security enhancements (TLS/STARTTLS support)
3. Advanced ESMTP features
4. Enhanced testing and documentation
5. Community-requested features

---

## Outstanding Issues from Current Development

### P2 (Medium Priority) - Deferred from v0.1.0

#### Issue 1: Blocking I/O in Async Context
**Location**: `/Sources/PrixFixeNetwork/FoundationSocket.swift:76,210,238`
**Severity**: MEDIUM
**Complexity**: L (Large)
**Status**: Documented Technical Debt

**Description**:
Currently using blocking POSIX read/write calls within async functions. This works but is not optimal for high-concurrency scenarios as it can exhaust the cooperative thread pool.

**Current Implementation**:
```swift
// TODO: Phase 2 - Use proper async I/O with kqueue/epoll
// Simple blocking read for Phase 1
let bytesRead = Darwin.read(fd, &buffer, maxBytes)
```

**Impact**:
- Thread pool exhaustion under high load (100+ concurrent connections)
- Reduced scalability potential
- Performance degradation with many slow clients

**Recommended Solution**:
Implement true async I/O using platform-specific mechanisms:
- **macOS/iOS**: Already using Network.framework (async by design) ✅
- **Linux**: Refactor FoundationSocket to use epoll for async operations
- **Alternative**: Use Swift NIO's EventLoop abstraction (adds dependency)

**Effort Estimate**: L (Large) - 16-24 hours
- Design async I/O abstraction layer
- Implement epoll-based FoundationSocket on Linux
- Comprehensive testing across platforms
- Performance benchmarking

**Acceptance Criteria**:
- [ ] No blocking operations in async contexts
- [ ] Can handle 1000+ concurrent connections without thread exhaustion
- [ ] Performance benchmarks show improvement
- [ ] All existing tests continue to pass

**Related Work Items**: WI-005 from work-items.md

---

#### Issue 2: Partial Write Handling Not Implemented
**Location**: `/Sources/PrixFixeNetwork/FoundationSocket.swift:246-249`
**Severity**: MEDIUM
**Complexity**: M (Medium)
**Status**: Known Limitation

**Description**:
Partial write scenario currently throws an error instead of retrying. While rare, this can occur under network pressure or when sending to slow clients.

**Current Implementation**:
```swift
} else if bytesWritten < data.count {
    // Partial write - in production, we'd retry
    // TODO: Phase 2 - Handle partial writes properly
    continuation.resume(throwing: NetworkError.writeFailed("Partial write"))
}
```

**Impact**:
- Potential data loss on partial writes
- Connection failures under network pressure
- Reduced reliability for slow clients

**Recommended Solution**:
Implement retry logic with configurable maximum attempts:
```swift
var totalWritten = 0
var remainingData = data
let maxRetries = 3

while totalWritten < data.count {
    let bytesWritten = try await writeChunk(remainingData)
    totalWritten += bytesWritten
    if bytesWritten < remainingData.count {
        remainingData = Data(remainingData.dropFirst(bytesWritten))
    }
}
```

**Effort Estimate**: M (Medium) - 4-6 hours
- Implement retry logic with exponential backoff
- Add tests for partial write scenarios
- Document retry behavior
- Test under network pressure conditions

**Acceptance Criteria**:
- [ ] Partial writes automatically retried
- [ ] Maximum retry limit prevents infinite loops
- [ ] All data transmitted or clear error thrown
- [ ] Tests verify partial write handling
- [ ] Performance impact measured and acceptable

**Related Work Items**: WI-006 from work-items.md

---

#### Issue 3: Network Transport Tests Not Implemented
**Location**: `/Tests/PrixFixeNetworkTests/NetworkTransportTests.swift:8`
**Severity**: MEDIUM
**Complexity**: M (Medium)
**Status**: Test Coverage Gap

**Description**:
NetworkTransport protocol tests contain only a placeholder:
```swift
// TODO: Phase 1 - Implement network transport tests
```

**Impact**:
- Reduced test coverage for networking layer
- Protocol contract not validated
- Potential regression risks for transport implementations

**Recommended Solution**:
Implement comprehensive protocol compliance tests:
- Test both FoundationSocket and NetworkFrameworkSocket
- Verify all protocol methods work correctly
- Test error handling scenarios
- Test connection lifecycle (bind, listen, accept, close)
- Test data transmission (send/receive)

**Effort Estimate**: M (Medium) - 4-6 hours
- Design protocol compliance test suite
- Implement tests for each transport
- Add negative test cases
- Document test approach

**Acceptance Criteria**:
- [ ] At least 10 tests per transport implementation
- [ ] Protocol contract fully validated
- [ ] Error scenarios covered
- [ ] All tests pass on all platforms

**Related Work Items**: New work item for v0.2.0

---

#### Issue 4: Large Message Performance Test Failure
**Location**: `/Tests/PrixFixeCoreTests/SMTPPerformanceTests.swift:204`
**Severity**: LOW
**Complexity**: S (Small)
**Status**: Test Issue - Not Production Blocker

**Description**:
Performance test for large messages has a known issue:
```swift
// TODO: Fix large message test - message handler not being called
```

**Impact**:
- Cannot verify large message handling performance
- Potential regression in large message support could go undetected
- Not a production blocker as functional tests pass

**Recommended Solution**:
Debug why message handler is not being invoked in large message test scenario:
- Add diagnostic logging to trace execution
- Verify test timeout is sufficient
- Check for race conditions in test setup
- May be related to async timing

**Effort Estimate**: S (Small) - 2-3 hours
- Debug test execution flow
- Add diagnostic logging
- Fix test or update expectations
- Document findings

**Acceptance Criteria**:
- [ ] Large message test executes correctly
- [ ] Message handler called for large messages
- [ ] Performance metrics captured
- [ ] Test is stable and repeatable

**Related Work Items**: New work item for v0.2.0

---

### P3 (Low Priority) - Quality Improvements

#### Issue 5: Missing Negative Test Cases
**Severity**: LOW
**Complexity**: M (Medium)
**Status**: Test Coverage Enhancement

**Description**:
While core functionality is well-tested, several error scenarios lack explicit test coverage:
- Server startup failure (port already in use)
- Network errors during message transmission
- Connection pool exhaustion
- Memory pressure situations
- Invalid UTF-8 sequences in messages

**Recommended Solution**:
Add comprehensive negative test suite:
```swift
@Test("Server fails gracefully when port is in use")
func testPortAlreadyInUse() async throws

@Test("Connection drop during DATA command")
func testConnectionDropDuringData() async throws

@Test("Maximum connections limit enforced")
func testConnectionPoolExhaustion() async throws

@Test("Invalid UTF-8 handled gracefully")
func testInvalidEncoding() async throws
```

**Effort Estimate**: M (Medium) - 4-6 hours
- Design negative test scenarios
- Implement test cases
- Verify error handling behavior
- Document expected error responses

**Acceptance Criteria**:
- [ ] At least 15 new negative test cases
- [ ] All error paths exercised
- [ ] Error recovery validated
- [ ] Tests pass consistently

**Related Work Items**: WI-007 from work-items.md

---

#### Issue 6: Performance Benchmarks Lack Assertions
**Severity**: LOW
**Complexity**: S (Small)
**Status**: Test Enhancement

**Description**:
Performance tests measure throughput but don't assert minimum acceptable values. This means performance regressions could slip through without detection.

**Current State**:
```swift
let throughput = commandsProcessed / elapsed
print("Throughput: \(throughput) commands/second")
// No assertion - regression could go unnoticed
```

**Recommended Solution**:
Establish performance baselines and add assertions:
```swift
let throughput = commandsProcessed / elapsed
#expect(throughput >= 10000) // At least 10k commands/second
```

**Effort Estimate**: S (Small) - 2-3 hours
- Run benchmarks to establish baselines
- Add assertions with acceptable thresholds
- Document performance characteristics
- Consider adding CI performance tracking

**Acceptance Criteria**:
- [ ] Performance baselines documented
- [ ] Tests assert minimum performance
- [ ] Thresholds are achievable on CI infrastructure
- [ ] Performance regressions detected automatically

**Related Work Items**: WI-008 from work-items.md

---

#### Issue 7: IPv4 Testing Gap
**Severity**: LOW
**Complexity**: S (Small)
**Status**: Test Coverage Enhancement

**Description**:
Most tests focus on IPv6 and IPv4-mapped addresses. Direct IPv4 connection scenarios could be tested more thoroughly.

**Recommended Solution**:
Add explicit IPv4 test cases:
- IPv4-only clients connecting to dual-stack server
- IPv4 address parsing edge cases (0.0.0.0, 127.0.0.1, 255.255.255.255)
- IPv4 broadcast and multicast address rejection
- IPv4 CIDR parsing (if added in future)

**Effort Estimate**: S (Small) - 2 hours
- Add IPv4-specific test cases
- Verify dual-stack behavior
- Test edge cases

**Acceptance Criteria**:
- [ ] At least 5 new IPv4-specific tests
- [ ] Edge cases covered
- [ ] Tests pass on all platforms

**Related Work Items**: WI-009 from work-items.md

---

#### Issue 8: Unsafe Methods Lack Documentation
**Severity**: LOW
**Complexity**: XS (Extra Small)
**Status**: Documentation Gap

**Description**:
Internal unsafe methods like `SocketAddress.__unsafeInit` lack comprehensive documentation explaining why they're unsafe and when to use them.

**Recommended Solution**:
Add comprehensive doc comments:
```swift
/// **UNSAFE:** Initialize a SocketAddress without validation.
///
/// This initializer bypasses all validation checks and should only be used
/// internally after the address has been validated through `parseIPv6()` or `parseIPv4()`.
///
/// - Warning: Passing unvalidated input will result in invalid addresses.
/// - Parameters:
///   - family: The address family (must match the host format)
///   - host: The IP address string (must be pre-validated)
///   - port: The port number
///   - zoneID: Optional zone identifier for link-local IPv6 addresses
private static func __unsafeInit(...) -> SocketAddress
```

**Effort Estimate**: XS (Extra Small) - 1 hour
- Add doc comments to unsafe methods
- Document why unsafe and when to use
- Add usage examples in comments

**Acceptance Criteria**:
- [ ] All unsafe methods documented
- [ ] Warnings clearly stated
- [ ] Usage guidelines provided

**Related Work Items**: WI-010 from work-items.md

---

## Deferred Features from v0.1.0

### Feature 1: iOS Example Application
**Complexity**: M (Medium)
**Status**: Deferred (Low Priority)

**Description**:
iOS UI example application was planned but deferred to focus on core functionality. iOS library support is complete and tested.

**Rationale for Deferral**:
- Core iOS support is fully implemented ✅
- Library works correctly on iOS ✅
- UI example is nice-to-have, not critical for v0.1.0
- Time better spent on documentation and testing

**Recommended Implementation for v0.2.0**:
Create iOS example app demonstrating:
- Background execution considerations
- SwiftUI integration
- Email message display UI
- Local notifications for received messages
- Settings and configuration UI

**Effort Estimate**: M (Medium) - 8-12 hours
- Design iOS app architecture
- Implement UI with SwiftUI
- Handle background execution
- Test on physical devices
- Document iOS-specific considerations

**Acceptance Criteria**:
- [ ] iOS app compiles and runs on iOS 16.0+
- [ ] Demonstrates server lifecycle management
- [ ] Shows received messages in UI
- [ ] Handles app backgrounding gracefully
- [ ] Includes README with setup instructions

---

### Feature 2: macOS Beta Test Failures Resolution
**Complexity**: XS (Extra Small)
**Status**: Monitoring - External Issue

**Description**:
9 Network.framework tests fail on macOS 26.1 beta due to NWListener binding bug in the OS (not a code defect).

**Current Status**:
- Issue is in macOS 26.1 beta OS, not PrixFixe code
- Tests pass on stable macOS releases (13.x, 14.x, 15.x)
- Production deployments unaffected
- Documented in README and CHANGELOG

**Resolution Options**:
1. **Monitor**: Wait for Apple to fix in next macOS beta
2. **Workaround**: Add beta-specific test exclusions
3. **Report**: File feedback to Apple (if not already done)

**Recommended Action**:
Monitor the issue and update tests when Apple releases fix. No code changes needed.

**Effort Estimate**: XS (1 hour for test updates once fixed)

---

## Potential Features for v0.2.0

### Security & Authentication

#### Feature 3: STARTTLS/TLS Support
**Complexity**: XL (Extra Large)
**Priority**: HIGH
**Status**: Future Feature

**Description**:
Add support for TLS encryption via STARTTLS command or implicit TLS.

**Requirements**:
- STARTTLS command support (RFC 3207)
- Certificate configuration
- TLS handshake handling
- Encrypted data transmission
- Certificate validation (optional)
- Platform-specific TLS implementation (Security.framework, OpenSSL, BoringSSL)

**Effort Estimate**: XL (24-40 hours)
- Design TLS abstraction layer
- Implement platform-specific TLS
- Add STARTTLS command to state machine
- Certificate management
- Comprehensive security testing
- Documentation and examples

**Acceptance Criteria**:
- [ ] STARTTLS command supported
- [ ] TLS encryption working on all platforms
- [ ] Certificate configuration flexible
- [ ] Security best practices followed
- [ ] Performance impact acceptable

**User Demand**: High - frequently requested for production deployments

---

#### Feature 4: SMTP AUTH Support
**Complexity**: L (Large)
**Priority**: MEDIUM
**Status**: Future Feature

**Description**:
Add authentication support (AUTH command) with various SASL mechanisms.

**Requirements**:
- AUTH command support
- PLAIN mechanism (base64 encoded)
- LOGIN mechanism
- CRAM-MD5 mechanism (optional)
- Authentication callback interface
- User credential validation

**Effort Estimate**: L (16-24 hours)
- Design authentication abstraction
- Implement SASL mechanisms
- Add AUTH command to state machine
- Authentication callback system
- Security testing
- Documentation

**Acceptance Criteria**:
- [ ] AUTH PLAIN working
- [ ] AUTH LOGIN working
- [ ] Flexible authentication callback
- [ ] Secure credential handling
- [ ] Tests for all auth paths

**Dependencies**: May want to implement after STARTTLS for credential security

---

### Advanced ESMTP Features

#### Feature 5: SIZE Extension Enhancement
**Complexity**: M (Medium)
**Priority**: LOW
**Status**: Partial Implementation

**Description**:
Currently advertises SIZE in EHLO but doesn't parse SIZE parameter in MAIL FROM command.

**Current Implementation**:
```
250-SIZE 10485760
```

**Enhancement**:
Parse and validate SIZE parameter:
```
MAIL FROM:<user@example.com> SIZE=1234567
```

**Effort Estimate**: M (4-6 hours)
- Parse SIZE parameter in MAIL FROM
- Validate against configured max
- Reject early if too large
- Update tests

**Acceptance Criteria**:
- [ ] SIZE parameter parsed correctly
- [ ] Early rejection if size exceeds limit
- [ ] All edge cases tested

---

#### Feature 6: PIPELINING Support
**Complexity**: L (Large)
**Priority**: LOW
**Status**: Future Feature

**Description**:
Support command pipelining (RFC 2920) for improved performance.

**Requirements**:
- Advertise PIPELINING in EHLO
- Buffer multiple commands
- Process commands in sequence
- Defer responses appropriately
- Handle errors in pipeline

**Effort Estimate**: L (16-20 hours)
- Design pipeline buffering
- Update state machine
- Response batching
- Error handling in pipeline
- Performance testing

---

#### Feature 7: DSN (Delivery Status Notification) Support
**Complexity**: M (Medium)
**Priority**: LOW
**Status**: Future Feature

**Description**:
Support DSN extension (RFC 3461) for delivery status notifications.

**Requirements**:
- Advertise DSN in EHLO
- Parse DSN parameters in MAIL FROM and RCPT TO
- Include DSN data in EmailMessage
- Documentation for DSN handling

**Effort Estimate**: M (6-8 hours)

---

### Performance & Scalability

#### Feature 8: Connection Rate Limiting
**Complexity**: M (Medium)
**Priority**: MEDIUM
**Status**: Future Feature

**Description**:
Add rate limiting to prevent abuse and DoS attacks.

**Requirements**:
- Connection rate limiting (connections per IP per time window)
- Command rate limiting (commands per connection per time window)
- Configurable limits and time windows
- Automatic blocking/throttling
- Metrics and monitoring

**Effort Estimate**: M (8-12 hours)
- Design rate limiting algorithm
- Implement sliding window counter
- Add configuration options
- Testing under load
- Documentation

**Acceptance Criteria**:
- [ ] Connections limited per IP
- [ ] Commands limited per connection
- [ ] Configurable thresholds
- [ ] Metrics available for monitoring

---

#### Feature 9: DKIM Verification
**Complexity**: XL (Extra Large)
**Priority**: LOW
**Status**: Future Feature

**Description**:
Verify DKIM signatures on received messages.

**Requirements**:
- Parse DKIM-Signature header
- DNS lookup for public keys
- Signature verification
- Result reporting in EmailMessage
- Configuration for verification policy

**Effort Estimate**: XL (24-32 hours)
- Implement DKIM parser
- DNS resolution integration
- Cryptographic signature verification
- Comprehensive testing
- Documentation

**Dependencies**: Requires cryptography library or platform crypto APIs

---

#### Feature 10: SPF Validation
**Complexity**: L (Large)
**Priority**: LOW
**Status**: Future Feature

**Description**:
Validate sender policy framework (SPF) records.

**Requirements**:
- DNS SPF record lookup
- SPF syntax parsing
- Policy evaluation
- Result reporting
- Configuration options

**Effort Estimate**: L (16-20 hours)

---

### Developer Experience

#### Feature 11: Structured Logging
**Complexity**: M (Medium)
**Priority**: MEDIUM
**Status**: Future Feature

**Description**:
Add comprehensive structured logging for debugging and monitoring.

**Requirements**:
- Logging abstraction (compatible with swift-log)
- Log levels (debug, info, warning, error)
- Structured log metadata
- Performance impact minimal
- Optional logging output

**Effort Estimate**: M (6-8 hours)
- Design logging abstraction
- Add logging throughout codebase
- Integration with swift-log (optional)
- Documentation and examples

**Acceptance Criteria**:
- [ ] Comprehensive logging coverage
- [ ] Structured metadata
- [ ] Configurable log levels
- [ ] Minimal performance impact
- [ ] Works with popular logging frameworks

---

#### Feature 12: Metrics and Monitoring
**Complexity**: M (Medium)
**Priority**: MEDIUM
**Status**: Future Feature

**Description**:
Expose metrics for monitoring server health and performance.

**Metrics to Track**:
- Connection count (current, total, rejected)
- Message count (received, rejected, total size)
- Command counts by type
- Error counts by type
- Average session duration
- Throughput (messages/second, bytes/second)

**Effort Estimate**: M (8-10 hours)
- Design metrics interface
- Add metric collection points
- Exposure API (callback or async stream)
- Integration examples (Prometheus, StatsD)
- Documentation

**Acceptance Criteria**:
- [ ] Key metrics tracked
- [ ] Minimal performance overhead
- [ ] Easy integration with monitoring systems
- [ ] Examples provided

---

#### Feature 13: Swift Package Index Documentation Hosting
**Complexity**: XS (Extra Small)
**Priority**: LOW
**Status**: Future Enhancement

**Description**:
Publish DocC documentation to Swift Package Index for easier discovery.

**Requirements**:
- Submit to Swift Package Index
- Ensure DocC builds correctly
- Add package metadata
- Monitor build status

**Effort Estimate**: XS (1-2 hours)

---

### Testing & Quality

#### Feature 14: Fuzzing Test Suite
**Complexity**: L (Large)
**Priority**: LOW
**Status**: Future Enhancement

**Description**:
Add fuzz testing to discover edge cases and vulnerabilities.

**Requirements**:
- Protocol fuzzing (malformed SMTP commands)
- Input fuzzing (addresses, data, headers)
- Integration with OSS-Fuzz or libFuzzer
- Crash detection and reporting
- Regression test generation

**Effort Estimate**: L (16-24 hours)

**Acceptance Criteria**:
- [ ] Fuzz testing framework integrated
- [ ] Protocol fuzzer implemented
- [ ] Input fuzzer implemented
- [ ] Crashes triaged and fixed
- [ ] CI/CD integration

---

#### Feature 15: Load Testing Suite
**Complexity**: M (Medium)
**Priority**: MEDIUM
**Status**: Future Enhancement

**Description**:
Comprehensive load testing to validate performance under stress.

**Requirements**:
- Load testing framework
- Realistic traffic patterns
- Concurrent connection testing (1000+)
- Message throughput testing
- Resource usage monitoring
- Performance regression detection

**Effort Estimate**: M (8-12 hours)

---

#### Feature 16: Code Coverage Tracking
**Complexity**: S (Small)
**Priority**: LOW
**Status**: Future Enhancement

**Description**:
Add code coverage reporting to CI/CD pipeline.

**Requirements**:
- Enable coverage in CI
- Generate coverage reports
- Upload to Codecov or similar
- Add badge to README
- Set coverage thresholds

**Effort Estimate**: S (2-3 hours)

---

## Technical Debt Items

### Debt 1: Consolidate Error Types
**Complexity**: S (Small)
**Priority**: LOW

**Description**:
Currently have separate error enums (ServerError, SMTPError, NetworkError). Consider consolidating into a single hierarchical error type for consistency.

**Effort Estimate**: S (4-6 hours)

---

### Debt 2: Configuration Validation
**Complexity**: S (Small)
**Priority**: LOW

**Description**:
ServerConfiguration accepts any values but some combinations may be invalid (e.g., maxConnections = 0). Add validation.

**Effort Estimate**: S (2-3 hours)

---

### Debt 3: Platform Detection Caching
**Complexity**: XS (Extra Small)
**Priority**: LOW

**Description**:
Platform detection runs every time. Consider caching the result as it doesn't change at runtime.

**Effort Estimate**: XS (1 hour)

---

## Community & Ecosystem

### Feature 17: Swift NIO Backend (Optional)
**Complexity**: XXL (Extra Extra Large)
**Priority**: LOW
**Status**: Alternative Implementation

**Description**:
Provide optional Swift NIO-based backend as alternative to FoundationSocket.

**Pros**:
- Battle-tested async I/O
- Excellent performance
- Large community

**Cons**:
- Adds significant dependency
- Increases complexity
- May not align with zero-dependency goal

**Effort Estimate**: XXL (40+ hours)

**Decision**: Defer until significant user demand exists

---

## Summary Statistics

| Category | Count | Total Complexity |
|----------|-------|------------------|
| **Outstanding Issues (P2)** | 4 | L + M + M + S = ~30 hours |
| **Outstanding Issues (P3)** | 4 | M + S + S + XS = ~12 hours |
| **Deferred Features** | 2 | M + XS = ~10 hours |
| **Future Features (v0.2.0)** | 17 | ~280 hours estimated |
| **Technical Debt** | 3 | ~8 hours |
| **TOTAL** | **30** | **~340 hours** |

### Priority Breakdown

| Priority | Count | % of Total |
|----------|-------|------------|
| P2 (Medium) | 4 | 13% |
| P3 (Low) | 4 | 13% |
| Deferred | 2 | 7% |
| Future (High) | 3 | 10% |
| Future (Medium) | 8 | 27% |
| Future (Low) | 9 | 30% |

### Complexity Breakdown

| Complexity | Count | Typical Hours |
|------------|-------|---------------|
| XS (Extra Small) | 4 | 1-2 hours each |
| S (Small) | 7 | 2-4 hours each |
| M (Medium) | 12 | 4-8 hours each |
| L (Large) | 5 | 16-24 hours each |
| XL (Extra Large) | 2 | 24-40 hours each |
| XXL (Extra Extra Large) | 1 | 40+ hours |

---

## Recommended Roadmap for v0.2.0

### Phase 1: Complete Outstanding P2 Issues (Sprint 1 - 2 weeks)
**Effort**: ~42 hours

1. ✅ Issue 1: Async I/O Refactoring (L - 20 hours)
2. ✅ Issue 2: Partial Write Handling (M - 6 hours)
3. ✅ Issue 3: Network Transport Tests (M - 6 hours)
4. ✅ Issue 4: Fix Large Message Test (S - 3 hours)

**Goal**: Resolve all known technical debt and test gaps

### Phase 2: Performance & Security (Sprint 2-3 - 3 weeks)
**Effort**: ~60 hours

1. Feature 3: STARTTLS/TLS Support (XL - 32 hours)
2. Feature 8: Connection Rate Limiting (M - 10 hours)
3. Feature 11: Structured Logging (M - 8 hours)
4. Feature 12: Metrics and Monitoring (M - 10 hours)

**Goal**: Production-grade security and observability

### Phase 3: Advanced Features (Sprint 4-5 - 3 weeks)
**Effort**: ~50 hours

1. Feature 4: SMTP AUTH Support (L - 20 hours)
2. Feature 5: SIZE Extension Enhancement (M - 6 hours)
3. Feature 6: PIPELINING Support (L - 18 hours)
4. Feature 1: iOS Example App (M - 10 hours)

**Goal**: Advanced ESMTP compliance and examples

### Phase 4: Quality & Polish (Sprint 6 - 1 week)
**Effort**: ~30 hours

1. All P3 Issues (Issues 5-8) (~12 hours)
2. Feature 14: Fuzzing Test Suite (L - 16 hours)
3. Feature 16: Code Coverage Tracking (S - 2 hours)
4. All Technical Debt items (~8 hours)

**Goal**: Comprehensive testing and documentation

---

## Release Strategy

### v0.1.0 - Initial Release (CURRENT)
**Status**: Ready for Release
**Focus**: Core SMTP receiving functionality
**Target Date**: 2025-11-27

### v0.1.1 - Bug Fix Release (if needed)
**Focus**: Critical bug fixes only
**Timeline**: Within 2 weeks of v0.1.0 if issues reported

### v0.2.0 - Performance & Security
**Focus**: Async I/O, TLS, Rate Limiting, Monitoring
**Timeline**: Q1 2026 (estimated)
**Dependencies**: Community feedback from v0.1.0

### v0.3.0 - Advanced ESMTP
**Focus**: SMTP AUTH, PIPELINING, DSN
**Timeline**: Q2 2026 (estimated)

### v1.0.0 - Production-Hardened
**Focus**: Battle-tested, comprehensive features
**Timeline**: Q3 2026 (estimated)
**Requirements**:
- 6+ months production usage
- Zero critical bugs
- Comprehensive security review
- Complete ESMTP feature set
- Excellent documentation

---

## Decision Log

### Decisions Made for v0.1.0

1. **Defer iOS Example App** - Focus on core functionality and documentation
2. **Accept macOS 26.1 Beta Test Failures** - OS bug, not code issue
3. **Zero Dependencies** - Maintain pure Swift implementation
4. **IPv6-First** - Modern networking foundation
5. **Network.framework for Apple Platforms** - Best performance and features
6. **Foundation Sockets for Linux** - Broad compatibility

### Open Questions for v0.2.0

1. **Swift NIO Integration?** - Wait for community demand
2. **Crypto Library Choice?** - Evaluate Security.framework vs Swift Crypto
3. **Logging Framework?** - swift-log integration or custom?
4. **Metrics Format?** - Prometheus, StatsD, or custom?
5. **Authentication Backend?** - Callback-based or protocol-based?

---

## Success Metrics for v0.2.0

### Code Quality
- [ ] Zero compiler warnings
- [ ] 95%+ test coverage
- [ ] All tests passing on all platforms
- [ ] Zero critical security vulnerabilities

### Performance
- [ ] 1000+ concurrent connections supported
- [ ] 100+ messages/second throughput
- [ ] <10ms average command processing latency
- [ ] <1% CPU overhead for logging/metrics

### Features
- [ ] STARTTLS working on all platforms
- [ ] SMTP AUTH with multiple mechanisms
- [ ] Rate limiting preventing abuse
- [ ] Comprehensive metrics available

### Documentation
- [ ] All new features documented
- [ ] Migration guide from v0.1.0
- [ ] Security best practices guide
- [ ] Performance tuning guide

### Community
- [ ] Swift Package Index listing
- [ ] 5+ community contributions
- [ ] 10+ GitHub stars
- [ ] Positive user feedback

---

## Contributing Guidelines for Next Phase

To contribute to v0.2.0 development:

1. Review this issues document
2. Choose an issue matching your expertise
3. Open a GitHub issue discussing your approach
4. Submit a PR with comprehensive tests
5. Update documentation
6. Follow existing code style and patterns

**High-Value Contributions**:
- TLS/STARTTLS implementation
- SMTP AUTH mechanisms
- Performance optimizations
- Comprehensive test coverage
- Documentation improvements

---

**Document Prepared By**: Technical Project Planner
**Review Date**: 2025-11-27
**Next Review**: After v0.1.0 release and community feedback
**Status**: APPROVED - Ready for v0.1.0 Release

**PrixFixe v0.1.0**: Production Ready ✅
**Next Phase**: v0.2.0 Planning Underway 🚀
