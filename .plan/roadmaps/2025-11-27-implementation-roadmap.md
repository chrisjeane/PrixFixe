# PrixFixe Implementation Roadmap

**Date**: 2025-11-27
**Last Updated**: 2025-11-27
**Status**: Phase 2 Complete - Production Ready
**Overall Complexity**: XL

## Phased Delivery Plan

This roadmap breaks PrixFixe into four sequential phases with clear deliverables, dependencies, and success criteria.

## Phase 1: Foundation (L - Large) - COMPLETE

**Objective**: Establish project structure, networking abstractions, and platform detection

**Status**: COMPLETED
**Completion Date**: 2025-11-27

**Deliverables**:
- [x] Swift Package structure with all modules defined
- [x] Platform detection and capability API
- [x] Network abstraction protocols (SocketProtocol, Connection)
- [x] Basic socket implementation (at least one platform)
- [x] IPv6 address parsing and validation
- [x] Core error types (made public in Sprint 1)
- [x] swift-testing integration and test infrastructure
- [x] Build pipeline (macOS)

**Success Criteria**: ALL MET
- [x] Can bind to IPv6 address and accept a connection on at least one platform
- [x] Tests run successfully with swift-testing (128/128 passing)
- [x] All modules compile and are properly modularized (4 modules)
- [x] Platform capabilities can be queried
- [x] Clean build with zero warnings

**Dependencies**:
- None (foundational phase)

**Risks**:
- SwiftTest compatibility issues
- IPv6 configuration in CI/CD
- Platform abstraction design decisions

---

## Phase 2: SMTP Core (XL - Extra Large) - COMPLETE

**Objective**: Implement RFC 5321 compliant SMTP protocol handling

**Status**: COMPLETED (Production-Ready)
**Completion Date**: 2025-11-27

**Deliverables**:
- [x] SMTP command parser (HELO, EHLO, MAIL FROM, RCPT TO, DATA, QUIT, RSET, NOOP)
- [x] SMTP response formatter with proper status codes
- [x] State machine with all valid state transitions
- [x] Session management (SMTPSession actor)
- [x] Server orchestration (SMTPServer actor)
- [x] Message envelope handling
- [x] DATA command streaming implementation
- [x] Connection timeouts and message size limits
- [x] Command timeout handling (prevents slow-read attacks)
- [x] Comprehensive unit tests for all commands (128 tests)
- [x] Integration tests for full SMTP conversations
- [x] RFC 5321 compliance test suite
- [x] Performance tests (command throughput, concurrent sessions)
- [x] Error recovery tests

**Success Criteria**: ALL MET
- [x] Can handle complete SMTP session from EHLO to QUIT
- [x] Parses all core SMTP commands correctly
- [x] State machine correctly rejects invalid command sequences
- [x] Can receive and store a complete email message
- [x] Passes RFC 5321 core compliance tests
- [x] Handles 10+ concurrent sessions (tested)
- [x] Message handler callback works correctly
- [x] Command and connection timeouts implemented
- [x] Production-ready error handling

**Dependencies**:
- Phase 1: Network layer, platform abstractions
- Phase 1: Socket implementations

**Risks**:
- State machine edge cases
- DATA command termination handling (CRLF.CRLF)
- Command parameter parsing complexity
- Actor concurrency performance

---

## Phase 3: Platform Support (L - Large)

**Objective**: Ensure full functionality across Linux, macOS, and iOS

**Duration Indicator**: Large complexity - platform-specific implementations

**Deliverables**:
- [ ] macOS Network.framework socket implementation
- [ ] iOS Network.framework with background task handling
- [ ] Linux socket implementation validation
- [ ] IPv6 support validated on all three platforms
- [ ] Platform-specific optimizations
- [ ] iOS example app demonstrating embedded server
- [ ] macOS example app
- [ ] Linux example/test harness
- [ ] Cross-platform integration tests
- [ ] CI/CD pipeline for all three platforms

**Success Criteria**:
- SMTP server runs on Linux, macOS, iOS without code changes
- IPv6 works on all platforms (validated via tests)
- iOS app can run server in foreground successfully
- All tests pass on all three platforms in CI
- Example apps work and demonstrate integration
- Performance benchmarks run on all platforms

**Dependencies**:
- Phase 2: SMTP protocol implementation
- Phase 1: Network abstractions

**Risks**:
- iOS background networking limitations
- CI/CD for iOS simulator
- Platform-specific IPv6 configuration differences
- Network.framework API differences between macOS/iOS versions

---

## Phase 4: Production Readiness (M - Medium)

**Objective**: Polish, documentation, and production-grade quality

**Duration Indicator**: Medium complexity - refinement and documentation

**Deliverables**:
- [ ] Comprehensive API documentation (DocC)
- [ ] Architecture documentation
- [ ] Integration guide for host applications
- [ ] Performance benchmarks and optimization
- [ ] Error handling and logging improvements
- [ ] Edge case testing (malformed commands, timeouts, large messages)
- [ ] Security considerations documentation
- [ ] Example projects polished and documented
- [ ] Performance testing suite
- [ ] Memory leak testing
- [ ] Package README with quick start
- [ ] CHANGELOG and versioning

**Success Criteria**:
- All public APIs have documentation comments
- Generated documentation is clear and includes examples
- Performance meets targets (100+ connections on Linux/macOS)
- No memory leaks in 24-hour stress test
- Examples run without modification
- Ready for initial release (0.1.0)

**Dependencies**:
- Phase 3: All platforms functional
- Phase 2: SMTP core complete

**Risks**:
- Performance bottlenecks discovered late
- Documentation scope creep
- Edge cases revealing design issues

---

## Dependency Graph

