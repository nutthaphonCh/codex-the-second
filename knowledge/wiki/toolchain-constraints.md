---
name: toolchain-constraints
description: What Command Line Tools can and cannot do compared with full Xcode, and the workarounds this repo uses.
metadata:
  type: wiki
---

The project is built and tested against **Command Line Tools only**, with full
Xcode on CI. Differences that actually bite:

**Universal binaries.** `swift build --arch arm64 --arch x86_64` requires
xcbuild, which ships with Xcode:

```
error: xcbuild executable at '.../XCBuild.framework/...' does not exist
```

Workaround: build each architecture into its own `--scratch-path` with
`-Xswiftc -target`, then `lipo -create`. Works everywhere, and is what
`scripts/build.sh` does.

**XCTest is absent from Command Line Tools.** Tests use **swift-testing**
(`import Testing`) instead, which CLT does ship — but in a location SwiftPM does
not search, and missing an rpath entry. `scripts/test.sh` detects a CLT-only
toolchain and adds:

```
-Xswiftc -F <CLT>/Library/Developer/Frameworks
-Xlinker -rpath -Xlinker <CLT>/Library/Developer/Frameworks
-Xlinker -rpath -Xlinker <CLT>/Library/Developer/usr/lib   # lib_TestingInterop
```

**swift-testing needs Xcode 16+.** The `macos-14` runner image's default Xcode
predates it and fails with `no such module 'Testing'`. CI runs on `macos-15` and
explicitly selects the newest `Xcode_*.app` on the image, rather than pinning a
version that image updates will remove.

**`plutil` reads JSON but does not lint it.** `plutil -extract` and
`plutil -convert` accept JSON; `plutil -lint` rejects it with
`Unexpected character { at line 1`. Profile JSON is validated with
`plutil -convert json -o /dev/null`. Reading config with `plutil` is why the
build needs no Python or jq.

**macOS ships bash 3.2.** `"${arr[@]}"` on an empty array is an *unbound
variable* there under `set -u`. Use `${arr[@]+"${arr[@]}"}`.

Related: [[signing-and-gatekeeper]], [[naming-conventions]]
