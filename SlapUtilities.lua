-- Slap Utilities. Client dashboard, no external UI downloads.
-- RightShift: show/hide. Drag the header to move.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TeleportService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local GUI_NAME = "SlapUtilitiesDashboard"
local VERSION = "3.0"
local UT_PLACE = 115782629143468
local BLOCK_POSITION = Vector3.new(0, 187, 31)

local old = playerGui:FindFirstChild(GUI_NAME)
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local C = {
    bg = Color3.fromRGB(19, 20, 22), side = Color3.fromRGB(16, 17, 19),
    card = Color3.fromRGB(26, 27, 30), input = Color3.fromRGB(31, 33, 37),
    line = Color3.fromRGB(47, 49, 54), text = Color3.fromRGB(235, 237, 240),
    muted = Color3.fromRGB(148, 153, 164), accent = Color3.fromRGB(154, 172, 196),
}
local alive, connections = true, {}
local selectionOutline
local function bind(signal, fn)
    local connection = signal:Connect(fn)
    table.insert(connections, connection)
    return connection
end
local originalCamera = workspace.CurrentCamera
local originalFov = originalCamera and originalCamera.FieldOfView
local changedFov = false
local function restoreFov()
    if changedFov and originalCamera and originalCamera.Parent then
        originalCamera.FieldOfView = originalFov
    end
    changedFov = false
end
gui.Destroying:Connect(function()
    alive = false
    if selectionOutline then selectionOutline:Destroy() selectionOutline = nil end
    restoreFov()
    for _, connection in ipairs(connections) do connection:Disconnect() end
end)
local function make(class, parent, props)
    local object = Instance.new(class)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function round(object, radius)
    make("UICorner", object, {CornerRadius = UDim.new(0, radius or 10)})
