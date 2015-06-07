# © 2007-2013 David Given.
# WordGrinder is licensed under the MIT open source license. See the COPYING
# file in this distribution for the full text.

hide = @

.DELETE_ON_ERROR:

PREFIX = $(HOME)
CC = gcc
WINCC = mingw32-gcc.exe
WINDRES = windres.exe
MAKENSIS = makensis

USE_LUAJIT = n

ifneq ($(findstring Windows,$(OS)),)
	OS = windows
	TESTER = bin/wordgrinder-debug.exe
all: windows
else ifneq ($(Apple_PubSub_Socket_Render),)
	BREWPREFIX := $(shell brew --prefix 2>/dev/null || echo)

	LIBROOT := $(BREWPREFIX)/lib $(BREWPREFIX)/opt/ncurses/lib
	INCROOT := $(BREWPREFIX)
	LUA_INCLUDE := $(BREWPREFIX)/include
	NCURSES_INCLUDE := /usr/include
	NCURSES_LIB := -L/usr/lib -lncurses
	LUA_LIB := -llua.5.2

	OS = unix
	TESTER = bin/wordgrinder-debug
all: unix
else
	LIBROOT := /usr/lib
	INCROOT := /usr
	ifeq ($(USE_LUAJIT),y)
		LUA_INCLUDE := $(INCROOT)/include/luajit-2.0
		LUA_LIB := -lluajit-5.1
		# The ImmutabliseArray() code, used by the debug version of
		# WordGrinder to ensure we don't modify stuff we shouldn't,
		# uses new 5.2 metamethods and doesn't work on LuaJIT.
		TESTER = bin/wordgrinder
	else
		LUA_INCLUDE := $(INCROOT)/include/lua5.2
		LUA_LIB := -llua5.2
		TESTER = bin/wordgrinder-debug
	endif

	NCURSES_CFLAGS := $(shell pkg-config ncursesw --cflags)
	NCURSES_LIB := $(shell pkg-config ncursesw --libs)
	X11_CFLAGS := $(shell pkg-config freetype2 --cflags) -I/usr/include/X11
	X11_LIB := -lX11 -lXft $(shell pkg-config freetype2 --libs) 

	OS = unix
all: unix x11unix
endif

VERSION := 0.6.0
FILEFORMAT := 6
DATE := $(shell date +'%-d %B %Y')

OBJ = .obj/lj_$(USE_LUAJIT)

override CFLAGS += \
	-DVERSION='"$(VERSION)"' \
	-DFILEFORMAT=$(FILEFORMAT) \
	-DPREFIX='"$(HOME)"' \
	-Isrc/c \
	-Isrc/c/minizip \
	-Wall \
	-ffunction-sections \
	-Werror=implicit-function-declaration \
	-fdata-sections \
	--std=gnu99

override LDFLAGS += \

WININSTALLER := bin/WordGrinder\ $(VERSION)\ setup.exe

unix: \
	bin/wordgrinder \
	bin/wordgrinder-debug \
	tests \
	bin/wordgrinder-static

x11unix: \
	bin/xwordgrinder \
	bin/xwordgrinder-debug \
	bin/xwordgrinder-static
.PHONY: unix x11unix
	
windows: \
	bin/wordgrinder.exe \
	bin/wordgrinder-debug.exe \
	tests \
	$(WININSTALLER)
.PHONY: windows

wininstaller: $(WININSTALLER)
.PHONY: wininstaller

install: bin/wordgrinder bin/wordgrinder.1
	@echo INSTALL
	$(hide)install -d                       $(PREFIX)/bin
	$(hide)install -m 755 bin/wordgrinder   $(PREFIX)/bin/wordgrinder
	$(hide)install -d                       $(PREFIX)/share/man/man1
	$(hide)install -m 644 bin/wordgrinder.1 $(PREFIX)/share/man/man1/wordgrinder.1
	$(hide)install -d                       $(PREFIX)/share/doc/wordgrinder
	$(hide)install -m 644 README.wg         $(PREFIX)/share/doc/wordgrinder/README.wg
	
# --- Builds the script blob ------------------------------------------------

