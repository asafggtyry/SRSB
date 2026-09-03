--[[
  Slap Battles Cheat – WindUI Edition
  Features: Teleport, Auto Collect, ESP, Combat, Anti‑Ragdoll, Crates, Settings
]]

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- ─── Utilities ──────────────────────────────────────────────
local function normalize(s) return string.lower(tostring(s or "")) end
local function getRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function isRagdolled(character, humanoid)
    if not humanoid then return false end
    if humanoid.PlatformStand or humanoid:GetState() == Enum.HumanoidStateType.Ragdoll then return true end
    local statuses = { "Ragdoll", "Ragdolled", "IsRagdolled", "Knocked", "Downed" }
    for _, s in ipairs(statuses) do
        if character:GetAttribute(s) or humanoid:GetAttribute(s) then return true end
    end
    return false
end

local function moveRoot(root, position, lookAt)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    if lookAt then
        root.CFrame = CFrame.lookAt(root.Position, lookAt)
    else
        root.CFrame = CFrame.new(position)
    end
    task.wait()
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function getGroundCFrame(position, exclude)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = exclude or {}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -50, 0), params)
    local y = result and result.Position.Y + 4 or position.Y + 4
    return CFrame.new(position.X, y, position.Z)
end

-- ─── Teleport System ────────────────────────────────────────
local Teleport = {
    Cooldown = 3.5,
    Debounce = 0.5,
    PostFLock = 0.2,
    Strikes = 0,
    MaxStrikes = 4,
    LockedUntil = 0,
    LastClick = 0,
    BlockFUntil = 0,
    Locations = {
        { Name = "Barn", Position = Vector3.new(477, 87, 318) },
        { Name = "School", Position = Vector3.new(494, 47, -322) },
        { Name = "Volcano", Position = Vector3.new(-304, -26, 379) },
        { Name = "Tunnels", Position = Vector3.new(-561, -35, -234) },
        { Name = "Towers", Position = Vector3.new(-31, 93, 428) },
        { Name = "Acid", Position = Vector3.new(-113, 14, -625) },
    }
}

function Teleport:isLocked() return os.clock() < self.LockedUntil end

function Teleport:canTeleport(ignoreStability)
    if self:isLocked() then return false end
    local now = os.clock()
    if now - self.LastClick < self.Debounce then return false end
    self:resetStrikes()
    return true
end

function Teleport:resetStrikes()
    if os.clock() - self.LastClick >= self.Cooldown then
        self.Strikes = 0
        self.LockedUntil = 0
    end
end

function Teleport:addStrike()
    self.LastClick = os.clock()
    self.Strikes = self.Strikes + 1
    if self.Strikes >= self.MaxStrikes then
        self.LockedUntil = os.clock() + self.Cooldown
        self.Strikes = 0
    end
end

function Teleport:startFBlock(duration)
    duration = duration or self.PostFLock
    self.BlockFUntil = os.clock() + duration
    pcall(function() game:GetService("ProximityPromptService").Enabled = false end)
    task.delay(duration, function()
        if self.BlockFUntil <= os.clock() + 0.02 then
            pcall(function() game:GetService("ProximityPromptService").Enabled = true end)
        end
    end)
end

function Teleport:toLocation(name, position)
    if not self:canTeleport() then return end
    if typeof(position) ~= "Vector3" then
        for _, loc in ipairs(self.Locations) do
            if loc.Name == name then position = loc.Position; break end
        end
    end
    if not position then return end
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not root then return end
    local target = getGroundCFrame(position, { char })
    moveRoot(root, target.Position)
    self:addStrike()
    self:startFBlock()
    Notify("Teleport", "Teleported to " .. name, "Success")
end

function Teleport:toPlayer(targetPlayer)
    if not self:canTeleport() then return end
    local char = player.Character or player.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not root then return end
    local tChar = targetPlayer.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return end
    local target = getGroundCFrame(tRoot.Position, { char, tChar })
    moveRoot(root, target.Position, tRoot.Position)
    self:addStrike()
    self:startFBlock()
    Notify("Teleport", "Teleported to " .. targetPlayer.Name, "Success")
end

function Teleport:toNearestPlayer()
    local nearest, dist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local r = getRoot(p.Character)
            if r then
                local d = (player.Character and getRoot(player.Character).Position - r.Position).Magnitude or 0
                if d < dist then dist = d; nearest = p end
            end
        end
    end
    if nearest then self:toPlayer(nearest) end
