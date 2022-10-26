#include "gui.h"
#include <fstream>
#include <vector>
#include <iterator>
#include <map>
#include "stb_rect_pack.h"

extern const FileDescriptor font_table[];

static const float background_colour[] = {0.0f, 0.0f, 0.0f};
static const float dim_colour[] = {0.33f, 0.33f, 0.33f};
static const float normal_colour[] = {0.66f, 0.66f, 0.66f};
static const float bright_colour[] = {1.0f, 1.0f, 0.0f};

static constexpr int FONT_XPADDING = 1;
static constexpr int FONT_YPADDING = 1;
static constexpr int PAGE_WIDTH = 256;
static constexpr int PAGE_HEIGHT = 256;
static int fontSize;
static int fontWidth;
static int fontHeight;
static int fontAscent;
static int fontXOffset;
static float fontScale;

struct TTFData
{
    virtual const uint8_t* getData() = 0;
    virtual ~TTFData() {}

    stbtt_fontinfo font;
};

struct ExternalFont : public TTFData
{
    std::vector<char> data;

    const uint8_t* getData() override
    {
        return (const uint8_t*)&data[0];
    }
};

struct InternalFont : public TTFData
{
    const uint8_t* data;

    const uint8_t* getData() override
    {
        return data;
    }
};

struct FontPage
{
    uint8_t textureData[PAGE_WIDTH * PAGE_HEIGHT];
    stbtt_pack_context ctx;
    GLuint texture;
    bool dirty = false;

    FontPage()
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
            nullptr);
    }

    ~FontPage()
    {
        stbtt_PackEnd(&ctx);
        glDeleteTextures(1, &texture);
    }
};

struct CharData
{
    FontPage* page;
    stbtt_packedchar packData;
};

static std::map<std::pair<uni_t, uint8_t>, std::unique_ptr<CharData>> charData;
static std::deque<std::unique_ptr<FontPage>> fontPages;
static std::unique_ptr<TTFData> fonts[8];

static std::unique_ptr<TTFData> loadFont(const std::string& filename)
{
    auto load = [&]() -> std::unique_ptr<TTFData>
    {
        std::ifstream is(filename, std::ios::in | std::ios::binary);
        if (is)
        {
            auto font = std::make_unique<ExternalFont>();
            font->data = std::vector<char>((std::istreambuf_iterator<char>(is)),
                std::istreambuf_iterator<char>());
            return font;
        }
        else
        {
            const auto* table = font_table;
            while (table->data)
            {
                if (table->name == filename)
                {
                    auto font = std::make_unique<InternalFont>();
                    font->data = table->data;
                    return font;
                }

                table++;
            }
        }
        return loadFont("font_regular");
    };

    auto font = load();
    stbtt_InitFont(&font->font, font->getData(), 0);
    return font;
}

void loadFonts()
{
    fontSize = getIvar("font_size");
    fonts[REGULAR] = loadFont(getSvar("font_regular"));
    fonts[ITALIC] = loadFont(getSvar("font_italic"));
    fonts[BOLD] = loadFont(getSvar("font_bold"));
    fonts[BOLD | ITALIC] = loadFont(getSvar("font_bolditalic"));

    auto& font = fonts[REGULAR];

    fontScale = stbtt_ScaleForPixelHeight(&font->font, fontSize);
    int ascent, descent, lineGap;
    stbtt_GetFontVMetrics(&font->font, &ascent, &descent, &lineGap);
    fontAscent = ascent * fontScale;
    fontHeight = (ascent - descent + lineGap) * fontScale + FONT_XPADDING;

    int advance, bearing;
    stbtt_GetCodepointHMetrics(&font->font, 'M', &advance, &bearing);
    fontWidth = advance * fontScale + FONT_YPADDING;
    fontXOffset = bearing * fontScale;
}

void flushFontCache()
{
    charData.clear();
    fontPages.clear();
}

void getFontSize(int& width, int& height)
{
    width = fontWidth;
    height = fontHeight;
}

static void renderTtfChar(uni_t c, uint8_t attrs, float x, float y)
{
    int style = REGULAR;
    if (attrs & DPY_BOLD)
        style |= BOLD;
    if (attrs & DPY_ITALIC)
        style |= ITALIC;

    auto& it = charData[std::pair(c, style)];
    if (!it)
    {
        if (fontPages.empty())
            fontPages.push_back(std::make_unique<FontPage>());

        auto charData = std::make_unique<CharData>();
        auto* page = fontPages.back().get();
        auto& font = fonts[style];
        if (!font)
            return;

        auto render = [&]() -> int
        {
            stbtt_pack_range range;
            range.first_unicode_codepoint_in_range = c;
            range.array_of_unicode_codepoints = nullptr;
            range.num_chars = 1;
            range.font_size = STBTT_POINT_SIZE(fontSize);
            range.chardata_for_range = &charData->packData;
            range.chardata_for_range->x0 = range.chardata_for_range->y0 =
                range.chardata_for_range->x1 = range.chardata_for_range->y1 = 0;

            stbrp_rect rect;

            int n = stbtt_PackFontRangesGatherRects(
                &page->ctx, &font->font, &range, 1, &rect);
            stbtt_PackFontRangesPackRects(&page->ctx, &rect, n);

            return stbtt_PackFontRangesRenderIntoRects(
                &page->ctx, &font->font, &range, 1, &rect);
        };

        // First try rendering into the current page. If that fails, the
        // page is full and we need a new one.

        if (!render())
        {
            fontPages.push_back(std::make_unique<FontPage>());
            page = fontPages.back().get();
            if (!render())
            {
                printf("Unrenderable codepoint %d\n", c);
                fontPages.pop_back();
                return;
            }
        }

        charData->page = page;
        page->dirty = true;

        it = std::move(charData);
    }

    auto* page = it->page;
    glBindTexture(GL_TEXTURE_2D, page->texture);
    if (page->dirty)
    {
        glTexImage2D(GL_TEXTURE_2D,
            0,
            GL_ALPHA,
            PAGE_WIDTH,
            PAGE_HEIGHT,
            0,
            GL_ALPHA,
            GL_UNSIGNED_BYTE,
            &page->textureData[0]);
        page->dirty = false;
    }

    stbtt_aligned_quad q;
    stbtt_GetPackedQuad(
        &it->packData, PAGE_WIDTH, PAGE_HEIGHT, 0, &x, &y, &q, true);

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

void printChar(uni_t c, uint8_t attrs, float x, float y)
{
    /* Draw background. */

    glDisable(GL_BLEND);
    const float* colour;
    if (attrs & DPY_REVERSE)
    {
        if (attrs & DPY_BRIGHT)
            colour = bright_colour;
        else if (attrs & DPY_DIM)
            colour = dim_colour;
        else
            colour = normal_colour;
        glColor3fv(colour);

        glRectf(x, y, x + fontWidth, y + fontHeight);
    }

    /* Draw foreground. */

    if (attrs & DPY_REVERSE)
        colour = background_colour;
    else if (attrs & DPY_BRIGHT)
        colour = bright_colour;
    else if (attrs & DPY_DIM)
        colour = dim_colour;
    else
        colour = normal_colour;
    glColor3fv(colour);

    int w = fontWidth;
    int h = fontHeight;
    int w2 = fontWidth / 2;
    int h2 = fontHeight / 2;
    switch (c)
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
            glBegin(GL_LINES);
            glVertex2i(x, y + 2);
            glVertex2i(x + w, y + 2);
            glEnd();
            break;

        default:
            glEnable(GL_BLEND);
            renderTtfChar(c, attrs, x + fontXOffset, y + fontAscent);
    }
}
