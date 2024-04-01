export OBJ = .obj
export LUA = lua
export CC = gcc
export CXX = g++
export AR = ar
export WINDRES = windres
export PKG_CONFIG = pkg-config
export MAKENSIS = makensis

export CFLAGS = -g -O0 -ffunction-sections -fdata-sections
export CXXFLAGS = $(CFLAGS) --std=c++17
export LDFLAGS = -g
export NINJAFLAGS =
export PREFIX = /usr/local

export BUILDTYPE ?= unix

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