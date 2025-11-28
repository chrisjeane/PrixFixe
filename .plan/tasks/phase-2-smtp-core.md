# Phase 2: SMTP Core - Detailed Task Breakdown

**Phase Complexity**: XL (Extra Large)
**Date**: 2025-11-27
**Status**: Planning

## Overview

Phase 2 implements the core SMTP protocol according to RFC 5321. This is the most complex phase, involving command parsing, state machine implementation, session management, and message handling.

## Task Breakdown

### 2.1 SMTP Response System

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.1.1 | Define SMTPResponse struct | S | None | Code, message, multiline support |
| 2.1.2 | Implement response formatter | S | 2.1.1 | Generate RFC-compliant response strings |
| 2.1.3 | Create response code constants | S | 2.1.1 | 220, 250, 354, 421, 500, 501, 502, 503, 504, 550, 551, 552, 553, 554 |
| 2.1.4 | Implement multiline response handling | M | 2.1.1 | Format with continuation lines (250-...) |
| 2.1.5 | Unit tests for response formatting | S | 2.1.1-2.1.4 | Test all response types |

**Subtotal**: S (responses are straightforward)

---

### 2.2 SMTP Command Parsing

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.2.1 | Define SMTPCommand enum | M | None | All command types with associated values |
| 2.2.2 | Implement HELO/EHLO parser | S | 2.2.1 | Extract domain parameter |
| 2.2.3 | Implement MAIL FROM parser | M | 2.2.1 | Parse address, extract parameters (SIZE, etc.) |
| 2.2.4 | Implement RCPT TO parser | M | 2.2.1 | Parse recipient address, parameters |
| 2.2.5 | Implement DATA, QUIT, RSET, NOOP parsers | S | 2.2.1 | Simple commands with no parameters |
| 2.2.6 | Implement VRFY parser (optional command) | S | 2.2.1 | Basic implementation |
| 2.2.7 | Add parameter parsing for ESMTP extensions | M | 2.2.3, 2.2.4 | KEY=value parameter extraction |
| 2.2.8 | Handle case-insensitivity for commands | S | 2.2.1 | Commands are case-insensitive per RFC |
| 2.2.9 | Implement line length validation (512 chars) | S | 2.2.1 | RFC 5321 limit |
| 2.2.10 | Handle unknown commands gracefully | S | 2.2.1 | Return 500/502 for unknown commands |
| 2.2.11 | Unit tests for all command parsers | L | 2.2.1-2.2.10 | Extensive edge case testing |

**Subtotal**: L (command parsing has many edge cases)

---

### 2.3 Email Address Parsing

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.3.1 | Define EmailAddress struct | S | None | localPart, domain |
| 2.3.2 | Implement basic address parser | M | 2.3.1 | Handle <user@domain> format |
| 2.3.3 | Handle angle bracket syntax | S | 2.3.2 | <> wrapping |
| 2.3.4 | Handle reverse-path/forward-path | M | 2.3.2 | MAIL FROM:<> for null sender |
| 2.3.5 | Implement basic validation | M | 2.3.1 | Local part and domain rules |
| 2.3.6 | Handle quoted local parts | M | 2.3.2 | "user name"@domain.com |
| 2.3.7 | Unit tests for address parsing | M | 2.3.1-2.3.6 | Many edge cases per RFC |

**Subtotal**: M (email parsing is well-defined but has edge cases)

---

### 2.4 SMTP State Machine

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.4.1 | Define SMTPState enum | M | None | All protocol states |
| 2.4.2 | Implement state transition logic | L | 2.4.1 | Valid transitions between states |
| 2.4.3 | Add validation for commands per state | L | 2.4.1, 2.2.1 | Which commands are valid in each state |
| 2.4.4 | Implement RSET command (state reset) | S | 2.4.1 | Reset to after-greeting state |
| 2.4.5 | Handle error states and recovery | M | 2.4.1 | Transition to error state, recovery paths |
| 2.4.6 | Implement state-specific response generation | M | 2.4.1, 2.1.1 | 503 Bad sequence of commands |
| 2.4.7 | Unit tests for state machine | L | 2.4.1-2.4.6 | All valid/invalid transitions |

**Subtotal**: L (state machine is complex with many transitions)

---

