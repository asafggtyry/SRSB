--[[
OP Slap Royale - merged WindUI script

Migration map:
- Main tab:
  * Main.GetCodeGoBarn -> Get Code + Go Barn button
  * UI.OpenTeleportMenu -> Open Teleport Menu button
  * UI.SetAutoEarlyBusJump -> Early Bus Jump toggle
  * UI.SetInfiniteJump -> Infinite Jump toggle
  * UI.SetPlayerStatsESP -> Player Stats ESP toggle
  * UI.SetItemESP -> Item ESP toggle
  * UI.SetAutoRejoin -> Auto Rejoin toggle
  * UI.SetRecommendedSettings -> Recommended Settings toggle
  * Items.TeleportTo(itemName) -> side Teleport Menu / Items tab rows
  * Combat.TeleportToPlayer/Nearest/Lowest -> side Teleport Menu / Players tab rows
  * Teleport.ToLocation(locationName) -> side Teleport Menu / Locations tab rows
- Items tab:
  * Items.SetAutoCollect -> Auto collect toggle
  * Items.SetAutoPickup -> Auto pick up toggle
  * Items.SetAutoHeal -> Auto Heal toggle
  * Items.SetAutoSort -> Auto Sort toggle
  * Items.SetAutoPermanentItems -> Auto Use Permanent Items toggle
  * Items.UseSpheres -> Use Spheres button
  * Items.UseCubes -> Use Cubes button
  * Items.UseAllItems -> Use All Items button
  * Items.DropAllItems -> Drop All Items button
  * Items.DropAllPermanents -> Drop Permanent Items button
  * Items.DropTempItems -> Drop Temp Items button
  * Items.TeleportToCrate -> Meteor Crate button
- Teleports tab:
  * Teleport.ToSchoolBusTop -> Teleport On School Bus button
- Combat tab:
  * Combat.SetHitboxSize -> Hitbox Size slider
  * Combat.SetHitboxExpanded -> Expand Hitbox toggle
  * Combat.SetHitboxVisible -> Visualize Hitboxes toggle
  * Combat.SetSlapAura -> Slap Aura toggle
  * Combat.SetAutoGloveTap -> Auto Slap toggle
- BETA tab:
  * Items.CollectCrates -> Collect Crates button
  * Items.SetFastCollectCrates -> Auto collect crates toggle
  * Items.SetCrateAura -> Crate Aura toggle
  * Items.SetEarlyAutoCollect -> Early Auto Collect toggle
- Safety tab:
  * Teleport.RunAutoOptimizeCooldownSettings -> Auto optimize cooldown settings button
  * Anti.SetStaffEnabled -> Anti-Staff toggle
  * Anti.SetHideUnderMap -> Hide under map toggle
  * Combat.SetAntiSlap -> Anti-Ragdoll / Anti-Slap toggle
- Settings tab:
  * NotificationsDisabled state -> Disable Notifications toggle
  * WindUI theme API -> Theme dropdown
  * Preferences auto-save -> toggles, sliders, dropdowns, theme, and teleport menu state

Internal helper functions from the non-UI script are preserved and are not exposed as UI controls.
Old no-op callbacks were not carried over.
]]

--[[
UI-stripped version. Visual UI/tabs/dropdowns/toggles/notifications were removed.
Only non-UI runtime tables/functions from the supplied script were kept where possible.
]]

local Services = {
	Players = game:GetService("Players"),
	RunService = game:GetService("RunService"),
	TweenService = game:GetService("TweenService"),
	UserInputService = game:GetService("UserInputService"),
	MarketplaceService = game:GetService("MarketplaceService"),
	ContextActionService = game:GetService("ContextActionService"),
	CollectionService = game:GetService("CollectionService"),
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	TeleportService = game:GetService("TeleportService"),
	GuiService = game:GetService("GuiService"),
	ProximityPromptService = game:GetService("ProximityPromptService"),
	HttpService = game:GetService("HttpService")
}

local Players = Services.Players
local RunService = Services.RunService
local TweenService = Services.TweenService
local UserInputService = Services.UserInputService
local MarketplaceService = Services.MarketplaceService
local ContextActionService = Services.ContextActionService
local ReplicatedStorage = Services.ReplicatedStorage
local ProximityPromptService = Services.ProximityPromptService
local HttpService = Services.HttpService
local player = Players.LocalPlayer

local UNDER_MAP_PLATFORM_Y = -35
local UNDER_MAP_PLATFORM_THICKNESS = 0.2
local UNDER_MAP_SAFE_OFFSET = 4
local UNDER_MAP_PLATFORM_SIZE = Vector3.new(12000, UNDER_MAP_PLATFORM_THICKNESS, 12000)
local UnderMapSafetyPlatform = nil

local function isUnderMapSafetyPlatform(object)
	return object:IsA("BasePart")
		and object.Name == "Part"
		and object.Transparency >= 1
		and object.Anchored
		and math.abs(object.Position.Y - UNDER_MAP_PLATFORM_Y) <= 1
		and object.Size.X >= UNDER_MAP_PLATFORM_SIZE.X * 0.9
		and object.Size.Z >= UNDER_MAP_PLATFORM_SIZE.Z * 0.9
end

local function clearUnderMapSafetyPlatform()
	if UnderMapSafetyPlatform and UnderMapSafetyPlatform.Parent then
		UnderMapSafetyPlatform.CanCollide = false
		UnderMapSafetyPlatform.CanTouch = false
		UnderMapSafetyPlatform.CanQuery = false
	end

	for _, object in ipairs(workspace:GetChildren()) do
		if isUnderMapSafetyPlatform(object) then
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
		end
	end

	UnderMapSafetyPlatform = nil
end

local function ensureUnderMapSafetyPlatform()
	if UnderMapSafetyPlatform and UnderMapSafetyPlatform.Parent then
		return UnderMapSafetyPlatform
	end

	for _, object in ipairs(workspace:GetChildren()) do
		if isUnderMapSafetyPlatform(object) then
			UnderMapSafetyPlatform = object
			return object
		end
	end

	local platform = Instance.new("Part")
	platform.Name = "Part"
	platform.Size = UNDER_MAP_PLATFORM_SIZE
	platform.Position = Vector3.new(0, UNDER_MAP_PLATFORM_Y, 0)
	platform.Anchored = true
	platform.CanCollide = false
	platform.CanTouch = false
	platform.CanQuery = false
	platform.Transparency = 1
	platform.Material = Enum.Material.SmoothPlastic
	platform.Parent = workspace

	UnderMapSafetyPlatform = platform
	return platform
end

local sharedEnvironment = nil
do
	local success, environment = pcall(function()
		return type(getgenv) == "function" and getgenv() or nil
	end)

	if success and type(environment) == "table" then
		sharedEnvironment = environment

		if type(sharedEnvironment.OPSlapRoyaleCleanup) == "function" then
			pcall(sharedEnvironment.OPSlapRoyaleCleanup)
		end

		sharedEnvironment.OPSlapRoyaleCleanup = nil
	end
end

clearUnderMapSafetyPlatform()

local WindUI = loadstring(game:HttpGet(
	"https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
))()

local Settings = nil
local NotificationsDisabled = false
local Notify = {}

function Notify.Show(title, message, kind, icon, duration, important)
	if NotificationsDisabled then
		return
	end

	local payload = {
		Title = tostring(title or "Le Fairs Le Goopa"),
		Content = tostring(message or ""),
		Icon = icon or "bell",
		Duration = duration or (important and 4 or 3),
	}

	local ok = pcall(function()
		if WindUI and type(WindUI.Notify) == "function" then
			WindUI:Notify(payload)
		elseif WindUI and type(WindUI.Notification) == "function" then
			WindUI:Notification(payload)
		end
	end)

	if not ok then
		pcall(function()
			warn("[OP Slap Royale] " .. payload.Title .. ": " .. payload.Content)
		end)
	end
end

local createNotification = Notify.Show
local UI = {
	SkipNextBusLandingLockUntil = 0,
	BusLandingWasInBus = false,
	AutoEarlyBusJumpEnabled = false,
	AutoEarlyBusJumpThread = nil,
	AutoEarlyBusJumpFiredInBus = false,
	InfiniteJumpEnabled = false,
	InfiniteJumpConnection = nil,
	LastAutoEarlyBusJumpAt = 0,
	LastJumpBusSeenAt = 0,
	JumpBusSearchActive = false,
	ToggleRefs = {},
	InputRefs = {}
}

local gui = nil
local isTouchDevice = UserInputService.TouchEnabled
local function getViewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(660, 430)
end

local Utility = {}
local Main = {}
local Teleport = {}
local Items = {}
local Combat = {}
local Anti = {}

Main.CodeKeywords = {
	"math", "equation", "problem", "code", "puzzle",
	"question", "solve", "answer", "number"
}

Main.CodeSearchOrigin = Vector3.new(464, 29, 323)
Main.CodeSearchRadius = 180
Main.KeypadSearchRadius = 170

Teleport.DefaultMaxStrikes = 4
Teleport.DefaultCooldown = 3.5
Teleport.DefaultDebounce = 0.5
Teleport.DefaultPostFLock = 0.2
Teleport.MaxStrikes = Teleport.DefaultMaxStrikes
Teleport.Cooldown = Teleport.DefaultCooldown
Teleport.Debounce = Teleport.DefaultDebounce
Teleport.PostFLock = Teleport.DefaultPostFLock
Teleport.Strikes = 0
Teleport.LockedUntil = 0
Teleport.LastClickAt = 0
Teleport.BlockFUntil = 0
Teleport.BusTopRidePlatform = nil
Teleport.BusTopRideConnection = nil
Teleport.BusTopRideLastCFrame = nil
Teleport.StabilityWait = 4
Teleport.LastJumpAt = 0
Teleport.LastRagdolledAt = 0
Teleport.LastBusLandingAt = 0
Teleport.StabilityConnection = nil
Teleport.StabilityCheckInterval = 0.3
Teleport.LastStabilityCheckAt = 0
Teleport.AutoOptimizeCooldownApplying = false

Items.SearchRootName = "Items"
Items.SearchText = ""
Items.TeleportDebounce = Teleport.Debounce
Items.EarlyAutoCollectEnabled = false
Items.EarlyAutoCollectThread = nil
Items.EarlyAutoCollectToggle = nil
Items.AutoCollectEnabled = false
Items.AutoCollectThread = nil
Items.AutoCollectToggle = nil
Items.EarlyAutoCollectAutoStarted = false
Items.EarlyAutoCollectNotInLobby = false
Items.EarlyAutoCollectPauseUntil = 0
Items.EarlyAutoCollectRestoreAutoPickup = false
Items.EarlyAutoCollectRestoreAutoPermanent = false
Items.PriorityCollectRestoreAutoPermanent = {
	Auto = false,
	Early = false
}
Items.EarlyBusPriorityTeleportBusy = false
Items.EarlyBusPriorityTeleportToken = 0
Items.LastEarlyBusPriorityTeleportAt = 0
Items.AutoPickupEnabled = false
Items.AutoPickupToggle = nil
Items.AutoPickupPart = nil
Items.AutoPickupFollowConnection = nil
Items.AutoPickupTouchedConnection = nil
Items.AutoPickupTouchEndedConnection = nil
Items.AutoPickupThread = nil
Items.AutoPickupTouching = {}
Items.AutoPickupScanInterval = 0.25
Items.AutoPickupFollowInterval = 0.05
Items.LastAutoPickupFollowAt = 0
Items.Crates = {}
Items.KnownCrates = {}
Items.CrateButtonLabel = nil
Items.CrateWatcherConnections = {}
Items.CrateWatcherRoot = nil
Items.CrateWatcherStarting = false
Items.CrateCollectPart = nil
Items.CollectCratesBusy = false
Items.CollectCratesSlapInterval = 0.025
Items.CrateCollectSlaps = 8
Items.CrateCollectSlapInterval = 0.12
Items.FastCollectCratesEnabled = false
Items.FastCollectCratesThread = nil
Items.FastCollectCratesInterval = 0.08
Items.FastCollectCratesLastScan = 0
Items.FastCollectCratesScanInterval = 1.5
Items.FastCollectCratesBox = nil
Items.FastCollectCratesBoxSize = Vector3.new(20, 20, 20)
Items.FastCollectCratesOverlapParams = nil
Items.FastCollectCratesLastNearbyScan = 0
Items.FastCollectCratesNearbyScanInterval = 0.35
Items.FastCollectCratesNearbyCache = {}
Items.CratePartCache = {}
Items.CrateFireCache = {}
Items.CrateFireCacheInterval = 0.35
Items.CrateUsedCache = {}
Items.CrateUsedCacheInterval = 0.08
Items.CrateAuraEnabled = false
Items.CrateAuraThread = nil
Items.CrateAuraInterval = 0.04
Items.LastCrateNotificationAt = 0
Items.CrateNotificationCooldown = 3
Items.AutoCollectCratesLastStart = 0
Items.AutoCollectCratesStartCooldown = 1

Teleport.Locations = {
	{ Name = "Acid", Position = Vector3.new(-113, 14, -625) },
	{ Name = "Barn", Position = Vector3.new(477, 87, 318) },
	{ Name = "Beach", Position = Vector3.new(-463, 13, -702) },
	{ Name = "Bob Cave", Position = Vector3.new(315, 49, -576) },
	{ Name = "Bone Pit", Position = Vector3.new(-344, -150, -414) },
	{ Name = "Bunker", Position = Vector3.new(464, 29, 323) },
	{ Name = "Crystal", Position = Vector3.new(488, -50, -272) },
	{ Name = "Forest", Position = Vector3.new(7, 18, 4) },
	{ Name = "Lighthouse", Position = Vector3.new(113, 14, -625) },
	{ Name = "Saloon", Position = Vector3.new(-576, 17, -188) },
	{ Name = "School", Position = Vector3.new(494, 47, -322) },
	{ Name = "Shop", Position = Vector3.new(-575, 13, -481) },
	{ Name = "Towers", Position = Vector3.new(-31, 93, 428) },
	{ Name = "Tunnels", Position = Vector3.new(-561, -35, -234) },
	{ Name = "Volcano", Position = Vector3.new(-304, -26, 379) },
	{ Name = "Watch Tower", Position = Vector3.new(78, 124, 101) }
}

function Utility.NormalizeName(text)
	return string.lower(tostring(text):gsub("’", "'"))
end

function Utility.GetObjectCFrame(object)
	if object:IsA("BasePart") then
		return object.CFrame
	end

	if object:IsA("Model") then
		return object:GetPivot()
	end

	if object:IsA("Tool") then
		local handle = object:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle.CFrame
		end
	end

	local part = object:FindFirstChildWhichIsA("BasePart", true)
	return part and part.CFrame or nil
end

function Main.IsCodeRelevantName(text)
	local lower = string.lower(tostring(text))

	for _, word in ipairs(Main.CodeKeywords) do
		if string.find(lower, word, 1, true) then
			return true
		end
	end

	return string.find(lower, "barn", 1, true) ~= nil
end

function Main.GetPuzzleSearchRoots()
	local roots = {}
	local seen = {}

	local function addRoot(object)
		if object and not seen[object] then
			seen[object] = true
			table.insert(roots, object)
		end
	end

	local map = workspace:FindFirstChild("Map")
	if map then
		for _, object in ipairs(map:GetChildren()) do
			if Main.IsCodeRelevantName(object.Name) then
				addRoot(object)
			end
		end
	end

	local success, parts = pcall(function()
		return workspace:GetPartBoundsInRadius(Main.CodeSearchOrigin, Main.CodeSearchRadius)
	end)

	if success and parts then
		for _, part in ipairs(parts) do
			local object = part
			local chosen = nil

			while object and object ~= workspace do
				if (object:IsA("Folder") or object:IsA("Model")) and Main.IsCodeRelevantName(object.Name) then
					chosen = object
					break
				end

				object = object.Parent
			end

			addRoot(chosen or part)
		end
	end

	return roots
end

function Main.GetCodePieceFromAssetName(name)
	local text = tostring(name)
	local exactNumber = string.match(text, "^%s*(%d+)%s*$")

	if exactNumber and #exactNumber <= 4 then
		return exactNumber
	end

	local labeledDigit = string.match(text, "^%s*[Nn]umber%s*(%d)%s*$") or string.match(text, "^%s*[Dd]igit%s*(%d)%s*$")
	return labeledDigit
end

function Main.GetPuzzleCode()
	local found = {}
	local ids = {}

	local function isRelevant(object)
		local full = string.lower(object:GetFullName())
		local name = string.lower(object.Name)

		for _, word in ipairs(Main.CodeKeywords) do
			if string.find(full, word) or string.find(name, word) then
				return true
			end
		end

		return false
	end

	for _, root in ipairs(Main.GetPuzzleSearchRoots()) do
		for _, object in ipairs(root:GetDescendants()) do
			local image = nil

			if object:IsA("ImageLabel") or object:IsA("ImageButton") then
				image = object.Image
			elseif object:IsA("Decal") or object:IsA("Texture") then
				image = object.Texture
			end

			if image and image ~= "" and isRelevant(object) then
				local id = tonumber(string.match(image, "%d+"))

				if id and not found[id] then
					found[id] = true
					table.insert(ids, id)
				end
			end
		end
	end

	local code = ""

	for _, id in ipairs(ids) do
		local success, info = pcall(function()
			return MarketplaceService:GetProductInfo(id)
		end)

		if success and info and info.Name then
			local piece = Main.GetCodePieceFromAssetName(info.Name)

			if piece then
				code = code .. piece
			end
		end
	end

print("CODE:", code)
	return code
end

function Main.GetBarnKeypadButtonText(object)
	local text = tostring(object.Name or "")
	local scanned = 0

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			text ..= " " .. tostring(descendant.Text)
		end

		scanned += 1

		if scanned >= 120 then
			break
		end
	end

	return string.lower(text)
end

function Main.TextMatchesDigit(text, digit)
	text = string.lower(tostring(text or ""))
	digit = tostring(digit)

	return text == digit
		or string.find(text, "number%s*" .. digit) ~= nil
		or string.find(text, "digit%s*" .. digit) ~= nil
		or string.find(text, "button%s*" .. digit) ~= nil
		or string.find(text, "key%s*" .. digit) ~= nil
		or string.find(text, "%f[%d]" .. digit .. "%f[%D]") ~= nil
end

function Main.IsBarnSubmitButton(object, text)
	text = string.lower(tostring(text or object.Name or ""))

	if string.find(text, "green", 1, true)
		or string.find(text, "enter", 1, true)
		or string.find(text, "submit", 1, true)
		or string.find(text, "confirm", 1, true)
		or string.find(text, "accept", 1, true)
		or string.find(text, "check", 1, true) then
		return true
	end

	if object:IsA("BasePart") then
		local color = object.Color
		return color.G > 0.45 and color.G > color.R * 1.3 and color.G > color.B * 1.3
	end

	return false
end

function Main.GetBarnKeypadSearchObjects()
	local objects = {}
	local seen = {}

	local function add(object)
		if object and object.Parent and not seen[object] then
			seen[object] = true
			table.insert(objects, object)
		end
	end

	local ok, parts = pcall(function()
		return workspace:GetPartBoundsInRadius(Main.CodeSearchOrigin, Main.KeypadSearchRadius)
	end)

	if ok and parts then
		for _, part in ipairs(parts) do
			add(part)

			local current = part.Parent
			local depth = 0

			while current and current ~= workspace and depth < 4 do
				add(current)
				current = current.Parent
				depth += 1
			end
		end
	end

	return objects
end

function Main.FindBarnKeypadButton(target, isSubmit)
	local bestObject = nil
	local bestScore = -1

	for _, object in ipairs(Main.GetBarnKeypadSearchObjects()) do
		local text = Main.GetBarnKeypadButtonText(object)
		local full = string.lower(object:GetFullName())
		local score = -1

		if isSubmit then
			if Main.IsBarnSubmitButton(object, text) then
				score = 25
			end
		elseif Main.TextMatchesDigit(text, target) then
			score = 25
		end

		if score > 0 then
			if string.find(full, "keypad", 1, true) then
				score += 8
			end

			if string.find(full, "button", 1, true) then
				score += 5
			end

			if string.find(full, "barn", 1, true) then
				score += 4
			end

			if object:IsA("BasePart") then
				score += 2
			end

			if score > bestScore then
				bestScore = score
				bestObject = object
			end
		end
	end

	return bestObject
end

function Main.ActivateBarnKeypadButton(button)
	if not button or not button.Parent then
		return false
	end

	local clicked = false

	for _, descendant in ipairs(button:GetDescendants()) do
		if descendant:IsA("ClickDetector") and type(fireclickdetector) == "function" then
			pcall(function()
				fireclickdetector(descendant)
				clicked = true
			end)
		elseif descendant:IsA("ProximityPrompt") then
			pcall(function()
				if type(fireproximityprompt) == "function" then
					fireproximityprompt(descendant)
				else
					descendant:InputHoldBegin()
					task.wait(math.max(descendant.HoldDuration, 0.05))
					descendant:InputHoldEnd()
				end

				clicked = true
			end)
		end
	end

	if button:IsA("ClickDetector") and type(fireclickdetector) == "function" then
		pcall(function()
			fireclickdetector(button)
			clicked = true
		end)
	elseif button:IsA("ProximityPrompt") then
		pcall(function()
			if type(fireproximityprompt) == "function" then
				fireproximityprompt(button)
			else
				button:InputHoldBegin()
				task.wait(math.max(button.HoldDuration, 0.05))
				button:InputHoldEnd()
			end

			clicked = true
		end)
	elseif button:IsA("BasePart") and type(firetouchinterest) == "function" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root then
			pcall(function()
				firetouchinterest(root, button, 0)
				task.wait(0.04)
				firetouchinterest(root, button, 1)
				clicked = true
			end)
		end
	end

	return clicked
end

function Main.EnterBarnKeypadCode(code)
	code = tostring(code or ""):gsub("%D", "")

	if code == "" then
		return false
	end

	local pressed = 0

	for digit in string.gmatch(code, "%d") do
		local button = Main.FindBarnKeypadButton(digit, false)

		if not Main.ActivateBarnKeypadButton(button) then
			return false
		end

		pressed += 1
		task.wait(0.09)
	end

	local submitButton = Main.FindBarnKeypadButton(nil, true)

	if not Main.ActivateBarnKeypadButton(submitButton) then
		return false
	end

	return pressed == #code
end

function Main.GetCountdownNumber(text)
	text = tostring(text or "")

	local exact = string.match(text, "^%s*(%d+)%s*$")
	if exact then
		return tonumber(exact)
	end

	local minutes, seconds = string.match(text, "^%s*(%d+)%s*:%s*(%d+)%s*$")
	if minutes and seconds then
		return tonumber(minutes) * 60 + tonumber(seconds)
	end

	return nil
end

function Main.GetTimerCandidateScore(object, number)
	if not number or number < 0 or number > 600 then
		return -1
	end

	local score = 0
	local fullName = string.lower(object:GetFullName())
	local text = string.lower(tostring(object.Text))

	for _, word in ipairs({ "timer", "time", "countdown", "count", "start", "starting", "bus", "round", "match" }) do
		if string.find(fullName, word, 1, true) then
			score += 10
		end

		if string.find(text, word, 1, true) then
			score += 8
		end
	end

	if object.Visible then
		score += 2
	end

	if string.match(tostring(object.Text), "^%s*%d+%s*$") then
		score += 3
	end

	return score
end

function Main.FindSlapRoyaleTimer()
	local now = os.clock()
	local cachedObject = Main.TimerCachedObject

	if cachedObject and cachedObject.Parent then
		local number = Main.GetCountdownNumber(cachedObject.Text)

		if number then
			Main.TimerLastScanAt = now
			Main.TimerCachedNumber = number
			return number, cachedObject
		end
	end

	if Main.TimerLastScanAt and now - Main.TimerLastScanAt < (Main.TimerScanInterval or 0.22) then
		return Main.TimerCachedNumber, Main.TimerCachedObject
	end

	Main.TimerLastScanAt = now

	local bestObject = nil
	local bestNumber = nil
	local bestScore = -1
	local playerGui = player:FindFirstChild("PlayerGui")

	if not playerGui then
		return nil, nil
	end

	for _, object in ipairs(playerGui:GetDescendants()) do
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			local number = Main.GetCountdownNumber(object.Text)
			local score = Main.GetTimerCandidateScore(object, number)

			if score > bestScore then
				bestObject = object
				bestNumber = number
				bestScore = score
			end
		end
	end

	Main.TimerCachedObject = bestObject
	Main.TimerCachedNumber = bestNumber
	return bestNumber, bestObject
end

function Main.StartSlapRoyaleTimerPrinter()
	if Main.TimerPrinterRunning then
		return
	end

	Main.TimerPrinterRunning = true
	Main.TimerPrinterLastNumber = nil

	task.spawn(function()
		while Main.TimerPrinterRunning do
			local number = Main.FindSlapRoyaleTimer()

			if number then
				if not Main.TimerPrinterLastNumber or number < Main.TimerPrinterLastNumber then
					Main.TimerPrinterLastNumber = number

					if number <= 0 then
						Main.TimerPrinterRunning = false
						break
					end
				elseif number > Main.TimerPrinterLastNumber then
					Main.TimerPrinterLastNumber = number
				end
			end

			task.wait(0.25)
		end

		Main.TimerPrinterRunning = false
	end)
end

function Teleport.GetCooldownLeft()
	return math.max(0, math.ceil(Teleport.LockedUntil - os.clock()))
end

function Teleport.IsLocked()
	return os.clock() < Teleport.LockedUntil
end

function Teleport.ResetStrikesIfReady()
	local lastClickAt = tonumber(Teleport.LastClickAt) or 0
	local cooldown = tonumber(Teleport.Cooldown) or 0

	if lastClickAt == 0 or os.clock() - lastClickAt >= cooldown then
		Teleport.Strikes = 0
		Teleport.LockedUntil = 0
	end
end

function Teleport.ShowWarning(secondsText)
	Notify.Show(
		"Cooldown",
		"Wait " .. secondsText .. " before teleporting again.",
		"Warning",
		nil,
		2.2,
		true
	)
end

function Teleport.ShowStabilityWarning(reason, secondsLeft)
	Notify.Show(
		"Teleport",
		reason .. " Wait " .. tostring(math.max(1, math.ceil(secondsLeft))) .. " seconds.",
		"Warning",
		nil,
		2.2,
		true
	)
end

function Teleport.IsLocalRagdolled(character, humanoid)
	if not character or not humanoid then
		return false
	end

	local ragdollStatuses = {
		"Ragdoll",
		"Ragdolled",
		"IsRagdolled",
		"Knocked",
		"KnockedDown",
		"Downed"
	}

	for _, statusName in ipairs(ragdollStatuses) do
		local characterAttribute = character:GetAttribute(statusName)
		local humanoidAttribute = humanoid:GetAttribute(statusName)

		if characterAttribute == true or humanoidAttribute == true then
			return true
		end

		local statusObject = character:FindFirstChild(statusName, true) or humanoid:FindFirstChild(statusName, true)

		if statusObject then
			if statusObject:IsA("BoolValue") then
				if statusObject.Value == true then
					return true
				end
			else
				return true
			end
		end
	end

	local state = humanoid:GetState()

	return humanoid.PlatformStand
		or state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.FallingDown
end

function Teleport.UpdateLocalStability()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local now = os.clock()

	if not humanoid or not root or humanoid.Health <= 0 then
		Teleport.LastRagdolledAt = now
		return
	end

	local state = humanoid:GetState()

	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		Teleport.LastJumpAt = now
	end

	if Teleport.IsLocalRagdolled(character, humanoid) then
		Teleport.LastRagdolledAt = now
	end
end

function Teleport.StartStabilityWatcher()
	if Teleport.StabilityConnection then
		return
	end

	Teleport.StabilityConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - Teleport.LastStabilityCheckAt < Teleport.StabilityCheckInterval then
			return
		end

		Teleport.LastStabilityCheckAt = now
		Teleport.UpdateLocalStability()
	end)
end

function Teleport.StopStabilityWatcher()
	if Teleport.StabilityConnection then
		Teleport.StabilityConnection:Disconnect()
		Teleport.StabilityConnection = nil
	end
end

function Teleport.CanPassStabilityGate()
	local now = os.clock()
	local waitTime = Teleport.StabilityWait or 4
	local jumpLeft = waitTime - (now - (Teleport.LastJumpAt or 0))

	if jumpLeft > 0 then
		Teleport.ShowStabilityWarning("Wait after jumping before teleporting.", jumpLeft)
		return false
	end

	local ragdollLeft = waitTime - (now - (Teleport.LastRagdolledAt or now))

	if ragdollLeft > 0 then
		Teleport.ShowStabilityWarning("Recover from ragdoll before teleporting.", ragdollLeft)
		return false
	end

	local busLandingLeft = waitTime - (now - (Teleport.LastBusLandingAt or 0))

	if busLandingLeft > 0 then
		Teleport.ShowStabilityWarning("Wait after landing from the bus.", busLandingLeft)
		return false
	end

	return true
end

function Teleport.GetWaitBeforeTeleport(debounceOverride)
	local now = os.clock()

	if Teleport.IsLocked() then
		return math.max(0, Teleport.LockedUntil - now)
	end

	local debounce = tonumber(debounceOverride or Teleport.Debounce) or 0
	local lastClickAt = tonumber(Teleport.LastClickAt) or 0

	if lastClickAt ~= 0 then
		return math.max(0, debounce - (now - lastClickAt))
	end

	return 0
end

function Teleport.CanTeleport(debounceOverride, ignoreStability, silent)
	if not ignoreStability and not Teleport.CanPassStabilityGate() then
		return false
	end

	if Teleport.IsLocked() then
		if not silent then
			Teleport.ShowWarning(tostring(Teleport.GetCooldownLeft()))
		end
		return false
	end

	local now = os.clock()
	local debounce = tonumber(debounceOverride or Teleport.Debounce) or 0
	local lastClickAt = tonumber(Teleport.LastClickAt) or 0
	local debounceLeft = debounce - (now - lastClickAt)

	if lastClickAt ~= 0 and debounceLeft > 0 then
		if not silent then
			Teleport.ShowWarning(tostring(math.max(1, math.ceil(debounceLeft))))
		end
		return false
	end

	Teleport.ResetStrikesIfReady()
	return true
end

Teleport.StartStabilityWatcher()

function Teleport.AddStrike()
	Teleport.LastClickAt = os.clock()
	Teleport.Strikes += 1

	if Teleport.Strikes >= Teleport.MaxStrikes then
		Teleport.LockedUntil = os.clock() + Teleport.Cooldown
		Teleport.Strikes = 0
	end
end

function Teleport.AddFixedStrike(maxStrikes, cooldown)
	Teleport.LastClickAt = os.clock()
	Teleport.Strikes += 1

	if Teleport.Strikes >= (maxStrikes or Teleport.DefaultMaxStrikes) then
		Teleport.LockedUntil = os.clock() + (cooldown or Teleport.DefaultCooldown)
		Teleport.Strikes = 0
	end
end

function Teleport.StartFBlock(duration)
	local fLockDuration = Teleport.GetCustomFLockDuration and Teleport.GetCustomFLockDuration(duration) or (duration or Teleport.PostFLock)
	local unlockAt = os.clock() + fLockDuration
	Teleport.BlockFUntil = math.max(Teleport.BlockFUntil or 0, unlockAt)
	Teleport.RefreshPickupLock()
end

function Teleport.StartBusLandingFBlock(duration)
	local now = os.clock()
	local fLockDuration = Teleport.GetCustomFLockDuration and Teleport.GetCustomFLockDuration(duration or 10) or (duration or 10)
	local unlockAt = now + fLockDuration

	Teleport.BlockFUntil = math.max(Teleport.BlockFUntil or 0, unlockAt)
	Items.BusLandingFBlockActive = true
	Teleport.RefreshPickupLock()

	task.delay(math.max(0.05, unlockAt - os.clock()), function()
		if Teleport.BlockFUntil <= unlockAt + 0.02 then
			Items.BusLandingFBlockActive = false
		end
	end)
end

function Teleport.StartBusLandingLock(duration)
	local now = os.clock()
	local lockDuration = duration or Teleport.StabilityWait or 4
	local fLockDuration = Teleport.GetCustomFLockDuration and Teleport.GetCustomFLockDuration(lockDuration) or lockDuration
	local lockUntil = now + lockDuration
	local unlockAt = now + fLockDuration

	Teleport.LastBusLandingAt = now
	Teleport.LockedUntil = math.max(Teleport.LockedUntil, lockUntil)
	Teleport.BlockFUntil = math.max(Teleport.BlockFUntil, unlockAt)
	Items.BusLandingFBlockActive = true
	Teleport.RefreshPickupLock()

	task.delay(math.max(0.05, unlockAt - os.clock()), function()
		if Teleport.BlockFUntil <= unlockAt + 0.02 then
			Items.BusLandingFBlockActive = false
		end
	end)
end

function Teleport.RefreshPickupLock()
	local unlockAt = Teleport.BlockFUntil

	pcall(function()
		game:GetService("ProximityPromptService").Enabled = false
	end)

	task.delay(math.max(0.05, unlockAt - os.clock()), function()
		if Teleport.BlockFUntil <= unlockAt + 0.02 then
			pcall(function()
				game:GetService("ProximityPromptService").Enabled = true
			end)
		end
	end)
end

function Teleport.ShowFBlockedWarning()
	local secondsLeft = math.max(0.1, Teleport.BlockFUntil - os.clock())

	Notify.Show(
		"Cooldown",
		"Wait " .. string.format("%.1f", secondsLeft) .. " seconds before pressing F again.",
		"Warning",
		nil,
		1.4,
		true
	)
end

function Teleport.MoveRoot(root, targetCFrame, lookAtPosition)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	if lookAtPosition then
		local flatLookAt = Vector3.new(lookAtPosition.X, targetCFrame.Position.Y, lookAtPosition.Z)

		if (flatLookAt - targetCFrame.Position).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(targetCFrame.Position, flatLookAt)
		else
			root.CFrame = CFrame.new(targetCFrame.Position)
		end

	else
		local _, yRotation, _ = root.CFrame:ToOrientation()
		root.CFrame = CFrame.new(targetCFrame.Position) * CFrame.Angles(0, yRotation, 0)
	end

	task.wait()

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function Teleport.StabilizeItemView(root, itemPart)
	if not root or not root.Parent or not itemPart or not itemPart.Parent then
		return
	end

	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	if camera then
		local focus = itemPart.Position + Vector3.new(0, 0.8, 0)
		local ignore = { character }

		table.insert(ignore, itemPart)

		if itemPart.Parent then
			table.insert(ignore, itemPart.Parent)
		end

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = ignore

		pcall(function()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
		end)

		local overlapParams = OverlapParams.new()
		overlapParams.FilterDescendantsInstances = ignore

		pcall(function()
			overlapParams.FilterType = Enum.RaycastFilterType.Exclude
		end)

		local function isBlockingCameraPart(part)
			if not part or not part:IsA("BasePart") then
				return false
			end

			if character and part:IsDescendantOf(character) then
				return false
			end

			return part.CanCollide and part.Transparency < 0.95
		end

		local function isCameraSpotClear(position)
			local parts = workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(1.6, 1.6, 1.6), overlapParams)

			for _, part in ipairs(parts) do
				if isBlockingCameraPart(part) then
					return false
				end
			end

			local headPosition = root.Position + Vector3.new(0, 2.5, 0)
			local overheadHit = workspace:Raycast(headPosition, position - headPosition, rayParams)

			if overheadHit and isBlockingCameraPart(overheadHit.Instance) then
				return false
			end

			local viewHit = workspace:Raycast(position, focus - position, rayParams)

			if viewHit and isBlockingCameraPart(viewHit.Instance) and (viewHit.Position - focus).Magnitude > 2.5 then
				return false
			end

			return true
		end

		local cameraPositions = {
			root.Position + Vector3.new(0, 13, 0),
			root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 10, 0),
			root.Position - root.CFrame.LookVector * 10 + Vector3.new(0, 4, 0),
			root.Position + root.CFrame.RightVector * 8 + Vector3.new(0, 5, 0),
			root.Position - root.CFrame.RightVector * 8 + Vector3.new(0, 5, 0),
		}

		local cameraPosition = cameraPositions[3]

		for _, position in ipairs(cameraPositions) do
			if isCameraSpotClear(position) then
				cameraPosition = position
				break
			end
		end

		if humanoid then
			camera.CameraSubject = humanoid
		end

		camera.CameraType = Enum.CameraType.Custom
		camera.CFrame = CFrame.lookAt(cameraPosition, focus)
	end
end

function Teleport.GetGroundCFrame(position, excludeInstances, stayClose)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeInstances or {}

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = excludeInstances or {}

	local function hasRoom(candidatePosition)
		local touching = workspace:GetPartBoundsInBox(CFrame.new(candidatePosition + Vector3.new(0, 2, 0)), Vector3.new(4, 5, 4), overlapParams)

		for _, part in ipairs(touching) do
			if part.CanCollide and part.Transparency < 0.95 then
				return false
			end
		end

		return true
	end

	local offsets = stayClose and {
		Vector3.zero,
		Vector3.new(2, 0, 0),
		Vector3.new(-2, 0, 0),
		Vector3.new(0, 0, 2),
		Vector3.new(0, 0, -2),
		Vector3.new(3, 0, 3),
		Vector3.new(-3, 0, 3),
		Vector3.new(3, 0, -3),
		Vector3.new(-3, 0, -3)
	} or {
		Vector3.zero,
		Vector3.new(6, 0, 0),
		Vector3.new(-6, 0, 0),
		Vector3.new(0, 0, 6),
		Vector3.new(0, 0, -6),
		Vector3.new(8, 0, 8),
		Vector3.new(-8, 0, 8),
		Vector3.new(8, 0, -8),
		Vector3.new(-8, 0, -8)
	}

	for _, offset in ipairs(offsets) do
		local rayOrigin = position + offset + Vector3.new(0, 6, 0)
		local rayDirection = Vector3.new(0, -90, 0)
		local result = workspace:Raycast(rayOrigin, rayDirection, params)
		local candidatePosition = result and (result.Position + Vector3.new(0, 4, 0)) or (position + offset + Vector3.new(0, 4, 0))

		if hasRoom(candidatePosition) then
			return CFrame.new(candidatePosition)
		end
	end

	return CFrame.new(position + Vector3.new(0, 4, 0))
