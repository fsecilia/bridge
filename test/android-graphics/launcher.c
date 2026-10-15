// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

// bridge_add_sdl_application() takes a desktop launcher on every platform, so
// a call written for Android still configures elsewhere. This specimen only
// builds for Android, where the APK loads the main library directly, so this
// launcher is never compiled.

int main(void) {
    return 1;
}
