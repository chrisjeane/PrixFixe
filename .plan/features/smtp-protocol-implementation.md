# SMTP Protocol Implementation

**Date**: 2025-11-27
**Status**: Planning
**Complexity**: XL

## Overview

PrixFixe implements a core subset of RFC 5321 (Simple Mail Transfer Protocol) focused on receiving email messages. This document defines the scope of protocol support.

## RFC Compliance

### Primary Standards
- **RFC 5321**: Simple Mail Transfer Protocol (SMTP)
  - Core command set
  - State machine implementation
  - Message format requirements

### Extended Support (ESMTP)
- **RFC 2821**: ESMTP base (deprecated, superseded by RFC 5321)
  - EHLO command
  - Extension advertisement

### Specific Extensions
- **RFC 1870**: SMTP SIZE extension
- **RFC 6152**: SMTP 8BITMIME extension

## Supported Commands

### Core Commands (Required)

| Command | Syntax | Purpose | Complexity |
|---------|--------|---------|------------|
| HELO | `HELO domain` | Simple greeting | S |
| EHLO | `EHLO domain` | Extended greeting | S |
| MAIL FROM | `MAIL FROM:<address>` | Specify sender | M |
| RCPT TO | `RCPT TO:<address>` | Specify recipient | M |
| DATA | `DATA` | Begin message transmission | L |
| QUIT | `QUIT` | End session | XS |

### Additional Commands

| Command | Syntax | Purpose | Complexity |
|---------|--------|---------|------------|
| RSET | `RSET` | Reset session state | S |
| NOOP | `NOOP` | No operation | XS |
| VRFY | `VRFY <address>` | Verify address (optional) | S |

## SMTP State Machine

### States

```
┌─────────────┐
│   Initial   │
└──────┬──────┘
       │ (connection accepted)
       ▼
┌─────────────┐
│   Greeting  │◄─────┐
└──────┬──────┘      │
       │ (HELO/EHLO) │ (RSET)
       ▼             │
┌─────────────┐      │
│   Ready     │──────┘
└──────┬──────┘
       │ (MAIL FROM)
       ▼
┌─────────────┐
│  Mail From  │
└──────┬──────┘
       │ (RCPT TO)
       ▼
┌─────────────┐
│  Rcpt To    │◄────┐
└──────┬──────┘     │ (additional RCPT TO)
       │            │
       │────────────┘
       │ (DATA)
       ▼
┌─────────────┐
│   Data      │
└──────┬──────┘
       │ (message received)
       ▼
┌─────────────┐
│  Complete   │
└──────┬──────┘
       │ (QUIT or RSET)
       ▼
```

### State Transitions

| From State | Command | To State | Response |
|------------|---------|----------|----------|
| Initial | (connect) | Greeting | 220 |
| Greeting | HELO | Ready | 250 |
| Greeting | EHLO | Ready | 250 (multiline) |
| Ready | MAIL FROM | Mail From | 250 |
| Mail From | RCPT TO | Rcpt To | 250 |
| Rcpt To | RCPT TO | Rcpt To | 250 |
| Rcpt To | DATA | Data | 354 |
| Data | (CRLF.CRLF) | Complete | 250 |
| Complete | MAIL FROM | Mail From | 250 |
| Complete | QUIT | (close) | 221 |
| Any | RSET | Ready | 250 |
| Any | NOOP | (same) | 250 |
| Any | QUIT | (close) | 221 |

## ESMTP Extensions

### SIZE
- **Purpose**: Advertise maximum message size
- **Advertisement**: `250-SIZE 10485760` (in EHLO response)
- **Usage**: Client can send `MAIL FROM:<addr> SIZE=12345`
- **Implementation**: Reject messages exceeding limit

### 8BITMIME
- **Purpose**: Indicate support for 8-bit MIME data
- **Advertisement**: `250-8BITMIME` (in EHLO response)
- **Usage**: No special client handling required
- **Implementation**: Accept 8-bit data in message body

### PIPELINING (Optional/Future)
- **Purpose**: Allow multiple commands without waiting for responses
- **Advertisement**: `250-PIPELINING`
- **Implementation**: Deferred to post-0.1.0

## Response Codes

### Success Codes
- **220**: Service ready
- **221**: Service closing transmission channel
- **250**: Requested mail action okay, completed
- **354**: Start mail input; end with CRLF.CRLF

