-- © 2023 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

declare class Object
	__call: (Object, any) -> any
end

local function instantiate(self: any, impl: any): any
	return setmetatable(impl or {}, {__index = self, __call = instantiate})
end
	
declare Object: Object
Object = {}::any
setmetatable(Object::any, {__call = instantiate})