end

function Teleport.GetItemCFrame(itemPart, excludeInstances)
	local position = itemPart.Position

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeInstances or {}

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = excludeInstances or {}

	local function hasRoom(candidatePosition)
		local touching = workspace:GetPartBoundsInBox(CFrame.new(candidatePosition + Vector3.new(0, 1.8, 0)), Vector3.new(2.8, 4.4, 2.8), overlapParams)

		for _, part in ipairs(touching) do
			if part ~= itemPart and part.CanCollide and part.Transparency < 0.95 then
				return false
			end
		end

		return true
	end

	local function canSeeItem(candidatePosition)
		local itemFocus = position + Vector3.new(0, 1, 0)
		local viewPosition = candidatePosition + Vector3.new(0, 1.6, 0)
		local direction = itemFocus - viewPosition

		if direction.Magnitude <= 0.1 then
			return true
		end

		local result = workspace:Raycast(viewPosition, direction, params)
		return not result or (result.Position - itemFocus).Magnitude <= 1.5
	end

	local roofResult = workspace:Raycast(position + Vector3.new(0, 0.5, 0), Vector3.new(0, 7, 0), params)
	local hasRoofAbove = roofResult and roofResult.Instance and roofResult.Instance.CanCollide and roofResult.Instance.Transparency < 0.95

	local centerOffsets = {
		Vector3.zero,
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1)
	}

	local roofOffsets = {
		Vector3.new(0.8, 0, 0),
		Vector3.new(-0.8, 0, 0),
		Vector3.new(0, 0, 0.8),
		Vector3.new(0, 0, -0.8),
		Vector3.new(1.4, 0, 1.4),
		Vector3.new(-1.4, 0, 1.4),
		Vector3.new(1.4, 0, -1.4),
		Vector3.new(-1.4, 0, -1.4),
		Vector3.new(2, 0, 0),
		Vector3.new(-2, 0, 0),
		Vector3.new(0, 0, 2),
		Vector3.new(0, 0, -2)
	}

	local sideOffsets = {
		Vector3.new(3, 0, 0),
		Vector3.new(-3, 0, 0),
		Vector3.new(0, 0, 3),
		Vector3.new(0, 0, -3),
		Vector3.new(4, 0, 4),
		Vector3.new(-4, 0, 4),
		Vector3.new(4, 0, -4),
		Vector3.new(-4, 0, -4)
	}

	local searchOffsets = hasRoofAbove and roofOffsets or centerOffsets

	if not hasRoofAbove then
		local rayStartHeight = math.min((itemPart.Size.Y / 2) + 1.5, 4)
		local rayOrigin = position + Vector3.new(0, rayStartHeight, 0)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -35, 0), params)

		if result and result.Position.Y <= position.Y + 0.6 and position.Y - result.Position.Y <= 18 then
			local candidatePosition = result.Position + Vector3.new(0, 4, 0)

			if hasRoom(candidatePosition) then
				return CFrame.new(candidatePosition)
			end
		end
	end

	for _, offset in ipairs(searchOffsets) do
		local rayStartHeight = math.min((itemPart.Size.Y / 2) + 1.5, 4)
		local rayOrigin = position + offset + Vector3.new(0, rayStartHeight, 0)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -35, 0), params)

		if result and result.Position.Y <= position.Y + 0.6 and position.Y - result.Position.Y <= 18 then
			local candidatePosition = result.Position + Vector3.new(0, 4, 0)

			if hasRoom(candidatePosition) and (not hasRoofAbove or canSeeItem(candidatePosition)) then
				return CFrame.new(candidatePosition)
			end
		end
	end

	for _, offset in ipairs(searchOffsets) do
		local rayOrigin = position + offset + Vector3.new(0, 1.5, 0)
		local result = workspace:Raycast(rayOrigin, Vector3.new(0, -20, 0), params)

		if result and math.abs(result.Position.Y - position.Y) <= 12 then
			local candidatePosition = result.Position + Vector3.new(0, 4, 0)

			if hasRoom(candidatePosition) and (not hasRoofAbove or canSeeItem(candidatePosition)) then
				return CFrame.new(candidatePosition)
			end
		end
	end

	for _, offset in ipairs(searchOffsets) do
		local candidatePosition = position + offset + Vector3.new(0, 4, 0)

		if hasRoom(candidatePosition) and (not hasRoofAbove or canSeeItem(candidatePosition)) then
			return CFrame.new(candidatePosition)
		end
	end

	if hasRoofAbove then
		for _, offset in ipairs(sideOffsets) do
			local rayOrigin = position + offset + Vector3.new(0, 1.5, 0)
			local result = workspace:Raycast(rayOrigin, Vector3.new(0, -20, 0), params)

			if result and math.abs(result.Position.Y - position.Y) <= 12 then
				local candidatePosition = result.Position + Vector3.new(0, 4, 0)

				if hasRoom(candidatePosition) and canSeeItem(candidatePosition) then
					return CFrame.new(candidatePosition)
				end
			end
		end
	end

	return CFrame.new(position + Vector3.new(0, 4, 0))
end

function Teleport.CreateMarker(position)
	return nil
end

function Teleport.ToLocation(locationName, position, forceTeleport)
	if forceTeleport then
		Teleport.LockedUntil = 0
		Teleport.LastClickAt = 0
		Teleport.Strikes = 0
	elseif not Teleport.CanTeleport() then
		return
	end

	if typeof(position) == "CFrame" then
		position = position.Position
	end

	if typeof(position) ~= "Vector3" then
		for _, location in ipairs(Teleport.Locations) do
			if location.Name == locationName then
				position = location.Position
				break
			end
		end
	end

	if typeof(position) ~= "Vector3" then
		createNotification("Teleport", "Could not find location: " .. tostring(locationName), "Error")
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)

	if not root then
		createNotification("Teleport", "Could not find your character.", "Error")
		return
	end

	local groundCFrame = Teleport.GetGroundCFrame(position, { character })
	local distance = (root.Position - groundCFrame.Position).Magnitude

	print("[TELEPORT DEBUG]", locationName, "distance:", math.floor(distance), "target:", groundCFrame.Position)

	Teleport.MoveRoot(root, groundCFrame)

	if not forceTeleport then
		Teleport.AddStrike()
		Teleport.StartFBlock()
	end

	createNotification("Teleport", "Teleported to " .. locationName)
end

function Teleport.GetBusCandidateFromObject(object)
	local current = object
	local candidate = nil

	while current and current ~= workspace do
		local name = Utility.NormalizeName(current.Name)

		if string.find(name, "bus", 1, true) and (current:IsA("Model") or current:IsA("BasePart")) then
			candidate = current
		end

		current = current.Parent
	end

	return candidate
end

function Teleport.GetBusParts(candidate)
	local parts = {}

	if not candidate or not candidate.Parent then
		return parts
	end

	if candidate:IsA("BasePart") then
		table.insert(parts, candidate)
		return parts
	end

	for _, object in ipairs(candidate:GetDescendants()) do
		if object:IsA("BasePart") then
			table.insert(parts, object)
		end
	end

	return parts
end

function Teleport.GetObjectWorldPosition(object)
	if object:IsA("BasePart") then
		return object.Position
	end

	if object:IsA("Model") then
		local ok, pivot = pcall(function()
			return object:GetPivot()
		end)

		if ok and pivot then
			return pivot.Position
		end

		local boxOk, cframe = pcall(function()
			return object:GetBoundingBox()
		end)

		if boxOk and cframe then
			return cframe.Position
		end
	end

	return nil
end

function Teleport.IsSchoolHouseBusCandidate(candidate)
	local position = Teleport.GetObjectWorldPosition(candidate)

	return position and (position - Vector3.new(494, 47, -322)).Magnitude <= 220
end

function Teleport.FindSchoolBusTopTarget()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local seen = {}
	local bestCandidate = nil
	local bestParts = nil
	local bestDistance = math.huge

	for _, object in ipairs(workspace:GetDescendants()) do
		local candidate = Teleport.GetBusCandidateFromObject(object)

		if candidate and candidate.Parent and not seen[candidate] and not Teleport.IsSchoolHouseBusCandidate(candidate) then
			seen[candidate] = true

			local parts = Teleport.GetBusParts(candidate)
			local position = Teleport.GetObjectWorldPosition(candidate)

			if #parts > 0 and position then
				local distance = root and (root.Position - position).Magnitude or 0

				if distance < bestDistance then
					bestDistance = distance
					bestCandidate = candidate
					bestParts = parts
				end
			end
		end
	end

	return bestCandidate, bestParts
end

function Teleport.MakeBusCollidable(parts)
	for _, part in ipairs(parts or {}) do
		if part and part.Parent then
			pcall(function()
				part.CanCollide = true
				part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1, 0, 100, 0)
			end)
		end
	end
end

function Teleport.ClearBusTopRidePlatform()
	if Teleport.BusTopRideConnection then
		Teleport.BusTopRideConnection:Disconnect()
		Teleport.BusTopRideConnection = nil
	end

	if Teleport.BusTopRidePlatform and Teleport.BusTopRidePlatform.Parent then
		Teleport.BusTopRidePlatform:Destroy()
	end

	Teleport.BusTopRidePlatform = nil
	Teleport.BusTopRideLastCFrame = nil
end

function Teleport.GetBusTopCFrame(candidate, parts)
	local topPart = nil
	local topY = -math.huge

	for _, part in ipairs(parts or {}) do
		if part and part.Parent then
			local partTopY = part.Position.Y + (part.Size.Y * 0.5)

			if partTopY > topY then
				topY = partTopY
				topPart = part
			end
		end
	end

	if not topPart then
		return nil
	end

	local targetPosition = topPart.Position + Vector3.new(0, (topPart.Size.Y * 0.5) + 5, 0)
	local platformPosition = Vector3.new(topPart.Position.X, topY + 0.15, topPart.Position.Z)

	if candidate and candidate:IsA("Model") then
		local ok, boxCFrame, boxSize = pcall(function()
			return candidate:GetBoundingBox()
		end)

		if ok and boxCFrame and boxSize then
			targetPosition = Vector3.new(boxCFrame.Position.X, boxCFrame.Position.Y + (boxSize.Y * 0.5) + 5, boxCFrame.Position.Z)
			platformPosition = Vector3.new(boxCFrame.Position.X, boxCFrame.Position.Y + (boxSize.Y * 0.5) + 0.15, boxCFrame.Position.Z)
		end
	end

	return CFrame.new(targetPosition), CFrame.new(platformPosition), topPart
end

function Teleport.IsRootOnBusTopRide(root, platformCFrame)
	if not root or not platformCFrame then
		return false
	end

	local localPosition = platformCFrame:PointToObjectSpace(root.Position)

	return math.abs(localPosition.X) <= 18
		and math.abs(localPosition.Z) <= 18
		and localPosition.Y >= -4
		and localPosition.Y <= 12
end

function Teleport.CreateBusTopRidePlatform(candidate, parts, platformCFrame, topPart)
	Teleport.ClearBusTopRidePlatform()

	if not platformCFrame then
		return
	end

	local platform = Instance.new("Part")
	platform.Name = "Part"
	platform.Size = Vector3.new(18, 0.3, 18)
	platform.CFrame = platformCFrame
	platform.Anchored = topPart == nil
	platform.Massless = true
	platform.CanCollide = true
	platform.CanTouch = false
	platform.CanQuery = false
	platform.Transparency = 1
	platform.Material = Enum.Material.SmoothPlastic
	platform.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1, 0, 100, 0)
	platform.Parent = workspace

	if topPart and topPart.Parent then
		local weld = Instance.new("WeldConstraint")
		weld.Name = "Part"
		weld.Part0 = platform
		weld.Part1 = topPart
		weld.Parent = platform
	end

	Teleport.BusTopRidePlatform = platform
	Teleport.BusTopRideLastCFrame = platformCFrame
	Teleport.BusTopRideConnection = RunService.Heartbeat:Connect(function(dt)
		if not platform.Parent or not candidate or not candidate.Parent or (topPart and not topPart.Parent) then
			Teleport.ClearBusTopRidePlatform()
			return
		end

		local _, nextPlatformCFrame = Teleport.GetBusTopCFrame(candidate, parts)

		if nextPlatformCFrame then
			local lastCFrame = Teleport.BusTopRideLastCFrame or platform.CFrame
			local delta = nextPlatformCFrame.Position - lastCFrame.Position
			local horizontalDelta = Vector3.new(delta.X, 0, delta.Z)

			if platform.Anchored then
				platform.CFrame = nextPlatformCFrame
			end

			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")

			if root and Teleport.IsRootOnBusTopRide(root, lastCFrame) and horizontalDelta.Magnitude > 0.001 and horizontalDelta.Magnitude < 80 then
				root.CFrame = root.CFrame + horizontalDelta

				local velocity = root.AssemblyLinearVelocity
				local followDt = math.max(dt or 0, 1 / 240)
				root.AssemblyLinearVelocity = Vector3.new(horizontalDelta.X / followDt, velocity.Y, horizontalDelta.Z / followDt)
			end

			Teleport.BusTopRideLastCFrame = nextPlatformCFrame
		end
	end)
end

function Teleport.ToSchoolBusTop()
	if not Teleport.CanTeleport(Teleport.DefaultDebounce) then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)

	if not root then
		createNotification("School Bus", "Could not find your character.", "Error")
		return
	end

	local bus, parts = Teleport.FindSchoolBusTopTarget()
	local targetCFrame, platformCFrame, topPart = Teleport.GetBusTopCFrame(bus, parts)

	if not bus or not targetCFrame then
		createNotification("School Bus", "Could not find a bus outside the schoolhouse area.", "Warning")
		return
	end

	Teleport.MakeBusCollidable(parts)
	Teleport.CreateBusTopRidePlatform(bus, parts, platformCFrame, topPart)
	if UI then
		UI.SkipNextBusLandingLockUntil = os.clock() + 3
		UI.BusLandingWasInBus = false
	end
	Teleport.MoveRoot(root, targetCFrame)
	Teleport.AddFixedStrike(Teleport.DefaultMaxStrikes, Teleport.DefaultCooldown)
	Teleport.StartFBlock()
	createNotification("School Bus", "Teleported on top of the bus.", "Success")
end

Items.SearchCache = {}
Items.SearchChildrenCache = {}
Items.SearchCacheBusy = false
Items.LastSearchCacheAt = 0
Items.SearchCacheCooldown = 60
Items.SearchCacheDirty = true
Items.SearchCacheRoot = nil
Items.SearchCacheRootConnections = {}

function Items.GetSearchRoot()
	local exactRoot = workspace:FindFirstChild(Items.SearchRootName)

	if exactRoot then
		return exactRoot
	end

	local wantedName = string.lower(Items.SearchRootName)

	for _, child in ipairs(workspace:GetChildren()) do
		if string.lower(child.Name) == wantedName then
			return child
		end
	end

	return nil
end

function Items.MarkSearchCacheDirty()
	Items.SearchCacheDirty = true
end

function Items.ClearSearchRootConnections()
	for _, connection in ipairs(Items.SearchCacheRootConnections) do
		if connection then
			connection:Disconnect()
		end
	end

	Items.SearchCacheRootConnections = {}
end

function Items.WatchSearchRoot(root)
	if Items.SearchCacheRoot == root then
		return
	end

	Items.ClearSearchRootConnections()
	Items.SearchCacheRoot = root

	if not root then
		return
	end

	table.insert(Items.SearchCacheRootConnections, root.ChildAdded:Connect(Items.MarkSearchCacheDirty))
	table.insert(Items.SearchCacheRootConnections, root.ChildRemoved:Connect(Items.MarkSearchCacheDirty))
end

function Items.RebuildSearchCache()
	if Items.SearchCacheBusy then
		return
	end

	Items.SearchCacheBusy = true

	local root = Items.GetSearchRoot()
	Items.WatchSearchRoot(root)

	if not root then
		Items.SearchCache = {}
		Items.SearchChildrenCache = {}
		Items.LastSearchCacheAt = os.clock()
		Items.SearchCacheDirty = false
		Items.SearchCacheBusy = false
		return
	end

	local children = root:GetChildren()
	local results = {}
	local lookup = Items.SearchNameLookup

	for _, object in ipairs(children) do
		if not lookup or lookup[Utility.NormalizeName(object.Name)] then
			table.insert(results, object)
		end
	end

	Items.SearchCache = results
	Items.SearchChildrenCache = children
	Items.LastSearchCacheAt = os.clock()
	Items.SearchCacheDirty = false
	Items.SearchCacheBusy = false
end

function Items.GetSearchDescendants()
	if Items.SearchCacheDirty or os.clock() - Items.LastSearchCacheAt > Items.SearchCacheCooldown then
		Items.RebuildSearchCache()
	end

	return Items.SearchCache
end

function Items.GetSearchChildren()
	if Items.SearchCacheDirty or os.clock() - Items.LastSearchCacheAt > Items.SearchCacheCooldown then
		Items.RebuildSearchCache()
	end

	return Items.SearchChildrenCache
end

local itemNameAliases = {
	["Bull's Essence"] = {
		"Bull's essence"
	},
	["Sphere of Fury"] = {
		"Sphere of fury"
	}
}

local getFullCollectibleSearchPool
local getItemTeleportDiscoveryPool
local getStrictItemMatchObject

local function strictItemNameMatches(candidateName, wantedName)
	local normalizedCandidate = Utility.NormalizeName(candidateName)
	local normalizedWanted = Utility.NormalizeName(wantedName)

	if candidateName == wantedName or normalizedCandidate == normalizedWanted then
		return true
	end

	local aliases = itemNameAliases[wantedName]
	if aliases then
		for _, alias in ipairs(aliases) do
			local normalizedAlias = Utility.NormalizeName(alias)

			if candidateName == alias or normalizedCandidate == normalizedAlias then
				return true
			end
		end
	end

	return false
end

function Items.FindManualItem(itemName)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return nil, nil
	end

	local closestObject = nil
	local closestPart = nil
	local closestDistance = math.huge

	local searchPool = getItemTeleportDiscoveryPool and getItemTeleportDiscoveryPool()
		or (getFullCollectibleSearchPool and getFullCollectibleSearchPool())
		or Items.GetSearchDescendants()

	for _, object in ipairs(searchPool) do
		local matchObject = getStrictItemMatchObject and getStrictItemMatchObject(object, itemName) or nil
		local displayName = object.Name

		if matchObject or strictItemNameMatches(displayName, itemName) then
			local itemObject = matchObject or object
			local itemCFrame = Utility.GetObjectCFrame(itemObject)

			if itemCFrame then
				local part = itemObject:IsA("BasePart") and itemObject or itemObject:FindFirstChildWhichIsA("BasePart", true)

				if part
					and part.Parent
					and part:IsDescendantOf(workspace)
					and part.Transparency < 0.95
					and part.Size.X > 0
					and part.Size.Y > 0
					and part.Size.Z > 0
				then
					local distance = (root.Position - part.Position).Magnitude

					if distance < closestDistance then
						closestDistance = distance
						closestObject = itemObject
						closestPart = part
					end
				end
			end
		end
	end

	return closestObject, closestPart
end

function Items.TeleportTo(itemName)
	if not Teleport.CanTeleport(Items.TeleportDebounce) then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		createNotification("Items", "Could not find your character.", "Error")
		return
	end

	local itemObject, itemPart = Items.FindManualItem(itemName)

	if not itemObject or not itemPart then
		createNotification("Items", itemName .. " is not currently available.")
		return
	end

	task.wait(0.08)

	if not itemObject.Parent
		or not itemPart.Parent
		or not itemPart:IsDescendantOf(workspace)
		or itemPart.Transparency >= 0.95
	then
		createNotification("Items", itemName .. " disappeared before teleporting.")
		return
	end

	local groundCFrame = Teleport.GetItemCFrame(itemPart, { character, itemObject })

	Teleport.MoveRoot(root, groundCFrame, itemPart.Position)
	Teleport.StabilizeItemView(root, itemPart)
	Teleport.AddStrike()
	Teleport.StartFBlock()
	createNotification("Items", "Teleported to " .. itemName)
end

function Items.GetCratePart(crate)
	if not crate or not crate.Parent or not crate:IsDescendantOf(workspace) then
		return nil
	end

	if crate:IsA("BasePart") then
		Items.CratePartCache[crate] = crate
		return crate
	end

	local cachedPart = Items.CratePartCache[crate]

	if cachedPart and cachedPart.Parent and cachedPart:IsDescendantOf(crate) then
		return cachedPart
	end

	local part = nil

	if crate:IsA("Model") then
		part = crate.PrimaryPart or crate:FindFirstChildWhichIsA("BasePart", true)
	else
		part = crate:FindFirstChildWhichIsA("BasePart", true)
	end

	if part then
		Items.CratePartCache[crate] = part
	end

	return part
end

function Items.IsKnownNonCrateItemName(text)
	local normalizedName = Utility.NormalizeName(text)
	local knownNames = {
		"Apple", "Bandage", "Boba", "Bomb", "Bombs", "Bull's Essence",
		"Cube of Ice", "First Aid Kit", "Forcefield Crystal", "Frog Potion",
		"Gravitation Shard", "Healing Potion", "Lightning Potion",
		"Potion of Strength", "Speed Potion", "Sphere of Fury",
		"Tomahawk", "True Power"
	}

	for _, itemName in ipairs(knownNames) do
		if normalizedName == Utility.NormalizeName(itemName) then
			return true
		end
	end

	return false
end

function Items.NameLooksLikeCrate(text)
	local normalizedName = Utility.NormalizeName(text)

	return string.find(normalizedName, "crate")
		or string.find(normalizedName, "chest")
		or string.find(normalizedName, "meteor")
		or string.find(normalizedName, "loot")
		or string.find(normalizedName, "supply")
		or string.find(normalizedName, "drop")
		or string.find(normalizedName, "box")
end

function Items.GetShipmentCratesRoot()
	local shipments = workspace:FindFirstChild("Shipments")
	local crates = shipments and shipments:FindFirstChild("Crates")

	return crates
end

function Items.IsShipmentCrateObject(object)
	local cratesRoot = Items.GetShipmentCratesRoot()

	if not cratesRoot or not object or not object:IsDescendantOf(cratesRoot) then
		return false
	end

	local current = object
	while current and current ~= cratesRoot do
		if current.Name == "Crate" and Items.GetCratePart(current) then
			return true
		end

		current = current.Parent
	end

	return false
end

function Items.GetShipmentCrates()
	local cratesRoot = Items.GetShipmentCratesRoot()
	local crates = {}

	if not cratesRoot then
		return crates
	end

	for _, object in ipairs(cratesRoot:GetChildren()) do
		if object.Name == "Crate" then
			table.insert(crates, object)
		end
	end

	return crates
end

function Items.GetTopItemObject(object)
	local root = Items.GetSearchRoot()

	if not root or not object or not object:IsDescendantOf(root) then
		return nil, root
	end

	local current = object
	local topItem = object

	while current and current ~= root do
		topItem = current
		current = current.Parent
	end

	return topItem, root
end

function Items.IsCrateCandidate(object)
	return Items.IsShipmentCrateObject(object)
end

function Items.GetCrateRoot(object)
	local cratesRoot = Items.GetShipmentCratesRoot()

	if cratesRoot and object and object:IsDescendantOf(cratesRoot) then
		local current = object

		while current and current ~= cratesRoot do
			if current.Name == "Crate" and Items.GetCratePart(current) then
				return current
			end

			current = current.Parent
		end
	end

	return nil
end