# Each script is loaded in this order, which is important.
LUASCRIPTS := \
	src/lua/_prologue.lua \
	src/lua/events.lua \
	src/lua/main.lua \
	src/lua/xml.lua \
	src/lua/utils.lua \
	src/lua/redraw.lua \
	src/lua/settings.lua \
	src/lua/document.lua \
	src/lua/forms.lua \
	src/lua/ui.lua \
	src/lua/browser.lua \
	src/lua/html.lua \
	src/lua/margin.lua \
	src/lua/fileio.lua \
	src/lua/export.lua \
	src/lua/export/text.lua \
	src/lua/export/html.lua \
	src/lua/export/latex.lua \
	src/lua/export/troff.lua \
	src/lua/export/opendocument.lua \
	src/lua/import.lua \
	src/lua/import/html.lua \
	src/lua/import/text.lua \
	src/lua/import/opendocument.lua \
	src/lua/navigate.lua \
	src/lua/addons/goto.lua \
	src/lua/addons/autosave.lua \
	src/lua/addons/docsetman.lua \
	src/lua/addons/scrapbook.lua \
	src/lua/addons/pagecount.lua \
	src/lua/addons/statusbar_charstyle.lua \
	src/lua/addons/statusbar_position.lua \
	src/lua/addons/statusbar_wordcount.lua \
	src/lua/addons/debug.lua \
	src/lua/addons/widescreen.lua \
	src/lua/addons/keymapoverride.lua \
	src/lua/addons/smartquotes.lua \
	src/lua/addons/undo.lua \
	src/lua/addons/spillchocker.lua \
	src/lua/menu.lua \
	src/lua/cli.lua \

$(OBJ)/luascripts.c: $(LUASCRIPTS)
	@echo SCRIPTS
	@mkdir -p $(OBJ)
	$(hide)lua tools/multibin2c.lua script_table $^ > $@
	
clean::
	@echo CLEAN $(OBJ)/luascripts.c
	@rm -f $(OBJ)/luascripts.c
	
# --- Builds a single C file ------------------------------------------------

define cfile

$(objdir)/$(1:.c=.o): $1 Makefile
	@echo CC $$@
	@mkdir -p $$(dir $$@)
	$(hide)$(cc) $(CFLAGS) $(cflags) $(INCLUDES) -c -o $$@ $1

$(objdir)/$(1:.c=.d): $1 Makefile
	@echo DEPEND $$@
	@mkdir -p $$(dir $$@)
	$(hide)$(cc) $(CFLAGS) $(cflags) $(INCLUDES) \
		-MP -MM -MT $(objdir)/$(1:.c=.o) -MF $$@ $1

DEPENDS += $(objdir)/$(1:.c=.d)
objs += $(objdir)/$(1:.c=.o)

endef

# --- Builds a single RC file -----------------------------------------------

define rcfile

$(objdir)/$(1:.rc=.o): $1 Makefile
	@echo WINDRES $$@
	@mkdir -p $$(dir $$@)
	$(hide)$(WINDRES) $1 $$@

objs += $(objdir)/$(1:.rc=.o)

endef

# --- Links WordGrinder -----------------------------------------------------

define build-wordgrinder

$(exe): $(objs) Makefile
	@echo LINK $$@
	@mkdir -p $$(dir $$@)
	$(hide)$(cc) $(CFLAGS) $(cflags) $(LDFLAGS) -o $$@ $(objs) $(ldflags) 

clean::
	@echo CLEAN $(exe)
	@rm -f $(exe) $(objs)
	
endef

# --- Builds the WordGrinder core code --------------------------------------

define build-wordgrinder-core

$(call cfile, src/c/utils.c)
$(call cfile, src/c/zip.c)
$(call cfile, src/c/main.c)
$(call cfile, src/c/lua.c)
$(call cfile, src/c/word.c)
$(call cfile, src/c/screen.c)
$(call cfile, $(OBJ)/luascripts.c)

endef

# --- Builds the LFS library ------------------------------------------------

define build-wordgrinder-lfs

$(call cfile, src/c/lfs/lfs.c)

endef

# --- Builds the minizip library --------------------------------------------

define build-wordgrinder-minizip

