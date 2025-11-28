# Phase 1: Foundation - Detailed Task Breakdown

**Phase Complexity**: L (Large)
**Date**: 2025-11-27
**Status**: Planning

## Overview

Phase 1 establishes the foundational infrastructure for PrixFixe: project structure, networking abstractions, platform detection, and test framework integration.

## Task Breakdown

### 1.1 Project Structure Setup

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.1.1 | Create Swift Package with Package.swift | XS | None | Define all targets, platforms, dependencies |
| 1.1.2 | Create directory structure for all modules | XS | 1.1.1 | Sources/, Tests/, Examples/ |
| 1.1.3 | Add SwiftTest as test dependency | S | 1.1.1 | May require research if not straightforward |
| 1.1.4 | Create .gitignore, README.md, LICENSE | XS | None | Basic project files |
| 1.1.5 | Set up basic CI/CD workflow (GitHub Actions) | M | 1.1.1, 1.1.3 | macOS runner initially, add Linux later |

**Subtotal**: M (considering CI/CD complexity)

---

### 1.2 Platform Detection and Capabilities

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.2.1 | Define Platform enum (Linux, macOS, iOS) | XS | 1.1.2 | Simple enum with platform detection |
| 1.2.2 | Create PlatformCapabilities struct | S | 1.2.1 | Query system capabilities per platform |
| 1.2.3 | Implement platform detection logic | S | 1.2.1 | Compile-time and runtime detection |
| 1.2.4 | Define platform-specific resource limits | S | 1.2.2 | Max connections, message sizes per platform |
| 1.2.5 | Add unit tests for platform detection | S | 1.2.1-1.2.4 | Test on available platforms |

**Subtotal**: S (straightforward platform detection)

---

### 1.3 Network Abstraction Layer - Protocols

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.3.1 | Define SocketProtocol protocol | S | None | bind, listen, accept, close methods |
| 1.3.2 | Define Connection protocol | S | None | read, write, close, address methods |
| 1.3.3 | Create SocketAddress struct | M | None | IPv6-first design, parsing, validation |
| 1.3.4 | Define network error types | XS | None | NetworkError enum |
| 1.3.5 | Add async stream abstractions for read/write | M | 1.3.2 | AsyncSequence wrappers if needed |

**Subtotal**: M (IPv6 address handling adds complexity)

---

### 1.4 IPv6 Address Handling

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.4.1 | Implement IPv6 address parsing | M | 1.3.3 | Handle full IPv6 syntax, zone IDs |
| 1.4.2 | Implement IPv4-mapped IPv6 support | S | 1.4.1 | ::ffff:192.0.2.1 format |
| 1.4.3 | Add address validation logic | S | 1.4.1 | Validate well-formed addresses |
| 1.4.4 | Create localhost/any-address constants | XS | 1.3.3 | ::1, ::, etc. |
| 1.4.5 | Unit tests for address parsing | M | 1.4.1-1.4.4 | Comprehensive edge cases |

**Subtotal**: M (IPv6 parsing is well-defined but has edge cases)

---

### 1.5 Socket Implementation (Foundation-based)

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.5.1 | Create FoundationSocket implementing SocketProtocol | M | 1.3.1 | Use Foundation's socket APIs |
| 1.5.2 | Implement bind() for IPv6 | M | 1.5.1, 1.3.3 | Handle dual-stack binding |
| 1.5.3 | Implement listen() and accept() | M | 1.5.2 | Async accept loop |
| 1.5.4 | Create FoundationConnection implementing Connection | M | 1.3.2 | Async read/write over socket |
| 1.5.5 | Add proper error handling and propagation | S | 1.5.1-1.5.4 | Map system errors to NetworkError |
| 1.5.6 | Implement graceful shutdown/cleanup | S | 1.5.1-1.5.4 | Close sockets, cancel tasks |

**Subtotal**: M (socket implementation is standard but requires care)

---

### 1.6 Core Error Handling

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.6.1 | Define PrixFixeError enum | XS | None | Top-level library errors |
| 1.6.2 | Define SMTPError enum (basic) | S | None | Protocol-level errors (expand in Phase 2) |
| 1.6.3 | Define NetworkError enum | XS | None | Network-specific errors |
| 1.6.4 | Add error message helpers | XS | 1.6.1-1.6.3 | LocalizedError conformance |

**Subtotal**: XS (error types are straightforward)

---

### 1.7 Test Infrastructure

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.7.1 | Set up SwiftTest for PrixFixeNetworkTests | M | 1.1.3 | First module to test, validate SwiftTest works |
| 1.7.2 | Create mock socket implementation for testing | M | 1.3.1 | MockSocket for unit tests |
| 1.7.3 | Create test utilities for async testing | S | 1.7.1 | Helpers for async assertions |
| 1.7.4 | Set up test data fixtures | S | None | Sample addresses, test payloads |
| 1.7.5 | Validate tests run in CI pipeline | S | 1.1.5, 1.7.1 | Ensure CI can run SwiftTest |

**Subtotal**: M (SwiftTest integration unknown, but test infrastructure is critical)

---

