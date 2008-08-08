-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

local listeners = {}

Event = {}
Event.Redraw = {}            --- the screen has just been redrawn
Event.Idle = {}              --- the user isn't touching the keyboard
Event.WaitingForUser = {}    --- we're about to wait for a keypress
Event.Changed = {}           --- the document's been changed
Event.DocumentCreated = {}   --- a new documentset has just been created
Event.DocumentLoaded = {}    --- a new documentset has just been loaded
Event.DocumentUpgrade = {}   --- (oldversion, newversion) the documentset is being upgraded
Event.RegisterAddons = {}    --- all addons should register themselves in the documentset

--- Adds a listener for a particular event.
-- The supplied callback is added as a listener for the specified event.
-- The order in which listeners are called is not defined. A callback may
-- be registered for any number of events.
--
-- The function returns a callback token which is unique for every listener;
-- it can be used to unregister the listener.
--
-- @param event              the event to register for
-- @param callback           the callback to register
-- @return                   the callback token

function AddEventListener(event, callback)
	-- Ensure there's a listener table for this event.
	
	if not listeners[event] then
		listeners[event] = {}
	end
	
	-- Register the callback.
	
	local token = {event}
	listeners[event][token] = callback
	return token
end

--- Removes a listener for a particular event.
-- The listener referred to by the handle is removed from the specified
-- event.
--
-- @param token              a token returned by AddEventListener

function RemoveEventListener(token)
	local event = token[1]
	listeners[event][token] = nil
end

--- Fires an event.
-- Any callbacks registered for the event will be called (in any order).
--
-- @param event              the event to fire
-- @param ...                any additional event parameters

function FireEvent(event, ...)
	local l = listeners[event]
	if not l then
		return
	end
	
	for token, callback in pairs(l) do
		callback(event, token, ...)
	end
end
