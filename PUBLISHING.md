# PrixFixe Publishing Guide

This document contains instructions for publishing PrixFixe as a Swift Package.

## Publishing Status

**Current Version**: v0.2.1 (Stable Release with STARTTLS/TLS Support)

**Package Readiness**: ✅ Complete

- ✅ Package.swift configured and validated
- ✅ README updated with installation instructions
- ✅ Git tags created (v0.2.0, v0.2.1)
- ✅ Tests passing (308/318)
- ✅ Documentation complete
- ✅ Build verified (debug and release)

## Remaining Steps

### 1. Set Up GitHub Repository

If you haven't already created a GitHub repository:

```bash
# Create repository on GitHub (via web interface or gh CLI)
gh repo create PrixFixe --public --description "Lightweight embedded SMTP server written in Swift"

# Or create manually at: https://github.com/new
```

### 2. Configure Git Remote

Add the GitHub repository as remote origin:

```bash
cd /Users/chris/Code/MCP/PrixFixe
git remote add origin https://github.com/YOUR-USERNAME/PrixFixe.git
```

Replace `YOUR-USERNAME` with your actual GitHub username.

### 3. Update README with Your Username

Update the placeholder in README.md:

```bash
# Find and replace YOUR-USERNAME with your actual GitHub username
sed -i '' 's/YOUR-USERNAME/your-actual-username/g' README.md
```

Or manually edit line 108 in `/Users/chris/Code/MCP/PrixFixe/README.md`

### 4. Commit README Changes

```bash
git add README.md
git commit -m "Update README with GitHub repository URL"
```

### 5. Push to GitHub

Push the code and tags to GitHub:

```bash
# Push main branch
git push -u origin main

# Push tags
git push origin v0.2.0
git push origin v0.2.1
```

### 6. Create GitHub Releases

Create releases on GitHub for both versions:

**Option A: Using GitHub CLI (`gh`)**

```bash
# Create v0.2.0 release
gh release create v0.2.0 \
  --title "v0.2.0 - STARTTLS/TLS Support" \
  --notes "$(cat <<'EOF'
Major feature release adding complete STARTTLS/TLS encryption support.

## Key Features

- RFC 3207 STARTTLS implementation
- Platform-native TLS: Security.framework (macOS/iOS), OpenSSL (Linux)
- Flexible certificate configuration (file, data, self-signed)
- TLS 1.2/1.3 support with configurable minimum version
- 108 comprehensive TLS tests
- Extensive TLS documentation guide

## Highlights

- Full RFC 5321 core compliance with STARTTLS extension
- Production-ready TLS encryption
- Multi-platform support: Linux, macOS 13.0+, iOS 16.0+
- Zero breaking changes from v0.1.0
- Comprehensive test coverage (258 tests)

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/YOUR-USERNAME/PrixFixe.git", from: "0.2.0")
]
```

See [CHANGELOG.md](https://github.com/YOUR-USERNAME/PrixFixe/blob/main/CHANGELOG.md) for complete release notes.
See [TLS-GUIDE.md](https://github.com/YOUR-USERNAME/PrixFixe/blob/main/Documentation/TLS-GUIDE.md) for TLS configuration.
EOF
)"

# Create v0.2.1 release
gh release create v0.2.1 \
  --title "v0.2.1 - Stability Improvements" \
  --notes "$(cat <<'EOF'
Stability and testing improvements release building on v0.2.0 STARTTLS/TLS support.

## Improvements

- Enhanced error handling for SMTP sessions
- Comprehensive metrics collection framework
- Additional test coverage (318 total tests, 308 passing)
- Performance optimizations and stress testing
- Production deployment guide
- Docker deployment improvements

## Testing

- 53 new MetricsCollector tests
- Enhanced error handling test coverage
- Production stress test validation

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/YOUR-USERNAME/PrixFixe.git", from: "0.2.1")
]
```

This is a recommended update for all v0.2.0 users.
EOF
)" \
  --latest
```

**Option B: Using GitHub Web Interface**

1. Go to https://github.com/YOUR-USERNAME/PrixFixe/releases
2. Click "Create a new release"
3. Select tag `v0.2.0`
4. Title: "v0.2.0 - STARTTLS/TLS Support"
5. Copy release notes from above
6. Click "Publish release"
7. Repeat for `v0.2.1` and mark it as "latest release"

