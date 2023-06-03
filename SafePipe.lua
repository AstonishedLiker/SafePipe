-- @ Classes
local PipeRemoteEvent = {}
local PipeRemoteFunction = {}

-- @ Lazy Functions
local assert = function(value: a, errorMessage: string?, level: number)
	local level = level or 1
	
	if not value then
		error(errorMessage, level + 1)
	end
	
	return value
end

local function IsNaN(Num: number)
	return Num ~= Num
end

local function IsNegative(Num: number)
	return Num < 0
end

-- @ Libraries
local Signal = require(script.Signal)

-- @ Safe version of FireClient Function for RemoteEvents
function PipeRemoteEvent:SafeFireClient(Client: Player, ...): (boolean, any)
	return pcall(self.Remote.FireServer, self.Remote, ...)
end

-- @ Safe version of InvokeClient Functions for RemoteFunctions
function PipeRemoteFunction:SafeInvokeClient(Client: Player, ...): ...any
	-- # We implement a timeout of 10 seconds (or self.Settings.Timeout) or until :InvokeClient stops yielding. If it's beyond the 10 seconds timeout, we error.
	local Timeout = self.Settings.Timeout or 10
	
	local Data, VarArg = nil, {...}; task.spawn(function()
		Data = {self.Remote:InvokeClient(Client, unpack(VarArg))}
	end)
	
	local CurrentClock = os.clock()
	repeat
		task.wait()
	until Data or os.clock() - CurrentClock >= Timeout
	
	if not Data then
		self.OnTimeoutSignal:Fire(Client)
		error(`Client yielded for too long (above the {Timeout} second(s) timeout)`, 2)
	end
	
	return unpack(Data)
end

-- @ Event Handler for RemoteEvents
function PipeRemoteEvent:ConnectOnServerEvent(CallBack: (...any) -> ...any): RBXScriptConnection
	--[[
		Arg Structure
		{
			[1] = {"string", "number"}
		}
	]]--
	return self.Remote.OnServerEvent:Connect(function(Player: Player, ...)
		local Args = {...}
		
		for Index, Types in pairs(self.Args) do
			if not table.find(Types, "any") then
				local Type = typeof(Args[Index])
				
				if not table.find(Types, Type) then
					self.OnBadArgumentSignal:Fire(Player, Index, Type, Types)
					error(`Invalid type for argument {Index} for remote "{self.Remote:GetFullName()}" (got {Type}, expected {table.concat(Types, ", ")})`, 2)
				end
				
				if Type == "number" then
					if self.Settings.AntiNaN and IsNaN(Args[Index]) then
						self.OnNaNArgumentSignal:Fire(Player, Index)
						error(`Invalid type for argument {Index} for remote "{self.Remote:GetFullName()}" (got NaN Number)`, 2)
					end
					
					if self.Settings.AntiNegative and IsNegative(Args[Index]) then
						self.OnNegativeArgumentSignal:Fire(Player, Index)
						error(`Invalid type for argument {Index} for remote "{self.Remote:GetFullName()}" (got Negative Number)`, 2)
					end
				end
			end
		end
		
		CallBack(Player, ...)
	end)
end

-- @ Event Handler for RemoteFunctions
function PipeRemoteFunction:ConnectOnServerInvoke(CallBack: (...any) -> ...any): nil
	self.Remote.OnServerInvoke = function(Player, ...)
		local Args = {...}

		for Index, Types in pairs(self.Args) do
			if not table.find(Types, "any") then
				local Type = typeof(Args[Index])

				if not table.find(Types, Type) then
					self.OnBadArgumentSignal:Fire(Player, Index, Type, Types)
					error(`Invalid type for argument {Index} for remote "{self.Remote:GetFullName()}" (got {Type}, expected {table.concat(Types, ", ")})`, 2)
				end

				if Type == "number" then
					if self.Settings.AntiNaN and IsNaN(Args[Index]) then
						self.OnNaNArgumentSignal:Fire(Player, Index)
						error(`Invalid type for argument {Index} for remote "{self.Remote:GetFullName()}" (got NaN Number)`, 2)
					end

					if self.Settings.AntiNegative and IsNegative(Args[Index]) then
						self.OnNegativeArgumentSignal:Fire(Player, Index)
						error(`Invalid type for argument {Index} for remote "{self.Remote:GetFullName()}" (got Negative Number)`, 2)
					end
				end
			end
		end

		return CallBack(Player, ...)
	end
end

return {
	new = function(Remote: RemoteFunction | RemoteEvent, Settings: {[string]: any}, Args: {[number]: {["Type"]: any}})
		return setmetatable({
			-- # Main Stuff
			Remote = Remote,
			Settings = Settings,
			Args = Args,
			
			-- # Defined Signals
			OnBadArgumentSignal = Signal.new(),
			OnNaNArgumentSignal = Signal.new(),
			OnNegativeArgumentSignal = Signal.new(),
			OnTimeoutSignal = Signal.new(),
		}, { __index = Remote:IsA("RemoteEvent") and PipeRemoteEvent or Remote:IsA("RemoteFunction") and PipeRemoteFunction })
	end,
}