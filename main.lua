--// Base Configuration (Cấu hình cơ bản)
local Configuration = {
	UseWorkspace = false,
	NoActors = false,
	FolderName = "Sigma Spy",
	-- Đã loại bỏ RepoUrl và ParserUrl theo yêu cầu không sử dụng HTTP
}

--// Load overwrites (Tải ghi đè)
local Parameters = {...}
local Overwrites = Parameters[1]
if typeof(Overwrites) == "table" then
	for Key, Value in Overwrites do
		Configuration[Key] = Value
	end
end

--// Service handler (Bộ xử lý dịch vụ)
local Services = setmetatable({}, {
	__index = function(self, Name: string): Instance
		local Service = game:GetService(Name)
		return cloneref(Service)
	end,
})

--// HttpService
local HttpService = Services.HttpService

-- =================================================================================
-- KHỐI MODULE ĐƯỢC HỢP NHẤT (CONSOLIDATED MODULE BLOCK)
-- =================================================================================

--// Files module (Module Quản lý File)
local Files = (function()
	type table = {
		[any]: any
	}

	--// Module
	local Files = {
		UseWorkspace = false,
		Folder = Configuration.FolderName, -- Sử dụng FolderName từ cấu hình chính
		FolderStructure = {
			["Sigma Spy"] = {
				"assets",
			}
		}
	}

	--// Services (Sử dụng HttpService từ phạm vi ngoài để mã hóa JSON)
	local HttpService = Services.HttpService

	function Files:Init(Data)
		local FolderStructure = self.FolderStructure
		-- Dịch vụ đã được lấy từ phạm vi ngoài, không cần Data.Services
		
		--// Kiểm tra và tạo thư mục
		-- Giả định các hàm file system (makefolder, isfolder, writefile, v.v.) tồn tại
		if makefolder and isfolder then
			self:CheckFolders(FolderStructure)
		else
			warn("Chức năng hệ thống file không được hỗ trợ. Bỏ qua các hoạt động tạo thư mục.")
		end
	end

	function Files:PushConfig(Config: table)
		for Key, Value in next, Config do
			self[Key] = Value
		end
	end

	function Files:MakePath(FileName: string): string
		local Path = self.Folder .. "/" .. FileName
		return Path
	end

	function Files:CheckFolders(FolderStructure: table, CurrentPath: string?)
		local Folder = self.Folder

		for Name, NextStructure in next, FolderStructure do
			local FullPath = CurrentPath and (CurrentPath .. "/" .. Name) or (Folder .. "/" .. Name)

			if isfolder and not isfolder(FullPath) and makefolder then
				makefolder(FullPath)
			end

			if typeof(NextStructure) == "table" then
				self:CheckFolders(NextStructure, FullPath)
			end
		end
	end

	function Files:CompileLibrary(Content: string, Name: string, ...): {}
		--// Compile library
		local Closure, Error = loadstring(Content, Name)
		assert(Closure, `Failed to load {Name}: {Error}`)

		return Closure(...)
	end

	function Files:CompileScripts(Scripts: table, ...): {}
		local Modules = {}
		for Name, Content in next, Scripts do
			if typeof(Content) ~= "string" then continue end

			--// Compile library
			local Closure, Error = loadstring(Content, Name)
			assert(Closure, `Failed to load {Name}: {Error}`)

			Modules[Name] = Closure(...)
		end
		return Modules
	end

	function Files:LoadModules(Modules: {}, Data: {})
		for Name, Module in next, Modules do
			local Init = Module.Init
			if not Init then continue end

			--// Invoke :Init function
			Module:Init(Data)
		end
	end

	function Files:CreateFont(Name: string, AssetId: string): string?
		-- Đã loại bỏ logic tạo font và ghi file
		warn("Files:CreateFont bị bỏ qua theo yêu cầu không sử dụng font tùy chỉnh.")
		return nil
	end

	function Files:CompileModule(Scripts): string
		local Out = "local Libraries = {\r\n"
		for Name, Content in Scripts do
			if typeof(Content) ~= "string" then continue end
			-- Nội dung module đã được nhúng trong code Lua.
			Out ..= `\t{Name} = (function()\\n{Content}\\n\tend)(),\\n`
		end
		Out ..= "}\r\n"
		Out ..= `\r\nreturn Libraries`
		return Out
	end

	function Files:MakeActorScript(Scripts, ChannelId): string
		local Compile = self:CompileModule(Scripts)
		local Actor = `
		local ChannelId = {ChannelId}
		local Scripts = (function()
			{Compile}
		end)()
		
		local Modules = Scripts.Libraries
		local Hook = Modules.Hook
		local Communication = Modules.Communication
		local Process = Modules.Process
		
		--// Create communication channel
		local Channel, Event = Communication:ConnectChannel(ChannelId)
		Communication:AddCommCallback("SetReturnSpoofs", function(Spoofs)
			Process:SetNewReturnSpoofs(Spoofs)
		end)
		Communication:AddCommCallback("RunCode", function(Code)
			loadstring(Code)()
		end)
		
		Hook:BeginService(Modules, Channel, ChannelId)
	`
		return Actor
	end

	return Files
end)()