function Items.RefreshCrates()
	local liveCrates = {}

	for _, crate in ipairs(Items.Crates) do
		if Items.GetCratePart(crate) then
			table.insert(liveCrates, crate)
		else
			Items.KnownCrates[crate] = nil
			Items.CratePartCache[crate] = nil
			Items.CrateFireCache[crate] = nil
			Items.CrateUsedCache[crate] = nil
		end
	end

	Items.Crates = liveCrates

	if Items.CrateButtonLabel then
		if #Items.Crates > 0 then
			Items.CrateButtonLabel.Text = "Meteor Crate (" .. tostring(#Items.Crates) .. ")"
		else
			Items.CrateButtonLabel.Text = "Meteor Crate (none spawned)"
		end
	end
end

function Items.TrackCrate(crate, notify)
	local crateRoot = Items.GetCrateRoot(crate)

	if not crateRoot then
		return
	end

	local current = crateRoot.Parent
	while current and current ~= workspace do
		if Items.KnownCrates[current] then
			return
		end

		current = current.Parent
	end

	for knownCrate in pairs(Items.KnownCrates) do
		if knownCrate.Parent and knownCrate:IsDescendantOf(crateRoot) then
			Items.KnownCrates[knownCrate] = nil
		end
	end

	if Items.KnownCrates[crateRoot] then
		return
	end

	Items.KnownCrates[crateRoot] = true
	Items.CratePartCache[crateRoot] = Items.GetCratePart(crateRoot)
	Items.CrateFireCache[crateRoot] = nil
	Items.CrateUsedCache[crateRoot] = nil
	table.insert(Items.Crates, crateRoot)

	if not Items.CrateWatcherBooting then
		Items.RefreshCrates()
	end

	if notify then
		local now = os.clock()

		if now - (Items.LastCrateNotificationAt or 0) >= Items.CrateNotificationCooldown then
			Items.LastCrateNotificationAt = now
			createNotification("Meteor Crate", "Crate detected.", "Info")
		end

		if Items.FastCollectCratesEnabled and not Items.CollectCratesBusy then
			task.defer(function()
				if Items.TryStartAutoCollectCrates then
					Items.TryStartAutoCollectCrates()
				end
			end)
		end
	end

	table.insert(Items.CrateWatcherConnections, crateRoot.AncestryChanged:Connect(function()
		if not crateRoot.Parent then
			Items.KnownCrates[crateRoot] = nil
			Items.CratePartCache[crateRoot] = nil
			Items.CrateFireCache[crateRoot] = nil
			Items.CrateUsedCache[crateRoot] = nil
		end

		Items.RefreshCrates()
	end))
end

function Items.ClearFastCollectCratesBox()
	if Items.FastCollectCratesBox then
		pcall(function()
			Items.FastCollectCratesBox:Destroy()
		end)

		Items.FastCollectCratesBox = nil
	end

	table.clear(Items.FastCollectCratesNearbyCache)
	table.clear(Items.CratePartCache)
	table.clear(Items.CrateFireCache)
	table.clear(Items.CrateUsedCache)
	Items.FastCollectCratesLastNearbyScan = 0
end

function Items.UpdateFastCollectCratesBox(root)
	if not Items.FastCollectCratesEnabled or not root or not root.Parent then
		Items.ClearFastCollectCratesBox()
		return nil
	end

	local box = Items.FastCollectCratesBox

	if not box or not box.Parent then
		box = Instance.new("Part")
		box.Name = "Part"
		box.Size = Items.FastCollectCratesBoxSize
		box.Anchored = true
		box.CanCollide = false
		box.CanTouch = false
		box.CanQuery = false
		box.Transparency = 1
		box.Color = Color3.fromRGB(255, 64, 64)
		box.Material = Enum.Material.Neon
		box.Parent = workspace
		Items.FastCollectCratesBox = box
	end

	box.Size = Items.FastCollectCratesBoxSize
	box.CFrame = root.CFrame

	return box
end

function Items.IsCratePartInFastCollectBox(cratePart, root)
	if not cratePart or not cratePart.Parent or not root or not root.Parent then
		return false
	end

	local relativePosition = root.CFrame:PointToObjectSpace(cratePart.Position)
	local halfSize = Items.FastCollectCratesBoxSize / 2

	return math.abs(relativePosition.X) <= halfSize.X
		and math.abs(relativePosition.Y) <= halfSize.Y
		and math.abs(relativePosition.Z) <= halfSize.Z
end

function Items.GetFastCollectOverlapParams()
	if Items.FastCollectCratesOverlapParams then
		return Items.FastCollectCratesOverlapParams
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = false
	Items.FastCollectCratesOverlapParams = params

	return params
end

function Items.GetNearbyCrateParts(root)
	local parts = {}
	local seen = {}

	if not root or not root.Parent then
		return parts
	end

	local now = os.clock()
	if now - (Items.FastCollectCratesLastNearbyScan or 0) < Items.FastCollectCratesNearbyScanInterval then
		return Items.FastCollectCratesNearbyCache or parts
	end

	Items.FastCollectCratesLastNearbyScan = now

	for _, crateRoot in ipairs(Items.GetShipmentCrates()) do
		local cratePart = Items.GetCratePart(crateRoot)

		if cratePart and not seen[crateRoot] and Items.IsCratePartInFastCollectBox(cratePart, root) then
			seen[crateRoot] = true
			table.insert(parts, cratePart)
			Items.TrackCrate(crateRoot, false)
		end
	end

	Items.FastCollectCratesNearbyCache = parts
	return parts
end

function Items.GetTrackedCrateParts(root)
	local parts = {}
	local seen = {}

	if os.clock() - (Items.FastCollectCratesLastScan or 0) >= Items.FastCollectCratesScanInterval then
		Items.FastCollectCratesLastScan = os.clock()
		Items.ScanCratesNow()
	else
		Items.RefreshCrates()
	end

	for _, crate in ipairs(Items.Crates) do
		local part = Items.GetCratePart(crate)

		if part and (not root or Items.IsCratePartInFastCollectBox(part, root)) then
			seen[crate] = true
			table.insert(parts, part)
		end
	end

	if root then
		for _, part in ipairs(Items.GetNearbyCrateParts(root)) do
			local crateRoot = Items.GetCrateRoot(part) or part

			if not seen[crateRoot] then
				seen[crateRoot] = true
				table.insert(parts, part)
			end
		end
	end

	return parts
end

function Items.StartFastCollectCrates()
	if Items.FastCollectCratesThread then
		return
	end

	Items.FastCollectCratesThread = task.spawn(function()
		while Items.FastCollectCratesEnabled do
			-- Global scan: crate slaps are attempted regardless of the player's position.
			Items.UpdateFastCollectCratesBox(nil)

			if not Items.CollectCratesBusy then
				for _, cratePart in ipairs(Items.GetTrackedCrateParts(nil)) do
					if not Items.FastCollectCratesEnabled then
						break
					end

					Items.SlapCrate(cratePart)
				end
			end

			task.wait(Items.FastCollectCratesInterval)
		end

		Items.FastCollectCratesThread = nil
	end)
end

function Items.SetFastCollectCrates(state, silent)
	Items.FastCollectCratesEnabled = state == true

	if Items.FastCollectCratesEnabled then
		Items.StartCrateWatcher()
		Items.StartFastCollectCrates()
		task.defer(function()
			if Items.TryStartAutoCollectCrates then
				Items.TryStartAutoCollectCrates()
			end
		end)

		if not silent then
			createNotification("Auto collect crates", "Auto collect crates enabled.", "Success")
		end
	else
		Items.ClearFastCollectCratesBox()

		if not silent then
			createNotification("Auto collect crates", "Auto collect crates disabled.")
		end
	end
end

function Items.StartCrateAura()
	if Items.CrateAuraThread then
		return
	end

	Items.CrateAuraThread = task.spawn(function()
		while Items.CrateAuraEnabled do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")

			if root then
				for _, cratePart in ipairs(Items.GetTrackedCrateParts(root)) do
					if not Items.CrateAuraEnabled then
						break
					end

					Items.SlapCrate(cratePart)
				end
			end

			task.wait(Items.CrateAuraInterval)
		end

		Items.CrateAuraThread = nil
	end)
end

function Items.SetCrateAura(state, silent)
	Items.CrateAuraEnabled = state == true

	if Items.CrateAuraEnabled then
		Items.StartCrateWatcher()
		Items.StartCrateAura()

		if not silent then
			createNotification("Crate Aura", "Crate Aura enabled.", "Success")
		end
	else
		if not silent then
			createNotification("Crate Aura", "Crate Aura disabled.")
		end
	end
end

function Items.FindNearestCrate()
	Items.ScanCratesNow()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local nearestCrate = nil
	local nearestPart = nil
	local nearestDistance = math.huge

	for _, crate in ipairs(Items.Crates) do
		local part = Items.GetCratePart(crate)

		if part then
			local distance = root and (root.Position - part.Position).Magnitude or 0

			if distance < nearestDistance then
				nearestDistance = distance
				nearestCrate = crate
				nearestPart = part
			end
		end
	end

	return nearestCrate, nearestPart
end

function Items.TeleportToCrate()
	if not Teleport.CanTeleport(Items.TeleportDebounce) then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart")

	if not root then
		return
	end

	local crate, part = Items.FindNearestCrate()
	if not crate or not part then
		return
	end

	local targetPosition = part.Position + Vector3.new(0, (part.Size.Y / 2) + 4, 0)

	Teleport.MoveRoot(root, CFrame.new(targetPosition))
	Teleport.AddStrike()
	Teleport.StartFBlock()
end

function Items.ClearCrateCollectPart()
	if Items.CrateCollectPart then
		pcall(function()
			Items.CrateCollectPart:Destroy()
		end)

		Items.CrateCollectPart = nil
	end
end

function Items.GetCrateUnderMapCFrame(crate, cratePart)
	local centerPosition = cratePart.Position
	local bottomY = cratePart.Position.Y - (cratePart.Size.Y / 2)

	if crate and crate:IsA("Model") then
		local ok, modelCFrame, modelSize = pcall(function()
			return crate:GetBoundingBox()
		end)

		if ok and modelCFrame and modelSize then
			centerPosition = modelCFrame.Position
			bottomY = modelCFrame.Position.Y - (modelSize.Y / 2)
		end
	elseif crate and crate:IsA("BasePart") then
		centerPosition = crate.Position
		bottomY = crate.Position.Y - (crate.Size.Y / 2)
	end

	local targetPosition = Vector3.new(centerPosition.X, bottomY - 4, centerPosition.Z)

	return CFrame.new(targetPosition, cratePart.Position)
end

function Items.EnsureCrateCollectPart(targetCFrame)
	Items.ClearCrateCollectPart()

	local part = Instance.new("Part")
	local platformHeight = 6

	part.Name = "Part"
	part.Size = Vector3.new(64, platformHeight, 64)
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.CFrame = CFrame.new(targetCFrame.Position - Vector3.new(0, (platformHeight * 0.5) + 3, 0))
	part.Parent = workspace
	Items.CrateCollectPart = part

	return part
end

function Items.MoveUnderMapAfterCrates()
	Items.ClearCrateCollectPart()

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return false
	end

	local platform = ensureUnderMapSafetyPlatform()

	platform.CanCollide = true
	platform.CanTouch = false
	platform.CanQuery = false
	platform.Transparency = 1
	Anti.HideUnderMapEnabled = true

	if UI.ToggleRefs.HideUnderMap then
		UI.ToggleRefs.HideUnderMap.Set(true, false)
	end

	local targetCFrame = CFrame.new(root.Position.X, platform.Position.Y + (platform.Size.Y * 0.5) + UNDER_MAP_SAFE_OFFSET, root.Position.Z)

	Teleport.MoveRoot(root, targetCFrame)
	task.wait(0.08)

	if root and root.Parent then
		Teleport.MoveRoot(root, targetCFrame)
	end

	return true
end

function Items.GetCrateCollectTargets()
	Items.ScanCratesNow()

	local targets = {}
	local seen = {}

	for _, crate in ipairs(Items.GetShipmentCrates()) do
		if crate and crate.Parent and not seen[crate] then
			seen[crate] = true
			table.insert(targets, crate)
		end
	end

	for _, crate in ipairs(Items.Crates) do
		if crate and crate.Parent and not seen[crate] and Items.GetCratePart(crate) then
			seen[crate] = true
			table.insert(targets, crate)
		end
	end

	return targets
end

function Items.CountShipmentCrates()
	local count = 0

	for _, crate in ipairs(Items.GetShipmentCrates()) do
		if crate and crate.Parent and crate:IsDescendantOf(workspace) then
			count += 1
		end
	end

	return count
end

function Items.IsCrateUsedUp(crate)
	if not crate or not crate.Parent or not crate:IsDescendantOf(workspace) then
		return true
	end

	local now = os.clock()
	local cached = Items.CrateUsedCache[crate]

	if cached and now - cached.At < Items.CrateUsedCacheInterval then
		return cached.Value
	end

	local usedUp = false

	local durability = crate:GetAttribute("Durability")
		or crate:GetAttribute("Health")
		or crate:GetAttribute("HP")
		or crate:GetAttribute("Uses")

	if type(durability) == "number" and durability <= 0 then
		usedUp = true
	end

	local part = Items.GetCratePart(crate)

	if not part or not part.Parent or not part:IsDescendantOf(workspace) then
		return true
	end

	if part:GetAttribute("Durability") == 0
		or part:GetAttribute("Health") == 0
		or part:GetAttribute("HP") == 0
		or part:GetAttribute("Uses") == 0
	then
		usedUp = true
	end

	if not usedUp and crate:IsA("BasePart") then
		usedUp = crate.Size.X <= 0 or crate.Size.Y <= 0 or crate.Size.Z <= 0
	end

	if not usedUp then
		local foundUsablePart = false

		for _, object in ipairs(crate:GetDescendants()) do
			if object:IsA("BasePart") then
				if object.Parent
					and object:IsDescendantOf(workspace)
					and object.Size.X > 0
					and object.Size.Y > 0
					and object.Size.Z > 0
				then
					foundUsablePart = true
					break
				end
			end
		end

		usedUp = not foundUsablePart
	end

	Items.CrateUsedCache[crate] = {
		At = now,
		Value = usedUp
	}

	return usedUp
end

function Items.GetReadyCrateTarget()
	local liveCount = 0

	for _, crate in ipairs(Items.GetCrateCollectTargets()) do
		if crate and not Items.IsCrateUsedUp(crate) then
			liveCount += 1

			if not Items.CrateHasActiveFire(crate) then
				return crate, liveCount
			end
		end
	end

	return nil, liveCount
end

function Items.GetFirstLiveCrateTarget()
	for _, crate in ipairs(Items.GetCrateCollectTargets()) do
		if crate and crate.Parent and Items.GetCratePart(crate) then
			return crate
		end
	end

	return nil
end

function Items.TeleportUnderCrate(crate)
	if not crate or not crate.Parent then
		return false
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = Items.GetCratePart(crate)

	if not root or not part then
		return false
	end

	local targetCFrame = Items.GetCrateUnderMapCFrame(crate, part)
	local platform = Items.EnsureCrateCollectPart(targetCFrame)

	if not platform or not platform.Parent then
		return false
	end

	Teleport.MoveRoot(root, targetCFrame, part.Position)

	return true
end

function Items.CollectSingleCrate(crate, alreadyTeleported)
	if not crate or not crate.Parent then
		return false
	end

	if Items.CrateHasActiveFire(crate) then
		return false
	end

	if not alreadyTeleported and not Items.TeleportUnderCrate(crate) then
		return false
	end

	local startedAt = os.clock()

	while not Items.IsCrateUsedUp(crate) and Items.CollectCratesBusy do
		if os.clock() - startedAt > 8 then
			break
		end

		if setMovementPaused then
			setMovementPaused(true)
		end

		local part = Items.GetCratePart(crate)

		if not part then
			break
		end

		if not Items.CrateHasActiveFire(crate) then
			Items.SlapCrate(part)
		end

		task.wait(Items.CollectCratesSlapInterval)
	end

	return true
end

function Items.CollectCrates()
	if Items.CollectCratesBusy then
		createNotification("Collect Crates", "Already collecting crates.", "Info")
		return
	end

	Items.CollectCratesBusy = true
	Items.StartCrateWatcher()

	if setMovementPaused then
		setMovementPaused(true)
	end

	task.spawn(function()
		local targets = Items.GetCrateCollectTargets()

		if #targets == 0 then
			createNotification("Collect Crates", "No crates found.", "Warning")
			Items.CollectCratesBusy = false
			if setMovementPaused then
				setMovementPaused(false)
			end
			Items.ClearCrateCollectPart()
			return
		end

		local crateCount = math.max(#targets, Items.CountShipmentCrates())
		local currentCrate = nil
		createNotification("Collect Crates", "Collecting " .. tostring(crateCount) .. " crate(s).", "Info")

		local function moveToCrate(crate)
			if not crate or not crate.Parent or not Items.GetCratePart(crate) then
				return false
			end

			if Items.TeleportUnderCrate(crate) then
				currentCrate = crate
				return true
			end

			return false
		end

		local firstReady = Items.GetReadyCrateTarget()
		moveToCrate(firstReady or Items.GetFirstLiveCrateTarget())

		while Items.CollectCratesBusy do
			if setMovementPaused then
				setMovementPaused(true)
			end

			if currentCrate and Items.IsCrateUsedUp(currentCrate) then
				currentCrate = nil
			end

			if not currentCrate then
				local readyCrate, liveCount = Items.GetReadyCrateTarget()

				if liveCount <= 0 then
					break
				end

				moveToCrate(readyCrate or Items.GetFirstLiveCrateTarget())
			elseif not Items.CrateHasActiveFire(currentCrate) then
				Items.CollectSingleCrate(currentCrate, true)
				currentCrate = nil
			else
				local readyCrate = Items.GetReadyCrateTarget()

				if readyCrate and readyCrate ~= currentCrate then
					moveToCrate(readyCrate)
				else
					task.wait(0.1)
				end
			end
		end

		Items.RefreshCrates()
		Items.CollectCratesBusy = false
		if setMovementPaused then
			setMovementPaused(false)
		end
		Items.MoveUnderMapAfterCrates()
		createNotification("Collect Crates", "Finished collecting crates.", "Success")
	end)
end

function Items.HasLiveCrateTargets()
	for _, crate in ipairs(Items.GetCrateCollectTargets()) do
		if crate and not Items.IsCrateUsedUp(crate) then
			return true
		end
	end

	return false
end

function Items.TryStartAutoCollectCrates()
	if not Items.FastCollectCratesEnabled or Items.CollectCratesBusy then
		return false
	end

	local now = os.clock()

	if now - (Items.AutoCollectCratesLastStart or 0) < Items.AutoCollectCratesStartCooldown then
		return false
	end

	if not Items.HasLiveCrateTargets() then
		return false
	end

	Items.AutoCollectCratesLastStart = now
	task.delay(0.2, function()
		if Items.FastCollectCratesEnabled and not Items.CollectCratesBusy then
			Items.CollectCrates()
		end
	end)

	return true
end

function Items.IsActiveCrateFireObject(object)
	if not object then
		return false
	end

	local objectName = Utility.NormalizeName(object.Name)

	if object:IsA("Fire") and object.Enabled ~= false then
		return true
	end

	if object:IsA("ParticleEmitter") and object.Enabled ~= false then
		return string.find(objectName, "fire")
			or string.find(objectName, "flame")
			or string.find(objectName, "burn")
			or string.find(objectName, "smoke")
			or string.find(objectName, "ember")
	end

	if object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
		return object.Enabled ~= false and (
			string.find(objectName, "fire")
			or string.find(objectName, "flame")
			or string.find(objectName, "burn")
		)
	end

	return false
end

function Items.CrateHasActiveFire(crate)
	if not crate or not crate.Parent then
		return false
	end

	local now = os.clock()
	local cached = Items.CrateFireCache[crate]

	if cached and now - cached.At < Items.CrateFireCacheInterval then
		return cached.Value
	end

	local hasFire = false

	if Items.IsActiveCrateFireObject(crate) then
		hasFire = true
	end

	if not hasFire then
		for _, object in ipairs(crate:GetDescendants()) do
			if Items.IsActiveCrateFireObject(object) then
				hasFire = true
				break
			end
		end
	end

	Items.CrateFireCache[crate] = {
		At = now,
		Value = hasFire
	}

	return hasFire
end

function Items.CanSlapCrate(cratePart)
	if not cratePart or not cratePart.Parent then
		return false
	end

	local crateRoot = Items.GetCrateRoot(cratePart) or cratePart

	if Items.CrateHasActiveFire(crateRoot) or Items.CrateHasActiveFire(cratePart) then
		return false
	end

	return true
end

function Items.SlapCrate(cratePart)
	local remote = Combat and Combat.GetSlapRemote and Combat.GetSlapRemote()

	if not remote or not cratePart or not cratePart.Parent then
		return false
	end

	if not Items.CanSlapCrate(cratePart) then
		return false
	end

	pcall(function()
		remote:FireServer(cratePart)
	end)

	local tool = Combat.GetEquippedTool and Combat.GetEquippedTool()
	if tool then
		pcall(function()
			tool:Activate()
		end)
	end

	return true
end

function Items.ScanCratesNow()
	local shipmentCratesRoot = Items.GetShipmentCratesRoot()

	if not shipmentCratesRoot then
		return
	end

	for _, object in ipairs(shipmentCratesRoot:GetChildren()) do
		if object.Name == "Crate" then
			Items.TrackCrate(object, false)
		end
	end

	Items.RefreshCrates()
end

function Items.ClearCrateWatcher()
	for _, connection in ipairs(Items.CrateWatcherConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(Items.CrateWatcherConnections)
	table.clear(Items.Crates)
	table.clear(Items.KnownCrates)
	table.clear(Items.CratePartCache)
	table.clear(Items.CrateFireCache)
	table.clear(Items.CrateUsedCache)
	Items.CrateWatcherStarted = false
	Items.CrateWatcherRoot = nil
	Items.CrateWatcherStarting = false
end

function Items.StartCrateWatcher()
	if Items.CrateWatcherStarted or Items.CrateWatcherStarting then
		return
	end

	Items.CrateWatcherStarting = true
	local root = Items.GetShipmentCratesRoot()

	if not root then
		task.spawn(function()
			for _ = 1, 300 do
				task.wait(1)

				root = Items.GetShipmentCratesRoot()
				if root then
					Items.CrateWatcherStarting = false
					Items.StartCrateWatcher()
					return
				end
			end

			Items.CrateWatcherStarting = false
			print("[OP Slap Royale] Crate watcher could not find Shipments.Crates.")
		end)

		return
	end

	if Items.CrateWatcherRoot == root then
		Items.CrateWatcherStarting = false
		return
	end

	Items.CrateWatcherRoot = root
	Items.CrateWatcherStarted = true
	Items.CrateWatcherStarting = false

	local function trackShipmentCrate(object, notify)
		if not object or object.Name ~= "Crate" then
			return
		end

		task.defer(function()
			Items.TrackCrate(object, notify)
		end)

		task.delay(0.25, function()
			Items.TrackCrate(object, notify)
		end)

		task.delay(1, function()
			Items.TrackCrate(object, false)
		end)
	end

	table.insert(Items.CrateWatcherConnections, root.ChildAdded:Connect(function(object)
		trackShipmentCrate(object, true)
	end))

	table.insert(Items.CrateWatcherConnections, root.ChildRemoved:Connect(function(object)
		Items.KnownCrates[object] = nil
		Items.CratePartCache[object] = nil
		Items.CrateFireCache[object] = nil
		Items.CrateUsedCache[object] = nil
		Items.RefreshCrates()
	end))

	task.spawn(function()
		Items.CrateWatcherBooting = true

		Items.ScanCratesNow()

		Items.CrateWatcherBooting = false
		Items.RefreshCrates()
	end)
end

task.defer(Items.StartCrateWatcher)

ContextActionService:BindActionAtPriority(
	"BlockFAfterTeleport",
	function(_, inputState)
		if inputState == Enum.UserInputState.Begin and os.clock() < Teleport.BlockFUntil then
			Teleport.ShowFBlockedWarning()
			return Enum.ContextActionResult.Sink
		end

		return Enum.ContextActionResult.Pass
	end,
	false,
	3000,
	Enum.KeyCode.F
)


local normalizeName = Utility.NormalizeName

function Main.GetCodeGoBarn()
	Teleport.ToLocation("Bunker", Main.CodeSearchOrigin, true)
	Notify.Show("Code", "Searching...", "Info", nil, 2.2, true)

	task.spawn(function()
		task.wait(0.45)

		local code = Main.GetPuzzleCode()
		Notify.Show("Code Found", code ~= "" and code or "No code found.", code ~= "" and "Success" or "Info", nil, 4, true)

		if code ~= "" then
			task.wait(0.2)

			if Main.EnterBarnKeypadCode(code) then
				Notify.Show("Barn Keypad", "Entered and submitted " .. code .. ".", "Success", nil, 3.5, true)
				Teleport.ToLocation("Barn", nil, true)
			else
				Notify.Show("Barn Keypad", "Found code, but could not press every keypad button.", "Warning", nil, 4, true)
			end
		end
	end)
end

local itemNames = {
	"Apple",
	"Bandage",
	"Boba",
	"Bomb",
	"Bull's Essence",
	"Cube of Ice",
	"First Aid Kit",
	"Forcefield Crystal",
	"Frog Potion",
	"Gravitation Shard",
	"Healing Potion",
	"Lightning Potion",
	"Potion of Strength",
	"Speed Potion",
	"Sphere of Fury",
	"Tomahawk",
	"True Power",
	"Bombs"
}

local autoCollectPriority = {
	"True Power",
	"Potion of Strength",
	"Bull's Essence",
	"Boba",
	"Speed Potion",
	"Frog Potion",
	"Sphere of Fury",
	"Tomahawk",
	"Gravitation Shard",
	"Healing Potion",
	"First Aid Kit",
	"Cube of Ice",
	"Bomb",
	"Bombs",
	"Bandage",
	"Apple",
	"Forcefield Crystal",
	"Lightning Potion"
}

local function matchesItem(toolName, itemList)
	if not toolName or not itemList then
		return false
	end

	local normalized = normalizeName(toolName)

	for _, itemName in ipairs(itemList) do
		if normalized == normalizeName(itemName) then
			return true
		end
	end

	return false
end

local function getItemDisplayName(object)
	return object.Name
end

function getStrictItemMatchObject(object, wantedName)
	local current = object

	while current and current ~= workspace do
		if strictItemNameMatches(current.Name, wantedName) then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function itemNameMatches(object, wantedName)
	return getStrictItemMatchObject(object, wantedName) ~= nil
end

local movementSave = nil
local visitedCollectPositions = {}
local ignoredCollectTargets = {}
local ignoredCollectPositions = {}
local AUTO_COLLECT_POSITION_RADIUS = 7

local function isItemMarkedGone(object)
	if not object then
		return true
	end

	local now = os.clock()

	if ignoredCollectTargets[object] and ignoredCollectTargets[object] > now then
		return true
	end

	local current = object

	while current and current ~= workspace do
		if ignoredCollectTargets[current] and ignoredCollectTargets[current] > now then
			return true
		end

		current = current.Parent
	end

	return object:GetAttribute("Collected") == true
		or object:GetAttribute("PickedUp") == true
		or object:GetAttribute("Available") == false
		or object:GetAttribute("Enabled") == false
end

local function getLiveItemPart(object)
	if not object or not object.Parent or not object:IsDescendantOf(workspace) or isItemMarkedGone(object) then
		return nil
	end

	local part = object:IsA("BasePart") and object or object:FindFirstChildWhichIsA("BasePart", true)

	if not part or not part.Parent or not part:IsDescendantOf(workspace) then
		return nil
	end

	if part.Transparency >= 0.95 or part.Size.X <= 0 or part.Size.Y <= 0 or part.Size.Z <= 0 then
		return nil
	end

	local characterModel = part:FindFirstAncestorOfClass("Model")
	if characterModel and Players:GetPlayerFromCharacter(characterModel) then
		return nil
	end

	return part
end

local function setMovementPaused(paused)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	if paused then
		if not movementSave then
			movementSave = {
				WalkSpeed = humanoid.WalkSpeed,
				JumpPower = humanoid.JumpPower,
				JumpHeight = humanoid.JumpHeight,
				AutoRotate = humanoid.AutoRotate
			}
		end

		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	elseif movementSave then
		humanoid.WalkSpeed = movementSave.WalkSpeed
		humanoid.JumpPower = movementSave.JumpPower
		humanoid.JumpHeight = movementSave.JumpHeight
		humanoid.AutoRotate = movementSave.AutoRotate
		movementSave = nil
	end
end

local function isVisitedCollectPosition(position)
	local now = os.clock()

	for index = #ignoredCollectPositions, 1, -1 do
		local entry = ignoredCollectPositions[index]

		if not entry or entry.Until <= now then
			table.remove(ignoredCollectPositions, index)
		elseif (entry.Position - position).Magnitude <= AUTO_COLLECT_POSITION_RADIUS * 1.75 then
			return true
		end
	end

	for _, visitedPosition in ipairs(visitedCollectPositions) do
		if (visitedPosition - position).Magnitude <= AUTO_COLLECT_POSITION_RADIUS then
			return true
		end
	end

	return false
end

local function markVisitedCollectPosition(position)
	table.insert(visitedCollectPositions, position)
end

local collectibleSearchPoolCache = {}
local collectibleSearchPoolCacheAt = 0
local COLLECTIBLE_POOL_CACHE_TIME = 0.05

local function invalidateCollectibleSearchPool()
	collectibleSearchPoolCache = {}
	collectibleSearchPoolCacheAt = 0
	Items.SearchCacheDirty = true
end

local function ignoreCollectedTarget(itemObject, itemPart, itemPosition)
	local ignoreUntil = os.clock() + 8

	if itemObject then
		ignoredCollectTargets[itemObject] = ignoreUntil
	end

	if itemPart then
		ignoredCollectTargets[itemPart] = ignoreUntil
	end

	if itemPosition then
		table.insert(ignoredCollectPositions, {
			Position = itemPosition,
			Until = ignoreUntil
		})
		markVisitedCollectPosition(itemPosition)
	elseif itemPart then
		table.insert(ignoredCollectPositions, {
			Position = itemPart.Position,
			Until = ignoreUntil
		})
		markVisitedCollectPosition(itemPart.Position)
	end

	invalidateCollectibleSearchPool()
end

local function getCollectibleSearchPool()
	local now = os.clock()

	if now - collectibleSearchPoolCacheAt <= COLLECTIBLE_POOL_CACHE_TIME then
		return collectibleSearchPoolCache
	end

	collectibleSearchPoolCache = Items.GetSearchDescendants()
	collectibleSearchPoolCacheAt = now
	return collectibleSearchPoolCache
end

local primaryCollectOrder

function getFullCollectibleSearchPool()
	return Items.GetSearchChildren()
end

local function getImmediateCollectibleSearchPool()
	return Items.GetSearchChildren()
end

primaryCollectOrder = autoCollectPriority

Items.PermanentCollectStopOrder = {
	"True Power",
	"Potion of Strength",
	"Bull's Essence",
	"Boba",
	"Speed Potion",
	"Frog Potion"
}

local secondaryCollectOrder = {
	"Sphere of Fury",
	"Tomahawk",
	"Gravitation Shard",
	"Healing Potion",
	"First Aid Kit",
	"Cube of Ice",
	"Bomb",
	"Bombs",
	"Bandage",
	"Apple",
	"Forcefield Crystal",
	"Lightning Potion"
}

local pinnedItemOrder = primaryCollectOrder

local PINNED_COLLECTION_SWITCH_PERCENT = 1
local searchAllItemsUnlocked = false
local pinnedItemsEverSeen = false

local function setItemSearchTargets(itemList)
	Items.SearchNameLookup = {}

	for _, itemName in ipairs(itemList) do
		Items.SearchNameLookup[normalizeName(itemName)] = true

		local aliases = itemNameAliases[itemName]
		if aliases then
			for _, alias in ipairs(aliases) do
				Items.SearchNameLookup[normalizeName(alias)] = true
			end
		end
	end

	Items.SearchCache = {}
	Items.LastSearchCacheAt = 0
	Items.SearchCacheDirty = true
	Items.RebuildSearchCache()
end

local function getPinnedCollectionProgress()
	local totalPinned = 0
	local leftPinned = 0

	for _, itemName in ipairs(pinnedItemOrder) do
		local leftCount = 0
		local totalCount = 0

		for _, object in ipairs(getCollectibleSearchPool()) do
			if itemNameMatches(object, itemName) then
				totalCount += 1

				if getLiveItemPart(object) then
					leftCount += 1
				end
			end
		end

		if totalCount > 0 then
			pinnedItemsEverSeen = true
		end

		totalPinned += totalCount
		leftPinned += leftCount
	end

	if totalPinned <= 0 then
		if Items.SearchCacheBusy and Items.LastSearchCacheAt == 0 then
			return 0
		end

		return 1
	end

	return (totalPinned - leftPinned) / totalPinned
end

local function updateItemSearchMode()
	if searchAllItemsUnlocked then
		return
	end

	if getPinnedCollectionProgress() >= PINNED_COLLECTION_SWITCH_PERCENT then
		searchAllItemsUnlocked = true
		setItemSearchTargets(itemNames)
		createNotification("Items", "Most priority items collected. Searching all items now.", "Success")
	end
end

setItemSearchTargets(itemNames)

local function findLiveItemByName(wantedName, allowVisited)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return nil, nil, nil, nil, nil
	end

	local closestObject = nil
	local closestPart = nil
	local closestDistance = math.huge

	for _, object in ipairs(getCollectibleSearchPool()) do
		if itemNameMatches(object, wantedName) then
			local part = getLiveItemPart(object)

			if part and (allowVisited or not isVisitedCollectPosition(part.Position)) then
				local distance = (root.Position - part.Position).Magnitude

				if distance < closestDistance then
					closestDistance = distance
					closestObject = object
					closestPart = part
				end
			end
		end
	end

	if closestObject and closestPart then
		return wantedName, closestPart.CFrame, closestPart.Position, closestObject, closestPart
	end

	return nil, nil, nil, nil, nil
end

function Items.GetPermanentCollectStatus()
	local remaining = 0
	local total = 0

	for _, wantedName in ipairs(Items.PermanentCollectStopOrder) do
		for _, object in ipairs(getFullCollectibleSearchPool()) do
			if itemNameMatches(object, wantedName) then
				total += 1

				if getLiveItemPart(object) then
					remaining += 1
				end
			end
		end
	end

	return remaining, total
end

function Items.ShouldFinishEarlyAutoCollectPermanents()
	local remaining, total = Items.GetPermanentCollectStatus()

	if total > 0 then
		Items.EarlyAutoCollectPermanentSeen = true
	end

	if remaining > 0 or not Items.EarlyAutoCollectPermanentSeen then
		Items.EarlyAutoCollectConfirmingPermanents = false
		Items.EarlyAutoCollectConfirmCount = 0
		return false
	end

	if not Items.EarlyAutoCollectConfirmingPermanents then
		Items.EarlyAutoCollectConfirmingPermanents = true
		Items.EarlyAutoCollectConfirmCount = 1
		Items.EarlyAutoCollectConfirmAt = os.clock() + 0.35
		Items.RebuildSearchCache()
		return false
	end

	if Items.SearchCacheBusy or os.clock() < (Items.EarlyAutoCollectConfirmAt or 0) then
		return false
	end

	local checkRemaining, checkTotal = Items.GetPermanentCollectStatus()

	if checkTotal > 0 then
		Items.EarlyAutoCollectPermanentSeen = true
	end

	if checkRemaining > 0 then
		Items.EarlyAutoCollectConfirmingPermanents = false
		Items.EarlyAutoCollectConfirmCount = 0
		return false
	end

	Items.EarlyAutoCollectConfirmCount = (Items.EarlyAutoCollectConfirmCount or 1) + 1

	if Items.EarlyAutoCollectConfirmCount < 3 then
		Items.EarlyAutoCollectConfirmAt = os.clock() + 0.35
		Items.RebuildSearchCache()
		return false
	end

	return true
end

local function findNextCollectTarget()
	local collectOrder = primaryCollectOrder

	for _, wantedName in ipairs(collectOrder) do
		local itemName, _, _, itemObject, itemPart = findLiveItemByName(wantedName)

		if itemName and itemObject and itemPart then
			return itemName, itemPart.CFrame, itemPart.Position, itemObject, itemPart
		end
	end

	for _, wantedName in ipairs(collectOrder) do
		local itemName, _, _, itemObject, itemPart = findLiveItemByName(wantedName, true)

		if itemName and itemObject and itemPart then
			return itemName, itemPart.CFrame, itemPart.Position, itemObject, itemPart
		end
	end

	return nil, nil, nil, nil, nil
end

local function findImmediatePriorityCollectTarget()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return nil, nil, nil, nil, nil
	end

	for _, wantedName in ipairs(primaryCollectOrder) do
		local manualObject, manualPart = Items.FindManualItem(wantedName)

		if manualObject and manualPart and getLiveItemPart(manualObject) == manualPart then
			return wantedName, manualPart.CFrame, manualPart.Position, manualObject, manualPart
		end
	end

	for _, wantedName in ipairs(primaryCollectOrder) do
		local closestObject = nil
		local closestPart = nil
		local closestDistance = math.huge

		for _, object in ipairs(getImmediateCollectibleSearchPool()) do
			if itemNameMatches(object, wantedName) then
				local part = getLiveItemPart(object)

				if part then
					local distance = (root.Position - part.Position).Magnitude

					if distance < closestDistance then
						closestDistance = distance
						closestObject = object
						closestPart = part
					end
				end
			end
		end

		if closestObject and closestPart then
			return wantedName, closestPart.CFrame, closestPart.Position, closestObject, closestPart
		end
	end

	return nil, nil, nil, nil, nil
end

local function isItemScanLoading()
	return Items.SearchCacheBusy or Items.LastSearchCacheAt == 0
end

local function isSameItemStillThere(itemObject, itemPart, wantedName)
	if not itemObject or not itemPart or not itemObject.Parent or not itemPart.Parent then
		return false
	end

	if not itemNameMatches(itemObject, wantedName) then
		return false
	end

	if itemObject:GetAttribute("Collected") == true
		or itemObject:GetAttribute("PickedUp") == true
		or itemObject:GetAttribute("Available") == false
		or itemObject:GetAttribute("Enabled") == false then
		return false
	end

	if not itemPart:IsDescendantOf(workspace)
		or itemPart.Transparency >= 0.95
		or itemPart.Size.X <= 0
		or itemPart.Size.Y <= 0
		or itemPart.Size.Z <= 0 then
		return false
	end

	local characterModel = itemPart:FindFirstAncestorOfClass("Model")
	if characterModel and Players:GetPlayerFromCharacter(characterModel) then
		return false
	end

	return true
end

local pressF

function pressF(skipPickupLock)
	local VirtualInputManager = game:GetService("VirtualInputManager")
	local pressed = false

	if not skipPickupLock and (Items.EarlyBusFBlockActive == true or Items.BusLandingFBlockActive == true) then
		return false
	end

	pcall(function()
		while not skipPickupLock and os.clock() < (Teleport.BlockFUntil or 0) do
			if Items.EarlyBusFBlockActive == true or Items.BusLandingFBlockActive == true then
				return
			end

			task.wait(0.03)
		end

		if not skipPickupLock and Items.IsPickupInputLocked and Items.IsPickupInputLocked() then
			return
		end

		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
		task.wait(0.05)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
		pressed = true
	end)

	return pressed
end

function Items.TryPickupPrompt(itemObject, itemPart)
	if Items.IsPickupInputLocked and Items.IsPickupInputLocked() then
		return false
	end

	local promptList = {}
	local triggered = false

	local function addPrompts(root)
		if not root then
			return
		end

		if root:IsA("ProximityPrompt") then
			table.insert(promptList, root)
			return
		end

		for _, descendant in ipairs(root:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				table.insert(promptList, descendant)
			end
		end
	end

	addPrompts(itemObject)
	addPrompts(itemPart)

	for _, prompt in ipairs(promptList) do
		if prompt.Enabled and prompt.Parent then
			pcall(function()
				if type(fireproximityprompt) == "function" then
					fireproximityprompt(prompt)
				else
					prompt:InputHoldBegin()
					task.wait(math.max(prompt.HoldDuration, 0.05))
					prompt:InputHoldEnd()
				end

				triggered = true
			end)
		end
	end

	return triggered
end

function Items.GetMobilePickupButtonScore(button)
	if not button
		or not button:IsA("GuiButton")
		or not button.Visible
		or button.AbsoluteSize.X < 12
		or button.AbsoluteSize.Y < 12
		or (gui and button:IsDescendantOf(gui)) then
		return 0
	end

	local text = button.Name or ""

	if button:IsA("TextButton") then
		text = text .. " " .. (button.Text or "")
	end

	for _, child in ipairs(button:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
			text = text .. " " .. (child.Text or "")
		end
	end

	local normalized = normalizeName(text)
	local score = 0

	if normalized:find("pickup", 1, true) or normalized:find("pick up", 1, true) then
		score += 12
	end

	if normalized:find("collect", 1, true)
		or normalized:find("grab", 1, true)
		or normalized:find("take", 1, true)
		or normalized:find("interact", 1, true)
		or normalized:find("loot", 1, true)
		or normalized:find("item", 1, true) then
		score += 8
	end

	if normalized == "f" or normalized == "e" or normalized:find("pressf", 1, true) or normalized:find("presse", 1, true) then
		score += 5
	end

	local viewport = getViewportSize()
	local center = button.AbsolutePosition + (button.AbsoluteSize * 0.5)

	if center.X > viewport.X * 0.45 and center.Y > viewport.Y * 0.35 then
		score += 2
	end

	return score
end

function Items.FindMobilePickupButton()
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local bestButton = nil
	local bestScore = 0

	if not playerGui then
		return nil
	end

	for _, object in ipairs(playerGui:GetDescendants()) do
		local score = Items.GetMobilePickupButtonScore(object)

		if score > bestScore then
			bestButton = object
			bestScore = score
		end
	end

	return bestScore > 0 and bestButton or nil
end

function Items.TapMobilePickupButton()
	local button = Items.FindMobilePickupButton()

	if not button then
		return false
	end

	local tapped = false

	pcall(function()
		if type(firesignal) == "function" then
			firesignal(button.Activated)
			firesignal(button.MouseButton1Click)
			tapped = true
		end
	end)

	pcall(function()
		local VirtualInputManager = game:GetService("VirtualInputManager")
		local center = button.AbsolutePosition + (button.AbsoluteSize * 0.5)

		VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
		task.wait(0.03)
		VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
		tapped = true
	end)

	return tapped
end

function Items.TapMobilePickupIcon(itemObject, itemPart)
	if not itemPart or not itemPart.Parent then
		return false
	end

	local camera = workspace.CurrentCamera

	if not camera then
		return false
	end

	local basePosition = itemPart.Position
	local halfHeight = itemPart:IsA("BasePart") and (itemPart.Size.Y * 0.5) or 1

	if itemObject and itemObject.Parent and itemObject:IsA("Model") then
		local ok, modelCFrame, modelSize = pcall(function()
			return itemObject:GetBoundingBox()
		end)

		if ok and modelCFrame and modelSize then
			basePosition = modelCFrame.Position
			halfHeight = math.max(halfHeight, modelSize.Y * 0.5)
		end
	end

	local tapPositions = {
		itemPart.Position + Vector3.new(0, halfHeight + 2.5, 0),
		itemPart.Position + Vector3.new(0, halfHeight + 1.4, 0),
		basePosition + Vector3.new(0, halfHeight + 2.5, 0),
		basePosition + Vector3.new(0, halfHeight + 1.4, 0),
		itemPart.Position,
	}
	local VirtualInputManager = game:GetService("VirtualInputManager")

	for _, worldPosition in ipairs(tapPositions) do
		local screenPosition, onScreen = camera:WorldToViewportPoint(worldPosition)

		if onScreen and screenPosition.Z > 0 then
			local x = math.floor(screenPosition.X)
			local y = math.floor(screenPosition.Y)
			local tapped = false

			pcall(function()
				VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
				task.wait(0.03)
				VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
				tapped = true
			end)

			pcall(function()
				VirtualInputManager:SendTouchEvent(1, Enum.UserInputState.Begin, x, y)
				task.wait(0.03)
				VirtualInputManager:SendTouchEvent(1, Enum.UserInputState.End, x, y)
				tapped = true
			end)

			if tapped then
				return true
			end
		end
	end

	return false
end

function Items.IsPickupInputLocked()
	return os.clock() < (Teleport.BlockFUntil or 0)
		or Items.EarlyBusFBlockActive == true
		or Items.BusLandingFBlockActive == true
end

function Items.UsePickupInput(itemObject, itemPart, skipPickupLock)
	if not skipPickupLock and Items.IsPickupInputLocked() then
		return false
	end

	return pressF(skipPickupLock) == true
end

function Items.GetAutoPickupRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Items.FindAutoPickupItemFromPart(touchedPart)
	if not touchedPart or not touchedPart.Parent then
		return nil
	end

	for _, object in ipairs(getCollectibleSearchPool()) do
		local itemPart = getLiveItemPart(object)

		if itemPart
			and (touchedPart == itemPart
				or touchedPart:IsDescendantOf(object)
				or itemPart:IsDescendantOf(touchedPart)) then
			for _, itemName in ipairs(itemNames) do
				if itemNameMatches(object, itemName) then
					return object, itemPart, itemName
				end
			end
		end
	end

	return nil
end

function Items.IsPartInsideAutoPickupZone(itemPart, root)
	if not itemPart or not itemPart.Parent or not root then
		return false
	end

	local localPosition = root.CFrame:PointToObjectSpace(itemPart.Position)
	local halfItemSize = itemPart.Size * 0.5
	local halfZoneSize = 15

	return math.abs(localPosition.X) <= halfZoneSize + halfItemSize.X
		and math.abs(localPosition.Y) <= halfZoneSize + halfItemSize.Y
		and math.abs(localPosition.Z) <= halfZoneSize + halfItemSize.Z
end

function Items.TrackAutoPickupItem(itemObject, itemPart, itemName)
	if not itemObject or not itemPart or not itemName then
		return
	end

	Items.AutoPickupTouching[itemObject] = {
		Object = itemObject,
		Part = itemPart,
		Name = itemName,
	}
end

function Items.ScanAutoPickupItems()
	local root = Items.GetAutoPickupRoot()

	if not root then
		return
	end

	for _, object in ipairs(getCollectibleSearchPool()) do
		local itemPart = getLiveItemPart(object)

		if itemPart and Items.IsPartInsideAutoPickupZone(itemPart, root) then
			for _, itemName in ipairs(itemNames) do
				if itemNameMatches(object, itemName) then
					Items.TrackAutoPickupItem(object, itemPart, itemName)
					break
				end
			end
		end
	end
end

function Items.ClearAutoPickupPart()
	if Items.AutoPickupFollowConnection then
		Items.AutoPickupFollowConnection:Disconnect()
		Items.AutoPickupFollowConnection = nil
	end

	if Items.AutoPickupTouchedConnection then
		Items.AutoPickupTouchedConnection:Disconnect()
		Items.AutoPickupTouchedConnection = nil
	end

	if Items.AutoPickupTouchEndedConnection then
		Items.AutoPickupTouchEndedConnection:Disconnect()
		Items.AutoPickupTouchEndedConnection = nil
	end

	if Items.AutoPickupPart then
		pcall(function()
			Items.AutoPickupPart:Destroy()
		end)

		Items.AutoPickupPart = nil
	end

	Items.AutoPickupTouching = {}
end

function Items.EnsureAutoPickupPart()
	local root = Items.GetAutoPickupRoot()

	if not root then
		Items.ClearAutoPickupPart()
		return nil
	end

	if Items.AutoPickupPart and Items.AutoPickupPart.Parent then
		return Items.AutoPickupPart
	end

	local pickupPart = Instance.new("Part")
	pickupPart.Name = "Part"
	pickupPart.Size = Vector3.new(30, 30, 30)
	pickupPart.Transparency = 1
	pickupPart.Anchored = true
	pickupPart.CanCollide = false
	pickupPart.CanQuery = false
	pickupPart.CanTouch = true
	pickupPart.CFrame = root.CFrame
	pickupPart.Parent = workspace

	Items.AutoPickupPart = pickupPart

	Items.AutoPickupTouchedConnection = pickupPart.Touched:Connect(function(hit)
		local itemObject, itemPart, itemName = Items.FindAutoPickupItemFromPart(hit)
		Items.TrackAutoPickupItem(itemObject, itemPart, itemName)
	end)

	Items.AutoPickupTouchEndedConnection = pickupPart.TouchEnded:Connect(function(hit)
		local itemObject = Items.FindAutoPickupItemFromPart(hit)

		if itemObject then
			Items.AutoPickupTouching[itemObject] = nil
		end
	end)

	Items.AutoPickupFollowConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()

		if now - (Items.LastAutoPickupFollowAt or 0) < (Items.AutoPickupFollowInterval or 0.05) then
			return
		end

		Items.LastAutoPickupFollowAt = now

		local currentRoot = Items.GetAutoPickupRoot()

		if currentRoot and pickupPart.Parent then
			pickupPart.CFrame = currentRoot.CFrame
		end
	end)

	return pickupPart
end

function Items.StartAutoPickupThread()
	if Items.AutoPickupThread then
		return
	end

	Items.AutoPickupThread = task.spawn(function()
		while Items.AutoPickupEnabled do
			Items.EnsureAutoPickupPart()
			Items.ScanAutoPickupItems()

			local root = Items.GetAutoPickupRoot()
			local shouldPressPickup = false

			for itemObject, entry in pairs(Items.AutoPickupTouching) do
				local itemPart = getLiveItemPart(itemObject)

				if not root
					or not itemPart
					or not isSameItemStillThere(itemObject, itemPart, entry.Name)
					or not Items.IsPartInsideAutoPickupZone(itemPart, root) then
					Items.AutoPickupTouching[itemObject] = nil
				else
					shouldPressPickup = true
					entry.Part = itemPart

					if not Items.IsPickupInputLocked() then
						pcall(function()
							ProximityPromptService.Enabled = true
						end)
					end

					if isTouchDevice then
						Items.UsePickupInput(itemObject, itemPart)
					end
				end
			end

			if shouldPressPickup and not isTouchDevice then
				Items.UsePickupInput(nil, nil)
			end

			task.wait(Items.AutoPickupScanInterval or 0.25)
		end

		Items.AutoPickupThread = nil
	end)
end

function Items.SetAutoPickup(state, silent)
	Items.AutoPickupEnabled = state == true

	if Items.AutoPickupEnabled then
		Items.EnsureAutoPickupPart()
		Items.StartAutoPickupThread()

		if not silent then
			createNotification("Auto pick up", "Auto pick up enabled.", "Success")
		end
	else
		Items.ClearAutoPickupPart()

		if not silent then
			createNotification("Auto pick up", "Auto pick up disabled.")
		end
	end
end

local autoPermanentEnabled = false
local autoPermanentToggle = nil
local autoPermanentThread = nil
local autoPermanentSeenAt = {}
local lastAutoPermanentUseAt = 0
local AUTO_PERMANENT_USE_DEBOUNCE = 0.015
local AUTO_PERMANENT_SCAN_INTERVAL = 0.015
local runAutoUsePermanentItems = nil
local toolUseBusy = false
local lastToolUseAt = 0
local TOOL_USE_SPACING = 0.35
local autoSortEnabled = false
local autoSortBusy = false
local autoSortQueued = false
local autoSortSuppressUntil = 0
local autoSortKnownTools = {}
local autoSortConnections = {}

local function setAutoPermanentItems(state, silent)
	if state == true and (Items.AutoCollectEnabled or Items.EarlyAutoCollectEnabled) then
		autoPermanentEnabled = false
		autoPermanentSeenAt = {}
		lastAutoPermanentUseAt = 0

		if autoPermanentToggle and autoPermanentToggle.Set then
			autoPermanentToggle.Set(false, false)
		end

		if not silent then
			createNotification("Auto Use", "Auto Use Permanent Items stays off while collecting.", "Info")
		end

		return
	end

	autoPermanentEnabled = state == true

	if autoPermanentEnabled then
		autoPermanentSeenAt = {}
		lastAutoPermanentUseAt = 0

		if not silent then
			createNotification("Auto Use", "Auto Use Permanent Items enabled.", "Success")
		end

		if not autoPermanentThread and runAutoUsePermanentItems then
			autoPermanentThread = task.spawn(function()
				runAutoUsePermanentItems()
				autoPermanentThread = nil
			end)
		end
	elseif not silent then
		createNotification("Auto Use", "Auto Use Permanent Items disabled.")
	end
end

function Items.ForceAutoPermanentItemsOff()
	autoPermanentEnabled = false
	autoPermanentSeenAt = {}
	lastAutoPermanentUseAt = 0

	if autoPermanentToggle and autoPermanentToggle.Set then
		autoPermanentToggle.Set(false, false)
	end

	task.defer(function()
		if autoPermanentToggle and autoPermanentToggle.Set then
			autoPermanentToggle.Set(false, false)
		end
	end)

	task.delay(0.35, function()
		if Items.AutoCollectEnabled or Items.EarlyAutoCollectEnabled then
			autoPermanentEnabled = false

			if autoPermanentToggle and autoPermanentToggle.Set then
				autoPermanentToggle.Set(false, false)
			end
		end
	end)
end

function Items.DisableEarlyAutoCollectConflicts(mode, silent)
	mode = mode == "Early" and "Early" or "Auto"

	Items.EarlyAutoCollectRestoreAutoPickup = false
	local wasAutoPermanentEnabled = autoPermanentEnabled == true
		or (autoPermanentToggle and autoPermanentToggle.Get and autoPermanentToggle.Get() == true)

	Items.PriorityCollectRestoreAutoPermanent[mode] = false
	Items.EarlyAutoCollectRestoreAutoPermanent = false

	Items.ForceAutoPermanentItemsOff()

	if wasAutoPermanentEnabled then
		if not silent then
			createNotification(Items.GetPriorityCollectTitle(mode), "Auto Use Permanent Items disabled.", "Info")
		end
	end

	Items.ForceAutoPermanentItemsOff()
end

function Items.RestoreEarlyAutoCollectConflicts(mode, silent)
	mode = mode == "Early" and "Early" or "Auto"

	Items.EarlyAutoCollectRestoreAutoPickup = false
	Items.PriorityCollectRestoreAutoPermanent[mode] = false
	Items.EarlyAutoCollectRestoreAutoPermanent = false
end

function Items.IsPriorityCollectEnabled(mode)
	if mode == "Auto" then
		return Items.AutoCollectEnabled == true
	end

	return Items.EarlyAutoCollectEnabled == true
end

function Items.SetPriorityCollectEnabled(mode, state)
	if mode == "Auto" then
		Items.AutoCollectEnabled = state == true
	else
		Items.EarlyAutoCollectEnabled = state == true
	end
end

function Items.GetPriorityCollectTitle(mode)
	return mode == "Auto" and "Auto collect" or "Early Auto Collect"
end

function Items.SpamPickupForPriorityCollect(mode, itemObject, itemPart, itemName, duration)
	local stopAt = os.clock() + duration

	task.spawn(function()
		while Items.IsPriorityCollectEnabled(mode) and os.clock() < stopAt and isSameItemStillThere(itemObject, itemPart, itemName) do
			if mode ~= "Auto" and os.clock() < (Items.EarlyAutoCollectPauseUntil or 0) then
				break
			end

			Items.UsePickupInput(itemObject, itemPart)
			task.wait(0.08)
		end
	end)
end

function Items.StopPriorityCollect(mode, message, notInLobby)
	local title = Items.GetPriorityCollectTitle(mode)

	Items.SetPriorityCollectEnabled(mode, false)
	setMovementPaused(false)
	Items.RestoreEarlyAutoCollectConflicts(mode, true)

	if notInLobby then
		Items.EarlyAutoCollectNotInLobby = true
	end

	if mode == "Auto" and Items.AutoCollectToggle then
		Items.AutoCollectToggle.Set(false, false)
	elseif Items.EarlyAutoCollectToggle then
		Items.EarlyAutoCollectToggle.Set(false, false)
	end

	if message then
		createNotification(title, message)
	end
end

function Items.StopEarlyAutoCollect(message, notInLobby)
	Items.StopPriorityCollect("Early", message, notInLobby)
end

function Items.ResetPriorityCollectState(mode)
	local isEarly = mode ~= "Auto"
	local collectOrder = isEarly and Items.PermanentCollectStopOrder or autoCollectPriority

	Items.SetPriorityCollectEnabled(mode, true)
	Items.EarlyAutoCollectPauseUntil = 0
	Items.EarlyAutoCollectZeroPauseTriggered = false
	Items.FullPriorityCollectUnlocked = true
	Items.EarlyAutoCollectPermanentSeen = false
	Items.EarlyAutoCollectConfirmingPermanents = false
	Items.EarlyAutoCollectConfirmAt = 0
	Items.EarlyAutoCollectConfirmCount = 0
	primaryCollectOrder = collectOrder
	pinnedItemOrder = primaryCollectOrder
	searchAllItemsUnlocked = true
	setItemSearchTargets(collectOrder)
	visitedCollectPositions = {}
	ignoredCollectTargets = {}
	ignoredCollectPositions = {}
	invalidateCollectibleSearchPool()
	Teleport.Cooldown = Teleport.DefaultCooldown
	if Teleport.ApplyCustomSettings then
		Teleport.ApplyCustomSettings()
	else
		Teleport.MaxStrikes = Teleport.DefaultMaxStrikes
		Teleport.Debounce = Teleport.DefaultDebounce
		Teleport.PostFLock = Teleport.DefaultPostFLock
		Items.TeleportDebounce = Teleport.DefaultDebounce
	end
end

function Items.UnlockFullPriorityCollect()
	if Items.FullPriorityCollectUnlocked then
		return
	end

	Items.FullPriorityCollectUnlocked = true
	Items.EarlyAutoCollectConfirmingPermanents = false
	Items.EarlyAutoCollectConfirmAt = 0
	Items.EarlyAutoCollectConfirmCount = 0
	primaryCollectOrder = autoCollectPriority
	pinnedItemOrder = autoCollectPriority
	searchAllItemsUnlocked = true
	setItemSearchTargets(autoCollectPriority)
	invalidateCollectibleSearchPool()
	createNotification("Auto collect", "Permanent items collected. Continuing priority order.", "Success")
end

function Items.StartEarlyAutoCollectZeroPauseWatcher()
	if Items.EarlyAutoCollectZeroPauseWatcherActive then
		return
	end

	Items.EarlyAutoCollectZeroPauseWatcherActive = true
	Items.EarlyAutoCollectZeroPauseTriggered = false

	task.spawn(function()
		local sawTimer = false
		local lastNumber = nil

		while Items.EarlyAutoCollectEnabled do
			local number = Main.FindSlapRoyaleTimer()

			if number then
				sawTimer = true
				lastNumber = number

				if number <= 0 then
					break
				end
			elseif sawTimer and lastNumber and lastNumber <= 1 then
				break
			end

			task.wait(0.1)
		end

		if Items.EarlyAutoCollectEnabled and not Items.EarlyAutoCollectZeroPauseTriggered then
			Items.EarlyAutoCollectZeroPauseTriggered = true

			task.wait(1)

			if Items.EarlyAutoCollectEnabled then
				local resumeDelay = Teleport.GetEarlyAutoCollectResumeDelay and Teleport.GetEarlyAutoCollectResumeDelay() or 11
				local resumeAt = os.clock() + resumeDelay
				Items.EarlyAutoCollectPauseUntil = math.max(Items.EarlyAutoCollectPauseUntil or 0, resumeAt)
				setMovementPaused(false)
				createNotification("Early Auto Collect", "Round started. Pausing collection for " .. string.format("%.1f", resumeDelay) .. " seconds.", "Info")
			end
		end

		Items.EarlyAutoCollectZeroPauseWatcherActive = false
	end)
end

function Items.RunPriorityAutoCollect(mode)
	local isEarly = mode ~= "Auto"
	local title = Items.GetPriorityCollectTitle(mode)
	local emptyTargetCount = 0

	setMovementPaused(true)

	if isEarly then
		Items.EarlyAutoCollectSawTimer = false
		Items.StartEarlyAutoCollectZeroPauseWatcher()

		while Items.EarlyAutoCollectEnabled do
			local number = Main.FindSlapRoyaleTimer()

			if number then
				Items.EarlyAutoCollectSawTimer = true
				Main.TimerPrinterLastNumber = number

				if number <= 3 then
					break
				end
			elseif Items.EarlyAutoCollectSawTimer then
				break
			end

			task.wait(0.1)
		end
	end

	if not Items.IsPriorityCollectEnabled(mode) then
		setMovementPaused(false)
		return
	end

	Teleport.Cooldown = Teleport.DefaultCooldown
	if Teleport.ApplyCustomSettings then
		Teleport.ApplyCustomSettings()
	else
		Teleport.MaxStrikes = Teleport.DefaultMaxStrikes
		Teleport.Debounce = Teleport.DefaultDebounce
		Teleport.PostFLock = Teleport.DefaultPostFLock
		Items.TeleportDebounce = Teleport.DefaultDebounce
	end
	createNotification(title, isEarly and "Timer hit 3. Starting priority collection." or "Starting priority collection.", "Success")

	while Items.IsPriorityCollectEnabled(mode) do
		setMovementPaused(true)

		while isEarly and Items.IsPriorityCollectEnabled(mode) and os.clock() < (Items.EarlyAutoCollectPauseUntil or 0) do
			setMovementPaused(false)
			task.wait(0.05)
		end

		if isEarly and Items.IsPriorityCollectEnabled(mode) then
			setMovementPaused(true)
		end

		if Items.IsPriorityCollectEnabled(mode) and not Items.FullPriorityCollectUnlocked and Items.ShouldFinishEarlyAutoCollectPermanents() then
			Items.UnlockFullPriorityCollect()
		end

		local teleportWait = Teleport.GetWaitBeforeTeleport(Items.TeleportDebounce)

		if teleportWait > 0 then
			task.wait(math.clamp(teleportWait, 0.1, 0.5))
			continue
		end

		if not Teleport.CanTeleport(Items.TeleportDebounce, true, true) then
			task.wait(0.15)
			continue
		end

		local itemName, itemCFrame, itemPosition, itemObject, itemPart = findNextCollectTarget()

			if not itemName then
				if isItemScanLoading() then
					emptyTargetCount = 0
					task.wait(0.05)
					continue
				end

				if not Items.FullPriorityCollectUnlocked then
					Items.UnlockFullPriorityCollect()
					emptyTargetCount = 0
					task.wait(0.05)
					continue
				end

				emptyTargetCount += 1

			if emptyTargetCount >= 8 then
				Items.StopPriorityCollect(mode, "Priority list finished.", false)
				break
			end

			task.wait(0.1)
			continue
		end

		emptyTargetCount = 0

		if not isSameItemStillThere(itemObject, itemPart, itemName) then
			ignoreCollectedTarget(itemObject, itemPart, itemPosition)
			task.wait(0.05)
			continue
		end

		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart", 5)

		if root then
			ignoreCollectedTarget(itemObject, itemPart, itemPosition)

			local groundCFrame = Teleport.GetItemCFrame(itemPart, { character, itemObject })

			Teleport.MoveRoot(root, groundCFrame, itemPart.Position)
			Teleport.StabilizeItemView(root, itemPart)
			Teleport.AddStrike()
			Teleport.StartFBlock()
			createNotification(title, "Collected " .. itemName)

			task.delay(0.05, function()
				if Items.IsPriorityCollectEnabled(mode) and isSameItemStillThere(itemObject, itemPart, itemName) then
					Items.SpamPickupForPriorityCollect(mode, itemObject, itemPart, itemName, 1.35)
				end
			end)
		end

		task.wait(0.5)
	end

	setMovementPaused(false)
end

function Items.RunEarlyAutoCollect()
	Items.RunPriorityAutoCollect("Early")
end

function Items.RunAutoCollect()
	Items.RunPriorityAutoCollect("Auto")
end

function Items.SetEarlyAutoCollect(state, silent)
	if state then
		if Items.EarlyAutoCollectNotInLobby then
			if not silent then
				createNotification("Early Auto Collect", "Not in lobby", "Warning")
			end

			task.defer(function()
				if Items.EarlyAutoCollectToggle then
					Items.EarlyAutoCollectToggle.Set(false, false)
				end
			end)

			return
		end

		if UI.IsLocalPlayerInBus and UI.IsLocalPlayerInBus() then
			if not silent then
				createNotification("Early Auto Collect", "You cannot start this while already in the bus.", "Warning")
			end

			task.defer(function()
				if Items.EarlyAutoCollectToggle then
					Items.EarlyAutoCollectToggle.Set(false, false)
				end
			end)

			return
		end

		local timerNumber = Main.FindSlapRoyaleTimer()

		if not timerNumber then
			if not silent then
				createNotification("Early Auto Collect", "No countdown detected.", "Warning")
			end

			task.defer(function()
				if Items.EarlyAutoCollectToggle then
					Items.EarlyAutoCollectToggle.Set(false, false)
				end
			end)

			return
		end

		if timerNumber <= 3 then
			if not silent then
				createNotification("Early Auto Collect", "Must be activated before there are 3 seconds left.", "Warning")
			end

			task.defer(function()
				if Items.EarlyAutoCollectToggle then
					Items.EarlyAutoCollectToggle.Set(false, false)
				end
			end)

			return
		end

		if Items.EarlyAutoCollectEnabled then
			return
		end

		if Items.AutoCollectEnabled then
			if not silent then
				createNotification("Early Auto Collect", "Turn Auto collect off first.", "Warning")
			end

			task.defer(function()
				if Items.EarlyAutoCollectToggle then
					Items.EarlyAutoCollectToggle.Set(false, false)
				end
			end)

			return
		end

		if UI.ToggleRefs.EarlyBusJump then
			UI.ToggleRefs.EarlyBusJump.Set(true, false)
		end

		if UI.SetAutoEarlyBusJump then
			UI.SetAutoEarlyBusJump(true, true)
		end

		Items.DisableEarlyAutoCollectConflicts("Early", silent)
		Items.ResetPriorityCollectState("Early")
		if not silent then
			createNotification("Early Auto Collect", "Waiting for countdown to end.", "Info")
		end

		if not Items.EarlyAutoCollectThread then
			Items.EarlyAutoCollectThread = task.spawn(function()
				Items.RunEarlyAutoCollect()
				Items.EarlyAutoCollectThread = nil
			end)
		end
	else
		Items.EarlyAutoCollectEnabled = false
		setMovementPaused(false)
		Items.RestoreEarlyAutoCollectConflicts("Early", silent)
		if not silent then
			createNotification("Early Auto Collect", "Early Auto Collect disabled.")
		end
	end
end

function Items.SetAutoCollect(state, silent)
	if state then
		if Items.AutoCollectEnabled then
			return
		end

		if Items.EarlyAutoCollectEnabled then
			if not silent then
				createNotification("Auto collect", "Turn Early Auto Collect off first.", "Warning")
			end

			task.defer(function()
				if Items.AutoCollectToggle then
					Items.AutoCollectToggle.Set(false, false)
				end
			end)

			return
		end

		Items.DisableEarlyAutoCollectConflicts("Auto", silent)
		Items.ResetPriorityCollectState("Auto")
		if not silent then
			createNotification("Auto collect", "Starting priority collection.", "Info")
		end

		if not Items.AutoCollectThread then
			Items.AutoCollectThread = task.spawn(function()
				Items.RunAutoCollect()
				Items.AutoCollectThread = nil
			end)
		end
	else
		Items.AutoCollectEnabled = false
		setMovementPaused(false)
		Items.RestoreEarlyAutoCollectConflicts("Auto", silent)
		if not silent then
			createNotification("Auto collect", "Auto collect disabled.")
		end
	end
end

local autoHealEnabled = false
local autoHealThread = nil
local autoHealConnection = nil
local lastAutoHealUseAt = 0
local AUTO_HEAL_USE_DEBOUNCE = 0.1

local healingItems = {
	"First Aid Kit",
	"Healing Potion",
	"Apple",
	"Bandage",
}

local priorityHotbarItems = {
	"True Power",
	"Gravitation Shard",
	"Lightning Potion",
	"Forcefield Crystal",
	"Tomahawk"
}

local permanentUseItems = {
	"Potion of Strength",
	"Bull's Essence",
	"Boba",
	"Speed Potion",
	"Frog Potion",
}

local backpackSortItems = {
	"First Aid Kit",
	"Healing Potion",
	"Apple",
	"Bandage",
	"Sphere of Fury",
	"Cube of Ice",
	"Bomb",
	"Bombs",
}

local function getInventoryTools()
	local tools = {}
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")

	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	return tools
end

local function getItemOrderRank(toolName, itemList)
	for index, itemName in ipairs(itemList) do
		if normalizeName(toolName) == normalizeName(itemName) then
			return index
		end
	end

	return nil
end

local function isLikelyGloveTool(tool)
	local name = normalizeName(tool.Name)

	if string.find(name, "glove") or string.find(name, "slap") then
		return true
	end

	return not matchesItem(tool.Name, itemNames)
end

local function getToolSortRank(tool)
	if isLikelyGloveTool(tool) then
		return math.huge
	end

	if normalizeName(tool.Name) == normalizeName("True Power") then
		return 20
	end

	if normalizeName(tool.Name) == normalizeName("Tomahawk") then
		return 21
	end

	if normalizeName(tool.Name) == normalizeName("Gravitation Shard") then
		return 22
	end

	local permanentRank = getItemOrderRank(tool.Name, permanentUseItems)
	if permanentRank then
		return 30 + permanentRank
	end

	local priorityRank = getItemOrderRank(tool.Name, priorityHotbarItems)
	if priorityRank then
		return 50 + priorityRank
	end

	local backpackRank = getItemOrderRank(tool.Name, backpackSortItems)
	if backpackRank then
		return 120 + backpackRank
	end

	for index, itemName in ipairs(itemNames) do
		if normalizeName(tool.Name) == normalizeName(itemName) then
			return 60 + index
		end
	end

	return 80
end

local function hasInventoryItemNamed(toolName)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and normalizeName(child.Name) == normalizeName(toolName) then
				return true
			end
		end
	end

	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and normalizeName(child.Name) == normalizeName(toolName) then
				return true
			end
		end
	end

	return false
end

local function sortInventory(showNotification)
	if autoSortBusy then
		return
	end

	local backpack = player:FindFirstChild("Backpack")

	if not backpack then
		if showNotification ~= false then
			createNotification("Inventory", "Backpack not found.", "Error")
		end
		return
	end

	autoSortBusy = true
	autoSortSuppressUntil = os.clock() + 2
	local tools = {}
	local holdingFolder = Instance.new("Folder")
	holdingFolder.Name = "Part"

	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and not isLikelyGloveTool(tool) then
			table.insert(tools, tool)
			tool.Parent = holdingFolder
		end
	end

	table.sort(tools, function(left, right)
		local leftRank = getToolSortRank(left)
		local rightRank = getToolSortRank(right)

		if leftRank == rightRank then
			return left.Name < right.Name
		end

		return leftRank < rightRank
	end)

	for _, tool in ipairs(tools) do
		tool.Parent = backpack
		task.wait()
	end

	holdingFolder:Destroy()
	autoSortBusy = false
	autoSortSuppressUntil = os.clock() + 2

	for _, tool in ipairs(getInventoryTools()) do
		autoSortKnownTools[tool] = true
	end

	if showNotification ~= false then
		createNotification("Auto Sort", "Glove first, priority items next, backpack items kept later.", "Success")
	end
end

local function refreshKnownAutoSortTools()
	autoSortKnownTools = {}

	for _, tool in ipairs(getInventoryTools()) do
		autoSortKnownTools[tool] = true
	end
end

local function queueAutoSort(child, allowKnownTool)
	if not autoSortEnabled or autoSortBusy or autoSortQueued or os.clock() < autoSortSuppressUntil then
		return
	end

	if child and not child:IsA("Tool") then
		return
	end

	if child and autoSortKnownTools[child] and not allowKnownTool then
		return
	end

	if child then
		autoSortKnownTools[child] = true
	end

	autoSortQueued = true
	task.delay(0.6, function()
		autoSortQueued = false

		if autoSortEnabled and not autoSortBusy and os.clock() >= autoSortSuppressUntil then
			sortInventory(false)
		end
	end)
end

local function queueAutoSortAdded(child)
	queueAutoSort(child, false)
end

local function queueAutoSortBackpackRemoved(child)
	if not child or not child:IsA("Tool") or not matchesItem(child.Name, itemNames) then
		return
	end

	local removedName = child.Name
	task.delay(0.15, function()
		if autoSortEnabled and not hasInventoryItemNamed(removedName) then
			queueAutoSort(child, true)
		end
	end)
end

local function queueAutoSortInventoryRemoved(child)
	if not child or not child:IsA("Tool") or not matchesItem(child.Name, itemNames) then
		return
	end

	queueAutoSort(child, true)
end

local function clearAutoSortConnections()
	for _, connection in ipairs(autoSortConnections) do
		connection:Disconnect()
	end

	autoSortConnections = {}
end

local function hookAutoSort()
	clearAutoSortConnections()
	refreshKnownAutoSortTools()

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		table.insert(autoSortConnections, backpack.ChildAdded:Connect(queueAutoSortAdded))
		table.insert(autoSortConnections, backpack.ChildRemoved:Connect(queueAutoSortBackpackRemoved))
	end

	local character = player.Character
	if character then
		table.insert(autoSortConnections, character.ChildRemoved:Connect(queueAutoSortInventoryRemoved))
	end
end

local function setAutoSort(state, silent)
	autoSortEnabled = state == true

	if autoSortEnabled then
		sortInventory(false)
		hookAutoSort()
		if not silent then
			createNotification("Auto Sort", "Auto Sort enabled and sorted.", "Success")
		end
	else
		clearAutoSortConnections()
		if not silent then
			createNotification("Auto Sort", "Auto Sort disabled.")
		end
	end
end

function Items.CleanupAutomation()
	autoPermanentEnabled = false
	autoHealEnabled = false
	autoSortEnabled = false
	Items.AutoPickupEnabled = false
	Items.EarlyAutoCollectRestoreAutoPickup = false
	Items.EarlyAutoCollectRestoreAutoPermanent = false
	Items.PriorityCollectRestoreAutoPermanent.Auto = false
	Items.PriorityCollectRestoreAutoPermanent.Early = false
	Items.CollectCratesBusy = false
	Items.SetFastCollectCrates(false, true)
	Items.SetCrateAura(false, true)
	setMovementPaused(false)
	clearAutoSortConnections()
	Items.ClearAutoPickupPart()
	Items.ClearCrateCollectPart()
	Items.ClearCrateWatcher()

	pcall(function()
		game:GetService("ProximityPromptService").Enabled = true
	end)

	if autoHealConnection then
		autoHealConnection:Disconnect()
		autoHealConnection = nil
	end
end

local function useTool(tool, fastMode)
	if toolUseBusy then
		return false
	end

	local now = os.clock()
	local spacing = fastMode and AUTO_PERMANENT_USE_DEBOUNCE or TOOL_USE_SPACING
	if now - lastToolUseAt < spacing then
		return false
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not tool or not tool:IsA("Tool") then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	toolUseBusy = true
	local used = false
	local backpack = player:FindFirstChild("Backpack")

	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true
	humanoid:ChangeState(Enum.HumanoidStateType.Running)

	if root then
		root.AssemblyAngularVelocity = Vector3.zero
		root.AssemblyLinearVelocity = Vector3.zero
	end

	if backpack and tool.Parent == backpack then
		humanoid:EquipTool(tool)
		task.wait(fastMode and 0.02 or 0.35)
	end

	if tool.Parent == character then
		if root then
			root.AssemblyAngularVelocity = Vector3.zero
			root.AssemblyLinearVelocity = Vector3.zero
		end

		used = pcall(function()
			tool:Activate()
			if fastMode then
				task.wait(0.012)
				tool:Activate()
				task.wait(0.012)
				tool:Activate()
			end
		end)

		task.wait(fastMode and 0.025 or 0.45)

		if root then
			root.AssemblyAngularVelocity = Vector3.zero
			root.AssemblyLinearVelocity = Vector3.zero
		end

		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.Running)

		lastToolUseAt = os.clock()
		task.wait(fastMode and 0.005 or 0.3)
		toolUseBusy = false
		return used
	end

	toolUseBusy = false
	return false
end

local function findMatchingTool(itemList)
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")

	if character then
		for _, tool in ipairs(character:GetChildren()) do
			if tool:IsA("Tool") and matchesItem(tool.Name, itemList) then
				return tool
			end
		end
	end

	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") and matchesItem(tool.Name, itemList) then
				return tool
			end
		end
	end

	return nil
end

function Items.GetMatchingInventoryTools(itemList)
	local tools = {}

	for _, tool in ipairs(getInventoryTools()) do
		if tool:IsA("Tool") and matchesItem(tool.Name, itemList) then
			table.insert(tools, tool)
		end
	end

	return tools
end

function Items.PulseToolUseInput(tool)
	if not tool or not tool.Parent then
		return false
	end

	local activated = false

	for _ = 1, 3 do
		if not tool.Parent then
			break
		end

		if pcall(function()
			tool:Activate()
		end) then
			activated = true
		end

		task.wait(0.012)
	end

	pcall(function()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize

		if viewport then
			local VirtualInputManager = game:GetService("VirtualInputManager")
			local x = viewport.X * 0.5
			local y = viewport.Y * 0.5

			VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
			task.wait(0.012)
			VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
			activated = true
		end
	end)

	return activated
end

function Items.UseAllMatchingTools(itemList, label, pluralName)
	task.spawn(function()
		local startingTools = Items.GetMatchingInventoryTools(itemList)

		if #startingTools == 0 then
			createNotification(label, "No " .. pluralName .. " found.", "Warning")
			return
		end

		local usedCount = 0
		local failedAttempts = 0

		for _ = 1, 80 do
			local tool = findMatchingTool(itemList)

			if not tool then
				break
			end

			local used = false

			for _ = 1, 12 do
				if not tool.Parent or not matchesItem(tool.Name, itemList) or (Items.ToolIsInInventory and not Items.ToolIsInInventory(tool)) then
					used = true
					break
				end

				useTool(tool, true)
				Items.PulseToolUseInput(tool)

				for _ = 1, 5 do
					if not tool.Parent or not matchesItem(tool.Name, itemList) or (Items.ToolIsInInventory and not Items.ToolIsInInventory(tool)) then
						used = true
						break
					end

					task.wait(0.025)
				end

				if used then
					break
				end

				task.wait(0.035)
			end

			if used then
				usedCount += 1
				failedAttempts = 0
				task.wait(0.04)
			else
				failedAttempts += 1

				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")

				if humanoid then
					pcall(function()
						humanoid:UnequipTools()
					end)
				end

				if failedAttempts >= 2 then
					break
				end

				task.wait(0.08)
			end
		end

		if usedCount > 0 then
			createNotification(label, "Used " .. tostring(usedCount) .. " " .. pluralName .. ".", "Success")
		else
			createNotification(label, "Could not use any " .. pluralName .. ".", "Warning")
		end
	end)
end

function Items.UseSpheres()
	Items.UseAllMatchingTools({ "Sphere of Fury" }, "Use Spheres", "Sphere(s) of Fury")
end

function Items.UseCubes()
	Items.UseAllMatchingTools({ "Cube of Ice" }, "Use Cubes", "Cube(s) of Ice")
end

function Items.UseAllItems()
	Items.UseAllMatchingTools(itemNames, "Use All Items", "item(s)")
end

function Items.ToolIsInInventory(tool)
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")

	return tool
		and tool.Parent
		and ((character and tool:IsDescendantOf(character)) or (backpack and tool:IsDescendantOf(backpack)))
end

function Items.DropTool(tool)
	if not tool or not tool:IsA("Tool") or not tool.Parent then
		return false
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return false
	end

	pcall(function()
		tool.CanBeDropped = true
	end)

	if tool.Parent ~= character then
		pcall(function()
			humanoid:EquipTool(tool)
		end)
		task.wait(0.012)
	end

	if tool.Parent ~= character then
		return false
	end

	local ok = pcall(function()
		local VirtualInputManager = game:GetService("VirtualInputManager")
		VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
		task.wait(0.006)
		VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
	end)

	if not ok then
		return false
	end

	for _ = 1, 4 do
		if not Items.ToolIsInInventory(tool) then
			return true
		end

		task.wait(0.01)
	end

	return not Items.ToolIsInInventory(tool)
end

function Items.DropMatchingTools(itemList, label, pluralName)
	task.spawn(function()
		local tools = Items.GetMatchingInventoryTools(itemList)

		if #tools == 0 then
			createNotification(label, "No " .. pluralName .. " found.", "Warning")
			return
		end

		local droppedCount = 0

		for _, tool in ipairs(tools) do
			if tool and tool.Parent and matchesItem(tool.Name, itemList) then
				if Items.DropTool(tool) then
					droppedCount += 1
				end

				task.wait(0.003)
			end
		end

		if droppedCount > 0 then
			createNotification(label, "Dropped " .. tostring(droppedCount) .. " " .. pluralName .. ".", "Success")
		else
			createNotification(label, "Could not drop any " .. pluralName .. ".", "Warning")
		end
	end)
end

function Items.DropAllItems()
	Items.DropMatchingTools(itemNames, "Drop All Items", "item(s)")
end

function Items.DropAllPermanents()
	Items.DropMatchingTools(permanentUseItems, "Drop Permanent Items", "permanent item(s)")
end

function Items.GetTemporaryDropItems()
	local tempItems = {}

	for _, itemName in ipairs(itemNames) do
		if not matchesItem(itemName, permanentUseItems) then
			table.insert(tempItems, itemName)
		end
	end

	return tempItems
end

function Items.DropTempItems()
	Items.DropMatchingTools(Items.GetTemporaryDropItems(), "Drop Temp Items", "temporary item(s)")
end

local function tryAutoHeal()
	if not autoHealEnabled or toolUseBusy or os.clock() - lastToolUseAt < TOOL_USE_SPACING then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	local now = os.clock()
	local threshold = humanoid and math.max(30, humanoid.MaxHealth * 0.45) or 30

	if humanoid and humanoid.Health > 0 and humanoid.Health <= threshold and now - lastAutoHealUseAt >= AUTO_HEAL_USE_DEBOUNCE then
		local tool = findMatchingTool(healingItems)

		if tool then
			lastAutoHealUseAt = now
			if not useTool(tool) then
				lastAutoHealUseAt = os.clock()
			end
		end
	end
end

local function tryAutoUsePermanentItem()
	if not autoPermanentEnabled or toolUseBusy or os.clock() - lastAutoPermanentUseAt < AUTO_PERMANENT_USE_DEBOUNCE then
		return false
	end

	local tool = nil
	local now = os.clock()

	for _, candidate in ipairs(getInventoryTools()) do
		if candidate:IsA("Tool") and matchesItem(candidate.Name, permanentUseItems) then
			tool = candidate
			break
		end
	end

	if not tool then
		autoPermanentSeenAt = {}
		return false
	end

	lastAutoPermanentUseAt = now
	autoPermanentSeenAt[tool] = nil
	if useTool(tool, true) then
		return true
	end

	lastAutoPermanentUseAt = os.clock()
	return false
end

runAutoUsePermanentItems = function()
	while autoPermanentEnabled do
		local used = tryAutoUsePermanentItem()
		task.wait(used and AUTO_PERMANENT_SCAN_INTERVAL or 0.25)
	end
end

local function hookAutoHealCharacter()
	if autoHealConnection then
		autoHealConnection:Disconnect()
		autoHealConnection = nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		autoHealConnection = humanoid.HealthChanged:Connect(function()
			tryAutoHeal()
		end)
	end
end

local function runAutoHeal()
	hookAutoHealCharacter()

	while autoHealEnabled do
		tryAutoHeal()
		task.wait(0.5)
	end

	autoHealThread = nil
end

function Items.SetAutoHeal(state, silent)
	autoHealEnabled = state == true

	if autoHealEnabled then
		hookAutoHealCharacter()

		if not autoHealThread then
			autoHealThread = task.spawn(runAutoHeal)
		end

		if not silent then
			createNotification("Auto Heal", "Auto Heal enabled.", "Success")
		end
	else
		if autoHealConnection then
			autoHealConnection:Disconnect()
			autoHealConnection = nil
		end

		if not silent then
			createNotification("Auto Heal", "Auto Heal disabled.")
		end
	end
end

function Items.SetAutoPermanentItems(state, silent)
	setAutoPermanentItems(state, silent)
end

function Items.SetAutoSort(state, silent)
	setAutoSort(state, silent)
end

player.CharacterAdded:Connect(function()
	task.wait(0.25)

	if autoHealEnabled then
		hookAutoHealCharacter()
	end

	if autoSortEnabled then
		hookAutoSort()
	end
end)

Combat = {
	HitboxSize = 10,
	HitboxMinSize = 10,
	HitboxMaxSize = 20,
	HitboxTransparency = 0.7,
	HitboxColor = Color3.fromRGB(0, 170, 255),
	HitboxExpanded = false,
	HitboxVisible = true,
	SavedHitboxes = {},
	HitboxConnection = nil,
	HitboxCharacterConnections = {},
	HitboxStatusConnections = {},
	HitboxRefreshInterval = 0.35,
	LastHitboxRefresh = 0,
	PlayerTpButtonsEnabled = false,
	PlayerTpButtonGuis = {},
	PlayerTpButtonConnections = {},
	PlayerTpButtonPlayerConnections = {},
	PlayerTpButtonPlayerAddedConnection = nil,
	AutoGloveTapEnabled = false,
	AutoGloveTapConnection = nil,
	AutoGloveTapThread = nil,
	AutoGloveTapDebounce = 0.12,
	AutoGloveTapScanInterval = 0.22,
	LastAutoGloveTap = 0,
	LastAutoGloveScan = 0,
	SlapAuraEnabled = false,
	SlapAuraThread = nil,
	SlapAuraRange = 20,
	SlapAuraInterval = 0.45,
	GloveTpSlapEnabled = false,
	GloveTpSlapConnections = {},
	GloveTpSlapCharacterConnections = {},
	GloveTpSlapCharacterAddedConnection = nil,
	LastGloveTpSlap = 0,
	LastGloveTpSlapWarning = 0,
	GloveTpSlapBusy = false,
	GloveTpSlapInternalActivate = false,
	GloveTpSlapHoldTime = 0.5,
	GloveTpSlapDebounce = 1,
	GloveTpSlapActionName = "GloveTpSlapClickBlock",
	AntiSlapEnabled = false,
	AntiSlapConnections = {},
	AntiSlapBoxFolder = nil,
	AntiSlapWasRagdolled = false,
	AntiSlapEnabledAt = 0,
	AntiSlapActiveUntil = 0,
	LastAntiSlapBoxAt = 0,
	LastAntiSlapCheckAt = 0,
	AntiSlapCheckInterval = 0.35,
	AntiSlapBoxDuration = 1,
	GloveSizeScale = 1,
	GloveSizeMin = 1,
	GloveSizeMax = 8,
	GloveSizeStep = 0.25,
	GloveSizeOriginals = {},
	GloveSizeLabel = nil,
	GloveSizeConnections = {},
	GloveSizeCharacterAddedConnection = nil
}

Combat.KnownItemToolLookup = {}

for _, itemName in ipairs({
	"Apple",
	"Bandage",
	"Boba",
	"Bomb",
	"Bull's Essence",
	"Bull's essence",
	"Cube of Ice",
	"First Aid Kit",
	"Forcefield Crystal",
	"Frog Potion",
	"Gravitation Shard",
	"Healing Potion",
	"Lightning Potion",
	"Potion of Strength",
	"Speed Potion",
	"Sphere of Fury",
	"Sphere of fury",
	"Tomahawk",
	"True Power",
	"Bombs"
}) do
	Combat.KnownItemToolLookup[Utility.NormalizeName(itemName)] = true
end

function Combat.IsKnownItemToolName(toolName)
	if not toolName then
		return false
	end

	return Combat.KnownItemToolLookup[Utility.NormalizeName(toolName)] == true
end

function Combat.GetEnemyRoot(otherPlayer)
	if otherPlayer == Players.LocalPlayer then
		return nil
	end

	local character = otherPlayer.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

function Combat.SaveOriginalHitbox(otherPlayer, root)
	if Combat.SavedHitboxes[otherPlayer] then
		return
	end

	Combat.SavedHitboxes[otherPlayer] = {
		Size = root.Size,
		Transparency = root.Transparency,
		Color = root.Color,
		Material = root.Material,
		CanCollide = root.CanCollide
	}
end

function Combat.ApplyHitbox(otherPlayer)
	local root = Combat.GetEnemyRoot(otherPlayer)
	if not root then
		return
	end

	local character = otherPlayer.Character
	local humanoid = Combat.GetPlayerHumanoid(otherPlayer)
	if not humanoid or humanoid.Health <= 0 then
		Combat.ResetHitbox(otherPlayer)
		return
	end

	if Combat.IsRagdolledTarget(character, humanoid, otherPlayer) then
		Combat.ResetHitbox(otherPlayer)
		return
	end

	Combat.SaveOriginalHitbox(otherPlayer, root)

	root.Size = Vector3.new(Combat.HitboxSize, Combat.HitboxSize, Combat.HitboxSize)
	root.Transparency = Combat.HitboxVisible and Combat.HitboxTransparency or 1
	root.Color = Combat.HitboxColor
	root.Material = Enum.Material.Neon
	root.CanCollide = false
end

function Combat.ResetHitbox(otherPlayer)
	local root = Combat.GetEnemyRoot(otherPlayer)
	local saved = Combat.SavedHitboxes[otherPlayer]

	if root and saved then
		root.Size = saved.Size
		root.Transparency = saved.Transparency
		root.Color = saved.Color
		root.Material = saved.Material
		root.CanCollide = saved.CanCollide
	end

	Combat.SavedHitboxes[otherPlayer] = nil
end

function Combat.ClearPlayerHitboxRefresh(otherPlayer)
	if Combat.HitboxCharacterConnections and Combat.HitboxCharacterConnections[otherPlayer] then
		pcall(function()
			Combat.HitboxCharacterConnections[otherPlayer]:Disconnect()
		end)

		Combat.HitboxCharacterConnections[otherPlayer] = nil
	end

	if Combat.HitboxStatusConnections and Combat.HitboxStatusConnections[otherPlayer] then
		for _, connection in ipairs(Combat.HitboxStatusConnections[otherPlayer]) do
			pcall(function()
				connection:Disconnect()
			end)
		end

		Combat.HitboxStatusConnections[otherPlayer] = nil
	end
end

function Combat.RefreshPlayerHitboxForRagdoll(otherPlayer)
	if not otherPlayer or otherPlayer == player then
		return
	end

	local character = otherPlayer.Character
	local humanoid = Combat.GetPlayerHumanoid(otherPlayer)

	if not character or not humanoid or humanoid.Health <= 0 then
		Combat.ResetHitbox(otherPlayer)
		return
	end

	if Combat.IsRagdolledTarget(character, humanoid, otherPlayer) then
		Combat.ResetHitbox(otherPlayer)
		return
	end

	if Combat.HitboxExpanded then
		Combat.ApplyHitbox(otherPlayer)
	end
end

function Combat.HookPlayerHitboxStatus(otherPlayer, character)
	if not otherPlayer or otherPlayer == player or not character then
		return
	end

	Combat.HitboxStatusConnections = Combat.HitboxStatusConnections or {}

	if Combat.HitboxStatusConnections[otherPlayer] then
		for _, connection in ipairs(Combat.HitboxStatusConnections[otherPlayer]) do
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local connections = {}
	Combat.HitboxStatusConnections[otherPlayer] = connections

	local function refreshSoon()
		task.defer(function()
			Combat.RefreshPlayerHitboxForRagdoll(otherPlayer)
		end)
	end

	if humanoid then
		table.insert(connections, humanoid.StateChanged:Connect(refreshSoon))
	end

	for _, statusName in ipairs({ "Ragdoll", "Ragdolled", "IsRagdolled", "IsInRagdoll", "Ragdolling", "Knocked", "KnockedDown", "Downed", "Stunned" }) do
		table.insert(connections, otherPlayer:GetAttributeChangedSignal(statusName):Connect(refreshSoon))
		table.insert(connections, character:GetAttributeChangedSignal(statusName):Connect(refreshSoon))

		if humanoid then
			table.insert(connections, humanoid:GetAttributeChangedSignal(statusName):Connect(refreshSoon))
		end
	end

	table.insert(connections, character.ChildAdded:Connect(refreshSoon))
	table.insert(connections, character.ChildRemoved:Connect(refreshSoon))
	table.insert(connections, character.DescendantAdded:Connect(refreshSoon))
	table.insert(connections, character.DescendantRemoving:Connect(refreshSoon))

	refreshSoon()
end

function Combat.StartHitboxLoop()
	if Combat.HitboxConnection then
		return
	end

	Combat.HitboxConnection = RunService.Heartbeat:Connect(function()
		if not Combat.HitboxExpanded then
			return
		end

		local now = os.clock()
		if now - Combat.LastHitboxRefresh < Combat.HitboxRefreshInterval then
			return
		end

		Combat.LastHitboxRefresh = now

		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			local humanoid = Combat.GetPlayerHumanoid(otherPlayer)

			if humanoid and humanoid.Health > 0 then
				Combat.ApplyHitbox(otherPlayer)
			else
				Combat.ResetHitbox(otherPlayer)
			end
		end
	end)
end

function Combat.StopHitboxLoop()
	if Combat.HitboxConnection then
		Combat.HitboxConnection:Disconnect()
		Combat.HitboxConnection = nil
	end

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		Combat.ResetHitbox(otherPlayer)
	end
end

function Combat.RefreshHitboxes()
	if Combat.HitboxExpanded then
		Combat.StartHitboxLoop()

		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			local humanoid = Combat.GetPlayerHumanoid(otherPlayer)

			if humanoid and humanoid.Health > 0 then
				Combat.ApplyHitbox(otherPlayer)
			else
				Combat.ResetHitbox(otherPlayer)
			end
		end
	else
		Combat.StopHitboxLoop()
	end
end

function Combat.GetEquippedTool()
	local character = player.Character

	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end

	return nil
end

function Combat.HasTruthyStatus(object, statusNames)
	if not object then
		return false
	end

	for _, statusName in ipairs(statusNames) do
		if object:GetAttribute(statusName) == true then
			return true
		end

		local statusObject = object:FindFirstChild(statusName)
		if statusObject then
			if statusObject:IsA("BoolValue") then
				if statusObject.Value == true then
					return true
				end
			else
				return true
			end
		end
	end

	return false
end

function Combat.HasStrictTruthyStatus(object, statusNames)
	if not object then
		return false
	end

	for _, statusName in ipairs(statusNames) do
		local attribute = object:GetAttribute(statusName)
		if attribute == true or attribute == 1 or attribute == "true" then
			return true
		end
		if typeof(attribute) == "string" and string.lower(attribute) == "true" then
			return true
		end

		local statusObject = object:FindFirstChild(statusName, true)
		if statusObject then
			if statusObject:IsA("BoolValue") then
				if statusObject.Value == true then
					return true
				end
			elseif statusObject:IsA("NumberValue") or statusObject:IsA("IntValue") then
				if statusObject.Value ~= 0 then
					return true
				end
			elseif statusObject:IsA("StringValue") then
				local value = string.lower(statusObject.Value)
				if value == "true" or value == "ragdoll" or value == "ragdolled" then
					return true
				end
			end
		end
	end

	return false
end

function Combat.IsRagdolledTarget(character, humanoid, targetPlayer)
	local ragdollStatuses = {
		"Ragdoll",
		"Ragdolled",
		"IsRagdolled",
		"IsInRagdoll",
		"Ragdolling",
		"Knocked",
		"KnockedDown",
		"Downed",
		"Stunned"
	}

	if Combat.HasTruthyStatus(targetPlayer, ragdollStatuses)
		or Combat.HasTruthyStatus(character, ragdollStatuses)
		or Combat.HasTruthyStatus(humanoid, ragdollStatuses) then
		return true
	end

	if humanoid.PlatformStand or humanoid:GetState() == Enum.HumanoidStateType.Ragdoll then
		return true
	end

	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.GettingUp
end

function Combat.IsValidAutoTapTarget(targetPlayer)
	if targetPlayer == player then
		return nil, nil, nil
	end

	local character = targetPlayer.Character
	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	if Combat.IsRagdolledTarget(character, humanoid, targetPlayer) then
		return nil, nil, nil
	end

	return character, humanoid, root
end

function Combat.IsGlovePart(object)
	if not object or not object:IsA("BasePart") then
		return false
	end

	local name = Utility.NormalizeName(object.Name)
	return string.find(name, "glove")
		or string.find(name, "hand")
		or string.find(name, "handle")
end

function Combat.GetAutoTapHitboxSize(root)
	if not root then
		return Vector3.new(Combat.HitboxSize, Combat.HitboxSize, Combat.HitboxSize)
	end

	return Vector3.new(
		math.max(root.Size.X, Combat.HitboxSize),
		math.max(root.Size.Y, Combat.HitboxSize),
		math.max(root.Size.Z, Combat.HitboxSize)
	)
end

function Combat.GetAutoTapOverlapParams(parts)
	local params = OverlapParams.new()
	params.FilterDescendantsInstances = parts

	local ok = pcall(function()
		params.FilterType = Enum.RaycastFilterType.Include
	end)

	if not ok then
		pcall(function()
			params.FilterType = Enum.RaycastFilterType.Whitelist
		end)
	end

	return params
end

function Combat.GetAutoTapGlovePadding(parts)
	local padding = 2

	for _, part in ipairs(parts) do
		if part and part.Parent then
			local size = part.Size
			padding = math.max(padding, math.max(size.X, size.Y, size.Z) * 0.5)
		end
	end

	return padding
end

function Combat.GetEquippedGloveParts(tool)
	local parts = {}

	if not Combat.IsEquippedGloveTool(tool) then
		return parts
	end

	for _, object in ipairs(tool:GetDescendants()) do
		if object:IsA("BasePart") then
			table.insert(parts, object)
		end
	end

	return parts
end

function Combat.GetCharacterGloveParts(character)
	local parts = {}
	local seen = {}

	if not character then
		return parts
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and not Combat.IsKnownItemToolName(child.Name) then
			for _, object in ipairs(child:GetDescendants()) do
				if object:IsA("BasePart") and not seen[object] then
					seen[object] = true
					table.insert(parts, object)
				end
			end
		end
	end

	for _, object in ipairs(character:GetDescendants()) do
		if Combat.IsGlovePart(object) and not seen[object] then
			seen[object] = true
			table.insert(parts, object)
		end
	end

	return parts
end

function Combat.IsPartInsideHitbox(part, hitboxRoot, hitboxSize, padding)
	if not part or not part.Parent or not hitboxRoot or not hitboxRoot.Parent then
		return false
	end

	local localPosition = hitboxRoot.CFrame:PointToObjectSpace(part.Position)
	local halfSize = hitboxSize * 0.5
	local partPadding = padding or (math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5)

	return math.abs(localPosition.X) <= halfSize.X + partPadding
		and math.abs(localPosition.Y) <= halfSize.Y + partPadding
		and math.abs(localPosition.Z) <= halfSize.Z + partPadding
end

function Combat.ArePartsInsideHitbox(parts, hitboxRoot)
	if #parts == 0 or not hitboxRoot then
		return false
	end

	local hitboxSize = Combat.GetAutoTapHitboxSize(hitboxRoot)
	local padding = Combat.GetAutoTapGlovePadding(parts)

	local ok, touchingParts = pcall(function()
		return workspace:GetPartBoundsInBox(hitboxRoot.CFrame, hitboxSize + Vector3.new(padding * 2, padding * 2, padding * 2), Combat.GetAutoTapOverlapParams(parts))
	end)

	if ok and touchingParts and #touchingParts > 0 then
		return true
	end

	for _, part in ipairs(parts) do
		if Combat.IsPartInsideHitbox(part, hitboxRoot, hitboxSize, padding) then
			return true
		end
	end

	return false
end

function Combat.IsTargetInAutoTapRange(root, targetRoot)
	if not root or not targetRoot then
		return false
	end

	local targetSize = Combat.GetAutoTapHitboxSize(targetRoot)
	local targetRadius = math.max(targetSize.X, targetSize.Y, targetSize.Z) * 0.5
	local localRadius = math.max(root.Size.X, root.Size.Y, root.Size.Z) * 0.5
	local gloveReach = math.max(6, (Combat.GloveSizeScale or 1) * 4)
	local triggerDistance = targetRadius + localRadius + gloveReach

	local offset = root.Position - targetRoot.Position
	return offset:Dot(offset) <= triggerDistance * triggerDistance
end

function Combat.FindAutoGloveTapTarget()
	local tool = Combat.GetEquippedTool()
	local equippedGloveParts = Combat.GetEquippedGloveParts(tool)

	if #equippedGloveParts == 0 then
		return nil
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		local targetCharacter, _, targetRoot = Combat.IsValidAutoTapTarget(targetPlayer)

		if targetRoot and (Combat.ArePartsInsideHitbox(equippedGloveParts, targetRoot) or Combat.IsTargetInAutoTapRange(root, targetRoot)) then
			return targetPlayer
		end

		if root and targetCharacter and targetRoot and Combat.IsTargetInAutoTapRange(root, targetRoot) then
			local enemyGloveParts = Combat.GetCharacterGloveParts(targetCharacter)

			if Combat.ArePartsInsideHitbox(enemyGloveParts, root) then
				return targetPlayer
			end
		end
	end

	return nil
end

function Combat.TapEquippedGlove()
	local now = os.clock()

	if now - Combat.LastAutoGloveTap < Combat.AutoGloveTapDebounce then
		return false
	end

	local tool = Combat.GetEquippedTool()
	if not Combat.IsEquippedGloveTool(tool) then
		return false
	end

	Combat.LastAutoGloveTap = now

	pcall(function()
		tool:Activate()
	end)

	return true
end

function Combat.StartAutoGloveTap()
	if Combat.AutoGloveTapThread then
		return
	end

	Combat.AutoGloveTapThread = task.spawn(function()
		while Combat.AutoGloveTapEnabled do
			if Combat.FindAutoGloveTapTarget() then
				Combat.TapEquippedGlove()
			end

			task.wait(Combat.AutoGloveTapScanInterval)
		end

		Combat.AutoGloveTapThread = nil
	end)
end

function Combat.StopAutoGloveTap()
	if Combat.AutoGloveTapConnection then
		Combat.AutoGloveTapConnection:Disconnect()
		Combat.AutoGloveTapConnection = nil
	end
end

function Combat.SetAutoGloveTap(state, silent)
	Combat.AutoGloveTapEnabled = state == true

	if Combat.AutoGloveTapEnabled then
		Combat.StartAutoGloveTap()
		if not silent then
			createNotification("Auto Slap", "Auto Slap enabled.", "Success")
		end
	else
		Combat.StopAutoGloveTap()
		if not silent then
			createNotification("Auto Slap", "Auto Slap disabled.")
		end
	end
end

function Combat.GetSlapRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("Slap")

	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	return nil
end

function Combat.CanUseSlapAuraTarget(targetPlayer)
	if targetPlayer == player then
		return nil, nil
	end

	local localCharacter = player.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
	local targetCharacter = targetPlayer.Character
	local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

	if not localCharacter or not localRoot or not targetCharacter or not targetRoot then
		return nil, nil
	end

	if targetCharacter:FindFirstChild("Dead") then
		return nil, nil
	end

	if targetCharacter:GetAttribute("inBus") == true or localCharacter:GetAttribute("inBus") == true then
		return nil, nil
	end

	if targetCharacter:GetAttribute("inMatch") ~= true or localCharacter:GetAttribute("inMatch") ~= true then
		return nil, nil
	end

	if localCharacter:GetAttribute("Ragdolled") ~= false then
		return nil, nil
	end

	if (localRoot.Position - targetRoot.Position).Magnitude > Combat.SlapAuraRange then
		return nil, nil
	end

	return targetRoot, localRoot
end

function Combat.StartSlapAura()
	if Combat.SlapAuraThread then
		return
	end

	Combat.SlapAuraThread = task.spawn(function()
		while Combat.SlapAuraEnabled do
			local remote = Combat.GetSlapRemote()

			if remote then
				for _, targetPlayer in ipairs(Players:GetPlayers()) do
					local targetRoot = Combat.CanUseSlapAuraTarget(targetPlayer)

					if targetRoot then
						pcall(function()
							remote:FireServer(targetRoot)
						end)
					end
				end
			end

			task.wait(Combat.SlapAuraInterval)
		end

		Combat.SlapAuraThread = nil
	end)
end

function Combat.SetSlapAura(state, silent)
	Combat.SlapAuraEnabled = state == true

	if Combat.SlapAuraEnabled then
		Combat.StartSlapAura()

		if not silent then
			createNotification("Slap Aura", "Slap Aura enabled.", "Success")
		end
	else
		if not silent then
			createNotification("Slap Aura", "Slap Aura disabled.")
		end
	end
end

function Combat.ShowGloveTpSlapWarning(message)
	local now = os.clock()

	if now - Combat.LastGloveTpSlapWarning < 1.5 then
		return
	end

	Combat.LastGloveTpSlapWarning = now
	createNotification("Glove TP Slap", message, "Warning")
end

function Combat.IsEquippedGloveTool(tool)
	local character = player.Character

	if not character or not tool or not tool:IsA("Tool") or tool.Parent ~= character then
		return false
	end

	if Combat.IsKnownItemToolName(tool.Name) then
		return false
	end

	local toolName = Utility.NormalizeName(tool.Name)
	if string.find(toolName, "glove") or string.find(toolName, "slap") then
		return true
	end

	for _, object in ipairs(tool:GetDescendants()) do
		local objectName = Utility.NormalizeName(object.Name)

		if string.find(objectName, "glove") or string.find(objectName, "slap") then
			return true
		end
	end

	for _, object in ipairs(tool:GetDescendants()) do
		if object:IsA("BasePart") then
			return true
		end
	end

	return false
end

function Combat.GetNearestGloveTpSlapRoot(originPosition)
	local nearestRoot = nil
	local nearestDistance = math.huge

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		local _, humanoid, targetRoot = Combat.GetValidPlayerTarget(targetPlayer)

		if humanoid and targetRoot then
			local distance = (originPosition - targetRoot.Position).Magnitude

			if distance < nearestDistance then
				nearestDistance = distance
				nearestRoot = targetRoot
			end
		end
	end

	return nearestRoot
end

function Combat.DetachGloveTpSlapJoints(character, tool)
	local records = {}

	if not character or not tool then
		return records
	end

	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("JointInstance") or object:IsA("WeldConstraint") then
			local okPart0, part0 = pcall(function()
				return object.Part0
			end)
			local okPart1, part1 = pcall(function()
				return object.Part1
			end)

			part0 = okPart0 and part0 or nil
			part1 = okPart1 and part1 or nil

			local part0InTool = part0 and part0:IsDescendantOf(tool)
			local part1InTool = part1 and part1:IsDescendantOf(tool)

			if part0InTool ~= part1InTool then
				local record = {
					Joint = object,
					Part0 = part0,
					Part1 = part1,
					Enabled = nil,
					UsedEnabled = false
				}

				local okEnabled, enabled = pcall(function()
					return object.Enabled
				end)

				if okEnabled then
					record.Enabled = enabled
					record.UsedEnabled = pcall(function()
						object.Enabled = false
					end)
				end

				if not record.UsedEnabled then
					pcall(function()
						object.Part0 = nil
					end)
					pcall(function()
						object.Part1 = nil
					end)
				end

				table.insert(records, record)
			end
		end
	end

	return records
end

function Combat.RestoreGloveTpSlapJoints(records)
	for _, record in ipairs(records) do
		local joint = record.Joint

		if joint and joint.Parent then
			if record.UsedEnabled then
				pcall(function()
					joint.Enabled = record.Enabled
				end)
			else
				pcall(function()
					joint.Part0 = record.Part0
				end)
				pcall(function()
					joint.Part1 = record.Part1
				end)
			end
		end
	end

	if Settings and Settings.OnControlChanged then
		Settings.OnControlChanged()
	end
end

function Combat.PrepareGloveTpSlapParts(parts, root)
	local partStates = {}
	local rootCFrame = root and root.CFrame or nil

	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			table.insert(partStates, {
				Part = part,
				CFrame = part.CFrame,
				RootOffset = rootCFrame and rootCFrame:ToObjectSpace(part.CFrame) or nil,
				Anchored = part.Anchored,
				CanCollide = part.CanCollide
			})

			part.Anchored = true
			part.CanCollide = false
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	return partStates
end

function Combat.RestoreGloveTpSlapParts(partStates, root)
	for _, state in ipairs(partStates) do
		local part = state.Part

		if part and part.Parent then
			if root and root.Parent and state.RootOffset then
				part.CFrame = root.CFrame * state.RootOffset
			else
				part.CFrame = state.CFrame
			end

			part.Anchored = state.Anchored
			part.CanCollide = state.CanCollide
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function Combat.GetGloveTpSlapCenterCFrame(parts)
	local totalPosition = Vector3.zero
	local count = 0

	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			totalPosition += part.Position
			count += 1
		end
	end

	if count == 0 then
		return nil
	end

	return CFrame.new(totalPosition / count)
end

function Combat.TeleportToNearestPlayerOnGloveSlap(tool)
	local now = os.clock()

	if Combat.GloveTpSlapBusy or now - Combat.LastGloveTpSlap < Combat.GloveTpSlapDebounce then
		return
	end

	if not Combat.IsEquippedGloveTool(tool) then
		Combat.ShowGloveTpSlapWarning("Equip a glove before using Glove TP Slap.")
		return
	end

	Combat.GloveTpSlapBusy = true
	Combat.LastGloveTpSlap = now

	local teleported = Combat.TeleportToNearestPlayer()

	if not teleported then
		task.delay(Combat.GloveTpSlapDebounce, function()
			Combat.GloveTpSlapBusy = false
		end)

		return
	end

	task.delay(Combat.GloveTpSlapHoldTime, function()
		if Combat.GloveTpSlapEnabled and Combat.IsEquippedGloveTool(tool) then
			Combat.GloveTpSlapInternalActivate = true

			pcall(function()
				tool:Activate()
			end)

			task.delay(0.1, function()
				Combat.GloveTpSlapInternalActivate = false
			end)
		end
	end)

	task.delay(Combat.GloveTpSlapDebounce, function()
		Combat.GloveTpSlapBusy = false
	end)
end

function Combat.ClearGloveTpSlapHooks()
	for tool, connection in pairs(Combat.GloveTpSlapConnections) do
		if connection then
			connection:Disconnect()
		end

		Combat.GloveTpSlapConnections[tool] = nil
	end

	for _, connection in ipairs(Combat.GloveTpSlapCharacterConnections) do
		connection:Disconnect()
	end

	Combat.GloveTpSlapCharacterConnections = {}
end

function Combat.HookGloveTpSlapTool(tool)
	if not Combat.IsEquippedGloveTool(tool) or Combat.GloveTpSlapConnections[tool] then
		return
	end

	Combat.GloveTpSlapConnections[tool] = tool.Activated:Connect(function()
		if Combat.GloveTpSlapEnabled and not Combat.GloveTpSlapInternalActivate then
			Combat.TeleportToNearestPlayerOnGloveSlap(tool)
		end
	end)
end

function Combat.RefreshGloveTpSlapHooks()
	Combat.ClearGloveTpSlapHooks()

	local character = player.Character
	if not character then
		return
	end

	for _, child in ipairs(character:GetChildren()) do
		Combat.HookGloveTpSlapTool(child)
	end

	table.insert(Combat.GloveTpSlapCharacterConnections, character.ChildAdded:Connect(function(child)
		task.defer(function()
			if Combat.GloveTpSlapEnabled then
				Combat.HookGloveTpSlapTool(child)
			end
		end)
	end))

	table.insert(Combat.GloveTpSlapCharacterConnections, character.ChildRemoved:Connect(function(child)
		local connection = Combat.GloveTpSlapConnections[child]

		if connection then
			connection:Disconnect()
			Combat.GloveTpSlapConnections[child] = nil
		end
	end))
end

function Combat.StartGloveTpSlap()
	ContextActionService:BindActionAtPriority(
		Combat.GloveTpSlapActionName,
		function(_, inputState, inputObject)
			if inputState ~= Enum.UserInputState.Begin or not Combat.GloveTpSlapEnabled or Combat.GloveTpSlapInternalActivate then
				return Enum.ContextActionResult.Pass
			end

			if inputObject and inputObject.Position then
				local playerGui = player:FindFirstChildOfClass("PlayerGui")
				local ok, guiObjects = pcall(function()
					return playerGui and playerGui:GetGuiObjectsAtPosition(inputObject.Position.X, inputObject.Position.Y)
				end)

				if ok and guiObjects then
					for _, guiObject in ipairs(guiObjects) do
						if gui and (guiObject == gui or guiObject:IsDescendantOf(gui)) then
							return Enum.ContextActionResult.Pass
						end
					end
				end
			end

			local tool = Combat.GetEquippedTool()
			if not Combat.IsEquippedGloveTool(tool) then
				return Enum.ContextActionResult.Pass
			end

			Combat.TeleportToNearestPlayerOnGloveSlap(tool)
			return Enum.ContextActionResult.Sink
		end,
		false,
		4000,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)

	if not Combat.GloveTpSlapCharacterAddedConnection then
		Combat.GloveTpSlapCharacterAddedConnection = player.CharacterAdded:Connect(function()
			task.wait(0.25)

			if Combat.GloveTpSlapEnabled then
				Combat.RefreshGloveTpSlapHooks()
			end
		end)
	end

	Combat.RefreshGloveTpSlapHooks()
end

function Combat.StopGloveTpSlap()
	ContextActionService:UnbindAction(Combat.GloveTpSlapActionName)

	if Combat.GloveTpSlapCharacterAddedConnection then
		Combat.GloveTpSlapCharacterAddedConnection:Disconnect()
		Combat.GloveTpSlapCharacterAddedConnection = nil
	end

	Combat.ClearGloveTpSlapHooks()
end

function Combat.SetGloveTpSlap(state, silent)
	Combat.GloveTpSlapEnabled = state == true

	if Combat.GloveTpSlapEnabled then
		Combat.StartGloveTpSlap()
		if not silent then
			createNotification("Glove TP Slap", "Glove TP Slap enabled.", "Success")
		end
	else
		Combat.StopGloveTpSlap()
		if not silent then
			createNotification("Glove TP Slap", "Glove TP Slap disabled.")
		end
	end
end

function Combat.CreateAntiSlapPart(folder, cframe, size)
	local part = Instance.new("Part")
	part.Name = "Part"
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Parent = folder
	return part
end

function Combat.SpawnAntiSlapBox()
    if Combat.AntiSlapBoxFolder and not Combat.AntiSlapBoxFolder.Parent then
        Combat.AntiSlapBoxFolder = nil
    end

    if not Combat.AntiSlapEnabled or Combat.AntiSlapBoxFolder or os.clock() - Combat.LastAntiSlapBoxAt < 0.2 then
        return
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return
	end

	Combat.LastAntiSlapBoxAt = os.clock()

    local folder = Instance.new("Folder")
    folder.Name = "Part"
    folder.Parent = workspace
    Combat.AntiSlapBoxFolder = folder

    local center = root.CFrame
    local innerWidth = 8
    local innerHeight = 8
    local innerDepth = 8
	local thickness = 40
    local outerWidth = innerWidth + thickness * 2
    local outerHeight = innerHeight + thickness * 2
    local outerDepth = innerDepth + thickness * 2

	Combat.CreateAntiSlapPart(folder, center * CFrame.new(0, -(innerHeight / 2 + thickness / 2), 0), Vector3.new(outerWidth, thickness, outerDepth))
	Combat.CreateAntiSlapPart(folder, center * CFrame.new(0, innerHeight / 2 + thickness / 2, 0), Vector3.new(outerWidth, thickness, outerDepth))
    Combat.CreateAntiSlapPart(folder, center * CFrame.new(innerWidth / 2 + thickness / 2, 0, 0), Vector3.new(thickness, outerHeight, outerDepth))
    Combat.CreateAntiSlapPart(folder, center * CFrame.new(-(innerWidth / 2 + thickness / 2), 0, 0), Vector3.new(thickness, outerHeight, outerDepth))
    Combat.CreateAntiSlapPart(folder, center * CFrame.new(0, 0, innerDepth / 2 + thickness / 2), Vector3.new(outerWidth, outerHeight, thickness))
    Combat.CreateAntiSlapPart(folder, center * CFrame.new(0, 0, -(innerDepth / 2 + thickness / 2)), Vector3.new(outerWidth, outerHeight, thickness))
end

function Combat.ClearAntiSlapBox()
    if Combat.AntiSlapBoxFolder then
        Combat.AntiSlapBoxFolder:Destroy()
        Combat.AntiSlapBoxFolder = nil
    end
end

function Combat.IsLocalAntiSlapRagdolled(character, humanoid)
    if not character or not humanoid or humanoid.Health <= 0 then
        return false
    end

    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Running
        or state == Enum.HumanoidStateType.RunningNoPhysics
        or state == Enum.HumanoidStateType.Landed
        or state == Enum.HumanoidStateType.Climbing
        or state == Enum.HumanoidStateType.Swimming
        or state == Enum.HumanoidStateType.Seated
    then
        return false
    end

    local ragdollStatuses = {
        "Ragdoll",
        "Ragdolled",
        "IsRagdolled",
        "IsInRagdoll",
        "Ragdolling",
    }

    if Combat.HasStrictTruthyStatus(player, ragdollStatuses)
        or Combat.HasStrictTruthyStatus(character, ragdollStatuses)
        or Combat.HasStrictTruthyStatus(humanoid, ragdollStatuses)
    then
        return true
    end

    if state == Enum.HumanoidStateType.Ragdoll then
        return true
    end

    if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.FallingDown then
        for _, object in ipairs(character:GetDescendants()) do
            local objectName = string.lower(object.Name)
            if string.find(objectName, "ragdoll", 1, true) then
                return true
            end

        end
    end

    return false
end

function Combat.IsLocalAntiSlapKnockbacked(character, humanoid, root)
    if not character or not humanoid or not root or humanoid.Health <= 0 then
        return false
    end

    if os.clock() - Combat.AntiSlapEnabledAt < 0.75 then
        return false
    end

    local state = humanoid:GetState()
    local slapState = humanoid.PlatformStand
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.GettingUp

    if not slapState then
        return false
    end

    local velocity = root.AssemblyLinearVelocity or Vector3.zero
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

    return horizontalVelocity >= 38 or math.abs(velocity.Y) >= 50
end

function Combat.UpdateAntiSlapBox(character, humanoid)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local isRagdolled = Combat.AntiSlapEnabled and Combat.IsLocalAntiSlapRagdolled(character, humanoid)
    local isKnockbacked = Combat.AntiSlapEnabled and Combat.IsLocalAntiSlapKnockbacked(character, humanoid, root)

    if isKnockbacked and root and root.Parent then
        pcall(function()
            local velocity = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(0, math.min(velocity.Y, 12), 0)
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    local now = os.clock()
    local state = humanoid and humanoid:GetState()
    local recovered = state == Enum.HumanoidStateType.Running
        or state == Enum.HumanoidStateType.RunningNoPhysics
        or state == Enum.HumanoidStateType.Landed
        or state == Enum.HumanoidStateType.Climbing
        or state == Enum.HumanoidStateType.Swimming
        or state == Enum.HumanoidStateType.Seated

    if recovered then
        Combat.AntiSlapActiveUntil = 0
    end

    if not recovered and (isRagdolled or isKnockbacked) then
        Combat.AntiSlapActiveUntil = math.max(Combat.AntiSlapActiveUntil, now + 1)
    end

    local shouldBox = not recovered and (isRagdolled or isKnockbacked or now < Combat.AntiSlapActiveUntil)

    if shouldBox and (not Combat.AntiSlapWasRagdolled or (isKnockbacked and not Combat.AntiSlapBoxFolder)) then
        Combat.SpawnAntiSlapBox()
    elseif not shouldBox then
        Combat.ClearAntiSlapBox()
        Combat.AntiSlapActiveUntil = 0
    end

    Combat.AntiSlapWasRagdolled = shouldBox
end

function Combat.ClearAntiSlapConnections()
    for _, connection in ipairs(Combat.AntiSlapConnections) do
        connection:Disconnect()
	end

	Combat.AntiSlapConnections = {}
end

function Combat.HookAntiSlapCharacter()
	Combat.ClearAntiSlapConnections()

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

    if not character or not humanoid or not root then
        return
    end

    Combat.ClearAntiSlapBox()
    Combat.AntiSlapWasRagdolled = Combat.IsLocalAntiSlapRagdolled(character, humanoid)
    Combat.AntiSlapActiveUntil = 0

    table.insert(Combat.AntiSlapConnections, humanoid.StateChanged:Connect(function()
        Combat.UpdateAntiSlapBox(character, humanoid)
    end))

    for _, statusName in ipairs({ "Ragdoll", "Ragdolled", "IsRagdolled", "IsInRagdoll", "Ragdolling" }) do
        table.insert(Combat.AntiSlapConnections, character:GetAttributeChangedSignal(statusName):Connect(function()
            Combat.UpdateAntiSlapBox(character, humanoid)
        end))

        table.insert(Combat.AntiSlapConnections, humanoid:GetAttributeChangedSignal(statusName):Connect(function()
            Combat.UpdateAntiSlapBox(character, humanoid)
        end))

        table.insert(Combat.AntiSlapConnections, player:GetAttributeChangedSignal(statusName):Connect(function()
            Combat.UpdateAntiSlapBox(character, humanoid)
        end))
    end

    table.insert(Combat.AntiSlapConnections, character.DescendantAdded:Connect(function()
        Combat.UpdateAntiSlapBox(character, humanoid)
    end))

    table.insert(Combat.AntiSlapConnections, character.DescendantRemoving:Connect(function()
        task.defer(function()
            Combat.UpdateAntiSlapBox(character, humanoid)
        end)
    end))

    table.insert(Combat.AntiSlapConnections, RunService.Heartbeat:Connect(function()
        if not Combat.AntiSlapEnabled or not root.Parent then
            Combat.ClearAntiSlapBox()
            return
        end

        local now = os.clock()
        if now - Combat.LastAntiSlapCheckAt < Combat.AntiSlapCheckInterval then
            return
        end

        Combat.LastAntiSlapCheckAt = now
        Combat.UpdateAntiSlapBox(character, humanoid)
    end))
end

function Combat.SetAntiSlap(state, silent)
	Combat.AntiSlapEnabled = state == true

    if Combat.AntiSlapEnabled then
        Combat.AntiSlapWasRagdolled = false
        Combat.AntiSlapEnabledAt = os.clock()
        Combat.AntiSlapActiveUntil = 0
    Combat.HookAntiSlapCharacter()
    if not silent then
        createNotification("Anti-Ragdoll", "Anti-Ragdoll enabled.", "Success")
    end
    else
        Combat.ClearAntiSlapConnections()
        Combat.ClearAntiSlapBox()
        Combat.AntiSlapWasRagdolled = false
        Combat.AntiSlapActiveUntil = 0
    if not silent then
        createNotification("Anti-Ragdoll", "Anti-Ragdoll disabled.")
    end
    end
end

function Combat.GetPlayerRoot(targetPlayer)
	if not targetPlayer or targetPlayer == player then
		return nil
	end

	local character = targetPlayer.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

function Combat.GetPlayerHumanoid(targetPlayer)
	local character = targetPlayer.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function Combat.GetValidPlayerTarget(targetPlayer)
	if not targetPlayer or targetPlayer == player then
		return nil, nil, nil
	end

	local character = targetPlayer.Character
	if not character then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	if Combat.IsRagdolledTarget(character, humanoid, targetPlayer) then
		return nil, nil, nil
	end

	return character, humanoid, root
end

function Combat.StabilizeCharacter(character, root)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	if humanoid then
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
end

function Combat.FindStormPosition()
	local bestPosition = nil
	local bestDistance = math.huge
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = root and root.Position or Vector3.zero

	for _, object in ipairs(workspace:GetDescendants()) do
		local name = normalizeName(object.Name)

		if string.find(name, "storm") or string.find(name, "zone") or string.find(name, "circle") then
			local cframe = nil

			if object:IsA("BasePart") then
				cframe = object.CFrame
			elseif object:IsA("Model") then
				cframe = object:GetPivot()
			end

			if cframe then
				local distance = (origin - cframe.Position).Magnitude

				if distance < bestDistance then
					bestDistance = distance
					bestPosition = cframe.Position
				end
			end
		end
	end

	return bestPosition
end

function Combat.AimRootAtPosition(root, lookPosition)
	if not root or not lookPosition then
		return
	end

	local flatTarget = Vector3.new(lookPosition.X, root.Position.Y, lookPosition.Z)
	if (flatTarget - root.Position).Magnitude < 1 then
		return
	end

	root.CFrame = CFrame.lookAt(root.Position, flatTarget)
	root.AssemblyAngularVelocity = Vector3.zero
end

function Combat.AimAtStorm(root)
	Combat.AimRootAtPosition(root, Combat.FindStormPosition())
end

function Combat.GetPlayerGroundCFrame(targetRoot, character, targetCharacter)
	local excludeInstances = { character }

	if targetCharacter then
		table.insert(excludeInstances, targetCharacter)
	end

	local lookVector = targetRoot.CFrame.LookVector
	local rightVector = targetRoot.CFrame.RightVector
	local velocity = targetRoot.AssemblyLinearVelocity or Vector3.zero
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local predictedPosition = targetRoot.Position

	if horizontalVelocity.Magnitude > 1 then
		predictedPosition += horizontalVelocity.Unit * math.min(horizontalVelocity.Magnitude * 0.25, 5)
	end

	local candidatePositions = {
		predictedPosition + (rightVector * 2.2),
		predictedPosition - (rightVector * 2.2),
		predictedPosition - (lookVector * 2),
		predictedPosition + (lookVector * 1.5),
		predictedPosition,
		targetRoot.Position + (rightVector * 2),
		targetRoot.Position - (rightVector * 2),
		targetRoot.Position
	}

	for _, candidatePosition in ipairs(candidatePositions) do
		local groundCFrame = Teleport.GetGroundCFrame(candidatePosition, excludeInstances, true)

		if (groundCFrame.Position - targetRoot.Position).Magnitude <= 7 then
			return groundCFrame
		end
	end

	return Teleport.GetGroundCFrame(targetRoot.Position, excludeInstances, true)
end

function Combat.TeleportToPlayer(targetPlayer)
	if not Teleport.CanTeleport() then
		return false
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local targetCharacter, _, targetRoot = Combat.GetValidPlayerTarget(targetPlayer)

	if not root then
		createNotification("Players", "Could not find your character.", "Error")
		return false
	end

	if not targetRoot then
		createNotification("Players", "Target player is unavailable or ragdolled.", "Warning")
		return false
	end

	local targetCFrame = Combat.GetPlayerGroundCFrame(targetRoot, character, targetCharacter)

	Combat.StabilizeCharacter(character, root)
	Teleport.MoveRoot(root, targetCFrame)
	Combat.StabilizeCharacter(character, root)
	task.delay(0.15, function()
		if character.Parent and root.Parent then
			Combat.StabilizeCharacter(character, root)
		end
	end)
	Teleport.AddStrike()
	Teleport.StartFBlock()
	createNotification("Players", "Teleported to " .. targetPlayer.Name)
	return true
end

function Combat.TeleportToLowestHealthPlayer()
	local lowestPlayer = nil
	local lowestHealth = math.huge

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		local _, humanoid, targetRoot = Combat.GetValidPlayerTarget(targetPlayer)

		if humanoid and targetRoot and humanoid.Health < lowestHealth then
			lowestHealth = humanoid.Health
			lowestPlayer = targetPlayer
		end
	end

	if lowestPlayer then
		Combat.TeleportToPlayer(lowestPlayer)
	else
		createNotification("Players", "No valid lowest health player found.")
	end
end

function Combat.TeleportToNearestPlayer()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)

	if not root then
		createNotification("Players", "Could not find your character.", "Error")
		return
	end

	local nearestPlayer = nil
	local nearestDistance = math.huge

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		local _, humanoid, targetRoot = Combat.GetValidPlayerTarget(targetPlayer)

		if humanoid and targetRoot then
			local distance = (root.Position - targetRoot.Position).Magnitude

			if distance < nearestDistance then
				nearestDistance = distance
				nearestPlayer = targetPlayer
			end
		end
	end

	if nearestPlayer then
		return Combat.TeleportToPlayer(nearestPlayer)
	else
		createNotification("Players", "No valid nearest player found.")
	end

	return false
end

function Combat.SetHitboxSize(newSize)
	Combat.HitboxSize = math.clamp(newSize, Combat.HitboxMinSize, Combat.HitboxMaxSize)

	if Combat.HitboxSizeLabel then
		Combat.HitboxSizeLabel.Text = "Hitbox Size: " .. tostring(math.floor(Combat.HitboxSize + 0.5)) .. " / " .. tostring(Combat.HitboxMaxSize)
	end

	if Combat.HitboxExpanded then
		Combat.RefreshHitboxes()
	end

	if Settings and Settings.OnControlChanged then
		Settings.OnControlChanged()
	end
end

function Combat.GetGloveParts(tool)
	local parts = {}

	if not tool then
		return parts
	end

	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		table.insert(parts, handle)
	end

	for _, object in ipairs(tool:GetDescendants()) do
		if object:IsA("BasePart") and object ~= handle then
			table.insert(parts, object)
		end
	end

	return parts
end

function Combat.SaveGloveOriginal(part)
	if Combat.GloveSizeOriginals[part] then
		return
	end

	local meshes = {}
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SpecialMesh") then
			meshes[child] = child.Scale
		end
	end

	Combat.GloveSizeOriginals[part] = {
		Size = part.Size,
		Meshes = meshes
	}
end

function Combat.RestoreGloveSize()
	for part, original in pairs(Combat.GloveSizeOriginals) do
		if part and part.Parent and original then
			pcall(function()
				part.Size = original.Size
			end)

			for mesh, originalScale in pairs(original.Meshes or {}) do
				if mesh and mesh.Parent then
					pcall(function()
						mesh.Scale = originalScale
					end)
				end
			end
		end
	end

	Combat.GloveSizeOriginals = {}
end

function Combat.ApplyGloveSize()
	local scale = Combat.GloveSizeScale
	Combat.RestoreGloveSize()
	Combat.GloveSizeScale = scale

	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")

	if not tool then
		if Combat.GloveSizeLabel then
			Combat.GloveSizeLabel.Text = string.format("Glove Size: %.2fx (equip glove)", Combat.GloveSizeScale)
		end

		return false
	end

	local parts = Combat.GetGloveParts(tool)

	for _, part in ipairs(parts) do
		Combat.SaveGloveOriginal(part)

		local original = Combat.GloveSizeOriginals[part]
		if original then
			pcall(function()
				part.Size = original.Size * Combat.GloveSizeScale
			end)

			for mesh, originalScale in pairs(original.Meshes or {}) do
				if mesh and mesh.Parent then
					pcall(function()
						mesh.Scale = originalScale * Combat.GloveSizeScale
					end)
				end
			end
		end
	end

	if Combat.GloveSizeLabel then
		Combat.GloveSizeLabel.Text = string.format("Glove Size: %.2fx", Combat.GloveSizeScale)
	end

	return #parts > 0
end

function Combat.SetGloveSizeScale(newScale, showNotification)
	local steppedScale = math.floor((newScale / Combat.GloveSizeStep) + 0.5) * Combat.GloveSizeStep
	Combat.GloveSizeScale = math.clamp(steppedScale, Combat.GloveSizeMin, Combat.GloveSizeMax)

	local applied = Combat.ApplyGloveSize()

	if showNotification and not applied then
		createNotification("Glove Size", "Equip your glove first, then adjust the slider.", "Warning")
	end

	if Settings and Settings.OnControlChanged then
		Settings.OnControlChanged()
	end
end

function Combat.ClearGloveSizeHooks()
	for _, connection in ipairs(Combat.GloveSizeConnections) do
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	Combat.GloveSizeConnections = {}
end

function Combat.HookGloveSizeCharacter(character)
	Combat.ClearGloveSizeHooks()

	if not character then
		return
	end

	table.insert(Combat.GloveSizeConnections, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.05)
			Combat.ApplyGloveSize()
		end
	end))

	table.insert(Combat.GloveSizeConnections, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			local scale = Combat.GloveSizeScale
			Combat.RestoreGloveSize()
			Combat.GloveSizeScale = scale
		end
	end))
