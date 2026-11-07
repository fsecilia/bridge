#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -euo pipefail

launcher=$1
scenario=$2
fixture=$3
rm -rf -- "$fixture"
mkdir -p -- "$fixture/bin"

fail() {
    printf 'Windows setup test %s: %s\n' "$scenario" "$1" >&2
    if [[ -f "$fixture/stdout" ]]; then cat "$fixture/stdout" >&2; fi
    if [[ -f "$fixture/stderr" ]]; then cat "$fixture/stderr" >&2; fi
    exit 1
}

# Limit PATH to test tools. In particular, the fake sudo never invokes pacman.
bin=$fixture/bin
ln -s "$(command -v bash)" "$bin/bash"
ln -s "$(command -v cat)" "$bin/cat"
ln -s "$(command -v dirname)" "$bin/dirname"
cat > "$bin/uname" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "${BRIDGE_TEST_HOST:-Linux}"
MOCK
cat > "$bin/sudo" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$BRIDGE_TEST_SUDO_LOG"
MOCK
for tool in pacman cmake ninja python x86_64-w64-mingw32-clang++ x86_64-w64-mingw32-windres makensis; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/$tool"
done
chmod +x "$bin"/{uname,sudo,pacman,cmake,ninja,python,x86_64-w64-mingw32-clang++,x86_64-w64-mingw32-windres,makensis}

case "$scenario" in
    arch|wine|missing-tool|missing-pacman|bad-argument)
        printf 'ID=arch\n' > "$fixture/os-release" ;;
    derivative)
        printf 'ID=examplelinux\nID_LIKE="debian arch"\n' > "$fixture/os-release" ;;
    cachyos)
        printf 'ID=cachyos\n' > "$fixture/os-release" ;;
    unsupported)
        printf 'ID=ubuntu\nID_LIKE=debian\n' > "$fixture/os-release" ;;
    lookalike)
        printf 'ID=archery\nID_LIKE=march\n' > "$fixture/os-release" ;;
    missing-release|nonlinux|help)
        printf 'ID=arch\n' > "$fixture/os-release" ;;
    *) fail "Unknown test scenario" ;;
esac

args=()
case "$scenario" in
    wine) args=(--with-wine) ;;
    bad-argument) args=(--unexpected) ;;
    help) args=(--help) ;;
esac
case "$scenario" in
    missing-tool) rm "$bin/makensis" ;;
    missing-pacman) rm "$bin/pacman" ;;
    missing-release|help) rm "$fixture/os-release" ;;
    nonlinux) export BRIDGE_TEST_HOST=Darwin ;;
esac

if env PATH="$bin" BRIDGE_OS_RELEASE_FILE="$fixture/os-release" \
    BRIDGE_TEST_HOST="${BRIDGE_TEST_HOST:-Linux}" BRIDGE_TEST_SUDO_LOG="$fixture/sudo-args" \
    "$(command -v bash)" "$launcher" "${args[@]}" > "$fixture/stdout" 2> "$fixture/stderr"; then
    result=0
else
    result=$?
fi

case "$scenario" in
    arch|wine|derivative|cachyos)
        [[ $result == 0 ]] || fail "Expected successful Arch setup, got status $result"
        [[ -f "$fixture/sudo-args" ]] || fail "Arch setup did not invoke sudo"
        printf '%s\n' pacman -Syu --needed cmake ninja python llvm-mingw nsis > "$fixture/expected"
        if [[ "$scenario" == wine ]]; then printf '%s\n' wine >> "$fixture/expected"; fi
        cmp -s "$fixture/expected" "$fixture/sudo-args" || fail "Unexpected pacman arguments"
        grep -q 'prerequisites are available' "$fixture/stdout" || fail "Missing tool validation success"
        ;;
    unsupported|lookalike)
        [[ $result != 0 ]] || fail "Unsupported distribution unexpectedly succeeded"
        grep -q 'Unsupported Linux distribution' "$fixture/stderr" || fail "Missing distribution diagnostic"
        [[ ! -e "$fixture/sudo-args" ]] || fail "Unexpected package-manager invocation"
        ;;
    missing-release)
        [[ $result != 0 ]] || fail "Missing os-release unexpectedly succeeded"
        grep -q 'Cannot read Linux distribution metadata' "$fixture/stderr" || fail "Missing metadata diagnostic"
        [[ ! -e "$fixture/sudo-args" ]] || fail "Unexpected package-manager invocation"
        ;;
    nonlinux)
        [[ $result != 0 ]] || fail "Non-Linux host unexpectedly succeeded"
        grep -q 'Linux hosts only' "$fixture/stderr" || fail "Missing host diagnostic"
        [[ ! -e "$fixture/sudo-args" ]] || fail "Unexpected package-manager invocation"
        ;;
    missing-pacman)
        [[ $result != 0 ]] || fail "Missing pacman unexpectedly succeeded"
        grep -q 'Arch setup requires pacman and sudo' "$fixture/stderr" || fail "Missing pacman diagnostic"
        [[ ! -e "$fixture/sudo-args" ]] || fail "Unexpected package-manager invocation"
        ;;
    missing-tool)
        [[ $result != 0 ]] || fail "Missing compiler tool unexpectedly succeeded"
        grep -q 'Required tool was not installed on PATH: makensis' "$fixture/stderr" || fail "Missing tool diagnostic"
        ! grep -q 'prerequisites are available' "$fixture/stdout" || fail "Incorrect success claim"
        ;;
    bad-argument)
        [[ $result == 2 ]] || fail "Unexpected argument should produce status 2, got $result"
        grep -q 'Unknown argument: --unexpected' "$fixture/stderr" || fail "Missing argument diagnostic"
        [[ ! -e "$fixture/sudo-args" ]] || fail "Unexpected package-manager invocation"
        ;;
    help)
        [[ $result == 0 ]] || fail "Help should work without os-release, got $result"
        grep -q 'Usage: scripts/setup-windows-build-deps.sh' "$fixture/stdout" || fail "Missing help output"
        [[ ! -e "$fixture/sudo-args" ]] || fail "Unexpected package-manager invocation"
        ;;
esac

printf 'Windows setup test %s passed\n' "$scenario"
