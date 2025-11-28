# CRITICAL-001: macOS/iOS TLS Certificate Loading Not Implemented

**Status**: 🔴 BLOCKS v0.2.0 RELEASE
**Severity**: CRITICAL
**Created**: 2025-11-28
**Priority**: P0 - Must fix before release
**Assignee**: TBD
**Estimated Effort**: 2-3 days

---

## Summary

The macOS/iOS TLS certificate loading functionality is completely non-functional. The `createIdentity_Darwin()` function is a placeholder that always throws an error, making TLS completely broken on Apple platforms despite documentation claiming "production-ready TLS support."

## Impact

- **Functionality**: TLS/STARTTLS does not work at all on macOS and iOS
- **User Experience**: Any attempt to configure TLS on Apple platforms will fail immediately
- **Documentation**: README.md and TLS-GUIDE.md promise functionality that doesn't exist
- **Reputation**: Releasing in this state would severely damage project credibility
- **Platform Support**: Advertises multi-platform TLS but only Linux actually works

## Technical Details

### Location
`Sources/PrixFixeNetwork/FoundationSocket.swift:442-449`

### Current Implementation
```swift
private func createIdentity_Darwin(certData: Data, keyData: Data) throws -> SecIdentity {
    // This is a placeholder. A full implementation would:
    // 1. Parse the PEM certificate and key
    // 2. Convert to DER format if needed
    // 3. Create SecCertificate and SecKey objects
    // 4. Create SecIdentity from those objects
    // For now, we'll throw an error
    throw NetworkError.invalidCertificate("Certificate loading not fully implemented")
}
```

### Called From
- `loadCertificate_Darwin()` for `.file` certificate source (line 406-416)
- `loadCertificate_Darwin()` for `.data` certificate source (line 424-433)

### Impact Scope
ALL certificate loading attempts on macOS/iOS fail, including:
- File-based certificates (`.file`)
- In-memory certificate data (`.data`)
- Self-signed certificates (`.selfSigned`) - also not implemented

## Why This Wasn't Caught

The 108 TLS-specific tests all use `MockTLSConnection` which simulates TLS upgrade without actually loading certificates or performing real TLS handshakes. Tests validate:
- ✅ State machine transitions
- ✅ Buffer security
- ✅ Command sequencing
- ✅ Error handling

But **do not** validate actual certificate loading or TLS handshake functionality.

## Required Fix

Implement `createIdentity_Darwin()` to:

1. **Parse PEM Format**
   - Extract certificate data from PEM format
   - Extract private key data from PEM format
   - Handle both RSA and EC keys

2. **Create SecCertificate**
   ```swift
   SecCertificateCreateWithData(allocator: CFAllocator?, data: CFData) -> SecCertificate?
   ```

3. **Create SecKey from Private Key**
   ```swift
   // For PEM keys, need to parse and convert to DER first
   SecKeyCreateWithData(keyData: CFData, attributes: CFDictionary, error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> SecKey?
   ```

4. **Create SecIdentity**
   ```swift
   // Option 1: Use PKCS#12 import
   SecPKCS12Import(pkcs12Data: CFData, options: CFDictionary, items: UnsafeMutablePointer<CFArray?>) -> OSStatus

   // Option 2: Create from certificate and key
   // May need to use Keychain temporarily
   ```

5. **Handle Errors**
   - Invalid PEM format
   - Mismatched certificate/key pair
   - Unsupported key types
   - Password-protected keys (for `.data` source)

## Implementation Notes

### PEM Parsing
PEM files have structure:
```
-----BEGIN CERTIFICATE-----
[Base64 encoded DER data]
-----END CERTIFICATE-----

-----BEGIN PRIVATE KEY----- or -----BEGIN RSA PRIVATE KEY-----
[Base64 encoded DER data]
-----END PRIVATE KEY-----
```

Need to:
1. Extract content between BEGIN/END markers
2. Base64 decode to get DER format
3. Create Security.framework objects from DER