$(call cfile, src/c/minizip/ioapi.c)
$(call cfile, src/c/minizip/zip.c)
$(call cfile, src/c/minizip/unzip.c)

endef

# --- Builds emulation routines ---------------------------------------------

define build-wordgrinder-emu

$(call cfile, src/c/emu/wcwidth.c)

endef

# --- Builds the ncurses front end ------------------------------------------

define build-wordgrinder-ncurses

$(call cfile, src/c/arch/unix/cursesw/dpy.c)

endef

# --- Builds the X11 front end ----------------------------------------------

define build-wordgrinder-x11

$(call cfile, src/c/arch/unix/x11/x11.c)
$(call cfile, src/c/arch/unix/x11/glyphcache.c)

endef

# --- Builds the Windows front end ------------------------------------------

define build-wordgrinder-windows

$(call cfile, src/c/arch/win32/gdi/dpy.c)
$(call cfile, src/c/arch/win32/gdi/glyphcache.c)
$(call cfile, src/c/arch/win32/gdi/realmain.c)
$(call rcfile, src/c/arch/win32/wordgrinder.rc)

src/c/arch/win32/wordgrinder.rc: \
	src/c/arch/win32/manifest.xml

endef

# --- Unix ------------------------------------------------------------------

ifeq ($(OS),unix)

cc := gcc
INCLUDES := -I$(LUA_INCLUDE)

UNIXCFLAGS := \
	-D_XOPEN_SOURCE_EXTENDED \
	-D_XOPEN_SOURCE \
	-D_GNU_SOURCE \
	-DARCH=\"unix\"
	
UNIXLDFLAGS := \
	$(addprefix -L,$(LIBROOT)) \
	$(LUA_LIB) \
	-lz

cflags := $(UNIXCFLAGS) $(NCURSES_CFLAGS) -Os -DNDEBUG
objdir := $(OBJ)/release
exe := bin/wordgrinder
objs :=
ldflags := $(UNIXLDFLAGS) $(NCURSES_LIB) -DBUILTIN_LFS
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-ncurses))
$(eval $(build-wordgrinder-minizip))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder))

cflags := $(UNIXCFLAGS) $(NCURSES_CFLAGS) -g -DBUILTIN_LFS
objdir := $(OBJ)/debug
exe := bin/wordgrinder-debug
objs :=
ldflags := $(UNIXLDFLAGS) $(NCURSES_LIB)
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-ncurses))
$(eval $(build-wordgrinder-minizip))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder))

cflags := $(UNIXCFLAGS) $(NCURSES_CFLAGS) -g -DEMULATED_WCWIDTH -DBUILTIN_LFS
objdir := $(OBJ)/debug-static
exe := bin/wordgrinder-static
objs :=
ldflags := $(UNIXLDFLAGS) $(NCURSES_LIB)
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-ncurses))
$(eval $(build-wordgrinder-minizip))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder-emu))
$(eval $(build-wordgrinder))

cflags := $(UNIXCFLAGS) $(X11_CFLAGS) -Os -DNDEBUG -DBUILTIN_LFS
objdir := $(OBJ)/release-x11
exe := bin/xwordgrinder
objs :=
ldflags := $(UNIXLDFLAGS) $(X11_LIB)
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-x11))
$(eval $(build-wordgrinder-minizip))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder))

cflags := $(UNIXCFLAGS) $(X11_CFLAGS) -g -DBUILTIN_LFS
objdir := $(OBJ)/debug-x11
exe := bin/xwordgrinder-debug
objs :=
ldflags := $(UNIXLDFLAGS) $(X11_LIB)
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-x11))
$(eval $(build-wordgrinder-minizip))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder))

cflags := $(UNIXCFLAGS) $(X11_CFLAGS) -g -DEMULATED_WCWIDTH -DBUILTIN_LFS
objdir := $(OBJ)/debug-static-x11
exe := bin/xwordgrinder-static
objs :=
ldflags := $(UNIXLDFLAGS) $(X11_LIB)
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-x11))
$(eval $(build-wordgrinder-minizip))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder-emu))
$(eval $(build-wordgrinder))

