--[[
	A simple implementation of a RBXScriptSignal,
	With the Once and Connect Support.

	Handlers are fired in order, and (dis)connections are properly handled when
	executing an event.

	Signal uses Immutable to avoid invalidating the 'Fire' loop iteration.
	
	Edited by Liker, module found in the DevConsole Folder of the RobloxGui, CoreGui.
	
	(this was intended to be only used in SafePipe! I am not responsible for any damages.)
]]

local Immutable = require(script.Immutable)

local Signal = {}
local SignalFunctions = {}
SignalFunctions.__index = SignalFunctions

function Signal.new()
	local self = {
		_listeners = {},
		_parallellisteners = {},
		_oncelisteners = {},
	}

	setmetatable(self, SignalFunctions)

	return self
end

function SignalFunctions:Connect(callback, ...) --> Edited for 'Connected' self Support
	local listener = {
		callback = callback,
		isConnected = true,
	}
	
	local Properties = {
		Disconnect = nil,
		Connected = true,
	}
	
	self._listeners = Immutable.Append(self._listeners, listener)
	
	function disconnect()
		listener.isConnected = false
		Properties.Connected = false

		self._listeners = Immutable.RemoveValueFromList(self._listeners, listener)
	end

	function Properties:Disconnect()
		disconnect(self)
	end

	return Properties
end

function SignalFunctions:Once(callback)
	local listener = {
		callback = callback,
		isConnected = true,
	}

	local Properties = {
		Disconnect = nil,
		Connected = true,
	}

	self._oncelisteners = Immutable.Append(self._oncelisteners, listener)

	function disconnect()
		listener.isConnected = false
		Properties.Connected = false

		self._oncelisteners = Immutable.RemoveValueFromList(self._oncelisteners, listener)
	end

	function Properties:Disconnect()
		disconnect()
	end

	return Properties
end

function SignalFunctions:Fire(...) --> Modified for the 'Parallel' Functionality
	--Regular
	for _, listener in ipairs(self._listeners) do
		if listener.isConnected then
			task.spawn(listener.callback, ...)
		end
	end
	
	--Once
	for _, listener in ipairs(self._oncelisteners) do
		if listener.isConnected then
			task.spawn(listener.callback, ...)
		end
	end
end

return Signal