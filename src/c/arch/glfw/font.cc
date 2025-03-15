#include "globals.h"
#include "gui.h"
#include "stb_rect_pack.h"
#include "stb_truetype.h"

#include "font_table.h"

extern const FileDescriptor font_table[];

#define FONT_XPADDING 1
#define FONT_YPADDING 2
#define PAGE_WIDTH 256
#define PAGE_HEIGHT 256

class Font
{
public:
    virtual ~Font() {};

public:
    uint8_t* data;
    stbtt_fontinfo info;
};

class StaticFont : public Font
{
public:
    ~StaticFont() {}
};

class DynamicFont : public Font
{
public:
    DynamicFont(FILE* fp)
    {
        (void)fseek(fp, 0, SEEK_END);
        unsigned len = ftell(fp);
        (void)fseek(fp, 0, SEEK_SET);

        data = new uint8_t[len];
        fread(data, 1, len, fp);
    }

    ~DynamicFont()
    {
        delete[] data;
    }
};

struct Page
{
    uint8_t textureData[PAGE_WIDTH * PAGE_HEIGHT];
    stbtt_pack_context ctx;
    GLuint texture;

    Page()
    {
        glGenTextures(1, &texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        stbtt_PackBegin(&ctx,
            &textureData[0],
            PAGE_WIDTH,
            PAGE_HEIGHT,
            PAGE_WIDTH,
            1,
            NULL);
    }

    ~Page()
    {
        stbtt_PackEnd(&ctx);
        glDeleteTextures(1, &texture);
    }
};

struct CharData
{
    uint32_t key;
    Page* page;
    stbtt_packedchar packData;
};

int fontWidth;
int fontHeight;
static int fontSize;
static int fontAscent;
static int fontXOffset;
static float fontScale;
static std::map<int, std::unique_ptr<Font>> fonts;
static std::vector<std::unique_ptr<Page>> pages;
static std::map<uint32_t, CharData> chardata;

static std::unique_ptr<Font> loadFont(const char* filename, int defaultfont)
{
    std::unique_ptr<Font> font;
    FILE* fp = fopen(filename, "rb");
    if (fp)
    {
        font = std::make_unique<DynamicFont>(fp);
        fclose(fp);
    }
    else
    {
        font = std::make_unique<StaticFont>();
        font->data = (uint8_t*)&font_table[defaultfont].data[0];
    }

    stbtt_InitFont(&font->info, font->data, 0);
    return font;
}

void loadFonts()
{
    fontSize = get_ivar("font_size");
    fonts[REGULAR] = loadFont(get_svar("font_regular"), 0);
    fonts[ITALIC] = loadFont(get_svar("font_italic"), 1);
    fonts[BOLD] = loadFont(get_svar("font_bold"), 2);
    fonts[BOLD | ITALIC] = loadFont(get_svar("font_bolditalic"), 3);

    auto& font = fonts[REGULAR];

    fontScale = stbtt_ScaleForPixelHeight(&font->info, fontSize);
    int ascent, descent, lineGap;
    stbtt_GetFontVMetrics(&font->info, &ascent, &descent, &lineGap);
    fontAscent = ascent * fontScale;
    fontHeight = (ascent - descent + lineGap) * fontScale + FONT_XPADDING;

    int advance, bearing;
    stbtt_GetCodepointHMetrics(&font->info, 'M', &advance, &bearing);
    fontWidth = advance * fontScale + FONT_YPADDING;
    fontXOffset = bearing * fontScale;
}

void unloadFonts()
{
    fonts.clear();
}

static Page* addPage()
{
    pages.push_back(std::make_unique<Page>());
    return pages.back().get();
}

void flushFontCache()
{
    pages.clear();
    chardata.clear();
}

static int rawRender(Font& font, Page* page, CharData& cd, uni_t c)
{
    stbtt_pack_range range;
    range.first_unicode_codepoint_in_range = c;
    range.array_of_unicode_codepoints = NULL;
    range.num_chars = 1;
    range.font_size = STBTT_POINT_SIZE(fontSize);
    range.chardata_for_range = &cd.packData;
    range.chardata_for_range->x0 = range.chardata_for_range->y0 =
        range.chardata_for_range->x1 = range.chardata_for_range->y1 = 0;

    stbrp_rect rect;

    int n = stbtt_PackFontRangesGatherRects(
        &page->ctx, &font.info, &range, 1, &rect);
    stbtt_PackFontRangesPackRects(&page->ctx, &rect, n);

    return stbtt_PackFontRangesRenderIntoRects(
        &page->ctx, &font.info, &range, 1, &rect);
}

static void renderTtfChar(uni_t c, uint8_t attrs, float x, float y)
{
    int style = REGULAR;
    if (attrs & DPY_BOLD)
        style |= BOLD;
    if (attrs & DPY_ITALIC)
        style |= ITALIC;

    uint32_t key = c | (style << 24);
    auto [it, inserted] = chardata.emplace(key, CharData{});
    auto& cd = it->second;
    if (inserted)
    {
        Page* page = pages.empty() ? addPage() : pages.back().get();

        auto& font = fonts[style];
        if (!font)
            return;

        cd.key = key;

        /* First try rendering into the current page. If that fails, the
         * page is full and we need a new one. */

        if (!rawRender(*font, page, cd, c))
        {
            page = addPage();
            if (!rawRender(*font, page, cd, c))
            {
                printf("Unrenderable codepoint %d\n", c);
                pages.pop_back();
                return;
            }
        }
        cd.page = page;

        /* Now we have a valid rendered glyph, but we need to update the
         * texture. */

        glBindTexture(GL_TEXTURE_2D, page->texture);
        glTexImage2D(GL_TEXTURE_2D,
            0,
            GL_ALPHA,
            PAGE_WIDTH,
            PAGE_HEIGHT,
            0,
            GL_ALPHA,
            GL_UNSIGNED_BYTE,
            &page->textureData[0]);
    }

    stbtt_aligned_quad q;
    stbtt_GetPackedQuad(
        &cd.packData, PAGE_WIDTH, PAGE_HEIGHT, 0, &x, &y, &q, true);

    glEnable(GL_BLEND);
    glBindTexture(GL_TEXTURE_2D, cd.page->texture);
    glBegin(GL_QUADS);
    glTexCoord2f(q.s0, q.t0);
    glVertex2f(q.x0, q.y0);
    glTexCoord2f(q.s1, q.t0);
    glVertex2f(q.x1, q.y0);
    glTexCoord2f(q.s1, q.t1);
    glVertex2f(q.x1, q.y1);
    glTexCoord2f(q.s0, q.t1);
    glVertex2f(q.x0, q.y1);
    glEnd();
}

void printChar(const cell_t* cell, float x, float y)
{
    GLfloat* fg = (GLfloat*)&cell->fg;
    GLfloat* bg = (GLfloat*)&cell->bg;
    GLfloat nfg[3];
    if (cell->attr & DPY_DIM)
    {
        constexpr float ALPHA = 0.4;
        for (int i = 0; i < 3; i++)
            nfg[i] = fg[i] * ALPHA + bg[i] * (1.0 - ALPHA);
        fg = &nfg[0];
    }

    /* Draw background. */

    glDisable(GL_BLEND);
    glColor3fv((cell->attr & DPY_REVERSE) ? fg : bg);
    glRectf(x, y, x + fontWidth, y + fontHeight);

    /* Draw foreground. */

    glColor3fv((cell->attr & DPY_REVERSE) ? bg : fg);

    int w = fontWidth;
    int h = fontHeight;
    int w2 = fontWidth / 2;
    int h2 = fontHeight / 2;
    switch (cell->c)
    {
        case 32:
        case 160: /* non-breaking space */
            break;

        case 0x2500: /* ─ */
        case 0x2501: /* ━ */
            glBegin(GL_LINES);
            glVertex2i(x + 0, y + h2);
            glVertex2i(x + w, y + h2);
            glEnd();
            break;

        case 0x2502: /* │ */
        case 0x2503: /* ┃ */
            glBegin(GL_LINES);
            glVertex2i(x + w2, y + 0);
            glVertex2i(x + w2, y + h);
            glEnd();
            break;

        case 0x250c: /* ┌ */
        case 0x250d: /* ┍ */
        case 0x250e: /* ┎ */
        case 0x250f: /* ┏ */
            glBegin(GL_LINES);
            glVertex2i(x + w2, y + h2);
            glVertex2i(x + w2, y + h);

            glVertex2i(x + w2, y + h2);
            glVertex2i(x + w, y + h2);
            glEnd();
            break;

        case 0x2510: /* ┐ */
        case 0x2511: /* ┑ */
        case 0x2512: /* ┒ */
        case 0x2513: /* ┓ */
            glBegin(GL_LINES);
            glVertex2i(x + w2, y + h2);
            glVertex2i(x + w2, y + h);

            glVertex2i(x + 0, y + h2);
            glVertex2i(x + w2, y + h2);
            glEnd();
            break;

        case 0x2514: /* └ */
        case 0x2515: /* ┕ */
        case 0x2516: /* ┖ */
        case 0x2517: /* ┗ */
            glBegin(GL_LINES);
            glVertex2i(x + w2, y + 0);
            glVertex2i(x + w2, y + h2);

            glVertex2i(x + w2, y + h2);
            glVertex2i(x + w, y + h2);
            glEnd();
            break;

        case 0x2518: /* ┘ */
        case 0x2519: /* ┙ */
        case 0x251a: /* ┚ */
        case 0x251b: /* ┛ */
            glBegin(GL_LINES);
            glVertex2i(x + w2, y + 0);
            glVertex2i(x + w2, y + h2);

            glVertex2i(x + 0, y + h2);
            glVertex2i(x + w2, y + h2);
            glEnd();
            break;

        case 0x2551: /* ║ */
            glBegin(GL_LINES);
            glVertex2i(x + w2 - 1, y);
            glVertex2i(x + w2 - 1, y + h);

            glVertex2i(x + w2 + 1, y);
            glVertex2i(x + w2 + 1, y + h);
            glEnd();
            break;

        case 0x2594: /* ▔ */
            glBegin(GL_POLYGON);
            glVertex2i(x, y + 0);
            glVertex2i(x + w, y + 0);
            glVertex2i(x + w, y + 2);
            glVertex2i(x, y + 2);
            glEnd();
            break;

        case 0x2581: /* ▁ */
            glBegin(GL_POLYGON);
            glVertex2i(x + w, y + h - 2);
            glVertex2i(x, y + h - 2);
            glVertex2i(x, y + h);
            glVertex2i(x + w, y + h);
            glEnd();
            break;

        case 0x25bc: /* ▼ */
            glBegin(GL_POLYGON);
            glVertex2i(x, y + h - w - 1);
            glVertex2i(x + w / 2, y + h - 1);
            glVertex2i(x + w, y + h - w - 1);
            glEnd();
            break;

        case 0x25be: /* ▾ */
            glBegin(GL_POLYGON);
            glVertex2i(x + w * 1 / 3, y + h * 2 / 3);
            glVertex2i(x + w / 2, y + h - 1);
            glVertex2i(x + w * 2 / 3, y + h * 2 / 3);
            glEnd();
            break;

        case 0x25e4: /* ◤ */
            glBegin(GL_POLYGON);
            glVertex2i(x, y + h - w - 1);
            glVertex2i(x + w, y + h - w - 1);
            glVertex2i(x, y + h - 1);
            glEnd();
            break;

        case 0x25e5: /* ◥ */
            glBegin(GL_POLYGON);
            glVertex2i(x, y + h - w - 1);
            glVertex2i(x + w, y + h - w - 1);
            glVertex2i(x + w, y + h - 1);
            glEnd();
            break;

        case 0x25b3: /* △ */
            glBegin(GL_LINE_LOOP);
            glVertex2i(x, y + w);
            glVertex2i(x + w / 2, y);
            glVertex2i(x + w, y + w);
            glEnd();
            break;

        case 0x25ff: /* ◿ */
            glBegin(GL_LINE_LOOP);
            glVertex2i(x + w, y);
            glVertex2i(x + w, y + w);
            glVertex2i(x, y + w);
            glEnd();
            break;

        case 0x25fa: /* ◺ */
            glBegin(GL_LINE_LOOP);
            glVertex2i(x, y);
            glVertex2i(x + w, y + w);
            glVertex2i(x, y + w);
            glEnd();
            break;

        case 0x25c7: /* ◇ */
        {
            int d = w / 2;
            glBegin(GL_LINE_LOOP);
            glVertex2i(x, y + h / 2);
            glVertex2i(x + d, y + h / 2 + d);
            glVertex2i(x + 2 * d, y + h / 2);
            glVertex2i(x + d, y + h / 2 - d);
            glEnd();
            break;
        }

        case 0x2080: /* ₀ */
        case 0x2081: /* ₁ */
        case 0x2082: /* ₂ */
        case 0x2083: /* ₃ */
        case 0x2084: /* ₄ */
        case 0x2085: /* ₅ */
        case 0x2086: /* ₆ */
        case 0x2087: /* ₇ */
        case 0x2088: /* ₈ */
        case 0x2089: /* ₉ */
        {
            int xx = x + w / 2;
            int yy = y + h;
            glPushMatrix();
            glTranslatef(xx, yy, 0);
            glScalef(0.7, 0.7, 0.7);
            glTranslatef(-xx, -yy, 0);
            renderTtfChar(cell->c - 0x2080 + '0',
                cell->attr,
                x + fontXOffset,
                y + fontAscent);
            glPopMatrix();
            break;
        }

        default:
            renderTtfChar(cell->c, cell->attr, x + fontXOffset, y + fontAscent);
    }

    if (cell->attr & DPY_UNDERLINE)
    {
        glDisable(GL_BLEND);
        glBegin(GL_LINES);
        glVertex2i(x + fontXOffset, y + fontAscent + 1);
        glVertex2i(x + fontXOffset + fontWidth, y + fontAscent + 1);
        glEnd();
    }
}