end

function Combat.RefreshGloveSizeHooks()
	Combat.HookGloveSizeCharacter(player.Character)

	if not Combat.GloveSizeCharacterAddedConnection then
		Combat.GloveSizeCharacterAddedConnection = player.CharacterAdded:Connect(function(character)
			task.wait(0.25)
			Combat.HookGloveSizeCharacter(character)
			Combat.ApplyGloveSize()
		end)
	end
end

Combat.RefreshGloveSizeHooks()

Anti = {
	HideUnderMapEnabled = false,
	AcidLavaEnabled = false,
	AcidLavaParts = {},
	StaffConnections = {},
	StaffKeywords = {
		"record", "recording", "rec", "clip", "proof", "evidence", "caught", "exposed",
		"screen record", "screenrec", "screenshot", "screen shot", "ss", "video", "vid",
		"obs", "shadowplay", "geforce", "nvidia", "stream", "streaming", "live",
		"staff", "admin", "mod", "moderator", "report", "reported", "ticket", "discord",
		"grava", "gravando", "prova", "video", "print", "aufnahme", "beweis",
		"enregistrer", "preuve", "filmer", "registrare", "prova", "录制", "录像", "録画", "証拠"
	}
}

function Anti.IsHazardName(text)
	local lowerName = string.lower(tostring(text or ""))
	local hazardWords = {
		"acid",
		"lava",
		"kill",
		"damage",
		"death",
		"deadly",
		"hazard",
		"hurt",
		"burn",
		"fire",
		"void",
		"toxic"
	}

	for _, word in ipairs(hazardWords) do
		if string.find(lowerName, word, 1, true) then
			return true
		end
	end

	return false