end

function Teleport:toLowestHealth()
    local lowest, health = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local h = getHumanoid(p.Character)
            if h and h.Health > 0 and h.Health < health then
                health = h.Health; lowest = p
            end
        end
    end
    if lowest then self:toPlayer(lowest) end
end

-- ─── Combat System ──────────────────────────────────────────
local Combat = {
    HitboxSize = 10,
    HitboxExpanded = false,
    HitboxVisible = false,
    SlapAuraEnabled = false,
    AutoSlapEnabled = false,
    SlapRemote = nil,
    AntiRagdoll = false,
}

function Combat:getSlapRemote()
    local r = ReplicatedStorage:FindFirstChild("Remotes")
    return r and r:FindFirstChild("Slap")
end

function Combat:applyHitbox(target)
    local root = getRoot(target.Character)
    if not root then return end
    root.Size = Vector3.new(self.HitboxSize, self.HitboxSize, self.HitboxSize)
    root.Transparency = self.HitboxVisible and 0.7 or 1
    root.Color = Color3.fromRGB(0, 170, 255)
    root.Material = Enum.Material.Neon
    root.CanCollide = false
end

function Combat:resetHitbox(target)
    local root = getRoot(target.Character)
    if root then
        root.Size = Vector3.new(2, 2, 2)
        root.Transparency = 1
        root.Material = Enum.Material.Plastic
        root.CanCollide = true
    end
end

RunService.Heartbeat:Connect(function()
    if Combat.HitboxExpanded then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then Combat:applyHitbox(p) end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then Combat:resetHitbox(p) end
        end
    end
end)

task.spawn(function()
    while true do
        if Combat.SlapAuraEnabled then
            local remote = Combat:getSlapRemote()
            if remote then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and getRoot(p.Character) and (player.Character and getRoot(player.Character).Position - getRoot(p.Character).Position).Magnitude < 20 then
                        pcall(function() remote:FireServer(getRoot(p.Character)) end)
                    end
                end
            end
        end
        task.wait(0.3)
    end
end)

function Combat:autoSlapCheck()
    if not self.AutoSlapEnabled then return end
    local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
    if not tool then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local r = getRoot(p.Character)
            if r and (player.Character and getRoot(player.Character).Position - r.Position).Magnitude < 10 then
                pcall(function() tool:Activate() end)
                break
            end
        end
    end
end

RunService.Heartbeat:Connect(function() Combat:autoSlapCheck() end)

-- ─── Items & Collection ─────────────────────────────────────
local Items = {
    AutoCollect = false,
    AutoPickup = false,
    AutoHeal = false,
    AutoSort = false,
    AutoPermanent = false,
    PriorityItems = {
        "True Power", "Potion of Strength", "Bull's Essence", "Boba",
        "Speed Potion", "Frog Potion", "Sphere of Fury", "Tomahawk"
    },
    HealItems = { "First Aid Kit", "Healing Potion", "Apple", "Bandage" },
    PermanentItems = { "Potion of Strength", "Bull's Essence", "Boba", "Speed Potion", "Frog Potion" },
}

function Items:getSearchRoot()
    return workspace:FindFirstChild("Items") or workspace
end

function Items:findItem(name)
    local root = self:getSearchRoot()
    if not root then return nil, nil end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent and obj.Parent.Name == name then
            return obj.Parent, obj
        end
    end
    return nil, nil
end

function Items:collectItem(itemName)
    local obj, part = self:findItem(itemName)
    if not obj or not part then return false end
    local char = player.Character
    local root = getRoot(char)
    if not root then return false end
    local target = getGroundCFrame(part.Position, { char })
    moveRoot(root, target.Position, part.Position)
    Teleport:addStrike()
    Teleport:startFBlock(0.5)
    task.wait(0.2)
    -- Press F to pick up
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end)
    return true
end

task.spawn(function()
    while true do
        if Items.AutoCollect then
            for _, name in ipairs(Items.PriorityItems) do
                if Items:collectItem(name) then
                    task.wait(0.5)
                    break
                end
            end
        end
        task.wait(0.1)
    end
end)

function Items:autoHeal()
    if not self.AutoHeal then return end
    local char = player.Character
    local h = getHumanoid(char)
    if not h or h.Health > h.MaxHealth * 0.4 then return end
    for _, name in ipairs(self.HealItems) do
        local tool = char:FindFirstChild(name) or player.Backpack:FindFirstChild(name)
        if tool then
            pcall(function() tool:Activate() end)
            break
        end
    end
end

RunService.Heartbeat:Connect(function() Items:autoHeal() end)

function Items:autoPickup()
    if not self.AutoPickup then return end
    local char = player.Character
    local root = getRoot(char)
    if not root then return end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    local parts = workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(15, 15, 15), params)
    for _, part in ipairs(parts) do
        if part.Parent and part.Parent.Name ~= "HumanoidRootPart" then
            -- Simulate pressing F if near item
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(0.05)
                vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end)
            break
        end
    end
end

RunService.Heartbeat:Connect(function() Items:autoPickup() end)

function Items:autoSort()
    if not self.AutoSort then return end
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    local tools = {}
    for _, t in ipairs(backpack:GetChildren()) do
        if t:IsA("Tool") then table.insert(tools, t) end
    end
    table.sort(tools, function(a, b)
        local rank = function(name)
            for i, item in ipairs(Items.PriorityItems) do
                if normalize(name) == normalize(item) then return i end
            end
            return 99
        end
        return rank(a.Name) < rank(b.Name)
    end)
    for i, t in ipairs(tools) do
        t.Parent = backpack
        task.wait()
    end
end

Items:autoSort()  -- initial sort

-- ─── ESP ─────────────────────────────────────────────────────
local ESP = { Enabled = false, Players = {}, Items = {} }

function ESP:updatePlayerESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local char = p.Character
            local head = char and char:FindFirstChild("Head")
            if head then
                local bill = Instance.new("BillboardGui")
                bill.Size = UDim2.fromOffset(200, 50)
                bill.AlwaysOnTop = true
                bill.Adornee = head
                bill.Parent = head
                local label = Instance.new("TextLabel")
                label.Size = UDim2.fromScale(1, 1)
                label.BackgroundTransparency = 1
                label.TextColor3 = Color3.new(1, 1, 1)
                label.TextStrokeTransparency = 0
                label.Font = Enum.Font.GothamBlack
                label.TextSize = 16
                label.Text = p.Name .. "\nHP: " .. (getHumanoid(char) and math.floor(getHumanoid(char).Health) or "?")
                label.Parent = bill
                task.delay(0.5, function() bill:Destroy() end) -- cleanup old
            end
        end
    end
end

task.spawn(function()
    while true do
        if ESP.Enabled then ESP:updatePlayerESP() end
        task.wait(1)
    end
end)

-- ─── Notifications ──────────────────────────────────────────
local Notify = function(title, msg, kind)
    if not WindUI then return end
    pcall(function()
        WindUI:Notify({ Title = title, Content = msg, Icon = kind or "info" })
    end)
end

-- ─── GUI ─────────────────────────────────────────────────────
local window = WindUI:CreateWindow({
    Title = "Slap Battles Cheat",
    Icon = "swords",
    Folder = "SlapBattles",
    Size = UDim2.fromOffset(500, 400),
    ToggleKey = Enum.KeyCode.RightControl,
})

local mainTab = window:Tab({ Title = "Main", Icon = "home" })
local itemsTab = window:Tab({ Title = "Items", Icon = "box" })
local combatTab = window:Tab({ Title = "Combat", Icon = "swords" })
local settingsTab = window:Tab({ Title = "Settings", Icon = "sliders" })

-- ─── Main Tab ──────────────────────────────────────────────
mainTab:Button({ Title = "Teleport to Nearest Player", Callback = function() Teleport:toNearestPlayer() end })
mainTab:Button({ Title = "Teleport to Lowest Health", Callback = function() Teleport:toLowestHealth() end })

local locDropdown = mainTab:Dropdown({
    Title = "Teleport to Location",
    Values = { "Barn", "School", "Volcano", "Tunnels", "Towers", "Acid" },
    Callback = function(value)
        Teleport:toLocation(value)
    end
})

mainTab:Toggle({
    Title = "Player Stats ESP",
    Value = false,
    Callback = function(state) ESP.Enabled = state end
})

-- ─── Items Tab ─────────────────────────────────────────────
itemsTab:Toggle({
    Title = "Auto Collect Priority Items",
    Value = false,
    Callback = function(state) Items.AutoCollect = state end
})

itemsTab:Toggle({
    Title = "Auto Pickup",
    Value = false,
    Callback = function(state) Items.AutoPickup = state end
})

itemsTab:Toggle({
    Title = "Auto Heal",
    Value = false,
    Callback = function(state) Items.AutoHeal = state end
})

itemsTab:Toggle({
    Title = "Auto Sort Inventory",
    Value = false,
    Callback = function(state) Items.AutoSort = state end
})

itemsTab:Toggle({
    Title = "Auto Use Permanent Items",
    Value = false,
    Callback = function(state)
        Items.AutoPermanent = state
        if state then
            task.spawn(function()
                while Items.AutoPermanent do
                    for _, name in ipairs(Items.PermanentItems) do
                        local tool = player.Backpack:FindFirstChild(name) or (player.Character and player.Character:FindFirstChild(name))
                        if tool then
                            pcall(function() tool:Activate() end)
                            task.wait(0.1)
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end
})

itemsTab:Button({ Title = "Use All Spheres", Callback = function()
    for _, t in ipairs(player.Backpack:GetChildren()) do
        if t:IsA("Tool") and normalize(t.Name):find("sphere") then
            pcall(function() t:Activate() end)
            task.wait(0.1)
        end
    end
end })

itemsTab:Button({ Title = "Drop All Items", Callback = function()
    for _, t in ipairs(player.Backpack:GetChildren()) do
        if t:IsA("Tool") then
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                task.wait(0.05)
                vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
            end)
            task.wait(0.05)
        end
    end
end })

-- ─── Combat Tab ─────────────────────────────────────────────
combatTab:Toggle({
    Title = "Slap Aura",
    Value = false,
    Callback = function(state) Combat.SlapAuraEnabled = state end
})

combatTab:Toggle({
    Title = "Auto Slap",
    Value = false,
    Callback = function(state) Combat.AutoSlapEnabled = state end
})

combatTab:Toggle({
    Title = "Expand Hitbox",
    Value = false,
    Callback = function(state) Combat.HitboxExpanded = state end
})

combatTab:Toggle({
    Title = "Visualize Hitboxes",
    Value = false,
    Callback = function(state) Combat.HitboxVisible = state end
})

combatTab:Slider({
    Title = "Hitbox Size",
    Value = { Min = 10, Max = 20, Default = 10 },
    Callback = function(value) Combat.HitboxSize = value end
})

combatTab:Toggle({
    Title = "Anti-Ragdoll (box cage)",
    Value = false,
    Callback = function(state)
        Combat.AntiRagdoll = state
        if state then
            task.spawn(function()
                while Combat.AntiRagdoll do
                    local char = player.Character
                    local h = getHumanoid(char)
                    if h and isRagdolled(char, h) then
                        -- Create invisible box to prevent knockback
                        local box = Instance.new("Part")
                        box.Size = Vector3.new(6, 6, 6)
                        box.CFrame = getRoot(char).CFrame
                        box.Anchored = true
                        box.CanCollide = true
                        box.Transparency = 1
                        box.Parent = workspace
                        task.delay(1, function() box:Destroy() end)
                    end
                    task.wait(0.5)
                end
            end)
        end
    end
})

-- ─── Settings Tab ───────────────────────────────────────────
settingsTab:Toggle({
    Title = "Disable Notifications",
    Value = false,
    Callback = function(state)
        NotificationsDisabled = state
    end
})

-- Theme dropdown
settingsTab:Dropdown({
    Title = "Theme",
    Values = { "Dark", "Light", "Void", "Matrix", "Sunset" },
    Value = "Dark",
    Callback = function(value)
        pcall(function()
            window:SetTheme(value)
            Notify("Theme", "Changed to " .. value, "Success")
        end)
    end
})

-- ─── Auto‑Rejoin (optional) ──────────────────────────────────
settingsTab:Toggle({
    Title = "Auto Rejoin on Death",
    Value = false,
    Callback = function(state)
        if state then
            local con
            con = player.CharacterAdded:Connect(function()
                task.delay(2, function()
                    if not player.Character or not getHumanoid(player.Character) or getHumanoid(player.Character).Health <= 0 then
                        TeleportService:Teleport(game.PlaceId, player)
                    end
                end)
            end)
            _G.AutoRejoinCon = con
        else
            if _G.AutoRejoinCon then _G.AutoRejoinCon:Disconnect() end
        end
    end
})

print("Slap Battles Cheat loaded. Press RightControl to toggle GUI.")
