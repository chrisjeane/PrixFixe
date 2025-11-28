# Phase 3: Platform Support - Detailed Task Breakdown

**Phase Complexity**: L (Large)
**Date**: 2025-11-27
**Status**: Planning

## Overview

Phase 3 ensures PrixFixe works correctly across all three target platforms (Linux, macOS, iOS), with platform-specific optimizations and full IPv6 validation. This phase builds on the SMTP core from Phase 2.

## Task Breakdown

### 3.1 macOS Network.framework Implementation

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.1.1 | Create NetworkFrameworkSocket implementation | M | Phase 1: SocketProtocol | Use Network.framework NWListener |
| 3.1.2 | Implement bind and listen with NWListener | M | 3.1.1 | Configure IPv6 parameters |
| 3.1.3 | Implement accept with NWConnection | M | 3.1.2 | Handle incoming connections |
| 3.1.4 | Create NetworkFrameworkConnection | M | 3.1.3 | Wrap NWConnection for Connection protocol |
| 3.1.5 | Implement async read/write over NWConnection | M | 3.1.4 | Use receive/send APIs with continuations |
| 3.1.6 | Handle Network.framework state changes | M | 3.1.1-3.1.5 | ready, failed, cancelled states |
| 3.1.7 | Implement graceful shutdown | S | 3.1.1-3.1.6 | Cancel listener and connections |
| 3.1.8 | Add error mapping from Network.framework | S | 3.1.1-3.1.7 | Map NWError to NetworkError |
| 3.1.9 | Unit tests for Network.framework socket | M | 3.1.1-3.1.8 | Test on macOS |

**Subtotal**: M (Network.framework is well-documented but requires learning)

---

### 3.2 macOS Platform Integration

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.2.1 | Configure macOS to prefer Network.framework | S | 3.1.1 | Platform capabilities logic |
| 3.2.2 | Run full test suite on macOS with Network.framework | M | 3.1.9, Phase 2 tests | Validate all tests pass |
| 3.2.3 | Performance testing on macOS | M | 3.2.2 | Benchmark against Foundation sockets |
| 3.2.4 | Fix any macOS-specific issues | M | 3.2.2 | May uncover platform quirks |
| 3.2.5 | Create macOS example app (command-line) | S | 3.2.2 | Demonstrate usage |

**Subtotal**: M (integration and testing add complexity)

---

### 3.3 iOS Network.framework Implementation

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.3.1 | Validate Network.framework works on iOS | S | 3.1.1 | Should be same as macOS mostly |
| 3.3.2 | Test on iOS simulator | S | 3.3.1 | Run server in simulator |
| 3.3.3 | Identify iOS-specific limitations | M | 3.3.2 | Background modes, network restrictions |
| 3.3.4 | Implement iOS background task integration | M | Phase 1: BackgroundTaskManager | Handle background execution |
| 3.3.5 | Configure iOS-specific resource limits | S | 3.3.3 | Lower connection/message limits |
| 3.3.6 | Handle iOS app lifecycle events | M | 3.3.4 | Pause/resume server on background/foreground |
| 3.3.7 | Test on physical iOS device | M | 3.3.2 | Validate real device behavior |

**Subtotal**: M (iOS limitations add complexity)

---

### 3.4 iOS Example Application

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.4.1 | Create iOS app project | S | None | Xcode project with PrixFixe dependency |
| 3.4.2 | Implement basic UI for server control | M | 3.4.1 | Start/stop button, status display |
| 3.4.3 | Display received messages in UI | M | 3.4.2 | List view of emails |
| 3.4.4 | Add server configuration UI | S | 3.4.2 | Port, limits |
| 3.4.5 | Implement message handler to update UI | M | 3.4.3 | Publish messages to UI |
| 3.4.6 | Add background/foreground handling | S | 3.4.2, 3.3.6 | Pause server on background |
| 3.4.7 | Test on simulator and device | M | 3.4.1-3.4.6 | Validate full app flow |
| 3.4.8 | Document iOS-specific constraints | S | 3.4.7 | What works/doesn't in iOS |