end

function Anti.HasHazardAssetId(object)
	local targetAssetId = "113506713"

	local function matchesAssetId(value)
		return string.find(tostring(value or ""), targetAssetId, 1, true) ~= nil
	end

	if object:IsA("MeshPart") and (matchesAssetId(object.MeshId) or matchesAssetId(object.TextureID)) then
		return true
	end

	for _, descendant in ipairs(object:GetDescendants()) do
		if descendant:IsA("SpecialMesh") and (matchesAssetId(descendant.MeshId) or matchesAssetId(descendant.TextureId)) then
			return true
		end

		if descendant:IsA("Decal") and matchesAssetId(descendant.Texture) then
			return true
		end

		if descendant:IsA("Texture") and matchesAssetId(descendant.Texture) then
			return true
		end
	end

	return false
end

function Anti.IsHazardPart(object)
	if not object or not object:IsA("BasePart") then
		return false
	end

	if Anti.HasHazardAssetId(object) then
		return true
	end

	local current = object

	while current and current ~= workspace do
		if Anti.IsHazardName(current.Name) then
			return true
		end

		current = current.Parent
	end

	return false
end

function Anti.EnableAcidLava()
	local covers = {
		{
			CFrame = CFrame.new(-113, 16, -625),
			Size = Vector3.new(155, 1, 155),
		},
		{
			CFrame = CFrame.new(-304, -21, 379),
			Size = Vector3.new(190, 1, 190),
		},
	}

	Anti.AcidLavaEnabled = true

	for index, cover in ipairs(covers) do
		local part = Anti.AcidLavaParts[index]

		if not part or not part.Parent then
			part = Instance.new("Part")
			part.Name = "Part"
			part.Anchored = true
			part.Transparency = 1
			part.CanTouch = false
			part.CanQuery = false
			part.Material = Enum.Material.SmoothPlastic
			part.Parent = workspace
			Anti.AcidLavaParts[index] = part
		end

		part.Size = cover.Size
		part.CFrame = cover.CFrame
		part.CanCollide = true
	end

	return #covers