### Error Codes
- **421**: Service not available, closing transmission channel
- **450**: Requested mail action not taken: mailbox unavailable
- **451**: Requested action aborted: local error in processing
- **452**: Requested action not taken: insufficient system storage
- **500**: Syntax error, command unrecognized
- **501**: Syntax error in parameters or arguments
- **502**: Command not implemented
- **503**: Bad sequence of commands
- **504**: Command parameter not implemented
- **550**: Requested action not taken: mailbox unavailable
- **551**: User not local; please try forward-path
- **552**: Requested mail action aborted: exceeded storage allocation
- **553**: Requested action not taken: mailbox name not allowed
- **554**: Transaction failed

## Message Format

### Envelope vs. Content
- **Envelope**: From MAIL FROM and RCPT TO commands
- **Content**: Headers and body from DATA command
- **Separation**: Blank line (CRLF) separates headers from body

### DATA Command Flow
1. Client sends `DATA`
2. Server responds `354 Start mail input`
3. Client sends message (headers + body)
4. Client ends with `CRLF.CRLF` (dot on line by itself)
5. Server responds `250 OK` or error

### Dot-Stuffing (Transparency)
- Lines beginning with `.` are prefixed with another `.` by client
- Server removes leading `.` from such lines
- Single `.` on a line indicates end of message

## Address Formats

### Basic Format
- `<user@domain.com>`
- Angle brackets required in MAIL FROM/RCPT TO

### Special Cases
- Null sender: `MAIL FROM:<>` (for bounces)
- Quoted local parts: `<"user name"@domain.com>`
- Case preservation: Addresses are case-sensitive per RFC (but usually treated as case-insensitive)

## Limits and Constraints

| Limit | Value | Rationale |
|-------|-------|-----------|
| Command line length | 512 bytes | RFC 5321 requirement |
| Text line length | 1000 bytes | RFC 5321 recommendation |
| Recipients per message | 100 | Configurable, prevents abuse |
| Message size | 10 MB (default) | Configurable per platform |
| Session timeout | 5 minutes | Idle timeout |
| Data timeout | 10 minutes | For large message upload |

## Not Implemented (0.1.0)

### SMTP AUTH
- No authentication in initial release
- Server accepts all connections
- Host application responsible for access control

### STARTTLS
- No TLS/SSL support in 0.1.0
- Plaintext only
- May be added in 0.2.0

### Sending (Relay)
- PrixFixe is receive-only
- Not an MTA (Mail Transfer Agent)
- No outbound message relay

### Advanced Routing
- No forwarding
- No aliasing
- Simple message reception only

## Implementation Notes

### Concurrency
- Each SMTP session runs in its own actor
- State machine per session ensures correctness
- Server actor manages multiple sessions

### Error Handling
- Protocol errors return appropriate SMTP error codes
- Network errors close connection
- Graceful degradation where possible

### Testing Strategy
- Unit tests for command parser
- Unit tests for state machine transitions
- Integration tests for full sessions
- RFC compliance test suite
- Edge case testing (malformed commands, timeouts)

## Success Criteria

- [ ] All core commands implemented
- [ ] State machine passes all transition tests
- [ ] EHLO advertises supported extensions
- [ ] SIZE extension works (enforces limits)
- [ ] 8BITMIME extension advertised
- [ ] Can receive complete email message
- [ ] Handles multiple recipients
- [ ] Dot-stuffing implemented correctly
- [ ] All response codes used appropriately
- [ ] Passes RFC 5321 compliance tests

## Future Extensions (Post-0.1.0)

### Version 0.2.0 Candidates
- **STARTTLS**: TLS encryption
- **AUTH**: SMTP authentication (PLAIN, LOGIN, CRAM-MD5)
- **PIPELINING**: Command pipelining for performance

### Version 0.3.0+ Candidates
- **SMTPUTF8**: UTF-8 email addresses (RFC 6531)
- **CHUNKING**: Binary message transfer (RFC 3030)
- **DSN**: Delivery Status Notifications (RFC 3461)

## References

- [RFC 5321: SMTP](https://www.rfc-editor.org/rfc/rfc5321)
- [RFC 1870: SIZE](https://www.rfc-editor.org/rfc/rfc1870)
- [RFC 6152: 8BITMIME](https://www.rfc-editor.org/rfc/rfc6152)
- [RFC 5322: Internet Message Format](https://www.rfc-editor.org/rfc/rfc5322)
