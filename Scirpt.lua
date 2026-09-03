--[[
  Slap Battles Cheat – Full Integrated Version
  All original features + enhancements:
    - Scale your own glove (toggle + slider in Combat tab)
    - 3D Item ESP (SelectionBoxes) with "Only Handles" toggle
    - Master Auto toggle (disables all auto‑loops)
    - Reused ESP billboards (better performance)
    - ESP max distance slider
    - Configurable ESP colours (player & items)
    - Teleport cooldown display button
]]

-- ============================================================
-- SERVICES
-- ============================================================
local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    MarketplaceService = game:GetService("MarketplaceService"),
    ContextActionService = game:GetService("ContextActionService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    TeleportService = game:GetService("TeleportService"),
    GuiService = game:GetService("GuiService"),
    ProximityPromptService = game:GetService("ProximityPromptService"),
    HttpService = game:GetService("HttpService")
}

local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local MarketplaceService = Services.MarketplaceService
local ContextActionService = Services.ContextActionService
local ReplicatedStorage = Services.ReplicatedStorage
local ProximityPromptService = Services.ProximityPromptService
local HttpService = Services.HttpService
local player = Players.LocalPlayer

-- ============================================================
-- UNDER‑MAP PLATFORM
-- ============================================================
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

-- ============================================================
-- SHARED ENVIRONMENT & WINDUI
-- ============================================================
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

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
local NotificationsDisabled = false
local Notify = {}
function Notify.Show(title, message, kind, icon, duration, important)
    if NotificationsDisabled then return end
    local payload = {
        Title = tostring(title or "OP Slap Royale"),
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

-- ============================================================
-- UI TABLE & BASIC VARIABLES
-- ============================================================
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

-- ============================================================
-- UTILITY, MAIN, TELEPORT, ITEMS, COMBAT, ANTI
-- ============================================================
local Utility = {}
local Main = {}
local Teleport = {}
local Items = {}
local Combat = {}
local Anti = {}

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
function Utility.NormalizeName(text)
    return string.lower(tostring(text):gsub("’", "'"))
end

function Utility.GetObjectCFrame(object)
    if object:IsA("BasePart") then return object.CFrame end
    if object:IsA("Model") then return object:GetPivot() end
    if object:IsA("Tool") then
        local handle = object:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then return handle.CFrame end
    end
    local part = object:FindFirstChildWhichIsA("BasePart", true)
    return part and part.CFrame or nil
end

-- ============================================================
-- MAIN (Puzzle solver, timer, barn keypad)
-- ============================================================
Main.CodeKeywords = {
    "math", "equation", "problem", "code", "puzzle",
    "question", "solve", "answer", "number"
}
Main.CodeSearchOrigin = Vector3.new(464, 29, 323)
Main.CodeSearchRadius = 180
Main.KeypadSearchRadius = 170

function Main.IsCodeRelevantName(text)
    local lower = string.lower(tostring(text))
    for _, word in ipairs(Main.CodeKeywords) do
        if string.find(lower, word, 1, true) then return true end
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
    if exactNumber and #exactNumber <= 4 then return exactNumber end
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
        if scanned >= 120 then break end
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
            if Main.IsBarnSubmitButton(object, text) then score = 25 end
        elseif Main.TextMatchesDigit(text, target) then
            score = 25
        end
        if score > 0 then
            if string.find(full, "keypad", 1, true) then score += 8 end
            if string.find(full, "button", 1, true) then score += 5 end
            if string.find(full, "barn", 1, true) then score += 4 end
            if object:IsA("BasePart") then score += 2 end
            if score > bestScore then
                bestScore = score
                bestObject = object
            end
        end
    end
    return bestObject
end

function Main.ActivateBarnKeypadButton(button)
    if not button or not button.Parent then return false end
    local clicked = false
    for _, descendant in ipairs(button:GetDescendants()) do
        if descendant:IsA("ClickDetector") and type(fireclickdetector) == "function" then
            pcall(function() fireclickdetector(descendant); clicked = true end)
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
        pcall(function() fireclickdetector(button); clicked = true end)
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
    if code == "" then return false end
    local pressed = 0
    for digit in string.gmatch(code, "%d") do
        local button = Main.FindBarnKeypadButton(digit, false)
        if not Main.ActivateBarnKeypadButton(button) then return false end
        pressed += 1
        task.wait(0.09)
    end
    local submitButton = Main.FindBarnKeypadButton(nil, true)
    if not Main.ActivateBarnKeypadButton(submitButton) then return false end
    return pressed == #code
end

function Main.GetCountdownNumber(text)
    text = tostring(text or "")
    local exact = string.match(text, "^%s*(%d+)%s*$")
    if exact then return tonumber(exact) end
    local minutes, seconds = string.match(text, "^%s*(%d+)%s*:%s*(%d+)%s*$")
    if minutes and seconds then return tonumber(minutes) * 60 + tonumber(seconds) end
    return nil
end

function Main.GetTimerCandidateScore(object, number)
    if not number or number < 0 or number > 600 then return -1 end
    local score = 0
    local fullName = string.lower(object:GetFullName())
    local text = string.lower(tostring(object.Text))
    for _, word in ipairs({"timer", "time", "countdown", "count", "start", "starting", "bus", "round", "match"}) do
        if string.find(fullName, word, 1, true) then score += 10 end
        if string.find(text, word, 1, true) then score += 8 end
    end
    if object.Visible then score += 2 end
    if string.match(tostring(object.Text), "^%s*%d+%s*$") then score += 3 end
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
    if not playerGui then return nil, nil end
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
    if Main.TimerPrinterRunning then return end
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
            else
                Notify.Show("Barn Keypad", "Found code, but could not press every keypad button.", "Warning", nil, 4, true)
            end
        end
    end)