**Subtotal**: M (iOS app development adds UI complexity)

---

### 3.5 Linux Platform Validation

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.5.1 | Validate Foundation sockets on Linux | S | Phase 1: FoundationSocket | Should already work |
| 3.5.2 | Run full test suite on Linux | M | Phase 2 tests | May uncover Linux-specific issues |
| 3.5.3 | Fix any Linux-specific compilation issues | M | 3.5.2 | Conditional compilation if needed |
| 3.5.4 | Optimize for Linux if needed | M | 3.5.2 | Profile and optimize hotspots |
| 3.5.5 | Create Linux example (command-line server) | S | 3.5.2 | Demonstrate usage |
| 3.5.6 | Test on Ubuntu 22.04+ | S | 3.5.2 | Primary Linux target |
| 3.5.7 | Document Linux-specific setup | S | 3.5.6 | Dependencies, build instructions |

**Subtotal**: M (validation and potential fixes)

---

### 3.6 IPv6 Cross-Platform Validation

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.6.1 | Test IPv6 localhost (::1) on all platforms | S | 3.2.2, 3.3.7, 3.5.2 | Validate loopback works |
| 3.6.2 | Test IPv6 any address (::) on all platforms | M | 3.6.1 | Validate binding to any interface |
| 3.6.3 | Test IPv4-mapped IPv6 on all platforms | M | 3.6.2 | ::ffff:192.0.2.1 compatibility |
| 3.6.4 | Test dual-stack behavior | M | 3.6.2 | IPv6 socket accepting IPv4 connections |
| 3.6.5 | Validate IPv6 address parsing on all platforms | S | Phase 1: 1.4.1 | Ensure consistent parsing |
| 3.6.6 | Create IPv6 integration test suite | M | 3.6.1-3.6.5 | Cross-platform IPv6 tests |
| 3.6.7 | Document IPv6 behavior per platform | S | 3.6.1-3.6.6 | Note any differences |

**Subtotal**: M (IPv6 testing across platforms)

---

### 3.7 Platform-Specific Optimizations

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.7.1 | Profile performance on each platform | M | 3.2.3, 3.5.4 | Identify platform-specific bottlenecks |
| 3.7.2 | Optimize macOS Network.framework usage | M | 3.7.1 | Tune parameters if needed |
| 3.7.3 | Optimize Linux socket handling | M | 3.7.1 | Consider SO_REUSEPORT, etc. |
| 3.7.4 | Tune iOS for resource constraints | S | 3.7.1 | Lower defaults for iOS |
| 3.7.5 | Benchmark optimizations | M | 3.7.2-3.7.4 | Validate improvements |

**Subtotal**: M (optimization requires profiling and tuning)

---

### 3.8 Cross-Platform CI/CD

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.8.1 | Ensure macOS CI runs with Network.framework | M | 3.1.9 | Update CI config |
| 3.8.2 | Ensure Linux CI runs successfully | S | Phase 1: 1.10.1 | Should already work |
| 3.8.3 | Add iOS simulator testing to CI | M | 3.3.2 | xcodebuild test on simulator |
| 3.8.4 | Configure IPv6 in CI environments | M | 3.8.1-3.8.3 | Ensure IPv6 available |
| 3.8.5 | Set up matrix testing (all platforms) | M | 3.8.1-3.8.4 | Run tests on all platforms in parallel |
| 3.8.6 | Add performance regression testing to CI | M | 3.7.5 | Benchmark on each commit |
| 3.8.7 | Configure code coverage reporting | S | 3.8.5 | Codecov or similar |

**Subtotal**: M (CI configuration is moderately complex)

---

