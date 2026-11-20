#ifndef WORDGRINDER_CSTRING_PROBE_H
#define WORDGRINDER_CSTRING_PROBE_H

/* Initialise the deterministic character encoding used by the native fixture. */
void wg_cstring_test_init(void);
void wg_cstring_test_check(const char* text, int example);
void wg_cstring_test_executable_path(const char* path);

#endif
