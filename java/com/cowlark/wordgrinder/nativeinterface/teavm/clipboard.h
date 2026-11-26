#ifndef WORDGRINDER_CLIPBOARD_H
#define WORDGRINDER_CLIPBOARD_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

void wg_clipboard_init(void);
void wg_clipboard_clear(void);
/* Snapshot owns both formats copied under one clipboard lock. */
void* wg_clipboard_get(void);
int32_t wg_clipboard_length(void* snapshot, int32_t format);
const char* wg_clipboard_data(void* snapshot, int32_t format);
void wg_clipboard_release(void* snapshot);
void wg_clipboard_set(const char* text, int32_t text_length, const char* data, int32_t data_length);

#ifdef __cplusplus
}
#endif
#endif
