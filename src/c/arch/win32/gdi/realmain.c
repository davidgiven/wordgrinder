/* © 2010 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id: dpy.c 159 2009-12-13 13:11:03Z dtrg $
 * $URL: https://wordgrinder.svn.sf.net/svnroot/wordgrinder/wordgrinder/src/c/arch/win32/console/dpy.c $
 */

#include "globals.h"
#include <string.h>
#include <windows.h>
#include "gdi.h"

#undef main
extern int appMain(int argc, const char* argv[]);

static int realargc;
static const char** realargv;
static uni_t queued[4];
static int numqueued = 0;
static int timeout = -1;
static uni_t currentkey;

static LPVOID appfiber;
static LPVOID uifiber;

static uni_t dequeue(void)
{
	uni_t c = queued[0];
	queued[0] = queued[1];
	queued[1] = queued[2];
	queued[2] = queued[3];
	numqueued--;
	return c;
}

void dpy_queuekey(uni_t c)
{
	if (numqueued >= (sizeof(queued)/sizeof(*queued)))
		return;

	queued[numqueued] = c;
	numqueued++;
}

uni_t dpy_getchar(int t)
{
	timeout = t;
	SwitchToFiber(uifiber);
	return currentkey;
}

static void sendkey(uni_t key)
{
	currentkey = key;
	SwitchToFiber(appfiber);
}

void dpy_flushkeys(void)
{
	if (GetCurrentFiber() == uifiber)
	{
		while (numqueued)
		{
			currentkey = dequeue();
			SwitchToFiber(appfiber);
		}
	}
}

static VOID CALLBACK application_cb(LPVOID user)
{
	exit(appMain(realargc, realargv));
}

int main(int argc, const char* argv[])
{
	if (AttachConsole(ATTACH_PARENT_PROCESS))
	{
		freopen("CONOUT$", "wb", stdout);
		freopen("CONOUT$", "wb", stderr);
	}

	uifiber = ConvertThreadToFiber(NULL);
	assert(uifiber);

	appfiber = CreateFiber(0, application_cb, NULL);
	assert(appfiber);

	realargc = argc;
	realargv = argv;

	/* Run the application fiber. This will deschedule when it wants an
	 * event.
	 */

	SwitchToFiber(appfiber);

	/* And now the event loop. */

	for (;;)
	{
		MSG msg;

		for (;;)
		{
			dpy_flushkeys();

			if (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE) > 0)
				break;

			if (timeout == -1)
			{
				GetMessageW(&msg, NULL, 0, 0);
				break;
			}
			else
			{
				if (MsgWaitForMultipleObjects(0, NULL, FALSE, timeout*1000, QS_ALLINPUT)
					== WAIT_TIMEOUT)
				{
					dpy_queuekey(-VK_TIMEOUT);
				}
			}
		}

		if (DispatchMessageW(&msg) == 0)
			TranslateMessage(&msg);
	}

	return 0;
}
