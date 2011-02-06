-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local function write(...)
	io.stdout:write(...)
end

local function multibin2c(pattern, ...)
	local files = {...}
	local id = 1
	
	write('#include "globals.h"\n')
	for _, f in ipairs(files) do
		write("\n/* This is ", f, " */\n")
		write("static const char file_", id, "[] = {\n")
		
		local fp = io.open(f, "rb")
		local data = fp:read("*a")
		for i = 1, data:len() do
			write(data:byte(i), ", ")
			if ((i % 16) == 0) then
				write("\n")
			end
		end
		fp:close()
		
		write("\n};\n")
		id = id + 1
	end
	
	write("const FileDescriptor ", pattern, "[] = {\n")
	for i = 1, id-1 do
		local id = "file_"..i
		write("{ ", id, ", sizeof(", id, "), \"", files[i], "\" },\n")
	end
	write("{ NULL, 0 }\n")
	write("};\n")
end

multibin2c(...)