end

-- ============================================================
-- TELEPORT
-- ============================================================
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
    Notify.Show("Cooldown", "Wait " .. secondsText .. " before teleporting again.", "Warning", nil, 2.2, true)
end

function Teleport.ShowStabilityWarning(reason, secondsLeft)
    Notify.Show("Teleport", reason .. " Wait " .. tostring(math.max(1, math.ceil(secondsLeft))) .. " seconds.", "Warning", nil, 2.2, true)
end

function Teleport.IsLocalRagdolled(character, humanoid)
    if not character or not humanoid then return false end
    local ragdollStatuses = {"Ragdoll", "Ragdolled", "IsRagdolled", "Knocked", "KnockedDown", "Downed"}
    for _, statusName in ipairs(ragdollStatuses) do
        local characterAttribute = character:GetAttribute(statusName)
        local humanoidAttribute = humanoid:GetAttribute(statusName)
        if characterAttribute == true or humanoidAttribute == true then return true end
        local statusObject = character:FindFirstChild(statusName, true) or humanoid:FindFirstChild(statusName, true)
        if statusObject then
            if statusObject:IsA("BoolValue") then
                if statusObject.Value == true then return true end
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
    if Teleport.StabilityConnection then return end
    Teleport.StabilityConnection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - Teleport.LastStabilityCheckAt < Teleport.StabilityCheckInterval then return end
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
    if not ignoreStability and not Teleport.CanPassStabilityGate() then return false end
    if Teleport.IsLocked() then
        if not silent then Teleport.ShowWarning(tostring(Teleport.GetCooldownLeft())) end
        return false
    end
    local now = os.clock()
    local debounce = tonumber(debounceOverride or Teleport.Debounce) or 0
    local lastClickAt = tonumber(Teleport.LastClickAt) or 0
    local debounceLeft = debounce - (now - lastClickAt)
    if lastClickAt ~= 0 and debounceLeft > 0 then
        if not silent then Teleport.ShowWarning(tostring(math.max(1, math.ceil(debounceLeft)))) end
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
    Notify.Show("Cooldown", "Wait " .. string.format("%.1f", secondsLeft) .. " seconds before pressing F again.", "Warning", nil, 1.4, true)
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
    if not root or not root.Parent or not itemPart or not itemPart.Parent then return end
    local camera = workspace.CurrentCamera
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    if camera then
        local focus = itemPart.Position + Vector3.new(0, 0.8, 0)
        local ignore = { character }
        table.insert(ignore, itemPart)
        if itemPart.Parent then table.insert(ignore, itemPart.Parent) end
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = ignore
        pcall(function() rayParams.FilterType = Enum.RaycastFilterType.Exclude end)
        local overlapParams = OverlapParams.new()
        overlapParams.FilterDescendantsInstances = ignore
        pcall(function() overlapParams.FilterType = Enum.RaycastFilterType.Exclude end)
        local function isBlockingCameraPart(part)
            if not part or not part:IsA("BasePart") then return false end
            if character and part:IsDescendantOf(character) then return false end
            return part.CanCollide and part.Transparency < 0.95
        end
        local function isCameraSpotClear(position)
            local parts = workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(1.6, 1.6, 1.6), overlapParams)
            for _, part in ipairs(parts) do
                if isBlockingCameraPart(part) then return false end
            end
            local headPosition = root.Position + Vector3.new(0, 2.5, 0)
            local overheadHit = workspace:Raycast(headPosition, position - headPosition, rayParams)
            if overheadHit and isBlockingCameraPart(overheadHit.Instance) then return false end
            local viewHit = workspace:Raycast(position, focus - position, rayParams)
            if viewHit and isBlockingCameraPart(viewHit.Instance) and (viewHit.Position - focus).Magnitude > 2.5 then return false end
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
        if humanoid then camera.CameraSubject = humanoid end
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
            if part.CanCollide and part.Transparency < 0.95 then return false end
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
            if part ~= itemPart and part.CanCollide and part.Transparency < 0.95 then return false end
        end
        return true
    end
    local function canSeeItem(candidatePosition)
        local itemFocus = position + Vector3.new(0, 1, 0)
        local viewPosition = candidatePosition + Vector3.new(0, 1.6, 0)
        local direction = itemFocus - viewPosition
        if direction.Magnitude <= 0.1 then return true end
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
    if typeof(position) == "CFrame" then position = position.Position end
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
    if not candidate or not candidate.Parent then return parts end
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
    if object:IsA("BasePart") then return object.Position end
    if object:IsA("Model") then
        local ok, pivot = pcall(function() return object:GetPivot() end)
        if ok and pivot then return pivot.Position end
        local boxOk, cframe = pcall(function() return object:GetBoundingBox() end)
        if boxOk and cframe then return cframe.Position end
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
    if not topPart then return nil end
    local targetPosition = topPart.Position + Vector3.new(0, (topPart.Size.Y * 0.5) + 5, 0)
    local platformPosition = Vector3.new(topPart.Position.X, topY + 0.15, topPart.Position.Z)
    if candidate and candidate:IsA("Model") then
        local ok, boxCFrame, boxSize = pcall(function() return candidate:GetBoundingBox() end)
        if ok and boxCFrame and boxSize then
            targetPosition = Vector3.new(boxCFrame.Position.X, boxCFrame.Position.Y + (boxSize.Y * 0.5) + 5, boxCFrame.Position.Z)
            platformPosition = Vector3.new(boxCFrame.Position.X, boxCFrame.Position.Y + (boxSize.Y * 0.5) + 0.15, boxCFrame.Position.Z)
        end
    end
    return CFrame.new(targetPosition), CFrame.new(platformPosition), topPart
