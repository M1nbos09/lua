--[[
	Sigma Spy - Complete Standalone Version
	No external dependencies, no HTTP requests, no font files
	All modules compiled inline
]]

--// Base Configuration
local Configuration = {
	UseWorkspace = false, 
	NoActors = false,
	FolderName = "Sigma Spy",
}

--// Load overwrites from parameters
local Parameters = {...}
local Overwrites = Parameters[1]
if typeof(Overwrites) == "table" then
	for Key, Value in Overwrites do
		Configuration[Key] = Value
	end
end

--// Service handler
local Services = setmetatable({}, {
	__index = function(self, Name: string): Instance
		local Service = game:GetService(Name)
		return cloneref and cloneref(Service) or Service
	end,
})

--// ============================================
--// FLAGS MODULE
--// ============================================
local Flags = (function()
	local Module = {
		Flags = {
			NoComments = {
				Value = false,
				Label = "No comments",
			},
			SelectNewest = {
				Value = false,
				Label = "Auto select newest",
			},
			DecompilePopout = {
				Value = false,
				Label = "Pop-out decompiles",
			},
			IgnoreNil = {
				Value = true,
				Label = "Ignore nil parents",
			},
			LogExploit = {
				Value = true,
				Label = "Log exploit calls",
			},
			LogRecives = {
				Value = true,
				Label = "Log receives",
			},
			Paused = {
				Value = false,
				Label = "Paused",
				Keybind = Enum.KeyCode.Q
			},
			KeybindsEnabled = {
				Value = true,
				Label = "Keybinds Enabled"
			},
			FindStringForName = {
				Value = true,
				Label = "Find arg for name"
			},
			UiVisible = {
				Value = true,
				Label = "UI Visible",
				Keybind = Enum.KeyCode.P
			},
			NoTreeNodes = {
				Value = false,
				Label = "No grouping"
			},
			TableArgs = {
				Value = false,
				Label = "Table args"
			},
			NoVariables = {
				Value = false,
				Label = "No compression"
			}
		}
	}

	function Module:GetFlagValue(Name: string)
		local Flag = self:GetFlag(Name)
		return Flag.Value
	end

	function Module:SetFlagValue(Name: string, Value)
		local Flag = self:GetFlag(Name)
		Flag.Value = Value
	end

	function Module:SetFlagCallback(Name: string, Callback)
		local Flag = self:GetFlag(Name)
		Flag.Callback = Callback
	end

	function Module:SetFlagCallbacks(Dict: {})
		for Name, Callback in next, Dict do 
			self:SetFlagCallback(Name, Callback)
		end
	end

	function Module:GetFlag(Name: string)
		local AllFlags = self:GetFlags()
		local Flag = AllFlags[Name]
		assert(Flag, "Flag does not exist!")
		return Flag
	end

	function Module:AddFlag(Name: string, Flag)
		local AllFlags = self:GetFlags()
		AllFlags[Name] = Flag
	end

	function Module:GetFlags()
		return self.Flags
	end

	return Module
end)()

--// ============================================
--// COMMUNICATION MODULE
--// ============================================
local Communication = (function()
	local Module = {
		CommCallbacks = {}
	}

	local CommWrapper = {}
	CommWrapper.__index = CommWrapper

	local SerializeCache = setmetatable({}, {__mode = "k"})
	local DeserializeCache = setmetatable({}, {__mode = "k"})

	local CoreGui
	local Hook
	local Channel
	local Config
	local Process

	function Module:Init(Data)
		local Modules = Data.Modules
		local Services = Data.Services

		Hook = Modules.Hook
		Process = Modules.Process
		Config = Modules.Config or Config
		CoreGui = Services.CoreGui
	end

	function CommWrapper:Fire(...)
		local Queue = self.Queue
		table.insert(Queue, {...})
	end

	function CommWrapper:ProcessArguments(Arguments) 
		local Channel = self.Channel
		Channel:Fire(Process:Unpack(Arguments))
	end

	function CommWrapper:ProcessQueue()
		local Queue = self.Queue

		for Index = 1, #Queue do
			local Arguments = table.remove(Queue)
			pcall(function()
				self:ProcessArguments(Arguments) 
			end)
		end
	end

	function CommWrapper:BeginQueueService()
		coroutine.wrap(function()
			while wait() do
				self:ProcessQueue()
			end
		end)()
	end

	function Module:NewCommWrap(Channel)
		local Base = {
			Queue = setmetatable({}, {__mode = "v"}),
			Channel = Channel,
			Event = Channel.Event
		}

		local Wrapped = setmetatable(Base, CommWrapper)
		Wrapped:BeginQueueService()

		return Wrapped
	end

	function Module:MakeDebugIdHandler()
		local Remote = Instance.new("BindableFunction")
		function Remote.OnInvoke(Object: Instance): string
			return Object:GetDebugId()
		end

		self.DebugIdRemote = Remote
		self.DebugIdInvoke = Remote.Invoke

		return Remote
	end

	function Module:GetDebugId(Object: Instance): string
		local Invoke = self.DebugIdInvoke
		local Remote = self.DebugIdRemote
		return Invoke(Remote, Object)
	end

	function Module:GetHiddenParent(): Instance
		if gethui then return gethui() end
		return CoreGui
	end

	function Module:CreateCommChannel()
		local Force = Config.ForceUseCustomComm
		if create_comm_channel and not Force then
			return create_comm_channel()
		end

		local Parent = self:GetHiddenParent()
		local ChannelId = math.random(1, 10000000)

		local Channel = Instance.new("BindableEvent", Parent)
		Channel.Name = ChannelId

		return ChannelId, Channel
	end

	function Module:GetCommChannel(ChannelId: number)
		local Force = Config.ForceUseCustomComm
		if get_comm_channel and not Force then
			local Channel = get_comm_channel(ChannelId)
			return Channel, false
		end

		local Parent = self:GetHiddenParent()
		local Channel = Parent:FindFirstChild(ChannelId)

		local Wrapped = self:NewCommWrap(Channel)
		return Wrapped, true
	end

	function Module:CheckValue(Value, Inbound: boolean?)
		if typeof(Value) ~= "table" then 
			return Value 
		end
		
		if Inbound then
			return self:DeserializeTable(Value)
		end

		return self:SerializeTable(Value)
	end

	local Tick = 0
	function Module:WaitCheck()
		Tick += 1
		if Tick > 40 then
			Tick = 0
			wait()
		end
	end

	function Module:MakePacket(Index, Value): table
		self:WaitCheck()
		return {
			Index = self:CheckValue(Index), 
			Value = self:CheckValue(Value)
		}
	end

	function Module:ReadPacket(Packet: table)
		if typeof(Packet) ~= "table" then return Packet end
		
		local Key = self:CheckValue(Packet.Index, true)
		local Value = self:CheckValue(Packet.Value, true)
		self:WaitCheck()

		return Key, Value
	end

	function Module:SerializeTable(Table: table): table
		local Cached = SerializeCache[Table]
		if Cached then return Cached end

		local Serialized = {}
		SerializeCache[Table] = Serialized

		for Index, Value in next, Table do
			local Packet = self:MakePacket(Index, Value)
			table.insert(Serialized, Packet)
		end

		return Serialized
	end

	function Module:DeserializeTable(Serialized: table): table
		local Cached = DeserializeCache[Serialized]
		if Cached then return Cached end

		local Table = {}
		DeserializeCache[Serialized] = Table
		
		for _, Packet in next, Serialized do
			local Index, Value = self:ReadPacket(Packet)
			if Index == nil then continue end

			Table[Index] = Value
		end

		return Table
	end

	function Module:SetChannel(NewChannel: number)
		Channel = NewChannel
	end

	function Module:ConsolePrint(...)
		self:Communicate("Print", ...)
	end

	function Module:QueueLog(Data)
		spawn(function()
			local SerializedArgs = self:SerializeTable(Data.Args)
			Data.Args = SerializedArgs

			self:Communicate("QueueLog", Data)
		end)
	end

	function Module:AddCommCallback(Type: string, Callback)
		local CommCallbacks = self.CommCallbacks
		CommCallbacks[Type] = Callback
	end

	function Module:GetCommCallback(Type: string)
		local CommCallbacks = self.CommCallbacks
		return CommCallbacks[Type]
	end

	function Module:ChannelIndex(Channel, Property: string)
		if typeof(Channel) == "Instance" then
			return Hook:Index(Channel, Property)
		end

		return Channel[Property]
	end

	function Module:Communicate(...)
		local Fire = self:ChannelIndex(Channel, "Fire")
		Fire(Channel, ...)
	end

	function Module:AddConnection(Callback)
		local Event = self:ChannelIndex(Channel, "Event")
		return Event:Connect(Callback)
	end

	function Module:AddTypeCallback(Type: string, Callback)
		local Event = self:ChannelIndex(Channel, "Event")
		return Event:Connect(function(RecivedType: string, ...)
			if RecivedType ~= Type then return end
			Callback(...)
		end)
	end

	function Module:AddTypeCallbacks(Types: table)
		for Type: string, Callback in next, Types do
			self:AddTypeCallback(Type, Callback)
		end
	end

	function Module:CreateChannel(): number
		local ChannelID, Event = self:CreateCommChannel()

		Event.Event:Connect(function(Type: string, ...)
			local Callback = self:GetCommCallback(Type)
			if Callback then
				Callback(...)
			end
		end)

		return ChannelID, Event
	end

	Module:MakeDebugIdHandler()

	return Module
end)()

