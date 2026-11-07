# Bridge

Bridge provides CMake-side build, execution, installation, and packaging helpers for applications targeting several operating systems. Linux is the current primary development host; Windows cross-compilation and packaging also support macOS hosts.

## Applications on every platform

`BridgeApplication.cmake` turns a shared library with an SDL entry point into a runnable application on Linux, Windows, and Android with one call. It chooses the platform-specific functions described in the sections below, so the consumer does not branch on the platform.

```cmake
include(external/bridge/cmake/BridgeApplication.cmake)

add_library(game_main SHARED main.cpp)
target_link_libraries(game_main PRIVATE SDL3::SDL3)

bridge_add_sdl_application(
    ALL
    TARGET game
    RUN_TARGET game_run
    MAIN_TARGET game_main
    LAUNCHER_SOURCES launcher.cpp
    SDL_TARGET SDL3::SDL3
    SDL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/external/sdl3"
    APPLICATION_ID com.example.game
    APPLICATION_NAME "Example Game"
    ASSET_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/runtime"
    ICON_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/icons"
    ADAPTIVE_ICON_BACKGROUND_COLOR "#070508"
    DESKTOP_CATEGORIES Game
)
```

On Android, `game` is the APK packaging target and `game_run` installs and launches it. `ALL`, `OUTPUT`, `VERSION_NAME`, `VERSION_CODE`, `MIN_API`, and `APPLICATION_CATEGORY` apply only to the APK.

Elsewhere, `game` is an executable built from `LAUNCHER_SOURCES`, a `main()` that forwards to the library, linked with `MAIN_TARGET` and `SDL_TARGET`. It receives Canon's build policy, so Canon must be loaded first. `game_run` runs it under Bridge's Wine runner on Windows and directly on the host otherwise. `MAIN_TARGET` must be a shared library on every platform, because Android loads it as `libmain.so`.

`ICON_DIRECTORY` adds the Android launcher icons, the embedded Windows icon, or the Linux desktop entry. Its companion arguments are validated on every platform, so a project that configures on Linux does not fail later on Android.

### Running desktop executables from the build tree

```cmake
bridge_stage_runtime(
    TARGET game
    ASSET_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/runtime"
    ICON_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/icons"
)
```

`bridge_stage_runtime()` makes an executable runnable from the build tree. On Windows it stages DLLs as `bridge_stage_win32_runtime()` does. It stages the asset directory's contents beside the executable and the icon directory as `icons/` beside it, the same layout `bridge_install_linux_desktop_application()` installs. Unchanged files are not rewritten, and a file removed from a source directory is removed from the staged copy on the next build. Other files beside the executable, including the executable itself, are never touched. `bridge_add_sdl_application()` calls it for desktop executables, and other tools can call it directly; with no directories it stages only what the platform needs, which on Linux is nothing.

Executables that share an output directory share one staging target, named `<first executable>_runtime_assets`, so the build never copies into one directory concurrently. Every executable in the directory depends on it, and it stages everything any of them requested, so a tool that asks only for assets still finds the icons another program staged. Each place in the directory (the directory itself, and `icons/`) is filled from one source directory; asking for a different source for the same place is a configuration error.

### Run targets

`bridge_add_run_target(TARGET game_run APPLICATION_TARGET game)` adds a target that builds an application and starts it: an APK through Bridge's Android application runner, a Windows executable through its Wine runner, or a host executable directly. Cross-compiling for any other system is an error.

## Windows cross-compilation

Bridge's Windows profile cross-compiles with LLVM-MinGW on Linux or macOS. Wine is optional and is needed only for executing Windows programs and tests. If no Wine backend is configured, requesting execution fails with a clear error; compilation, installation, and packaging remain available. A configured Windows CTest executable stays registered and reports the missing backend when run. When present, Wine is invoked through a POSIX runner. A small POSIX `sh` runner keeps Wine's background processes detached from captured test output so CTest does not wait for Wine's idle shutdown after each executable. The toolchain first honors `BRIDGE_LLVM_MINGW_ROOT`, then the environment variable of the same name, then searches a target-prefixed LLVM-MinGW compiler already on `PATH` and `/opt/llvm-mingw`. Bridge also adds LLVM-MinGW's target runtime DLL directory to Wine's executable search path.

On Wayland hosts, the Wine runner checks `WAYLAND_DISPLAY` and its Unix socket. When the socket exists, Bridge unsets `DISPLAY` for all Wine child processes, including startup, so Wine can use its native Wayland driver. On X11-only hosts, `DISPLAY` is preserved. If Wayland is advertised but its socket is unavailable, Bridge reports the problem and keeps X11 when available. Once Wayland is selected, a Wine failure is reported without silently retrying X11. Bridge does not modify the Wine registry or the calling shell's environment.