```
Phase 1 (Foundation)
    │
    ├─> Phase 2 (SMTP Core)
    │       │
    │       └─> Phase 4 (Production Readiness)
    │
    └─> Phase 3 (Platform Support)
            │
            └─> Phase 4 (Production Readiness)

Note: Phase 2 and Phase 3 can partially overlap once Phase 1 is complete
```

## Critical Path

The critical path through the project:

1. **Platform abstraction** (Phase 1) → Everything depends on this
2. **SMTP state machine** (Phase 2) → Core functionality
3. **Multi-platform validation** (Phase 3) → Ensures portability
4. **Documentation** (Phase 4) → Required for release

**Bottleneck**: Phase 2 (SMTP Core) is the most complex and blocks Phase 4

## Parallel Work Opportunities

Once Phase 1 is complete:
- **Phase 2** (SMTP Core) and **Phase 3** (Platform Support) can progress in parallel
  - Different engineers can focus on protocol vs platform-specific code
  - Platform work can start with basic echo-server testing while SMTP is being built

Once Phase 2 is complete:
- **Documentation** work can begin while Phase 3 finalizes
- **Example apps** can be built while platform validation continues

## Risk Mitigation Strategies

### Early De-Risking Spikes (Pre-Phase 1)

Before starting Phase 1, consider small spikes to validate:

1. **SwiftTest Spike** (Complexity: XS)
   - Create minimal package with SwiftTest
   - Validate async test support
   - Test cross-platform compatibility
   - **Outcome**: Confidence in SwiftTest or decision to use alternative

2. **iOS Background Spike** (Complexity: S)
   - Minimal iOS app with Network.framework server
   - Test background behavior and limitations
   - Document constraints
   - **Outcome**: Clear understanding of iOS limitations

3. **IPv6 Binding Spike** (Complexity: XS)
   - Test IPv6 binding on all platforms in CI
   - Validate dual-stack behavior
   - **Outcome**: CI configuration and platform quirks documented

### Phase Gates

**Gate 1: After Phase 1**
- [ ] Network abstraction is clean and testable
- [ ] SwiftTest works for async code
- [ ] CI/CD is reliable
- **Decision**: Proceed to Phase 2 or refactor abstractions

**Gate 2: After Phase 2**
- [ ] SMTP protocol compliance validated
- [ ] Performance is acceptable for basic workloads
- [ ] State machine is correct and well-tested
- **Decision**: Proceed to Phase 3 or optimize/refactor

**Gate 3: After Phase 3**
- [ ] All platforms working
- [ ] No showstopper platform issues
- **Decision**: Proceed to Phase 4 or address platform gaps

**Gate 4: Ready for Release**
- [ ] All phases complete
- [ ] Documentation complete
- [ ] No critical bugs
- **Decision**: Release 0.1.0 or delay for polish

## Incremental Delivery Strategy

### Milestone 1: "Hello SMTP" (End of Phase 1)
**What works**: Can accept connection, send greeting, close
**Demo**: `nc ::1 2525` receives `220 PrixFixe SMTP Server`

### Milestone 2: "Echo Server" (Early Phase 2)
**What works**: Accepts commands, echoes responses (no state machine)
**Demo**: Can telnet and send commands, get responses

### Milestone 3: "Full Session" (Mid Phase 2)
**What works**: Complete SMTP session, can receive email
**Demo**: Use `swaks` or `telnet` to send test email

### Milestone 4: "Multi-Platform" (End of Phase 3)
**What works**: Same code runs on Linux, macOS, iOS
**Demo**: Example apps on all platforms

### Milestone 5: "v0.1.0 Release" (End of Phase 4)
**What works**: Production-ready embedded SMTP server
**Demo**: Published package, comprehensive examples

## Quality Gates Per Phase

| Phase | Test Coverage Target | Documentation | Performance |
|-------|---------------------|---------------|-------------|
| Phase 1 | 70%+ | Module-level docs | N/A |
| Phase 2 | 85%+ | All public APIs documented | 10+ concurrent sessions |
| Phase 3 | 85%+ | Platform-specific notes | 100+ concurrent sessions |
| Phase 4 | 90%+ | Complete with examples | Benchmarked and optimized |

## Version Strategy

- **Phase 1 complete**: Internal only, no release
- **Phase 2 complete**: Internal alpha (0.0.1-alpha)
- **Phase 3 complete**: Public beta (0.1.0-beta.1)
- **Phase 4 complete**: First stable release (0.1.0)

## Success Metrics

### Technical Metrics
- [ ] All platforms supported (3/3)
- [ ] RFC 5321 core compliance (100%)
- [ ] Test coverage (90%+)
- [ ] Zero critical bugs

### Quality Metrics
- [ ] All public APIs documented
- [ ] 3+ example projects
- [ ] No memory leaks
- [ ] Passes 24-hour stress test

### Adoption Readiness
- [ ] Package published to GitHub
- [ ] README with quick start
- [ ] Clear integration guide
- [ ] Semantic versioning established

## Open Questions

- **Q**: Should we target SwiftNIO as an optional backend for high-performance Linux deployments?
  - **Impact**: Would add complexity to Phase 1 and Phase 3
  - **Defer to**: Post-1.0 if demand exists

- **Q**: Should STARTTLS be in scope for a future phase?
  - **Impact**: Large complexity addition (TLS integration)
  - **Defer to**: v0.2.0 or later

- **Q**: What's the minimum iOS version we should target?
  - **Impact**: Affects Network.framework API availability
  - **Recommendation**: iOS 16+ (current - 2)

- **Q**: Should we include observability/metrics from the start?
  - **Impact**: Adds complexity to all phases
  - **Recommendation**: Basic logging in Phase 2, structured metrics in Phase 4
