// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
    if (argc != 2 || std::strlen(argv[1]) >= sizeof(sockaddr_un::sun_path)) {
        std::fprintf(stderr, "usage: bridge_win32_wayland_socket_fixture <short-socket-path>\n");
        return 1;
    }

    sockaddr_un address{};
    address.sun_family = AF_UNIX;
    std::strcpy(address.sun_path, argv[1]);

    int const descriptor = socket(AF_UNIX, SOCK_STREAM, 0);
    if (descriptor < 0) {
        std::fprintf(stderr, "socket: %s\n", std::strerror(errno));
        return 1;
    }
    if (bind(descriptor, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0) {
        std::fprintf(stderr, "bind: %s\n", std::strerror(errno));
        close(descriptor);
        return 1;
    }
    if (close(descriptor) != 0) {
        std::fprintf(stderr, "close: %s\n", std::strerror(errno));
        return 1;
    }
    return 0;
}