A project using Bridge can include `external/bridge/cmake/BridgePresets.json` from its `CMakePresets.json`. Bridge's preset file includes Canon's presets and adds `win32-debug`, `win32-release`, `win32-asan`, `win32-tidy`, and `win32-coverage` with matching build, test, and workflow presets. Preset composition reads Canon from `external/canon` in the consuming source tree, so Bridge and the consumer use the same Canon preset policy.

Bridge also exposes a consumer-facing Win32 run target, parallel to its Android application run target. The run target depends on the consumer's executable, invokes the same Wine runner used by Bridge tests, and preserves Wine's display selection and LLVM-MinGW runtime configuration. Cross-compilation still works without Wine installed; invoking the run target then fails explicitly.

```cmake
include(external/bridge/cmake/BridgeWin32Run.cmake)
bridge_add_win32_run_target(
    TARGET game_run
    APPLICATION_TARGET game_exe
)
```

Build and run with one command:

```sh
cmake --build --preset win32-debug --target game_run
```

The target is intended for IDE and developer workflows, not for CTest. CMake Tools does not treat CMake custom build targets as debugger launch targets; IDEs can invoke the build target through their task integration.

Windows executables also need their DLL dependencies in the build tree. Bridge provides a separate staging API that copies CMake-managed runtime DLLs and, for recognized llvm-mingw C++ compilers, `libc++.dll` and `libunwind.dll` next to the executable after it links:

```cmake
include(external/bridge/cmake/BridgeWin32Runtime.cmake)
bridge_stage_win32_runtime(TARGET game_exe)
```

Call this from the CMake directory that defines `game_exe`, after creating the executable. The helper requires a Windows target and does not require Wine. For llvm-mingw it fails configuration if a required compiler DLL is missing. It covers build-tree execution, not a release package or arbitrary DLLs loaded at runtime outside the CMake dependency graph.

If LLVM-MinGW is installed in a nonstandard location, set the root explicitly when configuring:

```bash
cmake --preset win32-debug -DBRIDGE_LLVM_MINGW_ROOT=/path/to/llvm-mingw
```

Machine-local paths do not need to be committed or added globally to `PATH`.

### Windows build prerequisites on Linux

Windows cross-compilation needs CMake, Ninja, Python, and LLVM-MinGW. ZIP packaging needs no additional host tool. NSIS installers additionally need `makensis`; Wine is optional and is used only to execute Windows applications and tests. SDL and other Windows-target application dependencies are resolved separately by the consuming project through Canon. Bridge checks for the toolchain when configuring and reports missing requirements for requested build and execution operations.

#### Windows build prerequisites on Arch and Arch-based distributions

Install the host tools from the configured pacman repositories, updating the system as part of the operation to avoid a partial upgrade:

```sh
sudo pacman -Syu --needed cmake ninja python
```

On stock Arch, `llvm-mingw` and `nsis` are available from the AUR rather than the official repositories. Install LLVM-MinGW using your preferred AUR workflow; for example, with `paru`:

```sh
paru -S llvm-mingw
```

Arch derivatives may provide either package through their configured repositories instead. No particular AUR helper is required by Bridge.

For **optional NSIS installer packaging**, install `nsis` using your distribution's packages or the AUR. As of November 7, 2026, building AUR `nsis` 3.13-2 on an Arch-based system with LLVM-MinGW 23.1.0 exposed a package-provider conflict: `llvm-mingw` satisfied pacman's GNU MinGW dependency names without supplying the GNU assembler expected by the `mingw-w64-zlib` build. Its `i686-w64-mingw32-gcc` invocation then used the native Linux assembler and failed on Windows COFF directives such as `.def` and `.scl`.

Until the packaging dependencies are corrected, the verified workaround is to install the complete GNU MinGW toolchain components explicitly before building NSIS from the AUR:

```sh
sudo pacman -S --needed \
    mingw-w64-gcc \
    mingw-w64-binutils \
    mingw-w64-headers \
    mingw-w64-crt \
    mingw-w64-winpthreads

command -v i686-w64-mingw32-as
paru -S nsis
makensis -VERSION
```

These GNU MinGW packages are required here to **build the AUR NSIS package**, not to cross-compile Tinderbox, which continues to use LLVM-MinGW. This workaround reflects the observed package state on that date; check whether the AUR or distribution packages have since fixed the dependency chain before installing a second compiler toolchain. An official, prebuilt `makensis` does not require rebuilding NSIS or its Windows stub dependencies.

