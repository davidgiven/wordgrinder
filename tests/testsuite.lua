function AssertEquals(want, got)
	if (want ~= got) then
		error(
			string.format("Assertion failed: wanted '%s'; got '%s'\n",
				want, got))
	end
end

return {}