### 3.9 Platform Compatibility Testing

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.9.1 | Test on minimum supported macOS version | S | 3.2.2 | Validate compatibility |
| 3.9.2 | Test on minimum supported iOS version | S | 3.3.7 | Validate compatibility |
| 3.9.3 | Test on minimum supported Linux version | S | 3.5.6 | Ubuntu 22.04 |
| 3.9.4 | Test with different Swift versions if applicable | M | All above | Validate Swift 6.0+ |
| 3.9.5 | Create compatibility matrix documentation | S | 3.9.1-3.9.4 | Document supported versions |

**Subtotal**: S (compatibility validation)

---

### 3.10 Platform-Specific Edge Cases

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.10.1 | Test network changes on iOS (Wi-Fi to cellular) | M | 3.3.7 | Handle path changes |
| 3.10.2 | Test macOS firewall interactions | S | 3.2.2 | Document firewall requirements |
| 3.10.3 | Test Linux socket exhaustion scenarios | M | 3.5.2 | ulimit, max connections |
| 3.10.4 | Test iOS memory warnings | M | 3.3.7 | Handle low memory gracefully |
| 3.10.5 | Test process suspension on iOS | M | 3.3.6 | Validate pause/resume |

**Subtotal**: M (edge cases require thorough testing)

---

### 3.11 Example Projects

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.11.1 | Polish macOS command-line example | S | 3.2.5 | Add README, comments |
| 3.11.2 | Polish iOS example app | M | 3.4.8 | Add README, screenshots |
| 3.11.3 | Polish Linux command-line example | S | 3.5.5 | Add README, systemd example if applicable |
| 3.11.4 | Create "embedded server" integration example | M | Phase 2 | Show host app integration |
| 3.11.5 | Add example for custom message handler | S | Phase 2: 2.7.1 | Demonstrate extensibility |

**Subtotal**: M (multiple polished examples)

---

### 3.12 Documentation (Phase 3)

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 3.12.1 | Document platform-specific considerations | M | All above | What differs per platform |
| 3.12.2 | Document iOS limitations and workarounds | M | 3.3.3, 3.4.8 | Background modes, resource limits |
| 3.12.3 | Update architecture docs with platform details | S | All above | Network.framework vs Foundation |
| 3.12.4 | Create platform compatibility guide | S | 3.9.5 | Version requirements |
| 3.12.5 | Document example projects | S | 3.11.1-3.11.5 | How to run each example |

**Subtotal**: M (substantial platform documentation)

---

## Phase 3 Summary

| Category | Complexity | Task Count | Notes |
|----------|-----------|------------|-------|
| macOS Network.framework | M | 9 | New implementation |
| macOS Integration | M | 5 | Testing and examples |
| iOS Implementation | M | 7 | iOS-specific constraints |
| iOS Example App | M | 8 | UI development |
| Linux Validation | M | 7 | Testing and optimization |
| IPv6 Cross-Platform | M | 7 | Validation across platforms |
| Optimizations | M | 5 | Performance tuning |
| CI/CD | M | 7 | Multi-platform CI |
| Compatibility Testing | S | 5 | Version validation |
| Edge Cases | M | 5 | Platform-specific scenarios |
| Example Projects | M | 5 | Polished examples |
| Documentation | M | 5 | Platform guides |
| **TOTAL** | **L** | **75** | Aggregates to Large |

## Success Criteria Checklist

- [ ] SMTP server runs on Linux without modification
- [ ] SMTP server runs on macOS without modification
- [ ] SMTP server runs on iOS without modification
- [ ] Network.framework implementation works on macOS and iOS
- [ ] Foundation socket implementation works on Linux (and as fallback)
- [ ] IPv6 works on all three platforms
- [ ] IPv4-mapped IPv6 works where supported
- [ ] All tests pass on all platforms in CI
- [ ] iOS example app demonstrates embedded server
- [ ] macOS example works
- [ ] Linux example works
- [ ] Performance targets met on each platform
- [ ] Platform-specific constraints documented
- [ ] No platform-specific compilation errors