Once `makensis` is available, the intermediate compiler can be uninstalled:
```sh
pacman -Rs --print mingw-w64-gcc
sudo pacman -Rns mingw-w64-gcc
```

For optional Windows execution and tests under Wine, install it separately:

```sh
sudo pacman -S --needed wine
```

Check the Windows compiler with `x86_64-w64-mingw32-clang++ --version`. For NSIS packaging, check `makensis -VERSION`. These checks do not verify that application-specific Windows libraries have been built; those still need to be available to the consuming project. On other Linux distributions, install the equivalent tools using the distribution's package manager before configuring Bridge.

### Windows installation components

Install a Windows executable, all DLLs discovered by CMake, explicitly listed shared runtime targets, compiler runtime DLLs, and asset directories through a single Bridge helper:

```cmake
include(external/bridge/cmake/BridgeWin32Install.cmake)
bridge_install_win32_application(
    TARGET game_exe
    COMPONENT standalone
    RUNTIME_TARGETS game_main SDL3::SDL3
    ASSET_DIRECTORY "${CMAKE_BINARY_DIR}/game-runtime"
    ICON_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/icons"
)
```

The installed layout places the `.exe`, DLLs, and asset directory contents at the package root, with the icon tree under `icons/`. This keeps SDL title storage and window-icon loading consistent with build-tree execution. An explicit `RUNTIME_TARGETS` entry is important for libraries loaded dynamically, which CMake cannot discover from link dependencies alone. The helper accepts imported shared targets, including installed SDL packages. It uses the same LLVM-MinGW compiler DLL resolver as build-tree staging, and it does not require Wine or NSIS.

Install one component for a staging directory, or let CPack execute the install step while creating a ZIP:

```sh
cmake --install build/win32-release --config Release --component standalone --prefix build/stage/windows
cpack --config build/win32-release/CPackConfig.cmake -G ZIP -C Release -B build/dist
```

The consuming project owns component names, package identity, CPack options, and installer branding. CPack runs installation rules internally; do not stage the component separately before running CPack. Native Windows execution, image resources, and DLL loading still require target-platform validation before shipping.

### Distribution targets and collection

Bridge supports a per-build-tree distribution target and a host-side collector through `cmake/BridgeDistribution.cmake`. The consuming project owns its CPack package names, selected distribution formats, and install components. Each selected packaging target must produce a specific file in the build tree's `dist/` directory.

Register the per-tree target after the packaging targets:

```cmake
include(external/bridge/cmake/BridgeDistribution.cmake)
bridge_add_distribution_target(
    TARGET game_distribution
    OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/dist"
    PLATFORM windows-x64
    VERSION "${PROJECT_VERSION}"
    ARTIFACTS "windows-zip|game.zip" "windows-installer|game.exe"
    DEPENDS game_zip game_installer
)
```

The target verifies each named artifact and writes `dist/manifest.json` with its type, platform, version, relative path, SHA-256 checksum, and `validation: not_run`. `not_run` means that neither Wine nor native runtime tests have been executed as part of this packaging operation. Nothing searches the output directory for files left by previous releases.

A separately configured host-native build tree may then coordinate one or more **other** build trees:

```cmake
bridge_add_distribution_collection(
    TARGET game_distribution
    OUTPUT_DIRECTORY "${PROJECT_SOURCE_DIR}/build/dist"
    EXPECTED_SOURCE "${PROJECT_SOURCE_DIR}"
    BUILD_TREES "${PROJECT_SOURCE_DIR}/build/win32-release|game_distribution"
)
```

The collector calls `cmake --build` for each listed tree and copies only the manifest entries after verifying their checksums. It records platform-specific paths such as `windows-x64/game.zip` in `build/dist/manifest.json`. Each build tree must already be configured; the collector checks the configured source directory (not a Git revision) and refuses to invoke itself recursively. If a requested tree is not configured, a required target fails, or any artifact is missing or corrupt, the collection fails instead of silently skipping it. Bridge does not configure other toolchains, install their prerequisites, or depend on Wine to coordinate distributions.

The coordinator is a build target, not an `ALL` dependency; ordinary application builds require none of the optional distribution environments. Each distribution still requires release validation on its native target platform before shipping.

## Android prototype