end

function Anti.DisableAcidLava()
	Anti.AcidLavaEnabled = false

	for _, part in ipairs(Anti.AcidLavaParts) do
		if part and part.Parent then
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Transparency = 1
		end
	end
end

function Anti.ClearStaffConnections()
	for _, connection in ipairs(Anti.StaffConnections) do
		connection:Disconnect()
	end

	Anti.StaffConnections = {}
end

function Anti.GetStaffKeyword(message)
	local lowerMessage = string.lower(tostring(message or ""))

	for _, keyword in ipairs(Anti.StaffKeywords) do
		local lowerKeyword = string.lower(tostring(keyword))

		if string.find(lowerMessage, lowerKeyword, 1, true) then
			return keyword
		end
	end

	return nil
end

function Anti.HandleStaffChat(speaker, message)
	if not Anti.StaffEnabled or speaker == player then
		return
	end

	local keyword = Anti.GetStaffKeyword(message)
	if not keyword then
		return
	end

	local speakerName = speaker and speaker.Name or "Unknown"
		player:Kick("Anti-Staff detected chat from " .. speakerName .. ": " .. tostring(message) .. " [" .. tostring(keyword) .. "]")
end

function Anti.HookStaffPlayer(targetPlayer)
	if not targetPlayer or targetPlayer == player then
		return
	end

	table.insert(Anti.StaffConnections, targetPlayer.Chatted:Connect(function(message)
		Anti.HandleStaffChat(targetPlayer, message)
	end))
end

function Anti.SetStaffEnabled(state, silent)
	Anti.StaffEnabled = state == true
	Anti.ClearStaffConnections()

	if Anti.StaffEnabled then
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			Anti.HookStaffPlayer(targetPlayer)
		end

		table.insert(Anti.StaffConnections, Players.PlayerAdded:Connect(function(targetPlayer)
			Anti.HookStaffPlayer(targetPlayer)
		end))

		if not silent then
			createNotification("Anti-Staff", "Anti-Staff enabled.", "Success")
		end
	else
		if not silent then
			createNotification("Anti-Staff", "Anti-Staff disabled.")
		end
	end
end

function Anti.GetLocalRoot()
	local character = player.Character or player.CharacterAdded:Wait()
	return character and character:WaitForChild("HumanoidRootPart", 5)
end

function Anti.GetGroundReturnCFrame(root)
	local platform = UnderMapSafetyPlatform
	local character = player.Character
	local returnX = root.Position.X
	local returnZ = root.Position.Z

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excludeInstances = {}

	if character then
		table.insert(excludeInstances, character)
	end

	if platform then
		table.insert(excludeInstances, platform)
	end

	params.FilterDescendantsInstances = excludeInstances

	local origin = Vector3.new(returnX, 320, returnZ)
	local result = workspace:Raycast(origin, Vector3.new(0, -520, 0), params)

	if result and result.Position.Y > -80 and result.Position.Y < 260 then
		return CFrame.new(returnX, result.Position.Y + UNDER_MAP_SAFE_OFFSET, returnZ)
	end

	return CFrame.new(returnX, 30 + UNDER_MAP_SAFE_OFFSET, returnZ)
end

function Anti.SetHideUnderMap(state, silent)
	local root = Anti.GetLocalRoot()

	if not root then
		if not silent then
			createNotification("Hide under map", "Could not find your character.", "Error")
		end
		return
	end

	if state and movementSave then
		if not silent then
			createNotification("Hide under map", "Wait until the current auto collect movement lock ends.", "Warning")
		end

		task.defer(function()
			if UI.ToggleRefs.HideUnderMap then
				UI.ToggleRefs.HideUnderMap.Set(false, false)
			end
		end)

		return
	end

	if state and not Teleport.CanPassStabilityGate() then
		task.defer(function()
			if UI.ToggleRefs.HideUnderMap then
				UI.ToggleRefs.HideUnderMap.Set(false, false)
			end
		end)

		return
	end

	local targetCFrame = nil

	if state then
		local platform = ensureUnderMapSafetyPlatform()

		platform.CanCollide = true
		platform.CanTouch = false
		platform.CanQuery = false
		Anti.HideUnderMapEnabled = true
		targetCFrame = CFrame.new(root.Position.X, platform.Position.Y + (platform.Size.Y * 0.5) + UNDER_MAP_SAFE_OFFSET, root.Position.Z)
		if not silent then
			createNotification("Hide under map", "Moved under the map.", "Success")
		end
	else
		local platform = UnderMapSafetyPlatform

		Anti.HideUnderMapEnabled = false
		targetCFrame = Anti.GetGroundReturnCFrame(root)
		if not silent then
			createNotification("Hide under map", "Moved back above ground.", "Info")
		end

		if platform and platform.Parent then
			platform.CanCollide = false
			platform.CanTouch = false
			platform.CanQuery = false
		end
	end

	Teleport.MoveRoot(root, targetCFrame)
end

function Combat.SetupPlayerHitboxRefresh(otherPlayer)
	if not otherPlayer or otherPlayer == player then
		return
	end

	Combat.HitboxCharacterConnections = Combat.HitboxCharacterConnections or {}
	Combat.HitboxStatusConnections = Combat.HitboxStatusConnections or {}

	Combat.ClearPlayerHitboxRefresh(otherPlayer)

	local function hookCharacter(character)
		if not character then
			return
		end

		Combat.HookPlayerHitboxStatus(otherPlayer, character)

		task.delay(0.25, function()
			Combat.RefreshPlayerHitboxForRagdoll(otherPlayer)
		end)
	end

	Combat.HitboxCharacterConnections[otherPlayer] = otherPlayer.CharacterAdded:Connect(function(character)
		hookCharacter(character)
	end)

	if otherPlayer.Character then
		hookCharacter(otherPlayer.Character)
	end
end

player.CharacterAdded:Connect(function()
	task.wait(0.35)

	if Combat.AntiSlapEnabled then
		Combat.HookAntiSlapCharacter()
	end
end)

Players.PlayerAdded:Connect(function(otherPlayer)
	Combat.SetupPlayerHitboxRefresh(otherPlayer)
end)

for _, otherPlayer in ipairs(Players:GetPlayers()) do
	Combat.SetupPlayerHitboxRefresh(otherPlayer)
	Combat.ResetHitbox(otherPlayer)
end

Players.PlayerRemoving:Connect(function(otherPlayer)
	Combat.ClearPlayerHitboxRefresh(otherPlayer)
	Combat.ResetHitbox(otherPlayer)
	Combat.SavedHitboxes[otherPlayer] = nil
end)

-- New WindUI control layer.
pcall(function()
	WindUI:AddTheme({
		Name = "Neon Orchid",
		Toggle = "#33C759",
		Accent = "#CC33FF",
		Outline = "#FF66DD",
		Text = "#FFF5FB",
		PlaceholderText = "#D4A0C6",
		Background = "#180D18",
		Dialog = "#241524",
		Icon = "#FF99DD",
	})
	WindUI:AddTheme({
		Name = "Void",
		Toggle = "#33C759",
		Accent = "#6644CC",
		Outline = "#8866EE",
		Text = "#E6E0F8",
		PlaceholderText = "#8878B0",
		Background = "#06040E",
		Dialog = "#0E0A1A",
		Icon = "#6644CC",
	})
	WindUI:AddTheme({
		Name = "Sunset",
		Toggle = "#33C759",
		Accent = "#FF6B35",
		Outline = "#FF9966",
		Text = "#FFF4EE",
		PlaceholderText = "#D4A888",
		Background = "#140A06",
		Dialog = "#22120A",
		Icon = "#FF6B35",
	})
	WindUI:AddTheme({
		Name = "Matrix",
		Toggle = "#33C759",
		Accent = "#00FF41",
		Outline = "#33FF66",
		Text = "#E0FFE8",
		PlaceholderText = "#66CC77",
		Background = "#000A02",
		Dialog = "#001405",
		Icon = "#00FF41",
	})
	end)

local PREFERENCES_FOLDER = "OPSlapRoyale"
local PREFERENCES_FILE = PREFERENCES_FOLDER .. "/preferences.json"
local PREFERENCES_FALLBACK_FILE = PREFERENCES_FOLDER .. "_preferences.json"
local Preferences = {
	Toggles = {},
	Sliders = {},
	Dropdowns = {},
	Inputs = {},
	Theme = "Dark",
	TeleportMenuOpen = false,
	TeleportMenuTab = "Items",
}
local preferencesSaveQueued = false

local function ensurePreferenceTables()
	if type(Preferences.Toggles) ~= "table" then
		Preferences.Toggles = {}
	end

	if type(Preferences.Sliders) ~= "table" then
		Preferences.Sliders = {}
	end

	if type(Preferences.Dropdowns) ~= "table" then
		Preferences.Dropdowns = {}
	end

	if type(Preferences.Inputs) ~= "table" then
		Preferences.Inputs = {}
	end

	if type(Preferences.Theme) ~= "string" or Preferences.Theme == "" then
		Preferences.Theme = "Dark"
	end

	if type(Preferences.TeleportMenuTab) ~= "string" or Preferences.TeleportMenuTab == "" then
		Preferences.TeleportMenuTab = "Items"
	end

	if Preferences.TeleportMenuTab ~= "Items" and Preferences.TeleportMenuTab ~= "Players" and Preferences.TeleportMenuTab ~= "Locations" then
		Preferences.TeleportMenuTab = "Items"
	end
end

local function loadPreferences()
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return
	end

	local encoded = nil

	for _, fileName in ipairs({ PREFERENCES_FILE, PREFERENCES_FALLBACK_FILE }) do
		local ok, exists = pcall(isfile, fileName)

		if ok and exists then
			local readOk, contents = pcall(readfile, fileName)

			if readOk and type(contents) == "string" and contents ~= "" then
				encoded = contents
				break
			end
		end
	end

	if type(encoded) ~= "string" or encoded == "" then
		return
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(encoded)
	end)

	if decodeOk and type(decoded) == "table" then
		for key, value in pairs(decoded) do
			Preferences[key] = value
		end
	end

	ensurePreferenceTables()
end

local function savePreferences()
	ensurePreferenceTables()

	if type(writefile) ~= "function" then
		return
	end

	local encoded = HttpService:JSONEncode(Preferences)
	local saved = false

	local ok = pcall(function()
		if type(makefolder) == "function" then
			local folderReady = false

			if type(isfolder) == "function" then
				local ok, exists = pcall(isfolder, PREFERENCES_FOLDER)
				folderReady = ok and exists == true
			end

			if not folderReady then
				pcall(makefolder, PREFERENCES_FOLDER)
			end
		end

		writefile(PREFERENCES_FILE, encoded)
		saved = true
	end)

	if not ok or not saved then
		pcall(function()
			writefile(PREFERENCES_FALLBACK_FILE, encoded)
		end)
	end
end

local function queueSavePreferences()
	if preferencesSaveQueued then
		return
	end

	preferencesSaveQueued = true
	task.delay(0.25, function()
		preferencesSaveQueued = false
		savePreferences()
	end)
end

local function getSavedToggle(key, defaultValue)
	local saved = Preferences.Toggles[key]

	if saved == nil then
		return defaultValue == true
	end

	return saved == true
end

local function getSavedSlider(key, defaultValue)
	local saved = tonumber(Preferences.Sliders[key])
	return saved or defaultValue
end

local function getSavedDropdown(key, defaultValue, values)
	local saved = Preferences.Dropdowns[key]

	if saved ~= nil then
		local savedText = tostring(saved)

		for _, value in ipairs(values or {}) do
			if tostring(value) == savedText then
				return saved
			end
		end
	end

	return defaultValue
end

loadPreferences()
ensurePreferenceTables()
Preferences.Toggles.AutoCollect = false
Preferences.Toggles.HideUnderMap = false
Preferences.Toggles.AutoPickup = false
Preferences.Toggles.AutoPermanentItems = false
queueSavePreferences()

Teleport.CustomSettingDefinitions = {
	CustomStrikes = {
		Default = Teleport.DefaultMaxStrikes,
		Min = 1,
		Max = 50,
		Integer = true,
	},
	CustomTPDebounce = {
		Default = Teleport.DefaultDebounce,
		Min = 0,
		Max = 30,
	},
	CustomFLock = {
		Default = Teleport.DefaultPostFLock,
		Min = 0,
		Max = 60,
	},
}

function Teleport.GetCustomSettingValue(key)
	ensurePreferenceTables()

	local definition = Teleport.CustomSettingDefinitions[key]

	if not definition then
		return nil
	end

	local number = tonumber(Preferences.Inputs[key])

	if not number then
		return definition.Default
	end

	number = math.clamp(number, definition.Min, definition.Max)

	if definition.Integer then
		number = math.floor(number + 0.5)
	end

	return number
end

function Teleport.HasCustomSetting(key)
	ensurePreferenceTables()
	return tonumber(Preferences.Inputs[key]) ~= nil
end

function Teleport.GetCustomFLockDuration(defaultDuration)
	if Teleport.HasCustomSetting("CustomFLock") then
		return Teleport.GetCustomSettingValue("CustomFLock") or Teleport.DefaultPostFLock
	end

	return tonumber(defaultDuration) or Teleport.PostFLock or Teleport.DefaultPostFLock
end

function Teleport.GetEarlyAutoCollectResumeDelay()
	return (Teleport.GetCustomFLockDuration(10) or 10) + 1
end

function Teleport.ApplyCustomSettings()
	Teleport.MaxStrikes = Teleport.GetCustomSettingValue("CustomStrikes") or Teleport.DefaultMaxStrikes
	Teleport.Debounce = Teleport.GetCustomSettingValue("CustomTPDebounce") or Teleport.DefaultDebounce
	Teleport.PostFLock = Teleport.GetCustomSettingValue("CustomFLock") or Teleport.DefaultPostFLock
	Items.TeleportDebounce = Teleport.Debounce
end

