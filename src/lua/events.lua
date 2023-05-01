--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

type EventToken = {Event}

local listeners = {} :: {[Event]: {[EventToken]: (Event, EventToken, ...any) -> ()}}
local batched = {} :: {[Event]: boolean}

type Event =
	  "BuildStatusBar"    --- (statusbararray) the contents of the statusbar is being calculated
	| "Changed"           --- the document's been changed
	| "DocumentCreated"   --- a new documentset has just been created
	| "DocumentLoaded"    --- a new documentset has just been loaded
	| "DocumentModified"  --- (document) a document has been modified
	| "DocumentUpgrade"   --- (oldversion, newversion) the documentset is being upgraded
	| "DrawWord"          --- (word=, ostyle=, cstyle=) a word is being drawn on the screen
	| "KeyTyped"          --- (value=) user is typing into the document
	| "Idle"              --- the user isn't touching the keyboard
	| "Moved"             --- the cursor has moved
	| "Redraw"            --- the screen has just been redrawn
	| "RegisterAddons"    --- all addons should register themselves in the documentset
	| "WaitingForUser"    --- we're about to wait for a keypress
	| "ScreenInitialised" --- the screen has just been set up

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

function AddEventListener(event: Event, callback)
	-- Ensure there's a listener table for this event.
	
	if not listeners[event] then
		listeners[event] = {}
	end
	
	-- Register the callback.
	
	local token: EventToken = {event}
	listeners[event][token] = callback
	return token
end

--- Removes a listener for a particular event.
-- The listener referred to by the handle is removed from the specified
-- event.
--
-- @param token              a token returned by AddEventListener

function RemoveEventListener(token: EventToken)
	local event: Event = token[1]
	listeners[event][token] = nil
end

--- Fires an event.
-- Any callbacks registered for the event will be called (in any order).
--
-- @param event              the event to fire
-- @param ...                any additional event parameters

function FireEvent(event, ...)
	assert(event)

	local l = listeners[event]
	if not l then
		return
	end
	
	for token, callback in l do
		callback(event, token, ...)
	end
end

--- Fires an asynchronous event.
-- These are batched up and fired at the end of the event loop. No event
-- parameters are allowed; the order of event delivery is undefined.
--
-- @param event              the event to fire

function FireAsyncEvent(event)
	assert(event)

	batched[event] = true
end

--- Flushed any pending asynchronous events.
-- It is safe for an event handler to insert more asynchronous events
-- (including the one which is currently firing).

function FlushAsyncEvents()
	while true do
		local e: Event? = next(batched)::any
		if not e then
			break
		end
		assert(e)

		batched[e] = nil
		FireEvent(e)
	end
end