### 1.8 Basic Integration Test

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.8.1 | Create simple echo server using abstractions | S | 1.5.1-1.5.6 | Validate network layer works end-to-end |
| 1.8.2 | Write integration test: connect and send data | M | 1.8.1, 1.7.1 | Use URLSession or raw socket to connect |
| 1.8.3 | Validate IPv6 binding and connection | S | 1.8.2 | Test ::1 localhost |
| 1.8.4 | Test error conditions (bind failures, etc.) | S | 1.8.2 | Negative tests |

**Subtotal**: M (integration tests require more setup)

---

### 1.9 Documentation (Phase 1)

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.9.1 | Add module-level documentation comments | S | All modules | High-level purpose of each module |
| 1.9.2 | Document SocketProtocol and Connection | S | 1.3.1, 1.3.2 | Critical public protocols |
| 1.9.3 | Create architecture decision record (ADR) for network abstraction | S | 1.3.1 | Document why this approach |
| 1.9.4 | Update .plan/INDEX.md with Phase 1 completion | XS | All tasks | Track progress |

**Subtotal**: S (basic documentation)

---

### 1.10 Linux Platform Support (Basic)

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 1.10.1 | Add Linux to CI/CD pipeline | M | 1.1.5 | Ubuntu GitHub runner |
| 1.10.2 | Validate FoundationSocket works on Linux | S | 1.5.1, 1.10.1 | Run tests on Linux |
| 1.10.3 | Fix any Linux-specific compilation issues | S | 1.10.2 | Conditional compilation if needed |
| 1.10.4 | Document Linux-specific setup/requirements | XS | 1.10.1-1.10.3 | For contributors |

**Subtotal**: M (CI/CD for Linux adds moderate complexity)

---

## Phase 1 Summary

| Category | Complexity | Task Count | Notes |
|----------|-----------|------------|-------|
| Project Structure | M | 5 | CI/CD is the complexity driver |
| Platform Detection | S | 5 | Straightforward |
| Network Protocols | M | 5 | IPv6 design considerations |
| IPv6 Handling | M | 5 | Parsing and validation |
| Socket Implementation | M | 6 | Standard but requires care |
| Error Handling | XS | 4 | Simple error types |
| Test Infrastructure | M | 5 | SwiftTest integration uncertainty |
| Integration Testing | M | 4 | End-to-end validation |
| Documentation | S | 4 | Basic docs |
| Linux Support | M | 4 | CI/CD setup |
| **TOTAL** | **L** | **47** | Aggregates to Large complexity |

## Success Criteria Checklist

- [ ] Swift Package builds on macOS and Linux
- [ ] All tests pass with SwiftTest
- [ ] Can bind to IPv6 address (::1 or ::)
- [ ] Can accept a connection and read/write data
- [ ] CI/CD pipeline runs on both macOS and Linux
- [ ] SocketProtocol and Connection abstractions are clean
- [ ] IPv6 address parsing handles common formats
- [ ] Mock implementations available for testing
- [ ] No compiler warnings
- [ ] Code compiles with Swift 6 strict concurrency

## Phase 1 Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| SwiftTest doesn't support async/await well | Medium | High | Early spike to validate; fallback to XCTest if needed |
| IPv6 configuration issues in CI | Medium | Medium | Document CI setup; use GitHub Actions with IPv6 support |
| Foundation socket APIs insufficient | Low | High | Research Network.framework as alternative early |
| Linux/macOS socket API differences | Medium | Medium | Abstract carefully; test on both platforms continuously |
| CI/CD setup takes longer than expected | Medium | Low | Start with macOS only, add Linux incrementally |

## Recommended Task Ordering

### Week 1 (if sequencing linearly):
1. Project structure setup (1.1)
2. Platform detection (1.2)
3. Network protocol definitions (1.3)
4. Error types (1.6)

### Week 2:
5. IPv6 address handling (1.4)
6. Socket implementation (1.5)
7. Test infrastructure (1.7)

### Week 3:
8. Integration testing (1.8)
9. Linux support (1.10)
10. Documentation (1.9)

**Note**: Actual calendar time depends on team size and availability. This is a logical sequencing, not a time estimate.

## Dependencies on External Factors

- **SwiftTest availability**: Must be resolvable via SPM
- **GitHub Actions runners**: Need macOS and Linux runners with IPv6
- **Swift 6.0+**: Toolchain must be available on all CI platforms
- **Network access in CI**: Tests require localhost binding/connection

## Outputs from Phase 1

1. **Compilable Swift Package** with all module stubs
2. **Working network layer** with at least one socket implementation
3. **Test infrastructure** with SwiftTest integrated
4. **CI/CD pipeline** running on macOS and Linux
5. **Architecture documentation** explaining design decisions
6. **Foundation for Phase 2** (SMTP protocol implementation)

## Phase 1 Completion Definition

Phase 1 is complete when:
- [ ] All tasks marked as done
- [ ] All success criteria met
- [ ] CI/CD is green on both platforms
- [ ] Code review completed (if team-based)
- [ ] Architecture sign-off (phase gate 1)
- [ ] Ready to begin SMTP protocol implementation