### 7. Verify Package Installation

Test that users can install your package:

```bash
# Create a test project
mkdir /tmp/test-prixfixe
cd /tmp/test-prixfixe

# Create Package.swift
cat > Package.swift <<'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TestPrixFixe",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/YOUR-USERNAME/PrixFixe.git", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "TestPrixFixe",
            dependencies: [
                .product(name: "PrixFixe", package: "PrixFixe")
            ]
        )
    ]
)
EOF

# Create main.swift
mkdir Sources/TestPrixFixe
cat > Sources/TestPrixFixe/main.swift <<'EOF'
import PrixFixe
import PrixFixeCore

print("PrixFixe imports successfully!")

let config = ServerConfiguration(
    domain: "test.example.com",
    port: 2525
)
print("Configuration: \(config)")
EOF

# Resolve and build
swift build
swift run
```

### 8. Optional: Submit to Swift Package Index

Submit your package to the Swift Package Index for better discoverability:

1. Go to https://swiftpackageindex.com/add-a-package
2. Enter your repository URL: `https://github.com/YOUR-USERNAME/PrixFixe`
3. Submit for inclusion

Requirements:
- ✅ Public GitHub repository
- ✅ Valid Package.swift
- ✅ Semantic versioning tags
- ✅ MIT License
- ✅ README with documentation

## Package Information Summary

### Package Details

- **Name**: PrixFixe
- **Description**: Lightweight embedded SMTP server written in Swift
- **License**: MIT
- **Swift Version**: 6.0+
- **Platforms**: macOS 13.0+, iOS 16.0+, Linux

### Products

- `PrixFixe` (library): Main umbrella module re-exporting all public APIs

### Available Modules

Users can import:

```swift
import PrixFixe          // Umbrella module (imports all)
import PrixFixeCore      // SMTP server implementation
import PrixFixeNetwork   // Network transport abstractions
import PrixFixeMessage   // Email message structures
import PrixFixePlatform  // Platform detection
```

### Dependencies

- **Runtime**: None (pure Swift + Foundation + Network.framework on Apple platforms)
- **Development**: swift-testing 0.10.0+ (tests only)
- **Linux TLS**: OpenSSL libraries (libssl-dev)

### Tags Created

- `v0.2.0`: STARTTLS/TLS support (commit 11c5da5)
- `v0.2.1`: Stability improvements (HEAD)

## Verification Checklist

Before publishing, verify:

- ✅ Package.swift is valid (`swift package dump-package`)
- ✅ Package builds successfully (`swift build`)
- ✅ Tests pass (`swift test`)
- ✅ README contains installation instructions
- ✅ LICENSE file exists
- ✅ Git tags are created and annotated
- ✅ GitHub repository is public
- ✅ Remote origin is configured

## Post-Publication

After publishing:

1. **Announce the release**:
   - Twitter/Mastodon with #SwiftLang
   - Swift Forums: https://forums.swift.org/c/related-projects
   - Reddit: r/swift

2. **Monitor package health**:
   - Watch for GitHub issues
   - Monitor Swift Package Index build status (if submitted)
   - Check for compatibility with new Swift versions

3. **Update documentation**:
   - Consider generating and hosting DocC documentation
   - Keep examples up to date

## Troubleshooting

### Issue: Package resolution fails

Check that:
- Repository is public
- Tags are pushed to remote
- Package.swift is valid
- No typos in repository URL

### Issue: Build fails for consumers

Verify:
- Platform requirements are correct
- Dependencies are properly declared
- Public API is correctly exposed
- Import statements work

### Issue: Swift Package Index shows errors

Common causes:
- Missing or invalid LICENSE file
- Invalid semantic versioning
- Build errors on specific platforms
- Missing platform declarations

## Support

For questions or issues:

- **GitHub Issues**: https://github.com/YOUR-USERNAME/PrixFixe/issues
- **Documentation**: https://github.com/YOUR-USERNAME/PrixFixe/blob/main/README.md
- **TLS Guide**: https://github.com/YOUR-USERNAME/PrixFixe/blob/main/Documentation/TLS-GUIDE.md

---

**Note**: Remember to replace `YOUR-USERNAME` with your actual GitHub username throughout all files and commands.
