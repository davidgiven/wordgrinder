# ===========================================================================
#                          CONFIGURATION OPTIONS
# ===========================================================================

# It should be mostly safe to leave these options at the default.

PREFIX ?= $(HOME)
BINDIR ?= $(PREFIX)/bin
DOCDIR ?= $(PREFIX)/share/doc
MANDIR ?= $(PREFIX)/share/man
DESTDIR ?=

# Where do the temporary files go?
OBJDIR = /tmp/wg-build

# The compiler used for the native build (curses, X11)
CC ?= cc

# Used for the Windows build (either cross or native)
WINCC ?= i686-w64-mingw32-gcc
WINDRES ?= i686-w64-mingw32-windres
MAKENSIS ?= makensis
ifneq ($(strip $(shell type $(MAKENSIS) >/dev/null 2>&1; echo $$?)),0)
	# If makensis isn't on the path, chances are we're on Cygwin doing a
	# Windows build --- so look in the default installation directory.
	MAKENSIS := /cygdrive/c/Program\ Files\ \(x86\)/NSIS/makensis.exe
endif

# Application version and file format.
VERSION := 0.7.0
FILEFORMAT := 7
DATE ?= $(shell date +'%-d %B %Y')

# Which Lua do you want to use?
#
# Use 'builtin' if you want to use the built-in Lua 5.1. If
# you want to dynamically link to your system's Lua, or to Luajit,
# use a pkg-config name instead (e.g. lua-5.1, lua-5.2, luajit).
# WordGrinder works with 5.1, 5.2, 5.3, and LuaJit.
#
# Alternatively, use a flag specifier string like this:
# --cflags={-I/usr/include/thingylua} --libs={-L/usr/lib/thingylua -lthingylua}
LUA_PACKAGE ?= builtin

# Hack to try and detect the presence of the Xft library (it's not in
# pkg-config).
ifneq ($(wildcard /usr/include/X11/Xft/Xft.h),)
	XFT_PACKAGE ?= --libs={-lX11 -lXft}
else
	XFT_PACKAGE ?= none
endif

# Hack to try and detect OSX's non-pkg-config compliant ncurses.
ifneq ($(filter Darwin%,$(shell uname)),)
	CURSES_PACKAGE ?= --cflags={-I/usr/include} --libs={-L/usr/lib -lncurses}
else
	CURSES_PACKAGE ?= ncursesw
endif

# By default, WordGrinder uses the builtin versions of these libraries.
# However, they're overridable --- this is mainly of use if you're a
# package maintainer and want to dynamically link to your platform's
# version.
#
# Important note: the pkg-config files for Lua packages are typically
# wrong, as they'll try to link in the wrong Lua library. You'll
# probably have to use a manual flag specifier string. Also, setting
# these only makes sense with 'make all' --- don't use this with
# 'make dev' (but you probably won't be doing this anyway).

LUAFILESYSTEM_PACKAGE ?= builtin
LUABITOP_PACKAGE ?= builtin
MINIZIP_PACKAGE ?= builtin

# ===========================================================================
#                       END OF CONFIGURATION OPTIONS
# ===========================================================================
#
# If you need to edit anything below here, please let me know so I can add
# a proper configuration option.

hide = @

LUA_INTERPRETER = $(OBJDIR)/lua

NINJABUILD = \
	$(hide) ninja -f $(OBJDIR)/build.ninja $(NINJAFLAGS)

# Builds and tests the Unix release versions only.
.PHONY: all
all: $(OBJDIR)/build.ninja
	$(NINJABUILD) all

# Builds, tests and installs the Unix release versions only.
.PHONY: install
install: $(OBJDIR)/build.ninja
	$(NINJABUILD) install

# Builds and tests everything that's buildable on your machine.
.PHONY: dev
dev: $(OBJDIR)/build.ninja
	$(NINJABUILD) dev

# Builds Windows (but doesn't test it because that's hard).
.PHONY: windows
windows: $(OBJDIR)/build.ninja
	$(NINJABUILD) bin/WordGrinder-$(VERSION)-setup.exe

$(OBJDIR)/build.ninja:: $(LUA_INTERPRETER) build.lua Makefile
	@mkdir -p $(dir $@)
	$(hide) $(LUA_INTERPRETER) build.lua \
		BINDIR="$(BINDIR)" \
		BUILDFILE="$@" \
		CC="$(CC)" \
		CURSES_PACKAGE="$(CURSES_PACKAGE)" \
		DATE="$(DATE)" \
		DESTDIR="$(DESTDIR)" \
		DOCDIR="$(DOCDIR)" \
		FILEFORMAT="$(FILEFORMAT)" \
		LUABITOP_PACKAGE="$(LUABITOP_PACKAGE)" \
		LUAFILESYSTEM_PACKAGE="$(LUAFILESYSTEM_PACKAGE)" \
		LUA_INTERPRETER="$(LUA_INTERPRETER)" \
		LUA_PACKAGE="$(LUA_PACKAGE)" \
		MAKENSIS="$(MAKENSIS)" \
		MANDIR="$(MANDIR)" \
		MINIZIP_PACKAGE="$(MINIZIP_PACKAGE)" \
		OBJDIR="$(OBJDIR)" \
		VERSION="$(VERSION)" \
		WINCC="$(WINCC)" \
		WINDRES="$(WINDRES)" \
		XFT_PACKAGE="$(XFT_PACKAGE)" \

clean:
	@echo CLEAN
	@rm -rf $(OBJDIR)

$(LUA_INTERPRETER): src/c/emu/lua-5.1.5/*.[ch]
	@echo Bootstrapping build
	@mkdir -p $(dir $@)
	@$(CC) -o $(LUA_INTERPRETER) -O src/c/emu/lua-5.1.5/*.c -lm -DLUA_USE_MKSTEMP