end

function Teleport.IsRootOnBusTopRide(root, platformCFrame)
    if not root or not platformCFrame then return false end
    local localPosition = platformCFrame:PointToObjectSpace(root.Position)
    return math.abs(localPosition.X) <= 18
        and math.abs(localPosition.Z) <= 18
        and localPosition.Y >= -4
        and localPosition.Y <= 12
end

function Teleport.CreateBusTopRidePlatform(candidate, parts, platformCFrame, topPart)
    Teleport.ClearBusTopRidePlatform()
    if not platformCFrame then return end
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
    if not Teleport.CanTeleport(Teleport.DefaultDebounce) then return end
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

-- ============================================================
-- ITEMS
-- ============================================================
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
Items.PriorityCollectRestoreAutoPermanent = { Auto = false, Early = false }
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
    if exactRoot then return exactRoot end
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
    if Items.SearchCacheRoot == root then return end
    Items.ClearSearchRootConnections()
    Items.SearchCacheRoot = root
    if not root then return end
    table.insert(Items.SearchCacheRootConnections, root.ChildAdded:Connect(Items.MarkSearchCacheDirty))
    table.insert(Items.SearchCacheRootConnections, root.ChildRemoved:Connect(Items.MarkSearchCacheDirty))
end

function Items.RebuildSearchCache()
    if Items.SearchCacheBusy then return end
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
    ["Bull's Essence"] = {"Bull's essence"},
    ["Sphere of Fury"] = {"Sphere of fury"}
}

