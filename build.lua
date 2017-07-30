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
    return os.execute("pkg-config "..package) == 0
end

local function has_binary(binary)
    return os.execute("type "..binary.." >/dev/null 2&>1") == 0
end

local function package_flags(package, kind)
    if package:find("^-") then
        return package
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
    name = luapackage.."-"..frontend.."-"..buildstyle
    exe = addname(exe, name)
    allbinaries[#allbinaries+1] = exe

    local cflags = {
        "-g",
        "-DVERSION='\""..VERSION.."\"'",
        "-DFILEFORMAT="..FILEFORMAT,
        "-DBUILTIN_LFS",
        "-DNOUNCRYPT",
        "-DNOCRYPT",
        "-Isrc/c",
        "-Isrc/c/minizip",
        "-Wall",
        "-Wno-unused-function",
        "-ffunction-sections",
        "-fdata-sections",
        "-Werror=implicit-function-declaration",
        "--std=gnu99",
    }
    local ldflags = {
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
        cflags[#cflags+1] = "-Og"
    else
        cflags[#cflags+1] = "-Os"
        ldflags[#cflags+1] = "-s"
    end


    if luapackage == "internallua" then
        cflags[#cflags+1] = "-Isrc/c/emu/lua-5.1.5"
        cflags[#cflags+1] = "-DLUA_USE_MKSTEMP"
    else
        cflags[#cflags+1] = package_flags(luapackage, "--cflags")
        ldflags[#ldflags+1] = package_flags(luapackage, "--libs")
    end

    local needs_luabitop = (luapackage == "lua51") or (luapackage == "internallua") or (luapackage == "lua-5.1")
    if needs_luabitop then
        cflags[#cflags+1] = "-DBUILTIN_LUABITOP"
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

    -- Additional mandatory libraries

    srcfile("src/c/lfs/lfs.c")

    if (buildstyle == "static") or (frontend == "windows") then
        srcfile("src/c/emu/wcwidth.c")
    end

    if needs_luabitop then
        srcfile("src/c/luabitop/bit.c")
    end

    -- Lua (if internal)

    if luapackage == "internallua" then
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

    srcfile("src/c/minizip/ioapi.c")
    srcfile("src/c/minizip/zip.c")
    srcfile("src/c/minizip/unzip.c")

    emit("build ", exe, ": ld ", table.concat(objs, " "))
    emit("  ldflags = ", table.concat(ldflags, " "))
    emit("  cc = ", cc)
end

function run_wordgrinder_tests(exe, luapackage, frontend, buildstyle)
    name = luapackage.."-"..frontend.."-"..buildstyle
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
        "tests/weirdness-replacing-words.lua",
        "tests/weirdness-save-new-document.lua",
        "tests/weirdness-splitting-lines-before-space.lua",
        "tests/weirdness-stray-control-char-in-export.lua",
        "tests/weirdness-styled-clipboard.lua",
        "tests/weirdness-styling-unicode.lua",
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

-- Detect what tools we have available.

io.write("Windows toolchain: ")
if has_binary(WINCC) and has_binary(WINDRES) and has_binary(MAKENSIS) then
    print("found")
    FRONTENDS["windows"] = true
else
    print("not found")
end
io.write("Curses package '"..CURSES_PACKAGE.."': ")
if has_package(CURSES_PACKAGE) then
    print("found")
    FRONTENDS["curses"] = true
else
    print("not found")
end
io.write("FreeType2: ")
if has_package("freetype2") then
    print("found")
    FRONTENDS["x11"] = true
else
    print("not found")
end

local lua_packages = {"luajit", "lua-5.1", "lua-5.2", "lua-5.3"}

for _, luapackage in ipairs(lua_packages) do
    io.write("Lua package '"..luapackage.."': ")
    if has_package(luapackage) then
        print("found")
    else
        print("not found")
    end
end
lua_packages[#lua_packages+1] = "internallua"

if want_frontend("curses") then
    emit("CURSES_CFLAGS = ", package_flags(CURSES_PACKAGE, "--cflags"))
    emit("CURSES_LDFLAGS = ", package_flags(CURSES_PACKAGE, "--libs"))
end
if want_frontend("x11") then
    emit("X11_CFLAGS = ", package_flags("freetype2", "--cflags"), " -I/usr/include/X11")
    emit("X11_LDFLAGS = ", package_flags("freetype2", "--libs"), " -lX11 -lXft")
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

rule nop
    command = true
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
            if (luapackage == "internallua") or has_package(luapackage) then
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
end

if want_frontend("windows") then
    for _, buildstyle in ipairs({"release", "debug"}) do
        build_wordgrinder_binary("bin/wordgrinder.exe", "internallua", "windows", buildstyle)
    end

    emit("build ", OBJDIR, "/wordgrinder.rc.o: rcfile src/c/arch/win32/wordgrinder.rc | src/c/arch/win32/manifest.xml")

    local installer = "bin/WordGrinder-"..VERSION.."-setup.exe"
    allbinaries[#allbinaries+1] = installer
    emit("build ", installer, ": makensis extras/windows-installer.nsi | bin/wordgrinder-internallua-windows-release.exe")
end

emit("build clean: phony")
emit("build all: phony ", table.concat(allbinaries, " "))
