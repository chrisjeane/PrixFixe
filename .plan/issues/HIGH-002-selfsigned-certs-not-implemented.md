# HIGH-002: Self-Signed Certificate Generation Not Implemented

**Status**: 🟠 Should fix before v0.2.0
**Severity**: HIGH
**Created**: 2025-11-28
**Priority**: P1 - Strongly recommended for release
**Assignee**: TBD
**Estimated Effort**: 1-2 days (if implementing) OR 2-3 hours (if documenting limitation)

---

## Summary

Self-signed certificate generation is not implemented on any platform (macOS, iOS, or Linux), despite the API providing a `.selfSigned(commonName:)` option and documentation showing examples using this feature.

## Impact

- **Developer Experience**: Developers cannot easily test TLS without generating certificates manually
- **Documentation Mismatch**: README.md and TLS-GUIDE.md show examples that will always fail
- **Example Application**: SimpleServer cannot demonstrate TLS without external certificate setup
- **API Confusion**: The `.selfSigned` case exists but is completely non-functional
- **Testing Barrier**: Raises barrier to entry for TLS testing

## Technical Details

### Locations

**macOS/iOS** (`Sources/PrixFixeNetwork/FoundationSocket.swift:435-438`):
```swift
case .selfSigned(let commonName):
    // Generate a self-signed certificate (simplified - not production ready)
    // For now, throw an error as this requires more complex implementation
    throw NetworkError.tlsUpgradeFailed("Self-signed certificates not yet implemented")
```

**Linux** (`Sources/PrixFixeNetwork/FoundationSocket.swift:526-528`):
```swift
case .selfSigned(let commonName):
    // Self-signed certificates not yet implemented
    throw NetworkError.tlsUpgradeFailed("Self-signed certificates not yet supported on Linux")
```

### API Definition

From `Sources/PrixFixeNetwork/TLSConfiguration.swift`:
```swift
public enum CertificateSource: Sendable {
    case file(certificatePath: String, privateKeyPath: String)
    case data(certificateData: Data, privateKeyData: Data, password: String?)
    case selfSigned(commonName: String)  // ← This case is not implemented
}
```

### Documentation Examples

**README.md** (lines 73-93):
```swift
// Self-signed certificate for development only
let tlsConfig = TLSConfiguration(
    certificateSource: .selfSigned(commonName: "localhost")  // ← This will fail
)
```

**TLS-GUIDE.md** (lines 75-91):
```swift
// Self-signed certificate for development only
let tlsConfig = TLSConfiguration(
    certificateSource: .selfSigned(commonName: "localhost")  // ← This will fail
)
```

Both examples include the warning "Never use self-signed certificates in production" but the code doesn't work at all.

## Options

### Option A: Implement Self-Signed Certificate Generation (Recommended)

**Pros**:
- Best developer experience
- Examples in documentation work
- Makes TLS testing easy
- Professional, complete API

**Cons**:
- Requires platform-specific implementation
- Adds complexity
- Needs testing

**Estimated Effort**: 1-2 days

#### Linux Implementation (OpenSSL)

OpenSSL provides APIs for certificate generation:

```swift
private func generateSelfSignedCertificate_Linux(commonName: String) throws -> (Data, Data) {
    // 1. Generate RSA key pair
    let pkey = EVP_PKEY_new()
    let rsa = RSA_generate_key(2048, RSA_F4, nil, nil)
    EVP_PKEY_assign_RSA(pkey, rsa)

    // 2. Create X509 certificate
    let x509 = X509_new()
    X509_set_version(x509, 2) // X509 v3

    // 3. Set serial number
    ASN1_INTEGER_set(X509_get_serialNumber(x509), 1)

    // 4. Set validity period (1 year)
    X509_gmtime_adj(X509_get_notBefore(x509), 0)
    X509_gmtime_adj(X509_get_notAfter(x509), 365*24*60*60)

    // 5. Set subject/issuer (same for self-signed)
    let name = X509_get_subject_name(x509)
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC, commonName, -1, -1, 0)
    X509_set_issuer_name(x509, name)

    // 6. Set public key
    X509_set_pubkey(x509, pkey)

    // 7. Sign certificate
    X509_sign(x509, pkey, EVP_sha256())

    // 8. Convert to PEM format
    let certData = convertToPEM_Certificate(x509)
    let keyData = convertToPEM_PrivateKey(pkey)

    // 9. Clean up
    X509_free(x509)
    EVP_PKEY_free(pkey)

    return (certData, keyData)
}
```

#### macOS/iOS Implementation (Security.framework)

```swift
private func generateSelfSignedCertificate_Darwin(commonName: String) throws -> SecIdentity {
    // 1. Generate key pair
    let attributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
        kSecAttrKeySizeInBits as String: 2048
    ]

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
        throw NetworkError.tlsUpgradeFailed("Failed to generate key: \(error!.takeRetainedValue())")
    }

    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
        throw NetworkError.tlsUpgradeFailed("Failed to get public key")
    }

    // 2. Create certificate request
    // Note: Security.framework doesn't have direct X509 APIs
    // Options:
    //   a) Use SecCertificateCreateWithData with manually constructed DER
    //   b) Use Keychain Services to create and extract
    //   c) Call out to command-line tools (not ideal)

    // Most robust approach: Temporarily add to keychain
    let addQuery: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrApplicationTag as String: "com.prixfixe.temp.key",
        kSecValueRef as String: privateKey,
        kSecReturnPersistentRef as String: true
    ]

    var persistentRef: CFTypeRef?
    let addStatus = SecItemAdd(addQuery as CFDictionary, &persistentRef)

    // ... continue with certificate creation ...
    // This is complex and may require manual DER encoding
}
```