Files:PushConfig(Configuration)

--// Flags module (Module Cờ/Thiết lập)
local Flags = (function()
	type FlagValue = boolean|number|any
	type Flag = {
		Value: FlagValue,
		Label: string,
		Category: string
	}
	type Flags = {
		[string]: Flag
	}
	type table = {
		[any]: any
	}

	local Module = {
		Flags = {
			-- PreventRenaming = {
			--     Value = false,
			--     Label = "No renaming",
			-- },
			-- PreventParenting = {
			--     Value = false,
			--     Label = "No parenting",
			-- },
			NoComments = {
				Value = false,
				Label = "No comments",
			},
			SelectNewest = {
				Value = false,
				Label = "Auto select newest",
			},
			DecompilePopout = { -- Lovre SHUSH
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
				Label = "Keybinds enabled"
			},
			IgnoreLocal = {
				Value = false,
				Label = "Ignore local"
			},
			BlockInvocations = {
				Value = false,
				Label = "Block invocations"
			},
			UseNamecall = {
				Value = true,
				Label = "Use namecall"
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

	function Module:GetFlagValue(Name: string): FlagValue
		local Flag = self:GetFlag(Name)
		return Flag.Value
	end

	function Module:SetFlagValue(Name: string, Value: FlagValue)
		local Flag = self:GetFlag(Name)
		Flag.Value = Value
	end

	function Module:SetFlagCallback(Name: string, Callback: (...any) -> ...any)
		local Flag = self:GetFlag(Name)
		Flag.Callback = Callback
	end

	function Module:SetFlagCallbacks(Dict: {})
		for Name, Callback: (...any) -> ...any in next, Dict do
			self:SetFlagCallback(Name, Callback)
		end
	end

	function Module:GetFlag(Name: string): Flag
		local AllFlags = self:GetFlags()
		local Flag = AllFlags[Name]
		if not Flag then error(`Unknown flag {Name}`) end
		return Flag
	end

	function Module:GetFlags(): Flags
		return self.Flags
	end

	function Module:GetVisibleFlags(): Flags
		local Flags = {}
		local AllFlags = self:GetFlags()

		for Name, Flag in next, AllFlags do
			if not Flag.Hidden then
				Flags[Name] = Flag
			end
		end

		return Flags
	end

	return Module
end)()

--// UI Library (Giả định ReGui được include ở đây. Vì ReGui không được cung cấp, tôi sẽ bỏ qua phần code của nó)
-- ReGui không được cung cấp, giả định một module UI đơn giản để không làm hỏng logic chính.
local Ui = (function()
	local Module = {}

	function Module:Init(Data)
		-- Có thể init các thành phần UI ở đây
	end

	function Module:CreateMainWindow()
		-- Tạo cửa sổ chính. Trả về một đối tượng giả.
		return {
			Close = function() warn("Hàm Close UI giả được gọi.") end
		}
	end

	function Module:QueueLog(...)
		print("[LOG QUEUE]", ...)
	end

	function Module:ConsoleLog(...)
		print("[CONSOLE LOG]", ...)
	end

	function Module:SetCommChannel(Event)
		-- Giả định thiết lập kênh truyền thông
	end

	function Module:BeginLogService()
		-- Giả định bắt đầu dịch vụ Log
	end

	function Module:CreateWindowContent(Window)
		-- Giả định tạo nội dung cửa sổ
	end

	function Module:AskUser(Data)
		-- Giả định hộp thoại xác nhận. Mặc định là chấp nhận.
		print("[HỘP THOẠI HỎI NGƯỜI DÙNG]:", Data.Title)
		for _, content in ipairs(Data.Content) do
			print(">", content)
		end
		return true -- Giả định người dùng đồng ý
	end

	return Module
end)()

--// Generation module (Module Sinh mã)
local Generation = (function()
	type table = {
		[any]: any
	}
	
	type RemoteData = {
		Remote: Instance,
		IsReceive: boolean?,
		MetaMethod: string,
		Args: table,
		Method: string,
	    TransferType: string,
		ValueReplacements: table,
		NoVariables: boolean?
	}

	--// Module
	local Generation = {
		DumpBaseName = "SigmaSpy-Dump %s.lua", -- "-- Generated with sigma spy BOIIIIIIIII (+9999999 AURA)\n"
		Header = "-- Generated with Sigma Spy Github: https://github.com/depthso/Sigma-Spy\n",
		ScriptTemplates = {
			["Remote"] = {
				{"%RemoteCall%"}
			},
			["Spam"] = {
				{"while wait() do"},
				{"%RemoteCall%", 2},
				{"end"}
			},
			["Repeat"] = {
				{"for Index = 1, 10 do"},
				{"%RemoteCall%", 2},
				{"end"}
			},
			["Block"] = {
				["__index"] = {
					{"local Old; Old = hookfunction(%Signal%, function(self, ...)"},
					{"if self == %Remote% then", 2},
					{"return", 3},
					{"end", 2},
					{"return Old(self, ...)", 2},
					{"end)"}
				},
				["__namecall"] = {
					{"local Old; Old = hookfunction(%Signal%, function(self, Method, ...)"},
					{"if self == %Remote% and Method == \"%Method%\" then", 2},
					{"return", 3},
					{"end", 2},
					{"return Old(self, Method, ...)", 2},
					{"end)"}
				}
			},
			["Debug"] = {
				{"local Ret = {pcall(%RemoteCall%)}"},
				{"print(unpack(Ret))"}
			},
			["Passive"] = {
				{"local ReturnValues = {%RemoteCall%}"},
				{"--// Return values can be found here: table.unpack(ReturnValues)"}
			},
		}
	}

	function Generation:AddSwaps(Data: table)
		for Key, Value in Data do
			self.Swaps[Key] = Value
		end
	end

	function Generation:AddSwap(Instance: Instance, Data: table)
		local Swaps = self.Swaps
		local Path = Instance:GetFullName()
		
		--// Check for a path swap
		if not Swaps[Path] then
			Swaps[Path] = {}
		end
		
		--// Add data
		self:AddSwaps(Data)
	end
	
	function Generation:GenerateRemote(Data: RemoteData, Template: string): string
		local Remote = Data.Remote
		local MetaMethod = Data.MetaMethod
		local Method = Data.Method
		local Args = Data.Args
		local ValueReplacements = Data.ValueReplacements
		local NoVariables = Data.NoVariables
		
		--// Get script template
		local ScriptTemplate = self.ScriptTemplates[Template]
		local Lines = (MetaMethod == "__namecall" and ScriptTemplate["__namecall"]) or ScriptTemplate["__index"] or ScriptTemplate
		
		--// Generate remote call
		local RemoteCall = self:GenerateCall(Data)

		--// Replace parts
		local Replacements = {
			["%RemoteCall%"] = RemoteCall,
			["%Remote%"] = Remote,
			["%Method%"] = Method,
			["%Signal%"] = MetaMethod,
		}

		--// Compile lines
		local Out = {}
		for _, Line in Lines do
			local Content = Line[1]
			local TabCount = Line[2] or 0

			--// Tab count
			local Tabs = string.rep("\t", TabCount)

			--// Apply replacements
			for Target, Replace in Replacements do
				if typeof(Replace) == "Instance" then
					Replace = self:MakeInstancePath(Replace)
				end
				Content = Content:gsub(Target, tostring(Replace))
			end

			--// Append line
			table.insert(Out, Tabs .. Content)
		end
		
		--// Return generated script
		return table.concat(Out, "\n")
	end

	function Generation:GenerateCall(Data: RemoteData): string
		local Remote = Data.Remote
		local Args = Data.Args
		local Method = Data.Method
		local ValueReplacements = Data.ValueReplacements
		local NoVariables = Data.NoVariables
		
		--// Generate path
		local RemotePath = self:MakeInstancePath(Remote)
		
		--// Get Arguments
		local ArgumentString = self:MakeArgumentString(Args, ValueReplacements)
		local Return = `(RemotePath):{Method}({ArgumentString})`
		
		--// Return the call
		return Return
	end

	function Generation:MakeArgumentString(Args: table, ValueReplacements: table?): string
		local Arguments = {}
		for Index, Value in next, Args do
			local Replacement = ValueReplacements and ValueReplacements[Index]
			
			--// Check for replacement
			if Replacement then
				table.insert(Arguments, Replacement)
				continue
			end
			
			--// Convert value to string
			local String = self:ConvertValue(Value)
			table.insert(Arguments, String)
		end

		return table.concat(Arguments, ", ")
	end

	function Generation:ConvertValue(Value): string
		local Type = typeof(Value)
		
		if Type == "string" then
			return `"{Value}"`
		elseif Type == "Instance" then
			return self:MakeInstancePath(Value)
		elseif Type == "number" then
			return tostring(Value)
		elseif Type == "boolean" then
			return tostring(Value)
		elseif Type == "Vector3" then
			return `Vector3.new({Value.X}, {Value.Y}, {Value.Z})`
		elseif Type == "CFrame" then
			local X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = Value:ToTuple()
			return `CFrame.new({X}, {Y}, {Z}, {R00}, {R01}, {R02}, {R10}, {R11}, {R12}, {R20}, {R21}, {R22})`
		elseif Type == "UDim2" then
			return `UDim2.new({Value.X.Scale}, {Value.X.Offset}, {Value.Y.Scale}, {Value.Y.Offset})`
		elseif Type == "BrickColor" then
			return `BrickColor.new("{Value.Name}")`
		elseif Type == "Color3" then
			return `Color3.new({Value.R}, {Value.G}, {Value.B})`
		elseif Type == "table" then
			return self:MakeTable(Value)
		elseif Type == "nil" then
			return "nil"
		elseif Type == "function" then
			return "function() end"
		else
			return `[unsupported: {Type}]`
		end
	end
	
	function Generation:MakeTable(Table: table): string
		local IsArray = self:CheckIsArray(Table)
		local Out = IsArray and {"{"} or {"{"}
		
		for Key, Value in next, Table do
			local KeyString = IsArray and "" or `[{self:ConvertValue(Key)}] = `
			local ValueString = self:ConvertValue(Value)
			
			table.insert(Out, KeyString .. ValueString .. ",")
		end
		table.insert(Out, "}")
		
		return table.concat(Out)
	end

	function Generation:CheckIsArray(Table: table): boolean
		local Count = 0
		local MaxIndex = 0
		
		for Key in next, Table do
			Count += 1
			if typeof(Key) == "number" then
				MaxIndex = math.max(MaxIndex, Key)
			else
				return false
			end
		end
		
		return Count == MaxIndex
	end

	function Generation:MakeInstancePath(Instance: Instance): string
		local Swaps = self.Swaps
		local Path = Instance:GetFullName()
		
		--// Check if instance is nil
		if not Instance or not Instance.Parent then
			return "nil"
		end
		
		--// Check for a path swap
		if Swaps[Path] then
			return Swaps[Path].String or Path
		end
		
		--// Generate path
		local PathTable = {}
		local Current = Instance
		
		while Current and Current.Parent do
			local Swaps = Swaps[Current:GetFullName()]
			if Swaps and Swaps.NextParent then break end
			
			table.insert(PathTable, 1, Current.Name)
			Current = Current.Parent
		end
		
		local Out = Current and (Current.Name .. "." .. table.concat(PathTable, ".")) or table.concat(PathTable, ".")
		return `game.{Out}`
	end

	function Generation:DumpLog(Data): string
		local Remote = Data.Remote
		local Args = Data.Args
		local Method = Data.Method
		local MetaMethod = Data.MetaMethod
		
		--// Check for nil parent
		if not Data.Remote.Parent and Flags:GetFlagValue("IgnoreNil") then
			return ""
		end
		
		local Call = self:GenerateCall(Data)
		local Out = {self.Header}
		table.insert(Out, Call)
		
		return table.concat(Out, "\n")
	end

	function Generation:SetSwapsCallback(Callback)
		self.SwapsCallback = Callback
	end
	
	function Generation:NewParser()
		return setmetatable({}, {
			__index = self,
			Swaps = {}
		})
	end
	
	return Generation
end)()

--// Hook module (Module Hook)
local Hook = {
	OriginalNamecall = nil,
	OriginalIndex = nil,
	PreviousFunctions = {},
	DefaultConfig = {
		FunctionPatches = true
	}
}

type table = {
	[any]: any
}

type MetaFunc = (Instance, ...any) -> ...any
type UnkFunc = (...any) -> ...any

--// Modules
local Modules
local Process
local Configuration
local Config
local Communication

local ExeENV = getfenv(1)

function Hook:Init(Data)
    Modules = Data.Modules

	Process = Modules.Process
	Communication = Modules.Communication or Communication
	Config = Modules.Config or Config
	Configuration = Modules.Configuration or Configuration
end

--// The callback is expected to return a nil value sometimes which should be ingored
local HookMiddle = newcclosure(function(OriginalFunc, Callback, AlwaysTable: boolean?, ...)
	--// Invoke callback and check for a reponce otherwise ignored
	local ReturnValues = Callback(...)
	if ReturnValues then
		-- BẮT ĐẦU PHẦN ĐÃ CHỈNH SỬA
		-- Đảm bảo Process tồn tại và có hàm Unpack trước khi gọi.
		if Process and Process.Unpack then
			--// Unpack
			if not AlwaysTable then
				return Process:Unpack(ReturnValues)
			end
		else
			-- Ghi log lỗi nếu Process:Unpack không tồn tại
			warn("[HookMiddle] Lỗi: Process module hoặc Process:Unpack không khả dụng!")
			-- Tiếp tục bằng cách trả về giá trị đóng gói hoặc ngắt nếu không thể unpack
			if not AlwaysTable then 
				-- Nếu không thể unpack, ta giả định ReturnValues là giá trị đơn
				return ReturnValues 
			end
		end
		-- KẾT THÚC PHẦN ĐÃ CHỈNH SỬA

		--// Return packed responce
		return ReturnValues
	end

	--// Return packed responce
	if AlwaysTable then
		return {OriginalFunc(...)}
	end

	--// Unpacked
	return OriginalFunc(...)
end)

function Hook:Index(Instance: Instance, Property: string)
	if type(Instance) == "Instance" then
		local ReturnValue = rawget(Instance, Property)
		if ReturnValue then
			return ReturnValue
		end

		--// Get from metamethod
		if self.OriginalIndex then
			return self.OriginalIndex(Instance, Property)
		end
	end

	--// Return normal index
	return rawget(Instance, Property)
end

function Hook:Namecall(Method: string, ...)
	if self.OriginalNamecall then
		return self.OriginalNamecall(Method, ...)
	end
end

function Hook:HookGlobal(Global: string, Callback: MetaFunc)
	local Original = ExeENV[Global]
	if not Original then
		return
	end

	--// Previous function cache
	self.PreviousFunctions[Global] = Original

	--// Hook function
	ExeENV[Global] = newcclosure(function(...)
		return HookMiddle(Original, Callback, false, ...)
	end)
end

function Hook:Hook(Instance: Instance, Method: string, Callback: MetaFunc, AlwaysTable: boolean?)
	local Original = Instance[Method]
	if not Original then
		return
	end

	--// Previous function cache
	self.PreviousFunctions[Method] = Original

	--// Hook function
	Instance[Method] = newcclosure(function(...)
		return HookMiddle(Original, Callback, AlwaysTable, ...)
	end)
end

function Hook:Unhook(Instance: Instance, Method: string)
	local Original = self.PreviousFunctions[Method]
	if not Original then
		return
	end

	--// Unhook function
	Instance[Method] = Original
end

function Hook:UnhookGlobal(Global: string)
	local Original = self.PreviousFunctions[Global]
	if not Original then
		return
	end

	--// Unhook function
	ExeENV[Global] = Original
end

function Hook:PatchFunctions()
	local Patches = Config.Patches
	if not Patches then return end

	--// Patch functions
	for FuncName, Patches in next, Patches do
		local Original = ExeENV[FuncName]
		if not Original then continue end

		--// Patch
		ExeENV[FuncName] = Patches
	end

	Communication:ConsolePrint("Patched " .. tostring(#Patches) .. " functions")
end

--// Loop through all descendants
function Hook:ConnectClientRecive(Remote: Instance)
	local RemoteClassData = Process.RemoteClassData
	local ClassName = Remote.ClassName
	local Data = RemoteClassData[ClassName]

	--// Check for a remote class
	if not Data then return end

	local ReceiveMethods = Data.Receive
	for _, Method in next, ReceiveMethods do
		--// Hook recive
		self:Hook(Remote, Method, function(...)
			return Process:ProcessRemote(Remote, Method, true, ...)
		end, Data.IsRemoteFunction)
	end

	--// Fire event after adding recive hook
	Communication:Communicate("RemoteAdded", Remote, Data)
end

function Hook:ConnectClientSend(Remote: Instance)
	local RemoteClassData = Process.RemoteClassData
	local ClassName = Remote.ClassName
	local Data = RemoteClassData[ClassName]

	--// Check for a remote class
	if not Data then return end

	local SendMethods = Data.Send
	for _, Method in next, SendMethods do
		--// Hook send
		self:Hook(Remote, Method, function(self, ...)
			return Process:ProcessRemote(Remote, Method, false, ...)
		end, Data.IsRemoteFunction)
	end
end

function Hook:MultiConnect(Instances: table)
	for _, Instance: Instance in next, Instances do
		--// Check if instance is a remote
		self:ConnectClientRecive(Instance)
		self:ConnectClientSend(Instance)
	end
end

function Hook:BeginHooks()
	--// Hook functions
	local FunctionHooks = Config.FunctionHooks or {}
	for FuncName, Callback in next, FunctionHooks do
		self:HookGlobal(FuncName, Callback)
	end

	--// Remote send hook
	local Services = {
		game,
		game.Players,
	}

	for _, Service: Instance in next, Services do
		local Children = Service:GetDescendants()
		self:MultiConnect(Children)

		--// Child added
		Service.DescendantAdded:Connect(function(Remote)
			self:ConnectClientSend(Remote)
		end)
	end

	--// Receive hook
	self:LoadReceiveHooks()
end

function Hook:RunOnActors(ActorCode: string, ChannelId: number)
	local AllActors = getactors()

	--// Actors added later
	game.DescendantAdded:Connect(function(Instance)
		if not isactor(Instance) then return end
		loadstring(ActorCode)(Instance, ChannelId)
	end)

	--// Actors already present
	for _, Actor in next, AllActors do
		loadstring(ActorCode)(Actor, ChannelId)
	end
end

function Hook:BeginService(Modules: table, InitData: table?, ChannelId: number)
	local Configuration = Modules.Configuration
	local ProcessLib = Modules.Process
	local Communication = Modules.Communication
	local ExtraData = InitData and InitData.ExtraData

	--// Add communication callbacks
	Communication:AddTypeCallbacks({
		["SetNewSpoofs"] = function(Spoofs)
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
	
	--// Process configuration
	ProcessLib:SetChannel(Channel, IsWrapped)
	ProcessLib:SetExtraData(ExtraData)

	--// Hook configuration
	self:Init(InitData)

	if ExtraData and ExtraData.IsActor then
		Communication:ConsolePrint("Actor connected!")
	end
end

function Hook:LoadMetaHooks(ActorCode: string, ChannelId: number)
	--// Hook actors
	if not Configuration.NoActors then
		self:RunOnActors(ActorCode, ChannelId)
	end

	--// Hook current thread
	self:BeginService(Modules, nil, ChannelId) 
end

function Hook:LoadReceiveHooks()
	local NoReceiveHooking = Config.NoReceiveHooking
	local BlackListedServices = Config.BlackListedServices

	if NoReceiveHooking then return end

	--// Remote added
	game.DescendantAdded:Connect(function(Remote) -- TODO
		self:ConnectClientRecive(Remote)
	end)

	--// Collect remotes with nil parents
	self:MultiConnect(getnilinstances())

	--// Search for existing remotes
	local AllInstances = game:GetDescendants()
	self:MultiConnect(AllInstances)
end

return Hook


--// Communication module (Module Giao tiếp)
local Communication = (function()
	type table = {
		[any]: any
	}

	--// Module
	local Module = {
		CommCallbacks = {}
	}

	local CommWrapper = {}
	CommWrapper.__index = CommWrapper

	--// Serializer cache
	local SerializeCache = setmetatable({}, {__mode = "k"})
	local DeserializeCache = setmetatable({}, {__mode = "k"})

	--// Services
	local CoreGui
	local Players = Services.Players
	local LocalPlayer = Players.LocalPlayer

	--// Modules
	local Hook
	local Channel
	local Config
	local Process

	function Module:Init(Data)
		local Modules = Data.Modules
		local Services = Data.Services
		local IsWrapped = Data.IsWrapped
		local ChannelId = Data.ChannelId

		Hook = Modules.Hook
		Process = Modules.Process
		Config = Modules.Config or Config
		CoreGui = Services.CoreGui
		
		if IsWrapped then
			Channel = Data.Channel
		else
			self:ConnectChannel(ChannelId)
		end
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

	function Module:ConnectChannel(ChannelId: number): Instance, CommWrapper
		local CommEvent = Instance.new("RemoteEvent")
		CommEvent.Name = `SigmaSpyCommEvent {ChannelId}`
		CommEvent.Parent = CoreGui

		--// Create wrapper
		local Wrapper = setmetatable({
			Channel = CommEvent,
			Queue = {}
		}, CommWrapper)

		--// Begin service
		Wrapper:BeginQueueService()

		--// Add event listener
		CommEvent.OnClientEvent:Connect(function(Type: string, ...): ...any
			local Callback = Module:GetCommCallback(Type)
			if not Callback then return end
			return Callback(...)
		end)

		return CommEvent, Wrapper
	end

	function Module:AddCommCallback(Type: string, Callback: (...any) -> ...any)
		local CommCallbacks = self.CommCallbacks
		CommCallbacks[Type] = Callback
	end

	function Module:AddCommCallbacks(Types: table)
		for Type: string, Callback in next, Types do
			self:AddCommCallback(Type, Callback)
		end
	end

	function Module:GetCommCallback(Type: string): (...any) -> ...any
		local CommCallbacks = self.CommCallbacks
		return CommCallbacks[Type]
	end

	function Module:ChannelIndex(Channel, Property: string)
		if typeof(Channel) == "Instance" then
			return Hook:Index(Channel, Property)
		end

		--// Some executors return a UserData type
		return Channel[Property]
	end

	function Module:Communicate(...)
		local Fire = self:ChannelIndex(Channel, "Fire")
		Fire(Channel, ...)
	end

	function Module:AddConnection(Callback): RBXScriptConnection
		local Event = self:ChannelIndex(Channel, "Event")
		return Event:Connect(Callback)
	end

	function Module:AddTypeCallback(Type: string, Callback): RBXScriptConnection
		local Event = self:ChannelIndex(Channel, "Event")
		return Event:Connect(function(RecivedType: string, ...): ...any
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
		local ChannelID = math.random(1, 1e9)
		local Event = Instance.new("RemoteEvent")
		Event.Name = `SigmaSpyEvent {ChannelID}`
		Event.Parent = CoreGui
		
		--// Connect GetCommCallback function
		Event.OnClientEvent:Connect(function(Type: string, ...): ...any
			local Callback = Module:GetCommCallback(Type)
			if not Callback then return end
			return Callback(...)
		end)

		return ChannelID, Event
	end
	
	function Module:QueueLog(Data: table)
		self:Communicate("QueueLog", Data)
	end

	function Module:ConsolePrint(...)
		self:Communicate("Print", table.pack(...))
	end

	return Module
end)()

--// Process module (Module Xử lý)
local Process = (function()
	type table = {
		[any]: any
	}

	type RemoteData = {
		Remote: Instance,
	    NoBacktrace: boolean?,
		IsReceive: boolean?,
		Args: table,
	    Id: string,
		Method: string,
	    TransferType: string,
		ValueReplacements: table,
	    ReturnValues: table,
	    OriginalFunc: (Instance, ...any) -> ...any
	}

	--// Module
	local Process = {
		--// Remote classes
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
				NoReciveHook = true,
				IsRemoteFunction = true,
				Send = {
					"Invoke",
				},
				Receive = {
					"OnInvoke",
				}
			}
		},
		RemoteOptions = {},
		ReturnSpoofs = {},
		ExtraData = {}
	}

	--// Modules
	local Hook
	local Config
	local Communication
	local Generation

	local Services = Services

	function Process:Init(Data)
		local Modules = Data.Modules

		Hook = Modules.Hook
		Config = Modules.Config or Config
		Communication = Modules.Communication or Communication
		Generation = Modules.Generation or Generation
	end

	function Process:SetChannel(Channel, IsWrapped)
		self.Channel = Channel
		self.IsWrapped = IsWrapped
	end

	function Process:SetExtraData(ExtraData: table)
		self.ExtraData = ExtraData
	end

	function Process:Unpack(Table: table)
		return table.unpack(Table)
	end

	function Process:Merge(Target: table, Source: table)
		for Key, Value in next, Source do
			Target[Key] = Value
		end
		return Target
	end

	function Process:CheckIsSupported(): boolean
		local Workspace = Services.Workspace

		local Result = select(2, pcall(Workspace.FindFirstChild, Workspace, "Test"))
		return not not Result
	end

	function Process:GetClassData(ClassName: string): table?
		return self.RemoteClassData[ClassName]
	end

	function Process:GetRemoteOptions(Remote: Instance): table?
		return self.RemoteOptions[Remote]
	end

	function Process:SetNewReturnSpoofs(Spoofs: table)
		self.ReturnSpoofs = Spoofs
	end

	function Process:GetScriptFromFunc(Func: (...any) -> ...any): LocalScript?
		local Script = select(1, debug.getupvalue(Func, 1)) -- Lấy upvalue đầu tiên, thường là script
		if typeof(Script) == "Instance" and (Script:IsA("LocalScript") or Script:IsA("ModuleScript")) then
			return Script
		end
		
		-- Fallback for better compatibility
		local Info = debug.getinfo(Func)
		if Info and Info.source then
			local Source = Info.source
			if Source:match("^@%a+") then
				return Services.Workspace:FindFirstChild(Source:sub(2), true) or nil -- Thử tìm script
			end
		end
		return nil
	end
	
	function Process:FindCallingLClosure(Level: number): (...any) -> ...any?
		local Level = Level or 3
		local Info = debug.getinfo(Level, "f")
		return Info and Info.func or nil
	end

	local function ProcessCallback(Data, Remote, ...)
		local RemoteOptions = Process:GetRemoteOptions(Remote)
		local Args = Data.Args
		local Method = Data.Method
		local MetaMethod = Data.MetaMethod
		local IsReceive = Data.IsReceive
		local ReturnSpoofs = Process.ReturnSpoofs

		--// Check for block
		if Flags:GetFlagValue("BlockInvocations") then
			if not IsReceive then
				return {}
			end
		end

		--// Check for spoofed return
		local Return = ReturnSpoofs[Data.Id] and ReturnSpoofs[Data.Id][Method]
		if Return then
			return Return.Values
		end
		
		--// Check for original
		local OriginalFunc = RemoteOptions.OriginalFunc
		if OriginalFunc and not IsReceive then
			return {OriginalFunc(Remote, Process:Unpack(Args))}
		end
	end

	function Process:ProcessRemote(Remote: Instance, Method: string, MetaMethod: string?, IsReceive: boolean?, ...): RemoteData
		local Id = tostring(Remote)
		local RemoteOptions = self.RemoteOptions
		local Timestamp = os.time()
		local RemoteData = RemoteOptions[Remote]

		--// Collect data
		local Data = self:Merge({
			Remote = Remote,
			IsReceive = IsReceive,
			Method = Method,
			MetaMethod = MetaMethod or (Flags:GetFlagValue("UseNamecall") and "__namecall") or "__index",
			Id = Id,
			TransferType = IsReceive and "Receive" or "Send",
			ReturnValues = {},
			Args = {}
		}, self.ExtraData)
		
		local ClassData = RemoteData and RemoteData.ClassData
		local CallingFunction: (...any) -> ...any? = nil
		local SourceScript: LocalScript? = nil
		
		--// Add to queue
		self:Merge(Data, {
			Remote = cloneref(Remote),
			CallingScript = getcallingscript(),
			CallingFunction = CallingFunction,
			SourceScript = SourceScript,
			Id = Id,
			ClassData = ClassData,
			Timestamp = Timestamp,
			Args = {...}
		})

		--// Invoke the Remote and log return values
		local ReturnValues = ProcessCallback(Data, Remote, ...)
		Data.ReturnValues = ReturnValues

		--// Queue log
		Communication:QueueLog(Data)

		return Data
	end

	function Process:SetAllRemoteData(Key: string, Value)
		local RemoteOptions = self.RemoteOptions
		for RemoteID, Data in next, RemoteOptions do
			Data[Key] = Value
		end
	end

	--// The communication creates a different table address
	--// Recived tables will not be the same
	function Process:SetRemoteData(Remote: Instance, RemoteData: table)
		local RemoteOptions = self.RemoteOptions
		RemoteOptions[Remote] = RemoteData
	end

	function Process:UpdateRemoteData(Id: string, RemoteData: table)
		Communication:Communicate("UpdateRemoteData", Id, RemoteData)
	end

	return Process
end)()


--// Main execution (Thực thi chính)

--// Services
local Players = Services.Players

local Modules = {
	Config = {}, -- Giả định module config rỗng
	ReturnSpoofs = {}, -- Giả định module ReturnSpoofs rỗng
	Configuration = Configuration,
	Files = Files,
	Process = Process,
	Hook = Hook,
	Communication = Communication,
	Flags = Flags,
	Generation = Generation,
	Ui = Ui,
}

local InitData = {
	Modules = Modules,
	Services = Services
}

--// Init files
Files:Init(InitData)

--// Init process (đã được gọi trong Hook:BeginService)
-- Process:Init(InitData)

--// Init Communication (đã được gọi trong Hook:BeginService)
-- Communication:Init(InitData)

--// Init UI (đã được gọi trong Hook:BeginService)
-- Ui:Init(InitData)

--// ReGui Create window (Tạo cửa sổ UI)
local Window = Ui:CreateMainWindow()

--// Check if Sigma spy is supported (Kiểm tra hỗ trợ)
local Supported = Process:CheckIsSupported()
if not Supported then 
	Window:Close()
	return
end

--// Create communication channel (Tạo kênh giao tiếp)
local ChannelId, Event = Communication:CreateChannel()
Communication:AddCommCallback("QueueLog", function(...)
	Ui:QueueLog(...)
end)
Communication:AddCommCallback("Print", function(...)
	Ui:ConsoleLog(...)
end)

--// Generation swaps (Hoán đổi để sinh mã)
local LocalPlayer = Players.LocalPlayer
Generation:SetSwapsCallback(function(self)
	self:AddSwap(LocalPlayer, {
		String = "LocalPlayer",
	})
	self:AddSwap(LocalPlayer.Character, {
		String = "Character",
		NextParent = LocalPlayer
	})
end)

--// Create window content (Tạo nội dung cửa sổ)
Ui:CreateWindowContent(Window)

--// Begin the Log queue (Bắt đầu hàng đợi Log)
Ui:SetCommChannel(Event)
Ui:BeginLogService()

--// Load hooks (Tải các hook)
local Scripts = {
	Process = Files:CompileLibrary(require(script.Process).Source, "Process"),
	Hook = Files:CompileLibrary(require(script.Hook).Source, "Hook"),
	Communication = Files:CompileLibrary(require(script.Communication).Source, "Communication"),
}
local ActorCode = Files:MakeActorScript(Scripts, ChannelId)
Hook:LoadMetaHooks(ActorCode, ChannelId)

local EnablePatches = Ui:AskUser({
	Title = "Enable function patches?",
	Content = {
		"On some executors, function patches can prevent common detections that executor has",
		"By enabling this, it MAY trigger hook detections in some games, this is why you are asked"
	},
	Buttons = {
		{
			Title = "Yes",
			Return = true
		},
		{
			Title = "No",
			Return = false
		}
	}
})

if EnablePatches then
	Hook:PatchFunctions()
end

Hook:BeginHooks()

--// Set flags callback
Flags:SetFlagCallbacks({
	["Paused"] = function(Value)
		Process:SetAllRemoteData("Paused", Value)
	end
})
