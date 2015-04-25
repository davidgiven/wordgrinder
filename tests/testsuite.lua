function AssertEquals(want, got)
	if (want ~= got) then
		error(
			string.format("Assertion failed: wanted %q; got %q\n",
				want, got))
	end
end

return {}
