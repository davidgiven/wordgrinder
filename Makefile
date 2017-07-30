hide = @

PREFIX ?= $(HOME)
BINDIR ?= $(PREFIX)/bin
DOCDIR ?= $(PREFIX)/share/doc
MANDIR ?= $(PREFIX)/share/man

OBJDIR = .obj

# Used for the native build (curses, X11)
CC ?= gcc

# Used for the Windows build (either cross or native)
WINCC ?= i686-w64-mingw32-gcc
WINDRES ?= i686-w64-mingw32-windres
MAKENSIS ?= makensis
ifneq ($(strip $(shell type $(MAKENSIS) >/dev/null 2>&1; echo $$?)),0)
	# If makensis isn't on the path, chances are we're on Cygwin doing a
	# Windows build --- so look in the default installation directory.
	MAKENSIS := /cygdrive/c/Program\ Files\ \(x86\)/NSIS/makensis.exe
endif

VERSION := 0.7.0
FILEFORMAT := 7
DATE := $(shell date +'%-d %B %Y')

LUA_INTERPRETER = $(OBJDIR)/lua

# Hack to try and detect OSX's non-pkg-config compliant ncurses.
ifneq ($(Apple_PubSub_Socket_Render),)
	CURSES_PACKAGE := "-I/usr/include -L/usr/lib -lncurses"
else
	CURSES_PACKAGE := ncursesw
endif

# Replace lua53 with internallua or a pkg-config name (including luajit)
PREFERRED_WORDGRINDER = wordgrinder-lua-5.2-curses-release
PREFERRED_XWORDGRINDER = xwordgrinder-lua-5.2-x11-release

NINJABUILD = \
	$(hide) ninja -f $(OBJDIR)/build.ninja $(NINJAFLAGS)

# Builds and tests the Unix release versions only.
.PHONY: all
all: $(OBJDIR)/build.ninja
	$(NINJABUILD) \
		bin/$(PREFERRED_WORDGRINDER) \
		bin/$(PREFERRED_XWORDGRINDER) \
		$(subst wordgrinder,test,$(PREFERRED_WORDGRINDER))

# Builds and tests everything.
.PHONY: dev
dev: $(OBJDIR)/build.ninja
	$(NINJABUILD) all

# Builds Windows (but doesn't test it).
.PHONY: windows
windows: $(OBJDIR)/build.ninja
	$(NINJABUILD) bin/WordGrinder-$(VERSION)-setup.exe

.PHONY: install
install: all bin/wordgrinder.1
	@echo INSTALL
	$(hide)install -d                                   $(DESTDIR)$(BINDIR)
	$(hide)install -m 755 bin/$(PREFERRED_WORDGRINDER)  $(DESTDIR)$(BINDIR)/wordgrinder
	$(hide)install -m 755 bin/$(PREFERRED_XWORDGRINDER) $(DESTDIR)$(BINDIR)/xwordgrinder
	$(hide)install -d                                   $(DESTDIR)$(MANDIR)/man1
	$(hide)install -m 644 bin/wordgrinder.1             $(DESTDIR)$(MANDIR)/man1/wordgrinder.1
	$(hide)install -d                                   $(DESTDIR)$(DOCDIR)/wordgrinder
	$(hide)install -m 644 README.wg                     $(DESTDIR)$(DOCDIR)/wordgrinder/README.wg

bin/wordgrinder.1: wordgrinder.man
	@echo MANPAGE
	$(hide) sed -e 's/@@@DATE@@@/$(DATE)/g; s/@@@VERSION@@@/$(VERSION)/g' $< > $@

.PHONY: ninjabuild
ninjabuild: $(OBJDIR)/build.ninja
	$(hide) ninja -f $(OBJDIR)/build.ninja $(NINJAFLAGS) $(MAKECMDGOALS)

$(OBJDIR)/build.ninja: $(LUA_INTERPRETER) build.lua Makefile
	@mkdir -p $(dir $@)
	$(hide) $(LUA_INTERPRETER) build.lua \
		BUILDFILE="$@" \
		OBJDIR="$(OBJDIR)" \
		LUA_INTERPRETER="$(LUA_INTERPRETER)" \
		LUA_PACKAGE="$(LUA_PACKAGE)" \
		CURSES_PACKAGE="$(CURSES_PACKAGE)" \
		CC="$(CC)" \
		WINCC="$(WINCC)" \
		WINDRES="$(WINDRES)" \
		MAKENSIS="$(MAKENSIS)" \
		VERSION="$(VERSION)" \
		FILEFORMAT="$(FILEFORMAT)" \

clean:
	@echo CLEAN
	@rm -rf $(OBJDIR)

$(LUA_INTERPRETER): src/c/emu/lua-5.1.5/*.[ch]
	@echo Bootstrapping build
	@mkdir -p $(dir $@)
	@$(CC) -o $(LUA_INTERPRETER) -O src/c/emu/lua-5.1.5/*.c -lm -DLUA_USE_MKSTEMP