Bridge's Android profiles use the NDK's supported CMake toolchain file and deploy headless executables through `adb`. The Android toolchain is intentionally limited to target establishment: NDK, ABI, minimum API, and the NDK toolchain itself. Set `CMAKE_ANDROID_NDK` or `ANDROID_NDK_ROOT` to select the NDK; Bridge does not search installed NDK versions.

SDK and runtime discovery happen separately after the Android target has been established. Bridge uses `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) to locate the SDK and prefers `<sdk>/platform-tools/adb` over a same-named host executable. Host-program fallback searches do not use Android target roots. Without an SDK setting, headless tests can use `adb` on `PATH`, but APK packaging requires an SDK.

Bridge provides `android-x86_64-*` and `android-arm64-*` profiles for every Canon intent. The default Android platform is API 21 and can be overridden with `BRIDGE_ANDROID_PLATFORM`.

The Android runner selects exactly one online device that supports the target ABI. If multiple compatible devices are connected, set `BRIDGE_ANDROID_SERIAL` to the desired adb serial. The runner pushes each headless executable to `/data/local/tmp`, marks it executable, and runs it through `adb shell` while preserving target arguments, stdout, stderr, and exit status.

This first headless runner does not claim to mirror the host process environment or host working-directory contents onto Android. Tests that need environment variables or runtime files need an explicit deployment contract rather than an implicit host-filesystem assumption.

Register native executable tests on Linux, Windows/Wine, and Android through one Bridge API. `ASSET_DIRECTORY` becomes the test working directory on Linux and Windows; Android copies that directory to the device and runs from the deployed copy. `RUNTIME_TARGETS` identifies additional shared libraries to deploy explicitly. On Windows, Bridge also stages CMake-discovered DLLs and supported LLVM-MinGW compiler runtimes alongside the executable after it builds. On Android, Bridge pushes the explicit libraries alongside the executable and sets `LD_LIBRARY_PATH`. No build or configuration happens during CTest.

```cmake
include(external/bridge/cmake/BridgeNativeTest.cmake)
bridge_add_native_test(
    NAME game.unit
    TARGET GameTests
    RUNTIME_TARGETS SDL3::SDL3-shared
    ASSET_DIRECTORY "${CMAKE_BINARY_DIR}/assets"
)
```

Android's native test runner does not provide an Activity or Java-side SDL initialization. Tests requiring that lifecycle need an APK-based harness. A missing asset tree, runtime library, or failed deployment is an error rather than a skipped test.

### SDL3 APK packaging

Bridge can package an existing SDL3 Android shared-library target as a development APK. The consuming project still owns its targets. On Android, SDL requires the application entry point to live in a shared library that is loaded as `libmain.so`; Bridge does not rewrite an executable target into that form.

```cmake
add_library(main SHARED main.cpp)
target_link_libraries(main PRIVATE SDL3::SDL3-shared)

