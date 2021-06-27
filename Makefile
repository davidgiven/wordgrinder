# Note: there are no configuration options here (other than the NINJA
# variable). To configure properly, you need to pass parameters and/or
# environment variables into the configure script.

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

hide = @
OBJDIR = .obj

NINJABUILD = \
	$(hide) $(NINJA) -f $(OBJDIR)/build.ninja $(NINJAFLAGS)

.PHONY: all
all: $(OBJDIR)/build.ninja
	$(NINJABUILD)

.PHONY: install
install: $(OBJDIR)/build.ninja
	$(NINJABUILD) install

$(OBJDIR)/build.ninja: configure
	$(hide) sh ./configure

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