## Phase 3 Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| iOS background networking more limited than expected | High | High | Early testing, document constraints, warn users |
| Network.framework API differences between macOS/iOS | Medium | Medium | Thorough testing, conditional code if needed |
| IPv6 CI configuration issues | Medium | Medium | Test locally first, use reliable CI provider |
| Linux socket performance issues | Low | Medium | Profile early, optimize if needed |
| iOS app review restrictions on SMTP server | Medium | High | Document use cases, position as testing tool |
| Platform-specific Swift Concurrency bugs | Low | High | Stay on latest Swift, report bugs upstream |

## Critical Path

1. **macOS Network.framework** (3.1) → Platform-specific implementation
2. **iOS adaptation** (3.3) → Most constrained platform
3. **IPv6 validation** (3.6) → Critical requirement
4. **CI/CD** (3.8) → Enables continuous validation
5. **Example apps** (3.4, 3.11) → Demonstrates functionality

## Recommended Task Ordering

### Iteration 1: macOS
- Network.framework implementation (3.1)
- macOS integration (3.2)

### Iteration 2: iOS
- iOS implementation (3.3)
- iOS example app (3.4)

### Iteration 3: Linux
- Linux validation (3.5)
- Linux example (3.11.3)

### Iteration 4: IPv6
- IPv6 cross-platform testing (3.6)

### Iteration 5: CI/CD
- Multi-platform CI (3.8)

### Iteration 6: Polish
- Optimizations (3.7)
- Edge cases (3.10)
- Compatibility testing (3.9)
- Documentation (3.12)
- Example polish (3.11)

## Dependencies on Phase 2

- **SMTPServer**: Must be functional to test on platforms
- **Test suite**: Required to validate platform compatibility
- **Configuration system**: Used for platform-specific configs
- **Message handler**: Required for example apps

## Parallel Work Opportunities

- **macOS** (3.1-3.2) and **Linux** (3.5) can be developed in parallel
- **iOS app** (3.4) can start once iOS implementation (3.3) is working
- **IPv6 testing** (3.6) can run in parallel with platform work
- **Documentation** (3.12) can be written as each platform completes

## Outputs from Phase 3

1. **Network.framework implementation** for macOS and iOS
2. **Validated Linux support** with Foundation sockets
3. **iOS example app** demonstrating embedded server
4. **macOS and Linux examples** for command-line usage
5. **Cross-platform CI/CD** running on all platforms
6. **IPv6 validation** on all platforms
7. **Platform documentation** explaining differences and constraints
8. **Performance benchmarks** for each platform

## Phase 3 Completion Definition

Phase 3 is complete when:
- [ ] All tasks marked as done
- [ ] All success criteria met
- [ ] All tests pass on Linux, macOS, iOS
- [ ] CI/CD runs on all three platforms
- [ ] Example apps work on all platforms
- [ ] IPv6 validated on all platforms
- [ ] Performance acceptable on all platforms
- [ ] Code review completed
- [ ] Architecture sign-off (phase gate 3)
- [ ] Ready for production polish (Phase 4)

## iOS-Specific Considerations

### Background Execution
- iOS severely limits background network services
- Server will likely only work in foreground
- Document this limitation clearly
- Consider background task API for finishing current sessions

### App Store Guidelines
- SMTP server may not be suitable for App Store apps
- Position as development/testing tool
- Document enterprise/ad-hoc distribution if needed

### Resource Constraints
- Limit max connections on iOS (5-10 vs 100 on macOS/Linux)
- Limit message sizes (1MB vs 10MB)
- Monitor memory usage closely
- Handle memory warnings

### Network.framework on iOS
- Same API as macOS mostly
- May have additional restrictions
- Test thoroughly on real devices
- Validate with different network types (Wi-Fi, cellular, VPN)
