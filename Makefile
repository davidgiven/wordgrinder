export BUILDTYPE ?= unix

ifeq ($(BUILDTYPE),windows)
	MINGW = i686-w64-mingw32-
	CC = $(MINGW)gcc
	CXX = $(MINGW)g++ -std=c++17
	CFLAGS += \
		-ffunction-sections \
		-fdata-sections \
		-Wno-attributes
	CXXFLAGS += \
		-fext-numeric-literals \
		-Wno-deprecated-enum-float-conversion \
		-Wno-deprecated-enum-enum-conversion
	LDFLAGS += -static
	AR = $(MINGW)ar
	PKG_CONFIG = $(MINGW)pkg-config -static
	WINDRES = $(MINGW)windres
	MAKENSIS = makensis
	EXT = .exe
else
	export CC = gcc
	export CXX = g++
	export CFLAGS
	export CXXFLAGS
	export LDFLAGS
	export AR = ar
	export PKG_CONFIG = pkg-config
endif

CFLAGS += -g -Os -ffunction-sections -fdata-sections
CXXFLAGS = $(CFLAGS) --std=c++17
LDFLAGS += -ffunction-sections -fdata-sections

export PREFIX = /usr/local

export REALOBJ = .obj
export OBJ = $(REALOBJ)/$(BUILDTYPE)

.PHONY: all
all: +all

clean::
	$(hide) rm -rf $(REALOBJ)

.PHONY: install
install: +all
	test -f bin/wordgrinder && cp bin/wordgrinder $(PREFIX)/bin/wordgrinder
	test -f bin/wordgrinder.1 && cp bin/wordgrinder.1 $(PREFIX)/man/man1/wordgrinder.1
	test -f bin/xwordgrinder && cp bin/xwordgrinder $(PREFIX)/bin/xwordgrinder
	test -f bin/xwordgrinder.1 && cp bin/wordgrinder.1 $(PREFIX)/man/man1/xwordgrinder.1

.PHONY: debian-distr
debian-distr: bin/wordgrinder-minimal-dependencies-for-debian.tar.xz

.PHONY: bin/wordgrinder-minimal-dependencies-for-debian.tar.xz
bin/wordgrinder-minimal-dependencies-for-debian.tar.xz:
	tar cvaf $@ \
		--transform "s,^,wordgrinder-$(VERSION)/," \
		--exclude "*.dictionary" \
		Makefile \
		README \
		README.Windows.txt \
		README.wg \
		build.py \
		config.py \
		extras \
		licenses \
		scripts \
		src \
		testdocs \
		tests \
		third_party/luau \
		tools \
		wordgrinder.man \
		xwordgrinder.man

include build/ab.mk