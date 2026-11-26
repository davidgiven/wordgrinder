/* C interface to platform system operations, for TeaVM-generated code. */
#ifndef WORDGRINDER_SYSTEM_H
#define WORDGRINDER_SYSTEM_H

#ifdef __cplusplus
extern "C" {
#endif

/* Returns a static Windows executable path; do not free. Returns NULL elsewhere or on failure. */
char* wg_system_get_executable_path(void);

#ifdef __cplusplus
}
#endif

#endif
