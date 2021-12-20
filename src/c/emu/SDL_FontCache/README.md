# SDL_FontCache
A generic font caching C library with loading and rendering support for SDL.

SDL_FontCache loads, caches, and renders TrueType fonts using SDL_ttf.  
It fully supports UTF-8 strings and includes some utility functions for manipulating them.

An example using SDL_Renderer:

```
FC_Font* font = FC_CreateFont();  
FC_LoadFont(font, renderer, "fonts/FreeSans.ttf", 20, FC_MakeColor(0,0,0,255), TTF_STYLE_NORMAL);  

...

FC_Draw(font, renderer, 0, 0, "This is %s.\n It works.", "example text"); 
 
...

FC_FreeFont(font);
```