### Password Support
For `.data(certData, keyData, password)` source:
- Need to decrypt private key if password provided
- May need to use SecItemImport with password callback

### Testing Strategy
After implementation:
1. Add real certificate integration tests
2. Test with actual PEM files
3. Test with self-signed certificates
4. Test with password-protected keys
5. Test on both macOS and iOS
6. Verify TLS handshake completes successfully

## Alternative: Scope Reduction

If implementation cannot be completed in time for v0.2.0:

### Option B: Linux-Only TLS for v0.2.0

**Actions Required** (4-6 hours):

1. **Update Documentation**
   - README.md: Change "production-ready TLS" to "production-ready TLS on Linux"
   - TLS-GUIDE.md: Add platform status section
   - CHANGELOG.md: Add limitation note

2. **Add Early Validation**
   ```swift
   #if canImport(Darwin)
   public func startTLS(configuration: TLSConfiguration) async throws {
       throw NetworkError.tlsUpgradeFailed(
           "TLS support on macOS/iOS is planned for v0.3.0. " +
           "Currently only available on Linux platforms."
       )
   }
   #endif
   ```

3. **Update Version**
   - Consider: v0.2.0-linux or v0.2.0-beta
   - Or: v0.2.0 with clear platform limitations documented

4. **Plan v0.3.0**
   - Add macOS/iOS TLS implementation to roadmap
   - Estimate delivery timeline

**Pros**: Can release quickly with clear expectations
**Cons**: Reduces value proposition, disappoints Apple platform users

## References

### Apple Documentation
- [Security Framework Reference](https://developer.apple.com/documentation/security)
- [Certificate, Key, and Trust Services](https://developer.apple.com/documentation/security/certificate_key_and_trust_services)
- [SecCertificate](https://developer.apple.com/documentation/security/seccertificate)
- [SecKey](https://developer.apple.com/documentation/security/seckey)
- [SecIdentity](https://developer.apple.com/documentation/security/secidentity)

### Related Files
- `Sources/PrixFixeNetwork/FoundationSocket.swift` - Implementation location
- `Sources/PrixFixeNetwork/TLSConfiguration.swift` - Public API
- `Tests/PrixFixeCoreTests/STARTTLSIntegrationTests.swift` - Mock-based tests
- `Documentation/TLS-GUIDE.md` - User documentation

### Similar Implementations
- OpenSSL implementation in same file (lines 507-546) - complete and functional
- Study for comparison of certificate loading patterns

## Acceptance Criteria

### For Full Implementation (Option A)
- [ ] `createIdentity_Darwin()` successfully loads PEM certificates
- [ ] `createIdentity_Darwin()` successfully loads PEM private keys
- [ ] File-based certificate source (`.file`) works
- [ ] In-memory certificate source (`.data`) works
- [ ] Password-protected keys are supported
- [ ] Integration tests with real certificates pass
- [ ] TLS handshake completes on macOS
- [ ] TLS handshake completes on iOS
- [ ] Documentation remains accurate
- [ ] All existing tests still pass

### For Scope Reduction (Option B)
- [ ] Documentation updated to reflect Linux-only TLS
- [ ] Early validation added for macOS/iOS
- [ ] Error message is clear and actionable
- [ ] CHANGELOG.md documents limitation
- [ ] v0.3.0 roadmap includes macOS/iOS TLS
- [ ] All existing tests still pass

## Decision Required

**Project lead must choose**:
- [ ] Option A: Complete macOS/iOS implementation (2-3 days)
- [ ] Option B: Ship Linux-only TLS for v0.2.0 (4-6 hours)

**Deadline for Decision**: Before any v0.2.0 release tagging

---

**Related Issues**:
- HIGH-002: Self-signed certificate generation not implemented

**Blocks**:
- v0.2.0 release

**Dependencies**:
- Security.framework (system-provided on macOS/iOS)
