// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

#include <cstddef>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <ranges>

int main(int argc, char const* const* argv) {
    auto const arguments = std::views::counted(argv, static_cast<std::ptrdiff_t>(argc));
    if (argc != 3 || std::strcmp(arguments[1], "two words") != 0 ||
        std::strcmp(arguments[2], "single'quote") != 0) {
        std::cerr << "Bridge native test: arguments were changed\n";
        return 1;
    }

    auto* const input = std::fopen("fixtures/expected.txt", "rb");
    if (input == nullptr) {
        std::cerr << "Bridge native test: asset directory is unavailable\n";
        return 1;
    }
    char bytes[32]{};
    auto const count = std::fread(bytes, 1, sizeof(bytes), input);
    if (std::fclose(input) != 0 || count != std::strlen("Bridge native asset\n") ||
        std::strcmp(bytes, "Bridge native asset\n") != 0) {
        std::cerr << "Bridge native test: asset content changed\n";
        return 1;
    }
    return 0;
}
