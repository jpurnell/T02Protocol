# Publishing T02Protocol to GitHub

This guide shows you how to publish the T02Protocol Swift Package to GitHub so others can use it.

## Option 1: Standalone Repository (Recommended)

This creates a dedicated repository just for the Swift package.

### Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Fill in:
   - **Repository name**: `T02Protocol` (or `SwiftT02Protocol`)
   - **Description**: `Swift package for Phomemo T02 thermal printer communication`
   - **Public** or Private (your choice)
   - **Don't** initialize with README (we have one)
3. Click "Create repository"

### Step 2: Prepare Package Directory

```bash
cd /Users/jpurnell/Dropbox/Computer/Development/python/phomemo-tools/shared/swift

# Clean up development artifacts
rm -rf .build
rm -f test_image.png test_label.png test_output.swift

# Rename README for package
mv README_PACKAGE.md README.md

# Optional: Remove development docs (keep if you want)
# rm SWIFT_TDD_STATUS.md SWIFT_IMPLEMENTATION_COMPLETE.md
```

### Step 3: Initialize Git

```bash
# Initialize new git repo
git init

# Add files
git add .

# First commit
git commit -m "Initial release of T02Protocol Swift Package

- Complete T02 ESC/POS protocol implementation
- CoreBluetooth support for macOS/iOS
- Automatic image processing and conversion
- Command-line tool for testing
- Comprehensive test suite
- MIT License"
```

### Step 4: Push to GitHub

```bash
# Add remote (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/T02Protocol.git

# Push
git branch -M main
git push -u origin main
```

### Step 5: Create Release

1. Go to your repository on GitHub
2. Click "Releases" → "Create a new release"
3. Tag: `1.0.0`
4. Title: `v1.0.0 - Initial Release`
5. Description:
   ```markdown
   # T02Protocol v1.0.0

   First stable release of T02Protocol Swift Package.

   ## Features
   - ✅ Complete T02 thermal printer protocol
   - ✅ Bluetooth Low Energy support
   - ✅ Automatic image conversion
   - ✅ macOS 13+ and iOS 16+ support
   - ✅ Command-line printing tool
   - ✅ Full test suite

   ## Usage

   Add to your `Package.swift`:
   ```swift
   dependencies: [
       .package(url: "https://github.com/YOUR_USERNAME/T02Protocol", from: "1.0.0")
   ]
   ```

   See [README](https://github.com/YOUR_USERNAME/T02Protocol) for documentation.
   ```
6. Click "Publish release"

## Option 2: Subdirectory in Existing Repo

If you want to keep it in the phomemo-tools repo:

### Step 1: Add Swift Package to Main Repo

```bash
cd /Users/jpurnell/Dropbox/Computer/Development/python/phomemo-tools

# Add the swift package files
git add shared/swift/

# Commit
git commit -m "Add T02Protocol Swift Package

- Swift library for T02 thermal printer
- macOS/iOS support via CoreBluetooth
- Includes command-line tool and tests"

# Push
git push origin master
```

### Step 2: Document in Main README

Add to the main phomemo-tools README:

```markdown
## Swift Package (macOS/iOS)

For macOS and iOS applications, use the Swift package:

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/YOUR_USERNAME/phomemo-tools", from: "1.0.0")
]
```

See [shared/swift/README.md](shared/swift/README.md) for documentation.
```

## Using the Package in Other Projects

Once published, others can use it:

### In Xcode

1. File → Add Package Dependencies...
2. Enter your repository URL
3. Select version
4. Add to target

### In Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/YOUR_USERNAME/T02Protocol", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: ["T02Protocol"]
        )
    ]
)
```

## Versioning