--// ============================================
--// PROCESS MODULE
--// ============================================
local Process = (function()
	local Module = {
		RemoteClassData = {
			["RemoteEvent"] = {
				Send = {
					"FireServer",
					"fireServer",
				},
				Receive = {
					"OnClientEvent",
				}
			},
			["RemoteFunction"] = {
				IsRemoteFunction = true,
				Send = {
					"InvokeServer",
					"invokeServer",
				},
				Receive = {
					"OnClientInvoke",
				}
			},
			["UnreliableRemoteEvent"] = {
				Send = {
					"FireServer",
					"fireServer",
				},
				Receive = {
					"OnClientEvent",
				}
			},
			["BindableEvent"] = {
				NoReciveHook = true,
				Send = {
					"Fire",
				},
				Receive = {
					"Event",
				}
			},
			["BindableFunction"] = {
				IsRemoteFunction = true,
				NoReciveHook = true,
				Send = {
					"Invoke",
				},
				Receive = {
					"OnInvoke",
				}
			}
		},
		RemoteOptions = {},
		LoopingRemotes = {},
		ConfigOverwrites = {
			[{"sirhurt", "potassium", "wave"}] = {
				ForceUseCustomComm = true
			}
		}
	}

	local Hook
	local Communication
	local ReturnSpoofs = {}
	local Ui
	local Config = {}
	local HttpService
	local Channel
	local WrappedChannel = false
	local SigmaENV = getfenv(1)

	function Module:Merge(Base: table, New: table)
		if not New then return end
		for Key, Value in next, New do
			Base[Key] = Value
		end
	end

	function Module:Init(Data)
		local Modules = Data.Modules
		local Services = Data.Services

		HttpService = Services.HttpService
		Config = Modules.Config or {}
		Ui = Modules.Ui
		Hook = Modules.Hook
		Communication = Modules.Communication
		ReturnSpoofs = Modules.ReturnSpoofs or {}
	end

	function Module:SetChannel(NewChannel, IsWrapped: boolean)
		Channel = NewChannel
		WrappedChannel = IsWrapped
	end

	function Module:GetConfigOverwrites(Name: string)
		local ConfigOverwrites = self.ConfigOverwrites

		for List, Overwrites in next, ConfigOverwrites do
			if not table.find(List, Name) then continue end
			return Overwrites
		end
		return
	end

	function Module:CheckConfig(Config: table)
		local Name = identifyexecutor():lower()

		local Overwrites = self:GetConfigOverwrites(Name)
		if not Overwrites then return end

		self:Merge(Config, Overwrites)
	end

	function Module:CleanCError(Error: string): string
		Error = Error:gsub(":%d+: ", "")
		Error = Error:gsub(", got %a+", "")
		Error = Error:gsub("invalid argument", "missing argument")
		return Error
	end

	function Module:CountMatches(String: string, Match: string): number
		local Count = 0
		for _ in String:gmatch(Match) do
			Count +=1 
		end
		return Count
	end

	function Module:CheckValue(Value, Ignore: table?, Cache: table?)
		local Type = typeof(Value)
		Communication:WaitCheck()
		
		if Type == "table" then
			Value = self:DeepCloneTable(Value, Ignore, Cache)
		elseif Type == "Instance" then
			Value = cloneref and cloneref(Value) or Value
		end
		
		return Value
	end

	function Module:DeepCloneTable(Table, Ignore: table?, Visited: table?): table
		if typeof(Table) ~= "table" then return Table end
		local Cache = Visited or {}

		if Cache[Table] then
			return Cache[Table]
		end

		local New = {}
		Cache[Table] = New

		for Key, Value in next, Table do
			if Ignore and table.find(Ignore, Value) then continue end
			
			Key = self:CheckValue(Key, Ignore, Cache)
			New[Key] = self:CheckValue(Value, Ignore, Cache)
		end

		if not Visited then
			table.clear(Cache)
		end
		
		return New
	end

	function Module:Unpack(Table: table)
		if not Table then return Table end
		local Length = table.maxn(Table)
		return unpack(Table, 1, Length)
	end

	function Module:PushConfig(Overwrites)
		self:Merge(self, Overwrites)
	end

	function Module:FuncExists(Name: string)
		return SigmaENV[Name]
	end

	function Module:CheckExecutor(): boolean
		local Blacklisted = {
			"xeno",
			"solara",
			"jjsploit"
		}

		local Name = identifyexecutor():lower()
		local IsBlacklisted = table.find(Blacklisted, Name)

		if IsBlacklisted then
			if Ui then
				Ui:ShowUnsupportedExecutor(Name)
			end
			return false
		end

		return true
	end

	function Module:CheckFunctions(): boolean
		local CoreFunctions = {
			"hookmetamethod",
			"hookfunction",
			"getrawmetatable",
			"setreadonly"
		}

		for _, Name in CoreFunctions do
			local Func = self:FuncExists(Name)
			if Func then continue end

			if Ui then
				Ui:ShowUnsupported(Name)
			end
			return false
		end

		return true
	end

	function Module:CheckIsSupported(): boolean
		local ExecutorSupported = self:CheckExecutor()
		if not ExecutorSupported then
			return false
		end

		local FunctionsSupported = self:CheckFunctions()
		if not FunctionsSupported then
			return false
		end

		return true
	end

	function Module:GetClassData(Remote: Instance): table?
		local RemoteClassData = self.RemoteClassData
		local ClassName = Hook:Index(Remote, "ClassName")

		return RemoteClassData[ClassName]
	end

	function Module:IsProtectedRemote(Remote: Instance): boolean
		local IsDebug = Remote == Communication.DebugIdRemote
		local IsChannel = Remote == (WrappedChannel and Channel.Channel or Channel)

		return IsDebug or IsChannel
	end

	function Module:RemoteAllowed(Remote: Instance, TransferType: string, Method: string?): boolean?
		if typeof(Remote) ~= 'Instance' then return end
		
		if self:IsProtectedRemote(Remote) then return end

		local ClassData = self:GetClassData(Remote)
		if not ClassData then return end

		local Allowed = ClassData[TransferType]
		if not Allowed then return end

		if Method then
			return table.find(Allowed, Method) ~= nil
		end

		return true
	end

	function Module:SetExtraData(Data: table)
		if not Data then return end
		self.ExtraData = Data
	end

	function Module:GetRemoteSpoof(Remote: Instance, Method: string, ...): table?
		local Spoof = ReturnSpoofs[Remote]

		if not Spoof then return end
		if Spoof.Method ~= Method then return end

		local ReturnValues = Spoof.Return

		if typeof(ReturnValues) == "function" then
			ReturnValues = ReturnValues(...)
		end

		return ReturnValues
	end

	function Module:SetNewReturnSpoofs(NewReturnSpoofs: table)
		ReturnSpoofs = NewReturnSpoofs
	end

	function Module:FindCallingLClosure(Offset: number)
		local Getfenv = Hook:GetOriginalFunc(getfenv)
		Offset += 1

		while true do
			Offset += 1

			local IsValid = debug.info(Offset, "l") ~= -1
			if not IsValid then continue end

			local Function = debug.info(Offset, "f")
			if not Function then return end
			if Getfenv(Function) == SigmaENV then continue end

			return Function
		end
	end

	function Module:Decompile(Script): string
		if decompile then 
			return decompile(Script)
		end

		local Success, Bytecode = pcall(getscriptbytecode, Script)
		if not Success then
			local Error = `--Failed to get script bytecode, error:\n`
			Error ..= `\n--[[\n{Bytecode}\n]]`
			return Error, true
		end
		
		return "--Decompilation not available on this executor", true
	end

	function Module:GetScriptFromFunc(Func)
		if not Func then return end

		local Success, ENV = pcall(getfenv, Func)
		if not Success then return end
		
		if self:IsSigmaSpyENV(ENV) then return end

		return rawget(ENV, "script")
	end

	function Module:ConnectionIsValid(Connection: table): boolean
		local ValueReplacements = {
			["Script"] = function(Connection: table)
				local Function = Connection.Function
				if not Function then return end

				return self:GetScriptFromFunc(Function)
			end
		}

		local ToCheck = {
			"Script"
		}
		for _, Property in ToCheck do
			local Replacement = ValueReplacements[Property]
			local Value

			if Replacement then
				Value = Replacement(Connection)
			end

			if Value == nil then 
				return false 
			end
		end

		return true
	end

	function Module:FilterConnections(Signal): table
		local Processed = {}

		for _, Connection in getconnections(Signal) do
			if not self:ConnectionIsValid(Connection) then continue end
			table.insert(Processed, Connection)
		end

		return Processed
	end

	function Module:IsSigmaSpyENV(Env: table): boolean
		return Env == SigmaENV
	end

	function Module:GetRemoteData(Id: string)
		local RemoteOptions = self.RemoteOptions

		local Existing = RemoteOptions[Id]
		if Existing then return Existing end
		
		local Data = {
			Excluded = false,
			Blocked = false
		}

		RemoteOptions[Id] = Data
		return Data
	end

	local ProcessCallback = newcclosure(function(Data, Remote, ...)
		local OriginalFunc = Data.OriginalFunc
		local Id = Data.Id
		local Method = Data.Method

		local RemoteData = Module:GetRemoteData(Id)
		if RemoteData.Blocked then return {} end

		local Spoof = Module:GetRemoteSpoof(Remote, Method, OriginalFunc, ...)
		if Spoof then return Spoof end

		if not OriginalFunc then return end

		return {
			OriginalFunc(Remote, ...)
		}
	end)

	function Module:ProcessRemote(Data, Remote, ...)
		local Method = Data.Method
		local TransferType = Data.TransferType
		local IsReceive = Data.IsReceive

		if TransferType and not self:RemoteAllowed(Remote, TransferType, Method) then return end

		local Id = Communication:GetDebugId(Remote)
		local ClassData = self:GetClassData(Remote)
		local Timestamp = tick()

		local CallingFunction
		local SourceScript

		local ExtraData = self.ExtraData
		if ExtraData then
			self:Merge(Data, ExtraData)
		end

		if not IsReceive then
			CallingFunction = self:FindCallingLClosure(6)
			SourceScript = CallingFunction and self:GetScriptFromFunc(CallingFunction) or nil
		end

		self:Merge(Data, {
			Remote = cloneref and cloneref(Remote) or Remote,
			CallingScript = getcallingscript and getcallingscript() or nil,
			CallingFunction = CallingFunction,
			SourceScript = SourceScript,
			Id = Id,
			ClassData = ClassData,
			Timestamp = Timestamp,
			Args = {...}
		})

		local ReturnValues = ProcessCallback(Data, Remote, ...)
		Data.ReturnValues = ReturnValues

		Communication:QueueLog(Data)

		return ReturnValues
	end

	function Module:SetAllRemoteData(Key: string, Value)
		local RemoteOptions = self.RemoteOptions
		for RemoteID, Data in next, RemoteOptions do
			Data[Key] = Value
		end
	end

	function Module:SetRemoteData(Id: string, RemoteData: table)
		local RemoteOptions = self.RemoteOptions
		RemoteOptions[Id] = RemoteData
	end

	function Module:UpdateRemoteData(Id: string, RemoteData: table)
		Communication:Communicate("RemoteData", Id, RemoteData)
	end

	function Module:UpdateAllRemoteData(Key: string, Value)
		Communication:Communicate("AllRemoteData", Key, Value)
	end

	return Module
end)()

