// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Frank Secilia

#include <stdbool.h>

#include <GLES2/gl2.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        SDL_Log("Bridge graphics SDL_Init failed: %s", SDL_GetError());
        return 1;
    }

    if (!SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES)
        || !SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2)
        || !SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0)) {
        SDL_Log("Bridge graphics GL attribute setup failed: %s", SDL_GetError());
        SDL_Quit();
        return 2;
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
        return 3;
    }

    SDL_GLContext context = SDL_GL_CreateContext(window);
    if (context == NULL) {
        SDL_Log("Bridge graphics context creation failed: %s", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 4;
    }

    glClearColor(0.08F, 0.45F, 0.78F, 1.0F);
    glClear(GL_COLOR_BUFFER_BIT);
    if (glGetError() != GL_NO_ERROR) {
        SDL_Log("Bridge graphics GLES clear failed");
        SDL_GL_DestroyContext(context);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 5;
    }
    if (!SDL_GL_SwapWindow(window)) {
        SDL_Log("Bridge graphics buffer swap failed: %s", SDL_GetError());
        SDL_GL_DestroyContext(context);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 6;
    }
    SDL_Log("bridge android graphics ready");

    bool running = true;
    while (running) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                running = false;
            }
        }
        SDL_Delay(16);
    }

    SDL_GL_DestroyContext(context);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