end
local function stroke(object)
    make("UIStroke", object, {
        Color = C.line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end
local function text(parent, value, x, y, w, h, size, color)
    return make("TextLabel", parent, {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), Font = Enum.Font.GothamMedium,
        Text = value, TextSize = size or 13, TextColor3 = color or C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end
local function button(parent, value, x, y, w, h, callback)
    local object = make("TextButton", parent, {
        BackgroundColor3 = C.input, BorderSizePixel = 0,
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        Text = value, TextSize = 12, Font = Enum.Font.GothamMedium,
        TextColor3 = C.text, AutoButtonColor = false,
    })
    round(object, 8)
    stroke(object)
    bind(object.MouseEnter, function() object.BackgroundColor3 = C.line end)
    bind(object.MouseLeave, function() object.BackgroundColor3 = C.input end)
    bind(object.Activated, callback)
    return object
end
local function box(parent, placeholder, x, y, w, h)
    local object = make("TextBox", parent, {
        BackgroundColor3 = C.input, BorderSizePixel = 0,
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        Text = "", PlaceholderText = placeholder, PlaceholderColor3 = C.muted,
        TextColor3 = C.text, TextSize = 12, Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
    })
    round(object, 8)
    stroke(object)
    return object
end
local function card(parent, x, y, w, h)
    local frame = make("Frame", parent, {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = C.card, BorderSizePixel = 0,
    })
    round(frame, 12)
    stroke(frame)
    return frame
end

local root = make("Frame", gui, {
    Size = UDim2.fromOffset(820, 520), Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.bg,
    BorderSizePixel = 0, ClipsDescendants = true, Active = true,
})
round(root, 18)
stroke(root)
local scale = make("UIScale", root, {Scale = 1})
local function fit()
    local camera = workspace.CurrentCamera
    if camera then
        local view = camera.ViewportSize
        scale.Scale = math.min(1, math.max(0.1, math.min((view.X - 24) / 820, (view.Y - 24) / 520)))
    end
end
fit()
local side = make("Frame", root, {
    Size = UDim2.new(0, 180, 1, 0), BackgroundColor3 = C.side, BorderSizePixel = 0,
})
text(side, "SLAP UTILITIES", 18, 20, 150, 24, 14)
text(side, player.DisplayName, 18, 48, 146, 22, 12, C.muted)
make("Frame", side, {
    Position = UDim2.fromOffset(16, 86), Size = UDim2.fromOffset(148, 1),
    BackgroundColor3 = C.line, BorderSizePixel = 0,
})
text(side, "SESSION TOOLS  /  " .. VERSION, 18, 104, 146, 20, 10, C.muted)
text(side, "RightShift to show / hide", 18, 452, 150, 20, 10, C.muted)
text(side, "Drag the top bar to move", 18, 474, 150, 20, 10, C.muted)

local header = make("Frame", root, {
    Position = UDim2.fromOffset(180, 0), Size = UDim2.fromOffset(548, 62),
    BackgroundTransparency = 1, Active = true,
})
local breadcrumb = text(header, "Utilities / Dashboard", 22, 0, 470, 62, 12, C.muted)
button(root, "-", 734, 18, 30, 28, function() root.Visible = false end)
button(root, "x", 772, 18, 30, 28, function() gui:Destroy() end)
local status = text(root, "Ready", 202, 478, 596, 28, 11, C.muted)
status.TextWrapped = true
local function message(value) status.Text = value end

local pages, nav, onShow = {}, {}, {}
local function page(name)
    local frame = make("Frame", root, {
        Name = name, Position = UDim2.fromOffset(202, 70),
        Size = UDim2.fromOffset(596, 402), BackgroundTransparency = 1, Visible = false,
    })
    pages[name] = frame
    return frame
end
local function show(name)
    for key, frame in pairs(pages) do frame.Visible = key == name end
    for key, item in pairs(nav) do
        item.TextColor3 = key == name and C.text or C.muted
        item.BackgroundTransparency = key == name and 0 or 1
    end
    breadcrumb.Text = "Utilities / " .. name
    if onShow[name] then onShow[name]() end
end
for index, name in ipairs({"Dashboard", "Gloves", "Hitman", "Obtainments", "Rewards", "Mastery", "Bounties", "Utilities"}) do
    local key = name
    nav[key] = button(side, key, 12, 126 + (index - 1) * 38, 156, 32, function() show(key) end)
end

-- Slap tracking reads replicated stats. Missing stats display as unavailable.
local function stat(name)
    local folder = player:FindFirstChild("leaderstats")
    if not folder then return nil end
    for _, object in ipairs(folder:GetChildren()) do
        if object.Name:lower() == name:lower() then return object end
    end
end
local function slaps()
    local object = stat("Slaps")
    if object and (object:IsA("IntValue") or object:IsA("NumberValue")) then
        return object.Value
    end
end
local function number(value)
    if value == nil then return "Unavailable" end
    local valueText = tostring(math.floor(value))
    while true do
        local formatted, count = valueText:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        valueText = formatted
        if count == 0 then return valueText end
    end
end
local function duration(seconds)
    seconds = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end
local started, last, earned = os.clock(), nil, 0
local gains, log = {}, {}
local goal, goalNotified = nil, false
local home = page("Dashboard")
text(home, "Session overview", 0, 0, 596, 30, 23)
text(home, "Live slap totals and progress toward your next goal.", 0, 35, 596, 24, 12, C.muted)
local a = card(home, 0, 76, 190, 94)
local b = card(home, 202, 76, 190, 94)
local c = card(home, 404, 76, 192, 94)
text(a, "TOTAL SLAPS", 14, 12, 166, 20, 10, C.muted)
text(b, "SESSION EARNED", 14, 12, 166, 20, 10, C.muted)
text(c, "SLAPS / MIN", 14, 12, 166, 20, 10, C.muted)
local totalLabel = text(a, "Unavailable", 14, 40, 166, 36, 23)
local earnedLabel = text(b, "0", 14, 40, 166, 36, 23)
local rateLabel = text(c, "0.0", 14, 40, 166, 36, 23)
local goalCard = card(home, 0, 184, 596, 112)
text(goalCard, "Slap goal", 14, 9, 150, 24, 14)
local goalInput = box(goalCard, "Target total", 14, 40, 140, 30)
button(goalCard, "Set goal", 164, 40, 86, 30, function()
    local value = tonumber((goalInput.Text:gsub(",", "")))
    if not value or value ~= value or value == math.huge or value < 1 then
        message("Enter a positive slap total.")
        return
    end
    goal, goalNotified = math.floor(value), false
    message("Goal set to " .. number(goal) .. " slaps.")
end)
local progressLabel = text(goalCard, "No goal set", 266, 40, 314, 30, 12, C.muted)
local track = make("Frame", goalCard, {
    Position = UDim2.fromOffset(14, 86), Size = UDim2.fromOffset(568, 6),
    BackgroundColor3 = C.line, BorderSizePixel = 0, ClipsDescendants = true,
})
round(track, 3)
local fill = make("Frame", track, {
    Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0,
})
round(fill, 3)
local activity = card(home, 0, 310, 596, 90)
local sessionLabel = text(activity, "Session 00:00:00", 14, 8, 340, 22, 12)
local activityLabel = text(activity, "Waiting for slap data...", 14, 34, 450, 46, 11, C.muted)
activityLabel.TextWrapped = true
activityLabel.TextYAlignment = Enum.TextYAlignment.Top
button(activity, "Reset tracker", 464, 12, 116, 30, function()
    started, last, earned = os.clock(), slaps(), 0
    gains, log, goalNotified = {}, {}, false
    message("Session tracker reset.")
end)

-- BACKPACK GUI ADAPTER
local function normalize(value)
    return tostring(value or ""):gsub("<[^>]+>", ""):lower():gsub("[^%w]", "")
end
local function external(object)
    return object ~= gui and object:IsDescendantOf(playerGui) and not object:IsDescendantOf(gui)
end
local function backpackContext(object)
    local current = object
    while current and current ~= playerGui do
        local name = normalize(current.Name)
        if name:find("backpack", 1, true) or name:find("inventory", 1, true)
            or name:find("gloveselect", 1, true) or name:find("glovemenu", 1, true) then
            return true
        end
        current = current.Parent
    end
    return false
end
-- Exact PlayerGui paths from the supplied GUI dump.
-- Several ScreenGuis share the name Component, so resolve every matching branch.
local function nativeMatches(path)
    local nodes = {playerGui}
    for segment in path:gmatch("[^.]+") do
        local nextNodes = {}
        for _, parent in ipairs(nodes) do
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name == segment and external(child) then
                    table.insert(nextNodes, child)
                end
            end
        end
        nodes = nextNodes
    end
    return nodes
end
local function shown(object, stopAt)
    local current = object
    while current and current ~= playerGui do
        if current:IsA("GuiObject") and not current.Visible then return false end
        if current:IsA("ScreenGui") and not current.Enabled then return false end
        if current == stopAt then break end
        current = current.Parent
    end
    return object ~= nil and object.Parent ~= nil
end
local function nativeOne(path)
    local matches = nativeMatches(path)
    if #matches == 1 then return matches[1] end
    local visible = {}
    for _, object in ipairs(matches) do
        if shown(object) then table.insert(visible, object) end
    end
    if #visible == 1 then return visible[1] end
end
local function cleanText(value)
    return tostring(value or ""):gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")
end
local function nativeText(path)
    local object = nativeOne(path)
    if object and (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
        return cleanText(object.Text)
    end
    return ""
end
local function controlReady(object, stopAt)
    if not object or not object:IsA("GuiButton") or not object.Active or not shown(object, stopAt) then
        return false
    end
    local ok, interactable = pcall(function() return object.Interactable end)
    return not ok or interactable ~= false
end

local function nearestButton(object)
    local current = object
    while current and current ~= playerGui do
        if current:IsA("GuiButton") then return current end
        current = current.Parent
    end
end
local function reveal(object)
    local current = object
    while current and current ~= playerGui do
        if current:IsA("GuiObject") then current.Visible = true end
        if current:IsA("CanvasGroup") then current.GroupTransparency = 0 end
        if current:IsA("ScreenGui") then current.Enabled = true end
        current = current.Parent
    end
end
local function clearOutline()
    if selectionOutline then selectionOutline:Destroy() selectionOutline = nil end
end
local function highlight(object)
    clearOutline()
    selectionOutline = make("UIStroke", object, {
        Name = "SlapUtilitiesSelection", Color = C.accent, Thickness = 2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end
local function activateGuiButton(object)
    if not object or not object.Parent or not external(object) or not object:IsA("GuiButton") then
        return false, "The game button is no longer available. Refresh first."
    end
    if not object.Active then return false, "The game button is disabled." end
    local checked, interactable = pcall(function() return object.Interactable end)
    if checked and interactable == false then return false, "The game button is disabled." end
    reveal(object)
    highlight(object)
    -- Use the existing GUI callbacks, never guessed remote arguments.
    if type(getconnections) == "function" then
        for _, signal in ipairs({object.Activated, object.MouseButton1Click}) do
            local ok, callbacks = pcall(getconnections, signal)
            if ok and type(callbacks) == "table" then
                local fired = false
                for _, connection in ipairs(callbacks) do
                    local success, ran = pcall(function()
                        if connection.Enabled == false then return false end
                        if type(connection.Fire) == "function" then
                            connection:Fire()
                            return true
                        end
                        if type(connection.Function) == "function" then
                            connection.Function()
                            return true
                        end
                        return false
                    end)
                    if success and ran then fired = true end
                end
                if fired then return true, "Existing game button activated." end
            end
        end
    end
    root.Visible = false
    return false, "Click the outlined game control. RightShift restores this window."
end
local function equippedName()
    local character = player.Character
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if tool:IsA("Tool") then return tool.Name end
        end
    end
    local glove = stat("Glove")
    if glove and glove:IsA("StringValue") then return glove.Value end
end
local function findBackpackButton(name)
    local target = normalize(name)
    local matches, seen = {}, {}
    if target == "" then return nil, "Select a glove first." end
    for _, object in ipairs(playerGui:GetDescendants()) do
        if external(object) and object:IsA("GuiObject") and backpackContext(object) then
            local named = normalize(object.Name) == target
            local caption = (object:IsA("TextLabel") or object:IsA("TextButton"))
                and normalize(object.Text) == target
            local attributed = normalize(object:GetAttribute("GloveName")) == target
                or normalize(object:GetAttribute("ToolName")) == target
            if named or caption or attributed then
                local candidate = nearestButton(object)
                if not candidate then
                    -- Some cards keep the Equip button beside the name label.
                    local container = object.Parent
                    if container and container:IsA("GuiObject") then
                        local choices = {}
                        for _, child in ipairs(container:GetDescendants()) do
                            if child:IsA("GuiButton") then
                                local key = normalize(child.Name)
                                if child:IsA("TextButton") then key = key .. normalize(child.Text) end
                                if key:find("equip", 1, true) or key:find("select", 1, true) then
                                    table.insert(choices, child)
                                end
                            end
                        end
                        if #choices == 1 then candidate = choices[1] end
                    end
                end
                if candidate and not seen[candidate] then
                    seen[candidate] = true
                    table.insert(matches, candidate)
                end
            end
        end
    end
    if #matches == 1 then return matches[1] end
    if #matches > 1 then
        return nil, "Several backpack buttons match. Open the desired backpack panel and select the glove there."
    end
    return nil, "No matching backpack button is loaded. Open the game's backpack, then Refresh."
end
local function equipThroughBackpack(name)
    if normalize(equippedName()) == normalize(name) then
        message(name .. " is already equipped.") return
    end
    local target, problem = findBackpackButton(name)
    if not target then message(problem) return end
    local sent, result = activateGuiButton(target)
    message(result)
    if sent then
        task.delay(0.4, function()
            if not alive then return end
            if normalize(equippedName()) == normalize(name) then
                message("Equipped " .. name .. " through the backpack GUI.")
            else
                message("Backpack button activated for " .. name .. ". Finish any selection or requirement shown by the game.")
            end
        end)
    end
end

-- Native inventory uses Content -> selected InfoFrame.ItemName -> EquipButton.
do
    local genericEquip = equipThroughBackpack
    local base = "InventoryGui.InventoryWindow"
    local function currentInfo()
        return nativeOne(base .. ".InfoFrame")
    end
    local function infoName(info)
        local title = info and info:FindFirstChild("ItemName")
        return title and title:IsA("TextLabel") and cleanText(title.Text) or ""
    end
    local function equipButton(info)
        if not info then return nil end
        local choices = {}
        local primary = info:FindFirstChild("EquipButton")
        local buttons = info:FindFirstChild("Buttons")
        local alternate = buttons and buttons:FindFirstChild("Equip")
        if controlReady(primary, info) then table.insert(choices, primary) end
        if controlReady(alternate, info) then table.insert(choices, alternate) end
        if #choices == 1 then return choices[1] end
        return nil, #choices > 1 and "Multiple Equip buttons are active. Select the intended item in the game's inventory."
            or "The selected item's Equip button is hidden or disabled. Check the game's item requirements."
    end
    local function nativeSlot(name)
        local content = nativeOne(base .. ".Content")
        if not content then return nil end
        local matches, seen = {}, {}
        local target = normalize(name)
        for _, object in ipairs(content:GetDescendants()) do
            local titleMatch = (object:IsA("TextLabel") or object:IsA("TextButton"))
                and normalize(object.Text) == target
            if titleMatch or normalize(object.Name) == target
                or normalize(object:GetAttribute("GloveName")) == target
                or normalize(object:GetAttribute("ToolName")) == target then
                local candidate = nearestButton(object)
                if candidate and candidate:IsDescendantOf(content) and not seen[candidate] then
                    seen[candidate] = true
                    table.insert(matches, candidate)
                end
            end
        end
        if #matches == 1 then return matches[1] end
        local visible = {}
        for _, candidate in ipairs(matches) do
            if shown(candidate, content) then table.insert(visible, candidate) end
        end
        if #visible == 1 then return visible[1] end
    end
    local equipping = false
    equipThroughBackpack = function(name)
        if equipping then message("An inventory selection is already in progress.") return end
        if normalize(equippedName()) == normalize(name) then
            message(name .. " is already equipped.") return
        end
        if not nativeOne(base) then genericEquip(name) return end
        local info = currentInfo()
        local function pressEquip()
            local latest = currentInfo()
            if normalize(infoName(latest)) ~= normalize(name) then
                message("The selected inventory item changed. Equip cancelled.") return
            end
            local target, problem = equipButton(latest)
            if not target then message(problem) return end
            local sent, result = activateGuiButton(target)
            message(result)
            if sent then
                task.delay(0.5, function()
                    if not alive then return end
                    if normalize(equippedName()) == normalize(name) then
                        message("Equipped " .. name .. " through the inventory GUI.")
                    else
                        local warning = latest and latest:FindFirstChild("GloveEquipWarning")
                        local warningText = warning and shown(warning, latest) and cleanText(warning.Text) or ""
                        message(warningText ~= "" and warningText or "Equip button activated. Waiting for the game's inventory update.")
                    end
                end)
            end
        end
        if info and normalize(infoName(info)) == normalize(name) then pressEquip() return end
        local slot = nativeSlot(name)
        if not slot then
            message("Open the game's inventory, select " .. name .. ", then press Equip through backpack again.") return
        end
        local sent, result = activateGuiButton(slot)
        message(result)
        if not sent then return end
        equipping = true
        task.spawn(function()
            local deadline = os.clock() + 2
            while alive and os.clock() < deadline do
                local latest = currentInfo()
                if latest and normalize(infoName(latest)) == normalize(name) then
                    equipping = false
                    pressEquip()
                    return
                end
                task.wait(0.1)
            end
            equipping = false
            if alive then message("Inventory selection did not update. Select the item in-game, then retry Equip.") end
        end)
    end
end

local gloves = page("Gloves")
text(gloves, "Backpack gloves", 0, 0, 596, 30, 23)
text(gloves, "Select a glove, then activate its existing backpack button.", 0, 35, 596, 24, 12, C.muted)
local search = box(gloves, "Search backpack gloves", 0, 74, 440, 34)
local list = make("ScrollingFrame", gloves, {
    Position = UDim2.fromOffset(0, 120), Size = UDim2.fromOffset(596, 222),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.muted, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
make("UIListLayout", list, {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
local detail = text(gloves, "Open the game's backpack before refreshing.", 0, 348, 596, 20, 11, C.muted)
local selected, entries = nil, {}
local function rootPart()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end
local function renderList()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end
    local query, count = normalize(search.Text), 0
    for _, entry in ipairs(entries) do
        if normalize(entry.name):find(query, 1, true) then
            count = count + 1
            local row = make("TextButton", list, {
                Size = UDim2.new(1, -8, 0, 38), BackgroundColor3 = C.card,
                BorderSizePixel = 0, Text = "", LayoutOrder = count,
            })
            round(row, 8)
            local nameLabel = text(row, entry.name, 12, 0, 354, 38, 12)
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            text(row, entry.kind, 374, 0, 194, 38, 10, C.muted)
            row.Activated:Connect(function()
                selected = entry
                detail.Text = entry.name .. " / " .. entry.kind
            end)
        end
    end
    if count == 0 then text(list, "No glove entries loaded. Open the backpack and Refresh.", 0, 0, 580, 38, 12, C.muted) end
end
local function scanGloves()
    entries, selected = {}, nil
    detail.Text = "Select a glove."
    local seen = {}
    local function add(name, kind)
        local key = normalize(name)
        if key == "" or seen[key] then return end
        seen[key] = true
        table.insert(entries, {name = name, kind = kind})
    end
    local currentItem = nativeText("InventoryGui.InventoryWindow.InfoFrame.ItemName")
    if currentItem ~= "" and normalize(currentItem) ~= "itemname" then add(currentItem, "Selected in inventory") end
    local folder = player:FindFirstChild("_unlockedGloves")
    if folder then
        for _, value in ipairs(folder:GetChildren()) do
            if value:IsA("BoolValue") and value.Value then add(value.Name, "Unlocked") end
        end
    end
    local containers = {}
    if player:FindFirstChild("Backpack") then table.insert(containers, player.Backpack) end
    if player.Character then table.insert(containers, player.Character) end
    for _, container in ipairs(containers) do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then add(tool.Name, "Owned tool") end
        end
    end
    local ignored = {equip=true, unequip=true, select=true, search=true, all=true,
        gloves=true, backpack=true, inventory=true, close=true, locked=true,
        owned=true, unowned=true, badge=true, mastery=true, favorites=true}
    local nativeContent = nativeOne("InventoryGui.InventoryWindow.Content")
    for _, object in ipairs(playerGui:GetDescendants()) do
        if external(object) and backpackContext(object)
            and (object:IsA("TextLabel") or object:IsA("TextButton")) then
            local name, role = object.Text, normalize(object.Name)
            local key = normalize(name)
            local nameField = object:IsA("TextButton") or (nativeContent and object:IsDescendantOf(nativeContent)) or role == "name"
                or role == "glovename" or role == "toolname" or role == "itemname"
            if nameField and #name <= 40 and key ~= "" and not ignored[key]
                and not tonumber(key) and nearestButton(object) then
                add(name, "Backpack entry")
            end
        end
    end
    table.sort(entries, function(a, b) return a.name:lower() < b.name:lower() end)
    renderList()
    message(tostring(#entries) .. " backpack/glove entries found.")
end
button(gloves, "Refresh", 452, 74, 144, 34, scanGloves)
bind(search:GetPropertyChangedSignal("Text"), renderList)
button(gloves, "Equip through backpack", 0, 376, 190, 26, function()
    if not selected then message("Select a glove first.") return end
    equipThroughBackpack(selected.name)
end)
button(gloves, "Open game inventory", 202, 376, 190, 26, function()
    local window = nativeOne("InventoryGui.InventoryWindow")
    if window and shown(window) then
        root.Visible = false
        message("Inventory is open. RightShift restores this window.") return
    end
    local target = nativeOne("Component.Sidebar.Inventory")
    if target then
        local sent, result = activateGuiButton(target)
        message(result)
        if sent then root.Visible = false end
    elseif window then
        reveal(window)
        root.Visible = false
        message("Inventory opened. RightShift restores this window.")
    else
        message("The game's inventory is not loaded.")
    end
end)
button(gloves, "Search game inventory", 404, 376, 192, 26, function()
    local input = nativeOne("InventoryGui.InventoryWindow.SearchBar.SearchInput")
    if not input or not input:IsA("TextBox") then message("Game inventory search is not loaded.") return end
    input.Text = search.Text
    reveal(input)
    root.Visible = false
    message("Search entered. Press Enter in the inventory if needed. RightShift restores this window.")
end)
onShow.Gloves = scanGloves

local utils = page("Utilities")
text(utils, "Utilities", 0, 0, 596, 30, 23)
text(utils, "Glove route, saved position, and camera controls.", 0, 35, 596, 24, 12, C.muted)
local ut = card(utils, 0, 74, 596, 102)
text(ut, "Untitled Tag Glove", 14, 10, 500, 24, 15)
text(ut, "Join the required place, then use the buildz block route.", 14, 36, 560, 20, 11, C.muted)
button(ut, "Join Untitled Tag", 14, 64, 272, 26, function()
    message("Teleporting to Untitled Tag...")
    local ok, err = pcall(function() TS:Teleport(UT_PLACE, player) end)
    if not ok then message("Teleport failed: " .. tostring(err)) end
end)
button(ut, "Go to buildz block", 300, 64, 282, 26, function()
    if game.PlaceId ~= UT_PLACE then message("Join Untitled Tag first.") return end
    local folder, hrp = workspace:FindFirstChild("buildz"), rootPart()
    if not folder or not hrp then message("buildz folder or character unavailable.") return end
    for _, part in ipairs(folder:GetDescendants()) do
        if part:IsA("BasePart") and (part.Position - BLOCK_POSITION).Magnitude < 0.5 then
            hrp.CFrame = part.CFrame + Vector3.new(0, 2, 0)
            message("Teleported to buildz block.") return
        end
    end
    message("Target block is not loaded or was not found.")
end)
local savedPosition
local saved = card(utils, 0, 188, 596, 86)
text(saved, "Saved position", 14, 8, 500, 24, 14)
button(saved, "Save position", 14, 44, 272, 28, function()
    local hrp = rootPart()
    if not hrp then message("Character unavailable.") return end
    savedPosition = hrp.CFrame
    message("Position saved for this session.")
end)
button(saved, "Return to saved", 300, 44, 282, 28, function()
    local hrp = rootPart()
    if not hrp or not savedPosition then message("Save a position first.") return end
    hrp.CFrame = savedPosition
    message("Returned to saved position.")
end)
local cameraCard = card(utils, 0, 286, 596, 114)
text(cameraCard, "Camera field of view", 14, 10, 500, 24, 14)
local fovInput = box(cameraCard, "40 - 100", 14, 48, 160, 30)
button(cameraCard, "Apply FOV", 186, 48, 180, 30, function()
    local value, camera = tonumber(fovInput.Text), workspace.CurrentCamera
    if not camera or not value or value ~= value or value < 40 or value > 100 then
        message("Enter an FOV between 40 and 100.") return
    end
    if camera ~= originalCamera then
        restoreFov()
        originalCamera, originalFov = camera, camera.FieldOfView
    end
    camera.FieldOfView = value
    changedFov = true
    message("FOV set to " .. tostring(value) .. ".")
end)
button(cameraCard, "Reset FOV", 378, 48, 204, 30, function()
    restoreFov()
    message("Camera field of view restored.")
end)

-- HITMAN QUESTS: read existing PlayerGui panels, never assumed remote schemas.
local hitman = page("Hitman")
text(hitman, "Hitman quests", 0, 0, 596, 30, 23)
text(hitman, "Live quest text and actions from the game's PlayerGui.", 0, 35, 596, 24, 12, C.muted)
local questList = make("ScrollingFrame", hitman, {
    Position = UDim2.fromOffset(0, 74), Size = UDim2.fromOffset(596, 142),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
make("UIListLayout", questList, {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})
local questTextScroll = make("ScrollingFrame", hitman, {
    Position = UDim2.fromOffset(0, 228), Size = UDim2.fromOffset(596, 126),
    BackgroundColor3 = C.card, BorderSizePixel = 0, ScrollBarThickness = 3,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
round(questTextScroll, 10)
local questText = text(questTextScroll, "Open Hitman's quest panel in-game, then Refresh.", 12, 10, 568, 0, 12, C.muted)
questText.TextWrapped = true
questText.TextYAlignment = Enum.TextYAlignment.Top
questText.AutomaticSize = Enum.AutomaticSize.Y
local questSelection
local panelText
local QUEST_BASE = "QuestHunterComponent.QuestHunter.Element.Main.Main.Page"
local function nativeQuestInfo()
    return nativeOne(QUEST_BASE .. ".QuestInfoPage")
end
local questKeys = {"hitman", "quest", "bounty", "fourseason", "handkerchief", "terryfying"}
local function questName(name)
    name = normalize(name)
    for _, key in ipairs(questKeys) do
        if name:find(key, 1, true) then return true end
    end
    return false
end
local function collectQuestPanels()
    local roots = {}
    for _, object in ipairs(playerGui:GetDescendants()) do
        if external(object) and (object:IsA("GuiObject") or object:IsA("ScreenGui"))
            and (questName(object.Name) or ((object:IsA("TextLabel") or object:IsA("TextButton"))
                and (normalize(object.Text):find("terryfyingcatacombs", 1, true)
                    or normalize(object.Text):find("intotheunknown", 1, true)
                    or normalize(object.Text):find("fixmydangputer", 1, true)
                    or normalize(object.Text):find("fourseasons", 1, true)))) then
            local candidate = object
            -- A name label often shares its parent with progress and action buttons.
            if object:IsA("TextLabel") and object.Parent and object.Parent:IsA("GuiObject") then
                candidate = object.Parent
            end
            roots[candidate] = true
        end
    end
    local result = {}
    for object in pairs(roots) do
        local parent, nested = object.Parent, false
        while parent and parent ~= playerGui do
            if roots[parent] then nested = true break end
            parent = parent.Parent
        end
        if not nested then table.insert(result, object) end
    end
    table.sort(result, function(a, b) return a:GetFullName() < b:GetFullName() end)
    return result
end
panelText = function(panel)
    local lines, seen = {}, {}
    local nodes = {panel}
    for _, child in ipairs(panel:GetDescendants()) do table.insert(nodes, child) end
    for _, object in ipairs(nodes) do
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            local value = object.Text:gsub("<[^>]+>", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if value ~= "" and not seen[value] then
                seen[value] = true
                table.insert(lines, value)
            end
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or "This panel has no loaded text. Open the quest interface in-game."
end
local function scanQuests()
    local keep = questSelection and questSelection.object
    questSelection = nil
    for _, child in ipairs(questList:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    local panels, order = collectQuestPanels(), 0
    local function row(value, object, panel, isAction)
        order = order + 1
        local item = make("TextButton", questList, {
            Size = UDim2.new(1, -8, 0, 30), BackgroundColor3 = C.card,
            BorderSizePixel = 0, Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = C.text, Text = value, TextTruncate = Enum.TextTruncate.AtEnd,
            LayoutOrder = order,
        })
        round(item, 7)
        local selection = {object = object, panel = panel, action = isAction}
        if object == keep then questSelection = selection end
        item.Activated:Connect(function()
            questSelection = selection
            questText.Text = (isAction and "Selected game button: " .. value .. "\n\n" or "") .. panelText(panel)
        end)
    end
    local nativeInfo = nativeQuestInfo()
    local nativeQuestPage = nativeOne(QUEST_BASE .. ".QuestsPage")
    if nativeInfo then
        row("Current quest / " .. nativeText(QUEST_BASE .. ".QuestInfoPage.Title"), nativeInfo, nativeInfo, false)
    end
    if nativeQuestPage then
        for _, item in ipairs(nativeQuestPage:GetChildren()) do
            local target = item:FindFirstChild("Button")
            local title = target and target:FindFirstChild("Title")
            if target and target:IsA("GuiButton") and title and title:IsA("TextLabel")
                and normalize(title.Text) ~= "" and normalize(title.Text) ~= "title" then
                row("Quest / " .. cleanText(title.Text), target, nativeInfo or nativeQuestPage, true)
            end
        end
    end
    for _, panel in ipairs(panels) do
        row("Panel / " .. panel.Name, panel, panel, false)
        local children = panel:GetDescendants()
        if panel:IsA("GuiButton") then table.insert(children, 1, panel) end
        for _, object in ipairs(children) do
            if object:IsA("GuiButton") then
                local caption = object:IsA("TextButton") and object.Text or object.Name
                if caption == "" then caption = object.Name end
                row("Action / " .. caption, object, panel, true)
            end
        end
    end
    if #panels == 0 then
        text(questList, "No quest panel loaded. Open Hitman or the quest menu, then Refresh.", 0, 0, 580, 44, 11, C.muted)
    end
    if questSelection then
        questText.Text = panelText(questSelection.panel)
    else
        questText.Text = #panels > 0 and "Select a quest panel or Action row above."
            or "Open Hitman's quest panel in-game, then Refresh."
    end
end
button(hitman, "Refresh", 0, 370, 96, 30, function()
    scanQuests()
    local info = nativeQuestInfo()
    if info then questText.Text = panelText(info) end
    message("Hitman descriptions and CounterList objectives refreshed.")
end)
button(hitman, "Open panel", 106, 370, 110, 30, function()
    local homeButton = nativeOne(QUEST_BASE .. ".HomePage.QuestButton.Button")
    if homeButton and shown(homeButton) then
        local sent, result = activateGuiButton(homeButton)
        message(result)
        if sent then root.Visible = false end
        return
    end
    local actual = nativeOne("QuestHunterComponent.QuestHunter")
    if not actual then message("Hitman panel is not loaded. Talk to Hitman first.") return end
    reveal(actual)
    root.Visible = false
    message("Hitman panel opened. RightShift restores this window.")
end)
button(hitman, "View quest", 226, 370, 110, 30, function()
    if not questSelection or not questSelection.action then message("Select a Quest or Action row first.") return end
    local sent, result = activateGuiButton(questSelection.object)
    message(result)
    if sent then
        task.delay(0.3, function()
            if not alive then return end
            local info = nativeQuestInfo()
            if info then questText.Text = panelText(info) end
        end)
    end
end)
local function nativeQuestAction(name)
    local info = nativeQuestInfo()
    local target = nativeOne(QUEST_BASE .. ".QuestInfoPage." .. name)
    local title = nativeText(QUEST_BASE .. ".QuestInfoPage.Title")
    if not info or not shown(info, info) or title == "" or normalize(title) == "title"
        or not controlReady(target, info) then
        message("Open a quest in the game's Hitman panel. This quest action is hidden or disabled.") return
    end
    local sent, result = activateGuiButton(target)
    message(result)
    if sent then
        task.delay(0.3, function()
            if alive then scanQuests() questText.Text = panelText(info) end
        end)
    end
end
button(hitman, "Accept quest", 346, 370, 110, 30, function() nativeQuestAction("AcceptQuest") end)
button(hitman, "Collect reward", 466, 370, 130, 30, function() nativeQuestAction("CollectReward") end)
onShow.Hitman = scanQuests

-- LIVE GAME PANELS
local liveReaders = {}
do
    local rewards = page("Rewards")
    text(rewards, "Daily rewards", 0, 0, 596, 30, 23)
    text(rewards, "Reward timers and the game's daily Claim button.", 0, 35, 596, 24, 12, C.muted)
    local panel = card(rewards, 0, 74, 596, 250)
    local view = make("ScrollingFrame", panel, {
        Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(568, 224),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    local summary = text(view, "Open daily rewards to load reward details.", 0, 0, 550, 0, 12, C.muted)
    summary.AutomaticSize = Enum.AutomaticSize.Y
    summary.TextWrapped = true
    summary.TextYAlignment = Enum.TextYAlignment.Top
    local function refresh()
        local actual = nativeOne("Component.DailyRewards")
        summary.Text = actual and panelText(actual) or "Daily rewards panel is not loaded."
    end
    button(rewards, "Open daily rewards", 0, 340, 286, 32, function()
        local target = nativeOne("Component.Sidebar.DailyRewards")
        if target then local _, result = activateGuiButton(target) message(result)
        else
            local actual = nativeOne("Component.DailyRewards")
            if not actual then message("Daily rewards panel is not loaded.") return end
            reveal(actual)
            root.Visible = false
            message("Daily rewards opened. RightShift restores this window.")
        end
    end)
    button(rewards, "Claim daily reward", 298, 340, 298, 32, function()
        local actual = nativeOne("Component.DailyRewards")
        local target = nativeOne("Component.DailyRewards.ClaimButton")
        if not actual or not controlReady(target, actual) then
            message("The daily Claim button is hidden or disabled. Open rewards and check the timer.") return
        end
        local _, result = activateGuiButton(target)
        message(result)
    end)
    text(rewards, "The game's timer and eligibility rules determine claim availability.", 0, 382, 596, 20, 11, C.muted)
    onShow.Rewards = refresh
    liveReaders.Rewards = refresh
end
do
    local mastery = page("Mastery")
    text(mastery, "Mastery objectives", 0, 0, 596, 30, 23)
    text(mastery, "Live upgrades, descriptions, and loaded objective counters.", 0, 35, 596, 24, 12, C.muted)
    local view = make("ScrollingFrame", mastery, {
        Position = UDim2.fromOffset(0, 74), Size = UDim2.fromOffset(596, 270),
        BackgroundColor3 = C.card, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    round(view, 10)
    local summary = text(view, "Open an inventory item's Mastery button to load objectives.", 14, 12, 560, 0, 12, C.muted)
    summary.AutomaticSize = Enum.AutomaticSize.Y
    summary.TextWrapped = true
    summary.TextYAlignment = Enum.TextYAlignment.Top
    local function refresh()
        local actual = nativeOne("Component.MasteryWindow")
        local item = nativeText("InventoryGui.InventoryWindow.InfoFrame.ItemName")
        summary.Text = "Selected inventory item: " .. (item ~= "" and item or "None") .. "\n\n"
            .. (actual and panelText(actual) or "Mastery panel is not loaded.")
    end
    button(mastery, "Open selected item's mastery", 0, 360, 366, 32, function()
        local info = nativeOne("InventoryGui.InventoryWindow.InfoFrame")
        local target = nativeOne("InventoryGui.InventoryWindow.InfoFrame.Buttons.Mastery")
        if controlReady(target, info) then
            local _, result = activateGuiButton(target)
            message(result)
        else
            local actual = nativeOne("Component.MasteryWindow")
            if not actual then message("Select a glove in the inventory and open Mastery first.") return end
            reveal(actual)
            root.Visible = false
            message("Existing mastery panel opened. RightShift restores this window.")
        end
    end)
    button(mastery, "Refresh objectives", 378, 360, 218, 32, function()
        refresh()
        message("Mastery objectives refreshed.")
    end)
    onShow.Mastery = refresh
    liveReaders.Mastery = refresh
end
do
    local events = page("Bounties")
    text(events, "Bounties & tournaments", 0, 0, 596, 30, 23)
    text(events, "Read live offers and respond through the original buttons.", 0, 35, 596, 24, 12, C.muted)
    local function offerCard(title, path, y)
        local frame = card(events, 0, y, 596, 154)
        text(frame, title, 14, 8, 560, 24, 14)
        local summary = text(frame, "No loaded offer", 14, 35, 560, 64, 11, C.muted)
        summary.TextWrapped = true
        summary.TextYAlignment = Enum.TextYAlignment.Top
        summary.TextTruncate = Enum.TextTruncate.AtEnd
        local function respond(kind)
            local actual = nativeOne(path)
            local target = nativeOne(path .. "." .. kind .. "Button")
            if not actual or not shown(actual) or not controlReady(target, actual) then
                message("No visible " .. title:lower() .. " offer is ready for " .. kind:lower() .. ".") return
            end
            local _, result = activateGuiButton(target)
            message(result)
        end
        button(frame, "Accept", 14, 112, 272, 28, function() respond("Accept") end)
        button(frame, "Decline", 300, 112, 282, 28, function() respond("Decline") end)
        return function()
            local actual = nativeOne(path)
            summary.Text = actual and ((shown(actual) and "Active offer\n" or "Inactive panel\n") .. panelText(actual))
                or "No loaded offer"
        end
    end
    local bountyRefresh = offerCard("Bounty", "Component.BountyHunt", 74)
    local tournamentRefresh = offerCard("Tournament", "Component.SlapTournament", 240)
    local function refresh() bountyRefresh() tournamentRefresh() end
    onShow.Bounties = refresh
    liveReaders.Bounties = refresh
end

-- GLOVE OBTAINMENT TABLE AND TIMERS
local CATALOG = {
    {badge = "Error glove", reward = "Error", method = "Have 50k slaps; find Error behind moai statue between Normal Arena and Slap Royale portals."},
    {badge = "ez", reward = "Moon", method = "Win a Slap Tournament as last standing."},
    {badge = "court evidence", reward = "Hitman (1/2)", method = "In Lobby, behind/under Default Only Arena + Normal Arena portals, click knife in stabbed noob near gravestone."},
    {badge = "the touch of midas", reward = "buddies", method = "Slap 3 different people while golden using Golden's ability."},
    {badge = "really?", reward = "Pebble (1/3)", method = "Stay in Diamond's rock ability for 15 minutes."},
    {badge = "WHY", reward = "MEGAROCK + Pebble (1/3)", method = "Stay in Diamond's ability for 10 hours 15 minutes."},
    {badge = "Infected", reward = "Plague", method = "Get slapped by Plague or Zombie, or by another infected player."},
    {badge = "Jack's will", reward = "Hallow Jack", method = "Halloween only: get 10+ Killstreak kills; 10% chance every 10 min a gravestone spawns behind tree at Cube of Death island; click it. Not VIP."},
    {badge = "Evaded", reward = "[REDACTED]", method = "Enter [REDACTED]'s dimension portal and escape through one of 10 doors."},
    {badge = "250", reward = "Bubble (1/2)", method = "Get 250 kills with Killstreak without dying."},
    {badge = "To the moon", reward = "bus", method = "When bus ability approaches, use Space ability right before it hits you."},
    {badge = "Lucky Gift", reward = "Mitten", method = "Christmas only: open Mitten's gift; 10% chance."},
    {badge = "Unphased", reward = "Phase", method = "Collect a phase orb (5% random spawn around main island). Not VIP."},
    {badge = "Savior", reward = "Warp", method = "Use Swapper and swap with someone who fell off the map."},
    {badge = "Short fuse", reward = "Bomb", method = "Use Warp to teleport to someone falling off island and die immediately in void; resetting doesn't work."},
    {badge = "Harbinger of death", reward = "Bubble (1/2)", method = "Reach 9 kills with Reaper without dying."},
    {badge = "Orb of Flight", reward = "Jet", method = "Pick up Orb of Flight from randomly spawned jet; 10% every 10 min. Not VIP."},
    {badge = "Firefighter", reward = "Shard", method = "Cool down OVERKILL 5 times with Snow/Ice/Snowball/Iceskate without dying within 1 minute."},
    {badge = "Sorry to burst your bubble", reward = "potato", method = "Get hit by Bubble's bubble while under Reverse's effect."},
    {badge = "good job", reward = "CULT", method = "Using potato, get hot potato by being slapped by hot-potato/potato user and die to it; or slap active Reverse."},
    {badge = "bob", reward = "bob", method = "Using Replica, 1/7500 chance to spawn bob when using ability; need another player in arena."},
    {badge = "Death Dodger", reward = "Jupiter", method = "Survive a hit from God's Hand, e.g. God's Hand timestops then you use fish."},
    {badge = "Predator", reward = "Spy", method = "Win Slap Royale with 10+ kills. Not obtainable in private server."},
    {badge = "Head Hunter", reward = "Detonator", method = "Win Slap Royale with 15+ kills. Not obtainable in private server."},
    {badge = "Anticlimactic End", reward = "Rage", method = "Kill a Killstreak user with 50+ kills using Default."},
    {badge = "Brick Master", reward = "Trap", method = "Place 1,000 bricks without dying using Brick in a public server. Not VIP."},
    {badge = "YOU MONSTER", reward = "Orbit", method = "Kill bob by luring him into Cube of Death."},
    {badge = "Island Conqueror", reward = "Dominance", method = "Win a Slap Royale match. Not obtainable in private server."},
    {badge = "Prolonged Anger", reward = "Hybrid", method = "Stay in Rage mode for 60 seconds."},
    {badge = "The Golden Slapple", reward = "Slapple", method = "Claim Golden Slapple from biggest tree on Slapple Island; 1% every minute."},
    {badge = "Memento Mori", reward = "Disarm", method = "Kill 19 people with Reaper without dying."},
    {badge = "THE ACCIDENT", reward = "Chain", method = "In Slap Royale, solve 4 questions in old cabin near barn, then enter correct code in Bunker keypad inside Barn. Not private."},
    {badge = "Candy King", reward = "Rattlebones", method = "Halloween only: collect 1,000 candy corns. Not VIP."},
    {badge = "Witch Brew", reward = "Witch", method = "Halloween only: drink Witch Brew potion dropped by Witch. Not VIP."},
    {badge = "Killer", reward = "Charge", method = "Win Slap Royale with 5+ kills. Not obtainable in private server."},
    {badge = "Plate Master", reward = "Tycoon", method = "Stand on The Plate for 10 minutes straight in a server with 7+ people."},
    {badge = "what", reward = "Confusion", method = "Equip spin, have Reaper timer under 5 sec, destroy a Tycoon, and get hit by bus within 5 sec."},
    {badge = "RUN", reward = "Glitch", method = "Hit an Orb of Flight or Phase Orb with Error to make glitch orb, then pick it up. Not VIP."},
    {badge = "Engineer's Gift", reward = "Snowball", method = "Christmas only: open Mitten's gift; 5% chance."},
    {badge = "EXPOSED", reward = "Elude", method = "Keypad 20% chance behind biggest tree on Slapple/Moai every 10 min; collect 4 items in maze before timer. Not VIP."},
    {badge = "RNGod", reward = "RNG", method = "Using Dice, slap a player and deal max power."},
    {badge = "DEEP SLUMBER", reward = "fish", method = "Use ZZZZZZZ ability for 1 hour straight in public server. Not VIP."},
    {badge = "Moai", reward = "Moai", method = "Step on your own Trap."},
    {badge = "ULTRAROCK", reward = "Obby + Pebble (1/3)", method = "Absorb 10 different people with MEGAROCK/CUSTOM in one sitting."},
    {badge = "Insanity", reward = "Voodoo", method = "Survive as Ghost for 1 hour straight in public server. Not VIP."},
    {badge = "CHAOS", reward = "Goofy", method = "Be affected by Goofy's ability while under Confusion's effect."},
    {badge = "Demonic Ritual", reward = "Leash", method = "Full 16-player server all equip CULT and stand in Normal Arena."},
    {badge = "Underkill", reward = "Flamarang", method = "Kill 5 different OVERKILL players with Boomerang in one server."},
    {badge = "Kinetically Charged", reward = "Kinetic", method = "Get ragdolled 100 times and use Stun EMP 50 times affecting someone in public without dying. Not VIP."},
    {badge = "GO BERSERK", reward = "Berserk", method = "Survive 3 max-charged hits from Kinetic in one life in public server. Not VIP."},
    {badge = "Incredible Running Man", reward = "Sparky", method = "Use Speedrun, get hit by Reaper and Conveyor, then run into OVERKILL without stopping."},
    {badge = "Boogie With It", reward = "Boogie", method = "Full 16-player server all dance/use Boogie in Normal Arena at same time. Not VIP."},
    {badge = "Repressed Memories", reward = "Recall", method = "3% chance teleport to secret area while attempting Reverse Incident badge; answer quiz perfectly and follow NPC orders."},
    {badge = "Blasting Off Again", reward = "Quake", method = "Max Berserk, get launched by woah into fully charged Home Run."},
    {badge = "Ultimate Control", reward = "Psycho", method = "Get sent to The Ruins, go down staircase, complete obby."},
    {badge = "Escape the Abyss", reward = "Kraken", method = "Equip Squid, get slapped off by fish to Kraken boss; slap tentacles when down. If die, wait 5 min."},
    {badge = "Da Maze Runner", reward = "Counter", method = "Click lever in maze center, outrun Pim for 3 min, click glowing Counter glove spawn. Not VIP."},
    {badge = "Toolbox", reward = "Hammer", method = "Click Engineer's toolbox; 10% spawn. Can't use your own."},
    {badge = "Emissary Of Light", reward = "rob", method = "Need Killstreak + Reaper at 3 kills, God's Hand, Tycoon, and bob user; spawn bob near them, GH ability opens Dark Realm portal; defeat/seal bob's true form."},
    {badge = "Total Rhythm", reward = "Rhythm", method = "Use Boogie balls and slap 10 unique dancing players in range in one life."},
    {badge = "See in the dark", reward = "Rojo", method = "Get Reaper + Nightmare effects, then kill bob with Cube of Death."},
    {badge = "Sharp Shooter", reward = "Hitman (1/2)", method = "Use Track and kill 10 players with ability without dying. Not VIP."},
    {badge = "Parkour Pwner", reward = "Retro", method = "Get caught by Glitch, use Recall before release, get hit by Error; complete 3-part obby and go through end door."},
    {badge = "The Relic", reward = "Null", method = "Use Default, get sucked into bob+rob portal to Null Zone; complete maze/obbies, kill enemies, touch rob plush. Need 2+ people; max 4 teleported."},
    {badge = "Catch Emm All", reward = "Lure", method = "Use Leash to rope fish, Squid, and Kraken all at once."},
    {badge = "Great Escape", reward = "Tinkerer", method = "Use Default, enter bob+rob portal to Null Zone; complete maze/obby; puzzle needs 3 players on furthest pressure plates."},
    {badge = "Sweet-Tooth Sovereign", reward = "Necromancer", method = "Halloween only: collect 2,000 candy corns. Not VIP."},
    {badge = "Containment Breach", reward = "Alchemist", method = "Kill 5 different people with Plague's passive in one life; Zombie also works."},
    {badge = "Gardens And Ghouls", reward = "Druid", method = "Alchemist drink Corrupted Vine Potion (3 Wild Vines, 1 Blood Rose, 1 Dark Root, 1 Elder Wood, 1 Jade Stone); beat 6-wave tower defense."},
    {badge = "Now You See Me", reward = "Jester", method = "Use Elude and get teleported to Cube of Death from being slapped."},
    {badge = "Farmland Fray", reward = "Scythe", method = "Alchemist drink Corrupted Field Potion (2 Plane Flowers, 1 Hazel Lily); beat 6-wave tower defense."},
    {badge = "Yuletime Might", reward = "Santa", method = "Christmas only: in Snowball Smash, kill 65 players."},
    {badge = "Slap Battles: On Ice", reward = "Iceskate", method = "Become an ice cube from Iceskate or Jerry."},
    {badge = "G-Grandson..?", reward = "Blasphemy", method = "Get hit by bus; 1% chance cutscene plays and awards Blasphemy."},
    {badge = "Into the Crypt", reward = "Pan", method = "Collect all 3 artifacts and find the door. Requires Default, bob, rob, and Reverse/el gato."},
    {badge = "CERTIFIED ADMIN", reward = "Admin", method = "Source blank; listed requirements: Recall, Glitch, Error."},
    {badge = "Stand your ground", reward = "Joust", method = "Parry a Joust user who has ability active on horse."},
    {badge = "Easy As Pie", reward = "Firework", method = "Alchemist pick up Cake Mix and get trapped in Oven's oven; when shot out it becomes Birthday Cake; use it."},
    {badge = "It's Finally Over...", reward = "Run", method = "In Bunker, talk to Hitman, accept \"The Terry-fying Catacombs\"; escape Run's Catacombs 10 times via red Exit door; talk to Hitman. VIP escapes don't count."},
    {badge = "The Hunt", reward = "Glovel", method = "Take Hitman's quest for his handkerchief and return it safely."},
    {badge = "Null Piercer", reward = "Divebomb", method = "In Bunker, talk Hitman, accept \"Into the Unknown\"; go Cannon Island; Rocketman into 5 bob+rob portals; return to Hitman."},
    {badge = "Friend of the Dark", reward = "Lamp", method = "Break Nightmare's lightbulb while sleeping with ZZZZZZZ without dying 5 times."},
    {badge = "Code Breaker", reward = "Knockoff", method = "Enter Pocket dimension, interact painting beside cabinet, input 4553293, press green button."},
    {badge = "Ice Essence", reward = "Frostbite", method = "As Shard, get entrapped by Ice/Iceskate, then frozen by Frostbite while entrapped; complete Ice Trials obby and pick Ice Essence."},
    {badge = "Cranking 90's", reward = "Plank", method = "Use Fort to reach height limit where Fort can't build walls."},
    {badge = "SLAP BATTLES SWEEP", reward = "Spoonful", method = "Reach last upgrade / 5,000 points with Tycoon."},
    {badge = "Leap of Faith", reward = "the schlob", method = "Use fish, reach height limit with Cloud, flop onto The Plate."},
    {badge = "Caution: High Voltage", reward = "Siphon", method = "Source blank."},
    {badge = "UberCharged", reward = "Wrench", method = "As Engineer, get hit by Thor's ability, then slap one of your sentries while electrified."},
    {badge = "Nah, I'd win", reward = "Avatar", method = "Source blank; not obtainable in private server."},
    {badge = "A Guiding Hand", reward = "Relude", method = "Source blank; not obtainable in private server."},
    {badge = "Bounty Claimed", reward = "Hunter", method = "Source blank; not obtainable in private server."},
    {badge = "How did we get here?", reward = "Water", method = "Brew every currently available Alchemist potion and have all in inventory at same time. Not VIP."},
    {badge = "FREE OOG!", reward = "Fan", method = "Source blank; listed gloves: barzil, Nimbus, Balloony, Poltergeist, or Error."},
    {badge = "The Glove", reward = "Boxer", method = "Source blank; listed gloves: barzil, Nimbus, Balloony, Poltergeist, or Error."},
    {badge = "Orb of Honor", reward = "MATERIALIZE", method = "Wait for Phase Orb/Orb of Flight, wait for lightning strike chance every 1-3 min, collect it; protect it to let it become Honored Orb. Not VIP."},
    {badge = "Garden of Erasure", reward = "Bind", method = "Alchemist drink Lost Potion (3 Elder Wood, 1 Blue Crystal, 1 Red Crystal)  ->  Binded Maze; find Bind while chased by ghost copy; click Bind."},
    {badge = "Fetch me their Souls", reward = "Poltergeist", method = "Halloween only: Default Only Arena  ->  cross to island by gravestone obby  ->  retro house portal max 3 players  ->  survive 10 zombie waves. Not VIP."},
    {badge = "Shattered Memories", reward = "Clock", method = "Source blank; listed gloves: barzil, Nimbus, Balloony, Poltergeist, or Error."},
    {badge = "Hurt me plenty", reward = "Untitled Tag Glove", method = "Enter barzil; use Balloony/Poltergeist to reach portal above North Island where Cube of Death; climb house stack; reach end obby; click sign inside large floating building to TOH; complete obby or type \"I'M A LOSER\"/\"IM A LOSER\" and click sign."},
    {badge = "Fortress of Dreams", reward = "Pillow", method = "Two ZZZZZZZ users use ability together at The Fort  ->  Dreamscape; click pillows, buy/upgrade, defeat enemy base."},
    {badge = "You're gonna need a bigger glove", reward = "Angler", method = "Use Lure and kill 10 people with shark ability without dying. Not VIP."},
    {badge = "Snow man left behind", reward = "Jerry", method = "Christmas only; source blank for exact method."},
    {badge = "Insane Minds think Alike", reward = "Snowroller", method = "Source blank; listed glove: ZZZZZZZ."},
    {badge = "Oh! That's a Baseball!", reward = "Draw4", method = "Two Ping Pong users hit same ball back and forth 20 times total (10 each)."},
    {badge = "Rats, We're Rats, We're the Rats", reward = "Mouse", method = "Click cheese on Cannon Island with El gato  ->  Cheese Realm; build city, survive rats, earn 3,000 points, pay Master Whiskers to help defeat Rat King."},
    {badge = "Enlightened", reward = "Hexa", method = "Source blank; listed glove: Obby."},
    {badge = "Day in the life of a small Game Developer", reward = "Metaverse", method = "Source blank; listed gloves: barzil, Nimbus, Balloony, Poltergeist, or Error."},
    {badge = "Sword Fighter of The Heights", reward = "Swordfighter", method = "Source blank; listed glove: Retro."},
    {badge = "Pillow Fight", reward = "Tank", method = "Use Shotgun's 5 Explosive Rounds to destroy a maxed-out Pillow fort."},
    {badge = "Egging Over It", reward = "Eggler", method = "Source blank."},
    {badge = "Collect My Pages", reward = "Slender", method = "Source blank; listed gloves: Balloony, Pocket."},
    {badge = "Captain's Orders", reward = "Swashbuckler", method = "Using Kraken, jump off end of Plank bridge just before Lure ability kills you."},
    {badge = "Banished", reward = "Silly", method = "Use Baby, get slapped by Goofy, use cry ability, get blown by Fan while crying; die."},
    {badge = "Reawoken", reward = "Slasher", method = "Source blank; listed glove: Run."},
    {badge = "Slappy Wheels", reward = "Car Keys", method = "Use Adios ability while on a Car Keys user's car  ->  Slap Cart; race ghost and place first or finish within 30 sec of ghost."},
    {badge = "Plungering Heights", reward = "Suction", method = "In Bunker room with portal to Where Guide Resides, click plunger above doorway; click second plunger below Cube of Death  ->  Suction Trials; reach end and click Suction glove."},
    {badge = "Shattered Reality", reward = "Reflect", method = "Source blank; required gloves can vary."},
    {badge = "Dodecacide", reward = "Dave", method = "Traverse Evil Barzil and defeat Dodecahedron Dave."},
    {badge = "Die Hard", reward = "Mortis", method = "Defeat Dodecahedron Dave in Evil Barzil on hard mode."},
    {badge = "Dead or Alive", reward = "Bounty", method = "Reach a 250 bounty using Hitman. Not VIP."},
    {badge = "Out of Bounds", reward = "Debug", method = "While caught in Glitch Trojan, press Up, Up, Down, Down, Left, Right, Left, Right  ->  black room; solve puzzles for 4-digit code and enter it."},
    {badge = "Color Splash", reward = "Paint", method = "Enter Hitman Bunker in Lobby, climb ladder to paintcan platform, interact graffiti  ->  Splat Battles; win vs bots."},
    {badge = "Ceramic Panic", reward = "Plate", method = "Repeatedly slap The Plate's sign for 15 sec  ->  survival minigame; outlast attacks for 3 min."},
    {badge = "2000 Ping", reward = "Lag", method = "Remain mid-air 10 sec straight, or get pushed under floor by Defense's Barrier for 10 sec."},
    {badge = "The Cornfeared", reward = "Harvester", method = "Halloween only: enter Pim's Corn Maze portal in Default Only Arena; survive 5 mazes and chase sequence."},
    {badge = "Bullseye", reward = "Riftshot", method = "In Barzil shooting range, complete Sharpshooter Sam's target minigame / beat 10 levels by shooting all bombs."},
    {badge = "Autumnal Conkerer", reward = "Conker", method = "Complete Hitman's FourSeasons quest, interact scroll in bunker, go through Autumn tree, complete Markus Haybale's conker request. Not VIP."},
    {badge = "Glass Bones", reward = "Wheelchair", method = "Survive attacks from Bomb, Blasphemy, L.O.L.B.O.M.B, Slicer, Tableflip, and Bull in one life."},
    {badge = "Snowball Synergy", reward = "Elf", method = "Christmas only: in Snowball Smash, earn 350 hill points with each of 3 classes."},
    {badge = "Minimum Wage", reward = "Shopkeeper", method = "Using Extended/OVERKILL/Sbeve, interact with job application in Hitman Bunker  ->  Glove Store; earn $3,000 by end of Day 5 to buy Shopkeeper."},
    {badge = "Find The Gloves", reward = "Collector", method = "Interact with Snowglobe in Hitman Bunker; find/collect all 41 hidden gloves in Find The Gloves."},
    {badge = "Cleaved in Two", reward = "Glaxe", method = "In Slap Royale, kill a player using Tomahawk item."},
    {badge = "Birthday Bash", reward = "Pinata", method = "Slap a Pinata that has a chance to spawn hanging from pink trees."},
    {badge = "Hibernal Snowstopper", reward = "Penguin", method = "Complete Hitman FourSeasons quest, interact scroll, go through Winter tree to Penguin Place; complete Speedy Sam speed + Smart Aleck memory challenges, collect 2 keys, open chest."},
    {badge = "Untimely End", reward = "Undead", method = "Using Clock, die just after your Revive Time ends."},
    {badge = "Clobbering Time!", reward = "Groundbreaker", method = "Kill 3 unique players with a single Quake bury-slap. Not VIP."},
    {badge = "Easter Hatchastrophe", reward = "Shellbert", method = "In Egging Over It, talk to Kenneth after earning Eggler, accept quest, enter door, beat chicken boss."},
    {badge = "Genuinely how am I still alive", reward = "Lasso", method = "Get hit by Beatdown's ability, Trap's ability, and Knockoff in quick succession."},
    {badge = "Vernal Floralscence", reward = "Lotus", method = "In FourSeasons, enter Spring door  ->  Lotus Obtainment; collect 5 lotus flowers: purple, blue, white, red, pink."},
    {badge = "Fix my dang 'puter", reward = "G-X", method = "Accept Hitman quest \"Fix my dang 'puter!\", enter computer, complete 3 challenges, enter the box that fixes all computer issues."},
    {badge = "Gum, Gummy, Gone", reward = "Elastic", method = "Using Gummy, slap a player and have them die to height-limit kill border."},
    {badge = "The Door In-between", reward = "Doorkeeper", method = "Have Relude slap Elude to spawn door on main island; walk in  ->  corridor; open doors until jumpscare."},
    {badge = "Fatal Frame", reward = "Camera", method = "Using Ghost/Stalker, go invisible by Pim bench on Slapple to collect Camera; take 7 pictures at listed locations."},
    {badge = "Order Up!", reward = "Grillmaster", method = "Using Ketchup Default, complete all 6 tasks at hotdog truck."},
    {badge = "Return to Sender", reward = "Pool Noodle", method = "Slap Beachball's beachball back to user and kill them; if Reverse deflects, Beachball user gets badge instead."},
    {badge = "Unmasked", reward = "Marewarder", method = "Enter Pim bossfight and defeat Pim."},
    {badge = "Banish the Night", reward = "Static", method = "Defeat Pim bossfight on hard mode."},
    {badge = "Estival Heatwaver", reward = "Sand", method = "In FourSeasons, enter Summer door, accept John Surfboard's challenge, survive 5 surfboard rounds."},
    {badge = "Infinite Cobblestone Generator", reward = "Terrain", method = "Using Water, spray water on Stalagmite's magma to create cobblestone; interact as Water user. Not VIP."},
    {badge = "S P L A T", reward = "Be the Glove", method = "Using T H I C K, reach max size and get squashed by falling from great height or by BONK. Not VIP."},
    {badge = "It's Hip to be Square", reward = "Blunderbuss", method = "Using Shotgun, buy R15 Rounds from ammo merchant for 2 Coins; survive 3 waves of R15 Roblox players."},
    {badge = "Salvaged Code", reward = "Catseye", method = "Teleport to Debug area, interact Disk; interact hidden Disk in Retro Obby stage 1; slap Moai statue nose with Plague for Disk; slap tree on Default Only Arena; return to Debug area and interact Disk."},
    {badge = "Treated to Tricks", reward = "Revenant", method = "Halloween only: Default Only Arena  ->  left house portal; talk to Count Cornifer, complete candy quests; after Revenant consumes him, collect Revenant glove."},
}
local TIMER_PRESETS = {
    really = {seconds = 15 * 60, glove = "Diamond", label = "Pebble / Diamond rock"},
    why = {seconds = 10 * 3600 + 15 * 60, glove = "Diamond", label = "MEGAROCK / Diamond rock"},
    deepslumber = {seconds = 3600, glove = "ZZZZZZZ", label = "fish / sleep"},
    insanity = {seconds = 3600, glove = "Ghost", label = "Voodoo / invisibility"},
    platemaster = {seconds = 600, minPlayers = 7, label = "Tycoon / Plate", plate = true},
}
local PREREQUISITES = {
    bob = "Replica", trap = "Brick", hitman = "Track", buddies = "Golden",
    fish = "ZZZZZZZ", voodoo = "Ghost", rng = "Dice", hybrid = "Rage",
    plank = "Fort", spoonful = "Tycoon", alchemist = "Plague", angler = "Lure",
    bounty = "Hitman", joust = "Joust", mouse = "El gato",
}
local recipes = page("Obtainments")
text(recipes, "Glove obtainments", 0, 0, 596, 30, 23)
text(recipes, "Your supplied badge table, with helpers where supported.", 0, 35, 596, 24, 12, C.muted)
local recipeSearch = box(recipes, "Search reward, badge, or method", 0, 72, 596, 30)
local recipeList = make("ScrollingFrame", recipes, {
    Position = UDim2.fromOffset(0, 112), Size = UDim2.fromOffset(238, 246),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
make("UIListLayout", recipeList, {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})
local recipeDetailScroll = make("ScrollingFrame", recipes, {
    Position = UDim2.fromOffset(250, 112), Size = UDim2.fromOffset(346, 246),
    BackgroundColor3 = C.card, BorderSizePixel = 0, ScrollBarThickness = 3,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
})
round(recipeDetailScroll, 10)
local recipeDetail = text(recipeDetailScroll, "Select a glove from the table.", 12, 10, 318, 0, 12, C.muted)
recipeDetail.TextWrapped = true
recipeDetail.TextYAlignment = Enum.TextYAlignment.Top
recipeDetail.AutomaticSize = Enum.AutomaticSize.Y
local selectedRecipe, activeTimer
local timerText = text(recipes, "No timer running", 0, 362, 596, 16, 10, C.muted)
local function support(entry)
    if TIMER_PRESETS[normalize(entry.badge)] then return "Timer" end
    if normalize(entry.reward) == "error" then return "Slap goal" end
    if normalize(entry.reward) == "untitledtagglove" then return "Route" end
    return "Guide"
end
local function chooseRecipe(entry)
    selectedRecipe = entry
    local preset = TIMER_PRESETS[normalize(entry.badge)]
    local helper = support(entry)
    local detailText = entry.reward .. "\nBadge: " .. entry.badge .. "\n\n" .. entry.method .. "\n\nHelper: " .. helper
    if preset then
        detailText = detailText .. "\nDuration: " .. duration(preset.seconds)
        if preset.glove then
            detailText = detailText .. "\nRequired glove: " .. preset.glove
                .. "\n\nActivate the required ability, then start the timer. Death, respawn or glove changes reset the timer. Stop manually if the ability ends."
        else
            detailText = detailText .. "\n\nStand on The Plate, then start. Stop manually if you leave. Death, respawn or fewer than 7 players reset the timer."
        end
    elseif helper == "Guide" then
        detailText = detailText .. "\nOnly the supplied method is available here. Quest buttons appear in Hitman when loaded."
    end
    recipeDetail.Text = detailText
    recipeDetailScroll.CanvasPosition = Vector2.new(0, 0)
end
local function renderRecipes()
    for _, child in ipairs(recipeList:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    local query, count = normalize(recipeSearch.Text), 0
    for _, entry in ipairs(CATALOG) do
        if normalize(entry.reward .. entry.badge .. entry.method):find(query, 1, true) then
            count = count + 1
            local row = make("TextButton", recipeList, {
                Size = UDim2.new(1, -7, 0, 44), Text = "", BorderSizePixel = 0,
                BackgroundColor3 = C.card, LayoutOrder = count,
            })
            round(row, 8)
            local nameLabel = text(row, entry.reward, 10, 3, 210, 20, 12)
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            text(row, support(entry), 10, 24, 210, 15, 10, C.muted)
            row.Activated:Connect(function() chooseRecipe(entry) end)
        end
    end
end
bind(recipeSearch:GetPropertyChangedSignal("Text"), renderRecipes)
renderRecipes()
button(recipes, "Start helper", 0, 380, 190, 22, function()
    if not selectedRecipe then message("Select a glove first.") return end
    local preset = TIMER_PRESETS[normalize(selectedRecipe.badge)]
    if preset then
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then message("Spawn before starting a timer.") return end
        if preset.glove and normalize(equippedName()) ~= normalize(preset.glove) then
            message("Equip " .. preset.glove .. " and activate the required ability first.") return
        end
        if preset.minPlayers and #Players:GetPlayers() < preset.minPlayers then
            message("This timer needs at least " .. tostring(preset.minPlayers) .. " players.") return
        end
        activeTimer = {preset = preset, started = os.clock(), character = character}
        message("Manual timer started. Keep the required condition active.")
    elseif normalize(selectedRecipe.reward) == "error" then
        goal, goalNotified = 50000, false
        goalInput.Text = "50000"
        show("Dashboard")
        message("Error slap goal set to 50,000. The table also requires finding Error in the lobby.")
    elseif normalize(selectedRecipe.reward) == "untitledtagglove" then
        show("Utilities")
        message("Use the Untitled Tag Glove route buttons.")
    else
        message("Guide selected. Follow the displayed method or use the game's quest buttons in Hitman.")
    end
end)
button(recipes, "Equip prerequisite", 202, 380, 190, 22, function()
    if not selectedRecipe then message("Select a glove first.") return end
    local preset = TIMER_PRESETS[normalize(selectedRecipe.badge)]
    local needed = (preset and preset.glove)
        or (normalize(selectedRecipe.badge) == "sharpshooter" and "Track")
        or PREREQUISITES[normalize(selectedRecipe.reward)]
    if not needed then message("No single equip prerequisite configured. Read this glove's method.") return end
    equipThroughBackpack(needed)
end)
button(recipes, "Stop timer", 404, 380, 192, 22, function()
    activeTimer = nil
    timerText.Text = "No timer running"
    message("Obtainment timer stopped.")
end)
bind(player.CharacterRemoving, function()
    if activeTimer then
        activeTimer = nil
        timerText.Text = "Timer reset / character removed"
        message("Obtainment timer reset on respawn.")
    end
end)
local function updateTimer()
    if not activeTimer then return end
    local preset = activeTimer.preset
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local reason
    if character ~= activeTimer.character or not humanoid or humanoid.Health <= 0 then
        reason = "death or respawn"
    elseif preset.glove and normalize(equippedName()) ~= normalize(preset.glove) then
        reason = "required glove changed"
    elseif preset.minPlayers and #Players:GetPlayers() < preset.minPlayers then
        reason = "fewer than 7 players"
    end
    if reason then
        activeTimer = nil
        timerText.Text = "Timer reset / " .. reason
        message("Obtainment timer reset: " .. reason .. ".") return
    end
    local elapsed = os.clock() - activeTimer.started
    timerText.Text = preset.label .. " / " .. duration(elapsed) .. " / " .. duration(preset.seconds)
    if elapsed >= preset.seconds then
        activeTimer = nil
        timerText.Text = preset.label .. " / timer elapsed"
        message("Timer elapsed. Check the game for badge completion.")
    end
end
local lastQuestRefresh = 0
local lastPanelRefresh = 0
local function updateExtra()
    updateTimer()
    if os.clock() - lastPanelRefresh >= 1 then
        lastPanelRefresh = os.clock()
        for name, refresh in pairs(liveReaders) do
            if pages[name].Visible then refresh() end
        end
    end
    if pages.Hitman.Visible and os.clock() - lastQuestRefresh >= 3 then
        lastQuestRefresh = os.clock()
        scanQuests()
    end
end

local dragging, dragStart, dragPosition, activeTouch
bind(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, dragPosition = true, input.Position, root.Position
        activeTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
    end
end)
bind(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input == activeTouch then
        dragging, activeTouch = false, nil
    end
end)
bind(UIS.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == activeTouch) then
        local delta = input.Position - dragStart
        root.Position = UDim2.new(dragPosition.X.Scale, dragPosition.X.Offset + delta.X,
            dragPosition.Y.Scale, dragPosition.Y.Offset + delta.Y)
    end
end)
bind(UIS.InputBegan, function(input, processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightShift then root.Visible = not root.Visible end
end)
bind(TS.TeleportInitFailed, function(who, _, errorMessage)
    if who == player then message("Teleport failed: " .. tostring(errorMessage)) end
end)
show("Dashboard")
scanGloves()

local function update()
    fit()
    updateExtra()
    local now, current = os.clock(), slaps()
    local elapsed = now - started
    if current ~= nil then
        if last ~= nil and current > last then
            local delta = current - last
            earned = earned + delta
            table.insert(gains, {time = now, amount = delta})
            table.insert(log, 1, "+" .. number(delta) .. " slaps at " .. duration(elapsed))
            while #log > 3 do table.remove(log) end
        end
        last = current
    else
        last = nil
    end
    local recent = 0
    for index = #gains, 1, -1 do
        if now - gains[index].time > 60 then table.remove(gains, index)
        else recent = recent + gains[index].amount end
    end
    local rate = recent * 60 / math.max(1, math.min(elapsed, 60))
    totalLabel.Text = number(current)
    earnedLabel.Text = number(earned)
    rateLabel.Text = current ~= nil and string.format("%.1f", rate) or "Unavailable"
    sessionLabel.Text = "Session " .. duration(elapsed)
    activityLabel.Text = #log > 0 and table.concat(log, "\n") or "No slap gains recorded this session."
    if goal and current ~= nil then
        fill.Size = UDim2.fromScale(math.clamp(current / goal, 0, 1), 1)
        local remaining = math.max(0, goal - current)
        if remaining == 0 then
            progressLabel.Text = "Goal reached / " .. number(goal)
            if not goalNotified then message("Slap goal reached.") goalNotified = true end
        else
            local eta = rate > 0 and duration(remaining / rate * 60) or "Waiting for gains"
            progressLabel.Text = number(remaining) .. " left / ETA " .. eta
        end
    else
        fill.Size = UDim2.fromScale(0, 1)
        progressLabel.Text = goal and "Waiting for slap data" or "No goal set"
    end
end
update()
task.spawn(function()
    while alive do
        task.wait(0.5)
        if alive then update() end
    end
end)