--// ============================================
--// HOOK MODULE
--// ============================================
local Hook = (function()
	local Hook = {
		OriginalNamecall = nil,
		OriginalIndex = nil,
		PreviousFunctions = {},
		DefaultConfig = {
			FunctionPatches = true
		}
	}

	local Modules
	local Process
	local Configuration
	local Config = {}
	local Communication

	local ExeENV = getfenv(1)

	function Hook:Init(Data)
		Modules = Data.Modules

		Process = Modules.Process
		Communication = Modules.Communication or Communication
		Config = Modules.Config or {}
		Configuration = Modules.Configuration or Configuration
	end

	local HookMiddle = newcclosure(function(OriginalFunc, Callback, AlwaysTable: boolean?, ...)
		local ReturnValues = Callback(...)
		if ReturnValues then
			if not AlwaysTable then
				return Process:Unpack(ReturnValues)
			end

			return ReturnValues
		end

		if AlwaysTable then
			return {OriginalFunc(...)}
		end

		return OriginalFunc(...)
	end)

	local function Merge(Base: table, New: table)
		for Key, Value in next, New do
			Base[Key] = Value
		end
	end

	function Hook:Index(Object: Instance, Key: string)
		return Object[Key]
	end

	function Hook:PushConfig(Overwrites)
		Merge(self, Overwrites)
	end

	function Hook:ReplaceMetaMethod(Object: Instance, Call: string, Callback)
		local Metatable = getrawmetatable(Object)
		local OriginalFunc = clonefunction(Metatable[Call])
		
		setreadonly(Metatable, false)
		Metatable[Call] = newcclosure(function(...)
			return HookMiddle(OriginalFunc, Callback, false, ...)
		end)
		setreadonly(Metatable, true)

		return OriginalFunc
	end

	function Hook:HookFunction(Func, Callback)
		local OriginalFunc
		local WrappedCallback = newcclosure(Callback)
		OriginalFunc = clonefunction(hookfunction(Func, function(...)
			return HookMiddle(OriginalFunc, WrappedCallback, false, ...)
		end))
		return OriginalFunc
	end

	function Hook:HookMetaCall(Object: Instance, Call: string, Callback)
		local Metatable = getrawmetatable(Object)
		local Unhooked
		
		Unhooked = self:HookFunction(Metatable[Call], function(...)
			return HookMiddle(Unhooked, Callback, true, ...)
		end)
		return Unhooked
	end

	function Hook:HookMetaMethod(Object: Instance, Call: string, Callback)
		local Func = newcclosure(Callback)
		
		if Config.ReplaceMetaCallFunc then
			return self:ReplaceMetaMethod(Object, Call, Func)
		end
		
		return self:HookMetaCall(Object, Call, Func)
	end

	function Hook:PatchFunctions()
		if Config.NoFunctionPatching then return end

		local Patches = {
			[pcall] =  function(OldFunc, Func, ...)
				local Responce = {OldFunc(Func, ...)}
				local Success, Error = Responce[1], Responce[2]
				local IsC = iscclosure(Func)

				if Success == false and IsC then
					local NewError = Process:CleanCError(Error)
					Responce[2] = NewError
				end

				if Success == false and not IsC and Error:find("C stack overflow") then
					local Tracetable = Error:split(":")
					local Caller, Line = Tracetable[1], Tracetable[2]
					local Count = Process:CountMatches(Error, Caller)

					if Count == 196 then
						Communication:ConsolePrint(`C stack overflow patched, count was {Count}`)
						Responce[2] = Error:gsub(`{Caller}:{Line}: `, Caller, 1)
					end
				end

				return Responce
			end,
			[getfenv] = function(OldFunc, Level: number, ...)
				Level = Level or 1

				if type(Level) == "number" then
					Level += 2
				end

				local Responce = {OldFunc(Level, ...)}
				local ENV = Responce[1]

				if not checkcaller() and ENV == ExeENV then
					Communication:ConsolePrint("ENV escape patched")
					return OldFunc(999999, ...)
				end

				return Responce
			end
		}

		for Func, CallBack in Patches do
			local Wrapped = newcclosure(CallBack)
			local OldFunc; OldFunc = self:HookFunction(Func, function(...)
				return Wrapped(OldFunc, ...)
			end)

			self.PreviousFunctions[Func] = OldFunc
		end
	end

	function Hook:GetOriginalFunc(Func)
		return self.PreviousFunctions[Func] or Func
	end

	function Hook:RunOnActors(Code: string, ChannelId: number)
		if not getactors or not run_on_actor then return end
		
		local Actors = getactors()
		if not Actors then return end
		
		for _, Actor in Actors do 
			pcall(run_on_actor, Actor, Code, ChannelId)
		end
	end

	local function ProcessRemote(OriginalFunc, MetaMethod: string, self, Method: string, ...)
		return Process:ProcessRemote({
			Method = Method,
			OriginalFunc = OriginalFunc,
			MetaMethod = MetaMethod,
			TransferType = "Send",
			IsExploit = checkcaller()
		}, self, ...)
	end

	function Hook:HookRemoteTypeIndex(ClassName: string, FuncName: string)
		local Remote = Instance.new(ClassName)
		local Func = Remote[FuncName]
		local OriginalFunc

		OriginalFunc = self:HookFunction(Func, function(self, ...)
			if not Process:RemoteAllowed(self, "Send", FuncName) then return end

			return ProcessRemote(OriginalFunc, "__index", self, FuncName, ...)
		end)
	end

	function Hook:HookRemoteIndexes()
		local RemoteClassData = Process.RemoteClassData
		for ClassName, Data in RemoteClassData do
			local FuncName = Data.Send[1]
			self:HookRemoteTypeIndex(ClassName, FuncName)
		end
	end

	function Hook:BeginHooks()
		self:HookRemoteIndexes()

		local OriginalNameCall
		OriginalNameCall = self:HookMetaMethod(game, "__namecall", function(self, ...)
			local Method = getnamecallmethod()
			return ProcessRemote(OriginalNameCall, "__namecall", self, Method, ...)
		end)

		Merge(self, {
			OriginalNamecall = OriginalNameCall,
		})
	end

	function Hook:HookClientInvoke(Remote, Method, Callback)
		local Success, Function = pcall(function()
			return getcallbackvalue(Remote, Method)
		end)

		if not Success then return end
		if not Function then return end
		
		local HookSuccess = pcall(function()
			self:HookFunction(Function, Callback)
		end)
		if HookSuccess then return end

		Remote[Method] = function(...)
			return HookMiddle(Function, Callback, false, ...)
		end
	end

	function Hook:MultiConnect(Remotes)
		for _, Remote in next, Remotes do
			self:ConnectClientRecive(Remote)
		end
	end

	function Hook:ConnectClientRecive(Remote)
		local Allowed = Process:RemoteAllowed(Remote, "Receive")
		if not Allowed then return end

		local ClassData = Process:GetClassData(Remote)
		local IsRemoteFunction = ClassData.IsRemoteFunction
		local NoReciveHook = ClassData.NoReciveHook
		local Method = ClassData.Receive[1]

		if NoReciveHook then return end

		local function Callback(...)
			return Process:ProcessRemote({
				Method = Method,
				IsReceive = true,
				MetaMethod = "Connect",
				IsExploit = checkcaller()
			}, Remote, ...)
		end

		if not IsRemoteFunction then
			Remote[Method]:Connect(Callback)
		else
			self:HookClientInvoke(Remote, Method, Callback)
		end
	end

	function Hook:BeginService(Libraries, ExtraData, ChannelId, ...)
		local ReturnSpoofs = Libraries.ReturnSpoofs
		local ProcessLib = Libraries.Process
		local Communication = Libraries.Communication
		local Config = Libraries.Config

		ProcessLib:CheckConfig(Config)

		local InitData = {
			Modules = {
				ReturnSpoofs = ReturnSpoofs,
				Communication = Communication,
				Process = ProcessLib,
				Config = Config,
				Hook = self
			},
			Services = setmetatable({}, {
				__index = function(self, Name: string): Instance
					local Service = game:GetService(Name)
					return cloneref and cloneref(Service) or Service
				end,
			})
		}

		Communication:Init(InitData)
		ProcessLib:Init(InitData)

		local Channel, IsWrapped = Communication:GetCommChannel(ChannelId)
		Communication:SetChannel(Channel)
		Communication:AddTypeCallbacks({
			["RemoteData"] = function(Id: string, RemoteData)
				ProcessLib:SetRemoteData(Id, RemoteData)
			end,
			["AllRemoteData"] = function(Key: string, Value)
				ProcessLib:SetAllRemoteData(Key, Value)
			end,
			["UpdateSpoofs"] = function(Content: string)
				local Spoofs = loadstring(Content)()
				ProcessLib:SetNewReturnSpoofs(Spoofs)
			end,
			["BeginHooks"] = function(Config)
				if Config.PatchFunctions then
					self:PatchFunctions()
				end
				self:BeginHooks()
				Communication:ConsolePrint("Hooks loaded")
			end
		})
		
		ProcessLib:SetChannel(Channel, IsWrapped)
		ProcessLib:SetExtraData(ExtraData)

		self:Init(InitData)

		if ExtraData and ExtraData.IsActor then
			Communication:ConsolePrint("Actor connected!")
		end
	end

	function Hook:LoadMetaHooks(ActorCode: string, ChannelId: number)
		if not Configuration.NoActors then
			self:RunOnActors(ActorCode, ChannelId)
		end

		self:BeginService({
			Process = Process,
			Communication = Communication,
			Config = Config,
			ReturnSpoofs = {}
		}, nil, ChannelId) 
	end

	function Hook:LoadReceiveHooks()
		local NoReceiveHooking = Config.NoReceiveHooking
		local BlackListedServices = Config.BlackListedServices or {}

		if NoReceiveHooking then return end

		game.DescendantAdded:Connect(function(Remote)
			self:ConnectClientRecive(Remote)
		end)

		self:MultiConnect(getnilinstances and getnilinstances() or {})

		for _, Service in next, game:GetChildren() do
			if table.find(BlackListedServices, Service.ClassName) then continue end
			self:MultiConnect(Service:GetDescendants())
		end
	end

	function Hook:LoadHooks(ActorCode: string, ChannelId: number)
		self:LoadMetaHooks(ActorCode, ChannelId)
		self:LoadReceiveHooks()
	end

	return Hook
end)()