### 2.5 Message Envelope Handling

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.5.1 | Define Envelope struct | S | 2.3.1 | From, To[], timestamp |
| 2.5.2 | Implement envelope builder during session | S | 2.5.1 | Accumulate MAIL FROM and RCPT TO |
| 2.5.3 | Validate recipient count limits | S | 2.5.2 | Max recipients per message |
| 2.5.4 | Handle multiple RCPT TO commands | S | 2.5.2 | Accumulate recipients |
| 2.5.5 | Unit tests for envelope handling | S | 2.5.1-2.5.4 | Test limits, validation |

**Subtotal**: S (envelope is straightforward)

---

### 2.6 DATA Command and Message Reception

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.6.1 | Define EmailMessage struct | S | 2.5.1 | Envelope + headers + body |
| 2.6.2 | Implement DATA command initiation | S | 2.4.1 | Send 354 Start mail input |
| 2.6.3 | Implement message data streaming | L | 2.6.2 | Read lines until CRLF.CRLF |
| 2.6.4 | Handle dot-stuffing (transparency) | M | 2.6.3 | Lines starting with . are escaped |
| 2.6.5 | Implement message size limits | M | 2.6.3 | Enforce max message size |
| 2.6.6 | Parse message headers | M | 2.6.3 | Extract headers from message body |
| 2.6.7 | Handle header/body separation | S | 2.6.6 | Blank line separates headers/body |
| 2.6.8 | Implement timeout for DATA reception | M | 2.6.3 | Timeout if client stalls |
| 2.6.9 | Unit tests for DATA handling | L | 2.6.1-2.6.8 | Many edge cases (large messages, timeouts) |

**Subtotal**: L (DATA command is complex, especially streaming)

---

### 2.7 Message Handler Integration

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.7.1 | Define MessageHandler protocol | S | 2.6.1 | Callback for received messages |
| 2.7.2 | Implement in-memory message store (for testing) | S | 2.7.1 | Simple array-based storage |
| 2.7.3 | Integrate message handler into session | M | 2.7.1, 2.8.1 | Call handler after DATA completes |
| 2.7.4 | Handle message handler errors | M | 2.7.3 | Propagate errors to client appropriately |
| 2.7.5 | Unit tests for message handler flow | M | 2.7.1-2.7.4 | Test success and error cases |

**Subtotal**: M (integration requires coordination)

---

### 2.8 SMTP Session Management

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.8.1 | Define SMTPSession actor | M | 2.4.1, 2.2.1 | Per-connection state |
| 2.8.2 | Implement session lifecycle (greeting → quit) | M | 2.8.1, 2.4.1 | Full session flow |
| 2.8.3 | Implement command reading loop | M | 2.8.1, 2.2.1 | Read lines, parse commands |
| 2.8.4 | Integrate state machine into session | M | 2.8.1, 2.4.1 | Session uses state machine |
| 2.8.5 | Implement command dispatch and response | M | 2.8.3, 2.1.1 | Call handlers, send responses |
| 2.8.6 | Handle connection timeouts | M | 2.8.1 | Idle timeout, overall session timeout |
| 2.8.7 | Implement graceful session shutdown | S | 2.8.1 | QUIT command and cleanup |
| 2.8.8 | Handle client disconnection mid-session | M | 2.8.1 | Cleanup on unexpected close |
| 2.8.9 | Unit tests for session lifecycle | L | 2.8.1-2.8.8 | Full session scenarios |

**Subtotal**: L (session coordination is complex)

---

### 2.9 SMTP Server Orchestration

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.9.1 | Define SMTPServer actor | M | Phase 1 network layer | Main server coordinator |
| 2.9.2 | Implement server start/stop | M | 2.9.1, 1.5.1 | Bind socket, start accepting |
| 2.9.3 | Implement connection acceptance loop | M | 2.9.2, 2.8.1 | Accept connections, spawn sessions |
| 2.9.4 | Implement connection pool/limit | M | 2.9.3 | Max concurrent connections |
| 2.9.5 | Implement session tracking | M | 2.9.3 | Track active sessions, cleanup |
| 2.9.6 | Integrate message handler configuration | S | 2.9.1, 2.7.1 | Server owns message handler |
| 2.9.7 | Implement graceful server shutdown | M | 2.9.1 | Stop accepting, drain sessions |
| 2.9.8 | Handle port already in use errors | S | 2.9.2 | Proper error propagation |
| 2.9.9 | Integration tests for server | L | 2.9.1-2.9.8 | End-to-end server tests |