Follow [Semantic Versioning](https://semver.org/):

- **1.0.0** - Initial release
- **1.0.1** - Bug fixes
- **1.1.0** - New features (backward compatible)
- **2.0.0** - Breaking changes

## Updating the Package

When you make changes:

```bash
# Make your changes
# ...

# Commit
git add .
git commit -m "Description of changes"

# Tag new version
git tag 1.1.0
git push origin main --tags
```

Then create a new release on GitHub with release notes.

## Files to Include

Essential files (already in place):
- ✅ `Package.swift` - Package manifest
- ✅ `README.md` - Documentation
- ✅ `LICENSE` - MIT License
- ✅ `Sources/` - Source code
- ✅ `Tests/` - Test suite
- ✅ `.gitignore` - Git ignore rules

Optional but recommended:
- ✅ `INTEGRATION_EXAMPLE.md` - Usage examples
- 📝 `CHANGELOG.md` - Version history (create if updating)

Files to exclude:
- ❌ `.build/` - Build artifacts (in .gitignore)
- ❌ `test_*.png` - Test files (in .gitignore)
- ❌ Development notes (optional to keep)

## README Checklist

Make sure your README has:
- [x] Clear description
- [x] Installation instructions
- [x] Basic usage example
- [x] API documentation
- [x] Requirements
- [x] License
- [x] Examples

## GitHub Repository Settings

Recommended settings:

1. **Topics**: Add topics for discoverability
   - `swift`
   - `swift-package`
   - `thermal-printer`
   - `bluetooth`
   - `phomemo`
   - `ble`
   - `ios`
   - `macos`

2. **About**: Short description
   ```
   Swift package for Phomemo T02 thermal printer. BLE printing for macOS/iOS.
   ```

3. **Enable**:
   - Issues (for bug reports)
   - Discussions (optional - for questions)

4. **Disable**:
   - Wiki (unless you want it)

## Testing Before Release

Before publishing, verify:

```bash
# Clean build
rm -rf .build
swift build

# Run tests
swift test

# Test in a new project
cd /tmp
mkdir TestT02
cd TestT02

# Create test Package.swift pointing to your local package
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TestT02",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "/Users/jpurnell/Dropbox/Computer/Development/python/phomemo-tools/shared/swift")
    ],
    targets: [
        .executableTarget(
            name: "TestT02",
            dependencies: ["T02Protocol"]
        )
    ]
)
EOF

mkdir Sources
mkdir Sources/TestT02
cat > Sources/TestT02/main.swift << 'EOF'
import T02Protocol

let protocol = T02Protocol()
print("T02Protocol loaded successfully!")
print("Width: \(T02Protocol.widthDots) dots")
EOF

swift run
```

If that works, you're ready to publish!

## After Publishing

1. **Update main README** - Link to the package
2. **Create examples** - Show real-world usage
3. **Write blog post** - Share what you built
4. **Share on Twitter/Mastodon** - Let people know
5. **Add to Swift Package Index** - https://swiftpackageindex.com

## Support

If others use your package, they might:
- Open issues
- Submit pull requests
- Ask questions

Be ready to:
- Review contributions
- Fix bugs
- Answer questions
- Update documentation

## Example CHANGELOG.md

Create this file for version tracking:

```markdown
# Changelog

All notable changes to T02Protocol will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-10

### Added
- Initial release
- Complete T02 ESC/POS protocol implementation
- CoreBluetooth integration for macOS/iOS
- Automatic image processing
- Command-line printing tool
- Comprehensive test suite
- MIT License

### Documentation
- README with usage examples
- API documentation
- Integration examples
- Quick start guide
```

## Quick Publish Checklist

- [ ] Clean up test files
- [ ] Verify Package.swift is correct
- [ ] README.md is complete
- [ ] LICENSE file exists
- [ ] .gitignore is configured
- [ ] Tests pass (`swift test`)
- [ ] Builds cleanly (`swift build`)
- [ ] Initialize git repository
- [ ] Create GitHub repository
- [ ] Push to GitHub
- [ ] Create v1.0.0 release
- [ ] Add topics to repository
- [ ] Test installation in new project

---

You're ready to share your package with the world! 🚀