bin/wordgrinder.1: wordgrinder.man
	@echo MANPAGE
	$(hide)sed -e 's/@@@DATE@@@/$(DATE)/g; s/@@@VERSION@@@/$(VERSION)/g' $< > $@

endif
	
# --- Windows ---------------------------------------------------------------

ifeq ($(OS),windows)

cc := $(WINCC)

WINDOWSCFLAGS := \
	-DEMULATED_WCWIDTH \
	-DBUILTIN_LFS \
	-DWIN32 \
	-DWINVER=0x0501 \
	-DARCH=\"windows\" \
	-Dmain=appMain \
	-mwindows

ldflags := \
	-static \
	-lcomctl32 \
	-llua \
	-lz

cflags := $(WINDOWSCFLAGS) -Os -DNDEBUG
objdir := $(OBJ)/win32-release
exe := bin/wordgrinder.exe
objs :=
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-minizip))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder-emu))
$(eval $(build-wordgrinder-windows))
$(eval $(build-wordgrinder))


cflags := $(WINDOWSCFLAGS) -g
objdir := $(OBJ)/win32-debug
exe := bin/wordgrinder-debug.exe
objs :=
$(eval $(build-wordgrinder-core))
$(eval $(build-wordgrinder-minizip))
$(eval $(build-wordgrinder-lfs))
$(eval $(build-wordgrinder-emu))
$(eval $(build-wordgrinder-windows))
$(eval $(build-wordgrinder))

src/c/arch/win32/wordgrinder.rc: \
	src/c/arch/win32/icon.ico \
	src/c/arch/win32/manifest.xml


$(WININSTALLER): extras/windows-installer.nsi bin/wordgrinder.exe
	@echo INSTALLER
	@mkdir -p bin # $(dir) doesn't work with spaces
	$(hide)$(MAKENSIS) -v2 -nocd -dVERSION=$(VERSION) -dOUTFILE=$(WININSTALLER) $<

clean::
	@echo CLEAN $(WININSTALLER)
	@rm -f $(WININSTALLER)
	
endif

# --- Tests -----------------------------------------------------------------

define run-test

$(OBJ)/$(strip $1).passed: $(TESTER) $1
	@echo TEST $1
	@mkdir -p $$(dir $$@)
	@rm -f $$@
	$(hide) $(TESTER) --lua $1
	@touch $$@

tests: $(OBJ)/$(strip $1).passed

endef

$(eval $(call run-test, tests/apply-markup.lua))
$(eval $(call run-test, tests/change-paragraph-style.lua))
$(eval $(call run-test, tests/clipboard.lua))
$(eval $(call run-test, tests/delete-selection.lua))
$(eval $(call run-test, tests/get-style-from-word.lua))
$(eval $(call run-test, tests/immutable-paragraphs.lua))
$(eval $(call run-test, tests/insert-space-with-style-hint.lua))
$(eval $(call run-test, tests/line-down-into-style.lua))
$(eval $(call run-test, tests/line-up.lua))
$(eval $(call run-test, tests/line-wrapping.lua))
$(eval $(call run-test, tests/load-0.1.lua))
$(eval $(call run-test, tests/load-0.2.lua))
$(eval $(call run-test, tests/load-0.3.3.lua))
$(eval $(call run-test, tests/load-0.4.1.lua))
$(eval $(call run-test, tests/load-0.5.3.lua))
$(eval $(call run-test, tests/load-failed.lua))
$(eval $(call run-test, tests/move-while-selected.lua))
$(eval $(call run-test, tests/parse-string-into-words.lua))
$(eval $(call run-test, tests/simple-editing.lua))
$(eval $(call run-test, tests/smartquotes-selection.lua))
$(eval $(call run-test, tests/smartquotes-typing.lua))
$(eval $(call run-test, tests/type-while-selected.lua))
$(eval $(call run-test, tests/undo.lua))
$(eval $(call run-test, tests/weirdness-deletion-with-multiple-spaces.lua))
$(eval $(call run-test, tests/weirdness-end-of-lines.lua))
$(eval $(call run-test, tests/weirdness-combining-words.lua))
$(eval $(call run-test, tests/weirdness-replacing-words.lua))

.phony: tests

# --- Final setup -----------------------------------------------------------

-include $(DEPENDS)