**Subtotal**: L (server orchestration with concurrency is complex)

---

### 2.10 ESMTP Extensions Support

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.10.1 | Define SMTPExtension enum | S | None | 8BITMIME, SIZE, PIPELINING flags |
| 2.10.2 | Implement EHLO response with extensions | M | 2.10.1, 2.1.4 | Multiline response listing extensions |
| 2.10.3 | Implement SIZE extension | M | 2.10.1 | Advertise max message size |
| 2.10.4 | Implement 8BITMIME extension | S | 2.10.1 | Advertise support (no special handling needed) |
| 2.10.5 | Implement PIPELINING extension (basic) | M | 2.10.1 | Allow multiple commands before response |
| 2.10.6 | Unit tests for ESMTP features | M | 2.10.1-2.10.5 | Test EHLO, extensions |

**Subtotal**: M (extensions add moderate complexity)

---

### 2.11 Configuration System

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.11.1 | Define ServerConfiguration struct | S | None | Port, host, limits, greeting, extensions |
| 2.11.2 | Implement configuration validation | S | 2.11.1 | Validate port range, limits |
| 2.11.3 | Create configuration presets | S | 2.11.1 | default, ephemeralPort, iosOptimized |
| 2.11.4 | Integrate configuration into SMTPServer | S | 2.11.1, 2.9.1 | Server uses config |
| 2.11.5 | Unit tests for configuration | S | 2.11.1-2.11.4 | Test validation, presets |

**Subtotal**: S (configuration is straightforward)

---

### 2.12 Logging and Debugging

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.12.1 | Define logging strategy | S | None | Use os.Logger or print for now |
| 2.12.2 | Add logging points in session | S | 2.8.1 | Log commands, responses, state changes |
| 2.12.3 | Add logging points in server | S | 2.9.1 | Log connections, disconnections |
| 2.12.4 | Implement log levels | S | 2.12.1 | debug, info, error |
| 2.12.5 | Add configuration for logging | S | 2.11.1 | Enable/disable, set level |

**Subtotal**: S (basic logging, not a logging framework)

---

### 2.13 Comprehensive Testing

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.13.1 | Create SMTP test client utility | M | 2.9.1 | Helper for integration tests |
| 2.13.2 | Write integration tests for full SMTP sessions | L | All above | Happy path, error cases |
| 2.13.3 | Create RFC 5321 compliance test suite | L | All above | Test core command sequences |
| 2.13.4 | Write concurrency tests | M | 2.9.3 | Multiple simultaneous sessions |
| 2.13.5 | Write timeout and error recovery tests | M | 2.8.6, 2.8.8 | Test error conditions |
| 2.13.6 | Create test message corpus | S | None | Various test emails for DATA |
| 2.13.7 | Performance baseline tests | M | 2.9.1 | Measure throughput, latency |

**Subtotal**: L (comprehensive testing is substantial)

---

### 2.14 Documentation (Phase 2)

| Task ID | Task | Complexity | Dependencies | Notes |
|---------|------|-----------|--------------|-------|
| 2.14.1 | Document SMTPServer public API | M | 2.9.1 | Full API docs with examples |
| 2.14.2 | Document MessageHandler protocol | S | 2.7.1 | How to implement custom handlers |
| 2.14.3 | Document ServerConfiguration | S | 2.11.1 | All options explained |
| 2.14.4 | Create basic usage examples | M | All above | Quick start, embedded server example |
| 2.14.5 | Document SMTP protocol coverage | S | All above | Which RFCs, which commands |
| 2.14.6 | Create architecture decision records | S | 2.4.1, 2.9.1 | Document key design choices |

**Subtotal**: M (documentation is substantial for complex API)

---

## Phase 2 Summary

| Category | Complexity | Task Count | Notes |
|----------|-----------|------------|-------|
| Response System | S | 5 | Straightforward |
| Command Parsing | L | 11 | Many edge cases |
| Address Parsing | M | 7 | Email address complexity |
| State Machine | L | 7 | Complex logic |
| Envelope Handling | S | 5 | Simple data structure |
| DATA Command | L | 9 | Streaming complexity |
| Message Handler | M | 5 | Integration points |
| Session Management | L | 9 | Coordination complexity |
| Server Orchestration | L | 9 | Concurrency complexity |
| ESMTP Extensions | M | 6 | Moderate additions |
| Configuration | S | 5 | Standard config |
| Logging | S | 5 | Basic logging |
| Testing | L | 7 | Comprehensive coverage |
| Documentation | M | 6 | Substantial API |
| **TOTAL** | **XL** | **96** | Aggregates to Extra Large |