function Teleport.SetCustomSetting(key, rawValue, skipSave)
	ensurePreferenceTables()

	local definition = Teleport.CustomSettingDefinitions[key]

	if not definition then
		return false
	end

	local text = tostring(rawValue or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local changed = false

	if text == "" then
		changed = Preferences.Inputs[key] ~= nil
		Preferences.Inputs[key] = nil
	else
		local number = tonumber(text)

		if not number then
			return false
		end

		number = math.clamp(number, definition.Min, definition.Max)

		if definition.Integer then
			number = math.floor(number + 0.5)
		end

		local savedText = tostring(number)
		changed = Preferences.Inputs[key] ~= savedText
		Preferences.Inputs[key] = savedText
	end

	Teleport.ApplyCustomSettings()

	if changed and not skipSave then
		queueSavePreferences()
	end

	return true
end

function Teleport.ResetCustomSettings(skipSave)
	ensurePreferenceTables()
	Preferences.Inputs.CustomStrikes = nil
	Preferences.Inputs.CustomTPDebounce = nil
	Preferences.Inputs.CustomFLock = nil
	Teleport.ApplyCustomSettings()

	if not skipSave then
		queueSavePreferences()
	end
end

Teleport.ApplyCustomSettings()

function Teleport.WaitForFullGameLoad()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	local character = player.Character or player.CharacterAdded:Wait()

	character:WaitForChild("HumanoidRootPart", 15)
	character:WaitForChild("Humanoid", 15)

	for _ = 1, 60 do
		if workspace.CurrentCamera then
			break
		end

		task.wait(0.1)
	end

	task.wait(1)
end

function Teleport.ReadCurrentPing()
	local candidates = {}

	local function addCandidate(milliseconds)
		milliseconds = tonumber(milliseconds)

		if milliseconds and milliseconds >= 1 and milliseconds <= 500 then
			table.insert(candidates, milliseconds)
		end
	end

	local function numberFromText(text)
		if text == nil then
			return nil, ""
		end

		local textValue = tostring(text)
		return tonumber(textValue:match("%d+%.?%d*")), string.lower(textValue)
	end

	local function normalizeStatPing(value, text)
		local number = tonumber(value)
		local textNumber, lowerText = numberFromText(text)

		if textNumber then
			number = textNumber
		end

		if not number or number <= 0 then
			return nil
		end

		if string.find(lowerText, "ms", 1, true) then
			return number
		end

		if string.find(lowerText, "sec", 1, true) or string.match(lowerText, "%ds") then
			return number * 1000
		end

		if number <= 10 then
			return number * 1000
		end

		return number
	end

	local networkSamples = {}

	if player then
		for sampleIndex = 1, 5 do
			local ok, rawPing = pcall(function()
				return player:GetNetworkPing()
			end)

			local rawNumber = tonumber(rawPing)

			if ok and rawNumber and rawNumber > 0 then
				local milliseconds = rawNumber <= 10 and (rawNumber * 1000) or rawNumber

				if milliseconds >= 1 and milliseconds <= 500 then
					table.insert(networkSamples, milliseconds)
				end
			end

			if sampleIndex < 5 then
				task.wait(0.04)
			end
		end
	end

	if #networkSamples > 0 then
		table.sort(networkSamples)
		addCandidate(networkSamples[math.ceil(#networkSamples / 2)])
	end

	local ok, stats = pcall(function()
		return game:GetService("Stats")
	end)

	if ok and stats then
		local network = stats:FindFirstChild("Network")
		local serverStats = network and network:FindFirstChild("ServerStatsItem")

		if serverStats then
			for _, statName in ipairs({ "Data Ping", "Ping", "Server Ping" }) do
				local statObject = serverStats:FindFirstChild(statName)

				if statObject then
					local valueString = nil
					local value = nil

					pcall(function()
						valueString = statObject:GetValueString()
					end)

					pcall(function()
						value = statObject:GetValue()
					end)

					addCandidate(normalizeStatPing(value, valueString))
				end
			end
		end
	end

	if #candidates == 0 then
		return nil
	end

	table.sort(candidates)
	return candidates[1]
end

function Teleport.GetOptimizedCooldownSettingsForPing(ping)
	ping = tonumber(ping) or 131

	if ping <= 80 then
		return {
			FLock = 0.1,
			TPDebounce = 0.1,
			MaxStrikes = 10,
		}
	elseif ping <= 130 then
		return {
			FLock = 0.2,
			TPDebounce = 0.3,
			MaxStrikes = 5,
		}
	end

	return {
		FLock = 0.5,
		TPDebounce = 1,
		MaxStrikes = 4,
	}
end

function Teleport.ApplyAutoOptimizedCooldownSettings(ping, silent)
	local settings = Teleport.GetOptimizedCooldownSettingsForPing(ping)

	Teleport.SetCustomSetting("CustomStrikes", settings.MaxStrikes, true)
	Teleport.SetCustomSetting("CustomTPDebounce", settings.TPDebounce, true)
	Teleport.SetCustomSetting("CustomFLock", settings.FLock, true)
	queueSavePreferences()

	if UI.SyncCustomSettingInputVisuals then
		UI.SyncCustomSettingInputVisuals()
	else
		task.defer(function()
			if UI.SyncCustomSettingInputVisuals then
				UI.SyncCustomSettingInputVisuals()
			end
		end)
	end

	if not silent then
		createNotification(
			"Cooldown settings",
			"Optimized for " .. tostring(math.floor((tonumber(ping) or 131) + 0.5)) .. " ms ping.",
			"Success"
		)
	end
end

function Teleport.RunAutoOptimizeCooldownSettings(silent)
	if Teleport.AutoOptimizeCooldownApplying then
		if not silent then
			createNotification("Cooldown settings", "Already checking ping.", "Info")
		end

		return
	end

	Teleport.AutoOptimizeCooldownApplying = true

	task.spawn(function()
		Teleport.WaitForFullGameLoad()

		local ping = Teleport.ReadCurrentPing() or 131

		Teleport.ApplyAutoOptimizedCooldownSettings(ping, silent)
		Teleport.AutoOptimizeCooldownApplying = false
	end)

	if not silent then
		createNotification("Cooldown settings", "Checking ping and optimizing settings.", "Info")
	end
end

local WindUIWindow = WindUI:CreateWindow({
	Title = "Le Fairs Le Goopa",
	Icon = "crown",
	Author = "Le Fairs Le Goopa",
	Folder = "LeFairsLeGoopa",
	Size = UDim2.fromOffset(580, 460),
	ToggleKey = Enum.KeyCode.T,
	Transparent = true,
	Theme = Preferences.Theme or "Dark",
	SideBarWidth = 200,
})

local TabMain = WindUIWindow:Tab({ Title = "Main", Icon = "star" })
local TabItems = WindUIWindow:Tab({ Title = "Items", Icon = "box" })
local TabTeleports = WindUIWindow:Tab({ Title = "Teleports", Icon = "map-pin" })
local TabCombat = WindUIWindow:Tab({ Title = "Combat", Icon = "swords" })
local TabBETA = WindUIWindow:Tab({ Title = "BETA", Icon = "flask-conical" })
local TabSafety = WindUIWindow:Tab({ Title = "Safety", Icon = "shield" })
local TabSettings = WindUIWindow:Tab({ Title = "Settings", Icon = "settings" })

local _windToggles = {}
local _windSliders = {}
local _windDropdowns = {}
local TOGGLE_ON_COLOR = Color3.fromRGB(76, 195, 80)

local function safeTask(fn, ...)
	if type(fn) ~= "function" then
		return
	end

	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(function()
			fn(table.unpack(args, 1, args.n))
		end)

		if not ok then
			createNotification("OP Slap Royale", tostring(err), "Error", nil, 5, true)
		end
	end)
end

local function waitForStartupCharacterReady(timeout)
	local deadline = os.clock() + (timeout or 6)

	while os.clock() < deadline do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root then
			return true
		end

		task.wait(0.1)
	end

	return false
end

local function unwrapDropdownValue(value)
	if type(value) == "table" then
		return value.Value or value.Title or value.Name or value[1]
	end

	return value
end

local function normalizeToggleValue(value, fallback)
	if type(value) == "table" then
		local nested = value.Value

		if nested == nil then
			nested = value.State
		end

		if nested == nil then
			nested = value.Checked
		end

		if nested ~= nil then
			return normalizeToggleValue(nested, fallback)
		end

		return fallback == true
	end

	if type(value) == "string" then
		local lowered = string.lower(value)

		if lowered == "true" or lowered == "on" or lowered == "enabled" then
			return true
		end

		if lowered == "false" or lowered == "off" or lowered == "disabled" then
			return false
		end
	end

	if value == nil then
		return fallback == true
	end

	return value == true
end

local function trySetControl(control, value)
	if not control then
		return
	end

	local desired = value == true

	local function setKnownFields()
		pcall(function()
			if type(control.Value) ~= "function" then
				control.Value = desired
			end
		end)
		pcall(function()
			if type(control.State) ~= "function" then
				control.State = desired
			end
		end)
		pcall(function()
			if type(control.Checked) ~= "function" then
				control.Checked = desired
			end
		end)
		pcall(function()
			if type(control.Options) == "table" then
				control.Options.Value = desired
				control.Options.Default = desired
			end
		end)
	end

	local setMethod = control.Set

	if type(setMethod) == "function" then
		pcall(setMethod, control, desired)
	end

	setKnownFields()
end

local function AddButton(tab, title, desc, icon, callback)
	return tab:Button({
		Title = title,
		Desc = desc,
		Icon = icon or "",
		Callback = function()
			safeTask(callback)
		end,
	})
end

local function AddToggle(tab, title, desc, default, callback, key)
	local prefKey = key or title
	local ref = { Value = getSavedToggle(prefKey, default), Control = nil }
	local suppress = false
	local suppressUntil = 0
	local toggleReady = false
	local syncVisual = nil

	local toggle = tab:Toggle({
		Title = title,
		Desc = desc,
		Color = TOGGLE_ON_COLOR,
		Value = ref.Value,
		Default = ref.Value,
		Callback = function(value)
			if suppress or not toggleReady then
				return
			end

			local nextValue = normalizeToggleValue(value, ref.Value)

			if os.clock() < suppressUntil and nextValue == ref.Value then
				return
			end

			ref.Value = nextValue
			Preferences.Toggles[prefKey] = ref.Value
			queueSavePreferences()

			if syncVisual then
				syncVisual()
			end

			safeTask(callback, ref.Value)
		end,
	})

	ref.Control = toggle

	local function applyVisual()
		suppress = true
		suppressUntil = os.clock() + 0.12
		trySetControl(toggle, ref.Value)
		suppress = false
	end

	local function syncActualFeatureState()
		if not UI.GetRecommendedFeatureState then
			return
		end

		local actual = UI.GetRecommendedFeatureState(prefKey)

		if actual ~= nil and actual ~= ref.Value then
			ref.Value = actual == true
			Preferences.Toggles[prefKey] = ref.Value
			queueSavePreferences()
			syncVisual()
		end
	end

	syncVisual = function()
		applyVisual()

		for _, delaySeconds in ipairs({ 0.05, 0.15, 0.35, 0.75 }) do
			task.delay(delaySeconds, function()
				applyVisual()
			end)
		end
	end

	task.defer(function()
		toggleReady = true
		syncVisual()

		if ref.Value then
			task.spawn(function()
				waitForStartupCharacterReady(6)

				if ref.Value then
					safeTask(callback, true, true)
				end

				task.delay(0.75, syncActualFeatureState)
				task.delay(1.5, syncActualFeatureState)
			end)
		end
	end)

	function ref.Set(value, fireCallback, ...)
		ref.Value = normalizeToggleValue(value, ref.Value)
		Preferences.Toggles[prefKey] = ref.Value
		queueSavePreferences()
		syncVisual()

		if fireCallback ~= false then
			safeTask(callback, ref.Value, ...)
		end
	end

	function ref.Get()
		return ref.Value
	end

	function ref.Sync()
		syncVisual()
	end

	_windToggles[title] = ref

	if key then
		UI.ToggleRefs[key] = ref
	end

	return toggle, ref
end

local function syncAllToggleVisuals()
	for _, ref in pairs(_windToggles) do
		if type(ref) == "table" and type(ref.Sync) == "function" then
			ref.Sync()
		end
	end

	for _, ref in pairs(UI.ToggleRefs) do
		if type(ref) == "table" and type(ref.Sync) == "function" then
			ref.Sync()
		end
	end
end

local function AddSlider(tab, title, desc, minValue, maxValue, defaultValue, step, callback, key)
	local prefKey = key or title
	local savedDefault = math.clamp(getSavedSlider(prefKey, defaultValue), minValue, maxValue)
	local sliderReady = false
	local slider = tab:Slider({
		Title = title,
		Desc = desc,
		Step = step or 1,
		Value = {
			Min = minValue,
			Max = maxValue,
			Default = savedDefault,
		},
		Callback = function(value)
			if not sliderReady then
				return
			end

			local numericValue = tonumber(value) or savedDefault
			Preferences.Sliders[prefKey] = numericValue
			queueSavePreferences()
			safeTask(callback, numericValue)
		end,
	})

	task.defer(function()
		sliderReady = true

		if Preferences.Sliders[prefKey] ~= nil then
			safeTask(callback, savedDefault, true)
		end
	end)

	_windSliders[title] = slider
	return slider
end

function UI.SetInputVisual(input, value)
	if input and type(input.Set) == "function" then
		pcall(function()
			input:Set(tostring(value or ""))
		end)
	end
end

function UI.AddInput(tab, title, desc, placeholder, callback, key)
	local prefKey = key or title
	local savedValue = Preferences.Inputs[prefKey]
	local inputReady = false
	local input = tab:Input({
		Title = title,
		Desc = desc,
		Value = savedValue ~= nil and tostring(savedValue) or "",
		InputIcon = "hash",
		Type = "Input",
		Placeholder = tostring(placeholder or ""),
		Callback = function(value)
			if not inputReady then
				return
			end

			safeTask(callback, value)
		end,
	})

	task.defer(function()
		inputReady = true
	end)

	UI.InputRefs[prefKey] = input
	return input
end

function UI.SyncCustomSettingInputVisuals()
	UI.SetInputVisual(UI.InputRefs.CustomStrikes, Preferences.Inputs.CustomStrikes)
	UI.SetInputVisual(UI.InputRefs.CustomTPDebounce, Preferences.Inputs.CustomTPDebounce)
	UI.SetInputVisual(UI.InputRefs.CustomFLock, Preferences.Inputs.CustomFLock)
end

local function AddDropdown(tab, title, desc, values, defaultValue, callback, key)
	local prefKey = key or title
	local savedDefault = getSavedDropdown(prefKey, defaultValue, values)
	local dropdownReady = false
	local dropdown = tab:Dropdown({
		Title = title,
		Desc = desc,
		Values = values,
		Value = savedDefault,
		Callback = function(value)
			if not dropdownReady then
				return
			end

			local selectedValue = unwrapDropdownValue(value)
			Preferences.Dropdowns[prefKey] = selectedValue
			queueSavePreferences()
			safeTask(callback, selectedValue)
		end,
	})

	task.defer(function()
		dropdownReady = true
	end)

	_windDropdowns[title] = dropdown
	return dropdown
end

function Combat.SetHitboxExpanded(state)
	Combat.HitboxExpanded = state == true
	Combat.RefreshHitboxes()
end

function Combat.SetHitboxVisible(state)
	Combat.HitboxVisible = state == true
	Combat.RefreshHitboxes()
end

function Anti.SetAcidLava(state)
	if state then
		local count = Anti.EnableAcidLava()
		createNotification("Anti-Acid & Lava", "Enabled " .. tostring(count) .. " safety covers.", "Success")
	else
		Anti.DisableAcidLava()
		createNotification("Anti-Acid & Lava", "Disabled.")
	end
end

UI.AutoRejoinEnabled = false
UI.AutoRejoinConnections = {}
UI.AutoRejoinBusy = false
UI.AutoRejoinPlaceId = 9426795465
UI.AutoRejoinServerPageLimit = 4

function UI.DisconnectAutoRejoin()
	for _, connection in ipairs(UI.AutoRejoinConnections) do
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	table.clear(UI.AutoRejoinConnections)
end

function UI.FetchAutoRejoinServers(placeId, cursor)
	local url = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Desc&limit=100"

	if type(cursor) == "string" and cursor ~= "" then
		local encodedCursor = cursor
		pcall(function()
			encodedCursor = HttpService:UrlEncode(cursor)
		end)
		url = url .. "&cursor=" .. tostring(encodedCursor)
	end

	local body = nil
	local ok, result = pcall(function()
		return game:HttpGet(url)
	end)

	if ok and type(result) == "string" and result ~= "" then
		body = result
	else
		local requestFunction = nil

		if type(syn) == "table" and type(syn.request) == "function" then
			requestFunction = syn.request
		elseif type(http) == "table" and type(http.request) == "function" then
			requestFunction = http.request
		elseif type(http_request) == "function" then
			requestFunction = http_request
		elseif type(request) == "function" then
			requestFunction = request
		end

		if type(requestFunction) == "function" then
			local requestOk, response = pcall(function()
				return requestFunction({
					Url = url,
					Method = "GET",
				})
			end)

			if requestOk and type(response) == "table" then
				body = response.Body or response.body
			end
		end
	end

	if type(body) ~= "string" or body == "" then
		return nil
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)

	if decodeOk and type(decoded) == "table" then
		return decoded
	end

	return nil
end

function UI.GetHighestPlayerAutoRejoinServer(placeId)
	local bestServerId = nil
	local bestPlaying = -1
	local bestMaxPlayers = 0
	local cursor = nil

	for _ = 1, UI.AutoRejoinServerPageLimit do
		local decoded = UI.FetchAutoRejoinServers(placeId, cursor)

		if type(decoded) ~= "table" then
			break
		end

		for _, server in ipairs(decoded.data or {}) do
			local serverId = tostring(server.id or "")
			local playing = tonumber(server.playing) or 0
			local maxPlayers = tonumber(server.maxPlayers) or 0

			if serverId ~= "" and serverId ~= game.JobId and playing < 30 and (maxPlayers <= 0 or playing < maxPlayers) and playing > bestPlaying then
				bestServerId = serverId
				bestPlaying = playing
				bestMaxPlayers = maxPlayers
			end
		end

		if bestServerId then
			break
		end

		cursor = decoded.nextPageCursor

		if type(cursor) ~= "string" or cursor == "" then
			break
		end
	end

	return bestServerId, bestPlaying, bestMaxPlayers
end

function UI.TeleportAutoRejoin(reason)
	if UI.AutoRejoinBusy then
		return
	end

	UI.AutoRejoinBusy = true
	createNotification("Auto Play Again", "Finding fullest server after " .. tostring(reason) .. ".", "Info")

	task.spawn(function()
		local placeId = tonumber(UI.AutoRejoinPlaceId) or game.PlaceId
		local serverId, playing, maxPlayers = UI.GetHighestPlayerAutoRejoinServer(placeId)
		local joinedServer = false

		if serverId then
			createNotification("Auto Play Again", "Joining fullest server (" .. tostring(playing) .. "/" .. tostring(maxPlayers) .. ").", "Info")
			joinedServer = pcall(function()
				Services.TeleportService:TeleportToPlaceInstance(placeId, serverId, player)
			end)
		end

		if not joinedServer then
			createNotification("Auto Play Again", "Joining place " .. tostring(placeId) .. ".", "Info")
			pcall(function()
				Services.TeleportService:Teleport(placeId, player)
			end)
		end

		task.wait(3)
		UI.AutoRejoinBusy = false
	end)
end

function UI.HookAutoRejoinCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	table.insert(UI.AutoRejoinConnections, humanoid.Died:Connect(function()
		if UI.AutoRejoinEnabled then
			UI.TeleportAutoRejoin("death")
		end
	end))
end

function UI.SetAutoRejoin(state, silent)
	UI.AutoRejoinEnabled = state == true
	UI.DisconnectAutoRejoin()

	if UI.AutoRejoinEnabled then
		UI.AutoRejoinBusy = false
		UI.HookAutoRejoinCharacter(player.Character)

		table.insert(UI.AutoRejoinConnections, player.CharacterAdded:Connect(function(character)
			task.wait(0.3)

			if UI.AutoRejoinEnabled then
				UI.HookAutoRejoinCharacter(character)
			end
		end))

		pcall(function()
			table.insert(UI.AutoRejoinConnections, Services.GuiService.ErrorMessageChanged:Connect(function()
				if UI.AutoRejoinEnabled then
					UI.TeleportAutoRejoin("disconnect")
				end
			end))
		end)

		if not silent then
			createNotification("Auto Play Again", "Auto play again enabled.", "Success")
		end
	else
		UI.AutoRejoinBusy = false

		if not silent then
			createNotification("Auto Play Again", "Auto play again disabled.")
		end
	end
end

function UI.DoInfiniteJump()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then
		return
	end

	pcall(function()
		humanoid.Jump = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end)
end

function UI.StartInfiniteJump()
	if UI.InfiniteJumpConnection then
		return
	end

	UI.InfiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
		if UI.InfiniteJumpEnabled then
			UI.DoInfiniteJump()
		end
	end)
end

function UI.StopInfiniteJump()
	if UI.InfiniteJumpConnection then
		UI.InfiniteJumpConnection:Disconnect()
		UI.InfiniteJumpConnection = nil
	end
end

function UI.SetInfiniteJump(state, silent)
	UI.InfiniteJumpEnabled = state == true

	if UI.InfiniteJumpEnabled then
		UI.StartInfiniteJump()

		if not silent then
			createNotification("Infinite Jump", "Infinite Jump enabled.", "Success")
		end
	else
		UI.StopInfiniteJump()

		if not silent then
			createNotification("Infinite Jump", "Infinite Jump disabled.")
		end
	end
end

local ESP = {
	Enabled = false,
	Connections = {},
	Folder = nil,
	Billboards = {},
	Highlights = {},
	StatObjectCache = {},
	UpdateInterval = 1,
}

function ESP.EnsureFolder()
	if ESP.Folder and ESP.Folder.Parent then
		return ESP.Folder
	end

	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	ESP.Folder = Instance.new("Folder")
	ESP.Folder.Name = "Part"
	ESP.Folder.Parent = playerGui or gui or game:GetService("CoreGui")
	return ESP.Folder
end

function ESP.GetStatValue(targetPlayer, statNames)
	local cache = ESP.StatObjectCache[targetPlayer]

	if cache then
		for _, statName in ipairs(statNames) do
			local cachedStat = cache[statName]

			if cachedStat and cachedStat.Parent and cachedStat:IsA("ValueBase") then
				return cachedStat.Value
			end
		end
	end

	local leaderstats = targetPlayer:FindFirstChild("leaderstats")

	if leaderstats then
		for _, statName in ipairs(statNames) do
			local stat = leaderstats:FindFirstChild(statName)

			if stat and stat:IsA("ValueBase") then
				ESP.StatObjectCache[targetPlayer] = ESP.StatObjectCache[targetPlayer] or {}
				ESP.StatObjectCache[targetPlayer][statName] = stat
				return stat.Value
			end
		end
	end

	for _, statName in ipairs(statNames) do
		local attribute = targetPlayer:GetAttribute(statName)

		if attribute ~= nil then
			return attribute
		end
	end

	local character = targetPlayer.Character

	if character then
		for _, statName in ipairs(statNames) do
			local attribute = character:GetAttribute(statName)

			if attribute ~= nil then
				return attribute
			end
		end

		for _, object in ipairs(character:GetDescendants()) do
			for _, statName in ipairs(statNames) do
				if normalizeName(object.Name) == normalizeName(statName) and object:IsA("ValueBase") then
					ESP.StatObjectCache[targetPlayer] = ESP.StatObjectCache[targetPlayer] or {}
					ESP.StatObjectCache[targetPlayer][statName] = object
					return object.Value
				end
			end
		end
	end

	for _, object in ipairs(targetPlayer:GetDescendants()) do
		for _, statName in ipairs(statNames) do
			if normalizeName(object.Name) == normalizeName(statName) and object:IsA("ValueBase") then
				ESP.StatObjectCache[targetPlayer] = ESP.StatObjectCache[targetPlayer] or {}
				ESP.StatObjectCache[targetPlayer][statName] = object
				return object.Value
			end
		end
	end

	return "?"
end

function ESP.GetSpeed(targetPlayer)
	local statSpeed = ESP.GetStatValue(targetPlayer, { "Speed", "WalkSpeed" })

	if statSpeed ~= "?" then
		return statSpeed
	end

	local character = targetPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		return math.floor(humanoid.WalkSpeed)
	end

	return "?"
end

function ESP.Remove(targetPlayer)
	local existingBillboard = ESP.Billboards[targetPlayer]

	if existingBillboard then
		existingBillboard:Destroy()
	end

	ESP.Billboards[targetPlayer] = nil

	local existingHighlight = ESP.Highlights[targetPlayer]

	if existingHighlight then
		existingHighlight:Destroy()
	end

	ESP.Highlights[targetPlayer] = nil
	ESP.StatObjectCache[targetPlayer] = nil
end

function ESP.Create(targetPlayer)
	if targetPlayer == player then
		return
	end

	ESP.Remove(targetPlayer)

	local character = targetPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not character or not head or not humanoid or humanoid.Health <= 0 then
		ESP.Remove(targetPlayer)
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "Part"
	highlight.FillColor = Color3.fromRGB(0, 170, 255)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.75
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character
	ESP.Highlights[targetPlayer] = highlight

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Part"
	billboard.Size = UDim2.fromOffset(360, 170)
	billboard.StudsOffset = Vector3.new(0, 5.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 10000
	billboard.Adornee = head
	billboard.Parent = ESP.EnsureFolder()
	ESP.Billboards[targetPlayer] = billboard

	local label = Instance.new("TextLabel")
	label.Name = "Part"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.15
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 28
	label.TextWrapped = true
	label.RichText = true
	label.Parent = billboard

	task.spawn(function()
		while ESP.Enabled and billboard.Parent do
			local liveCharacter = targetPlayer.Character
			local liveHumanoid = liveCharacter and liveCharacter:FindFirstChildOfClass("Humanoid")

			if not liveHumanoid or liveHumanoid.Health <= 0 then
				ESP.Remove(targetPlayer)
				break
			end

			local health = math.floor(liveHumanoid.Health) .. "/" .. math.floor(liveHumanoid.MaxHealth)
			local kills = ESP.GetStatValue(targetPlayer, { "Kills", "Kill", "KOs" })
			local power = ESP.GetStatValue(targetPlayer, { "Power", "Strength", "Slaps" })
			local speed = ESP.GetSpeed(targetPlayer)

			label.Text =
				'<font color="rgb(255,255,255)">' .. targetPlayer.Name .. '</font>'
				.. '\n<font color="rgb(80,255,120)">Health: ' .. tostring(health) .. '</font>'
				.. '\n<font color="rgb(80,170,255)">Kills: ' .. tostring(kills) .. '</font>'
				.. '\n<font color="rgb(255,80,80)">Strength: ' .. tostring(power) .. '</font>'
				.. '\n<font color="rgb(255,235,70)">Speed: ' .. tostring(speed) .. '</font>'

			task.wait(ESP.UpdateInterval or 1)
		end
	end)
end

function ESP.Refresh()
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if ESP.Enabled then
			ESP.Create(targetPlayer)
		else
			ESP.Remove(targetPlayer)
		end
	end
end

function ESP.ClearConnections()
	for _, connection in ipairs(ESP.Connections) do
		connection:Disconnect()
	end

	ESP.Connections = {}
end

function ESP.Enable()
	if ESP.Enabled then
		return
	end

	ESP.Enabled = true
	ESP.EnsureFolder()
	ESP.Refresh()

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		table.insert(ESP.Connections, targetPlayer.CharacterAdded:Connect(function()
			task.wait(0.5)

			if ESP.Enabled then
				ESP.Create(targetPlayer)
			end
		end))
	end

	table.insert(ESP.Connections, Players.PlayerAdded:Connect(function(targetPlayer)
		table.insert(ESP.Connections, targetPlayer.CharacterAdded:Connect(function()
			task.wait(0.5)

			if ESP.Enabled then
				ESP.Create(targetPlayer)
			end
		end))
	end))

	table.insert(ESP.Connections, Players.PlayerRemoving:Connect(function(targetPlayer)
		ESP.Remove(targetPlayer)
	end))
end

function ESP.Disable()
	ESP.Enabled = false
	ESP.ClearConnections()

	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		ESP.Remove(targetPlayer)
	end

	if ESP.Folder then
		for _, item in ipairs(ESP.Folder:GetChildren()) do
			item:Destroy()
		end
	end
end

function UI.SetPlayerStatsESP(state, silent)
	if state then
		ESP.Enable()

		if not silent then
			createNotification("ESP", "Player Stats ESP enabled.", "Success")
		end
	else
		ESP.Disable()

		if not silent then
			createNotification("ESP", "Player Stats ESP disabled.")
		end
	end
end

local ItemESP = {
	Enabled = false,
	Folder = nil,
	Rows = {},
	Thread = nil,
	RefreshDelay = 2.5,
	KnownNameLookup = {},
}

ItemESP.Colors = {
	Default = Color3.fromRGB(235, 245, 255),
	TruePower = Color3.fromRGB(255, 255, 255),
	Power = Color3.fromRGB(255, 72, 86),
	Speed = Color3.fromRGB(255, 226, 82),
	Jump = Color3.fromRGB(92, 170, 255),
	Heal = Color3.fromRGB(98, 255, 142),
	Defense = Color3.fromRGB(96, 245, 255),
	Utility = Color3.fromRGB(190, 116, 255),
	Danger = Color3.fromRGB(255, 145, 72),
}

ItemESP.ColorLookup = {
	[normalizeName("True Power")] = ItemESP.Colors.TruePower,
	[normalizeName("Potion of Strength")] = ItemESP.Colors.Power,
	[normalizeName("Bull's Essence")] = ItemESP.Colors.Power,
	[normalizeName("Sphere of Fury")] = ItemESP.Colors.Power,
	[normalizeName("Speed Potion")] = ItemESP.Colors.Speed,
	[normalizeName("Boba")] = ItemESP.Colors.Speed,
	[normalizeName("Frog Potion")] = ItemESP.Colors.Jump,
	[normalizeName("Healing Potion")] = ItemESP.Colors.Heal,
	[normalizeName("First Aid Kit")] = ItemESP.Colors.Heal,
	[normalizeName("Apple")] = ItemESP.Colors.Heal,
	[normalizeName("Bandage")] = ItemESP.Colors.Heal,
	[normalizeName("Forcefield Crystal")] = ItemESP.Colors.Defense,
	[normalizeName("Cube of Ice")] = ItemESP.Colors.Defense,
	[normalizeName("Gravitation Shard")] = ItemESP.Colors.Utility,
	[normalizeName("Lightning Potion")] = ItemESP.Colors.Utility,
	[normalizeName("Bomb")] = ItemESP.Colors.Danger,
	[normalizeName("Bombs")] = ItemESP.Colors.Danger,
	[normalizeName("Tomahawk")] = ItemESP.Colors.Danger,
}

for _, itemName in ipairs(itemNames) do
	ItemESP.KnownNameLookup[normalizeName(itemName)] = itemName
end

function ItemESP.GetColor(itemName)
	return ItemESP.ColorLookup[normalizeName(itemName)] or ItemESP.Colors.Default
end

function ItemESP.GetKnownName(object)
	if not object or not (object:IsA("Model") or object:IsA("Tool") or object:IsA("BasePart")) then
		return nil
	end

	return ItemESP.KnownNameLookup[normalizeName(getItemDisplayName(object))]
end

function ItemESP.GetSearchPool()
	return getFullCollectibleSearchPool()
end

function ItemESP.ClearObject(object)
	local row = ItemESP.Rows[object]

	if not row then
		return
	end

	if row.Highlight then
		row.Highlight:Destroy()
	end

	if row.Billboard then
		row.Billboard:Destroy()
	end

	ItemESP.Rows[object] = nil
end

function ItemESP.Clear()
	for object in pairs(ItemESP.Rows) do
		ItemESP.ClearObject(object)
	end

	if ItemESP.Folder then
		ItemESP.Folder:Destroy()
		ItemESP.Folder = nil
	end
end

function ItemESP.EnsureFolder()
	if ItemESP.Folder and ItemESP.Folder.Parent then
		return ItemESP.Folder
	end

	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	ItemESP.Folder = Instance.new("Folder")
	ItemESP.Folder.Name = "Part"
	ItemESP.Folder.Parent = playerGui or gui or game:GetService("CoreGui")
	return ItemESP.Folder
end

function ItemESP.CreateOrUpdate(object, itemName, part)
	ItemESP.EnsureFolder()

	local color = ItemESP.GetColor(itemName)
	local row = ItemESP.Rows[object]

	if not row then
		row = {}
		ItemESP.Rows[object] = row

		row.Highlight = Instance.new("Highlight")
		row.Highlight.Name = "Part"
		row.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		row.Highlight.FillTransparency = 0.72
		row.Highlight.OutlineTransparency = 0
		row.Highlight.Parent = ItemESP.Folder

		row.Billboard = Instance.new("BillboardGui")
		row.Billboard.Name = "Part"
		row.Billboard.Size = UDim2.fromOffset(240, 48)
		row.Billboard.StudsOffset = Vector3.new(0, 3.2, 0)
		row.Billboard.AlwaysOnTop = true
		row.Billboard.MaxDistance = 1200
		row.Billboard.Parent = ItemESP.Folder

		row.Label = Instance.new("TextLabel")
		row.Label.Name = "Part"
		row.Label.Size = UDim2.fromScale(1, 1)
		row.Label.BackgroundTransparency = 1
		row.Label.Font = Enum.Font.GothamBlack
		row.Label.TextSize = 20
		row.Label.TextStrokeTransparency = 0.12
		row.Label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		row.Label.TextWrapped = true
		row.Label.Parent = row.Billboard

		row.Button = Instance.new("TextButton")
		row.Button.Name = "Teleport"
		row.Button.Size = UDim2.fromScale(1, 1)
		row.Button.BackgroundTransparency = 1
		row.Button.Text = ""
		row.Button.AutoButtonColor = false
		row.Button.ZIndex = 5
		row.Button.Parent = row.Billboard
		row.Button.Activated:Connect(function()
			local currentPart = row.CurrentPart
			local currentItemName = row.CurrentItemName
			if ItemESP.Enabled and object.Parent and currentPart and currentPart.Parent then
				Items.TeleportTo(currentItemName)
			end
		end)
	end

	row.CurrentPart = part
	row.CurrentItemName = itemName

	local highlightAdornee = object:IsA("Model") and object or part
	row.Highlight.Adornee = highlightAdornee
	row.Highlight.FillColor = color
	row.Highlight.OutlineColor = color
	row.Billboard.Adornee = part
	row.Label.Text = itemName
	row.Label.TextColor3 = color
end

function ItemESP.Refresh()
	local seen = {}

	for _, object in ipairs(ItemESP.GetSearchPool()) do
		local itemName = ItemESP.GetKnownName(object)

		if itemName then
			local part = getLiveItemPart(object)

			if part then
				seen[object] = true
				ItemESP.CreateOrUpdate(object, itemName, part)
			end
		end
	end

	for object in pairs(ItemESP.Rows) do
		if not seen[object] then
			ItemESP.ClearObject(object)
		end
	end
end

function ItemESP.Start()
	if ItemESP.Thread then
		return
	end

	ItemESP.Thread = task.spawn(function()
		while ItemESP.Enabled do
			ItemESP.Refresh()
			task.wait(ItemESP.RefreshDelay)
		end

		ItemESP.Thread = nil
	end)
end

function ItemESP.SetEnabled(state)
	ItemESP.Enabled = state == true

	if ItemESP.Enabled then
		ItemESP.Start()
		ItemESP.Refresh()
	else
		ItemESP.Clear()
	end
end

function UI.SetItemESP(state, silent)
	ItemESP.SetEnabled(state == true)

	if not silent then
		createNotification("Item ESP", state and "Item ESP enabled." or "Item ESP disabled.", state and "Success" or "Info")
	end
end

UI.JumpBusExitSent = false
UI.JumpBusTrackedObject = nil
UI.LastSlapRoyaleTimerNumber = nil
UI.LastSlapRoyaleTimerZeroAt = -math.huge
UI.JumpBusSearchStartedAt = 0
UI.JumpBusTimerSeen = false
UI.BusSearchCache = {}
UI.LastBusSearchAt = 0

function UI.FireRemoteAction(label, remoteName, ...)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild(remoteName)

	if remote and remote:IsA("RemoteEvent") then
		local ok, err = pcall(function(...)
			remote:FireServer(...)
		end, ...)

		if ok then
			createNotification(label, remoteName .. " request sent.", "Success")
			return true
		end

		createNotification(label, "Failed: " .. tostring(err), "Error")
		return false
	end

	createNotification(label, remoteName .. " remote not found.", "Error")
	return false
end

function UI.RequestEarlyBusPriorityTeleport(delaySeconds, forceRestart)
	task.delay(delaySeconds or 0, function()
		for _ = 1, 30 do
			if UI.TeleportToEarlyBusPriorityItem then
				UI.TeleportToEarlyBusPriorityItem(forceRestart)
				return
			end

			task.wait(0.2)
		end
	end)
end

function UI.FireEarlyBusJump()
	local success = UI.FireRemoteAction("Early Bus Jump", "BusJumping", true)

	if success then
		UI.JumpBusExitSent = true
		UI.LastAutoEarlyBusJumpAt = os.clock()
		local earlyUnlockAt = os.clock() + 10
		Items.EarlyBusFBlockActive = true
		Teleport.BlockFUntil = math.max(Teleport.BlockFUntil or 0, earlyUnlockAt)
		Teleport.RefreshPickupLock()

		task.delay(math.max(0.05, earlyUnlockAt - os.clock()), function()
			if Teleport.BlockFUntil <= earlyUnlockAt + 0.02 then
				Items.EarlyBusFBlockActive = false
				Teleport.RefreshPickupLock()
			end
		end)

		if UI.TeleportToEarlyBusPriorityItem then
			UI.TeleportToEarlyBusPriorityItem(true)
		else
			UI.RequestEarlyBusPriorityTeleport(0, true)
		end
	end

	return success
end

function UI.RefreshJumpBusTimerWindow()
	local timerNumber = Main.FindSlapRoyaleTimer()
	local now = os.clock()

	if timerNumber then
		UI.JumpBusTimerSeen = true

		if timerNumber <= 5 or (UI.LastSlapRoyaleTimerNumber and UI.LastSlapRoyaleTimerNumber > 0 and timerNumber <= 0) then
			UI.LastSlapRoyaleTimerZeroAt = now
		end

		UI.LastSlapRoyaleTimerNumber = timerNumber
	elseif UI.LastSlapRoyaleTimerNumber and UI.LastSlapRoyaleTimerNumber <= 5 then
		UI.LastSlapRoyaleTimerZeroAt = now
		UI.LastSlapRoyaleTimerNumber = nil
	else
		UI.LastSlapRoyaleTimerNumber = nil
	end
end

function UI.IsJumpBusDetectionActive()
	UI.RefreshJumpBusTimerWindow()

	if UI.JumpBusExitSent then
		return true
	end

	if UI.JumpBusSearchActive ~= true then
		return false
	end

	local now = os.clock()

	if now - (UI.LastSlapRoyaleTimerZeroAt or -math.huge) <= 7 then
		return true
	end

	return not UI.JumpBusTimerSeen and now - (UI.JumpBusSearchStartedAt or 0) <= 12
end

function UI.GetBusCandidateRoot(object)
	local current = object
	local candidate = nil

	while current and current ~= workspace do
		local lowerName = string.lower(current.Name)

		if string.find(lowerName, "bus", 1, true) and (current:IsA("Model") or current:IsA("BasePart")) then
			candidate = current
		end

		current = current.Parent
	end

	return candidate
end

function UI.IsJumpBusCandidate(object)
	local lowerName = string.lower(object.Name)
	return string.find(lowerName, "bus", 1, true) ~= nil and (object:IsA("Model") or object:IsA("BasePart"))
end

function UI.GetBusCandidates(rootPosition)
	if os.clock() - (UI.LastBusSearchAt or 0) < 0.65 then
		return UI.BusSearchCache or {}
	end

	local results = {}

	if UI.IsJumpBusDetectionActive() and rootPosition then
		local seen = {}

		local ok, nearbyParts = pcall(function()
			return workspace:GetPartBoundsInBox(CFrame.new(rootPosition), Vector3.new(180, 130, 180))
		end)

		if ok then
			for _, part in ipairs(nearbyParts) do
				local candidate = UI.GetBusCandidateRoot(part)

				if candidate and not seen[candidate] then
					seen[candidate] = true
					table.insert(results, candidate)
				end
			end
		end

		if #results == 0 then
			for _, object in ipairs(workspace:GetChildren()) do
				if UI.IsJumpBusCandidate(object) and not seen[object] then
					seen[object] = true
					table.insert(results, object)
				end
			end
		end
	end

	UI.BusSearchCache = results
	UI.LastBusSearchAt = os.clock()
	return results
end

function UI.IsPointNearObjectBounds(point, object)
	if object:IsA("BasePart") then
		local localPoint = object.CFrame:PointToObjectSpace(point)
		local halfSize = (object.Size * 0.5) + Vector3.new(14, 14, 14)

		return math.abs(localPoint.X) <= halfSize.X
			and math.abs(localPoint.Y) <= halfSize.Y
			and math.abs(localPoint.Z) <= halfSize.Z
	end

	if object:IsA("Model") then
		local ok, cframe, size = pcall(function()
			return object:GetBoundingBox()
		end)

		if ok then
			local localPoint = cframe:PointToObjectSpace(point)
			local halfSize = (size * 0.5) + Vector3.new(18, 18, 18)

			return math.abs(localPoint.X) <= halfSize.X
				and math.abs(localPoint.Y) <= halfSize.Y
				and math.abs(localPoint.Z) <= halfSize.Z
		end
	end

	return false
end

function UI.IsLocalPlayerInBus()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root then
		return false
	end

	if UI.JumpBusTrackedObject and UI.JumpBusTrackedObject.Parent then
		if UI.IsPointNearObjectBounds(root.Position, UI.JumpBusTrackedObject) then
			UI.LastJumpBusSeenAt = os.clock()
			return true
		end

		if UI.JumpBusExitSent then
			return false
		end
	end

	for _, busObject in ipairs(UI.GetBusCandidates(root.Position)) do
		if busObject.Parent and UI.IsPointNearObjectBounds(root.Position, busObject) then
			UI.LastJumpBusSeenAt = os.clock()
			UI.JumpBusTrackedObject = busObject
			return true
		end
	end

	return false
end

function UI.FindEarlyBusPriorityLandingTarget()
	for _, wantedName in ipairs(Items.PermanentCollectStopOrder) do
		local manualObject, manualPart = Items.FindManualItem(wantedName)

		if manualObject and manualPart and getLiveItemPart(manualObject) == manualPart then
			return wantedName, manualPart.CFrame, manualPart.Position, manualObject, manualPart
		end
	end

	for _, wantedName in ipairs(Items.PermanentCollectStopOrder) do
		local itemName, itemCFrame, itemPosition, itemObject, itemPart = findLiveItemByName(wantedName)

		if itemName and itemObject and itemPart then
			return itemName, itemCFrame, itemPosition, itemObject, itemPart
		end
	end

	for _, wantedName in ipairs(Items.PermanentCollectStopOrder) do
		local itemName, itemCFrame, itemPosition, itemObject, itemPart = findLiveItemByName(wantedName, true)

		if itemName and itemObject and itemPart then
			return itemName, itemCFrame, itemPosition, itemObject, itemPart
		end
	end

	return nil, nil, nil, nil, nil
end

function UI.GetEarlyBusLandingCFrames(itemPart, character, itemObject)
	local itemExclude = {}
	local groundExclude = {}
	local landingCFrames = {}

	if character then
		table.insert(itemExclude, character)
		table.insert(groundExclude, character)
	end

	if itemObject then
		table.insert(itemExclude, itemObject)
		table.insert(groundExclude, itemObject)
	end

	if itemPart then
		table.insert(groundExclude, itemPart)
	end

	local function addLanding(cframe)
		if typeof(cframe) ~= "CFrame" then
			return
		end

		for _, existing in ipairs(landingCFrames) do
			if (existing.Position - cframe.Position).Magnitude <= 1.5 then
				return
			end
		end

		table.insert(landingCFrames, cframe)
	end

	addLanding(Teleport.GetItemCFrame(itemPart, itemExclude))
	addLanding(Teleport.GetGroundCFrame(itemPart.Position, groundExclude, true))

	local offsets = {
		Vector3.zero,
		Vector3.new(4, 0, 0),
		Vector3.new(-4, 0, 0),
		Vector3.new(0, 0, 4),
		Vector3.new(0, 0, -4),
		Vector3.new(6, 0, 6),
		Vector3.new(-6, 0, 6),
		Vector3.new(6, 0, -6),
		Vector3.new(-6, 0, -6),
	}

	for _, offset in ipairs(offsets) do
		addLanding(Teleport.GetGroundCFrame(itemPart.Position + offset, groundExclude, true))
	end

	addLanding(CFrame.new(itemPart.Position + Vector3.new(0, 4, 0)))

	return landingCFrames
end

function UI.PrepareEarlyBusLandingCharacter(character, root)
	if root and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		pcall(function()
			humanoid.Sit = false
			humanoid.PlatformStand = false
			humanoid.Jump = true
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end)
	end
end

function UI.TryEarlyBusItemLanding(root, itemPart, character, itemObject, teleportToken)
	if not root or not root.Parent or not itemPart or not itemPart.Parent then
		return nil
	end

	local landingCFrames = UI.GetEarlyBusLandingCFrames(itemPart, character, itemObject)

	for attempt = 1, 5 do
		if Items.EarlyBusPriorityTeleportToken ~= teleportToken then
			return nil
		end

		for _, landingCFrame in ipairs(landingCFrames) do
			if not root.Parent or not itemPart.Parent then
				return nil
			end

			UI.PrepareEarlyBusLandingCharacter(character, root)
			Teleport.MoveRoot(root, landingCFrame, itemPart.Position)
			task.wait(attempt == 1 and 0.08 or 0.12)

			local rootPosition = root.Position
			local flatRoot = Vector3.new(rootPosition.X, 0, rootPosition.Z)
			local flatItem = Vector3.new(itemPart.Position.X, 0, itemPart.Position.Z)
			local landingDistance = (rootPosition - landingCFrame.Position).Magnitude
			local itemFlatDistance = (flatRoot - flatItem).Magnitude
			local landingYDistance = math.abs(rootPosition.Y - landingCFrame.Position.Y)

			if landingDistance <= 10 or (itemFlatDistance <= 14 and landingYDistance <= 12) then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				return landingCFrame
			end
		end

		task.wait(0.08)
	end

	return nil
end

function UI.TeleportToEarlyBusPriorityItem(forceRestart)
	if Items.EarlyBusPriorityTeleportBusy and not forceRestart then
		return
	end

	Items.EarlyBusPriorityTeleportBusy = true
	Items.EarlyBusPriorityTeleportToken = (Items.EarlyBusPriorityTeleportToken or 0) + 1
	local teleportToken = Items.EarlyBusPriorityTeleportToken

	task.spawn(function()
		Items.LastEarlyBusPriorityTeleportAt = os.clock()
		createNotification("Early Bus Jump", "Finding first priority item to land on.", "Info")

		local itemName, itemCFrame, itemPosition, itemObject, itemPart = nil, nil, nil, nil, nil
		local findUntil = os.clock() + 18
		local postLandingLockActive = false

		repeat
			if Items.EarlyBusPriorityTeleportToken ~= teleportToken then
				return
			end

			Items.RebuildSearchCache()
			itemName, itemCFrame, itemPosition, itemObject, itemPart = UI.FindEarlyBusPriorityLandingTarget()

			if itemName and itemPart and isSameItemStillThere(itemObject, itemPart, itemName) then
				break
			end

			task.wait(0.1)
		until os.clock() >= findUntil

		if itemName and itemPart and isSameItemStillThere(itemObject, itemPart, itemName) then
			local character = player.Character or player.CharacterAdded:Wait()
			local root = character:WaitForChild("HumanoidRootPart", 5)

			if root then
				local groundCFrame = UI.TryEarlyBusItemLanding(root, itemPart, character, itemObject, teleportToken)

				if groundCFrame then
					local landedAt = os.clock()
					local fLockDuration = 10
					local unlockAt = landedAt + fLockDuration
					local nextTeleportAt = unlockAt + 1

					postLandingLockActive = true
					Items.EarlyAutoCollectPauseUntil = math.max(Items.EarlyAutoCollectPauseUntil or 0, nextTeleportAt)
					Items.EarlyBusFBlockActive = true
					Teleport.BlockFUntil = math.max(Teleport.BlockFUntil or 0, unlockAt)
					Teleport.RefreshPickupLock()
					createNotification("Early Bus Jump", "F locked for 10 seconds after early bus jump.", "Info")

					task.delay(math.max(0.05, unlockAt - os.clock()), function()
						if Items.EarlyBusPriorityTeleportToken ~= teleportToken then
							return
						end

						Items.EarlyBusFBlockActive = false
						Teleport.RefreshPickupLock()
						createNotification("Early Bus Jump", "F unlocked. Early Auto Collect starts in 1 second.", "Info")
					end)

					Teleport.StabilizeItemView(root, itemPart)
					Teleport.AddFixedStrike(Teleport.DefaultMaxStrikes, Teleport.DefaultCooldown)
					createNotification("Early Bus Jump", "Teleported to " .. itemName .. ".", "Success")
				else
					createNotification("Early Bus Jump", "Could not stay on the item landing position.", "Error")
				end
			end
		else
			createNotification("Early Bus Jump", "No priority item was ready to teleport to.", "Warning")
		end

		if not postLandingLockActive then
			local unlockAt = Teleport.BlockFUntil or 0

			task.delay(math.max(0.05, unlockAt - os.clock()), function()
				if Teleport.BlockFUntil <= unlockAt + 0.02 then
					Items.EarlyBusFBlockActive = false
					Teleport.RefreshPickupLock()
				end
			end)
		end

		task.wait(1)

		if Items.EarlyBusPriorityTeleportToken == teleportToken then
			Items.EarlyBusPriorityTeleportBusy = false
		end
	end)
end

function UI.RunAutoEarlyBusJump()
	if UI.AutoEarlyBusJumpThread then
		return
	end

	UI.JumpBusSearchActive = true
	UI.JumpBusExitSent = false
	UI.JumpBusTrackedObject = nil
	UI.JumpBusSearchStartedAt = os.clock()
	UI.JumpBusTimerSeen = false
	UI.LastSlapRoyaleTimerNumber = nil
	UI.LastSlapRoyaleTimerZeroAt = -math.huge
	UI.BusSearchCache = {}
	UI.LastBusSearchAt = 0

	UI.AutoEarlyBusJumpThread = task.spawn(function()
		while UI.AutoEarlyBusJumpEnabled do
			local inBus = UI.IsLocalPlayerInBus()

			if inBus and not UI.AutoEarlyBusJumpFiredInBus and os.clock() - (UI.LastAutoEarlyBusJumpAt or 0) >= 1 then
				if UI.FireEarlyBusJump() then
					UI.AutoEarlyBusJumpFiredInBus = true
					UI.LastAutoEarlyBusJumpAt = os.clock()
				end
			elseif not inBus and not UI.JumpBusExitSent then
				UI.AutoEarlyBusJumpFiredInBus = false
			end

			task.wait(0.15)
		end

		UI.AutoEarlyBusJumpThread = nil
		UI.AutoEarlyBusJumpFiredInBus = false
		UI.JumpBusSearchActive = false
		UI.JumpBusTimerSeen = false
	end)
end

function UI.SetAutoEarlyBusJump(state, silent)
	UI.AutoEarlyBusJumpEnabled = state == true

	if UI.AutoEarlyBusJumpEnabled then
		UI.JumpBusSearchActive = true
		UI.JumpBusExitSent = false
		UI.JumpBusTrackedObject = nil
		UI.AutoEarlyBusJumpFiredInBus = false
		UI.JumpBusSearchStartedAt = os.clock()
		UI.JumpBusTimerSeen = false
		UI.LastSlapRoyaleTimerNumber = nil
		UI.LastSlapRoyaleTimerZeroAt = -math.huge
		UI.BusSearchCache = {}
		UI.LastBusSearchAt = 0
		UI.RunAutoEarlyBusJump()

		if not silent then
			createNotification("Early Bus Jump", "Auto bus jump enabled.", "Success")
		end
	else
		UI.JumpBusSearchActive = false
		UI.JumpBusExitSent = false
		UI.JumpBusTrackedObject = nil
		UI.AutoEarlyBusJumpFiredInBus = false
		UI.JumpBusTimerSeen = false

		if not silent then
			createNotification("Early Bus Jump", "Auto bus jump disabled.")
		end
	end
end

;(function()
local ItemTeleportNames = {
	"True Power", "Potion of Strength", "Bull's Essence", "Boba", "Speed Potion",
	"Frog Potion", "Sphere of Fury", "Tomahawk", "Gravitation Shard",
	"Healing Potion", "First Aid Kit", "Cube of Ice", "Bomb", "Bombs", "Bandage",
	"Apple", "Forcefield Crystal", "Lightning Potion", "Meteor Crate",
}

local GenericTeleportItemNames = {
	[""] = true,
	["part"] = true,
	["meshpart"] = true,
	["union"] = true,
	["handle"] = true,
	["root"] = true,
	["primarypart"] = true,
	["humanoidrootpart"] = true,
	["hitbox"] = true,
	["touch"] = true,
	["prompt"] = true,
	["pickup"] = true,
	["collectible"] = true,
	["item"] = true,
	["items"] = true,
	["drops"] = true,
	["loot"] = true,
}

local function addTeleportItemName(list, seen, itemName)
	itemName = tostring(itemName or "")

	if itemName == "" then
		return
	end

	local key = Utility.NormalizeName(itemName)

	if seen[key] then
		return
	end

	seen[key] = true
	table.insert(list, itemName)
end

local function getCanonicalTeleportItemName(candidateName)
	for _, itemName in ipairs(ItemTeleportNames) do
		if strictItemNameMatches(candidateName, itemName) then
			return itemName
		end
	end

	for _, itemName in ipairs(itemNames) do
		if strictItemNameMatches(candidateName, itemName) then
			return itemName
		end
	end

	return nil
end

local function isGoodDynamicTeleportItemName(itemName)
	local normalized = Utility.NormalizeName(itemName)

	if GenericTeleportItemNames[normalized] then
		return false
	end

	return normalized ~= ""
end

local function getDynamicTeleportItemName(object)
	local current = object

	while current and current ~= workspace do
		local canonical = getCanonicalTeleportItemName(current.Name)

		if canonical then
			return canonical
		end

		current = current.Parent
	end

	local searchRoot = Items.GetSearchRoot()

	if searchRoot then
		current = object
		local topUnderRoot = nil

		while current and current ~= workspace and current ~= searchRoot do
			topUnderRoot = current
			current = current.Parent
		end

		if current == searchRoot and topUnderRoot and isGoodDynamicTeleportItemName(topUnderRoot.Name) then
			return topUnderRoot.Name
		end
	end

	current = object

	while current and current ~= workspace do
		if isGoodDynamicTeleportItemName(current.Name) then
			return current.Name
		end

		current = current.Parent
	end

	return nil
end

function getItemTeleportDiscoveryPool()
	return Items.GetSearchChildren()
end

local function buildItemTeleportMenuNames()
	local ordered = {}
	local seen = {}
	local extra = {}
	local extraSeen = {}
	local liveNames = {}

	-- Permanent/stat-boosting items always come first.
	for _, itemName in ipairs(Items.PermanentCollectStopOrder or {}) do
		addTeleportItemName(ordered, seen, itemName)
	end

	for _, itemName in ipairs(ItemTeleportNames) do
		addTeleportItemName(ordered, seen, itemName)
	end

	for _, itemName in ipairs(itemNames) do
		addTeleportItemName(ordered, seen, itemName)
	end

	for _, object in ipairs(getItemTeleportDiscoveryPool()) do
		local itemName = getDynamicTeleportItemName(object)

		if itemName then
			local key = Utility.NormalizeName(itemName)
			local matchObject = getStrictItemMatchObject(object, itemName) or object

			if getLiveItemPart(matchObject) or getLiveItemPart(object) then
				liveNames[key] = true

				if not seen[key] and not extraSeen[key] then
					extraSeen[key] = true
					table.insert(extra, itemName)
				end
			end
		end
	end

	Items.RefreshCrates()

	if #Items.Crates > 0 then
		liveNames[Utility.NormalizeName("Meteor Crate")] = true
	end

	table.sort(extra, function(left, right)
		return string.lower(tostring(left)) < string.lower(tostring(right))
	end)

	for _, itemName in ipairs(extra) do
		addTeleportItemName(ordered, seen, itemName)
	end

	return ordered, liveNames
end

local function getPlayerTeleportLabel(targetPlayer)
	if targetPlayer.DisplayName ~= targetPlayer.Name then
		return targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")"
	end

	return targetPlayer.Name
end

local TeleportMenu = {
	Gui = nil,
	Window = nil,
	Rows = nil,
	TabButtons = {},
	ActiveTab = Preferences.TeleportMenuTab or "Items",
	PlayerAddedConnection = nil,
	PlayerRemovingConnection = nil,
}

local renderTeleportMenuRows

local function getTeleportRows(tabName)
	local rows = {}

	if tabName == "Items" then
		local itemOrder, liveNames = buildItemTeleportMenuNames()

		for _, itemName in ipairs(itemOrder) do
			if not liveNames[Utility.NormalizeName(itemName)] then
				continue
			end

			table.insert(rows, {
				Title = itemName,
				Callback = function()
					if itemName == "Meteor Crate" then
						Items.TeleportToCrate()
					else
						Items.TeleportTo(itemName)
					end

					task.delay(0.6, function()
						if TeleportMenu.ActiveTab == "Items" then
							TeleportMenu.LastRowsSignature = nil
							renderTeleportMenuRows()
						end
					end)
				end,
			})
		end
	elseif tabName == "Players" then
		table.insert(rows, { Title = "Teleport To Nearest", Callback = Combat.TeleportToNearestPlayer })
		table.insert(rows, { Title = "Teleport To Lowest Health", Callback = Combat.TeleportToLowestHealthPlayer })

		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			if targetPlayer ~= player then
				table.insert(rows, {
					Title = getPlayerTeleportLabel(targetPlayer),
					Callback = function()
						Combat.TeleportToPlayer(targetPlayer)
					end,
				})
			end
		end
	elseif tabName == "Locations" then
		for _, location in ipairs(Teleport.Locations) do
			table.insert(rows, {
				Title = location.Name,
				Callback = function()
					Teleport.ToLocation(location.Name, location.Position)
				end,
			})
		end
	end

	return rows
end

local function styleCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.Name = "Part"
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function styleStroke(parent, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Part"
	stroke.Color = color
	stroke.Thickness = 1
	stroke.Transparency = transparency or 0.25
	stroke.Parent = parent
	return stroke
end

local MinimizedLauncher = {
	Active = true,
	Gui = nil,
	Container = nil,
	Button = nil,
	MainGui = nil,
	MainRoot = nil,
	HasSeenMainWindow = false,
	LastClickAt = 0,
	LastWindowScanAt = 0,
	WindowScanInterval = 1.5,
	Dragging = false,
	DragMoved = false,
	DragStart = nil,
	DragStartPosition = nil,
}

local function getScreenGuiAncestor(object)
	local current = object

	while current do
		if current:IsA("ScreenGui") then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function getTopGuiObjectUnderScreen(object, screenGui)
	local current = object
	local topObject = object

	while current and current.Parent and current.Parent ~= screenGui do
		current = current.Parent

		if current:IsA("GuiObject") then
			topObject = current
		end
	end

	return topObject
end

local function isActuallyVisible(object)
	local current = object

	while current do
		if current:IsA("ScreenGui") and current.Enabled == false then
			return false
		end

		if current:IsA("GuiObject") and current.Visible == false then
			return false
		end

		current = current.Parent
	end

	return true
end

local function isLauncherDescendant(object)
	return MinimizedLauncher.Gui and object:IsDescendantOf(MinimizedLauncher.Gui)
end

local function findWindUIMainWindowInfo()
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

	if not playerGui then
		return nil
	end

	for _, object in ipairs(playerGui:GetDescendants()) do
		if not isLauncherDescendant(object)
			and (object:IsA("TextLabel") or object:IsA("TextButton"))
			and object.Text == "OP Slap Royale" then
			local screenGui = getScreenGuiAncestor(object)

			if screenGui then
				local root = getTopGuiObjectUnderScreen(object, screenGui)
				local rootSize = root and root.AbsoluteSize or Vector2.new(0, 0)
				local minimizedBySize = rootSize.X > 0 and rootSize.Y > 0 and (rootSize.X < 280 or rootSize.Y < 180)

				return {
					ScreenGui = screenGui,
					Root = root,
					Visible = isActuallyVisible(object),
					Minimized = minimizedBySize,
				}
			end
		end
	end

	return nil
end

local function setMinimizedLauncherVisible(state)
	if MinimizedLauncher.Gui then
		MinimizedLauncher.Gui.Enabled = state == true
	end
end

local function restoreWindUIWindow()
	MinimizedLauncher.LastClickAt = os.clock()

	pcall(function()
		if MinimizedLauncher.MainGui then
			MinimizedLauncher.MainGui.Enabled = true
		end
	end)

	pcall(function()
		if MinimizedLauncher.MainRoot then
			MinimizedLauncher.MainRoot.Visible = true
		end
	end)

	for _, methodName in ipairs({ "Open", "Show", "Restore", "Maximize", "Unminimize" }) do
		local method = WindUIWindow and WindUIWindow[methodName]

		if type(method) == "function" then
			MinimizedLauncher.CalledOpenMethod = true
			pcall(method, WindUIWindow)
			pcall(method)
		end
	end

	local toggleMethod = WindUIWindow and WindUIWindow.Toggle
	if not MinimizedLauncher.CalledOpenMethod and type(toggleMethod) == "function" then
		pcall(toggleMethod, WindUIWindow, true)
	end

	MinimizedLauncher.CalledOpenMethod = false

	setMinimizedLauncherVisible(false)
end

local function ensureMinimizedLauncher()
	if not MinimizedLauncher.Active then
		return
	end

	if MinimizedLauncher.Gui and MinimizedLauncher.Gui.Parent then
		return
	end

	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

	if not playerGui then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Part"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 999998
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local container = Instance.new("TextButton")
	container.Name = "Part"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, isTouchDevice and 34 or 26)
	container.Size = UDim2.fromOffset(isTouchDevice and 74 or 66, isTouchDevice and 48 or 42)
	container.BackgroundColor3 = Color3.fromRGB(13, 23, 20)
	container.BackgroundTransparency = 0.06
	container.BorderSizePixel = 0
	container.Active = true
	container.AutoButtonColor = true
	container.Font = Enum.Font.GothamBlack
	container.Text = "OP"
	container.TextColor3 = Color3.fromRGB(236, 255, 240)
	container.TextSize = isTouchDevice and 20 or 18
	container.Parent = screenGui

	styleCorner(container, 12)
	styleStroke(container, Color3.fromRGB(92, 210, 128), 0.16)

	container.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		MinimizedLauncher.Dragging = true
		MinimizedLauncher.DragMoved = false
		MinimizedLauncher.DragStart = input.Position
		MinimizedLauncher.DragStartPosition = container.Position
	end)

	container.InputChanged:Connect(function(input)
		if not MinimizedLauncher.Dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local dragStart = MinimizedLauncher.DragStart
		local startPosition = MinimizedLauncher.DragStartPosition

		if not dragStart or not startPosition then
			return
		end

		local delta = input.Position - dragStart

		if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
			MinimizedLauncher.DragMoved = true
		end

		container.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end)

	container.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local wasDragging = MinimizedLauncher.Dragging
		local wasMoved = MinimizedLauncher.DragMoved
		MinimizedLauncher.Dragging = false
		MinimizedLauncher.DragStart = nil
		MinimizedLauncher.DragStartPosition = nil

		if wasDragging and not wasMoved then
			restoreWindUIWindow()
		end
	end)

	MinimizedLauncher.Gui = screenGui
	MinimizedLauncher.Container = container
	MinimizedLauncher.Button = container
end

local function refreshMinimizedLauncher()
	if not MinimizedLauncher.Active then
		return
	end

	local now = os.clock()
	local info = nil

	if MinimizedLauncher.MainGui and MinimizedLauncher.MainRoot then
		info = {
			ScreenGui = MinimizedLauncher.MainGui,
			Root = MinimizedLauncher.MainRoot,
			Visible = isActuallyVisible(MinimizedLauncher.MainRoot),
			Minimized = MinimizedLauncher.MainRoot.AbsoluteSize.X > 0
				and MinimizedLauncher.MainRoot.AbsoluteSize.Y > 0
				and (MinimizedLauncher.MainRoot.AbsoluteSize.X < 280 or MinimizedLauncher.MainRoot.AbsoluteSize.Y < 180),
		}
	elseif now - (MinimizedLauncher.LastWindowScanAt or 0) >= (MinimizedLauncher.WindowScanInterval or 1.5) then
		MinimizedLauncher.LastWindowScanAt = now
		info = findWindUIMainWindowInfo()
	end

	if info then
		MinimizedLauncher.MainGui = info.ScreenGui
		MinimizedLauncher.MainRoot = info.Root
		MinimizedLauncher.HasSeenMainWindow = true
		local showLauncher = (info.Visible == false or info.Minimized == true) and os.clock() - MinimizedLauncher.LastClickAt > 0.4

		if showLauncher then
			ensureMinimizedLauncher()
		end

		setMinimizedLauncherVisible(showLauncher)
	elseif MinimizedLauncher.HasSeenMainWindow then
		local showLauncher = os.clock() - MinimizedLauncher.LastClickAt > 0.4

		if showLauncher then
			ensureMinimizedLauncher()
		end

		setMinimizedLauncherVisible(showLauncher)
	end
end

task.spawn(function()
	while MinimizedLauncher.Active do
		refreshMinimizedLauncher()
		task.wait(0.75)
	end
end)

local function updateTeleportMenuTabs()
	for tabName, button in pairs(TeleportMenu.TabButtons) do
		local active = tabName == TeleportMenu.ActiveTab
		button.BackgroundColor3 = active and Color3.fromRGB(42, 84, 62) or Color3.fromRGB(22, 38, 32)
		button.TextColor3 = active and Color3.fromRGB(245, 255, 238) or Color3.fromRGB(176, 212, 190)
	end
end

function renderTeleportMenuRows()
	if not TeleportMenu.Rows then
		return
	end

	updateTeleportMenuTabs()

	local rows = getTeleportRows(TeleportMenu.ActiveTab)
	local signatureParts = { TeleportMenu.ActiveTab }

	for _, row in ipairs(rows) do
		table.insert(signatureParts, tostring(row.Title))
	end

	local signature = table.concat(signatureParts, "|")

	if TeleportMenu.LastRowsSignature == signature then
		return
	end

	TeleportMenu.LastRowsSignature = signature

	for _, child in ipairs(TeleportMenu.Rows:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local rowHeight = isTouchDevice and 42 or 38

	for index, row in ipairs(rows) do
		local button = Instance.new("TextButton")
		button.Name = "Part"
		button.LayoutOrder = index
		button.Size = UDim2.new(1, 0, 0, rowHeight)
		button.BackgroundColor3 = Color3.fromRGB(24, 49, 38)
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamMedium
		button.Text = tostring(row.Title or "Teleport")
		button.TextColor3 = Color3.fromRGB(239, 250, 242)
		button.TextSize = isTouchDevice and 14 or 13
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Parent = TeleportMenu.Rows

		styleCorner(button, 7)

		local padding = Instance.new("UIPadding")
		padding.Name = "Part"
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 10)
		padding.Parent = button

		button.Activated:Connect(function()
			safeTask(row.Callback)
		end)
	end
end

local function closeTeleportSideMenu(skipPreferenceSave)
	if not skipPreferenceSave then
		Preferences.TeleportMenuOpen = false
		queueSavePreferences()
	end

	if TeleportMenu.PlayerAddedConnection then
		TeleportMenu.PlayerAddedConnection:Disconnect()
		TeleportMenu.PlayerAddedConnection = nil
	end

	if TeleportMenu.PlayerRemovingConnection then
		TeleportMenu.PlayerRemovingConnection:Disconnect()
		TeleportMenu.PlayerRemovingConnection = nil
	end

	if TeleportMenu.Gui then
		TeleportMenu.Gui:Destroy()
	end

	TeleportMenu.Gui = nil
	TeleportMenu.Window = nil
	TeleportMenu.Rows = nil
	TeleportMenu.TabButtons = {}
	TeleportMenu.LastRowsSignature = nil
end

local function openTeleportSideMenu()
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	if TeleportMenu.Gui and TeleportMenu.Gui.Parent then
		TeleportMenu.Gui.Enabled = true
		Preferences.TeleportMenuOpen = true
		queueSavePreferences()
		renderTeleportMenuRows()
		return
	end

	closeTeleportSideMenu(true)

	local viewport = getViewportSize()
	local width = isTouchDevice and 286 or 316
	local height = math.clamp(viewport.Y - (isTouchDevice and 118 or 154), 300, isTouchDevice and 410 or 440)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Part"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local window = Instance.new("Frame")
	window.Name = "Part"
	window.AnchorPoint = Vector2.new(1, 0.5)
	window.Position = UDim2.new(1, isTouchDevice and -8 or -14, 0.5, 0)
	window.Size = UDim2.fromOffset(width, height)
	window.BackgroundColor3 = Color3.fromRGB(13, 23, 20)
	window.BorderSizePixel = 0
	window.Parent = screenGui

	styleCorner(window, 10)
	styleStroke(window, Color3.fromRGB(92, 210, 128), 0.18)

	local header = Instance.new("Frame")
	header.Name = "Part"
	header.Size = UDim2.new(1, 0, 0, 42)
	header.BackgroundTransparency = 1
	header.Parent = window

	local title = Instance.new("TextLabel")
	title.Name = "Part"
	title.Position = UDim2.fromOffset(12, 0)
	title.Size = UDim2.new(1, -54, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "Teleport Menu"
	title.TextColor3 = Color3.fromRGB(245, 255, 238)
	title.TextSize = isTouchDevice and 16 or 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Part"
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -8, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.BackgroundColor3 = Color3.fromRGB(28, 48, 40)
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.fromRGB(245, 255, 238)
	closeButton.TextSize = 14
	closeButton.Parent = header

	styleCorner(closeButton, 7)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "Part"
	tabBar.Position = UDim2.fromOffset(10, 44)
	tabBar.Size = UDim2.new(1, -20, 0, 34)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = window

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Name = "Part"
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabBar

	TeleportMenu.TabButtons = {}
	for index, tabName in ipairs({ "Items", "Players", "Locations" }) do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = "Part"
		tabButton.LayoutOrder = index
		tabButton.Size = UDim2.new(1 / 3, -4, 1, 0)
		tabButton.BackgroundColor3 = Color3.fromRGB(22, 38, 32)
		tabButton.BorderSizePixel = 0
		tabButton.Font = Enum.Font.GothamBold
		tabButton.Text = tabName
		tabButton.TextColor3 = Color3.fromRGB(176, 212, 190)
		tabButton.TextSize = isTouchDevice and 13 or 12
		tabButton.Parent = tabBar

		styleCorner(tabButton, 7)
		TeleportMenu.TabButtons[tabName] = tabButton

		tabButton.Activated:Connect(function()
			TeleportMenu.ActiveTab = tabName
			Preferences.TeleportMenuTab = tabName
			TeleportMenu.LastRowsSignature = nil
			queueSavePreferences()
			renderTeleportMenuRows()
		end)
	end

	local rows = Instance.new("ScrollingFrame")
	rows.Name = "Part"
	rows.Position = UDim2.fromOffset(10, 86)
	rows.Size = UDim2.new(1, -20, 1, -96)
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.ScrollBarThickness = isTouchDevice and 7 or 5
	rows.CanvasSize = UDim2.fromOffset(0, 0)
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.ScrollingDirection = Enum.ScrollingDirection.Y
	rows.Parent = window

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.Name = "Part"
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 7)
	rowLayout.Parent = rows

	local rowPadding = Instance.new("UIPadding")
	rowPadding.Name = "Part"
	rowPadding.PaddingBottom = UDim.new(0, 8)
	rowPadding.Parent = rows

	closeButton.Activated:Connect(function()
		closeTeleportSideMenu(false)
	end)

	TeleportMenu.Gui = screenGui
	TeleportMenu.Window = window
	TeleportMenu.Rows = rows
	TeleportMenu.ActiveTab = Preferences.TeleportMenuTab or TeleportMenu.ActiveTab or "Items"
	TeleportMenu.LastRowsSignature = nil
	Preferences.TeleportMenuOpen = true
	queueSavePreferences()
	renderTeleportMenuRows()

	TeleportMenu.PlayerAddedConnection = Players.PlayerAdded:Connect(function()
		if TeleportMenu.ActiveTab == "Players" then
			task.defer(renderTeleportMenuRows)
		end
	end)

	TeleportMenu.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function()
		if TeleportMenu.ActiveTab == "Players" then
			task.defer(renderTeleportMenuRows)
		end
	end)

	task.spawn(function()
		while TeleportMenu.Gui == screenGui and screenGui.Parent do
			if TeleportMenu.ActiveTab == "Items" then
				renderTeleportMenuRows()
			end

			task.wait(3)
		end
	end)