**Note**: macOS implementation is more complex because Security.framework doesn't expose high-level certificate generation APIs like OpenSSL does.

#### Alternative: Use OpenSSL for Both Platforms

Could link against OpenSSL on macOS as well for self-signed generation only:
- Use Security.framework for TLS handshake (existing implementation)
- Use OpenSSL just for certificate generation
- Simpler implementation, consistent across platforms
- Requires OpenSSL on macOS (via Homebrew)

### Option B: Document Limitation and Remove Examples (Acceptable Fallback)

**Pros**:
- Quick to implement (2-3 hours)
- Clear expectations
- No risk of bugs in cert generation

**Cons**:
- Worse developer experience
- Requires manual certificate setup for testing
- Incomplete API (why have `.selfSigned` if it doesn't work?)

**Estimated Effort**: 2-3 hours

#### Required Changes

1. **Update TLS-GUIDE.md**
   - Remove self-signed examples
   - Add "How to Generate Test Certificates" section
   - Show OpenSSL commands for manual cert generation

2. **Update README.md**
   - Replace self-signed example with file-based example
   - Link to TLS guide for certificate generation

3. **Update TLSConfiguration.swift DocC comments**
   ```swift
   /// - selfSigned: Generate a self-signed certificate for development
   ///   - Note: Not implemented in v0.2.0. Use OpenSSL to generate certificates manually.
   ///         See TLS-GUIDE.md for instructions.
   case selfSigned(commonName: String)
   ```

4. **Improve Error Message**
   ```swift
   case .selfSigned(let commonName):
       throw NetworkError.tlsUpgradeFailed(
           "Self-signed certificate generation is not yet implemented. " +
           "Please generate a certificate using OpenSSL and use .file() instead. " +
           "See Documentation/TLS-GUIDE.md for instructions."
       )
   ```

5. **Add Certificate Generation Guide to TLS-GUIDE.md**
   ```markdown
   ## Generating Self-Signed Certificates for Testing

   Until self-signed certificate generation is implemented in v0.3.0,
   you can generate certificates manually using OpenSSL:

   ### Linux and macOS

   ```bash
   # Generate private key
   openssl genrsa -out server.key 2048

   # Generate self-signed certificate (valid for 365 days)
   openssl req -new -x509 -key server.key -out server.crt -days 365 \
       -subj "/CN=localhost"

   # Use in PrixFixe
   let tlsConfig = TLSConfiguration(
       certificateSource: .file(
           certificatePath: "server.crt",
           privateKeyPath: "server.key"
       )
   )
   ```
   ```

### Option C: Deprecate .selfSigned for v0.2.0

Mark the case as unavailable:
```swift
@available(*, unavailable, message: "Self-signed generation will be available in v0.3.0. Use .file() with OpenSSL-generated certificates.")
case selfSigned(commonName: String)
```

**Pros**: Makes limitation explicit in compiler
**Cons**: Breaking change for anyone who compiled against this API

## Recommendation

**For v0.2.0**: Choose **Option B** (Document limitation)
- Quick to implement
- Unblocks release
- Provides clear workaround
- Sets expectation for future enhancement

**For v0.3.0**: Implement **Option A** (Self-signed generation)
- Prioritize Linux implementation first (easier with OpenSSL)
- Consider OpenSSL-based solution for macOS as well
- Excellent developer experience improvement

## References

### OpenSSL Certificate Generation
- [X509_new](https://www.openssl.org/docs/man1.1.1/man3/X509_new.html)
- [EVP_PKEY_new](https://www.openssl.org/docs/man1.1.1/man3/EVP_PKEY_new.html)
- [RSA_generate_key](https://www.openssl.org/docs/man1.1.1/man3/RSA_generate_key.html)

### Security.framework
- [SecKeyCreateRandomKey](https://developer.apple.com/documentation/security/1823694-seckeycreaterandomkey)
- [SecCertificateCreateWithData](https://developer.apple.com/documentation/security/1396073-seccertificatecreatewithdata)

### Related Files
- `Sources/PrixFixeNetwork/TLSConfiguration.swift` - API definition
- `Sources/PrixFixeNetwork/FoundationSocket.swift` - Implementation location
- `Documentation/TLS-GUIDE.md` - User documentation
- `README.md` - Examples

## Acceptance Criteria

### For Option A (Implementation)
- [ ] Self-signed certificate generation works on Linux
- [ ] Self-signed certificate generation works on macOS/iOS
- [ ] Generated certificates are valid for TLS handshake
- [ ] Certificates have configurable common name
- [ ] Documentation examples work without changes
- [ ] Tests verify certificate generation
- [ ] Error handling for generation failures

### For Option B (Document Limitation)
- [ ] TLS-GUIDE.md self-signed examples removed
- [ ] TLS-GUIDE.md includes OpenSSL generation instructions
- [ ] README.md self-signed example replaced
- [ ] Error messages improved with actionable guidance
- [ ] DocC comments updated with limitation note
- [ ] Users have clear path to generate test certificates

---

**Related Issues**:
- CRITICAL-001: macOS/iOS TLS certificate loading not implemented

**Recommended for**:
- v0.2.0 (Option B - document limitation)
- v0.3.0 (Option A - full implementation)
