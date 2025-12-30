# Anitomy FFI Cross-Platform Build Guide

This guide explains how to compile the anitomy C++ wrapper for different platforms and integrate it with Flutter.

## Overview

The anitomy library is exposed to Dart via FFI (Foreign Function Interface) through a C wrapper. Each platform requires:

1. Compiling the C++ library to a shared library (.dylib, .dll, .so)
2. Bundling the library with your Flutter app
3. Loading it correctly in Dart code

## Platform-Specific Instructions

### macOS

#### Build Steps:

```bash
cd native/anitomy/wrapper
mkdir -p build && cd build
cmake ..
cmake --build .
```

**Output:** `libanitomy_wrapper.dylib`

#### Integration:

1. Copy the dylib to your Flutter app:

    ```bash
    cp build/libanitomy_wrapper.dylib ../../../macos/
    ```

2. For development/testing, the Dart code already tries to load from:

    - Current directory: `libanitomy_wrapper.dylib`
    - Build directory: `native/anitomy/wrapper/build/libanitomy_wrapper.dylib`

3. For production, add to your `macos/Runner.xcodeproj`:
    - Add the dylib as a resource
    - Ensure it's copied to the app bundle

#### Alternative - Bundle with App:

Edit `macos/Podfile` to copy the dylib during build:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_macos_build_settings(target)
  end

  # Copy anitomy library
  system("cp native/anitomy/wrapper/build/libanitomy_wrapper.dylib macos/")
end
```

---

### iOS

iOS uses the same source code but with different compiler settings.

#### Build Steps:

```bash
cd native/anitomy/wrapper
mkdir -p build-ios && cd build-ios

# For device (arm64)
cmake .. \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH=NO

cmake --build . --config Release

# For simulator (x86_64 or arm64)
cmake .. \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0

cmake --build . --config Release
```

#### Create Universal Binary (Fat Library):

```bash
lipo -create \
  build-ios-device/libanitomy_wrapper.dylib \
  build-ios-simulator/libanitomy_wrapper.dylib \
  -output libanitomy_wrapper.dylib
```

#### Integration:

1. Copy to iOS directory:

    ```bash
    cp libanitomy_wrapper.dylib ../../../ios/
    ```

2. Add to `ios/Runner.xcodeproj`:
    - Drag the .dylib into Xcode project
    - Add to "Frameworks, Libraries, and Embedded Content"
    - Set to "Embed & Sign"

---

### Android

Android requires building for multiple architectures (ABIs).

#### Prerequisites:

```bash
# Install Android NDK
# Set environment variable
export ANDROID_NDK=$HOME/Android/Sdk/ndk/26.1.10909125
```

#### Build Steps:

Create a build script `build-android.sh`:

```bash
#!/bin/bash

NDK_PATH=$ANDROID_NDK
TOOLCHAIN=$NDK_PATH/build/cmake/android.toolchain.cmake

ANDROID_ABIS=("armeabi-v7a" "arm64-v8a" "x86" "x86_64")

for ABI in "${ANDROID_ABIS[@]}"; do
  echo "Building for $ABI..."

  BUILD_DIR="build-android-$ABI"
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"

  cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM=android-21 \
    -DCMAKE_BUILD_TYPE=Release \
    -DANDROID_STL=c++_shared

  cmake --build . --config Release

  cd ..
done
```

Run the script:

```bash
cd native/anitomy/wrapper
chmod +x build-android.sh
./build-android.sh
```

**Output:** Multiple `libanitomy_wrapper.so` files, one per ABI

#### Integration:

1. Create JNI library structure:

    ```bash
    mkdir -p android/app/src/main/jniLibs/{armeabi-v7a,arm64-v8a,x86,x86_64}
    ```

2. Copy libraries to their respective ABI folders:

    ```bash
    cp build-android-armeabi-v7a/libanitomy_wrapper.so android/app/src/main/jniLibs/armeabi-v7a/
    cp build-android-arm64-v8a/libanitomy_wrapper.so android/app/src/main/jniLibs/arm64-v8a/
    cp build-android-x86/libanitomy_wrapper.so android/app/src/main/jniLibs/x86/
    cp build-android-x86_64/libanitomy_wrapper.so android/app/src/main/jniLibs/x86_64/
    ```

3. The libraries will be automatically included when building the APK/AAB

---

### Windows

#### Prerequisites:

-   Visual Studio 2019+ with C++ desktop development tools
-   CMake

#### Build Steps (Command Prompt or PowerShell):

```powershell
cd native\anitomy\wrapper
mkdir build
cd build

# For 64-bit
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release

# For 32-bit (if needed)
cmake .. -G "Visual Studio 17 2022" -A Win32
cmake --build . --config Release
```

**Output:** `anitomy_wrapper.dll` in `build/Release/`

#### Integration:

1. Copy DLL to Windows directory:

    ```powershell
    copy build\Release\anitomy_wrapper.dll windows\
    ```

2. For deployment, ensure the DLL is in the same directory as the executable or in the system PATH

---

### Linux

#### Build Steps:

```bash
cd native/anitomy/wrapper
mkdir -p build && cd build
cmake ..
cmake --build . --config Release
```

**Output:** `libanitomy_wrapper.so`

#### Integration:

1. Copy to linux directory:

    ```bash
    cp build/libanitomy_wrapper.so ../../../linux/
    ```

2. For system-wide installation (optional):
    ```bash
    sudo cp build/libanitomy_wrapper.so /usr/local/lib/
    sudo ldconfig
    ```

---

## Automated Build with Flutter

### Option 1: Build Script

Create `scripts/build_native.sh`:

```bash
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER_DIR="$PROJECT_ROOT/native/anitomy/wrapper"