--// ============================================
--// SIMPLE UI MODULE (CONSOLE ONLY)
--// ============================================
local Ui = (function()
	local Module = {}
	
	function Module:Init(Data)
		print("[Sigma Spy] Initialized")
	end

	function Module:ShowUnsupportedExecutor(Name)
		warn(`[Sigma Spy] Unsupported executor: {Name}`)
	end

	function Module:ShowUnsupported(FuncName)
		warn(`[Sigma Spy] Missing function: {FuncName}`)
	end

	function Module:QueueLog(Data)
		local Remote = Data.Remote
		local Method = Data.Method
		local Args = Data.Args
		
		print(`[Sigma Spy] {Remote.ClassName}:{Method}() - Args: {#Args}`)
	end

	function Module:ConsoleLog(...)
		print("[Sigma Spy]", ...)
	end

	function Module:SetCommChannel(Event)
	end

	function Module:BeginLogService()
	end

	function Module:AskUser(Data)
		return "Yes"
	end

	return Module
end)()

--// ============================================
--// SIMPLE CONFIG MODULE
--// ============================================
local Config = {
	ForceUseCustomComm = false,
	NoReceiveHooking = false,
	NoFunctionPatching = false,
	BlackListedServices = {"CoreGui", "Players"}
}

--// ============================================
--// INITIALIZE
--// ============================================
local Modules = {
	Flags = Flags,
	Communication = Communication,
	Process = Process,
	Hook = Hook,
	Ui = Ui,
	Config = Config,
	Configuration = Configuration,
	ReturnSpoofs = {}
}

