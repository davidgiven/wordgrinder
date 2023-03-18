--!strict
-- © 2023 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

function FakeIO(data: string)
	local index = 1
	local self = {
		read = function(self, parameter: string)
			if (index >= #data) then
				return nil
			end

			if (parameter == "*l") then
				local s, e, r = data:find("^([^\n]*)\n", index)
				if r then
					index = e + 1
				else
					r = data:sub(index)
					index = #self
				end
				return r
			else
				error("bad parameter")
			end
		end
	}

	setmetatable(self, self)
	return self
end