include(external/bridge/cmake/BridgeAndroidPackaging.cmake)
bridge_add_sdl_android_application(
    ALL
    TARGET game_apk
    APPLICATION_ID com.example.game
    APPLICATION_NAME "Example Game"
    MAIN_TARGET main
    SDL_TARGET SDL3::SDL3-shared
    SDL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/external/sdl3"
    ASSET_DIRECTORY "${CMAKE_SOURCE_DIR}/assets"
)
```

`ASSET_DIRECTORY` copies the directory contents into the APK's `assets/` tree. `RUNTIME_TARGETS` can name additional shared-library targets that must ship beside `libmain.so` and `libSDL3.so`. Bridge rejects duplicate packaged targets and fails if two runtime libraries would overwrite the same staged library name. The packaging target exposes its APK path through the `BRIDGE_ANDROID_APK` target property.

The packaging path uses a build-local debug signing key. **Debug signing does not make an APK debuggable.** The optional `DEBUGGABLE` flag to `bridge_add_sdl_android_application()` (also forwarded by `bridge_add_sdl_application()` on Android) sets `android:debuggable="true"`. Without it, Bridge writes `android:debuggable="false"` explicitly, even in a CMake Debug build. Use this flag only for development and test APKs that need `adb shell run-as` to retrieve app-owned files. It is independent of optimization or build type, so an optimized Release benchmark can still use `run-as` without making shipping APKs debuggable. Production signing, store packaging, and multi-ABI distribution remain separate concerns.

The optional `APPLICATION_CATEGORY` argument to `bridge_add_sdl_android_application()` (also forwarded by `bridge_add_sdl_application()` on Android) sets the manifest's `android:appCategory`. It must be one of Android's categories: `accessibility`, `audio`, `game`, `image`, `maps`, `news`, `productivity`, `social`, or `video`. Without it, the manifest declares no category. `bridge_add_sdl_application()` rejects an invalid category on every platform. A game should pass `game`: for apps targeting API 36 or later, Android ignores orientation, resizability, and aspect-ratio restrictions on displays at least 600dp wide, such as tablets and unfolded foldables, and games are exempt.

### Android application runner

Bridge can attach a developer run target to a packaged Android application. The run target depends on the APK, selects a compatible online device when invoked, installs or updates the package, stops any previous instance, and launches its Android activity. Device selection follows the same rule as headless execution: if more than one compatible device is online, set `BRIDGE_ANDROID_SERIAL`.

```cmake
include(external/bridge/cmake/BridgeAndroidRun.cmake)
bridge_add_android_run_target(
    TARGET game_run
    APPLICATION_TARGET game_apk
)
```

Then build and launch with one command:

```sh
cmake --build --preset android-arm64-debug --target game_run
```

The run target is developer tooling, not a test. It may build its APK dependency before installing it. CTest continues to execute only artifacts that the normal build graph has already produced.

### Application icons and Linux desktop integration

Bridge accepts one directory of consumer-rendered icon images. Filenames describe the image content, not the target platform: `opaque/<size>.png` has a solid background, `transparent/<size>.png` has the same standalone artwork with alpha, `adaptive/<size>.png` has transparent Android safe-area artwork, and `monochrome/<size>.png` has Android themed-icon artwork. The opaque and transparent families each contain sizes 16, 24, 32, 48, 64, 72, 96, 128, 144, 192, 256, and 512. The adaptive and monochrome families each contain sizes 108, 162, 216, 324, and 432. Every image must be square, non-interlaced, 8-bit RGB or RGBA PNG with the expected dimensions. Bridge validates all 34 images at configuration time and revalidates resources when generating Windows or Android packages. No image is resized. These packaging helpers require host Python 3 only when icons are requested.

Bridge chooses the family for each platform: Android legacy launcher resources use `opaque/`, Android adaptive foregrounds use `adaptive/`, and Android themed icons use `monochrome/`. Windows executables embed a multi-resolution ICO assembled from a subset of `transparent/` (16, 24, 32, 48, 64, and 256). Linux installs `transparent/` files into the hicolor icon directories, and SDL can load the same transparent artwork for window icons. The `ICON_DIRECTORY` argument always names the root of the complete family tree; platform callers do not select a family themselves.

For Android, add the following arguments to `bridge_add_sdl_android_application`:

```cmake
ICON_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/icons"
ADAPTIVE_ICON_BACKGROUND_COLOR "#070508"
```

Bridge copies `opaque/` images into density-specific legacy launcher resources, creates adaptive foreground and monochrome layers from `adaptive/` and `monochrome/`, supplies the solid background color, and compiles resources with AAPT2. The manifest points to `@mipmap/ic_launcher`. Consumers may omit both icon arguments to build without an application icon; supplying only one is an error.

For a Windows executable, use:

```cmake
include(external/bridge/cmake/BridgeApplicationIcons.cmake)
bridge_embed_win32_application_icon(
    TARGET game_exe
    ICON_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/icons"
)
```

Bridge embeds a multi-resolution ICO assembled from the `transparent/` PNGs in the consumer-owned Windows executable. The public `bridge_embed_win32_application_icon()` macro enables RC at directory scope when needed and then delegates to an implementation function. A Windows project that enables C or C++ normally already has RC enabled. If a project does not, calling the macro from inside a CMake function fails explicitly because RC cannot be enabled for the target's directory from there.

For Linux desktop installation, use:

```cmake
include(external/bridge/cmake/BridgeApplicationIcons.cmake)
bridge_install_linux_desktop_application(
    TARGET game_exe
    APPLICATION_ID com.example.game
    APPLICATION_NAME "Example Game"
    CATEGORIES Game
    ASSET_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/runtime"
    RUNTIME_TARGETS game_runtime SDL3::SDL3
    ICON_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/icons"
)
```

This installs the executable, its explicit shared runtime targets, optional runtime assets, and `com.example.game.desktop` under `share/applications`. Linux hicolor directories receive the `transparent/` PNGs renamed to the application ID. Executable and packaged-library RPATHs are relative to the installation prefix; the host still provides system libraries. `CATEGORIES`, `ASSET_DIRECTORY`, and `RUNTIME_TARGETS` are optional. The application should use the same ID in its window-system metadata so Wayland can associate its window with the desktop entry. `SDL_SetWindowIcon()` remains the consumer's responsibility and is separate from the installed desktop icons.
