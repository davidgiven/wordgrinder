# ===========================================================================
#                          CONFIGURATION OPTIONS
# ===========================================================================

# It should be mostly safe to leave these options at the default.

PREFIX ?= $(HOME)
BINDIR ?= $(PREFIX)/bin
SHAREDIR ?= $(PREFIX)/share
DOCDIR ?= $(SHAREDIR)/doc
MANDIR ?= $(SHAREDIR)/man
DESTDIR ?=

# Where do the temporary files go?
OBJDIR = .obj

# The compiler used for the native build (curses, X11)
CC ?= cc

# Which ninja do you want to use?
ifeq ($(strip $(shell type ninja >/dev/null; echo $$?)),0)
	NINJA ?= ninja
else
	ifeq ($(strip $(shell type ninja-build >/dev/null; echo $$?)),0)
		NINJA ?= ninja-build
    else
        $(error No ninja found)
    endif
endif

# Global CFLAGS and LDFLAGS.
CFLAGS ?=
LDFLAGS ?=

# Used for the Windows build (either cross or native)
WINCC ?= i686-w64-mingw32-gcc
WINLINK ?= i686-w64-mingw32-g++
WINDRES ?= i686-w64-mingw32-windres
MAKENSIS ?= makensis

# Application version and file format.
VERSION := 0.8
FILEFORMAT := 8

ifdef SOURCE_DATE_EPOCH
       DATE := $(shell LC_ALL date --utc --date="@$(SOURCE_DATE_EPOCH)" +'%-d %B %Y')
else
       DATE := $(shell date +'%-d %B %Y')
endif

# Do you want your binaries stripped on installation?

WANT_STRIPPED_BINARIES ?= yes

# ===========================================================================
#                       END OF CONFIGURATION OPTIONS
# ===========================================================================
#
# If you need to edit anything below here, please let me know so I can add
# a proper configuration option.

hide = @

LUA_INTERPRETER = $(OBJDIR)/lua

NINJABUILD = \
	$(hide) $(NINJA) -f $(OBJDIR)/build.ninja $(NINJAFLAGS)

# Builds and tests the Unix release versions only.
.PHONY: all
all: $(OBJDIR)/build.ninja
	$(NINJABUILD)

$(OBJDIR)/build.ninja:
	$(hide) echo "You must run 'configure' first."
	$(hide) false

.DELETE_ON_ERROR:

clean:
	@echo CLEAN
	@rm -rf $(OBJDIR) bin

.PHONY: distr
distr: wordgrinder-$(VERSION).tar.xz

.PHONY: debian-distr
debian-distr: wordgrinder-$(VERSION)-minimal-dependencies-for-debian.tar.xz

.PHONY: wordgrinder-$(VERSION).tar.xz
wordgrinder-$(VERSION).tar.xz:
	tar cvaf $@ \
		--transform "s,^,wordgrinder-$(VERSION)/," \
		extras \
		licenses \
		scripts \
		src \
		testdocs \
		tests \
		tools \
		build.lua \
		Makefile \
		README \
		README.wg \
		README.Windows.txt \
		wordgrinder.man \
		xwordgrinder.man

.PHONY: wordgrinder-$(VERSION)-minimal-dependencies-for-debian.tar.xz
wordgrinder-$(VERSION)-minimal-dependencies-for-debian.tar.xz:
	tar cvaf $@ \
		--transform "s,^,wordgrinder-$(VERSION)/," \
		--exclude "*.dictionary" \
		--exclude "src/c/emu" \
		extras \
		licenses \
		scripts \
		src \
		testdocs \
		tests \
		tools \
		build.lua \
		Makefile \
		README \
		README.wg \
		README.Windows.txt \
		wordgrinder.man \
		xwordgrinder.man

