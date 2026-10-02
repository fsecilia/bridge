// SPDX-License-Identifier: MIT

/// \file
/// \copyright Copyright (C) 2026 Frank Secilia

#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string_view>

namespace {

auto testArguments(int argc, char const* const* argv) -> int
{
    if (argc != 3) {
        return 1;
    }

    return std::string_view{argv[2]} == "two words" ? 0 : 1;
}

auto testEnvironment() -> int
{
    auto const* const value = std::getenv("BRIDGE_SPECIMEN_VALUE");
    return value != nullptr && std::string_view{value} == "from-ctest" ? 0 : 1;
}

auto testWorkingDirectory(int argc, char const* const* argv) -> int
{
    if (argc != 3) {
        return 1;
    }

    return std::filesystem::current_path() == std::filesystem::path{argv[2]} ? 0 : 1;
}

auto testOutput() -> int
{
    std::cout << "bridge specimen output\n";
    return 0;
}

auto testFailure() -> int
{
    return 7;
}

} // namespace

int main(int argc, char const* const* argv)
{
    if (argc < 2) {
        return 1;
    }

    auto const mode = std::string_view{argv[1]};
    if (mode == "arguments") {
        return testArguments(argc, argv);
    }
    if (mode == "environment") {
        return testEnvironment();
    }
    if (mode == "working-directory") {
        return testWorkingDirectory(argc, argv);
    }
    if (mode == "output") {
        return testOutput();
    }
    if (mode == "failure") {
        return testFailure();
    }

    return 1;
}