end

UI.OpenTeleportMenu = openTeleportSideMenu
UI.CloseTeleportMenu = closeTeleportSideMenu

function UI.GetRecommendedFeatureState(key)
	if key == "ExpandHitbox" then
		return Combat.HitboxExpanded == true
	elseif key == "VisualizeHitboxes" then
		return Combat.HitboxVisible == true
	elseif key == "SlapAura" then
		return Combat.SlapAuraEnabled == true
	elseif key == "AutoCollect" then
		return Items.AutoCollectEnabled == true
	elseif key == "AutoPermanentItems" then
		return autoPermanentEnabled == true
	elseif key == "AutoPickup" then
		return Items.AutoPickupEnabled == true
	elseif key == "AutoHeal" then
		return autoHealEnabled == true
	elseif key == "EarlyAutoCollect" then
		return Items.EarlyAutoCollectEnabled == true
	elseif key == "EarlyBusJump" then
		return UI.AutoEarlyBusJumpEnabled == true
	elseif key == "InfiniteJump" then
		return UI.InfiniteJumpEnabled == true
	elseif key == "AntiRagdoll" then
		return Combat.AntiSlapEnabled == true
	elseif key == "AutoSort" then
		return autoSortEnabled == true
	elseif key == "PlayerESP" then
		return ESP.Enabled == true
	elseif key == "ItemESP" then
		return ItemESP.Enabled == true
	elseif key == "AutoRejoin" then
		return UI.AutoRejoinEnabled == true
	elseif key == "AutoSlap" then
		return Combat.AutoGloveTapEnabled == true
	elseif key == "FastCollectCrates" then
		return Items.FastCollectCratesEnabled == true
	elseif key == "CrateAura" then
		return Items.CrateAuraEnabled == true
	elseif key == "AntiStaff" then
		return Anti.StaffEnabled == true
	elseif key == "HideUnderMap" then
		return Anti.HideUnderMapEnabled == true
	elseif key == "DisableNotifications" then
		return NotificationsDisabled == true
	end

	local toggle = UI.ToggleRefs[key]

	if toggle and toggle.Get then
		return toggle.Get() == true
	end

	return nil
end

function UI.SetToggleByKey(key, value, fireCallback, options)
	options = options or {}

	local desired = value == true
	local attempts = 0
	local maxAttempts = options.MaxAttempts or 10
	local retryDelay = options.RetryDelay or 0.2
	local checkFeatureState = options.CheckFeatureState ~= false

	local function needsRetry(toggle)
		if not checkFeatureState then
			return false
		end

		local featureState = UI.GetRecommendedFeatureState(key)

		if featureState ~= nil and featureState ~= desired then
			return true
		end

		if toggle and toggle.Get and toggle.Get() ~= desired then
			return true
		end

		return false
	end

	local function apply()
		attempts += 1

		local toggle = UI.ToggleRefs[key]

		if toggle and toggle.Set then
			toggle.Set(desired, fireCallback ~= false, options.Silent == true)

			if toggle.Sync then
				toggle.Sync()
			end

			if attempts < maxAttempts then
				task.delay(retryDelay, function()
					local latestToggle = UI.ToggleRefs[key]

					if latestToggle and needsRetry(latestToggle) then
						apply()
					elseif latestToggle and latestToggle.Sync then
						latestToggle.Sync()
					end
				end)
			end

			return
		end

		if attempts < maxAttempts then
			task.delay(0.15, apply)
		end
	end

	apply()
end

function UI.SetRecommendedSettings(state, silent)
	local enabled = state == true

	local function setToggle(key, value, fireCallback, options)
		options = options or {}
		options.Silent = silent == true
		UI.SetToggleByKey(key, value, fireCallback, options)
	end

	-- Recommended = only the requested features.
	setToggle("SlapAura", enabled)
	setToggle("AutoSlap", enabled)
	setToggle("ExpandHitbox", enabled)
	setToggle("VisualizeHitboxes", enabled)
	setToggle("ItemESP", enabled)

	if enabled then
		Combat.SetHitboxSize(20)
	end

	-- Explicitly keep unrelated automation out of the quick preset.
	setToggle("AutoHeal", false)
	setToggle("AntiRagdoll", false)
	setToggle("AutoSort", false)
	setToggle("PlayerESP", false)
	setToggle("AutoRejoin", false)
	setToggle("EarlyBusJump", false, false, { CheckFeatureState = false })
	UI.SetAutoEarlyBusJump(false, true)

	if enabled then
		TeleportMenu.ActiveTab = "Items"
		Preferences.TeleportMenuTab = "Items"
		TeleportMenu.LastRowsSignature = nil
		openTeleportSideMenu()
	else
		closeTeleportSideMenu(false)
	end

	task.delay(0.2, syncAllToggleVisuals)
	task.delay(0.8, syncAllToggleVisuals)
end

local function applyTheme(themeName)
	local ok = false
	local applied = false

	ok = pcall(function()
		if WindUIWindow and type(WindUIWindow.SetTheme) == "function" then
			WindUIWindow:SetTheme(themeName)
			applied = true
		elseif WindUI and type(WindUI.SetTheme) == "function" then
			WindUI:SetTheme(themeName)
			applied = true
		end
	end)

	if ok and applied then
		Preferences.Theme = tostring(themeName or "Dark")
		queueSavePreferences()
		createNotification("Theme", "Theme changed to " .. tostring(themeName) .. ".", "Success")
	elseif not applied then
		createNotification("Theme", "This WindUI build did not expose a theme setter.", "Warning")
	end
end

-- Main
AddButton(TabMain, "Auto Barn - Code + TP", "Finds the Barn code, submits it, shows the code, then teleports to Barn", "hash", Main.GetCodeGoBarn)
AddButton(TabMain, "Open Teleport Menu", "Items, players, and map locations", "map", openTeleportSideMenu)
AddToggle(TabMain, "Early Bus Jump", "Automatically jumps out when you are seated in the bus", false, UI.SetAutoEarlyBusJump, "EarlyBusJump")
AddToggle(TabMain, "Infinite Jump", "Lets you jump again while airborne", false, UI.SetInfiniteJump, "InfiniteJump")
AddToggle(TabMain, "Player Stats ESP", "Shows player health, kills, strength, and speed", false, UI.SetPlayerStatsESP, "PlayerESP")
AddToggle(TabMain, "Item ESP", "Highlights dropped items with color tags", false, UI.SetItemESP, "ItemESP")
AddToggle(TabMain, "Auto Play Again", "Automatically rejoins after death or disconnect", false, UI.SetAutoRejoin, "AutoRejoin")
AddToggle(TabMain, "Quick Recommended", "Show hitboxes, expand hitbox to 20, Auto Slap, Slap Aura, and Item ESP", false, UI.SetRecommendedSettings, "RecommendedSettings")

-- Items
local _, autoCollectRef = AddToggle(TabItems, "Auto collect", "Collects priority items without waiting for the round countdown", false, Items.SetAutoCollect, "AutoCollect")
Items.AutoCollectToggle = autoCollectRef

local _, autoPickupRef = AddToggle(TabItems, "Auto pick up", "Creates an invisible pickup zone around you", false, Items.SetAutoPickup, "AutoPickup")
Items.AutoPickupToggle = autoPickupRef

AddToggle(TabItems, "Auto Heal", "Uses healing items when HP drops", false, Items.SetAutoHeal, "AutoHeal")
AddToggle(TabItems, "Auto Sort", "Glove in slot 1, priority items next", false, Items.SetAutoSort, "AutoSort")
local _, permanentRef = AddToggle(TabItems, "Auto Use Permanent Items", "Uses permanent boosts on pickup", false, Items.SetAutoPermanentItems, "AutoPermanentItems")
autoPermanentToggle = permanentRef

AddButton(TabItems, "Use Spheres", "Uses all Sphere of Fury tools in your inventory", "circle", Items.UseSpheres)
AddButton(TabItems, "Use Cubes", "Uses all Cube of Ice tools in your inventory", "box", Items.UseCubes)
AddButton(TabItems, "Use All Items", "Uses every held game item quickly", "zap", Items.UseAllItems)
AddButton(TabItems, "Drop All Items", "Drops every held game item quickly", "trash-2", Items.DropAllItems)
AddButton(TabItems, "Drop Permanent Items", "Drops all permanent boost items quickly", "trash-2", Items.DropAllPermanents)
AddButton(TabItems, "Drop Temp Items", "Drops non-permanent held items quickly", "trash", Items.DropTempItems)
AddButton(TabItems, "Meteor Crate", "Teleports to nearest meteor crate", "box", Items.TeleportToCrate)

-- Teleports
AddButton(TabTeleports, "Teleport On School Bus", "Teleports you on top of the school bus", "bus-front", Teleport.ToSchoolBusTop)

-- Combat
AddSlider(TabCombat, "Hitbox Size", "Adjust hitbox size (10-20)", Combat.HitboxMinSize, Combat.HitboxMaxSize, Combat.HitboxSize, 1, Combat.SetHitboxSize)
AddToggle(TabCombat, "Expand Hitbox", "Applies expanded hitbox to players", false, Combat.SetHitboxExpanded, "ExpandHitbox")
AddToggle(TabCombat, "Visualize Hitboxes", "Shows neon hitbox preview", Combat.HitboxVisible, Combat.SetHitboxVisible, "VisualizeHitboxes")
AddToggle(TabCombat, "Slap Aura", "Slaps valid nearby match players", false, Combat.SetSlapAura, "SlapAura")
AddToggle(TabCombat, "Auto Slap", "Taps when enemy enters hitbox", false, Combat.SetAutoGloveTap, "AutoSlap")
AddButton(TabCombat, "Teleport To Lowest Health", "Teleports you behind the player with the lowest HP", "heart-pulse", Combat.TeleportToLowestHealthPlayer)
AddButton(TabCombat, "Teleport To Nearest", "Teleports you behind the closest player", "crosshair", Combat.TeleportToNearestPlayer)

-- BETA
AddButton(TabBETA, "Collect Crates", "Teleports under each crate and collects them in order", "box", Items.CollectCrates)
AddToggle(TabBETA, "Auto Slap Crates (Global)", "Automatically slaps all spawned meteor crates, regardless of your position", false, Items.SetFastCollectCrates, "FastCollectCrates")
AddToggle(TabBETA, "Crate Aura", "Slaps nearby meteor crates without teleporting", false, Items.SetCrateAura, "CrateAura")
local _, earlyCollectRef = AddToggle(TabBETA, "Early Auto Collect", "Starts collecting items before round begins", false, Items.SetEarlyAutoCollect, "EarlyAutoCollect")
Items.EarlyAutoCollectToggle = earlyCollectRef

-- Safety
AddButton(TabSafety, "Auto optimize cooldown settings", "Checks ping and updates cooldown settings", "gauge", Teleport.RunAutoOptimizeCooldownSettings)
AddToggle(TabSafety, "Anti-Staff", "Leaves when recording keywords detected", false, Anti.SetStaffEnabled, "AntiStaff")
AddToggle(TabSafety, "Hide under map", "Hides your character below the map", false, Anti.SetHideUnderMap, "HideUnderMap")
AddToggle(TabSafety, "Anti Knockback", "Blocks detected knockback and anti-ragdoll movement", false, Combat.SetAntiSlap, "AntiRagdoll")

-- Settings
AddButton(TabSettings, "Reset to default settings?", "Resets custom strikes, teleport debounce, and F lock", "rotate-ccw", function()
	Teleport.ResetCustomSettings()
	UI.SyncCustomSettingInputVisuals()
	createNotification("Settings", "Custom teleport settings reset to defaults.", "Success")
end)

UI.AddInput(TabSettings, "Custom strikes", "Teleports before the strike cooldown", Teleport.DefaultMaxStrikes, function(value)
	if not Teleport.SetCustomSetting("CustomStrikes", value) then
		createNotification("Settings", "Custom strikes needs a number.", "Warning")
	end
end, "CustomStrikes")

UI.AddInput(TabSettings, "Custom TP Debounce", "Seconds before teleporting to another object", Teleport.DefaultDebounce, function(value)
	if not Teleport.SetCustomSetting("CustomTPDebounce", value) then
		createNotification("Settings", "Custom TP Debounce needs a number.", "Warning")
	end
end, "CustomTPDebounce")

UI.AddInput(TabSettings, "Custom F Lock", "Seconds before F works again after teleporting", Teleport.DefaultPostFLock, function(value)
	if not Teleport.SetCustomSetting("CustomFLock", value) then
		createNotification("Settings", "Custom F Lock needs a number.", "Warning")
	end
end, "CustomFLock")

AddToggle(TabSettings, "Disable Notifications", "Disables normal notifications", false, function(state)
	NotificationsDisabled = state == true
end, "DisableNotifications")

local allThemeNames = {
	"Dark", "Light", "Rose", "Crimson", "Plant", "Indigo", "Sky", "Violet", "Amber",
	"Neon Orchid", "Cyber Lime", "Solar Flare", "Ocean Sync", "Rose Terminal",
	"Midnight Purple", "Sakura", "Arctic", "Ember", "Toxic", "Phantom", "Cotton Candy",
	"Void", "Sunset", "Matrix",
}
AddDropdown(TabSettings, "Theme", "Change the color theme", allThemeNames, Preferences.Theme or "Dark", applyTheme, "Theme")

task.defer(UI.SyncCustomSettingInputVisuals)
task.delay(0.35, UI.SyncCustomSettingInputVisuals)
task.defer(function()
	Items.SetAutoCollect(false, true)
	Items.SetAutoPickup(false, true)
	Items.SetAutoPermanentItems(false, true)
	Anti.SetHideUnderMap(false, true)

	if UI.ToggleRefs.AutoCollect then
		UI.ToggleRefs.AutoCollect.Set(false, false)
	end

	if UI.ToggleRefs.AutoPickup then
		UI.ToggleRefs.AutoPickup.Set(false, false)
	end

	if UI.ToggleRefs.AutoPermanentItems then
		UI.ToggleRefs.AutoPermanentItems.Set(false, false)
	end

	if UI.ToggleRefs.HideUnderMap then
		UI.ToggleRefs.HideUnderMap.Set(false, false)
	end
end)
task.defer(syncAllToggleVisuals)
task.delay(0.35, syncAllToggleVisuals)
task.delay(1, syncAllToggleVisuals)

if Preferences.TeleportMenuOpen then
	task.defer(openTeleportSideMenu)
end

if sharedEnvironment then
	sharedEnvironment.OPSlapRoyaleCleanup = function()
		pcall(function() Items.CleanupAutomation() end)
		pcall(function() Combat.SetAutoGloveTap(false) end)
		pcall(function() Combat.SetSlapAura(false, true) end)
		pcall(function() Combat.SetHitboxExpanded(false) end)
		pcall(function() Combat.SetAntiSlap(false) end)
		pcall(function() UI.SetPlayerStatsESP(false, true) end)
		pcall(function() UI.SetItemESP(false, true) end)
		pcall(function() UI.SetAutoRejoin(false, true) end)
		pcall(function() UI.SetInfiniteJump(false, true) end)
		pcall(function() Anti.SetStaffEnabled(false) end)
		pcall(function() Anti.DisableAcidLava() end)
		pcall(function() Anti.SetHideUnderMap(false) end)
		pcall(function() Teleport.ClearBusTopRidePlatform() end)
		pcall(function() closeTeleportSideMenu(true) end)
		pcall(function() clearUnderMapSafetyPlatform() end)
		pcall(function()
			MinimizedLauncher.Active = false
			if MinimizedLauncher.Gui then
				MinimizedLauncher.Gui:Destroy()
			end
		end)
		pcall(function()
			if WindUIWindow and type(WindUIWindow.Destroy) == "function" then
				WindUIWindow:Destroy()
			end
		end)
	end

	sharedEnvironment.OPSlapRoyale = {
		Window = WindUIWindow,
		Notify = Notify,
		UI = UI,
		Main = Main,
		Items = Items,
		Teleport = Teleport,
		Combat = Combat,
		Anti = Anti,
		Preferences = Preferences,
		TeleportMenu = TeleportMenu,
		MinimizedLauncher = MinimizedLauncher,
		Toggles = _windToggles,
		Sliders = _windSliders,
		Dropdowns = _windDropdowns,
	}
end
end)()