## Success Criteria Checklist

- [ ] Can handle complete SMTP session from connect to QUIT
- [ ] All core commands implemented (HELO, EHLO, MAIL FROM, RCPT TO, DATA, QUIT)
- [ ] RSET and NOOP commands work
- [ ] State machine correctly validates command sequences
- [ ] Can receive complete email messages via DATA
- [ ] Message handler callback invoked with complete message
- [ ] EHLO advertises supported extensions
- [ ] SIZE and 8BITMIME extensions work
- [ ] Handles at least 10 concurrent sessions
- [ ] Passes RFC 5321 core compliance tests
- [ ] All unit tests pass
- [ ] Integration tests cover happy path and errors
- [ ] Performance baseline established
- [ ] API fully documented

## Phase 2 Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| State machine bugs with edge cases | High | High | Extensive unit tests, state diagram validation |
| DATA command performance issues | Medium | Medium | Profile early, optimize streaming |
| Actor concurrency bottlenecks | Medium | High | Performance tests early, benchmark session creation |
| Command parsing ambiguity in RFC | Low | Medium | Refer to RFC examples, test against real clients |
| Message size handling memory issues | Medium | High | Implement streaming, enforce limits strictly |
| Timeout handling complexity | Medium | Medium | Use structured concurrency patterns |

## Critical Path

1. **Response system** (2.1) → Foundation for all responses
2. **Command parsing** (2.2) → Required for state machine
3. **State machine** (2.4) → Core protocol logic
4. **Session management** (2.8) → Orchestrates everything
5. **DATA command** (2.6) → Most complex command
6. **Server orchestration** (2.9) → Brings it all together
7. **Testing** (2.13) → Validates correctness

## Recommended Task Ordering

### Iteration 1: Basic Command/Response
- Response system (2.1)
- Basic command parsing (2.2.1-2.2.5)
- Configuration (2.11)

### Iteration 2: State Machine
- State machine definition (2.4.1-2.4.3)
- State validation (2.4.4-2.4.6)
- Tests (2.4.7)

### Iteration 3: Session
- Session actor (2.8.1-2.8.5)
- Session tests (2.8.9)

### Iteration 4: Envelope & Addresses
- Email address parsing (2.3)
- Envelope handling (2.5)
- Advanced command parsing (2.2.3-2.2.4, 2.2.7)

### Iteration 5: DATA Command
- Message structures (2.6.1-2.6.2)
- DATA streaming (2.6.3-2.6.7)
- Message handler (2.7)

### Iteration 6: Server Orchestration
- Server actor (2.9.1-2.9.6)
- Connection handling (2.9.3-2.9.5)
- Shutdown (2.9.7)

### Iteration 7: Extensions
- ESMTP extensions (2.10)

### Iteration 8: Testing & Polish
- Comprehensive testing (2.13)
- Logging (2.12)
- Documentation (2.14)

## Dependencies on Phase 1

- **SocketProtocol and Connection**: Required for all network I/O
- **Platform capabilities**: Used for configuration defaults
- **Test infrastructure**: Required for all Phase 2 tests
- **Error types**: Extended in Phase 2 for SMTP errors

## Outputs from Phase 2

1. **Functional SMTP server** that can receive emails
2. **Complete test suite** for protocol compliance
3. **Public API** (SMTPServer, MessageHandler, etc.)
4. **Configuration system** for customization
5. **Documentation** and usage examples
6. **Performance baseline** metrics

## Phase 2 Completion Definition

Phase 2 is complete when:
- [ ] All tasks marked as done
- [ ] All success criteria met
- [ ] Can send test email using `swaks` or `telnet`
- [ ] RFC 5321 compliance tests pass
- [ ] Performance targets met (10+ concurrent sessions)
- [ ] Code review completed
- [ ] Architecture sign-off (phase gate 2)
- [ ] Ready for platform-specific work (Phase 3)
