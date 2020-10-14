#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#if defined WIN32
#include <windows.h>
#include <fileapi.h>
#endif

/* Lua really, really wants to use tmpnam, but gcc really, really doesn't want
 * you to use tmpnam. So, we have to hack around it. Note that this doesn't
 * actually fix the problem, because the 'problem' is inherent in trying to
 * generate a filename without generating the file, so all this achieves is to
 * remove the warning. Being able to silence it would be just as effective and
 * much easier. Ho hum. */

int emu_tmpnam(char* buffer)
{
	#if defined WIN32
		int len = GetTempPathA(PATH_MAX, buffer);
		if (!len || (len > PATH_MAX))
			return 1;
	#else
		const char* tmpdir = getenv("TMPDIR");
		if (!tmpdir)
			tmpdir = "/tmp";
		strcpy(buffer, tmpdir);
		strcat(buffer, "/");
	#endif

	strcat(buffer, "wg_XXXXXX");
	int fd = mkstemp(buffer);
	if (fd != -1)
		close(fd);
	return fd == -1;
}
