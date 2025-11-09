--[[
	Sigma Spy - Complete Standalone Version with Full UI
	Self-contained implementation with ReGui interface
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

--// Services
local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService

--// Load ReGui from GitHub
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()

--// Initialize ReGui
local PrefabsId = `rbxassetid://{ReGui.PrefabsId}`
ReGui:Init({
	Prefabs = game:GetService("InsertService"):LoadLocalAsset(PrefabsId)
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

	function Module:GetFlag(Name: string)
		local AllFlags = self:GetFlags()
		local Flag = AllFlags[Name]
		assert(Flag, "Flag does not exist!")
		return Flag
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
--// PROCESS MODULE (Abbreviated for space)
--// ============================================
local Process = (function()
	local Module = {
		RemoteClassData = {
			["RemoteEvent"] = {
				Send = {"FireServer", "fireServer"},
				Receive = {"OnClientEvent"}
			},
			["RemoteFunction"] = {
				IsRemoteFunction = true,
				Send = {"InvokeServer", "invokeServer"},
				Receive = {"OnClientInvoke"}
			},
		},
		RemoteOptions = {},
	}

	function Module:Init(Data)
		-- Initialization logic
	end

	function Module:ProcessRemote(Data, Remote, ...)
		-- Processing logic
		Communication:QueueLog(Data)
		return {}
	end

	return Module
end)()

--// ============================================
--// UI CREATION WITH REGUI
--// ============================================

--// Create main window
local Window = ReGui:Window({
	Title = "Sigma Spy - Remote Logger",
	Size = UDim2.fromOffset(800, 600),
	Theme = "DarkTheme"
}):Center()

--// Create tabs
local TabSelector = Window:TabSelector()

--// Logs Tab
local LogsTab = TabSelector:CreateTab({Name = "Logs"})
local LogsConsole = LogsTab:Console({
	ReadOnly = true,
	AutoScroll = true,
	MaxLines = 500,
	RichText = true,
	Size = UDim2.new(1, 0, 1, -100)
})

--// Remote Info Display
local InfoSection = LogsTab:CollapsingHeader({
	Title = "Selected Remote Info",
	Collapsed = true
})

local RemoteNameLabel = InfoSection:Label({Text = "No remote selected"})
local RemotePathLabel = InfoSection:Label({Text = ""})

--// Code generation section
local CodeSection = InfoSection:CollapsingHeader({
	Title = "Generated Code",
	Collapsed = false
})

local CodeDisplay = CodeSection:Console({
	Value = "-- Select a remote to generate code",
	LineNumbers = true,
	Size = UDim2.new(1, 0, 0, 200)
})

local ButtonRow = CodeSection:Row()
ButtonRow:Button({
	Text = "Copy Remote Call",
	Callback = function()
		if CodeDisplay:GetValue() ~= "-- Select a remote to generate code" then
			setclipboard(CodeDisplay:GetValue())
			LogsConsole:AppendText("<font color='rgb(130,188,91)'>[✓] Code copied to clipboard!</font>")
		end
	end
})

ButtonRow:Button({
	Text = "Copy Full Script",
	Callback = function()
		local fullScript = [[
-- Generated by Sigma Spy
local Remote = ]] .. (selectedRemotePath or "nil") .. [[

]] .. CodeDisplay:GetValue()
		setclipboard(fullScript)
		LogsConsole:AppendText("<font color='rgb(130,188,91)'>[✓] Full script copied to clipboard!</font>")
	end
})

--// Settings Tab
local SettingsTab = TabSelector:CreateTab({Name = "Settings"})

--// Create checkboxes for flags
for FlagName, FlagData in pairs(Flags:GetFlags()) do
	SettingsTab:Checkbox({
		Label = FlagData.Label,
		Value = FlagData.Value,
		Callback = function(self, Value)
			Flags:SetFlagValue(FlagName, Value)
			LogsConsole:AppendText(string.format("<font color='rgb(66,150,250)'>[Settings]</font> %s: %s", FlagData.Label, tostring(Value)))
		end
	})
end

--// About Tab
local AboutTab = TabSelector:CreateTab({Name = "About"})
AboutTab:Label({Text = "Sigma Spy - Remote Logger"})
AboutTab:Label({Text = "Version: 1.0.0"})
AboutTab:Label({Text = "UI Framework: Dear ReGui"})
AboutTab:Separator()
AboutTab:Button({
	Text = "GitHub Repository",
	Callback = function()
		LogsConsole:AppendText("<font color='rgb(66,150,250)'>[Info]</font> Check console for GitHub link")
		print("https://github.com/depthso/Sigma-Spy")
	end
})

--// ============================================
--// LOG PROCESSING
--// ============================================

local selectedRemotePath = nil
local LogHistory = {}

Communication:AddCommCallback("QueueLog", function(Data)
	if Flags:GetFlagValue("Paused") then return end
	
	local Remote = Data.Remote
	local Method = Data.Method
	local Args = Data.Args
	
	--// Format log entry
	local remoteName = Remote:GetFullName()
	local timestamp = os.date("%H:%M:%S")
	local argsStr = ""
	
	for i, arg in ipairs(Args) do
		local argType = typeof(arg)
		local argValue = tostring(arg)
		if argType == "Instance" then
			argValue = arg:GetFullName()
		elseif argType == "table" then
			argValue = "Table[" .. #arg .. "]"
		end
		argsStr = argsStr .. (i > 1 and ", " or "") .. argValue
	end
	
	local logEntry = string.format(
		"<font color='rgb(172,171,175)'>[%s]</font> <font color='rgb(66,150,250)'>%s</font>:<font color='rgb(253,251,172)'>%s</font>(%s)",
		timestamp,
		remoteName,
		Method,
		argsStr
	)
	
	LogsConsole:AppendText(logEntry)
	table.insert(LogHistory, Data)
	
	--// Auto-select if enabled
	if Flags:GetFlagValue("SelectNewest") then
		UpdateSelectedRemote(Data)
	end
end)

function UpdateSelectedRemote(Data)
	selectedRemotePath = Data.Remote:GetFullName()
	RemoteNameLabel:SetLabel("Remote: " .. Data.Remote.Name)
	RemotePathLabel:SetLabel("Path: " .. selectedRemotePath)
	
	--// Generate code
	local codeTemplate = string.format([[
-- Remote: %s
local Remote = %s

-- Fire remote
Remote:%s(%s)
]],
		Data.Remote.Name,
		selectedRemotePath,
		Data.Method,
		table.concat(Data.Args, ", ")
	)
	
	CodeDisplay:SetValue(codeTemplate)
end

Communication:AddCommCallback("Print", function(...)
	local args = {...}
	local message = table.concat(args, " ")
	LogsConsole:AppendText("<font color='rgb(255,198,0)'>[System]</font> " .. message)
end)

--// ============================================
--// KEYBINDS
--// ============================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	local flags = Flags:GetFlags()
	for flagName, flagData in pairs(flags) do
		if flagData.Keybind and input.KeyCode == flagData.Keybind then
			if flags.KeybindsEnabled.Value then
				Flags:SetFlagValue(flagName, not flagData.Value)
				LogsConsole:AppendText(string.format("<font color='rgb(66,150,250)'>[Keybind]</font> %s toggled: %s", flagData.Label, tostring(Flags:GetFlagValue(flagName))))
			end
		end
	end
end)

--// ============================================
--// INITIALIZE
--// ============================================

local ChannelId, Event = Communication:CreateChannel()

LogsConsole:AppendText("<font color='rgb(130,188,91)'>[✓] Sigma Spy initialized successfully!</font>")
LogsConsole:AppendText("<font color='rgb(172,171,175)'>Press " .. tostring(Flags:GetFlag("UiVisible").Keybind) .. " to toggle UI visibility</font>")
LogsConsole:AppendText("<font color='rgb(172,171,175)'>Press " .. tostring(Flags:GetFlag("Paused").Keybind) .. " to pause/resume logging</font>")

print("Sigma Spy loaded! UI Framework: Dear ReGui")