local getFullCollectibleSearchPool
local getItemTeleportDiscoveryPool
local getStrictItemMatchObject

local function strictItemNameMatches(candidateName, wantedName)
    local normalizedCandidate = Utility.NormalizeName(candidateName)
    local normalizedWanted = Utility.NormalizeName(wantedName)
    if candidateName == wantedName or normalizedCandidate == normalizedWanted then return true end
    local aliases = itemNameAliases[wantedName]
    if aliases then
        for _, alias in ipairs(aliases) do
            local normalizedAlias = Utility.NormalizeName(alias)
            if candidateName == alias or normalizedCandidate == normalizedAlias then return true end
        end
    end
    return false
end

function Items.FindManualItem(itemName)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil end
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
    if not Teleport.CanTeleport(Items.TeleportDebounce) then return end
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
    if not crate or not crate.Parent or not crate:IsDescendantOf(workspace) then return nil end
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
    if part then Items.CratePartCache[crate] = part end
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
        if normalizedName == Utility.NormalizeName(itemName) then return true end
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
    if not cratesRoot or not object or not object:IsDescendantOf(cratesRoot) then return false end
    local current = object
    while current and current ~= cratesRoot do
        if current.Name == "Crate" and Items.GetCratePart(current) then return true end
        current = current.Parent
    end
    return false
end

function Items.GetShipmentCrates()
    local cratesRoot = Items.GetShipmentCratesRoot()
    local crates = {}
    if not cratesRoot then return crates end
    for _, object in ipairs(cratesRoot:GetChildren()) do
        if object.Name == "Crate" then
            table.insert(crates, object)
        end
    end
    return crates
end

