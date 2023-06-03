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

export PYTHONHASHSEED = 1

#all: $(OBJ)/build.mk
#	@+make -f $(OBJ)/build.mk +all

all: $(OBJ)/build.ninja
	@ninja -f $< +all
	
clean:
	@echo CLEAN
	@rm -rf $(OBJ) bin

build-files = $(shell find . -name 'build.py') build/*.py config.py
$(OBJ)/build.mk: Makefile $(build-files)
	@echo ACKBUILDER
	@mkdir -p $(OBJ)
	@python3 -X pycache_prefix=$(OBJ) build/ab2.py -m make -t +all -o $@ build.py

$(OBJ)/build.ninja: Makefile $(build-files)
	@echo ACKBUILDER
	@mkdir -p $(OBJ)
	@python3 -X pycache_prefix=$(OBJ) build/ab2.py -m ninja -t +all -o $@ \
		-v OBJ,CC,CXX,AR,WINDRES,MAKENSIS \
		build.py

.PHONY: install
install: all
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

.DELETE_ON_ERROR:
.SECONDARY:

