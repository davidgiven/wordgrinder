for _, arg in ipairs({...}) do
    local _, _, name, value = arg:find("^([%w_]+)=(.*)$")
    if name then
        _G[name] = value
    end
end

local allbinaries = {}
local outfp = io.open(BUILDFILE, "w")
local function emit(...)
    outfp:write(...)
    outfp:write("\n")
end

FRONTENDS = {}
local function want_frontend(name)
    return not not FRONTENDS[name]
end

local function has_package(package)
    if package:find("^-") then
        return true
    end
    if package == "builtin" then
        return true
    end
    return os.execute("pkg-config "..package) == 0
end

local function detect_package(name, package)
    io.write("Detecting "..name.." in package '"..package.."': ")
    io.stdout:flush()

    local found = has_package(package)
    print(found and "found" or "not found")
    return found
end

local function detect_mandatory_package(name, package)
    if not detect_package(name, package) then
        print()
        print("Mandatory package is missing --- cannot build. (There's probably a built-")
        print("in one; try 'builtin'.")
        print()
        os.exit(1)
    end
end

local function package_name(package)
    if package:find("^-") then
        return "custom"
    end
    return package
end

local function has_binary(binary)
    return os.execute("type "..binary.." >/dev/null 2>&1") == 0
end

local function package_flags(package, kind)
    if package:find("^-") then
        local _, _, clause = package:find(kind.."={(.-)}")
        if not clause then
            print("External package specifier "..package.." contains no clause "..kind)
            os.exit(1)
        end
        return clause
    end

    local filename = os.tmpname()
    local e = os.execute("pkg-config "..kind.." "..package.." > "..filename)
    if e ~= 0 then
        error("required package "..package.." is not available")
    end
    local s = io.open(filename):read("*a")
    s = s:gsub("^%s*(.-)%s*$", "%1")
    s = s:gsub("\n", " ")
    os.remove(filename)
    return s
end

local function addname(exe, name)
    return exe:gsub("^([^.]*)", "%1-"..name)
end

function build_wordgrinder_binary(exe, luapackage, frontend, buildstyle)
    name = package_name(luapackage).."-"..frontend.."-"..buildstyle
    exe = addname(exe, name)
    allbinaries[#allbinaries+1] = exe

    local cflags = {
        "$CFLAGS",
        "-g",
        "-DVERSION='\""..VERSION.."\"'",
        "-DFILEFORMAT="..FILEFORMAT,
        "-DNOUNCRYPT",
        "-DNOCRYPT",
        "-Isrc/c",
        "-Wall",
        "-Wno-unused-function",
        "-ffunction-sections",
        "-fdata-sections",
        "-Werror=implicit-function-declaration",
        "--std=gnu99",
    }
    local ldflags = {
        "$LDFLAGS",
        "-lz",
        "-lm",
        "-g",
    }
    local objs = {}

    if frontend == "x11" then
        cflags[#cflags+1] = "$X11_CFLAGS"
        ldflags[#ldflags+1] = "$X11_LDFLAGS"
    elseif frontend == "curses" then
        cflags[#cflags+1] = "$CURSES_CFLAGS"
        ldflags[#ldflags+1] = "$CURSES_LDFLAGS"
    elseif frontend == "windows" then
        ldflags[#ldflags+1] = "-lgdi32"
        ldflags[#ldflags+1] = "-lcomdlg32"
    end

    if (buildstyle == "static") or (frontend == "windows") then
        cflags[#cflags+1] = "-DEMULATED_WCWIDTH"
    end

    if buildstyle == "debug" then
        cflags[#cflags+1] = "-O0"
    else
        cflags[#cflags+1] = "-Os"
    end

    if luapackage == "builtin" then
        cflags[#cflags+1] = "-Isrc/c/emu/lua-5.1.5"
        cflags[#cflags+1] = "-DLUA_USE_MKSTEMP"
    else
        cflags[#cflags+1] = package_flags(luapackage, "--cflags")
        ldflags[#ldflags+1] = package_flags(luapackage, "--libs")
    end

    if LUAFILESYSTEM_PACKAGE == "builtin" then
        cflags[#cflags+1] = "-Isrc/c/emu/lfs"
    else
        cflags[#cflags+1] = package_flags(LUAFILESYSTEM_PACKAGE, "--cflags")
        ldflags[#ldflags+1] = package_flags(LUAFILESYSTEM_PACKAGE, "--libs")
    end

    if LUABITOP_PACKAGE == "builtin" then
        cflags[#cflags+1] = "-Isrc/c/emu/luabitop"
    else
        cflags[#cflags+1] = package_flags(LUABITOP_PACKAGE, "--cflags")
        ldflags[#ldflags+1] = package_flags(LUABITOP_PACKAGE, "--libs")
    end

	if UTHASH_PACKAGE == "builtin" then
		cflags[#cflags+1] = "-Isrc/c/emu/uthash"
	else
        cflags[#cflags+1] = package_flags(UTHASH_PACKAGE, "--cflags")
        ldflags[#ldflags+1] = package_flags(UTHASH_PACKAGE, "--libs")
    end

    local cc
    if frontend == "windows" then
        cc = WINCC
        cflags[#cflags+1] = "-DARCH='\"windows\"'"
        cflags[#cflags+1] = "-DWIN32"
        cflags[#cflags+1] = "-DWINVER=0x0501"
        cflags[#cflags+1] = "-Dmain=appMain"
        cflags[#cflags+1] = "-mwindows"
        ldflags[#ldflags+1] = "-static"
        ldflags[#ldflags+1] = "-lcomctl32"
	ldflags[#ldflags+1] = "-mwindows"
    else
        cc = CC
        cflags[#cflags+1] = "-DARCH='\"unix\"'"
        cflags[#cflags+1] = "-D_XOPEN_SOURCE_EXTENDED"
        cflags[#cflags+1] = "-D_XOPEN_SOURCE"
        cflags[#cflags+1] = "-D_GNU_SOURCE"
    end

    if MINIZIP_PACKAGE == "builtin" then
        cflags[#cflags+1] = "-Isrc/c/emu/minizip"
    else
        cflags[#cflags+1] = package_flags(MINIZIP_PACKAGE, "--cflags")
        ldflags[#ldflags+1] = package_flags(MINIZIP_PACKAGE, "--libs")
    end

    local function srcfile(cfile)
        ofile = cfile:gsub("^(.*)%.c$", OBJDIR.."/"..name.."/%1.o")
        objs[#objs+1] = ofile
        emit("build ", ofile, ": cc ", cfile)
        emit("  cflags = ", table.concat(cflags, " "))
        emit("  cc = ", cc)
    end

    -- Main core

    srcfile("src/c/utils.c")
    srcfile("src/c/zip.c")
    srcfile("src/c/main.c")
    srcfile("src/c/lua.c")
    srcfile("src/c/word.c")
    srcfile("src/c/screen.c")
    srcfile(OBJDIR.."/luascripts.c")

    -- Additional optional libraries

    if LUAFILESYSTEM_PACKAGE == "builtin" then
        srcfile("src/c/emu/lfs/lfs.c")
    end

    if (buildstyle == "static") or (frontend == "windows") then
        srcfile("src/c/emu/wcwidth.c")
    end

    if LUABITOP_PACKAGE == "builtin" then
        srcfile("src/c/emu/luabitop/lua-bitop.c")
    end

    -- Lua (if builtin)

    if luapackage == "builtin" then
        srcfile("src/c/emu/lua-5.1.5/lapi.c")
        srcfile("src/c/emu/lua-5.1.5/lauxlib.c")
        srcfile("src/c/emu/lua-5.1.5/lbaselib.c")
        srcfile("src/c/emu/lua-5.1.5/lcode.c")
        srcfile("src/c/emu/lua-5.1.5/ldblib.c")
        srcfile("src/c/emu/lua-5.1.5/ldebug.c")
        srcfile("src/c/emu/lua-5.1.5/ldo.c")
        srcfile("src/c/emu/lua-5.1.5/ldump.c")
        srcfile("src/c/emu/lua-5.1.5/lfunc.c")
        srcfile("src/c/emu/lua-5.1.5/lgc.c")
        srcfile("src/c/emu/lua-5.1.5/linit.c")
        srcfile("src/c/emu/lua-5.1.5/liolib.c")
        srcfile("src/c/emu/lua-5.1.5/llex.c")
        srcfile("src/c/emu/lua-5.1.5/lmathlib.c")
        srcfile("src/c/emu/lua-5.1.5/lmem.c")
        srcfile("src/c/emu/lua-5.1.5/loadlib.c")
        srcfile("src/c/emu/lua-5.1.5/lobject.c")
        srcfile("src/c/emu/lua-5.1.5/lopcodes.c")
        srcfile("src/c/emu/lua-5.1.5/loslib.c")
        srcfile("src/c/emu/lua-5.1.5/lparser.c")
        srcfile("src/c/emu/lua-5.1.5/lstate.c")
        srcfile("src/c/emu/lua-5.1.5/lstring.c")
        srcfile("src/c/emu/lua-5.1.5/lstrlib.c")
        srcfile("src/c/emu/lua-5.1.5/ltable.c")
        srcfile("src/c/emu/lua-5.1.5/ltablib.c")
        srcfile("src/c/emu/lua-5.1.5/ltm.c")
        srcfile("src/c/emu/lua-5.1.5/lundump.c")
        srcfile("src/c/emu/lua-5.1.5/lvm.c")
        srcfile("src/c/emu/lua-5.1.5/lzio.c")
    end

    -- Frontends

    if frontend == "curses" then
        srcfile("src/c/arch/unix/cursesw/dpy.c")
    elseif frontend == "x11" then
        srcfile("src/c/arch/unix/x11/x11.c")
        srcfile("src/c/arch/unix/x11/glyphcache.c")
    elseif frontend == "windows" then
        srcfile("src/c/arch/win32/gdi/dpy.c")
        srcfile("src/c/arch/win32/gdi/glyphcache.c")
        srcfile("src/c/arch/win32/gdi/realmain.c")
        objs[#objs+1] = OBJDIR.."/wordgrinder.rc.o"
    end

    -- Minizip

    if MINIZIP_PACKAGE == "builtin" then
        srcfile("src/c/emu/minizip/ioapi.c")
        srcfile("src/c/emu/minizip/zip.c")
        srcfile("src/c/emu/minizip/unzip.c")
    end

    emit("build ", exe, ": ld ", table.concat(objs, " "))
    emit("  ldflags = ", table.concat(ldflags, " "))
    emit("  cc = ", cc)
end

function run_wordgrinder_tests(exe, luapackage, frontend, buildstyle)
    name = package_name(luapackage).."-"..frontend.."-"..buildstyle
    exe = addname(exe, name)
    allbinaries[#allbinaries+1] = "test-"..name

    local alltests = {}
    for _, test in ipairs({
        "tests/apply-markup.lua",
        "tests/change-paragraph-style.lua",
        "tests/clipboard.lua",
        "tests/delete-selection.lua",
        "tests/escape-strings.lua",
        "tests/export-to-text.lua",
        "tests/find-and-replace.lua",
        "tests/get-style-from-word.lua",
        "tests/immutable-paragraphs.lua",
        "tests/insert-space-with-style-hint.lua",
        "tests/io-open-enoent.lua",
        "tests/line-down-into-style.lua",
        "tests/line-up.lua",
        "tests/line-wrapping.lua",
        "tests/load-0.1.lua",
        "tests/load-0.2.lua",
        "tests/load-0.3.3.lua",
        "tests/load-0.4.1.lua",
        "tests/load-0.5.3.lua",
        "tests/load-0.6.lua",
        "tests/load-0.6-v6.lua",
        "tests/load-failed.lua",
        "tests/move-while-selected.lua",
        "tests/parse-string-into-words.lua",
        "tests/save-format-escaped-strings.lua",
        "tests/simple-editing.lua",
        "tests/smartquotes-selection.lua",
        "tests/smartquotes-typing.lua",
        "tests/spellchecker.lua",
        "tests/type-while-selected.lua",
        "tests/undo.lua",
        "tests/utils.lua",
        "tests/weirdness-cannot-save-settings.lua",
        "tests/weirdness-combining-words.lua",
        "tests/weirdness-deletion-with-multiple-spaces.lua",
        "tests/weirdness-end-of-lines.lua",
        "tests/weirdness-globals-applied-on-startup.lua",
        "tests/weirdness-missing-clipboard.lua",
        "tests/weirdness-replacing-words.lua",
        "tests/weirdness-save-new-document.lua",
        "tests/weirdness-splitting-lines-before-space.lua",
        "tests/weirdness-stray-control-char-in-export.lua",
        "tests/weirdness-styled-clipboard.lua",
        "tests/weirdness-styling-unicode.lua",
        "tests/weirdness-upgrade-0.6-with-clipboard.lua",
        "tests/weirdness-word-left-from-end-of-line.lua",
        "tests/weirdness-word-right-to-last-word-in-doc.lua",
        "tests/windows-installdir.lua",
        "tests/xpattern.lua",
    }) do
        local stampfile = OBJDIR.."/"..name.."/"..test..".stamp"
        alltests[#alltests+1] = stampfile

        emit("build ", stampfile, ": wordgrindertest ", test, " | ", exe)
        emit("  exe = ", exe)
    end

    emit("build test-", name, ": phony ", table.concat(alltests, " "))
end

local installables = {}
function install_file(mode, src, dest)
    emit("build ", dest, ": install ", src)
    emit("  mode = ", mode)
    installables[#installables+1] = dest
end

-- Sanity check

if (not WANT_STRIPPED_BINARIES) or (WANT_STRIPPED_BINARIES == "") then
    WANT_STRIPPED_BINARIES = "yes"
end

-- Detect what tools we have available.

io.write("Windows toolchain: ")
if has_binary(WINCC) and has_binary(WINDRES) and has_binary(MAKENSIS) then
    print("found")
    FRONTENDS["windows"] = true
else
    print("not found")
end

FRONTENDS["curses"] = detect_package("Curses", CURSES_PACKAGE)
FRONTENDS["x11"] = detect_package("FreeType2", "freetype2") and detect_package("Xft", XFT_PACKAGE)

detect_mandatory_package("Minizip", MINIZIP_PACKAGE)
detect_mandatory_package("LuaFileSystem", LUAFILESYSTEM_PACKAGE)
detect_mandatory_package("uthash", UTHASH_PACKAGE)
detect_mandatory_package("LuaBitOp", LUABITOP_PACKAGE)

local lua_packages = {}
local function add_lua_package(package)
    if not lua_packages[package] then
        lua_packages[package] = true
        lua_packages[#lua_packages+1] = package
    end
end
add_lua_package(LUA_PACKAGE)
add_lua_package("builtin")
add_lua_package("lua-5.1")
add_lua_package("lua-5.2")
add_lua_package("lua-5.3")
add_lua_package("luajit")

for _, luapackage in ipairs(lua_packages) do
    detect_package("Lua", luapackage)
end

emit("CFLAGS = ", CFLAGS)
emit("LDFLAGS = ", LDFLAGS)

if want_frontend("curses") then
    emit("CURSES_CFLAGS = ", package_flags(CURSES_PACKAGE, "--cflags"))
    emit("CURSES_LDFLAGS = ", package_flags(CURSES_PACKAGE, "--libs"))
end
if want_frontend("x11") then
    emit("X11_CFLAGS = ", package_flags("freetype2", "--cflags"),
	" ", package_flags(XFT_PACKAGE, "--cflags"))
    emit("X11_LDFLAGS = ", package_flags("freetype2", "--libs"),
	" ",  package_flags(XFT_PACKAGE, "--libs"))
end
emit("LUA_INTERPRETER = ", LUA_INTERPRETER)
emit("WINDRES = ", WINDRES)
emit("MAKENSIS = ", MAKENSIS)
emit("VERSION = ", VERSION)

emit([[
rule cc
    depfile = $out.d
    command = $cc -MMD -MF $out.d $cflags -c $in -o $out

rule ld
    command = $cc $in -o $out $ldflags

rule luascripts
    command = $LUA_INTERPRETER tools/multibin2c.lua script_table $in > $out

rule wordgrindertest
    command = $exe --lua $in && touch $out

rule rcfile
    command = $WINDRES $in $out

rule makensis
    command = $MAKENSIS -v2 -nocd -dVERSION=$VERSION -dOUTFILE=$out $in

rule strip
    command = strip $in -o $out

rule install
    command = install -m $mode $in $out

rule manpage
    command = sed 's/@@@DATE@@@/$date/g; s/@@@VERSION@@@/$version/g' $in > $out
]])

emit("build ", OBJDIR.."/luascripts.c: luascripts ", table.concat({
    "src/lua/_prologue.lua",
    "src/lua/events.lua",
    "src/lua/main.lua",
    "src/lua/xml.lua",
    "src/lua/utils.lua",
    "src/lua/redraw.lua",
    "src/lua/settings.lua",
    "src/lua/document.lua",
    "src/lua/forms.lua",
    "src/lua/ui.lua",
    "src/lua/browser.lua",
    "src/lua/html.lua",
    "src/lua/margin.lua",
    "src/lua/xpattern.lua",
    "src/lua/fileio.lua",
    "src/lua/export.lua",
    "src/lua/export/text.lua",
    "src/lua/export/html.lua",
    "src/lua/export/latex.lua",
    "src/lua/export/troff.lua",
    "src/lua/export/opendocument.lua",
    "src/lua/export/markdown.lua",
    "src/lua/import.lua",
    "src/lua/import/html.lua",
    "src/lua/import/text.lua",
    "src/lua/import/opendocument.lua",
    "src/lua/navigate.lua",
    "src/lua/addons/goto.lua",
    "src/lua/addons/autosave.lua",
    "src/lua/addons/docsetman.lua",
    "src/lua/addons/scrapbook.lua",
    "src/lua/addons/statusbar_charstyle.lua",
    "src/lua/addons/statusbar_pagecount.lua",
    "src/lua/addons/statusbar_position.lua",
    "src/lua/addons/statusbar_wordcount.lua",
    "src/lua/addons/debug.lua",
    "src/lua/addons/look-and-feel.lua",
    "src/lua/addons/keymapoverride.lua",
    "src/lua/addons/smartquotes.lua",
    "src/lua/addons/undo.lua",
    "src/lua/addons/spillchocker.lua",
    "src/lua/menu.lua",
    "src/lua/cli.lua",
}, " "))

if want_frontend("x11") or want_frontend("curses") then
    for _, buildstyle in ipairs({"release", "debug", "static"}) do
        for _, luapackage in ipairs(lua_packages) do
            if has_package(luapackage) then
                if want_frontend("x11") then
                    build_wordgrinder_binary("bin/xwordgrinder", luapackage, "x11", buildstyle)
                    run_wordgrinder_tests("bin/xwordgrinder", luapackage, "x11", buildstyle)
                end
                if want_frontend("curses") then
                    build_wordgrinder_binary("bin/wordgrinder", luapackage, "curses", buildstyle)
                    run_wordgrinder_tests("bin/wordgrinder", luapackage, "curses", buildstyle)
                end
            end
        end
    end

    if not has_package(LUA_PACKAGE) then
        print()
        print("LUA_PACKAGE is set to '"..LUA_PACKAGE.."', but no Lua package of that name is available.")
        print("Cannot build, giving up. (Try 'builtin').")
        print()
        os.exit(1)
    end
    print("The preferred Lua package is: '"..LUA_PACKAGE.."'")

    local function strip_binary(binary)
        if WANT_STRIPPED_BINARIES == "yes" then
            local stripped = binary.."-stripped"
            emit("build ", stripped, ": strip ", binary)
            allbinaries[#allbinaries+1] = stripped
            binary = stripped
        end

        return binary
    end

    local preferred_test
    local preferred_curses
    local preferred_x11
    if want_frontend("curses") then
        preferred_curses = "bin/wordgrinder-"..package_name(LUA_PACKAGE).."-curses-release"
        preferred_test = "test-"..package_name(LUA_PACKAGE).."-curses-debug"

        preferred_curses = strip_binary(preferred_curses)
        install_file("755", preferred_curses, DESTDIR..BINDIR.."/wordgrinder")
    end
    if want_frontend("x11") then
        preferred_x11 = "bin/xwordgrinder-"..package_name(LUA_PACKAGE).."-x11-release"
        if not preferred_test then
            preferred_test = "test-"..package_name(LUA_PACKAGE).."-x11-debug"
        end

        preferred_x11 = strip_binary(preferred_x11)
        install_file("755", preferred_x11, DESTDIR..BINDIR.."/xwordgrinder")
    end
    install_file("644", "bin/wordgrinder.1", DESTDIR..MANDIR.."/man1/wordgrinder.1")
    install_file("644", "README.wg", DESTDIR..DOCDIR.."/wordgrinder/README.wg")

    emit("build bin/wordgrinder.1: manpage wordgrinder.man")
    emit("  date = ", DATE)
    emit("  version = ", VERSION)

    emit("build binaries: phony bin/wordgrinder.1 ", preferred_curses or "", " ", preferred_x11 or "", " ")
	emit("build tests: phony ", preferred_test)
    emit("build all: phony binaries tests")
    emit("build install: phony all ", table.concat(installables, " "))
    emit("build install-notests: phony binaries ", table.concat(installables, " "))
end

if want_frontend("windows") then
    for _, buildstyle in ipairs({"release", "debug"}) do
        build_wordgrinder_binary("bin/wordgrinder.exe", "builtin", "windows", buildstyle)
    end

    emit("build ", OBJDIR, "/wordgrinder.rc.o: rcfile src/c/arch/win32/wordgrinder.rc | src/c/arch/win32/manifest.xml")

    local installer = "bin/WordGrinder-"..VERSION.."-setup.exe"
    allbinaries[#allbinaries+1] = installer
    emit("build ", installer, ": makensis extras/windows-installer.nsi | bin/wordgrinder-builtin-windows-release.exe")
end

emit("build clean: phony")
emit("build dev: phony ", table.concat(allbinaries, " "))