function Items.GetTopItemObject(object)
    local root = Items.GetSearchRoot()
    if not root or not object or not object:IsDescendantOf(root) then return nil, root end
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
    if not crateRoot then return end
    local current = crateRoot.Parent
    while current and current ~= workspace do
        if Items.KnownCrates[current] then return end
        current = current.Parent
    end
    for knownCrate in pairs(Items.KnownCrates) do
        if knownCrate.Parent and knownCrate:IsDescendantOf(crateRoot) then
            Items.KnownCrates[knownCrate] = nil
        end
    end
    if Items.KnownCrates[crateRoot] then return end
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
        pcall(function() Items.FastCollectCratesBox:Destroy() end)
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
    if not cratePart or not cratePart.Parent or not root or not root.Parent then return false end
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
    if not root or not root.Parent then return parts end
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
    if Items.FastCollectCratesThread then return end
    Items.FastCollectCratesThread = task.spawn(function()
        while Items.FastCollectCratesEnabled do
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            Items.UpdateFastCollectCratesBox(root)
            if not Items.CollectCratesBusy then
                for _, cratePart in ipairs(Items.GetTrackedCrateParts(root)) do
                    if not Items.FastCollectCratesEnabled then break end
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
    if Items.CrateAuraThread then return end
    Items.CrateAuraThread = task.spawn(function()
        while Items.CrateAuraEnabled do
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if root then
                for _, cratePart in ipairs(Items.GetTrackedCrateParts(root)) do
                    if not Items.CrateAuraEnabled then break end
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
    if not Teleport.CanTeleport(Items.TeleportDebounce) then return end
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local crate, part = Items.FindNearestCrate()
    if not crate or not part then return end
    local targetPosition = part.Position + Vector3.new(0, (part.Size.Y / 2) + 4, 0)
    Teleport.MoveRoot(root, CFrame.new(targetPosition))
    Teleport.AddStrike()
    Teleport.StartFBlock()
end

function Items.ClearCrateCollectPart()
    if Items.CrateCollectPart then
        pcall(function() Items.CrateCollectPart:Destroy() end)
        Items.CrateCollectPart = nil
    end
end

function Items.GetCrateUnderMapCFrame(crate, cratePart)
    local centerPosition = cratePart.Position
    local bottomY = cratePart.Position.Y - (cratePart.Size.Y / 2)
    if crate and crate:IsA("Model") then
        local ok, modelCFrame, modelSize = pcall(function() return crate:GetBoundingBox() end)
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
    if not root then return false end
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
    if not crate or not crate.Parent or not crate:IsDescendantOf(workspace) then return true end
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
    if type(durability) == "number" and durability <= 0 then usedUp = true end
    local part = Items.GetCratePart(crate)
    if not part or not part.Parent or not part:IsDescendantOf(workspace) then return true end
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
    Items.CrateUsedCache[crate] = { At = now, Value = usedUp }
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
    if not crate or not crate.Parent then return false end
    local character = player.Character or player.CharacterAdded:Wait()
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local part = Items.GetCratePart(crate)
    if not root or not part then return false end
    local targetCFrame = Items.GetCrateUnderMapCFrame(crate, part)
    local platform = Items.EnsureCrateCollectPart(targetCFrame)
    if not platform or not platform.Parent then return false end
    Teleport.MoveRoot(root, targetCFrame, part.Position)
    return true
end

function Items.CollectSingleCrate(crate, alreadyTeleported)
    if not crate or not crate.Parent then return false end
    if Items.CrateHasActiveFire(crate) then return false end
    if not alreadyTeleported and not Items.TeleportUnderCrate(crate) then return false end
    local startedAt = os.clock()
    while not Items.IsCrateUsedUp(crate) and Items.CollectCratesBusy do
        if os.clock() - startedAt > 8 then break end
        if setMovementPaused then setMovementPaused(true) end
        local part = Items.GetCratePart(crate)
        if not part then break end
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
    if setMovementPaused then setMovementPaused(true) end
    task.spawn(function()
        local targets = Items.GetCrateCollectTargets()
        if #targets == 0 then
            createNotification("Collect Crates", "No crates found.", "Warning")
            Items.CollectCratesBusy = false
            if setMovementPaused then setMovementPaused(false) end
            Items.ClearCrateCollectPart()
            return
        end
        local crateCount = math.max(#targets, Items.CountShipmentCrates())
        local currentCrate = nil
        createNotification("Collect Crates", "Collecting " .. tostring(crateCount) .. " crate(s).", "Info")
        local function moveToCrate(crate)
            if not crate or not crate.Parent or not Items.GetCratePart(crate) then return false end
            if Items.TeleportUnderCrate(crate) then
                currentCrate = crate
                return true
            end
            return false
        end
        local firstReady = Items.GetReadyCrateTarget()
        moveToCrate(firstReady or Items.GetFirstLiveCrateTarget())
        while Items.CollectCratesBusy do
            if setMovementPaused then setMovementPaused(true) end
            if currentCrate and Items.IsCrateUsedUp(currentCrate) then currentCrate = nil end
            if not currentCrate then
                local readyCrate, liveCount = Items.GetReadyCrateTarget()
                if liveCount <= 0 then break end
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
        if setMovementPaused then setMovementPaused(false) end
        Items.MoveUnderMapAfterCrates()
        createNotification("Collect Crates", "Finished collecting crates.", "Success")
    end)
end

function Items.HasLiveCrateTargets()
    for _, crate in ipairs(Items.GetCrateCollectTargets()) do
        if crate and not Items.IsCrateUsedUp(crate) then return true end
    end
    return false
end

function Items.TryStartAutoCollectCrates()
    if not Items.FastCollectCratesEnabled or Items.CollectCratesBusy then return false end
    local now = os.clock()
    if now - (Items.AutoCollectCratesLastStart or 0) < Items.AutoCollectCratesStartCooldown then return false end
    if not Items.HasLiveCrateTargets() then return false end
    Items.AutoCollectCratesLastStart = now
    task.delay(0.2, function()
        if Items.FastCollectCratesEnabled and not Items.CollectCratesBusy then
            Items.CollectCrates()
        end
    end)
    return true
end

function Items.IsActiveCrateFireObject(object)
    if not object then return false end
    local objectName = Utility.NormalizeName(object.Name)
    if object:IsA("Fire") and object.Enabled ~= false then return true end
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
    if not crate or not crate.Parent then return false end
    local now = os.clock()
    local cached = Items.CrateFireCache[crate]
    if cached and now - cached.At < Items.CrateFireCacheInterval then
        return cached.Value
    end
    local hasFire = false
    if Items.IsActiveCrateFireObject(crate) then hasFire = true end
    if not hasFire then
        for _, object in ipairs(crate:GetDescendants()) do
            if Items.IsActiveCrateFireObject(object) then
                hasFire = true
                break
            end
        end
    end
    Items.CrateFireCache[crate] = { At = now, Value = hasFire }
    return hasFire
end

function Items.CanSlapCrate(cratePart)
    if not cratePart or not cratePart.Parent then return false end
    local crateRoot = Items.GetCrateRoot(cratePart) or cratePart
    if Items.CrateHasActiveFire(crateRoot) or Items.CrateHasActiveFire(cratePart) then return false end
    return true
end

function Items.SlapCrate(cratePart)
    local remote = Combat and Combat.GetSlapRemote and Combat.GetSlapRemote()
    if not remote or not cratePart or not cratePart.Parent then return false end
    if not Items.CanSlapCrate(cratePart) then return false end
    pcall(function() remote:FireServer(cratePart) end)
    local tool = Combat.GetEquippedTool and Combat.GetEquippedTool()
    if tool then pcall(function() tool:Activate() end) end
    return true
end

function Items.ScanCratesNow()
    local shipmentCratesRoot = Items.GetShipmentCratesRoot()
    if not shipmentCratesRoot then return end
    for _, object in ipairs(shipmentCratesRoot:GetChildren()) do
        if object.Name == "Crate" then
            Items.TrackCrate(object, false)
        end
    end
    Items.RefreshCrates()
end

function Items.ClearCrateWatcher()
    for _, connection in ipairs(Items.CrateWatcherConnections) do
        pcall(function() connection:Disconnect() end)
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
    if Items.CrateWatcherStarted or Items.CrateWatcherStarting then return end
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
        if not object or object.Name ~= "Crate" then return end
        task.defer(function() Items.TrackCrate(object, notify) end)
        task.delay(0.25, function() Items.TrackCrate(object, notify) end)
        task.delay(1, function() Items.TrackCrate(object, false) end)
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

-- ============================================================
-- ITEMS: Auto collect, pickup, heal, sort, permanents (condensed)
-- ============================================================
local normalizeName = Utility.NormalizeName

local itemNames = {
    "Apple", "Bandage", "Boba", "Bomb", "Bull's Essence",
    "Cube of Ice", "First Aid Kit", "Forcefield Crystal", "Frog Potion",
    "Gravitation Shard", "Healing Potion", "Lightning Potion",
    "Potion of Strength", "Speed Potion", "Sphere of Fury",
    "Tomahawk", "True Power", "Bombs"
}

local autoCollectPriority = {
    "True Power", "Potion of Strength", "Bull's Essence", "Boba",
    "Speed Potion", "Frog Potion", "Sphere of Fury", "Tomahawk",
    "Gravitation Shard", "Healing Potion", "First Aid Kit",
    "Cube of Ice", "Bomb", "Bombs", "Bandage", "Apple",
    "Forcefield Crystal", "Lightning Potion"
}

local function matchesItem(toolName, itemList)
    if not toolName or not itemList then return false end
    local normalized = normalizeName(toolName)
    for _, itemName in ipairs(itemList) do
        if normalized == normalizeName(itemName) then return true end
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
    if not object then return true end
    local now = os.clock()
    if ignoredCollectTargets[object] and ignoredCollectTargets[object] > now then return true end
    local current = object
    while current and current ~= workspace do
        if ignoredCollectTargets[current] and ignoredCollectTargets[current] > now then return true end
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
    if not part or not part.Parent or not part:IsDescendantOf(workspace) then return nil end
    if part.Transparency >= 0.95 or part.Size.X <= 0 or part.Size.Y <= 0 or part.Size.Z <= 0 then return nil end
    local characterModel = part:FindFirstAncestorOfClass("Model")
    if characterModel and Players:GetPlayerFromCharacter(characterModel) then return nil end
    return part
end

local function setMovementPaused(paused)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
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
    if itemObject then ignoredCollectTargets[itemObject] = ignoreUntil end
    if itemPart then ignoredCollectTargets[itemPart] = ignoreUntil end
    if itemPosition then
        table.insert(ignoredCollectPositions, { Position = itemPosition, Until = ignoreUntil })
        markVisitedCollectPosition(itemPosition)
    elseif itemPart then
        table.insert(ignoredCollectPositions, { Position = itemPart.Position, Until = ignoreUntil })
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
    "True Power", "Potion of Strength", "Bull's Essence",
    "Boba", "Speed Potion", "Frog Potion"
}

local secondaryCollectOrder = {
    "Sphere of Fury", "Tomahawk", "Gravitation Shard",
    "Healing Potion", "First Aid Kit", "Cube of Ice",
    "Bomb", "Bombs", "Bandage", "Apple",
    "Forcefield Crystal", "Lightning Potion"
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
                if getLiveItemPart(object) then leftCount += 1 end
            end
        end
        if totalCount > 0 then pinnedItemsEverSeen = true end
        totalPinned += totalCount
        leftPinned += leftCount
    end
    if totalPinned <= 0 then
        if Items.SearchCacheBusy and Items.LastSearchCacheAt == 0 then return 0 end
        return 1
    end
    return (totalPinned - leftPinned) / totalPinned
end

local function updateItemSearchMode()
    if searchAllItemsUnlocked then return end
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
    if not root then return nil, nil, nil, nil, nil end
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
                if getLiveItemPart(object) then remaining += 1 end
            end
        end
    end
    return remaining, total
end

function Items.ShouldFinishEarlyAutoCollectPermanents()
    local remaining, total = Items.GetPermanentCollectStatus()
    if total > 0 then Items.EarlyAutoCollectPermanentSeen = true end
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
    if checkTotal > 0 then Items.EarlyAutoCollectPermanentSeen = true end
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
    if not root then return nil, nil, nil, nil, nil end
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
    if not itemObject or not itemPart or not itemObject.Parent or not itemPart.Parent then return false end
    if not itemNameMatches(itemObject, wantedName) then return false end
    if itemObject:GetAttribute("Collected") == true
        or itemObject:GetAttribute("PickedUp") == true
        or itemObject:GetAttribute("Available") == false
        or itemObject:GetAttribute("Enabled") == false then return false end
    if not itemPart:IsDescendantOf(workspace)
        or itemPart.Transparency >= 0.95
        or itemPart.Size.X <= 0
        or itemPart.Size.Y <= 0
        or itemPart.Size.Z <= 0 then return false end
    local characterModel = itemPart:FindFirstAncestorOfClass("Model")
    if characterModel and Players:GetPlayerFromCharacter(characterModel) then return false end
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
            if Items.EarlyBusFBlockActive == true or Items.BusLandingFBlockActive == true then return end
            task.wait(0.03)
        end
        if not skipPickupLock and Items.IsPickupInputLocked and Items.IsPickupInputLocked() then return end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        pressed = true
    end)
    return pressed
end

function Items.TryPickupPrompt(itemObject, itemPart)
    if Items.IsPickupInputLocked and Items.IsPickupInputLocked() then return false end
    local promptList = {}
    local triggered = false
    local function addPrompts(root)
        if not root then return end
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
    if not playerGui then return nil end
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
    if not button then return false end
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
    if not itemPart or not itemPart.Parent then return false end
    local camera = workspace.CurrentCamera
    if not camera then return false end
    local basePosition = itemPart.Position
    local halfHeight = itemPart:IsA("BasePart") and (itemPart.Size.Y * 0.5) or 1
    if itemObject and itemObject.Parent and itemObject:IsA("Model") then
        local ok, modelCFrame, modelSize = pcall(function() return itemObject:GetBoundingBox() end)
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
            if tapped then return true end
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
    if not skipPickupLock and Items.IsPickupInputLocked() then return false end
    return pressF(skipPickupLock) == true
end

function Items.GetAutoPickupRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function Items.FindAutoPickupItemFromPart(touchedPart)
    if not touchedPart or not touchedPart.Parent then return nil end
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
    if not itemPart or not itemPart.Parent or not root then return false end
    local localPosition = root.CFrame:PointToObjectSpace(itemPart.Position)
    local halfItemSize = itemPart.Size * 0.5
    local halfZoneSize = 15
    return math.abs(localPosition.X) <= halfZoneSize + halfItemSize.X
        and math.abs(localPosition.Y) <= halfZoneSize + halfItemSize.Y
        and math.abs(localPosition.Z) <= halfZoneSize + halfItemSize.Z
end

function Items.TrackAutoPickupItem(itemObject, itemPart, itemName)
    if not itemObject or not itemPart or not itemName then return end
    Items.AutoPickupTouching[itemObject] = { Object = itemObject, Part = itemPart, Name = itemName }
end

function Items.ScanAutoPickupItems()
    local root = Items.GetAutoPickupRoot()
    if not root then return end
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
        pcall(function() Items.AutoPickupPart:Destroy() end)
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
        if itemObject then Items.AutoPickupTouching[itemObject] = nil end
    end)
    Items.AutoPickupFollowConnection = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - (Items.LastAutoPickupFollowAt or 0) < (Items.AutoPickupFollowInterval or 0.05) then return end
        Items.LastAutoPickupFollowAt = now
        local currentRoot = Items.GetAutoPickupRoot()
        if currentRoot and pickupPart.Parent then
            pickupPart.CFrame = currentRoot.CFrame
        end
    end)
    return pickupPart
end

function Items.StartAutoPickupThread()
    if Items.AutoPickupThread then return end
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
                        pcall(function() ProximityPromptService.Enabled = true end)
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
            if mode ~= "Auto" and os.clock() < (Items.EarlyAutoCollectPauseUntil or 0) then break end
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
    if notInLobby then Items.EarlyAutoCollectNotInLobby = true end
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
    if Items.FullPriorityCollectUnlocked then return end
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
    if Items.EarlyAutoCollectZeroPauseWatcherActive then return end
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
                if number <= 0 then break end
            elseif sawTimer and lastNumber and lastNumber <= 1
