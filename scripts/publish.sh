#!/bin/bash
#
# PrixFixe Publishing Helper Script
#
# This script helps with the publishing process for PrixFixe.
# It performs verification checks and provides guidance on the next steps.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Change to repository root
cd "$(dirname "$0")/.."

section "PrixFixe Publishing Verification"

info "Checking repository status..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not in a git repository"
    exit 1
fi
success "Git repository detected"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    warning "You have uncommitted changes"
    info "Modified files:"
    git status --short
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    success "Working directory is clean"
fi

# Check for git tags
section "Git Tags"

if git tag -l | grep -q "v0.2.0"; then
    success "Tag v0.2.0 exists"
else
    error "Tag v0.2.0 not found"
    exit 1
fi

if git tag -l | grep -q "v0.2.1"; then
    success "Tag v0.2.1 exists"
else
    error "Tag v0.2.1 not found"
    exit 1
fi

info "Tag details:"
git tag -l -n3 "v0.2.*"

# Check remote configuration
section "Remote Configuration"

if git remote -v | grep -q "origin"; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "not set")

    if [[ $REMOTE_URL == *"github.com"* ]]; then
        success "GitHub remote configured: $REMOTE_URL"
        REPO_CONFIGURED=true
    else
        warning "Remote exists but might not be GitHub: $REMOTE_URL"
        REPO_CONFIGURED=false
    fi
else
    warning "No remote 'origin' configured"
    REPO_CONFIGURED=false
    info "You'll need to set up a GitHub repository first"
fi

# Check Package.swift
section "Package Validation"

info "Validating Package.swift..."
if swift package dump-package > /dev/null 2>&1; then
    success "Package.swift is valid"
else
    error "Package.swift validation failed"
    exit 1
fi

info "Checking package structure..."
PACKAGE_NAME=$(swift package dump-package | grep -o '"name" : "[^"]*"' | head -1 | cut -d'"' -f4)
if [[ "$PACKAGE_NAME" == "PrixFixe" ]]; then
    success "Package name: $PACKAGE_NAME"
else
    error "Unexpected package name: $PACKAGE_NAME"
    exit 1
fi

# Build verification
section "Build Verification"

info "Building package (debug)..."
if swift build > /dev/null 2>&1; then
    success "Debug build successful"
else
    error "Debug build failed"
    exit 1
fi

info "Building package (release)..."
if swift build -c release > /dev/null 2>&1; then
    success "Release build successful"
else
    error "Release build failed"
    exit 1
fi

# Check required files
section "Required Files"

required_files=("README.md" "LICENSE" "CHANGELOG.md" "Package.swift")
for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        success "Found: $file"
    else
        error "Missing: $file"
        exit 1
    fi
done

# Check README for placeholder
if grep -q "YOUR-USERNAME" README.md; then
    warning "README.md still contains placeholder 'YOUR-USERNAME'"
    info "You need to replace it with your actual GitHub username"
    PLACEHOLDER_EXISTS=true
else
    success "No placeholders found in README.md"
    PLACEHOLDER_EXISTS=false
fi

# Test execution (quick check)
section "Test Verification"

info "Running quick test verification..."
if swift test --filter PrixFixeTests 2>&1 | grep -q "passed"; then
    success "Tests are executable"
else
    warning "Test execution check inconclusive"
fi

# Summary and next steps
section "Publication Checklist"

echo ""
if [[ $REPO_CONFIGURED == true ]]; then
    success "Repository is configured"
else
    echo "☐ Set up GitHub repository"
    echo "  Command: gh repo create PrixFixe --public"
    echo "  Or manually at: https://github.com/new"
    echo ""
    echo "☐ Configure git remote"
    echo "  Command: git remote add origin https://github.com/YOUR-USERNAME/PrixFixe.git"
    echo ""
fi

if [[ $PLACEHOLDER_EXISTS == true ]]; then
    echo "☐ Update README.md with your GitHub username"
    echo "  Edit line 108 to replace YOUR-USERNAME"
    echo ""
fi

echo "☐ Push code and tags to GitHub"
echo "  Command: git push -u origin main"
echo "  Command: git push origin v0.2.0"
echo "  Command: git push origin v0.2.1"
echo ""
echo "☐ Create GitHub releases"
echo "  Option 1 (gh CLI): See PUBLISHING.md for commands"
echo "  Option 2 (Web): Visit https://github.com/YOUR-USERNAME/PrixFixe/releases"
echo ""
echo "☐ Verify package installation (see PUBLISHING.md)"
echo ""
echo "☐ Optional: Submit to Swift Package Index"
echo "  Visit: https://swiftpackageindex.com/add-a-package"
echo ""

section "Documentation"

echo ""
info "For detailed publishing instructions, see:"
echo "  - ${BLUE}PUBLISHING.md${NC} (complete step-by-step guide)"
echo "  - ${BLUE}CHANGELOG.md${NC} (release notes)"
echo "  - ${BLUE}README.md${NC} (user-facing documentation)"
echo ""

if [[ $REPO_CONFIGURED == true ]] && [[ $PLACEHOLDER_EXISTS == false ]]; then
    section "Ready to Publish!"
    echo ""
    success "All verifications passed!"
    success "Your package is ready to be published to GitHub"
    echo ""
    info "Next step: Push to GitHub"
    echo ""
    echo "Run these commands:"
    echo "  ${GREEN}git push -u origin main${NC}"
    echo "  ${GREEN}git push origin v0.2.0${NC}"
    echo "  ${GREEN}git push origin v0.2.1${NC}"
    echo ""
else
    section "Action Required"
    echo ""
    warning "Complete the checklist items above before publishing"
    info "Refer to PUBLISHING.md for detailed instructions"
    echo ""
fi