echo "Building anitomy native library..."

# Determine platform
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Building for macOS..."
  cd "$WRAPPER_DIR"
  mkdir -p build && cd build
  cmake ..
  cmake --build .
  cp libanitomy_wrapper.dylib "$PROJECT_ROOT/macos/"
  echo "✓ macOS library built and copied"

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Building for Linux..."
  cd "$WRAPPER_DIR"
  mkdir -p build && cd build
  cmake ..
  cmake --build . --config Release
  cp libanitomy_wrapper.so "$PROJECT_ROOT/linux/"
  echo "✓ Linux library built and copied"

elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
  echo "Building for Windows..."
  cd "$WRAPPER_DIR"
  mkdir -p build && cd build
  cmake .. -G "Visual Studio 17 2022" -A x64
  cmake --build . --config Release
  cp Release/anitomy_wrapper.dll "$PROJECT_ROOT/windows/"
  echo "✓ Windows library built and copied"
fi

echo "Build complete!"
```

Make executable and run:

```bash
chmod +x scripts/build_native.sh
./scripts/build_native.sh
```

### Option 2: CMake Plugin Integration

For more advanced integration, you can use `flutter_rust_wrapper` patterns or create a custom build configuration that runs CMake as part of the Flutter build process.

---

## Dart Library Loading

The current implementation in `lib/shared/anitomy.dart` loads libraries correctly for each platform:

```dart
DynamicLibrary loadAnitomyLibrary() {
  if (Platform.isMacOS || Platform.isIOS) {
    try {
      return DynamicLibrary.open('libanitomy_wrapper.dylib');
    } catch (e) {
      return DynamicLibrary.open(
        'native/anitomy/wrapper/build/libanitomy_wrapper.dylib',
      );
    }
  }
  if (Platform.isWindows) return DynamicLibrary.open('anitomy_wrapper.dll');
  return DynamicLibrary.open('libanitomy_wrapper.so'); // Linux/Android
}
```

For production, you may want to use `DynamicLibrary.process()` on iOS/macOS if the library is statically linked.

---

## Troubleshooting

### Symbol Not Found

-   **macOS/iOS:** Check with `nm -g libanitomy_wrapper.dylib | grep anitomy_parse`
-   **Linux:** Check with `nm -D libanitomy_wrapper.so | grep anitomy_parse`
-   **Windows:** Check with `dumpbin /EXPORTS anitomy_wrapper.dll`

Ensure symbols are exported with proper visibility settings in CMakeLists.txt.

### Library Not Found at Runtime

-   Verify the library is in the correct location
-   Check file permissions (must be readable/executable)
-   On Android, verify the correct ABI is being used
-   Use `DynamicLibrary.open()` with absolute paths for debugging

### UTF-8 Encoding Issues

The wrapper converts wide strings (UTF-16/32) to UTF-8. If you see garbled text:

-   Ensure input filenames are UTF-8 encoded
-   Check the conversion logic in `anitomy_wrapper.cpp`

### Android ABI Mismatch

If the app crashes on Android:

-   Build for all required ABIs (arm64-v8a is most important)
-   Check `android/app/build.gradle` for `ndk.abiFilters`

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Native Libraries

on: [push, pull_request]

jobs:
    build-macos:
        runs-on: macos-latest
        steps:
            - uses: actions/checkout@v3
            - name: Build
              run: |
                  cd native/anitomy/wrapper
                  mkdir build && cd build
                  cmake ..
                  cmake --build .
            - uses: actions/upload-artifact@v3
              with:
                  name: macos-lib
                  path: native/anitomy/wrapper/build/libanitomy_wrapper.dylib

    build-linux:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v3
            - name: Build
              run: |
                  cd native/anitomy/wrapper
                  mkdir build && cd build
                  cmake ..
                  cmake --build .
            - uses: actions/upload-artifact@v3
              with:
                  name: linux-lib
                  path: native/anitomy/wrapper/build/libanitomy_wrapper.so

    build-windows:
        runs-on: windows-latest
        steps:
            - uses: actions/checkout@v3
            - name: Build
              run: |
                  cd native/anitomy/wrapper
                  mkdir build
                  cd build
                  cmake .. -G "Visual Studio 17 2022" -A x64
                  cmake --build . --config Release
            - uses: actions/upload-artifact@v3
              with:
                  name: windows-lib
                  path: native/anitomy/wrapper/build/Release/anitomy_wrapper.dll
```

---

## Best Practices

1. **Version Control:** Don't commit compiled binaries. Use build scripts or CI/CD
2. **Testing:** Test on all target platforms before release
3. **Error Handling:** Wrap library loading in try-catch for graceful fallbacks
4. **Documentation:** Keep this guide updated as you add platform support
5. **Dependencies:** Document any platform-specific dependencies (NDK versions, etc.)
