// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

#include <stdbool.h>

#include <GLES2/gl2.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

bool bridgeAndroidGraphicsRuntimeReady(void);

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    if (!bridgeAndroidGraphicsRuntimeReady()) {
        SDL_Log("Bridge graphics runtime library check failed");
        return 1;
    }

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        SDL_Log("Bridge graphics SDL_Init failed: %s", SDL_GetError());
        return 2;
    }

    size_t assetSize = 0;
    char *asset = SDL_LoadFile("bridge-asset.txt", &assetSize);
    if (asset == NULL) {
        SDL_Log("Bridge graphics asset load failed: %s", SDL_GetError());
        SDL_Quit();
        return 3;
    }
    static const char expectedAsset[] = "bridge android asset\n";
    if (assetSize != sizeof(expectedAsset) - 1
        || SDL_memcmp(asset, expectedAsset, sizeof(expectedAsset) - 1) != 0) {
        SDL_Log("Bridge graphics asset contents are invalid");
        SDL_free(asset);
        SDL_Quit();
        return 4;
    }
    SDL_free(asset);

    if (!SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES)
        || !SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2)
        || !SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0)) {
        SDL_Log("Bridge graphics GL attribute setup failed: %s", SDL_GetError());
        SDL_Quit();
        return 5;
    }

    SDL_Window *window = SDL_CreateWindow(
        "Bridge Android Graphics",
        640,
        480,
        SDL_WINDOW_OPENGL
    );
    if (window == NULL) {
        SDL_Log("Bridge graphics window creation failed: %s", SDL_GetError());
        SDL_Quit();
        return 6;
    }

    SDL_GLContext context = SDL_GL_CreateContext(window);
    if (context == NULL) {
        SDL_Log("Bridge graphics context creation failed: %s", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 7;
    }

    glClearColor(0.08F, 0.45F, 0.78F, 1.0F);

    int result = 0;
    bool ready = false;
    bool running = true;
    while (running) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                running = false;
            }
        }
        if (!running) {
            break;
        }

        glClear(GL_COLOR_BUFFER_BIT);
        if (glGetError() != GL_NO_ERROR) {
            SDL_Log("Bridge graphics GLES clear failed");
            result = 8;
            break;
        }
        if (!SDL_GL_SwapWindow(window)) {
            SDL_Log("Bridge graphics buffer swap failed: %s", SDL_GetError());
            result = 9;
            break;
        }

        if (!ready) {
            SDL_Log("bridge android graphics ready");
            ready = true;
        }

        SDL_Delay(16);
    }

    SDL_GL_DestroyContext(context);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return result;
}
