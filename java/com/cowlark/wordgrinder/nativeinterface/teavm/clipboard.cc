#include "clipboard.h"
#include "clip.h"
#include <limits>
#include <memory>
#include <new>
#include <stdexcept>
#include <vector>

static clip::format wordgrinderFormat;

struct ClipboardData
{
    bool available = false;
    std::vector<char> bytes;
};

struct ClipboardSnapshot
{
    ClipboardData formats[2];
};

void wg_clipboard_init(void)
{
    wordgrinderFormat = clip::register_format("com.cowlark.wordgrinder.wgtext");
}

void wg_clipboard_clear(void)
{
    clip::clear();
}

static void getData(clip::lock& lock, clip::format format, ClipboardData& result)
{
    if (!lock.is_convertible(format))
        return;
    size_t length = lock.get_data_length(format);
    if (length > static_cast<size_t>(std::numeric_limits<int32_t>::max()))
        throw std::length_error("clipboard data exceeds Java array size");
    result.bytes.resize(length);
    if (length && !lock.get_data(format, result.bytes.data(), length))
        return;
    // Match the original Lua API: remove one trailing NUL, preserving embedded NULs.
    if (!result.bytes.empty() && result.bytes.back() == 0)
        result.bytes.pop_back();
    result.available = true;
}

void* wg_clipboard_get(void)
{
    try
    {
        auto snapshot = std::make_unique<ClipboardSnapshot>();
        clip::lock lock;
        getData(lock, clip::text_format(), snapshot->formats[0]);
        getData(lock, wordgrinderFormat, snapshot->formats[1]);
        return snapshot.release();
    }
    catch (const std::bad_alloc&) { return nullptr; }
    catch (const std::length_error&) { return nullptr; }
}

int32_t wg_clipboard_length(void* snapshot, int32_t format)
{
    const auto& data = static_cast<ClipboardSnapshot*>(snapshot)->formats[format];
    return data.available ? static_cast<int32_t>(data.bytes.size()) : -1;
}

const char* wg_clipboard_data(void* snapshot, int32_t format)
{
    return static_cast<ClipboardSnapshot*>(snapshot)->formats[format].bytes.data();
}

void wg_clipboard_release(void* snapshot)
{
    delete static_cast<ClipboardSnapshot*>(snapshot);
}

void wg_clipboard_set(const char* text, int32_t text_length, const char* data, int32_t data_length)
{
    clip::lock lock;
    lock.clear();
    if (text_length >= 0)
        lock.set_data(clip::text_format(), text, static_cast<size_t>(text_length));
    if (data_length >= 0)
        lock.set_data(wordgrinderFormat, data, static_cast<size_t>(data_length));
}
