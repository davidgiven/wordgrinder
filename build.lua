
clibrary {
	name = "minizip_lib",
	srcs = {"src/c/minizip/*.c"},
	headers = {"src/c/minizip/*.h"},
}

define_rule("script_table",
	function(p)
		return hermetictarget {
			name = p.name,
			ins = {
				script = "tools/multibin2c.lua",
				unpack(p.scripts),
			},
			outpatterns = {"%/"..p.symbol..".c"},
			commands = {
				"lua ${ins.script} "..p.symbol.." ${ins} > ${outs[1]}"
			}
		}
	end)

script_table {
	name = "luascripts",
	symbol = "script_table",
	scripts = {
		"src/lua/*.lua",
		"src/lua/export/*.lua",
		"src/lua/import/*.lua",
		"src/lua/addons/*.lua"
	},
}

clibrary {
	name = "wordgrinder_main_lib",
	srcs = {
		"src/c/*.c",
		":luascripts",
	},
	headers = {
		"src/c/globals.h",
		"src/c/minizip/zip.h",
		"src/c/minizip/unzip.h",
		"src/c/minizip/ioapi.h",
	}
}

clibrary {
	name = "wordgrinder_unix_lib",
	srcs = {"src/c/arch/unix/x11/*.c"},
	headers = {
		"src/c/globals.h",
		"src/c/arch/unix/x11/x11.h",
		"src/c/utils",
	}
}

cprogram {
	name = "wordgrinder",
	deps = {
		":wordgrinder_main_lib",
		":wordgrinder_unix_lib",
		":minizip_lib",
	},
	libraries = {
		"-llua5.2",
		"-lz",
		"-lX11",
		"-lXft",
	},
	binary = "$(BIN)/wordgrinder"
}

