-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local coroutine_yield = coroutine.yield
local coroutine_wrap = coroutine.wrap
local writeu8 = wg.writeu8
local string_find = string.find

local function cowcopy(t)
	return setmetatable({},
		{
			__index = t
		}
	)
end

--- Tokenises XML.
-- Given an XML string, this function returns an iterator which streams
-- tokens from it.
--
-- @param xml                   XML string to tokenise
-- @return                      iterator

function TokeniseXML(xml)
	local PROCESSING = '^<%?([%w_-]+)%s*(.-)%?>'
	local COMMENT = '^<!%-%-(.-)%-%->'
	local CDATA = '^<%!%[CDATA%[(.-)%]%]>'
	local OPENTAG = '^<%s*([%w_-]+)(:?)([%w+-]*)%s*(.-)(/?)>'
	local TAGATTR1 = '^%s*([%w_-]+)(:?)([%w+-]*)%s*=%s*"([^"]*)"'
	local TAGATTR2 = "^%s*([%w_-]+)(:?)([%w+-]*)%s*=%s*'([^']*)'"
	local CLOSETAG = '^</%s*([%w_-]+)(:?)([%w+-]*)%s*>'
	local TEXT = '^([^&<]+)'
	local DECIMALENTITY = '^&#(%d+);'
	local HEXENTITY = '^&#x(%x+);'
	local NAMEDENTITY = '^&(%w+);'
	local EOF = '^%s*$'

	local entities =
	{
		["amp"] = "&",
		["lt"] = "<",
		["gt"] = ">",
		["quot"] = '"',
		["apos"] = "'"
	}
	
	-- Collapse whitespace.
	
	xml = xml:gsub("\r", "")
	xml = xml:gsub("\t", " ")
	xml = xml:gsub(" *\n", "\n")
	xml = xml:gsub("\n *", "\n")
	xml = xml:gsub(" +", " ")
	xml = xml:gsub("\n+", "\n")
	xml = xml:gsub("([^>])\n([^<])", "%1 %2")
	xml = xml:gsub("\n", "")
	xml = xml:gsub("> +<", "><")
	
	local offset = 1
	
	local function parse_attributes(scope, data)
		local attrs = {}
		local offset = 1
		
		local _, e, s1, s2, s3, s4
		while true do
			while true do
				_, e, s1, s2, s3, s4 = string_find(data, TAGATTR1, offset)
				if not e then
					_, e, s1, s2, s3, s4 = string_find(data, TAGATTR2, offset)
				end
				if e then
					local namespace = ""
					local name
					if (s2 ~= "") then
						namespace = s1
						name = s3
					else
						name = s1
					end
					
					if (namespace == "xmlns") then
						scope[name] = s4
					elseif (namespace == "") and (name == "xmlns") then
						scope[""] = s4
					else
						attrs[#attrs+1] =
							{
								namespace = namespace,
								name = name,
								value = s4
							}
					end
					break
				end
				
				for _, a in ipairs(attrs) do
					a.namespace = scope[a.namespace] or a.namespace
				end
				return attrs
			end
			
			offset = e + 1
		end
	end
	
	local parse_tag
	local function parse_tag_contents(scope)
		local _, e, s1, s2, s3, s4, s5

		while true do
			while true do
				_, e = string_find(xml, OPENTAG, offset)
				if e then
					parse_tag(scope)
					break
				end

				_, e = string_find(xml, CLOSETAG, offset)
				if e then
					offset = e + 1
					return
				end
				
				_, e, s1 = string_find(xml, TEXT, offset)
				if e then
					coroutine_yield(
						{
							event = "text",
							text = s1
						}
					)
					
					offset = e + 1
					break
				end
				
				_, e, s1 = string_find(xml, DECIMALENTITY, offset)
				if e then
					coroutine_yield(
						{
							event = "text",
							text = writeu8(tonumber(s1))
						}
					)
					offset = e + 1
					break
				end
				
				_, e, s1 = string_find(xml, HEXENTITY, offset)
				if e then
					coroutine_yield(
						{
							event = "text",
							text = writeu8(tonumber("0x"..s1))
						}
					)
					offset = e + 1
					break
				end
				
				_, e, s1 = string_find(xml, NAMEDENTITY, offset)
				if e then
					coroutine_yield(
						{
							event = "text",
							text = entities[s1] or "invalidentity"
						}
					)
					offset = e + 1
					break
				end
				
				_, e, s1, s2 = string_find(xml, PROCESSING, offset)
				if s1 then
					coroutine_yield(
						{
							event = "processing",
							name = s1,
							attrs = parse_attributes({}, s2)
						}
					)
					offset = e + 1
					break
				end

				_, e = string_find(xml, EOF, offset)
				if e then
					return
				end

				coroutine_yield(
					{
						event = "error",
						text = xml:sub(offset, offset+100)
					}
				)				
				return
			end			
		end
	end
	
	parse_tag = function(scope)
		local _, e, s1, s2, s3, s4, s5 = string_find(xml, OPENTAG, offset)
		local newscope = cowcopy(scope)

		local tag = {
			event = "opentag",
			attrs = parse_attributes(newscope, s4)
		}
		
		if (s2 ~= "") then
			tag.namespace = newscope[s1] or s1
			tag.name = s3
		else
			tag.namespace = newscope[""] or s1
			tag.name = s1
		end
		
		coroutine_yield(tag)
		offset = e + 1

		if (s5 == "") then
			parse_tag_contents(newscope)
		end
							
		coroutine_yield(
			{
				event = "closetag",
				namespace = tag.namespace,
				name = tag.name
			}
		)
	end
	
	local function parser()
		parse_tag_contents({})
	end
		
	return coroutine_wrap(parser)
end

--- Parses an XML string into a DOM-ish tree.
-- 
-- @param xml                   XML string to parse
-- @return                      tree

function ParseXML(xml)
	local nextToken = TokeniseXML(xml)

	local function parse_tag(token)
		local n = token.name
		if (token.namespace ~= "") then
			n = token.namespace .. " " .. n
		end
		
		local t = {
			_name = n
		}
		
		for _, a in ipairs(token.attrs) do
			n = a.name
			if (a.namespace ~= "") then
				n = a.namespace .. " " .. n
			end
			t[n] = a.value
		end
		
		while true do
			token = nextToken()
			
			if (token.event == "opentag") then
				t[#t+1] = parse_tag(token)
			elseif (token.event == "text") then
				t[#t+1] = token.text
			elseif (token.event == "closetag") then
				return t
			end
		end 
	end
	
	-- Find and parse the first element.
	
	while true do
		local token = nextToken()
		if (token.event == "opentag") then
			return parse_tag(token)
		end
		if not token then
			return {}
		end
	end
end