Process:CheckConfig(Config)

local InitData = {
	Modules = Modules,
	Services = Services
}

Communication:Init(InitData)
Process:Init(InitData)
Hook:Init(InitData)
Ui:Init(InitData)

local Supported = Process:CheckIsSupported()
if not Supported then 
	warn("[Sigma Spy] Not supported on this executor")
	return
end

local ChannelId, Event = Communication:CreateChannel()

Communication:AddCommCallback("QueueLog", function(...)
	Ui:QueueLog(...)
end)

Communication:AddCommCallback("Print", function(...)
	Ui:ConsoleLog(...)
end)

Ui:SetCommChannel(Event)
Ui:BeginLogService()

ActorCode = [==[
local Process = (function()
	local Module = {
		RemoteClassData = {
			["RemoteEvent"] = {
				Send = {
					"FireServer",
					"fireServer",
				},
				Receive = {
					"OnClientEvent",
				}
			},
			["RemoteFunction"] = {
				IsRemoteFunction = true,
				Send = {
					"InvokeServer",
					"invokeServer",
				},
				Receive = {
					"OnClientInvoke",
				}
			},
			["UnreliableRemoteEvent"] = {
				Send = {
					"FireServer",
					"fireServer",
				},
				Receive = {
					"OnClientEvent",
				}
			},
			["BindableEvent"] = {
				NoReciveHook = true,
				Send = {
					"Fire",
				},
				Receive = {
					"Event",
				}
			},
			["BindableFunction"] = {
				IsRemoteFunction = true,
				NoReciveHook = true,
				Send = {
					"Invoke",
				},
				Receive = {
					"OnInvoke",
				}
			}
		},
		RemoteOptions = {},
		LoopingRemotes = {},
		ConfigOverwrites = {
			[{"sirhurt", "potassium", "wave"}] = {
				ForceUseCustomComm = true
			}
		}
	}

	local Hook
	local Communication
	local ReturnSpoofs = {}
	local Ui
	local Config = {}
	local HttpService
	local Channel
	local WrappedChannel = false
	local SigmaENV = getfenv(1)

	function Module:Merge(Base: table, New: table)
		if not New then return end
		for Key, Value in next, New do
			Base[Key] = Value
		end
	end

	function Module:Init(Data)
		local Modules = Data.Modules
		local Services = Data.Services

		HttpService = Services.HttpService
		Config = Modules.Config or {}
		Ui = Modules.Ui
		Hook = Modules.Hook
		Communication = Modules.Communication
		ReturnSpoofs = Modules.ReturnSpoofs or {}
	end

	function Module:SetChannel(NewChannel, IsWrapped: boolean)
		Channel = NewChannel
		WrappedChannel = IsWrapped
	end

	function Module:GetConfigOverwrites(Name: string)
		local ConfigOverwrites = self.ConfigOverwrites

		for List, Overwrites in next, ConfigOverwrites do
			if not table.find(List, Name) then continue end
			return Overwrites
		end
		return
	end

	function Module:CheckConfig(Config: table)
		local Name = identifyexecutor():lower()

		local Overwrites = self:GetConfigOverwrites(Name)
		if not Overwrites then return end

		self:Merge(Config, Overwrites)
	end

	function Module:CleanCError(Error: string): string
		Error = Error:gsub(":%d+: ", "")
		Error = Error:gsub(", got %a+", "")
		Error = Error:gsub("invalid argument", "missing argument")
		return Error
	end

	function Module:CountMatches(String: string, Match: string): number
		local Count = 0
		for _ in String:gmatch(Match) do
			Count +=1 
		end
		return Count
	end

	function Module:CheckValue(Value, Ignore: table?, Cache: table?)
		local Type = typeof(Value)
		Communication:WaitCheck()
		
		if Type == "table" then
			Value = self:DeepCloneTable(Value, Ignore, Cache)
		elseif Type == "Instance" then
			Value = cloneref and cloneref(Value) or Value
		end
		
		return Value
	end

	function Module:DeepCloneTable(Table, Ignore: table?, Visited: table?): table
		if typeof(Table) ~= "table" then return Table end
		local Cache = Visited or {}

		if Cache[Table] then
			return Cache[Table]
		end

		local New = {}
		Cache[Table] = New

		for Key, Value in next, Table do
			if Ignore and table.find(Ignore, Value) then continue end
			
			Key = self:CheckValue(Key, Ignore, Cache)
			New[Key] = self:CheckValue(Value, Ignore, Cache)
		end

		if not Visited then
			table.clear(Cache)
		end
		
		return New
	end

	function Module:Unpack(Table: table)
		if not Table then return Table end
		local Length = table.maxn(Table)
		return unpack(Table, 1, Length)
	end

	function Module:PushConfig(Overwrites)
		self:Merge(self, Overwrites)
	end

	function Module:FuncExists(Name: string)
		return SigmaENV[Name]
	end

	function Module:CheckExecutor(): boolean
		local Blacklisted = {
			"xeno",
			"solara",
			"jjsploit"
		}

		local Name = identifyexecutor():lower()
		local IsBlacklisted = table.find(Blacklisted, Name)

		if IsBlacklisted then
			if Ui then
				Ui:ShowUnsupportedExecutor(Name)
			end
			return false
		end

		return true
	end

	function Module:CheckFunctions(): boolean
		local CoreFunctions = {
			"hookmetamethod",
			"hookfunction",
			"getrawmetatable",
			"setreadonly"
		}

		for _, Name in CoreFunctions do
			local Func = self:FuncExists(Name)
			if Func then continue end

			if Ui then
				Ui:ShowUnsupported(Name)
			end
			return false
		end

		return true
	end

	function Module:CheckIsSupported(): boolean
		local ExecutorSupported = self:CheckExecutor()
		if not ExecutorSupported then
			return false
		end

		local FunctionsSupported = self:CheckFunctions()
		if not FunctionsSupported then
			return false
		end

		return true
	end

	function Module:GetClassData(Remote: Instance): table?
		local RemoteClassData = self.RemoteClassData
		local ClassName = Hook:Index(Remote, "ClassName")

		return RemoteClassData[ClassName]
	end

	function Module:IsProtectedRemote(Remote: Instance): boolean
		local IsDebug = Remote == Communication.DebugIdRemote
		local IsChannel = Remote == (WrappedChannel and Channel.Channel or Channel)

		return IsDebug or IsChannel
	end

	function Module:RemoteAllowed(Remote: Instance, TransferType: string, Method: string?): boolean?
		if typeof(Remote) ~= 'Instance' then return end
		
		if self:IsProtectedRemote(Remote) then return end

		local ClassData = self:GetClassData(Remote)
		if not ClassData then return end

		local Allowed = ClassData[TransferType]
		if not Allowed then return end

		if Method then
			return table.find(Allowed, Method) ~= nil
		end

		return true
	end

	function Module:SetExtraData(Data: table)
		if not Data then return end
		self.ExtraData = Data
	end

	function Module:GetRemoteSpoof(Remote: Instance, Method: string, ...): table?
		local Spoof = ReturnSpoofs[Remote]

		if not Spoof then return end
		if Spoof.Method ~= Method then return end

		local ReturnValues = Spoof.Return

		if typeof(ReturnValues) == "function" then
			ReturnValues = ReturnValues(...)
		end

		return ReturnValues
	end

	function Module:SetNewReturnSpoofs(NewReturnSpoofs: table)
		ReturnSpoofs = NewReturnSpoofs
	end

	function Module:FindCallingLClosure(Offset: number)
		local Getfenv = Hook:GetOriginalFunc(getfenv)
		Offset += 1

		while true do
			Offset += 1

			local IsValid = debug.info(Offset, "l") ~= -1
			if not IsValid then continue end

			local Function = debug.info(Offset, "f")
			if not Function then return end
			if Getfenv(Function) == SigmaENV then continue end

			return Function
		end
	end

	function Module:Decompile(Script): string
		if decompile then 
			return decompile(Script)
		end

		local Success, Bytecode = pcall(getscriptbytecode, Script)
		if not Success then
			local Error = `--Failed to get script bytecode, error:\n`
			Error ..= `\n--[[\n{Bytecode}\n]]`
			return Error, true
		end
		
		return "--Decompilation not available on this executor", true
	end

	function Module:GetScriptFromFunc(Func)
		if not Func then return end

		local Success, ENV = pcall(getfenv, Func)
		if not Success then return end
		
		if self:IsSigmaSpyENV(ENV) then return end

		return rawget(ENV, "script")
	end

	function Module:ConnectionIsValid(Connection: table): boolean
		local ValueReplacements = {
			["Script"] = function(Connection: table)
				local Function = Connection.Function
				if not Function then return end

				return self:GetScriptFromFunc(Function)
			end
		}

		local ToCheck = {
			"Script"
		}
		for _, Property in ToCheck do
			local Replacement = ValueReplacements[Property]
			local Value

			if Replacement then
				Value = Replacement(Connection)
			end

			if Value == nil then 
				return false 
			end
		end

		return true
	end

	function Module:FilterConnections(Signal): table
		local Processed = {}

		for _, Connection in getconnections(Signal) do
			if not self:ConnectionIsValid(Connection) then continue end
			table.insert(Processed, Connection)
		end

		return Processed
	end

	function Module:IsSigmaSpyENV(Env: table): boolean
		return Env == SigmaENV
	end

	function Module:GetRemoteData(Id: string)
		local RemoteOptions = self.RemoteOptions

		local Existing = RemoteOptions[Id]
		if Existing then return Existing end
		
		local Data = {
			Excluded = false,
			Blocked = false
		}

		RemoteOptions[Id] = Data
		return Data
	end

	local ProcessCallback = newcclosure(function(Data, Remote, ...)
		local OriginalFunc = Data.OriginalFunc
		local Id = Data.Id
		local Method = Data.Method

		local RemoteData = Module:GetRemoteData(Id)
		if RemoteData.Blocked then return {} end

		local Spoof = Module:GetRemoteSpoof(Remote, Method, OriginalFunc, ...)
		if Spoof then return Spoof end

		if not OriginalFunc then return end

		return {
			OriginalFunc(Remote, ...)
		}
	end)

	function Module:ProcessRemote(Data, Remote, ...)
		local Method = Data.Method
		local TransferType = Data.TransferType
		local IsReceive = Data.IsReceive

		if TransferType and not self:RemoteAllowed(Remote, TransferType, Method) then return end

		local Id = Communication:GetDebugId(Remote)
		local ClassData = self:GetClassData(Remote)
		local Timestamp = tick()

		local CallingFunction
		local SourceScript

		local ExtraData = self.ExtraData
		if ExtraData then
			self:Merge(Data, ExtraData)
		end

		if not IsReceive then
			CallingFunction = self:FindCallingLClosure(6)
			SourceScript = CallingFunction and self:GetScriptFromFunc(CallingFunction) or nil
		end

		self:Merge(Data, {
			Remote = cloneref and cloneref(Remote) or Remote,
			CallingScript = getcallingscript and getcallingscript() or nil,
			CallingFunction = CallingFunction,
			SourceScript = SourceScript,
			Id = Id,
			ClassData = ClassData,
			Timestamp = Timestamp,
			Args = {...}
		})

		local ReturnValues = ProcessCallback(Data, Remote, ...)
		Data.ReturnValues = ReturnValues

		Communication:QueueLog(Data)

		return ReturnValues
	end

	function Module:SetAllRemoteData(Key: string, Value)
		local RemoteOptions = self.RemoteOptions
		for RemoteID, Data in next, RemoteOptions do
			Data[Key] = Value
		end
	end

	function Module:SetRemoteData(Id: string, RemoteData: table)
		local RemoteOptions = self.RemoteOptions
		RemoteOptions[Id] = RemoteData
	end

	function Module:UpdateRemoteData(Id: string, RemoteData: table)
		Communication:Communicate("RemoteData", Id, RemoteData)
	end

	function Module:UpdateAllRemoteData(Key: string, Value)
		Communication:Communicate("AllRemoteData", Key, Value)
	end

	return Module
end)()
local Hook = (function()
	local Hook = {
		OriginalNamecall = nil,
		OriginalIndex = nil,
		PreviousFunctions = {},
		DefaultConfig = {
			FunctionPatches = true
		}
	}

	local Modules
	local Process
	local Configuration
	local Config = {}
	local Communication

	local ExeENV = getfenv(1)

	function Hook:Init(Data)
		Modules = Data.Modules

		Process = Modules.Process
		Communication = Modules.Communication or Communication
		Config = Modules.Config or {}
		Configuration = Modules.Configuration or Configuration
	end

	local HookMiddle = newcclosure(function(OriginalFunc, Callback, AlwaysTable: boolean?, ...)
		local ReturnValues = Callback(...)
		if ReturnValues then
			if not AlwaysTable then
				return Process:Unpack(ReturnValues)
			end

			return ReturnValues
		end

		if AlwaysTable then
			return {OriginalFunc(...)}
		end

		return OriginalFunc(...)
	end)

	local function Merge(Base: table, New: table)
		for Key, Value in next, New do
			Base[Key] = Value
		end
	end

	function Hook:Index(Object: Instance, Key: string)
		return Object[Key]
	end

	function Hook:PushConfig(Overwrites)
		Merge(self, Overwrites)
	end

	function Hook:ReplaceMetaMethod(Object: Instance, Call: string, Callback)
		local Metatable = getrawmetatable(Object)
		local OriginalFunc = clonefunction(Metatable[Call])
		
		setreadonly(Metatable, false)
		Metatable[Call] = newcclosure(function(...)
			return HookMiddle(OriginalFunc, Callback, false, ...)
		end)
		setreadonly(Metatable, true)

		return OriginalFunc
	end

	function Hook:HookFunction(Func, Callback)
		local OriginalFunc
		local WrappedCallback = newcclosure(Callback)
		OriginalFunc = clonefunction(hookfunction(Func, function(...)
			return HookMiddle(OriginalFunc, WrappedCallback, false, ...)
		end))
		return OriginalFunc
	end

	function Hook:HookMetaCall(Object: Instance, Call: string, Callback)
		local Metatable = getrawmetatable(Object)
		local Unhooked
		
		Unhooked = self:HookFunction(Metatable[Call], function(...)
			return HookMiddle(Unhooked, Callback, true, ...)
		end)
		return Unhooked
	end

	function Hook:HookMetaMethod(Object: Instance, Call: string, Callback)
		local Func = newcclosure(Callback)
		
		if Config.ReplaceMetaCallFunc then
			return self:ReplaceMetaMethod(Object, Call, Func)
		end
		
		return self:HookMetaCall(Object, Call, Func)
	end

	function Hook:PatchFunctions()
		if Config.NoFunctionPatching then return end

		local Patches = {
			[pcall] =  function(OldFunc, Func, ...)
				local Responce = {OldFunc(Func, ...)}
				local Success, Error = Responce[1], Responce[2]
				local IsC = iscclosure(Func)

				if Success == false and IsC then
					local NewError = Process:CleanCError(Error)
					Responce[2] = NewError
				end

				if Success == false and not IsC and Error:find("C stack overflow") then
					local Tracetable = Error:split(":")
					local Caller, Line = Tracetable[1], Tracetable[2]
					local Count = Process:CountMatches(Error, Caller)

					if Count == 196 then
						Communication:ConsolePrint(`C stack overflow patched, count was {Count}`)
						Responce[2] = Error:gsub(`{Caller}:{Line}: `, Caller, 1)
					end
				end

				return Responce
			end,
			[getfenv] = function(OldFunc, Level: number, ...)
				Level = Level or 1

				if type(Level) == "number" then
					Level += 2
				end

				local Responce = {OldFunc(Level, ...)}
				local ENV = Responce[1]

				if not checkcaller() and ENV == ExeENV then
					Communication:ConsolePrint("ENV escape patched")
					return OldFunc(999999, ...)
				end

				return Responce
			end
		}

		for Func, CallBack in Patches do
			local Wrapped = newcclosure(CallBack)
			local OldFunc; OldFunc = self:HookFunction(Func, function(...)
				return Wrapped(OldFunc, ...)
			end)

			self.PreviousFunctions[Func] = OldFunc
		end
	end

	function Hook:GetOriginalFunc(Func)
		return self.PreviousFunctions[Func] or Func
	end

	function Hook:RunOnActors(Code: string, ChannelId: number)
		if not getactors or not run_on_actor then return end
		
		local Actors = getactors()
		if not Actors then return end
		
		for _, Actor in Actors do 
			pcall(run_on_actor, Actor, Code, ChannelId)
		end
	end

	local function ProcessRemote(OriginalFunc, MetaMethod: string, self, Method: string, ...)
		return Process:ProcessRemote({
			Method = Method,
			OriginalFunc = OriginalFunc,
			MetaMethod = MetaMethod,
			TransferType = "Send",
			IsExploit = checkcaller()
		}, self, ...)
	end

	function Hook:HookRemoteTypeIndex(ClassName: string, FuncName: string)
		local Remote = Instance.new(ClassName)
		local Func = Remote[FuncName]
		local OriginalFunc

		OriginalFunc = self:HookFunction(Func, function(self, ...)
			if not Process:RemoteAllowed(self, "Send", FuncName) then return end

			return ProcessRemote(OriginalFunc, "__index", self, FuncName, ...)
		end)
	end

	function Hook:HookRemoteIndexes()
		local RemoteClassData = Process.RemoteClassData
		for ClassName, Data in RemoteClassData do
			local FuncName = Data.Send[1]
			self:HookRemoteTypeIndex(ClassName, FuncName)
		end
	end

	function Hook:BeginHooks()
		self:HookRemoteIndexes()

		local OriginalNameCall
		OriginalNameCall = self:HookMetaMethod(game, "__namecall", function(self, ...)
			local Method = getnamecallmethod()
			return ProcessRemote(OriginalNameCall, "__namecall", self, Method, ...)
		end)

		Merge(self, {
			OriginalNamecall = OriginalNameCall,
		})
	end

	function Hook:HookClientInvoke(Remote, Method, Callback)
		local Success, Function = pcall(function()
			return getcallbackvalue(Remote, Method)
		end)

		if not Success then return end
		if not Function then return end
		
		local HookSuccess = pcall(function()
			self:HookFunction(Function, Callback)
		end)
		if HookSuccess then return end

		Remote[Method] = function(...)
			return HookMiddle(Function, Callback, false, ...)
		end
	end

	function Hook:MultiConnect(Remotes)
		for _, Remote in next, Remotes do
			self:ConnectClientRecive(Remote)
		end
	end

	function Hook:ConnectClientRecive(Remote)
		local Allowed = Process:RemoteAllowed(Remote, "Receive")
		if not Allowed then return end

		local ClassData = Process:GetClassData(Remote)
		local IsRemoteFunction = ClassData.IsRemoteFunction
		local NoReciveHook = ClassData.NoReciveHook
		local Method = ClassData.Receive[1]

		if NoReciveHook then return end

		local function Callback(...)
			return Process:ProcessRemote({
				Method = Method,
				IsReceive = true,
				MetaMethod = "Connect",
				IsExploit = checkcaller()
			}, Remote, ...)
		end

		if not IsRemoteFunction then
			Remote[Method]:Connect(Callback)
		else
			self:HookClientInvoke(Remote, Method, Callback)
		end
	end

	function Hook:BeginService(Libraries, ExtraData, ChannelId, ...)
		local ReturnSpoofs = Libraries.ReturnSpoofs
		local ProcessLib = Libraries.Process
		local Communication = Libraries.Communication
		local Config = Libraries.Config

		ProcessLib:CheckConfig(Config)

		local InitData = {
			Modules = {
				ReturnSpoofs = ReturnSpoofs,
				Communication = Communication,
				Process = ProcessLib,
				Config = Config,
				Hook = self
			},
			Services = setmetatable({}, {
				__index = function(self, Name: string): Instance
					local Service = game:GetService(Name)
					return cloneref and cloneref(Service) or Service
				end,
			})
		}

		Communication:Init(InitData)
		ProcessLib:Init(InitData)

		local Channel, IsWrapped = Communication:GetCommChannel(ChannelId)
		Communication:SetChannel(Channel)
		Communication:AddTypeCallbacks({
			["RemoteData"] = function(Id: string, RemoteData)
				ProcessLib:SetRemoteData(Id, RemoteData)
			end,
			["AllRemoteData"] = function(Key: string, Value)
				ProcessLib:SetAllRemoteData(Key, Value)
			end,
			["UpdateSpoofs"] = function(Content: string)
				local Spoofs = loadstring(Content)()
				ProcessLib:SetNewReturnSpoofs(Spoofs)
			end,
			["BeginHooks"] = function(Config)
				if Config.PatchFunctions then
					self:PatchFunctions()
				end
				self:BeginHooks()
				Communication:ConsolePrint("Hooks loaded")
			end
		})
		
		ProcessLib:SetChannel(Channel, IsWrapped)
		ProcessLib:SetExtraData(ExtraData)

		self:Init(InitData)

		if ExtraData and ExtraData.IsActor then
			Communication:ConsolePrint("Actor connected!")
		end
	end

	function Hook:LoadMetaHooks(ActorCode: string, ChannelId: number)
		if not Configuration.NoActors then
			self:RunOnActors(ActorCode, ChannelId)
		end

		self:BeginService({
			Process = Process,
			Communication = Communication,
			Config = Config,
			ReturnSpoofs = {}
		}, nil, ChannelId) 
	end

	function Hook:LoadReceiveHooks()
		local NoReceiveHooking = Config.NoReceiveHooking
		local BlackListedServices = Config.BlackListedServices or {}

		if NoReceiveHooking then return end

		game.DescendantAdded:Connect(function(Remote)
			self:ConnectClientRecive(Remote)
		end)

		self:MultiConnect(getnilinstances and getnilinstances() or {})

		for _, Service in next, game:GetChildren() do
			if table.find(BlackListedServices, Service.ClassName) then continue end
			self:MultiConnect(Service:GetDescendants())
		end
	end

	function Hook:LoadHooks(ActorCode: string, ChannelId: number)
		self:LoadMetaHooks(ActorCode, ChannelId)
		self:LoadReceiveHooks()
	end

	return Hook
end)()
local Communication = (function()
	local Module = {
		CommCallbacks = {}
	}

	local CommWrapper = {}
	CommWrapper.__index = CommWrapper

	local SerializeCache = setmetatable({}, {__mode = "k"})
	local DeserializeCache = setmetatable({}, {__mode = "k"})

	local CoreGui
	local Hook
	local Channel
	local Config
	local Process

	function Module:Init(Data)
		local Modules = Data.Modules
		local Services = Data.Services

		Hook = Modules.Hook
		Process = Modules.Process
		Config = Modules.Config or Config
		CoreGui = Services.CoreGui
	end

	function CommWrapper:Fire(...)
		local Queue = self.Queue
		table.insert(Queue, {...})
	end

	function CommWrapper:ProcessArguments(Arguments) 
		local Channel = self.Channel
		Channel:Fire(Process:Unpack(Arguments))
	end

	function CommWrapper:ProcessQueue()
		local Queue = self.Queue

		for Index = 1, #Queue do
			local Arguments = table.remove(Queue)
			pcall(function()
				self:ProcessArguments(Arguments) 
			end)
		end
	end

	function CommWrapper:BeginQueueService()
		coroutine.wrap(function()
			while wait() do
				self:ProcessQueue()
			end
		end)()
	end

	function Module:NewCommWrap(Channel)
		local Base = {
			Queue = setmetatable({}, {__mode = "v"}),
			Channel = Channel,
			Event = Channel.Event
		}

		local Wrapped = setmetatable(Base, CommWrapper)
		Wrapped:BeginQueueService()

		return Wrapped
	end

	function Module:MakeDebugIdHandler()
		local Remote = Instance.new("BindableFunction")
		function Remote.OnInvoke(Object: Instance): string
			return Object:GetDebugId()
		end

		self.DebugIdRemote = Remote
		self.DebugIdInvoke = Remote.Invoke

		return Remote
	end

	function Module:GetDebugId(Object: Instance): string
		local Invoke = self.DebugIdInvoke
		local Remote = self.DebugIdRemote
		return Invoke(Remote, Object)
	end

	function Module:GetHiddenParent(): Instance
		if gethui then return gethui() end
		return CoreGui
	end

	function Module:CreateCommChannel()
		local Force = Config.ForceUseCustomComm
		if create_comm_channel and not Force then
			return create_comm_channel()
		end

		local Parent = self:GetHiddenParent()
		local ChannelId = math.random(1, 10000000)

		local Channel = Instance.new("BindableEvent", Parent)
		Channel.Name = ChannelId

		return ChannelId, Channel
	end

	function Module:GetCommChannel(ChannelId: number)
		local Force = Config.ForceUseCustomComm
		if get_comm_channel and not Force then
			local Channel = get_comm_channel(ChannelId)
			return Channel, false
		end

		local Parent = self:GetHiddenParent()
		local Channel = Parent:FindFirstChild(ChannelId)

		local Wrapped = self:NewCommWrap(Channel)
		return Wrapped, true
	end

	function Module:CheckValue(Value, Inbound: boolean?)
		if typeof(Value) ~= "table" then 
			return Value 
		end
		
		if Inbound then
			return self:DeserializeTable(Value)
		end

		return self:SerializeTable(Value)
	end

	local Tick = 0
	function Module:WaitCheck()
		Tick += 1
		if Tick > 40 then
			Tick = 0
			wait()
		end
	end

	function Module:MakePacket(Index, Value): table
		self:WaitCheck()
		return {
			Index = self:CheckValue(Index), 
			Value = self:CheckValue(Value)
		}
	end

	function Module:ReadPacket(Packet: table)
		if typeof(Packet) ~= "table" then return Packet end
		
		local Key = self:CheckValue(Packet.Index, true)
		local Value = self:CheckValue(Packet.Value, true)
		self:WaitCheck()

		return Key, Value
	end

	function Module:SerializeTable(Table: table): table
		local Cached = SerializeCache[Table]
		if Cached then return Cached end

		local Serialized = {}
		SerializeCache[Table] = Serialized

		for Index, Value in next, Table do
			local Packet = self:MakePacket(Index, Value)
			table.insert(Serialized, Packet)
		end

		return Serialized
	end

	function Module:DeserializeTable(Serialized: table): table
		local Cached = DeserializeCache[Serialized]
		if Cached then return Cached end

		local Table = {}
		DeserializeCache[Serialized] = Table
		
		for _, Packet in next, Serialized do
			local Index, Value = self:ReadPacket(Packet)
			if Index == nil then continue end

			Table[Index] = Value
		end

		return Table
	end

	function Module:SetChannel(NewChannel: number)
		Channel = NewChannel
	end

	function Module:ConsolePrint(...)
		self:Communicate("Print", ...)
	end

	function Module:QueueLog(Data)
		spawn(function()
			local SerializedArgs = self:SerializeTable(Data.Args)
			Data.Args = SerializedArgs

			self:Communicate("QueueLog", Data)
		end)
	end

	function Module:AddCommCallback(Type: string, Callback)
		local CommCallbacks = self.CommCallbacks
		CommCallbacks[Type] = Callback
	end

	function Module:GetCommCallback(Type: string)
		local CommCallbacks = self.CommCallbacks
		return CommCallbacks[Type]
	end

	function Module:ChannelIndex(Channel, Property: string)
		if typeof(Channel) == "Instance" then
			return Hook:Index(Channel, Property)
		end

		return Channel[Property]
	end

	function Module:Communicate(...)
		local Fire = self:ChannelIndex(Channel, "Fire")
		Fire(Channel, ...)
	end

	function Module:AddConnection(Callback)
		local Event = self:ChannelIndex(Channel, "Event")
		return Event:Connect(Callback)
	end

	function Module:AddTypeCallback(Type: string, Callback)
		local Event = self:ChannelIndex(Channel, "Event")
		return Event:Connect(function(RecivedType: string, ...)
			if RecivedType ~= Type then return end
			Callback(...)
		end)
	end

	function Module:AddTypeCallbacks(Types: table)
		for Type: string, Callback in next, Types do
			self:AddTypeCallback(Type, Callback)
		end
	end

	function Module:CreateChannel(): number
		local ChannelID, Event = self:CreateCommChannel()

		Event.Event:Connect(function(Type: string, ...)
			local Callback = self:GetCommCallback(Type)
			if Callback then
				Callback(...)
			end
		end)

		return ChannelID, Event
	end

	Module:MakeDebugIdHandler()

	return Module
end)()
local Config = {
    ForceUseCustomComm = false,
    NoReceiveHooking = false,
    NoFunctionPatching = false,
    BlackListedServices = {"CoreGui", "Players"}
}
       
local Libraries = {
    Process = Process,
    Hook = Hook,
    Communication = Communication,
    Config = Config,
    ReturnSpoofs = {}
}

local ExtraData = {IsActor = true}
Hook:BeginService(Libraries, ExtraData, ]] .. ChannelId .. [[)
   ]==]

Hook:LoadHooks(ActorCode, ChannelId)

Event:Fire("BeginHooks", {
	PatchFunctions = true
})

print("[Sigma Spy] Successfully loaded!")
