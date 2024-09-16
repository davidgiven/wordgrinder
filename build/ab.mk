ifeq ($(findstring 4.,$(MAKE_VERSION)),)
$(error You need GNU Make 4.x for this (if you're on OSX, use gmake).)
endif

OBJ ?= .obj
PYTHON ?= python3
CC ?= gcc
CXX ?= g++
AR ?= ar
CFLAGS ?= -g -Og
LDFLAGS ?= -g
PKG_CONFIG ?= pkg-config
ECHO ?= echo
TARGETS ?= +all

ifdef VERBOSE
	hide =
else
	ifdef V
		hide =
	else
		hide = @
	endif
endif

ifeq ($(OS), Windows_NT)
	EXT ?= .exe
endif
EXT ?=

include $(OBJ)/build.mk

MAKEFLAGS += -r -j$(shell nproc)
.DELETE_ON_ERROR:

.PHONY: update-ab
update-ab:
	@echo "Press RETURN to update ab from the repository, or CTRL+C to cancel." \
		&& read a \
		&& (curl -L https://github.com/davidgiven/ab/releases/download/dev/distribution.tar.xz | tar xvJf -) \
		&& echo "Done."

.PHONY: clean
clean::
	@echo CLEAN
	$(hide) rm -rf $(OBJ)

export PYTHONHASHSEED = 1
build-files = $(shell find . -name 'build.py') $(wildcard build/*.py) $(wildcard config.py)
$(OBJ)/build.mk: Makefile $(build-files)
	@echo "AB"
	@mkdir -p $(OBJ)
	$(hide) $(PYTHON) -X pycache_prefix=$(OBJ) build/ab.py -o $@ build.py \
		|| rm -f $@
