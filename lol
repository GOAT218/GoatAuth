
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

-- Load LinoriaLib with fallback attempts
local Library
local libSuccess = pcall(function()
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/GOAT218/GoatAuth/refs/heads/main/loll"))()
end)


local ThemeManager, SaveManager
if Library then
    pcall(function()
        ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
    end)
    pcall(function()
        SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()
    end)
end

local Window = Library:CreateWindow({
    Title = 'GOATHUB | Ninja Tycoon',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
    ShowCustomCursor = false
})

-- Tabs
local Tabs = {
    Main = Window:AddTab('Main'),
    Tycoon = Window:AddTab('Tycoon'),
    Visual = Window:AddTab('Visual'),
    Misc = Window:AddTab('Misc'),
    World = Window:AddTab('World'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ===================== MAIN TAB GROUPBOXES =====================
local LeftGroupBox = Tabs.Main:AddLeftGroupbox('Silent Aim')
local AimSettingsGroupBox = Tabs.Main:AddRightGroupbox('Aim Settings')
local ReachGroupBox = Tabs.Main:AddRightGroupbox('Reach')
local PlayerGroupBox = Tabs.Main:AddLeftGroupbox('Player')
local LocalPlayerModsBox = Tabs.Main:AddLeftGroupbox('Local Player Mods')
local CameraGroupBox = Tabs.Main:AddLeftGroupbox('Camera')
local HitboxGroupBox = Tabs.Main:AddLeftGroupbox('Hitbox Expander')
local NpcKillAuraGroupBox = Tabs.Main:AddRightGroupbox('NPC KillAura')

-- ===================== SILENT AIM =====================
local SA = {
    Enabled = false,
    ShowFov = false,
    FovColor = Color3.fromRGB(255, 255, 255),
    TargetPart = "HumanoidRootPart",
    FovRadius = 150,
    Highlight = false,
    PredictionEnabled = false,
    PredictionStrength = 100,
    ProjectileSpeed = 200,
    SmartFOV = false,
}

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
if not Camera then
    Camera = workspace:FindFirstChildWhichIsA("Camera")
        or (pcall(function() return workspace:WaitForChild("Camera", 5) end) and workspace:FindFirstChild("Camera"))
        or workspace.CurrentCamera
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera or Camera
end)
local LP = Players.LocalPlayer
local mouse = LP:GetMouse()

-- Velocity tracking cache for smarter prediction
local velocityCache = {}
local function getSmartVelocity(part)
    if not part then return Vector3.new() end
    local vel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new()
    local cache = velocityCache[part]
    if not cache then
        velocityCache[part] = {vel, tick()}
        return vel
    end
    local smoothed = cache[1]:Lerp(vel, 0.3)
    velocityCache[part] = {smoothed, tick()}
    if tick() - cache[2] > 5 then
        velocityCache[part] = nil
    end
    return smoothed
end

-- Cached best target for silent aim (refreshed asynchronously to avoid __index lag)
local cachedBestTarget = nil
local cachedBestTargetPos = nil

-- FOV Circle
local fov = Drawing.new("Circle")
fov.Thickness = 1
fov.NumSides = 64
fov.Color = Color3.fromRGB(255, 255, 255)
fov.Transparency = 0.8
fov.Filled = false
fov.Visible = false

-- Crosshair lines
local crosshair = {
    Line1 = Drawing.new("Line"),
    Line2 = Drawing.new("Line"),
    Line3 = Drawing.new("Line"),
    Line4 = Drawing.new("Line"),
    TargetLine = Drawing.new("Line")
}

for i = 1, 4 do
    local line = crosshair["Line" .. i]
    line.Thickness = 2
    line.Color = Color3.fromRGB(255, 100, 255)
    line.Transparency = 0.9
    line.Visible = false
end

crosshair.TargetLine.Thickness = 2
crosshair.TargetLine.Color = Color3.fromRGB(255, 50, 50)
crosshair.TargetLine.Transparency = 0.7
crosshair.TargetLine.Visible = false

local crosshairRotation = 0
local highlights = {}

local function cleanupDrawing()
    pcall(function()
        if fov then fov:Remove() end
    end)
    for _, obj in pairs(crosshair) do
        pcall(function()
            if obj then obj:Remove() end
        end)
    end
end

local function ensureHighlightForPlayer(plr)
    if not plr then return end
    local h = highlights[plr]
    if not h then
        h = Instance.new("Highlight")
        h.FillColor = Color3.fromRGB(0, 255, 255)
        h.FillTransparency = 0.7
        h.OutlineTransparency = 0
        h.Parent = workspace
        highlights[plr] = h
    end
    h.Adornee = plr.Character
    h.Enabled = true
end

local function clearHighlights(except)
    for plr, h in pairs(highlights) do
        if not except or not except[plr] then
            h.Enabled = false
            h.Adornee = nil
        end
    end
end

Players.PlayerRemoving:Connect(function(plr)
    local h = highlights[plr]
    if h then h:Destroy(); highlights[plr] = nil end
end)

-- Shared helper: find best target in FOV, returns target BasePart or nil
local function SA_getBestTarget()
    local centre = fov.Position
    local fovCap = SA.FovRadius
    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local origin = myRoot and myRoot.Position or Camera.CFrame.Position
    local best, dst = nil, fovCap

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local ch = p.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local part = ch and ch:FindFirstChild(SA.TargetPart or "HumanoidRootPart")
            if part and hum and hum.Health > 0 and part:IsA("BasePart") then
                local pos = part.Position
                if SA.PredictionEnabled then
                    local dist = (origin - pos).Magnitude
                    local vel = getSmartVelocity(part)
                    local t = math.clamp(dist / (SA.ProjectileSpeed or 200), 0.05, 1.5)
                    pos = pos + vel * t * ((SA.PredictionStrength or 100) / 100)
                end
                local vec, onScreen = Camera:WorldToScreenPoint(pos)
                if onScreen then
                    local d = (Vector2.new(vec.X, vec.Y) - centre).Magnitude
                    if d < dst then best, dst = part, d end
                end
            end
        end
    end
    return best
end

-- Screen centre for FOV (mouse / touch / SmartFOV). Mutates fov.Position; returns centre Vector2.
local function SA_syncScreenCentre()
    local centre
    if UIS.TouchEnabled then
        centre = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        local ml = UIS:GetMouseLocation()
        centre = Vector2.new(ml.X, ml.Y)
    end
    fov.Position = centre

    if SA.SmartFOV then
        local nearestDist = math.huge
        local nearestPos = nil
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local ch = p.Character
                local targetPart = ch and ch:FindFirstChild(SA.TargetPart or "HumanoidRootPart")
                if targetPart then
                    local targetVec, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
                    if onScreen then
                        local screenPos = Vector2.new(targetVec.X, targetVec.Y)
                        local absoluteDist = (screenPos - screenCenter).Magnitude
                        if absoluteDist < nearestDist then
                            nearestDist = absoluteDist
                            nearestPos = screenPos
                        end
                    end
                end
            end
        end
        if nearestPos then
            centre = nearestPos
            fov.Position = centre
        end
    end
    return centre
end

local function updateCachedBestTarget()
    if not SA.Enabled then
        cachedBestTarget = nil
        cachedBestTargetPos = nil
        return
    end
    SA_syncScreenCentre()
    local best = SA_getBestTarget()
    cachedBestTarget = best
    if best then
        local pos = best.Position
        if SA.PredictionEnabled then
            local origin = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            origin = origin and origin.Position or Camera.CFrame.Position
            local vel = getSmartVelocity(best)
            local dist = (origin - pos).Magnitude
            pos = pos + vel * math.clamp(dist / (SA.ProjectileSpeed or 200), 0.05, 1.5) * ((SA.PredictionStrength or 100) / 100)
        end
        cachedBestTargetPos = pos
    else
        cachedBestTargetPos = nil
    end
end

task.spawn(function()
    while true do
        if SA.Enabled then
            task.wait(0.05)
            updateCachedBestTarget()
        else
            task.wait(0.35)
        end
    end
end)

-- Silent Aim Render Loop (only heavy work while FOV drawing or highlights are active)
local saFrameCounter = 0
RS.RenderStepped:Connect(function(dt)
    saFrameCounter = saFrameCounter + 1

    local visualsOn = SA.ShowFov or SA.Highlight
    if not visualsOn then
        if saFrameCounter % 90 == 0 then
            fov.Visible = false
            crosshair.Line1.Visible = false
            crosshair.Line2.Visible = false
            crosshair.Line3.Visible = false
            crosshair.Line4.Visible = false
            crosshair.TargetLine.Visible = false
            clearHighlights(nil)
        end
        return
    end

    fov.Radius = SA.FovRadius
    fov.Color = SA.FovColor or fov.Color
    fov.Visible = SA.ShowFov

    local centre = SA_syncScreenCentre()

    crosshairRotation = crosshairRotation + (dt * 120)
    if crosshairRotation >= 360 then crosshairRotation = crosshairRotation - 360 end

    local nearestTarget = nil
    local nearestDist = math.huge
    local nearestPos = nil

    for _, line in pairs(crosshair) do
        if line then
            line.Visible = false
        end
    end

    -- Highlight in FOV
    if SA.Highlight then
        local keep = {}
        local allPlayers = Players:GetPlayers()
        for _, p in ipairs(allPlayers) do
            if p ~= LP then
                local ch = p.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                local targetPart = ch and ch:FindFirstChild(SA.TargetPart or "HumanoidRootPart")
                if hrp and targetPart then
                    local vec, onScreen = Camera:WorldToScreenPoint(hrp.Position)
                    if onScreen then
                        local screenPos = Vector2.new(vec.X, vec.Y)
                        local d = (screenPos - centre).Magnitude
                        if d <= SA.FovRadius then
                            ensureHighlightForPlayer(p)
                            keep[p] = true
                            if not SA.SmartFOV and d < nearestDist then
                                nearestDist = d
                                nearestTarget = p
                                local targetVec = Camera:WorldToScreenPoint(targetPart.Position)
                                nearestPos = Vector2.new(targetVec.X, targetVec.Y)
                            end
                        end
                    end
                end
            end
        end
        clearHighlights(keep)
    else
        if saFrameCounter % 10 == 0 then clearHighlights(nil) end
    end

    if nearestPos and SA.ShowFov then
        crosshair.TargetLine.From = centre
        crosshair.TargetLine.To = nearestPos
        crosshair.TargetLine.Visible = true
    else
        crosshair.TargetLine.Visible = false
    end
end)

-- Silent Aim — Dual Hook Strategy
-- Layer 1: mouse.__index hook (for tools that read mouse.Hit / mouse.Target)
-- Layer 2: FireServer hook (intercepts CFrame/Vector3 args in attack remotes)

local mt = getrawmetatable(game)
local originalIndex = mt.__index
local hookFn

-- Layer 1: mouse metatable hook
local function applyHook()
    local ok = pcall(function()
        setreadonly(mt, false)
        hookFn = newcclosure(function(t, k)
            if SA.Enabled and t == mouse and (k == "Hit" or k == "Target") then
                -- HitChance gate
                if SA.HitChance and SA.HitChance < 100 then
                    if math.random(1, 100) > SA.HitChance then
                        return originalIndex(t, k)
                    end
                end
                local best = cachedBestTarget
                local pos = cachedBestTargetPos
                if best and pos then
                    if k == "Hit" then return CFrame.new(pos)
                    else return best end
                end
            end
            return originalIndex(t, k)
        end)
        mt.__index = hookFn
        setreadonly(mt, true)
    end)
    return ok
end

if applyHook() then
    task.spawn(function()
        while true do
            task.wait(2)
            if getrawmetatable(game).__index ~= hookFn then applyHook() end
        end
    end)
end





-- Silent Aim UI
LeftGroupBox:AddToggle('SilentAimEnabled', {
    Text = 'Enable Silent Aim',
    Default = false,
    Callback = function(v) SA.Enabled = v end
}):AddKeyPicker('SilentAimKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Silent Aim',
    NoUI = false,
    Callback = function(v)
        Toggles.SilentAimEnabled:SetValue(v)
    end
})

local SADepbox = LeftGroupBox:AddDependencyBox()
SADepbox:AddSlider('SilentAimHitChance', {
    Text = 'Hit Chance (%)',
    Default = 100,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(v) SA.HitChance = v end
})
SADepbox:SetupDependencies({{ Toggles.SilentAimEnabled, true }})





LeftGroupBox:AddDivider()


-- Mouse Aimbot
local MA = {
    Enabled = false,
    Smoothness = 0.15,
    Thread = nil,
}

local function getAimTarget()
    local AimSettings_TargetMode = Options.AimTargetMode and Options.AimTargetMode.Value or "Mouse"
    local AimSettings_VisCheck = Toggles.AimVisCheck and Toggles.AimVisCheck.Value or false
    local AimSettings_UseFOV = Toggles.AimUseFOV and Toggles.AimUseFOV.Value or false
    local AimSettings_FOVSize = Options.AimFOVSize and Options.AimFOVSize.Value or 150

    local bestTarget = nil
    local bestDist = math.huge
    local centre
    if AimSettings_TargetMode == "Mouse" then
        local ml = UIS:GetMouseLocation()
        centre = Vector2.new(ml.X, ml.Y)
    else
        centre = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local ch = p.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        if not root or not hum or hum.Health <= 0 then continue end

        if AimSettings_VisCheck then
            local result = workspace:Raycast(Camera.CFrame.Position, (root.Position - Camera.CFrame.Position).Unit * 1000,
                RaycastParams.new())
            if not result or not result.Instance or not result.Instance:IsDescendantOf(ch) then
                continue
            end
        end

        local vec, onScreen = Camera:WorldToScreenPoint(root.Position)
        if not onScreen then continue end
        local screenPos = Vector2.new(vec.X, vec.Y)
        local d = (screenPos - centre).Magnitude
        if AimSettings_UseFOV and d > AimSettings_FOVSize then continue end

        if d < bestDist then
            bestDist = d
            bestTarget = root
        end
    end
    return bestTarget
 end

local function startMouseAimbot()
    if MA.Thread then task.cancel(MA.Thread) end
    MA.Thread = task.spawn(function()
        while MA.Enabled do
            local target = getAimTarget()
            if target then
                local AimSettings_Prediction = Toggles.AimPrediction and Toggles.AimPrediction.Value or false
                local pos = target.Position
                if AimSettings_Prediction then
                    local vel = getSmartVelocity(target)
                    local dist = (Camera.CFrame.Position - pos).Magnitude
                    pos = pos + vel * math.clamp(dist / (SA.ProjectileSpeed or 200), 0.05, 1.5)
                end
                local screenPos, onScreen = Camera:WorldToScreenPoint(pos)
                if onScreen then
                    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                    local currentPos = UIS:GetMouseLocation()
                    local lerpPos = currentPos:Lerp(targetPos, MA.Smoothness)
                    mousemoverel(lerpPos.X - currentPos.X, lerpPos.Y - currentPos.Y)
                end
            end
            task.wait(0.03)
        end
    end)
end

LeftGroupBox:AddToggle('MouseAimbotEnabled', {
    Text = 'Mouse Aimbot',
    Default = false,
    Callback = function(v)
        MA.Enabled = v
        if v then startMouseAimbot()
        else
            if MA.Thread then task.cancel(MA.Thread) MA.Thread = nil end
        end
    end
}):AddKeyPicker('MouseAimbotKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Mouse Aimbot',
    NoUI = false,
    Callback = function(v)
        Toggles.MouseAimbotEnabled:SetValue(v)
    end
})

local MADepbox = LeftGroupBox:AddDependencyBox()
MADepbox:AddSlider('MouseAimbotSmoothness', {
    Text = 'Smoothness',
    Default = 15,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(v) MA.Smoothness = v / 100 end
})
MADepbox:SetupDependencies({{ Toggles.MouseAimbotEnabled, true }})

-- ===================== AIM SETTINGS (shared for SA + Aimbot) =====================
SA.HitChance = 100

AimSettingsGroupBox:AddDropdown('AimTargetMode', {
    Values = { 'Mouse', 'Closest' },
    Default = 1,
    Text = 'Target Mode',
    Callback = function(v)
        SA.SmartFOV = (v == 'Closest')
    end
})


AimSettingsGroupBox:AddDivider()


AimSettingsGroupBox:AddToggle('AimVisCheck', {
    Text = 'Visible Check',
    Default = false,
    Callback = function(v) end
})

AimSettingsGroupBox:AddToggle('AimPrediction', {
    Text = 'Prediction',
    Default = false,
    Callback = function(v) SA.PredictionEnabled = v end
})

-- ===================== AUTO-DETECT PROJECTILE SPEED =====================
local projSpeedTracker = {
    Part = nil,
    LastPos = nil,
    LastTick = 0
}

local function onProjectileAdded(child)
    if not SA.PredictionEnabled then return end
    task.defer(function()
        local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
        if part then
            projSpeedTracker.Part = part
            projSpeedTracker.LastPos = part.Position
            projSpeedTracker.LastTick = tick()
        end
    end)
end

local debrisFolder = workspace:FindFirstChild("DebrisFolder")
if debrisFolder then
    debrisFolder.ChildAdded:Connect(onProjectileAdded)
end
workspace.ChildAdded:Connect(function(child)
    if child.Name == "DebrisFolder" then
        child.ChildAdded:Connect(onProjectileAdded)
    end
end)

task.spawn(function()
    while true do
        if SA.PredictionEnabled then
            task.wait(0.05)
            if projSpeedTracker.Part and projSpeedTracker.Part.Parent then
                local currentPos = projSpeedTracker.Part.Position
                local t = tick()
                local dt = t - projSpeedTracker.LastTick
                if dt > 0.05 then
                    local dist = (currentPos - projSpeedTracker.LastPos).Magnitude
                    local speed = dist / dt
                    if speed > 10 and speed < 2000 then
                        SA.ProjectileSpeed = speed
                    end
                    projSpeedTracker.LastPos = currentPos
                    projSpeedTracker.LastTick = t
                end
            end
        else
            task.wait(0.5)
        end
    end
end)


AimSettingsGroupBox:AddDivider()

AimSettingsGroupBox:AddToggle('AimUseFOV', {
    Text = 'Use FOV',
    Default = false,
    Callback = function(v) end
})

local AimFOVDepbox = AimSettingsGroupBox:AddDependencyBox()
AimFOVDepbox:AddSlider('AimFOVSize', {
    Text = 'FOV Size',
    Default = 150,
    Min = 50,
    Max = 600,
    Rounding = 0,
    Callback = function(v)
        SA.FovRadius = v
    end
})
AimFOVDepbox:AddToggle('AimShowFOV', {
    Text = 'Show FOV Circle',
    Default = false,
    Callback = function(v) SA.ShowFov = v end
}):AddColorPicker('AimShowFOVColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'FOV Circle Color',
    Callback = function(color)
        SA.FovColor = color
        pcall(function() fov.Color = color end)
    end
})
AimFOVDepbox:SetupDependencies({{ Toggles.AimUseFOV, true }})

-- ===================== REACH =====================
local ReachURL = "https://goathub.lat/api/scripts/Reach"
pcall(function()
    loadstring(game:HttpGet(ReachURL))()
end)

local function reachAPI()
    return getgenv().Reach or {}
end

ReachGroupBox:AddToggle('ReachEnabled', {
    Text = 'Extended Reach',
    Default = false,
    Callback = function(v)
        if reachAPI().SetEnabled then
            reachAPI().SetEnabled(v)
        end
    end
}):AddKeyPicker('ReachKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Extended Reach',
    NoUI = false,
    Callback = function(v)
        Toggles.ReachEnabled:SetValue(v)
    end
})

ReachGroupBox:AddSlider('ReachRange', {
    Text = 'Reach Range',
    Default = 10,
    Min = 10,
    Max = 1000,
    Rounding = 0,
    Callback = function(v)
        local n = tonumber(v)
        if reachAPI().SetRange then
            reachAPI().SetRange(n)
        end
    end
})

-- ===================== HITBOX EXPANDER =====================
-- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
do
local BoxExpander = {
    Enabled = false,
    Part = "Head",
    Size = 8,
    Target = "NPC",
}

-- Two systems run together, combined (per confirmed working setup):
--
-- 1. A direct resize of the character's REAL Head/HumanoidRootPart, at the FULL
--    BoxExpanderSize. This game's own combat validation evidently checks
--    specifically for the real part (a same-shaped proxy alone doesn't register
--    as a hit in actual gameplay), so this is what actually lands hits. But
--    resizing an unowned, physically-simulated part freezes the target IF
--    they're at rest when it happens: resting parts stop replicating position
--    updates to save bandwidth, so this client's local write is the last thing
--    that "sticks." A moving target is safe since their real owner keeps
--    re-sending the true position every tick. So this only resizes the real
--    part while it's confirmed moving (checked every single Heartbeat frame,
--    requiring MOVING_CONFIRM_FRAMES of consecutive movement first so a player
--    who's about to stop never gets touched), restoring it the instant it's not.
--
-- 2. A smaller ANCHORED PROXY part alongside it, sized to a fraction of
--    BoxExpanderSize. Anchored parts have no network ownership at all, so this
--    never freezes anyone; it's repositioned every frame to follow the real
--    part and helps broader raycasts/targeting notice the target from further
--    out, without itself risking the same freeze.
local original = {}
local movingStreak = {}
local hitboxParts = {}
local followConns = {}
local boxConn

local MOVING_VELOCITY_THRESHOLD = 2
local MOVING_CONFIRM_FRAMES = 8
-- The real part (resized in applyReal) gets the FULL slider size -- it's what
-- actually registers hits. The proxy (applyProxy) stays smaller since it's only
-- there to help broader raycasts/targeting notice the target from further out.
local PROXY_RESIZE_RATIO = 0.5
local MIN_PROXY_RESIZE = 2

local function findPart(character)
    if not character then return nil end
    if BoxExpander.Part == "Head" then
        return character:FindFirstChild("Head") or character:FindFirstChild("HeadHB")
    end
    return character:FindFirstChild("HumanoidRootPart")
end

local function restorePart(part)
    movingStreak[part] = nil
    local o = original[part]
    if not o then return end
    pcall(function()
        part.Size = o.Size
        part.Transparency = o.Transparency
        part.CanCollide = o.CanCollide
        part.Material = o.Material
        part.Color = o.Color
    end)
    original[part] = nil
end

local function clearHitbox(character)
    local conn = followConns[character]
    if conn then
        followConns[character] = nil
        conn:Disconnect()
    end
    local hb = hitboxParts[character]
    if hb then
        hitboxParts[character] = nil
        pcall(function() hb:Destroy() end)
    end
end

local function applyProxy(character, part)
    local hb = hitboxParts[character]
    if not hb or not hb.Parent then
        hb = Instance.new("Part")
        hb.Name = "GOATHUB_Hitbox"
        hb.Anchored = true
        hb.CanCollide = false
        hb.CanTouch = true
        hb.CanQuery = true
        hb.Massless = true
        hb.Transparency = 0.7
        hb.Material = Enum.Material.Neon
        hb.Color = Color3.fromRGB(0, 170, 255)
        hb.CFrame = part.CFrame
        hb.Parent = character
        hitboxParts[character] = hb

        followConns[character] = RS.Heartbeat:Connect(function()
            if not hb.Parent or not part.Parent then
                clearHitbox(character)
                return
            end
            hb.CFrame = part.CFrame
        end)
    end
    local proxySize = math.max(MIN_PROXY_RESIZE, BoxExpander.Size * PROXY_RESIZE_RATIO)
    pcall(function()
        hb.Size = Vector3.new(proxySize, proxySize, proxySize)
    end)
end

local function applyReal(part)
    local isMoving = part.AssemblyLinearVelocity.Magnitude > MOVING_VELOCITY_THRESHOLD
    if not isMoving then
        restorePart(part)
        return
    end

    local streak = (movingStreak[part] or 0) + 1
    movingStreak[part] = streak
    if streak < MOVING_CONFIRM_FRAMES then
        return -- not confirmed moving long enough yet; leave it alone
    end

    if not original[part] then
        original[part] = {
            Size = part.Size,
            Transparency = part.Transparency,
            CanCollide = part.CanCollide,
            Material = part.Material,
            Color = part.Color,
        }
    end
    pcall(function()
        part.Size = Vector3.new(BoxExpander.Size, BoxExpander.Size, BoxExpander.Size)
        part.Transparency = 0.7
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(0, 170, 255)
    end)
end

local function applyPart(character, part)
    if not part or not part:IsA("BasePart") then return end
    applyProxy(character, part)
    applyReal(part)
end

-- Only real enemies get expanded in NPC mode -- excludes quest-givers,
-- dialogue NPCs, and decorative statues. Same tagging convention the rest of
-- this script already uses for combat targeting (see isNPC further down):
-- real enemies carry an EnemyNPC tag; friendly/decorative ones use a
-- "StatueHum"-named Humanoid or a TravelNinja/STATUE model name.
local function isHittableNPC(model)
    if not model:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    if model:FindFirstChild("EnemyNPC") then return true end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.Name == "StatueHum" then return false end
    if model.Name:find("TravelNinja") or model.Name:find("STATUE") then return false end
    return true
end

local function getTargets()
    local targets = {}
    if BoxExpander.Target == "NPC" then
        for _, model in ipairs(workspace:GetChildren()) do
            if isHittableNPC(model) then
                table.insert(targets, model)
            end
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                table.insert(targets, plr.Character)
            end
        end
    end
    return targets
end

local function stopBox()
    BoxExpander.Enabled = false
    if boxConn then
        boxConn:Disconnect()
        boxConn = nil
    end
    for part in pairs(original) do
        restorePart(part)
    end
    movingStreak = {}
    for character in pairs(hitboxParts) do
        clearHitbox(character)
    end
end

local function startBox()
    if boxConn then boxConn:Disconnect() end
    boxConn = RS.Heartbeat:Connect(function()
        if not BoxExpander.Enabled then return end
        for _, character in ipairs(getTargets()) do
            local part = findPart(character)
            if part then
                applyPart(character, part)
            end
        end
    end)
end

HitboxGroupBox:AddToggle('BoxExpanderEnabled', {
    Text = 'Box Expander',
    Default = false,
    Callback = function(v)
        BoxExpander.Enabled = v
        if v then startBox() else stopBox() end
    end
}):AddKeyPicker('BoxExpanderKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Hitbox Expander',
    NoUI = false,
    Callback = function(v)
        Toggles.BoxExpanderEnabled:SetValue(v)
    end
})

HitboxGroupBox:AddDropdown('BoxExpanderPart', {
    Values = {"Head", "HumanoidRootPart"},
    Default = 1,
    Text = 'Box Part',
    Callback = function(v)
        BoxExpander.Part = v
        for part in pairs(original) do restorePart(part) end
        for character in pairs(hitboxParts) do clearHitbox(character) end
    end
})

-- NPC mode only expands actual hostile enemies (isHittableNPC), never quest-givers,
-- dialogue NPCs, or decorative statues, so switching to NPC won't touch every NPC
-- in the game indiscriminately.
HitboxGroupBox:AddDropdown('BoxExpanderTarget', {
    Values = {"Player", "NPC"},
    Default = 2,
    Text = 'Target',
    Callback = function(v)
        BoxExpander.Target = v
        for part in pairs(original) do restorePart(part) end
        for character in pairs(hitboxParts) do clearHitbox(character) end
    end
})

-- Note: past a certain size the box's own half-extent exceeds normal attack
-- range, meaning YOU end up standing inside its volume when you get close enough
-- to attack. Raycasts only register a part when they enter it from outside --
-- starting inside it, the ray just skips it and hits the real, small body part
-- instead, so a very large size may stop registering hits up close.
HitboxGroupBox:AddSlider('BoxExpanderSize', {
    Text = 'Box Size',
    Default = 8,
    Min = 2,
    Max = 1000,
    Rounding = 0,
    Callback = function(v) BoxExpander.Size = math.clamp(v, 2, 1000) end
})

Players.PlayerRemoving:Connect(function(plr)
    if plr == LP then
        stopBox()
        return
    end
    local character = plr.Character
    if not character then return end
    local part = findPart(character)
    if part then restorePart(part) end
    clearHitbox(character)
end)
end -- Hitbox Expander scope

-- ===================== PLAYER FEATURES =====================
-- No Barrier Damage
local noBarrierDamageEnabled = false
local destroyedBarrierTouches = {}

local function disableBarrierLasers()
    local tycoonKit = workspace:FindFirstChild("Zednov's Tycoon Kit")
    local tycoons = tycoonKit and tycoonKit:FindFirstChild("Tycoons")
    if not tycoons then return 0 end

    local changed = 0
    for _, tycoon in pairs(tycoons:GetChildren()) do
        local purchased = tycoon:FindFirstChild("PurchasedObjects")
        if not purchased then continue end

        for _, obj in pairs(purchased:GetChildren()) do
            if obj.Name:lower():find("barrier") then
                for _, d in pairs(obj:GetDescendants()) do
                    local touch = d:FindFirstChild("TouchInterest")
                    if touch and not destroyedBarrierTouches[touch] then
                        destroyedBarrierTouches[touch] = true
                        pcall(function() touch:Destroy() end)
                        changed += 1
                    end
                end
            end

            local lasers = obj:FindFirstChild("Lasers")
            if lasers then
                for _, laser in pairs(lasers:GetChildren()) do
                    local touch = laser:FindFirstChild("TouchInterest")
                    if touch and not destroyedBarrierTouches[touch] then
                        destroyedBarrierTouches[touch] = true
                        pcall(function() touch:Destroy() end)
                        changed += 1
                    end
                end
            end
        end
    end
    return changed
end

PlayerGroupBox:AddToggle('NoBarrierDamage', {
    Text = 'No barrier damage',
    Default = false,
    Callback = function(state)
        noBarrierDamageEnabled = state
        if state then
            task.spawn(function()
                while noBarrierDamageEnabled do
                    local success, res = pcall(disableBarrierLasers)
                    if success then
                        local changed = tonumber(res) or 0
                        if changed == 0 then
                            task.wait(2)
                        else
                            task.wait(1)
                        end
                    else
                        task.wait(2)
                    end
                end
            end)
        end
    end
})

-- Instant ProximityPrompt (no hold, no line of sight)
local instantPromptEnabled = false
local instantPromptConn = nil
local promptDefaults = {}

local function applyInstantPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    if not promptDefaults[prompt] then
        promptDefaults[prompt] = {
            HoldDuration = prompt.HoldDuration,
            RequiresLineOfSight = prompt.RequiresLineOfSight,
        }
    end
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
end

local function restoreInstantPrompt(prompt)
    local orig = promptDefaults[prompt]
    if not orig then return end
    pcall(function()
        if prompt.Parent then
            prompt.HoldDuration = orig.HoldDuration
            prompt.RequiresLineOfSight = orig.RequiresLineOfSight
        end
    end)
    promptDefaults[prompt] = nil
end

local function enableInstantPrompts()
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            applyInstantPrompt(obj)
        end
    end
    if not instantPromptConn then
        instantPromptConn = game.DescendantAdded:Connect(function(obj)
            if instantPromptEnabled and obj:IsA("ProximityPrompt") then
                applyInstantPrompt(obj)
            end
        end)
    end
end

local function disableInstantPrompts()
    for prompt in pairs(promptDefaults) do
        restoreInstantPrompt(prompt)
    end
    if instantPromptConn then
        instantPromptConn:Disconnect()
        instantPromptConn = nil
    end
end

PlayerGroupBox:AddToggle('InstantPrompt', {
    Text = 'Instant Prompt',
    Default = false,
    Tooltip = 'All ProximityPrompts activate instantly with no hold time and no line-of-sight check.',
    Callback = function(state)
        instantPromptEnabled = state
        if state then
            enableInstantPrompts()
        else
            disableInstantPrompts()
        end
    end
})

-- Infinite Jump (Press-based, works mid-air)
local infiniteJump = false
local infiniteJumpConnection

local function setupInfiniteJump(humanoid)
    if infiniteJumpConnection then infiniteJumpConnection:Disconnect() end

    infiniteJumpConnection = UIS.JumpRequest:Connect(function()
        if not infiniteJump then return end
        if not humanoid or humanoid:GetState() == Enum.HumanoidStateType.Dead then return end

        -- Get character root part
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Force jump state regardless of being on ground
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

        -- Apply upward velocity for consistent jump height in air
        -- Only add velocity if we're already in air (not on ground)
        if humanoid.FloorMaterial == Enum.Material.Air then
            local currentVel = hrp.Velocity
            hrp.Velocity = Vector3.new(currentVel.X, math.max(currentVel.Y, 50), currentVel.Z)
        end
    end)
end

LP.CharacterAdded:Connect(function(char)
    local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
    if infiniteJump then
        setupInfiniteJump(humanoid)
    end
end)

LocalPlayerModsBox:AddToggle('InfiniteJump', {
    Text = 'Infinite Jump',
    Default = false,
    Tooltip = 'Press jump repeatedly in mid-air to jump again. Works like double/triple jump but infinite.',
    Callback = function(state)
        infiniteJump = state
        if LP.Character then
            local humanoid = LP.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                setupInfiniteJump(humanoid)
            end
        end
    end
}):AddKeyPicker('InfiniteJumpKeybind', {
    Default = 'J',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Infinite Jump',
    NoUI = false,
    Callback = function(v)
        Toggles.InfiniteJump:SetValue(v)
    end
})

-- Noclip
local noclip = false
local noclipConnection

LocalPlayerModsBox:AddToggle('Noclip', {
    Text = 'Noclip',
    Default = false,
    Tooltip = 'Disables collision on all character parts every Stepped frame, allowing you to walk through walls and objects.',
    Callback = function(state)
        noclip = state
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
        if state then
            local noclipCachedChar = nil
            local noclipCachedParts = {}
            noclipConnection = RS.Stepped:Connect(function()
                if noclip and LP.Character then
                    if noclipCachedChar ~= LP.Character then
                        noclipCachedChar = LP.Character
                        noclipCachedParts = {}
                        for _, part in ipairs(LP.Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                table.insert(noclipCachedParts, part)
                            end
                        end
                    end
                    for _, part in ipairs(noclipCachedParts) do
                        if part.Parent then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        else
            if LP.Character then
                for _, part in ipairs(LP.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
}):AddKeyPicker('NoclipKeybind', {
    Default = 'V',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Noclip',
    NoUI = false,
    Callback = function(v)
        Toggles.Noclip:SetValue(v)
    end
})

-- God Mode
local GodMode = {
    Enabled = false,
    Forcefield = Instance.new("ForceField"),
    Connections = {}
}
GodMode.Forcefield.Visible = true

local function setupGodCharacter(character)
    GodMode.Forcefield.Parent = character
    local tycoons = workspace["Zednov's Tycoon Kit"].Tycoons:GetChildren()
    for _, tycoon in pairs(tycoons) do
        local purchasedObjects = tycoon:FindFirstChild("PurchasedObjects")
        if purchasedObjects then
            for _, item in pairs(purchasedObjects:GetChildren()) do
                local healingPad = item:FindFirstChild("HealingPad")
                if healingPad then
                    healingPad.Size = Vector3.new(0.001, 0, 0)
                    healingPad.Transparency = 0
                end
            end
        end
    end
end

PlayerGroupBox:AddToggle('GodMode', {
    Text = 'GOD MODE',
    Default = false,
    Callback = function(state)
        GodMode.Enabled = state
        for _, conn in pairs(GodMode.Connections) do conn:Disconnect() end
        GodMode.Connections = {}
        if state then
            if LP.Character then
                setupGodCharacter(LP.Character)
            end
            table.insert(GodMode.Connections, LP.CharacterAdded:Connect(setupGodCharacter))
            table.insert(GodMode.Connections, RS.Heartbeat:Connect(function()
                if not GodMode.Enabled then return end
                local char = LP.Character
                local rootPart = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChild("Humanoid")
                if not rootPart or not humanoid then return end
                local tycoons = workspace["Zednov's Tycoon Kit"].Tycoons:GetChildren()
                for _, tycoon in pairs(tycoons) do
                    local purchasedObjects = tycoon:FindFirstChild("PurchasedObjects")
                    if purchasedObjects then
                        for _, item in pairs(purchasedObjects:GetChildren()) do
                            local healingPad = item:FindFirstChild("HealingPad")
                            if healingPad and healingPad.Parent then
                                healingPad.Position = rootPart.Position
                                if (healingPad.Position - rootPart.Position).Magnitude < 5 then
                                    humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 5)
                                end
                            end
                        end
                    end
                end
            end))
        else
            GodMode.Forcefield.Parent = nil
        end
    end
}):AddKeyPicker('GodModeKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'God Mode',
    NoUI = false,
    Callback = function(v)
        Toggles.GodMode:SetValue(v)
    end
})

-- Infinite Dash (Keybind Override Method)
local InfiniteDash = {
    Enabled = false,
    OriginalAction = nil,
    DashKey = Enum.KeyCode.E
}

local function playDashAnimation(char)
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://12003682032"
        local loaded = hum:LoadAnimation(anim)
        if loaded then loaded:Play() end
    end
end

local function playDashSound(hrp)
    task.spawn(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://4689460614"
        sound.Volume = 1
        sound.Parent = hrp
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
    end)
end

local function spawnSprintParticle(hrp)
    task.spawn(function()
        local sprintParticle = game:GetService("ReplicatedStorage"):FindFirstChild("ModuleAssets")
            and game.ReplicatedStorage.ModuleAssets:FindFirstChild("SprintParticle")
        if sprintParticle then
            local clone = sprintParticle:Clone()
            clone.Parent = hrp
            clone.Enabled = true
            game:GetService("Debris"):AddItem(clone, 1)
            task.delay(0.1, function()
                if clone then clone.Enabled = false end
            end)
        end
    end)
end

local function spawnDashLines(hrp)
    task.spawn(function()
        local dashLines = game:GetService("ReplicatedStorage"):FindFirstChild("ModuleAssets")
            and game.ReplicatedStorage.ModuleAssets:FindFirstChild("DashLines")
        if dashLines then
            local clone = dashLines:Clone()
            clone.Parent = hrp
            clone.Enabled = true
            game:GetService("Debris"):AddItem(clone, 2)
            task.delay(0.5, function()
                if clone then clone.Enabled = false end
            end)
        end
    end)
end

local function enableInfiniteDash()
    local CAS = game:GetService("ContextActionService")
    local player = game:GetService("Players").LocalPlayer

    CAS:UnbindAction("Dashing")

    CAS:BindAction("InfiniteDashing", function(actionName, inputState)
        if inputState == Enum.UserInputState.Begin then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Velocity = hrp.CFrame.lookVector * 200
                playDashAnimation(char)
                playDashSound(hrp)
                spawnSprintParticle(hrp)
                spawnDashLines(hrp)
            end
        end
        return Enum.ContextActionResult.Sink
    end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonY)

    CAS:SetPosition("InfiniteDashing", UDim2.new(0.4, 0, 0.1, 0))
end

local function disableInfiniteDash()
    local CAS = game:GetService("ContextActionService")
    CAS:UnbindAction("InfiniteDashing")

    -- Rebind original (if script exists)
    local dashScript = workspace:FindFirstChild("vdvdfbdfv") and workspace.vdvdfbdfv:FindFirstChild("Dash")
    if dashScript and not dashScript.Disabled then
        -- Let the original script handle it
        local player = game:GetService("Players").LocalPlayer
        local function dashRequest(_, p13)
            if p13 == Enum.UserInputState.Begin then
                local env = getfenv(dashScript)
                if env.Dash then env.Dash() end
            end
        end
        CAS:BindAction("Dashing", dashRequest, true, Enum.KeyCode.E, Enum.KeyCode.ButtonY)
        CAS:SetPosition("Dashing", UDim2.new(0.4, 0, 0.1, 0))
    end
end

-- UI Toggle
PlayerGroupBox:AddToggle('NoDashCooldown', {
    Text = 'No Dash Cooldown',
    Default = false,
    Tooltip = 'Replaces the original dash with an instant cooldown-free version using keybind override.',
    Callback = function(state)
        InfiniteDash.Enabled = state
        if state then
            enableInfiniteDash()
        else
            disableInfiniteDash()
        end
    end
}):AddKeyPicker('NoDashCooldownKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'No Dash Cooldown',
    NoUI = false,
    Callback = function(v)
        Toggles.NoDashCooldown:SetValue(v)
    end
})

-- Persist dash override + walk speed on respawn
local function applyWalkSettingsToCharacter(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass('Humanoid') or char:WaitForChild('Humanoid', 3)
    if not hum then return end
    if Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value and Options.WalkSpeed then
        pcall(function() hum.WalkSpeed = Options.WalkSpeed.Value end)
    end
end

LP.CharacterAdded:Connect(function(char)
    -- Dash scripts often rebind on spawn; re-apply after a short delay.
    if Toggles.NoDashCooldown and Toggles.NoDashCooldown.Value then
        task.delay(0.35, function()
            if Toggles.NoDashCooldown and Toggles.NoDashCooldown.Value then
                pcall(enableInfiniteDash)
            end
        end)
    end
    task.defer(function()
        applyWalkSettingsToCharacter(char)
    end)
end)

-- Apply immediately for current character (script injected mid-life)
task.defer(function()
    if LP.Character then
        applyWalkSettingsToCharacter(LP.Character)
        if Toggles.NoDashCooldown and Toggles.NoDashCooldown.Value then
            task.delay(0.35, function()
                if Toggles.NoDashCooldown and Toggles.NoDashCooldown.Value then
                    pcall(enableInfiniteDash)
                end
            end)
        end
    end
end)

-- Instant Wall Climb
local wallClimbEnabled = false
local wallClimbConnections = {}

local function enableWallClimb()
    if wallClimbEnabled then return end
    wallClimbEnabled = true
    local player = Players.LocalPlayer

    local function setup(char)
        local hum = char:WaitForChild("Humanoid")
        local root = char:WaitForChild("HumanoidRootPart")
        local debounce = false

        local function findWall()
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {char}
            params.FilterType = Enum.RaycastFilterType.Blacklist
            return workspace:Raycast(root.Position, root.CFrame.LookVector * 6, params)
        end

        local function teleportToTop(hit)
            local part = hit.Instance
            if not part then return end
            local topY = part.Position.Y + (part.Size.Y / 2) + 4
            root.CFrame = CFrame.new(root.Position.X, topY, root.Position.Z)
        end

        local conn = UIS.JumpRequest:Connect(function()
            if not wallClimbEnabled then return end
            if debounce then return end
            if hum:GetState() ~= Enum.HumanoidStateType.Freefall then return end
            local hit = findWall()
            if not hit then return end
            debounce = true
            teleportToTop(hit)
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(0.1)
            debounce = false
        end)
        table.insert(wallClimbConnections, conn)
    end

    if player.Character then
        setup(player.Character)
    end
    table.insert(wallClimbConnections, player.CharacterAdded:Connect(setup))
end

local function disableWallClimb()
    wallClimbEnabled = false
    for _, conn in ipairs(wallClimbConnections) do
        if conn then conn:Disconnect() end
    end
    wallClimbConnections = {}
end

PlayerGroupBox:AddToggle('InstantWallClimb', {
    Text = 'Instant Wall Climb',
    Default = false,
    Callback = function(state)
        if state then enableWallClimb() else disableWallClimb() end
    end
}):AddKeyPicker('InstantWallClimbKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Instant Wall Climb',
    NoUI = false,
    Callback = function(v)
        Toggles.InstantWallClimb:SetValue(v)
    end
})

-- Invisible
local InvisibleEffect = {
    Enabled = false,
    Heartbeat = nil,
    CharConn = nil,
    DiedConn = nil,
    Character = nil,
    Humanoid = nil,
    HRP = nil,
    Parts = {},
}

local function IE_getCharacterParts(char)
    local parts = {}
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency == 0 then
            table.insert(parts, part)
        end
    end
    return parts
end

local function IE_setTransparency(active)
    local t = active and 0.5 or 0
    for _, part in pairs(InvisibleEffect.Parts) do
        if part and part.Parent then
            part.Transparency = t
        end
    end
end

local function IE_resetAll()
    InvisibleEffect.Enabled = false
    if InvisibleEffect.Humanoid and InvisibleEffect.Humanoid.Parent then
        InvisibleEffect.Humanoid.CameraOffset = Vector3.new(0, 0, 0)
    end
    IE_setTransparency(false)
end

local function IE_bindCharacter(char)
    IE_resetAll()
    InvisibleEffect.Character = char
    InvisibleEffect.Humanoid = char:WaitForChild("Humanoid")
    InvisibleEffect.HRP = char:WaitForChild("HumanoidRootPart")
    InvisibleEffect.Parts = IE_getCharacterParts(char)

    if InvisibleEffect.DiedConn then
        InvisibleEffect.DiedConn:Disconnect()
    end
    InvisibleEffect.DiedConn = InvisibleEffect.Humanoid.Died:Connect(IE_resetAll)
end

local function IE_start()
    if InvisibleEffect.Heartbeat then return end
    if LP.Character then
        IE_bindCharacter(LP.Character)
    end
    if not InvisibleEffect.CharConn then
        InvisibleEffect.CharConn = LP.CharacterAdded:Connect(IE_bindCharacter)
    end

    InvisibleEffect.Heartbeat = RS.Heartbeat:Connect(function()
        if not InvisibleEffect.Enabled then return end
        local hrp = InvisibleEffect.HRP
        local hum = InvisibleEffect.Humanoid
        if not hrp or not hrp.Parent or not hum or hum.Health <= 0 then return end

        local originalCFrame = hrp.CFrame
        local originalCameraOffset = hum.CameraOffset
        local targetCFrame = originalCFrame * CFrame.new(0, -50, 0)
        hum.CameraOffset = targetCFrame:ToObjectSpace(CFrame.new(originalCFrame.Position)).Position
        hrp.CFrame = targetCFrame
        task.defer(function()
            if hum and hum.Parent then hum.CameraOffset = originalCameraOffset end
            if hrp and hrp.Parent then hrp.CFrame = originalCFrame end
        end)
    end)
end

local function IE_stop()
    InvisibleEffect.Enabled = false
    IE_resetAll()
    if InvisibleEffect.Heartbeat then
        InvisibleEffect.Heartbeat:Disconnect()
        InvisibleEffect.Heartbeat = nil
    end
    if InvisibleEffect.CharConn then
        InvisibleEffect.CharConn:Disconnect()
        InvisibleEffect.CharConn = nil
    end
    if InvisibleEffect.DiedConn then
        InvisibleEffect.DiedConn:Disconnect()
        InvisibleEffect.DiedConn = nil
    end
end

PlayerGroupBox:AddToggle('Invisible', {
    Text = 'Invisible',
    Default = false,
    Callback = function(state)
        if state then
            IE_start()
            InvisibleEffect.Enabled = true
            IE_setTransparency(true)
        else
            IE_stop()
        end
    end
}):AddKeyPicker('InvisibleKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Invisible',
    NoUI = false,
    Callback = function(v)
        Toggles.Invisible:SetValue(v)
    end
})



LocalPlayerModsBox:AddToggle('WalkSpeedEnabled', {
    Text = 'Walk Speed',
    Default = false,
    Callback = function(state)
        if not state and LP.Character then
            local hum = LP.Character:FindFirstChildOfClass('Humanoid')
            if hum then hum.WalkSpeed = 16 end
        end
    end
}):AddKeyPicker('WalkSpeedKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Walk Speed',
    NoUI = false,
    Callback = function(v)
        Toggles.WalkSpeedEnabled:SetValue(v)
    end
})

local WalkSpeedDepbox = LocalPlayerModsBox:AddDependencyBox()
WalkSpeedDepbox:AddSlider('WalkSpeed', {
    Text = 'Walk Speed',
    Default = 30,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        if LP.Character and LP.Character:FindFirstChildOfClass('Humanoid') then
            LP.Character:FindFirstChildOfClass('Humanoid').WalkSpeed = Value
        end
    end
})
WalkSpeedDepbox:SetupDependencies({
    { Toggles.WalkSpeedEnabled, true }
})

CameraGroupBox:AddToggle('FOVEnabled', {
    Text = 'Custom FOV',
    Default = false,
    Callback = function(state)
        if not state then
            workspace.CurrentCamera.FieldOfView = 70
        end
    end
})

local FOVDepbox = CameraGroupBox:AddDependencyBox()
FOVDepbox:AddSlider('FOV', {
    Text = 'Field of View',
    Default = 70,
    Min = 70,
    Max = 120,
    Rounding = 0,
    Callback = function(Value)
        workspace.CurrentCamera.FieldOfView = Value
    end
})
FOVDepbox:SetupDependencies({
    { Toggles.FOVEnabled, true }
})

-- Aspect Ratio
-- Roblox doesn't expose a real "aspect ratio" property, so this recomputes FOV
-- from the vertical FOV using the standard hFOV/vFOV aspect relationship to
-- simulate a wider/narrower view (e.g. ultrawide).
CameraGroupBox:AddToggle('CustomAspectRatio', {
    Text = 'Custom Aspect Ratio',
    Default = false,
    Tooltip = 'Recomputes FOV to simulate a custom aspect ratio.',
    Callback = function(state)
        if not state then
            local baseFov = (Toggles.FOVEnabled and Toggles.FOVEnabled.Value and Options.FOV.Value) or 70
            workspace.CurrentCamera.FieldOfView = baseFov
        end
    end
})

local AspectRatioDepbox = CameraGroupBox:AddDependencyBox()
AspectRatioDepbox:AddSlider('AspectRatio', {
    Text = 'Aspect Ratio',
    Default = 1.78,
    Min = 0.5,
    Max = 3.5,
    Rounding = 2,
    Callback = function(v)
        local baseFov = (Toggles.FOVEnabled and Toggles.FOVEnabled.Value and Options.FOV.Value) or 70
        local vFovRad = math.rad(baseFov)
        local hFovRad = 2 * math.atan(math.tan(vFovRad / 2) * v)
        workspace.CurrentCamera.FieldOfView = math.deg(hFovRad)
    end
})
AspectRatioDepbox:SetupDependencies({
    { Toggles.CustomAspectRatio, true }
})

-- Fly
local Fly = {
    Enabled = false,
    Speed = 50,
    Connection = nil,
    Up = false,
    Down = false,
    Keys = {W = false, A = false, S = false, D = false}
}

local function startFly()
    if Fly.Connection then Fly.Connection:Disconnect() end
    Fly.Connection = RS.RenderStepped:Connect(function(dt)
        if not Fly.Enabled then return end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not hrp.Parent then return end

        local camera = workspace.CurrentCamera
        local moveVector = Vector3.new()
        if Fly.Keys.W then moveVector = moveVector + camera.CFrame.LookVector end
        if Fly.Keys.S then moveVector = moveVector - camera.CFrame.LookVector end
        if Fly.Keys.A then moveVector = moveVector - camera.CFrame.RightVector end
        if Fly.Keys.D then moveVector = moveVector + camera.CFrame.RightVector end
        if Fly.Up then moveVector = moveVector + Vector3.new(0, 1, 0) end
        if Fly.Down then moveVector = moveVector - Vector3.new(0, 1, 0) end

        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit
        end

        hrp.Anchored = true
        hrp.CFrame = hrp.CFrame + (moveVector * Fly.Speed * dt)
    end)
end

local function stopFly()
    if Fly.Connection then
        Fly.Connection:Disconnect()
        Fly.Connection = nil
    end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.Anchored = false end
end

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.W then Fly.Keys.W = true
    elseif input.KeyCode == Enum.KeyCode.S then Fly.Keys.S = true
    elseif input.KeyCode == Enum.KeyCode.A then Fly.Keys.A = true
    elseif input.KeyCode == Enum.KeyCode.D then Fly.Keys.D = true
    elseif input.KeyCode == Enum.KeyCode.Space then Fly.Up = true
    elseif input.KeyCode == Enum.KeyCode.LeftControl then Fly.Down = true
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then Fly.Keys.W = false
    elseif input.KeyCode == Enum.KeyCode.S then Fly.Keys.S = false
    elseif input.KeyCode == Enum.KeyCode.A then Fly.Keys.A = false
    elseif input.KeyCode == Enum.KeyCode.D then Fly.Keys.D = false
    elseif input.KeyCode == Enum.KeyCode.Space then Fly.Up = false
    elseif input.KeyCode == Enum.KeyCode.LeftControl then Fly.Down = false
    end
end)

LP.CharacterAdded:Connect(function()
    if Fly.Enabled then
        stopFly()
        task.wait(0.5)
        if Fly.Enabled then startFly() end
    end
end)

LocalPlayerModsBox:AddToggle('FlyToggle', {
    Text = 'Fly',
    Default = false,
    Callback = function(state)
        Fly.Enabled = state
        if state then startFly() else stopFly() end
    end
}):AddKeyPicker('FlyKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Fly',
    NoUI = false,
    Callback = function(v)
        Toggles.FlyToggle:SetValue(v)
    end
})

local FlyDepbox = LocalPlayerModsBox:AddDependencyBox()
FlyDepbox:AddSlider('FlySpeed', {
    Text = 'Fly Speed',
    Default = 50,
    Min = 10,
    Max = 300,
    Rounding = 0,
    Callback = function(Value) Fly.Speed = Value end
})
FlyDepbox:SetupDependencies({{ Toggles.FlyToggle, true }})

-- ===================== PLAYER MODE COPIER (Transformation Copy) =====================
local TransformCopyGroupBox = Tabs.Visual:AddLeftGroupbox('Transformation Copy')

-- Standard rig parts/classes to skip — anything else on a character is a transformation
local TC_RIG = {
    HumanoidRootPart=true, Torso=true, Head=true,
    ["Left Arm"]=true, ["Right Arm"]=true, ["Left Leg"]=true, ["Right Leg"]=true,
    UpperTorso=true, LowerTorso=true,
    LeftUpperArm=true, LeftLowerArm=true, LeftHand=true,
    RightUpperArm=true, RightLowerArm=true, RightHand=true,
    LeftUpperLeg=true, LeftLowerLeg=true, LeftFoot=true,
    RightUpperLeg=true, RightLowerLeg=true, RightFoot=true,
    Humanoid=true, Animate=true,
}
local TC_RIG_CLASS = {
    Humanoid=true, LocalScript=true, Script=true, ModuleScript=true,
    Shirt=true, Pants=true, BodyColors=true, ShirtGraphic=true,
    Accessory=true, Tool=true, -- exclude tools/accessories
}

-- Which body part each transformation model attaches to (confirmed from live inspection)
-- All welds are identity C0/C1 - exactly how the server does it
local TC_ATTACH_MAP = {
    Chest   = "Torso",
    HeadPart= "Head",
    Arm1    = "Left Arm",
    Arm2    = "Right Arm",
    Leg1    = "Left Leg",
    Leg2    = "Right Leg",
    Skin    = "Torso",
}

local TC_appliedParts = {}
local TC_appliedWelds = {}

local function TC_isTransform(child)
    if TC_RIG[child.Name] or TC_RIG_CLASS[child.ClassName] then return false end
    return child:IsA("Model") or child:IsA("BasePart") or child:IsA("MeshPart")
end

local function TC_getTransformationPlayers()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local char = p.Character
        if not char then continue end
        for _, child in ipairs(char:GetChildren()) do
            if TC_isTransform(child) then
                table.insert(names, p.Name)
                break
            end
        end
    end
    table.sort(names)
    if #names == 0 then table.insert(names, "No players found") end
    return names
end

local function TC_removeApplied()
    for _, w in ipairs(TC_appliedWelds) do
        pcall(function() if w and w.Parent then w:Destroy() end end)
    end
    TC_appliedWelds = {}
    for _, part in ipairs(TC_appliedParts) do
        pcall(function() if part and part.Parent then part:Destroy() end end)
    end
    TC_appliedParts = {}
    local myChar = LP.Character
    if myChar then
        for _, child in ipairs(myChar:GetChildren()) do
            if child:GetAttribute("GOATHUB_TC") then
                pcall(function() child:Destroy() end)
            end
        end
    end
end

local function TC_copyFromPlayer(playerName)
    if not playerName or playerName == "No players found" then
        Library:Notify("Select a valid player first", 3); return
    end
    local target = Players:FindFirstChild(playerName)
    if not target then Library:Notify("Player not found", 3); return end
    local srcChar = target.Character
    if not srcChar then Library:Notify(playerName .. " has no character", 3); return end
    local myChar = LP.Character
    if not myChar then Library:Notify("Your character not loaded", 3); return end

    TC_removeApplied()

    local copied = 0
    for _, child in ipairs(srcChar:GetChildren()) do
        if not TC_isTransform(child) then continue end

        local ok, clone = pcall(function() return child:Clone() end)
        if not ok or not clone then continue end

        clone:SetAttribute("GOATHUB_TC", true)

        -- Strip scripts but keep AnimationController/Animator/Animation intact
        for _, desc in ipairs(clone:GetDescendants()) do
            if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("ModuleScript") then
                pcall(function() desc:Destroy() end)
            elseif desc:IsA("BasePart") then
                desc.Anchored = false
                desc.CanCollide = false
                desc.CanTouch = false
                desc.Massless = true
            end
        end
        if clone:IsA("BasePart") then
            clone.Anchored = false; clone.CanCollide = false
            clone.CanTouch = false; clone.Massless = true
        end

        clone.Parent = myChar
        table.insert(TC_appliedParts, clone)

        -- Play animation if the model has an AnimationController
        task.defer(function()
            local animCtrl = clone:FindFirstChildOfClass("AnimationController")
            local animInst = clone:FindFirstChildOfClass("Animation")
            if animCtrl and animInst then
                pcall(function()
                    local animator = animCtrl:FindFirstChildOfClass("Animator")
                    if animator then
                        local track = animator:LoadAnimation(animInst)
                        track.Looped = true
                        track:Play()
                    end
                end)
            end
        end)

        -- Determine attach point: use map first, fall back to Torso
        local attachName = TC_ATTACH_MAP[child.Name] or "Torso"
        local attachPart = myChar:FindFirstChild(attachName)
            or myChar:FindFirstChild("Torso")
            or myChar:FindFirstChild("UpperTorso")
        if not attachPart then continue end

        -- Find the Middle anchor
        local anchor
        if clone:IsA("Model") then
            anchor = clone:FindFirstChild("Middle")
                or clone.PrimaryPart
                or clone:FindFirstChildWhichIsA("BasePart", true)
        elseif clone:IsA("BasePart") then
            anchor = clone
        end

        if anchor and anchor:IsA("BasePart") then
            -- Remove external welds that came from the source player
            for _, w in ipairs(anchor:GetChildren()) do
                if w:IsA("Weld") or w:IsA("WeldConstraint") then
                    local p0 = w.Part0
                    local p1 = w.Part1
                    if (p0 and not p0:IsDescendantOf(clone)) or
                       (p1 and not p1:IsDescendantOf(clone)) then
                        pcall(function() w:Destroy() end)
                    end
                end
            end

            -- Attach with identity C0/C1 — exactly how the server does it
            local weld = Instance.new("Weld")
            weld.Name = "TC_Weld"
            weld.Part0 = attachPart
            weld.Part1 = anchor
            weld.C0 = CFrame.new()
            weld.C1 = CFrame.new()
            weld.Parent = attachPart
            table.insert(TC_appliedWelds, weld)
        end

        copied += 1
    end

    if copied == 0 then
        Library:Notify("No transformation parts found on " .. playerName, 4)
    else
        Library:Notify("Copied " .. copied .. " parts from " .. playerName, 4)
    end
end

local TC_selectedPlayer = nil
local TC_playerValues = TC_getTransformationPlayers()

TransformCopyGroupBox:AddDropdown('TCPlayerDropdown', {
    Values = TC_playerValues,
    Default = 1,
    Text = 'Players With Transformation',
    Callback = function(v)
        TC_selectedPlayer = (v and v ~= "No players found") and v or nil
    end
})

TransformCopyGroupBox:AddButton({
    Text = 'Refresh Players',
    Func = function()
        TC_playerValues = TC_getTransformationPlayers()
        pcall(function()
            if Options.TCPlayerDropdown then
                Options.TCPlayerDropdown:SetValues(TC_playerValues)
                Options.TCPlayerDropdown:SetValue(TC_playerValues[1])
            end
        end)
        local count = 0
        for _, v in ipairs(TC_playerValues) do
            if v ~= "No players found" then count += 1 end
        end
        Library:Notify("Found " .. count .. " player(s) with transformations", 3)
    end,
})

TransformCopyGroupBox:AddButton({
    Text = 'Copy Transformation',
    Func = function()
        if not TC_selectedPlayer then
            Library:Notify("No player selected", 3); return
        end
        TC_copyFromPlayer(TC_selectedPlayer)
    end,
})

TransformCopyGroupBox:AddButton({
    Text = 'Remove Copied',
    Func = function()
        TC_removeApplied()
        Library:Notify("Removed copied transformation", 3)
    end,
})

-- ===================== PROJECTILE DEFENSE =====================
local ProjDefBox = Tabs.Main:AddLeftGroupbox('Projectile Defense')

local ProjDef = {
    Enabled = false,
    Radius = 15,
    Mode = "Auto Dodge (Side)",
    FriendlyProjectiles = {}
}

task.spawn(function()
    while true do
        task.wait(5)
        for obj, creationTime in pairs(ProjDef.FriendlyProjectiles) do
            if not obj.Parent or tick() - creationTime > 10 then
                ProjDef.FriendlyProjectiles[obj] = nil
            end
        end
    end
end)

local function trackFriendlyProj(child)
    task.defer(function()
        local char = LP.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
        if part then
            if (part.Position - root.Position).Magnitude < 15 then
                ProjDef.FriendlyProjectiles[child] = tick()
            end
        end
    end)
end

local debrisF2 = workspace:FindFirstChild("DebrisFolder")
if debrisF2 then debrisF2.ChildAdded:Connect(trackFriendlyProj) end
workspace.ChildAdded:Connect(function(child)
    if child.Name == "DebrisFolder" then child.ChildAdded:Connect(trackFriendlyProj) end
end)

-- Scans every single Heartbeat frame (no frame-skip throttle) and dodges with
-- only a 1-frame-ish cooldown, so detection and reaction are effectively
-- instant instead of the old 3-frame scan + 0.5s dodge cooldown.
RS.Heartbeat:Connect(function()
    if not ProjDef.Enabled then return end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local myPos = root.Position
    local folder = workspace:FindFirstChild("DebrisFolder")
    if not folder then return end

    for _, child in ipairs(folder:GetChildren()) do
        if not ProjDef.FriendlyProjectiles[child] then
            local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (part.Position - myPos).Magnitude
                if dist <= ProjDef.Radius then
                    if tick() - (ProjDef.LastDodge or 0) > 0.05 then
                        if ProjDef.Mode == 'Auto Dodge (Up)' then
                            root.CFrame = root.CFrame * CFrame.new(0, 30, 0)
                        else
                            local dir = (math.random() > 0.5) and 30 or -30
                            root.CFrame = root.CFrame * CFrame.new(dir, 0, 0)
                        end
                        ProjDef.LastDodge = tick()
                    end
                end
            end
        end
    end
end)

ProjDefBox:AddToggle('ProjDefEnabled', {
    Text = 'Anti-Projectile Shield',
    Default = false,
    Tooltip = 'Instantly dodges away from hostile projectiles the moment they enter the defense radius.',
    Callback = function(v) ProjDef.Enabled = v end
}):AddKeyPicker('ProjDefKeybind', {
    Default = '',
    SyncToggleState = true,
    Mode = 'Toggle',
    Text = 'Projectile Defense',
    NoUI = false,
    Callback = function(v)
        Toggles.ProjDefEnabled:SetValue(v)
    end
})

ProjDefBox:AddSlider('ProjDefRadius', {
    Text = 'Defense Radius',
    Default = 15,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Callback = function(v) ProjDef.Radius = v end
})

ProjDefBox:AddDropdown('ProjDefMode', {
    Values = { 'Auto Dodge (Side)', 'Auto Dodge (Up)' },
    Default = 1,
    Multi = false,
    Text = 'Defense Mode',
    Callback = function(v) ProjDef.Mode = v end
})

-- ===================== AUTO COMBO =====================
-- (Wrapped in do-end to avoid Luau's 200 file-scope local limit)
do
local AutoComboBox = Tabs.Misc:AddLeftGroupbox('Auto Combo')

local AutoCombo = {
    Enabled = false,
    Tools = {},      -- 10 tool slots
    Delay = 0.5,     -- Delay between tool uses
    OnlyNearPlayers = false,
    Range = 50,      -- Range to check for players
    UseAllAtOnce = false, -- Use all tools simultaneously instead of in sequence
    Thread = nil,
    MobileButton = nil,
    ToolList = {}    -- Available tools from inventory
}

local function AC_getToolList()
    local tools = { "None" } -- First option is None
    local backpack = LP:FindFirstChild("Backpack")
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") then
                table.insert(tools, t.Name)
            end
        end
    end
    local char = LP.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                if not table.find(tools, t.Name) then
                    table.insert(tools, t.Name)
                end
            end
        end
    end
    table.sort(tools)
    return tools
end

local function AC_equipTool(toolName)
    if not toolName or toolName == "None" then return nil end
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end

    -- Check if already equipped
    local equipped = char:FindFirstChild(toolName)
    if equipped and equipped:IsA("Tool") then return equipped end

    -- Find in backpack and equip
    local backpack = LP:FindFirstChild("Backpack")
    local tool = backpack and backpack:FindFirstChild(toolName)
    if tool and tool:IsA("Tool") then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.15)
        return char:FindFirstChild(toolName)
    end
    return nil
end

local function AC_activateTool(tool)
    if not tool then return false end

    -- Method 1: Fire tool's Activated event (most tools use this)
    pcall(function() tool:Activate() end)

    -- Method 2: Fire any RemoteEvent named Attack/Fire/Activate
    for _, remote in ipairs(tool:GetDescendants()) do
        if remote:IsA("RemoteEvent") then
            local name = remote.Name:lower()
            if name:find("attack") or name:find("fire") or name:find("activate") then
                pcall(function() remote:FireServer() end)
            end
        end
    end

    return true
end

local function AC_createMobileButton()
    if AutoCombo.MobileButton then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "GOATHUB_ComboButton"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not sg.Parent then sg.Parent = LP:FindFirstChildOfClass("PlayerGui") end

    local btn = Instance.new("TextButton")
    btn.Name = "ComboToggle"
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.Position = UDim2.new(0.85, 0, 0.7, 0)
    btn.Size = UDim2.new(0, 70, 0, 70)
    btn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    btn.BorderSizePixel = 0
    btn.Text = "STOP\nCOMBO"
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.Parent = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 2
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        if Toggles.AutoComboEnabled then
            Toggles.AutoComboEnabled:SetValue(false)
        end
    end)

    -- Make draggable
    local dragging = false
    local dragInput, dragStart, startPos

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
        end
    end)

    btn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    AutoCombo.MobileButton = sg
end

local function AC_removeMobileButton()
    if AutoCombo.MobileButton then
        pcall(function() AutoCombo.MobileButton:Destroy() end)
        AutoCombo.MobileButton = nil
    end
end

local function AC_isPlayerNearby()
    if not AutoCombo.OnlyNearPlayers then return true end

    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return false end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local theirHRP = plr.Character:FindFirstChild("HumanoidRootPart")
            if theirHRP then
                local dist = (myHRP.Position - theirHRP.Position).Magnitude
                if dist <= AutoCombo.Range then
                    return true
                end
            end
        end
    end
    return false
end

local function AC_runCombo()
    while AutoCombo.Enabled do
        local hasTools = false
        for i = 1, 10 do
            if AutoCombo.Tools[i] and AutoCombo.Tools[i] ~= "None" then
                hasTools = true
                break
            end
        end

        if not hasTools then
            task.wait(1)
            continue
        end

        -- Check if player is nearby (if that option is enabled)
        if not AC_isPlayerNearby() then
            task.wait(0.5)
            continue
        end

        if AutoCombo.UseAllAtOnce then
            -- Use all tools simultaneously - equip and fire all at once
            local char = LP.Character
            local backpack = LP:FindFirstChild("Backpack")
            if char and backpack then
                -- Collect all selected tools
                local toolsToFire = {}
                for i = 1, 10 do
                    local toolName = AutoCombo.Tools[i]
                    if toolName and toolName ~= "None" then
                        local tool = char:FindFirstChild(toolName) or backpack:FindFirstChild(toolName)
                        if tool and tool:IsA("Tool") then
                            table.insert(toolsToFire, tool)
                        end
                    end
                end

                -- Fire all tools at once (no waiting between)
                for _, tool in ipairs(toolsToFire) do
                    task.spawn(function()
                        AC_activateTool(tool)
                    end)
                end
            end
            task.wait(AutoCombo.Delay) -- Wait before next cycle
        else
            -- Use tools in sequence (original behavior)
            for i = 1, 10 do
                if not AutoCombo.Enabled then break end

                local toolName = AutoCombo.Tools[i]
                if toolName and toolName ~= "None" then
                    local tool = AC_equipTool(toolName)
                    if tool then
                        task.wait(0.1) -- Small delay after equip
                        AC_activateTool(tool)
                    end
                    task.wait(AutoCombo.Delay)
                end
            end
        end
    end
end

AutoCombo.ToolList = AC_getToolList()

AutoComboBox:AddToggle('AutoComboEnabled', {
    Text = 'Enable Auto Combo',
    Default = false,
    Tooltip = 'Continuously cycles through your combo. Mobile players get an on-screen stop button.',
    Callback = function(state)
        AutoCombo.Enabled = state
        if state then
            -- Check if any tools are selected
            local hasTools = false
            for i = 1, 10 do
                if AutoCombo.Tools[i] and AutoCombo.Tools[i] ~= "None" then
                    hasTools = true
                    break
                end
            end
            if not hasTools then
                Library:Notify("Select at least one tool first!", 4)
                Toggles.AutoComboEnabled:SetValue(false)
                return
            end

            -- Create mobile button if on mobile/touch device
            local UIS = game:GetService("UserInputService")
            if UIS.TouchEnabled then
                AC_createMobileButton()
            end

            Library:Notify("Auto Combo started", 3)
            if AutoCombo.Thread then task.cancel(AutoCombo.Thread) end
            AutoCombo.Thread = task.spawn(function()
                pcall(AC_runCombo)
                AutoCombo.Thread = nil
            end)
        else
            AC_removeMobileButton()
            if AutoCombo.Thread then
                task.cancel(AutoCombo.Thread)
                AutoCombo.Thread = nil
            end
        end
    end
}):AddKeyPicker('AutoComboKeybind', {
    Default = 'None',
    Text = 'Auto Combo',
    Mode = 'Toggle',
    NoUI = false
})

-- Everything below only matters once Auto Combo is actually on, so it's tucked
-- behind a dependency box driven by the Enable toggle above.
local ComboDepbox = AutoComboBox:AddDependencyBox()

ComboDepbox:AddButton({
    Text = 'Refresh Tool List',
    Func = function()
        AutoCombo.ToolList = AC_getToolList()
        for i = 1, 10 do
            local opt = Options['ComboTool' .. i]
            if opt then opt:SetValues(AutoCombo.ToolList) end
        end
        Library:Notify("Found " .. (#AutoCombo.ToolList - 1) .. " tools", 3)
    end
})

ComboDepbox:AddLabel('Select Tools (in order):')

-- Create 10 dropdowns for tool selection
for i = 1, 10 do
    ComboDepbox:AddDropdown('ComboTool' .. i, {
        Values = AutoCombo.ToolList,
        Default = 1,
        Text = 'Tool Slot ' .. i,
        Tooltip = 'Select tool for position ' .. i .. ' in combo',
        Callback = function(v)
            AutoCombo.Tools[i] = v
        end
    })
end

ComboDepbox:AddLabel('Configuration:')

ComboDepbox:AddSlider('ComboDelay', {
    Text = 'Delay Between Tools',
    Default = 0.5,
    Min = 0,
    Max = 5,
    Rounding = 1,
    Compact = false,
    Callback = function(v) AutoCombo.Delay = v end
})

ComboDepbox:AddToggle('ComboUseAllAtOnce', {
    Text = 'Use All Tools At Once',
    Default = false,
    Tooltip = 'Activate all selected tools simultaneously instead of in sequence',
    Callback = function(state) AutoCombo.UseAllAtOnce = state end
})

ComboDepbox:AddToggle('ComboOnlyNearPlayers', {
    Text = 'Only When Player Nearby',
    Default = false,
    Tooltip = 'Only run combo when an enemy player is within range',
    Callback = function(state) AutoCombo.OnlyNearPlayers = state end
})

local ComboRangeDepbox = ComboDepbox:AddDependencyBox()
ComboRangeDepbox:AddSlider('ComboRange', {
    Text = 'Detection Range',
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Compact = false,
    Callback = function(v) AutoCombo.Range = v end
})
ComboRangeDepbox:SetupDependencies({ { Toggles.ComboOnlyNearPlayers, true } })

ComboDepbox:SetupDependencies({ { Toggles.AutoComboEnabled, true } })
end -- Auto Combo scope

-- ===================== NPC KILLAURA =====================
local KillAura = {
    Enabled = false,
    Range = 15,
    DamagePerHit = 25,
    AttackCooldown = 0.8,
    LastAttack = 0,
    Thread = nil,
    UseServerHits = true,
    WhitelistedNPCs = {}
}

local KA = {
    ShowCircle = true,
    Range = 17
}

local KA_RingFolder = Instance.new("Folder")
KA_RingFolder.Name = "KillAuraRing"
KA_RingFolder.Parent = workspace

local KA_SegmentCount = 60
local KA_DefaultColor = Color3.fromRGB(255, 50, 50)
local KA_ThicknessY = 0.2
local KA_HeightOffset = -3

local function KA_GetSegmentLength(radius)
    return (2 * radius * math.pi / KA_SegmentCount) * 1.05
end

local KA_Segments = {}
for i = 1, KA_SegmentCount do
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = KA_DefaultColor
    part.Size = Vector3.new(0.1, KA_ThicknessY, KA_GetSegmentLength(KillAura.Range))
    part.Transparency = 1
    part.Name = "RingSegment"
    part.Parent = KA_RingFolder
    table.insert(KA_Segments, part)
end

local function KA_ToggleRingVisibility(visible)
    for _, segment in ipairs(KA_Segments) do
        segment.Transparency = visible and 0 or 1
    end
end

local function KA_UpdateRing(pos, radius)
    if not KA_RingFolder or not KA_RingFolder.Parent then return end
    if not KA.ShowCircle then return end
    for i, segment in ipairs(KA_Segments) do
        local angle = (i / KA_SegmentCount) * 2 * math.pi
        local x = math.cos(angle) * radius
        local z = math.sin(angle) * radius
        local segmentPos = pos + Vector3.new(x, KA_HeightOffset, z)
        local lookDir = Vector3.new(-math.sin(angle), 0, math.cos(angle))
        segment.CFrame = CFrame.lookAt(segmentPos, segmentPos + lookDir)
        segment.Size = Vector3.new(0.1, KA_ThicknessY, KA_GetSegmentLength(radius))
    end
end

local function isNPC(model)
    if Players:GetPlayerFromCharacter(model) then return false end
    -- Real enemies are tagged by the game with an EnemyNPC BoolValue
    if model:FindFirstChild("EnemyNPC") then return true end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    -- Skip decorative statues / friendly NPCs (their humanoid is named StatueHum)
    if hum.Name == "StatueHum" then return false end
    if model.Name:find("TravelNinja") or model.Name:find("STATUE") then return false end
    return true
end

-- Combat tool support: firing the tool's Attack remote makes the SERVER do
-- the hit detection, so kills are real (client TakeDamage is visual-only).
-- (Stored on the KA table to avoid adding file-scope locals — Luau caps
-- active locals at 200 per scope and this file is right at the limit.)
function KA.getCombatTool()
    local char = LP.Character
    if not char then return nil end
    local tool = char:FindFirstChild("Combat")
    if tool then return tool end
    local backpack = LP:FindFirstChild("Backpack")
    tool = backpack and backpack:FindFirstChild("Combat")
    if tool then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(tool) end) end
        return char:FindFirstChild("Combat")
    end
    return nil
end

function KA.serverAttack(npc)
    local tool = KA.getCombatTool()
    local remote = tool and tool:FindFirstChild("Attack")
    if not remote then return end
    -- Face the target so the server-side swing hitbox connects
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local npcRoot = npc and npc:FindFirstChild("HumanoidRootPart")
    if hrp and npcRoot then
        local look = Vector3.new(npcRoot.Position.X, hrp.Position.Y, npcRoot.Position.Z)
        if (look - hrp.Position).Magnitude > 0.5 then
            pcall(function() hrp.CFrame = CFrame.lookAt(hrp.Position, look) end)
        end
    end
    pcall(function() remote:FireServer() end)
end

local function updateRangeVisual()
    KA.Range = KillAura.Range
    KA_ToggleRingVisibility(KA.ShowCircle and KillAura.Enabled)
end

local function executeAttack(npc)
    if tick() - KillAura.LastAttack < KillAura.AttackCooldown then return end
    local humanoid = npc:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 and isNPC(npc) then
        if KillAura.UseServerHits then
            KA.serverAttack(npc)
        end
        local damage = math.min(humanoid.MaxHealth * (KillAura.DamagePerHit/100), humanoid.Health)
        humanoid:TakeDamage(damage)

        local blood = Instance.new("Part")
        blood.Size = Vector3.new(0.3, 0.3, 0.3)
        blood.Color = Color3.fromRGB(150, 0, 0)
        blood.CFrame = npc:FindFirstChild("HumanoidRootPart").CFrame
        blood.Anchored = true
        blood.CanCollide = false
        blood.Parent = workspace
        game:GetService("Debris"):AddItem(blood, 0.6)

        KillAura.LastAttack = tick()
    end
end

local function combatLoop()
    updateRangeVisual()
    while KillAura.Enabled and LP.Character do
        local root = LP.Character:FindFirstChild("HumanoidRootPart")
        if root then
            KA_UpdateRing(root.Position, KillAura.Range)
            for _, npc in ipairs(workspace:GetChildren()) do
                if npc:IsA("Model") and isNPC(npc) then
                    local npcRoot = npc:FindFirstChild("HumanoidRootPart")
                    if npcRoot and (root.Position - npcRoot.Position).Magnitude <= KillAura.Range then
                        executeAttack(npc)
                    end
                end
            end
        end
        task.wait(0.2)
    end
end

NpcKillAuraGroupBox:AddToggle('NpcKillAuraEnabled', {
    Text = 'Enable NPC Aura',
    Default = false,
    Callback = function(state)
        KillAura.Enabled = state
        if state then
            KillAura.Thread = task.spawn(combatLoop)
        else
            if KillAura.Thread then task.cancel(KillAura.Thread) end
        end
    end
})

local KillAuraDepbox = NpcKillAuraGroupBox:AddDependencyBox()

KillAuraDepbox:AddSlider('NpcKillAuraRange', {
    Text = 'Attack Range',
    Default = 15,
    Min = 5,
    Max = 90,
    Rounding = 0,
    Callback = function(v)
        KillAura.Range = v
        updateRangeVisual()
    end
})

KillAuraDepbox:AddSlider('NpcKillAuraDamage', {
    Text = 'Damage %',
    Default = 25,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(v) KillAura.DamagePerHit = v end
})

KillAuraDepbox:AddSlider('NpcKillAuraCooldown', {
    Text = 'Attack Speed',
    Default = 0.8,
    Min = 0.3,
    Max = 3,
    Rounding = 1,
    Callback = function(v) KillAura.AttackCooldown = v end
})

KillAuraDepbox:AddToggle('NpcKillAuraServerHits', {
    Text = 'Real Damage (Combat Tool)',
    Default = true,
    Tooltip = 'Auto-equips your Combat tool and fires its Attack remote so the server registers real hits. Without this, damage is client-side (visual only).',
    Callback = function(state) KillAura.UseServerHits = state end
})

KillAuraDepbox:AddToggle('NpcKillAuraShowCircle', {
    Text = 'Show Range Circle',
    Default = true,
    Callback = function(state)
        KA.ShowCircle = state
        updateRangeVisual()
    end
}):AddColorPicker('KillAuraRingColor', {
    Default = Color3.fromRGB(255, 50, 50),
    Title = 'Aura Ring Color',
    Callback = function(color)
        KA_DefaultColor = color
        for _, seg in ipairs(KA_Segments) do
            seg.Color = color
        end
    end
})

KillAuraDepbox:SetupDependencies({
    { Toggles.NpcKillAuraEnabled, true }
})
-- ===================== MAGNETS =====================
-- NPC Magnet
local NPCMagnet = {
    Enabled = false,
    Target = nil,
    Distance = 5,
    Thread = nil
}

local function getNPCNames()
    local npcNames = {}
    for _, npc in ipairs(workspace:GetDescendants()) do
        if npc:FindFirstChild("Humanoid") and npc:FindFirstChild("HumanoidRootPart") then
            if not Players:GetPlayerFromCharacter(npc) then
                table.insert(npcNames, npc.Name)
            end
        end
    end
    return npcNames
end

local function startNPCMagnet()
    if NPCMagnet.Thread then task.cancel(NPCMagnet.Thread) end
    NPCMagnet.Thread = task.spawn(function()
        while NPCMagnet.Enabled and NPCMagnet.Target do
            local npc = workspace:FindFirstChild(NPCMagnet.Target)
            local localChar = LP.Character
            if npc and localChar then
                local npcRoot = npc:FindFirstChild("HumanoidRootPart")
                local localRoot = localChar:FindFirstChild("HumanoidRootPart")
                if npcRoot and localRoot then
                    local newCFrame = localRoot.CFrame * CFrame.new(0, 0, -NPCMagnet.Distance)
                    npcRoot.CFrame = newCFrame
                    npcRoot.Velocity = Vector3.zero
                    local humanoid = npc:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
                    end
                end
            end
            task.wait()
        end
    end)
end



-- ===================== TYCOON TAB =====================
local TycoonLeftBox = Tabs.Tycoon:AddLeftGroupbox('Tycoon Mods')
local TycoonRightBox = Tabs.Tycoon:AddRightGroupbox('Auto Features')
local TycoonCollectBox = Tabs.Tycoon:AddLeftGroupbox('Collection')
local TycoonMagnetBox = Tabs.Tycoon:AddLeftGroupbox('Magnet')
local TycoonFarmBox = Tabs.Tycoon:AddRightGroupbox('Auto Farm')

-- Remove Force Fields
-- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
do
local function removeForceFields(silent)
    local tycoonKit = workspace:FindFirstChild("Zednov's Tycoon Kit")
    if not tycoonKit then return end
    local tycoons = tycoonKit:FindFirstChild("Tycoons")
    if not tycoons then return end

    local removed = 0
    for _, tycoon in pairs(tycoons:GetChildren()) do
        local purchased = tycoon:FindFirstChild("PurchasedObjects")
        if purchased then
            for _, item in pairs(purchased:GetChildren()) do
                local owner = tycoon:FindFirstChild("Owner")
                if item.Name:lower() == "roof barrier jutsu" and owner then
                    local ownerValue = owner:IsA("ObjectValue") and owner.Value or owner:IsA("StringValue") and owner.Value
                    if ownerValue ~= LP and ownerValue ~= LP.Name and ownerValue ~= LP.Character.Name then
                        item:Destroy()
                        removed += 1
                    end
                end
            end
        end
    end
    if removed > 0 and not silent then
        Library:Notify("Force fields removed", 3)
    end
end

local autoRemoveForceFieldsEnabled = false
local autoRemoveForceFieldsThread = nil

TycoonLeftBox:AddToggle('AutoRemoveForceFields', {
    Text = 'Remove Force Fields',
    Default = false,
    Tooltip = 'Continuously destroys enemy roof barrier jutsu as they spawn.',
    Callback = function(state)
        autoRemoveForceFieldsEnabled = state
        if state then
            if autoRemoveForceFieldsThread then task.cancel(autoRemoveForceFieldsThread) end
            autoRemoveForceFieldsThread = task.spawn(function()
                while autoRemoveForceFieldsEnabled do
                    pcall(removeForceFields, true)
                    task.wait(2)
                end
                autoRemoveForceFieldsThread = nil
            end)
        elseif autoRemoveForceFieldsThread then
            task.cancel(autoRemoveForceFieldsThread)
            autoRemoveForceFieldsThread = nil
        end
    end
})
end -- Remove Force Fields scope

-- Remove Walls
-- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
do
local function removeWalls(silent)
    local tycoonKit = workspace:FindFirstChild("Zednov's Tycoon Kit")
    if not tycoonKit then return end
    local tycoons = tycoonKit:FindFirstChild("Tycoons")
    if not tycoons then return end

    local removed = 0
    for _, tycoon in pairs(tycoons:GetChildren()) do
        local purchased = tycoon:FindFirstChild("PurchasedObjects")
        if purchased then
            for _, item in pairs(purchased:GetChildren()) do
                local owner = tycoon:FindFirstChild("Owner")
                if item.Name:lower():match("wall") and owner then
                    local ownerValue = owner:IsA("ObjectValue") and owner.Value or owner:IsA("StringValue") and owner.Value
                    if ownerValue ~= LP and ownerValue ~= LP.Name and ownerValue ~= LP.Character.Name then
                        item:Destroy()
                        removed += 1
                    end
                end
            end
        end
    end
    if removed > 0 and not silent then
        Library:Notify("Walls removed", 3)
    end
end

local autoRemoveWallsEnabled = false
local autoRemoveWallsThread = nil

TycoonLeftBox:AddToggle('AutoRemoveWalls', {
    Text = 'Remove Walls',
    Default = false,
    Tooltip = 'Continuously destroys enemy walls as they spawn.',
    Callback = function(state)
        autoRemoveWallsEnabled = state
        if state then
            if autoRemoveWallsThread then task.cancel(autoRemoveWallsThread) end
            autoRemoveWallsThread = task.spawn(function()
                while autoRemoveWallsEnabled do
                    pcall(removeWalls, true)
                    task.wait(2)
                end
                autoRemoveWallsThread = nil
            end)
        elseif autoRemoveWallsThread then
            task.cancel(autoRemoveWallsThread)
            autoRemoveWallsThread = nil
        end
    end
})
end -- Remove Walls scope

-- Auto Build
local autoBuildEnabled = false
local autoBuildThread = nil

local function getMyTycoon()
    local tycoonKit = workspace:FindFirstChild("Zednov's Tycoon Kit")
    local tycoons = tycoonKit and tycoonKit:FindFirstChild("Tycoons")
    if not tycoons then return nil end

    local char = LP.Character
    local charName = char and char.Name

    for _, tycoon in ipairs(tycoons:GetChildren()) do
        local owner = tycoon:FindFirstChild("Owner")
        if owner then
            if owner:IsA("ObjectValue") and owner.Value == LP then
                return tycoon
            end
            if owner:IsA("StringValue") and (owner.Value == LP.Name or (charName and owner.Value == charName)) then
                return tycoon
            end
        end
    end
    return nil
end

local function getPrice(buttonName)
    local price = buttonName:match("%[%$(%d+)%]")
    return price and tonumber(price) or math.huge
end

local function pressButton(button, hrp)
    local head = button and button:FindFirstChild("Head")
    if not head then return end
    local touch = head:FindFirstChild("TouchInterest")
    if not touch then return end
    firetouchinterest(hrp, head, 0)
    task.wait(0.05)
    firetouchinterest(hrp, head, 1)
end

local function startAutoBuild()
    if autoBuildThread then return end
    autoBuildThread = task.spawn(function()
        local myTycoon = nil
        while autoBuildEnabled do
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                task.wait(0.25)
                continue
            end

            if not myTycoon or not myTycoon.Parent then
                repeat
                    myTycoon = getMyTycoon()
                    if not autoBuildEnabled then break end
                    task.wait(0.3)
                until myTycoon
            end

            local buttonsFolder = myTycoon and myTycoon:FindFirstChild("Buttons")
            if not buttonsFolder then
                task.wait(0.5)
                continue
            end

            local buttons = buttonsFolder:GetChildren()
            table.sort(buttons, function(a, b)
                return getPrice(a.Name) < getPrice(b.Name)
            end)

            for _, button in ipairs(buttons) do
                if not autoBuildEnabled then break end
                pressButton(button, hrp)
            end
            task.wait(0.4)
        end
        autoBuildThread = nil
    end)
end

TycoonLeftBox:AddToggle('AutoBuild', {
    Text = 'Auto Build',
    Default = false,
    Callback = function(state)
        autoBuildEnabled = state
        if state then
            startAutoBuild()
        else
            if autoBuildThread then
                task.cancel(autoBuildThread)
                autoBuildThread = nil
            end
        end
    end
})

-- Collect Signature Jutsu
-- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
do
local function collectSignatureJutsuDroppers(silent)
    local tycoonKit = workspace:FindFirstChild("Zednov's Tycoon Kit")
    local tycoons = tycoonKit and tycoonKit:FindFirstChild("Tycoons")
    if not tycoons then
        if not silent then Library:Notify("Tycoon kit not found", 3) end
        return
    end

    local collected = 0
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, tycoon in ipairs(tycoons:GetChildren()) do
        local purchased = tycoon:FindFirstChild("PurchasedObjects")
        if not purchased then continue end

        for _, obj in ipairs(purchased:GetChildren()) do
            if obj.Name:match("^Signature Jutsu") then
                local spaceFolder = obj:FindFirstChild(" ")
                local head = spaceFolder and spaceFolder:FindFirstChild("Head")
                local touch = head and head:FindFirstChild("TouchInterest")
                if touch then
                    firetouchinterest(hrp, head, 0)
                    task.wait()
                    firetouchinterest(hrp, head, 1)
                    collected += 1
                end
            end
        end
    end

    if collected > 0 and not silent then
        Library:Notify("Collected " .. collected .. " droppers", 3)
    end
end

local autoCollectSignatureJutsuEnabled = false
local autoCollectSignatureJutsuThread = nil

TycoonLeftBox:AddToggle('AutoCollectSignatureJutsu', {
    Text = 'Collect Signature Jutsu',
    Default = false,
    Tooltip = 'Continuously collects Signature Jutsu droppers as they appear.',
    Callback = function(state)
        autoCollectSignatureJutsuEnabled = state
        if state then
            if autoCollectSignatureJutsuThread then task.cancel(autoCollectSignatureJutsuThread) end
            autoCollectSignatureJutsuThread = task.spawn(function()
                while autoCollectSignatureJutsuEnabled do
                    pcall(collectSignatureJutsuDroppers, true)
                    task.wait(3)
                end
                autoCollectSignatureJutsuThread = nil
            end)
        elseif autoCollectSignatureJutsuThread then
            task.cancel(autoCollectSignatureJutsuThread)
            autoCollectSignatureJutsuThread = nil
        end
    end
})
end -- Collect Signature Jutsu scope

-- Auto Dropper
-- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
do
local isScriptEnabled = false
local currentTaskCount = 20
local dropperThreads = {}
local dropperEmitterState = {}
local dropperRainbowEnabled = false
local dropperRainbowThread = nil

-- Rainbow ColorSequence helper
local function makeRainbowSequence()
    local kps = {}
    local steps = 6
    for i = 0, steps do
        local t = i / steps
        table.insert(kps, ColorSequenceKeypoint.new(t, Color3.fromHSV(t, 1, 1)))
    end
    return ColorSequence.new(kps)
end

local dropperEmitterColor = makeRainbowSequence() -- default: rainbow

local function eachMineParticleEmitter(callback)
    local tycoonKit = workspace:FindFirstChild("Zednov's Tycoon Kit")
    local tycoons = tycoonKit and tycoonKit:FindFirstChild("Tycoons")
    if not tycoons then return false end

    for _, tycoon in pairs(tycoons:GetChildren()) do
        local purchased = tycoon:FindFirstChild("PurchasedObjects")
        local mine = purchased and purchased:FindFirstChild("Mine")
        local drop = mine and mine:FindFirstChild("Drop")
        local attachment = drop and drop:FindFirstChild("Attachment")
        local emitter = attachment and attachment:FindFirstChild("ParticleEmitter")
        if emitter and emitter:IsA("ParticleEmitter") then
            callback(emitter)
        end
    end
    return true
end

local function setAutoDropperEmitterVisuals(enabled)
    if enabled then
        eachMineParticleEmitter(function(emitter)
            if not dropperEmitterState[emitter] then
                dropperEmitterState[emitter] = {
                    VelocitySpread = emitter.VelocitySpread,
                    Color = emitter.Color
                }
            end
            emitter.VelocitySpread = 50
            emitter.Color = dropperEmitterColor
        end)
    else
        for emitter, original in pairs(dropperEmitterState) do
            if emitter and emitter.Parent and original then
                pcall(function()
                    emitter.VelocitySpread = original.VelocitySpread
                    emitter.Color = original.Color
                end)
            end
        end
        table.clear(dropperEmitterState)
    end
end

local function toggleAutoDropper(enable)
    for _, t in ipairs(dropperThreads) do
        pcall(task.cancel, t)
    end
    table.clear(dropperThreads)

    isScriptEnabled = enable
    if enable then
        local tycoonKit = workspace:FindFirstChild("Zednov's Tycoon Kit")
        local tycoons = tycoonKit and tycoonKit:FindFirstChild("Tycoons")
        if not tycoons then
            Library:Notify("Tycoon kit not found", 3)
            isScriptEnabled = false
            setAutoDropperEmitterVisuals(false)
            return
        end

        setAutoDropperEmitterVisuals(true)

        for _, tycoon in pairs(tycoons:GetChildren()) do
            local mine = tycoon:FindFirstChild("PurchasedObjects") and tycoon.PurchasedObjects:FindFirstChild("Mine")
            local button = mine and mine:FindFirstChild("Clicker")
            local prompt = button and button:FindFirstChild("ProximityPrompt")

            if prompt and button then
                local function isPlayerInRange()
                    local char = LP.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        return (button.Position - hrp.Position).Magnitude <= 10
                    end
                    return false
                end

                for i = 1, currentTaskCount do
                    local t = task.spawn(function()
                        while isScriptEnabled do
                            if prompt.Enabled and isPlayerInRange() then
                                pcall(fireproximityprompt, prompt)
                            end
                            task.wait(0)
                        end
                    end)
                    table.insert(dropperThreads, t)
                end
            end
        end
        Library:Notify("Auto Dropper enabled with " .. currentTaskCount .. " tasks", 3)
    else
        setAutoDropperEmitterVisuals(false)
    end
end

TycoonRightBox:AddToggle('AutoDropper', {
    Text = 'Auto Dropper',
    Default = false,
    Callback = function(state) toggleAutoDropper(state) end
})

TycoonRightBox:AddSlider('DropperTaskCount', {
    Text = 'Task Count',
    Default = 20,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Callback = function(value)
        currentTaskCount = value
        if isScriptEnabled then
            toggleAutoDropper(false)
            task.wait()
            toggleAutoDropper(true)
        end
    end
})

TycoonRightBox:AddToggle('DropperRainbow', {
    Text = 'Rainbow Mode',
    Default = true,
    Callback = function(state)
        dropperRainbowEnabled = state
        if state then
            if dropperRainbowThread then
                task.cancel(dropperRainbowThread)
            end
            dropperRainbowThread = task.spawn(function()
                local hue = 0
                while dropperRainbowEnabled do
                    hue = (hue + 0.005) % 1
                    local kps = {}
                    for i = 0, 6 do
                        local t = i / 6
                        kps[#kps+1] = ColorSequenceKeypoint.new(
                            t, Color3.fromHSV((hue + t) % 1, 1, 1)
                        )
                    end
                    dropperEmitterColor = ColorSequence.new(kps)
                    if isScriptEnabled then
                        eachMineParticleEmitter(function(emitter)
                            pcall(function() emitter.Color = dropperEmitterColor end)
                        end)
                    end
                    task.wait(0.05)
                end
            end)
        else
            if dropperRainbowThread then
                task.cancel(dropperRainbowThread)
                dropperRainbowThread = nil
            end
        end
    end
})
end -- Auto Dropper scope

-- Auto Collect
local autoCollectEnabled = false
local collectionThread = nil

local function collectFromAllGivers()
    while autoCollectEnabled do
        local char = LP.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local tycoonKit = workspace:FindFirstChild("Zednov's Tycoon Kit")
            local tycoons = tycoonKit and tycoonKit:FindFirstChild("Tycoons")
            if tycoons then
                for _, tycoon in pairs(tycoons:GetChildren()) do
                    if not autoCollectEnabled then break end
                    local essentials = tycoon:FindFirstChild("Essentials")
                    local giver = essentials and essentials:FindFirstChild("Giver")
                    if giver then
                        pcall(firetouchinterest, hrp, giver, 0)
                        pcall(firetouchinterest, hrp, giver, 1)
                    end
                end
            end
        end
        task.wait(0.15)
    end
end

local function setupAutoCollect()
    if collectionThread then
        pcall(task.cancel, collectionThread)
        collectionThread = nil
    end
    if autoCollectEnabled then
        collectionThread = task.spawn(collectFromAllGivers)
    end
end

TycoonCollectBox:AddToggle('AutoCollect', {
    Text = 'Auto Collect Money',
    Default = false,
    Callback = function(state)
        autoCollectEnabled = state
        setupAutoCollect()
    end
})

-- Auto Pickup
local AutoPickup = {
    Cash = false,
    Scroll = false,
    Threads = {}
}

local function getChar()
    return LP.Character or LP.CharacterAdded:Wait()
end

local function getHRP()
    return getChar():WaitForChild("HumanoidRootPart")
end

local function firePrompt(prompt)
    if fireproximityprompt then
        fireproximityprompt(prompt)
    else
        prompt:InputHoldBegin()
        task.wait(0.2)
        prompt:InputHoldEnd()
    end
end

local function isCharacter(model)
    return model and model:IsA("Model") and model:FindFirstChildWhichIsA("Humanoid")
end

local function startCashPickup()
    if AutoPickup.Threads.Cash then
        task.cancel(AutoPickup.Threads.Cash)
    end
    AutoPickup.Threads.Cash = task.spawn(function()
        while AutoPickup.Cash do
            local hrp = getHRP()
            for _, v in ipairs(workspace:GetChildren()) do
                if v.Name == "CashScroll" then
                    local prompt = v:FindFirstChild("PP", true) or v:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt and prompt.Enabled then
                        pcall(function()
                            hrp.CFrame = v.CFrame + Vector3.new(0, 3, 0)
                        end)
                        firePrompt(prompt)
                        task.wait(0.25)
                    end
                end
            end
            task.wait(0.6)
        end
    end)
end

local function startScrollPickup()
    if AutoPickup.Threads.Scroll then
        task.cancel(AutoPickup.Threads.Scroll)
    end
    AutoPickup.Threads.Scroll = task.spawn(function()
        while AutoPickup.Scroll do
            local hrp = getHRP()
            if hrp then
                for _, obj in ipairs(workspace:GetChildren()) do
                    -- Ryo scrolls: EScroll, SScroll, AScroll, BScroll, etc. (NOT CashScroll)
                    -- Pattern: single letter + "Scroll" (E/S/A/B/etc. + Scroll)
                    if obj.Name:find("Scroll") and obj.Name ~= "CashScroll" and not isCharacter(obj) then
                        local pp = obj:FindFirstChild("PP")
                        if pp and pp:IsA("ProximityPrompt") and pp.Enabled then
                            -- Teleport directly to the scroll part (all Ryo scrolls are BaseParts)
                            if obj:IsA("BasePart") then
                                pcall(function()
                                    hrp.CFrame = obj.CFrame + Vector3.new(0, 2, 0)
                                end)
                                task.wait(0.15)
                                firePrompt(pp)
                                task.wait(0.2)
                            end
                        end
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

TycoonCollectBox:AddToggle('AutoPickupCash', {
    Text = 'Auto Pick Up Cash',
    Default = false,
    Callback = function(v)
        AutoPickup.Cash = v
        if v then
            startCashPickup()
        else
            if AutoPickup.Threads.Cash then
                pcall(task.cancel, AutoPickup.Threads.Cash)
                AutoPickup.Threads.Cash = nil
            end
        end
    end
})

TycoonCollectBox:AddToggle('AutoPickupScrolls', {
    Text = 'Auto Pick Up Ryo',
    Default = false,
    Tooltip = 'Automatically collects Ryo scrolls (EScroll, AScroll, etc.) by teleporting to them and firing their PP proximity prompt.',
    Callback = function(v)
        AutoPickup.Scroll = v
        if v then
            startScrollPickup()
        else
            if AutoPickup.Threads.Scroll then
                pcall(task.cancel, AutoPickup.Threads.Scroll)
                AutoPickup.Threads.Scroll = nil
            end
        end
    end
})

-- ===================== UNIFIED MAGNET (Tycoon Left) =====================
local MagnetTargetType = "NPC"
local MagnetTargetName = nil
local MagnetDistance = 5
local UnifiedMagnet = { Enabled = false, Thread = nil }

local function getMagnetTargetList(targetType)
    if targetType == "NPC" then
        local names = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:FindFirstChildOfClass("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                if not Players:GetPlayerFromCharacter(obj) then
                    table.insert(names, obj.Name)
                end
            end
        end
        if #names == 0 then table.insert(names, "No NPCs found") end
        return names
    else
        local names = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LP then
                table.insert(names, player.Name)
            end
        end
        if #names == 0 then table.insert(names, "No players found") end
        return names
    end
end

local function startUnifiedMagnet()
    if UnifiedMagnet.Thread then task.cancel(UnifiedMagnet.Thread) end
    UnifiedMagnet.Thread = task.spawn(function()
        while UnifiedMagnet.Enabled and MagnetTargetName do
            local localChar = LP.Character
            local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
            if localRoot then
                if MagnetTargetType == "NPC" then
                    -- Pull NPC to player
                    local npc = workspace:FindFirstChild(MagnetTargetName)
                    if npc then
                        local npcRoot = npc:FindFirstChild("HumanoidRootPart")
                        if npcRoot then
                            npcRoot.CFrame = localRoot.CFrame * CFrame.new(0, 0, -MagnetDistance)
                            npcRoot.Velocity = Vector3.zero
                            local hum = npc:FindFirstChildOfClass("Humanoid")
                            if hum then hum:ChangeState(Enum.HumanoidStateType.Physics) end
                        end
                    end
                else
                    -- Pull player character to us (client-side only)
                    local targetPlayer = Players:FindFirstChild(MagnetTargetName)
                    local targetChar = targetPlayer and targetPlayer.Character
                    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                    if targetRoot then
                        pcall(function()
                            targetRoot.CFrame = localRoot.CFrame * CFrame.new(0, 0, -MagnetDistance)
                        end)
                    end
                end
            end
            task.wait()
        end
    end)
end

TycoonMagnetBox:AddDropdown('MagnetTargetType', {
    Values = {"NPC", "Player"},
    Default = 1,
    Text = 'Target Type',
    Tooltip = 'Choose whether to magnet an NPC or another player toward you.',
    Callback = function(v)
        MagnetTargetType = v
        local newList = getMagnetTargetList(v)
        pcall(function()
            if Options.MagnetTarget then
                Options.MagnetTarget:SetValues(newList)
                Options.MagnetTarget:SetValue(newList[1])
            end
        end)
        MagnetTargetName = (newList[1] ~= "No NPCs found" and newList[1] ~= "No players found") and newList[1] or nil
    end
})

TycoonMagnetBox:AddDropdown('MagnetTarget', {
    Values = getMagnetTargetList("NPC"),
    Default = 1,
    Text = 'Select Target',
    Tooltip = 'The specific NPC or player to pull toward you. Refresh the list if it is empty.',
    Callback = function(v)
        if v and v ~= "No NPCs found" and v ~= "No players found" then
            MagnetTargetName = v
        else
            MagnetTargetName = nil
        end
    end
})

TycoonMagnetBox:AddSlider('MagnetBringDistance', {
    Text = 'Bring Distance',
    Default = 5,
    Min = 0,
    Max = 30,
    Rounding = 0,
    Tooltip = 'How many studs in front of you the target will be placed when Bring is active.',
    Callback = function(v) MagnetDistance = v end
})

TycoonMagnetBox:AddButton({
    Text = 'Refresh List',
    Tooltip = 'Re-scans the workspace for NPCs or server for players and updates the target dropdown.',
    Func = function()
        local newList = getMagnetTargetList(MagnetTargetType)
        pcall(function()
            if Options.MagnetTarget then
                Options.MagnetTarget:SetValues(newList)
            end
        end)
        local count = 0
        for _, v in ipairs(newList) do
            if v ~= "No NPCs found" and v ~= "No players found" then count += 1 end
        end
        Library:Notify("Targets found: " .. count, 3)
    end
})

TycoonMagnetBox:AddToggle('EnableUnifiedMagnet', {
    Text = 'Enable Bring',
    Default = false,
    Tooltip = 'Continuously pulls the selected target to the position in front of you every frame.',
    Callback = function(state)
        UnifiedMagnet.Enabled = state
        if state then
            if not MagnetTargetName then
                Library:Notify("Select a target first", 3)
                Toggles.EnableUnifiedMagnet:SetValue(false)
                return
            end
            startUnifiedMagnet()
        else
            if UnifiedMagnet.Thread then
                task.cancel(UnifiedMagnet.Thread)
                UnifiedMagnet.Thread = nil
            end
        end
    end
})

-- Quick Shop
-- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
do
local TycoonToolbarBox = Tabs.Tycoon:AddRightGroupbox('Toolbar')
local selectedQuickTool = nil
local quickShopValues = {}
local quickToolToCaseIndex = {}

local function getQuickShopHRP()
    local character = LP.Character
    if not character then
        character = LP.CharacterAdded:Wait()
    end
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getShopCasesFolder()
    local shop = workspace:FindFirstChild("Shop")
    return shop and shop:FindFirstChild("Cases")
end

local function getToolNameFromButton(buttonName)
    local name = tostring(buttonName or "")
    name = name:gsub("^Buy%s+", "")
    -- Strip a trailing price tag, e.g. "War Fan - $34000" or "Item - [$1,234]"
    name = name:gsub("%s*%-%s*%[?%$[%d%,%.kKmMbB]+%]?%s*$", "")
    return name
end

local function getSortedCases(casesFolder)
    local cases = casesFolder:GetChildren()
    table.sort(cases, function(a, b)
        local numA = tonumber(a.Name)
        local numB = tonumber(b.Name)
        if numA and numB then
            return numA < numB
        elseif numA then
            return true
        elseif numB then
            return false
        else
            return tostring(a.Name):lower() < tostring(b.Name):lower()
        end
    end)
    return cases
end

local function findToolInCase(case)
    for _, child in ipairs(case:GetChildren()) do
        if child:IsA("Tool") or child:IsA("Model") or child:IsA("Part") then
            if child.Name ~= "Platform" and child.Name ~= "CaseBase" then
                return child.Name
            end
        end
    end
    return nil
end

local function getCaseDisplayName(case, pp)
    -- The reliable, human-readable name lives on the floating billboard above
    -- each case (e.g. "War Fan - $34000"); the case/item instances themselves
    -- are just generically named ("Item", "Model", "ShopCase") and the
    -- ProximityPrompt's ActionText is always just "Purchase?", so neither is
    -- usable as a display name on its own.
    local platform = case:FindFirstChild("Platform")
    local billboard = platform and platform:FindFirstChild("TitleBillboard")
    local label = billboard and billboard:FindFirstChild("TextLabel")
    if label and label.Text and label.Text ~= "" then
        return label.Text
    end

    local toolName = findToolInCase(case)
    if toolName then return toolName end

    if pp.ActionText and pp.ActionText ~= "" and pp.ActionText ~= "Purchase?" then
        return pp.ActionText
    end
    if pp.ObjectText and pp.ObjectText ~= "" then
        return pp.ObjectText
    end
    return case.Name
end

local function processCase(case, caseIndex, pp, values, valueToCaseIndex)
    local toolName = getCaseDisplayName(case, pp)
    local display = getToolNameFromButton(toolName)
    if display == "" then
        display = "Case " .. tostring(caseIndex)
    end

    local unique = display
    local i = 2
    while valueToCaseIndex[unique] do
        unique = display .. " (" .. tostring(i) .. ")"
        i += 1
    end

    valueToCaseIndex[unique] = caseIndex
    table.insert(values, unique)
end

local function collectShopTools()
    local values = {}
    local valueToCaseIndex = {}
    local casesFolder = getShopCasesFolder()
    if not casesFolder then
        return {"No tools found"}, valueToCaseIndex
    end

    local cases = getSortedCases(casesFolder)

    for caseIndex, case in ipairs(cases) do
        local platform = case:FindFirstChild("Platform")
        local pp = platform and platform:FindFirstChild("PP")
        if pp and pp:IsA("ProximityPrompt") then
            processCase(case, caseIndex, pp, values, valueToCaseIndex)
        end
    end

    table.sort(values, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)

    if #values == 0 then
        table.insert(values, "No tools found")
    end

    return values, valueToCaseIndex
end

quickShopValues, quickToolToCaseIndex = collectShopTools()
if #quickShopValues > 0 and quickShopValues[1] ~= "No tools found" then
    selectedQuickTool = quickShopValues[1]
end

TycoonToolbarBox:AddDropdown('QuickShopTools', {
    Values = quickShopValues,
    Default = 1,
    Text = 'Select Tool',
    Callback = function(value)
        if value and value ~= "No tools found" then
            selectedQuickTool = value
        else
            selectedQuickTool = nil
        end
    end
})

TycoonToolbarBox:AddButton({
    Text = 'Buy Selected Tool',
    Func = function()
        if not selectedQuickTool then
            Library:Notify("Select a tool first", 3)
            return
        end

        local caseIndex = quickToolToCaseIndex[selectedQuickTool]
        if not caseIndex then
            Library:Notify("Tool mapping not found, refresh list", 3)
            return
        end

        -- Get character and save position
        local hrp = getQuickShopHRP()
        if not hrp then
            Library:Notify("Could not find character", 3)
            return
        end
        local lastPosition = hrp.CFrame

        -- Find the case
        local casesFolder = getShopCasesFolder()
        if not casesFolder then
            Library:Notify("Shop cases not found", 3)
            return
        end

        local cases = casesFolder:GetChildren()
        table.sort(cases, function(a, b)
            local numA = tonumber(a.Name)
            local numB = tonumber(b.Name)
            if numA and numB then
                return numA < numB
            elseif numA then
                return true
            elseif numB then
                return false
            else
                return tostring(a.Name):lower() < tostring(b.Name):lower()
            end
        end)

        local targetCase = cases[caseIndex]
        if not targetCase then
            Library:Notify("Case " .. tostring(caseIndex) .. " not found", 3)
            return
        end

        local platform = targetCase:FindFirstChild("Platform")
        local pp = platform and platform:FindFirstChild("PP")
        if not pp or not pp:IsA("ProximityPrompt") then
            Library:Notify("ProximityPrompt not found for " .. selectedQuickTool, 3)
            return
        end

        -- Teleport to platform, fire prompt, teleport back
        local ok = pcall(function()
            hrp.CFrame = platform.CFrame + Vector3.new(0, 5, 0)
            task.wait(0.2)
            fireproximityprompt(pp)
            task.wait(0.3)
            hrp.CFrame = lastPosition
        end)

        if ok then
            Library:Notify("Quick bought: " .. tostring(selectedQuickTool), 3)
        else
            Library:Notify("Purchase failed to trigger", 3)
        end
    end
})

TycoonToolbarBox:AddButton({
    Text = 'Refresh Tools',
    Func = function()
        quickShopValues, quickToolToCaseIndex = collectShopTools()
        Library:Notify("Tools found: " .. tostring(#quickShopValues - (quickShopValues[1] == "No tools found" and 1 or 0)), 3)
    end
})
end -- Quick Shop scope
-- ===================== TYCOON AUTO FARM =====================
-- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
do
local Autoform = {
    Enabled = false,
    TargetEnemy = "Auto",
    Connection = nil,
    FireThread = nil,
    Tool = nil,
    TargetNPC = nil,
    TargetTorso = nil,
    OriginalTorsoSize = nil,
    OriginalTorsoTransparency = nil,
    Delay = 0.15,
    -- Rolling history of the last few farmed NPC names (see RECENT_HISTORY_SIZE).
    -- A single "last target" wasn't enough: Rogue Ninja/Sound Ninja/Reanimated
    -- Ninja respawn in ~3 seconds, so Auto mode would just bounce between two of
    -- those three forever and never let anything else (bosses, statue spawns) in.
    RecentTargetNames = {},
    StatueRotationIndex = 0,
}

local function getFarmHRP()
    local character = LP.Character
    if not character then
        character = LP.CharacterAdded:Wait()
    end
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function cleanupAutoform()
    Autoform.Enabled = false
    if Autoform.Connection then
        Autoform.Connection:Disconnect()
        Autoform.Connection = nil
    end
    if Autoform.FireThread then
        task.cancel(Autoform.FireThread)
        Autoform.FireThread = nil
    end
    if Autoform.TargetTorso and Autoform.OriginalTorsoSize and Autoform.OriginalTorsoTransparency then
        pcall(function()
            Autoform.TargetTorso.Size = Autoform.OriginalTorsoSize
            Autoform.TargetTorso.Transparency = Autoform.OriginalTorsoTransparency
        end)
    end
    Autoform.Tool = nil
    Autoform.TargetNPC = nil
    Autoform.TargetTorso = nil
end

local function equipAndFire()
    local character = LP.Character
    if not character then return end
    local tool = Autoform.Tool
    if not tool or not tool.Parent then return end
    if tool.Parent ~= character then
        tool.Parent = character
    end
    if tool.Parent == character then
        pcall(function()
            tool:Activate()
        end)
    end
end

-- setupAutoformTool/setupAutoformTarget/getTargetNPC are forward-declared and
-- assigned inside the nested do-blocks below, split into two separate blocks that
-- each close as soon as their own one-off dependencies (NPC lookup, cash parsing,
-- statue spawning, etc.) are no longer needed by name. This frees their local
-- registers progressively instead of holding everything live for the rest of this
-- section (Luau caps a function at 200 live locals, which this file kept hitting).
local setupAutoformTool, setupAutoformTarget, getTargetNPC

do
    local FARM_NPC_PRIORITY = {
        -- existing / bosses
        "Jigan",
        "Nisshiki Otsutsushi",
        "Gimshiki", -- renamed from Jigan/Nisshiki Otsutsushi in a game update
        "Monashiki (Awakened)", -- next phase after Gimshiki dies
        "Tenth Beast",

        -- requested additions
        "Mizouki",
        "Oroshimaro",
        "Pain",
        "Juubito",
        "Nadara",
        "Kaguyai",
        "Clownjason",
        "Rogue Ninja",
        "Sound Ninja",
        "Reanimated Ninja",
    }

    local FARM_TORSO_PARTS = { "Torso", "HumanoidRootPart", "MainTorso" }

    local function getNpcTorso(model)
        if not model then return nil end
        for _, partName in ipairs(FARM_TORSO_PARTS) do
            local p = model:FindFirstChild(partName)
            if p and p:IsA("BasePart") then
                return p
            end
        end
        -- fallback: first BasePart (covers odd rigs)
        local anyPart = model:FindFirstChildWhichIsA("BasePart")
        return anyPart
    end

    -- A boss's model/corpse can stick around in the workspace after death (still
    -- being cleaned up, ragdolled, etc.); without this check the farm would lock
    -- onto a dead NPC forever instead of moving on to the next one.
    local function isNpcAlive(model)
        if not model or not model.Parent then return false end
        local hum = model:FindFirstChildOfClass("Humanoid")
        return hum ~= nil and hum.Health > 0
    end

    local function getNpcByName(name)
        if not name then return nil end
        -- Recursive lookup: some enemies (e.g. "Pain") live 5+ folders deep inside a
        -- player's Tycoon (Tycoons/<Owner>/PurchasedObjects/<Name>), not in workspace
        -- root or BossRooms, so a shallow search was missing them entirely.
        local npc = workspace:FindFirstChild(name, true)
        if npc and npc:IsA("Model") and isNpcAlive(npc) then return npc end
        return nil
    end

    -- This fight has multiple phases under different names: "Jigan"/"Nisshiki
    -- Otsutsushi" was renamed to "Gimshiki" in a game update, and once that phase
    -- dies it's replaced by "Monashiki (Awakened)". Check all of them every time so
    -- farming doesn't stall when the fight transitions to its next name/phase.
    local JIGAN_PHASE_NAMES = {
        "Jigan",
        "Nisshiki Otsutsushi",
        "Gimshiki",
        "Monashiki (Awakened)",
    }

    getTargetNPC = function()
        local choice = Autoform.TargetEnemy

        -- Only lock onto a phase that's actually alive right now; if the current
        -- phase's corpse is still around when the next phase spawns, prefer whichever
        -- one is alive instead of getting stuck on the dead one.
        local jigan
        for _, phaseName in ipairs(JIGAN_PHASE_NAMES) do
            local candidate = workspace:FindFirstChild(phaseName)
            if candidate and isNpcAlive(candidate) then
                jigan = candidate
                break
            end
        end

        local tenthCandidate = workspace:FindFirstChild("Tenth Beast")
        local tenth = (tenthCandidate and isNpcAlive(tenthCandidate)) and tenthCandidate or nil

        local function getJigan()
            local torso = jigan and getNpcTorso(jigan)
            return (torso and jigan) or nil, torso
        end
        local function getTenth()
            local torso = tenth and (tenth:FindFirstChild("MainTorso") or tenth:WaitForChild("MainTorso", 10))
            return (torso and tenth) or nil, torso
        end

        if choice == "Jigan / Nisshiki" or choice == "Gimshiki" or choice == "Monashiki (Awakened)" then
            return getJigan()
        elseif choice == "Tenth Beast" then
            return getTenth()
        end

        -- Direct selection by NPC name: only ever return that NPC, or nothing at all.
        -- Previously this fell through to the Auto fallback below when the chosen NPC
        -- wasn't found yet, which farmed a completely different enemy than selected.
        if choice and choice ~= "Auto" then
            local m = getNpcByName(choice)
            local t = getNpcTorso(m)
            if m and t then
                return m, t
            end
            return nil, nil
        end

        -- Auto mode: Jigan/Tenth first, then priority scan. Some trash mobs (Rogue
        -- Ninja, Sound Ninja, Reanimated Ninja) respawn in ~3 seconds, so a single
        -- "last target" exclusion wasn't enough to stop Auto mode bouncing between
        -- just those two or three forever. Exclude anything in the recent-history
        -- list instead, so once all the fast respawners have had a turn, the scan
        -- is forced past them onto everything else (and, if nothing else is up,
        -- into the statue-spawn rotation in setupAutoformTarget).
        local function isRecentTarget(name)
            if not name then return false end
            for _, recent in ipairs(Autoform.RecentTargetNames) do
                if recent == name then return true end
            end
            return false
        end

        local function scanAuto(allowRepeat)
            if jigan and (allowRepeat or not isRecentTarget(jigan.Name)) then
                local aNpc, aTorso = getJigan()
                if aTorso then return aNpc, aTorso end
            end
            if tenth and (allowRepeat or not isRecentTarget(tenth.Name)) then
                local tNpc, tTorso = getTenth()
                if tTorso then return tNpc, tTorso end
            end
            for _, name in ipairs(FARM_NPC_PRIORITY) do
                if allowRepeat or not isRecentTarget(name) then
                    local m = getNpcByName(name)
                    local t = getNpcTorso(m)
                    if m and t then
                        return m, t
                    end
                end
            end
            return nil, nil
        end

        local npc, torso = scanAuto(false)
        if npc then return npc, torso end
        return scanAuto(true) -- nothing else available, allow repeating a recent target
    end
end -- Block 1 closes: frees the NPC-lookup locals now that getTargetNPC is defined

do
    local function parseCash(str)
        str = tostring(str):lower():gsub("%+", "")
        local multiplier = 1
        if str:find("k") then
            multiplier = 1e3
        elseif str:find("m") then
            multiplier = 1e6
        elseif str:find("b") then
            multiplier = 1e9
        end
        local num = tonumber(str:match("[%d%.]+"))
        return num and num * multiplier or 0
    end

    local function getCashValue()
        local leaderstats = LP:FindFirstChild("leaderstats") or LP:WaitForChild("leaderstats", 10)
        local cash = leaderstats and leaderstats:FindFirstChild("Cash")
        if not cash then return 0 end
        return parseCash(cash.Value)
    end

    -- Some bosses (Juubito, Kaguyai, Mizouki, Oroshimaro, Nadara, Pain, Clownjason)
    -- don't exist in the world until their statue is interacted with (walk up, hold
    -- F on the ProximityPrompt). Without this, selecting one of them just waits
    -- forever since the NPC never spawns on its own. Clownjason's statue lives under
    -- workspace.kamuiDimension instead of workspace.BossRooms like the others, but
    -- the recursive FindFirstChild(name, true) search in trySpawnViaStatue finds it
    -- regardless of location.
    local STATUE_MAP = {
        ["Juubito"] = "JuubitoSTATUE",
        ["Kaguyai"] = "KaguyaiSTATUE",
        ["Mizouki"] = "MizoukiSTATUE",
        ["Oroshimaro"] = "OroshimaroSTATUE",
        ["Nadara"] = "NadaraSTATUE",
        ["Pain"] = "PainSTATUE",
        ["Clownjason"] = "ClownjasonSTATUE",
    }
    -- Fixed order (not pairs()'s undefined order) so Auto mode's rotation below is
    -- stable/predictable instead of jumping around randomly between calls.
    local STATUE_ENEMY_ORDER = { "Juubito", "Kaguyai", "Mizouki", "Oroshimaro", "Nadara", "Pain", "Clownjason" }

    -- >= the number of fast-respawning trash mobs (Rogue/Sound/Reanimated Ninja) so
    -- that once all of them have had a turn, the exclusion in getTargetNPC's Auto
    -- scan forces it past them onto slower/statue-gated enemies.
    local RECENT_HISTORY_SIZE = 3

    local function trySpawnViaStatue(enemyName)
        local statueName = STATUE_MAP[enemyName]
        if not statueName then return false end

        local statue = workspace:FindFirstChild(statueName, true)
        if not statue then return false end

        local prompt = statue:FindFirstChild("ProxPrompt") or statue:FindFirstChildWhichIsA("ProximityPrompt", true)
        local anchor = statue:FindFirstChild("HumanoidRootPart")
        if not prompt or not anchor then return false end

        local hrp = getFarmHRP()
        if not hrp then return false end

        -- Move within the prompt's activation range and face the statue (RequiresLineOfSight)
        hrp.CFrame = CFrame.new(anchor.Position + Vector3.new(0, 3, 5), anchor.Position)
        task.wait(0.5)

        local ok = pcall(function()
            fireproximityprompt(prompt)
        end)

        task.wait(3)
        return ok
    end

    local function findTool(toolName)
        local backpack = LP:FindFirstChild("Backpack")
        local tool = backpack and backpack:FindFirstChild(toolName)
        if tool then return tool end
        local char = LP.Character
        tool = char and char:FindFirstChild(toolName)
        if tool then return tool end
        local zone = workspace:FindFirstChild(LP.Name)
        tool = zone and zone:FindFirstChild(toolName)
        return tool
    end

    local function tryBuyIceDeathSenbons()
        local hrp = getFarmHRP()
        if not hrp then return false end

        local shop = workspace:FindFirstChild("Shop")
        local cases = shop and shop:FindFirstChild("Cases")
        if not cases then return false end

        local case30 = cases:GetChildren()[30]
        if not case30 then return false end

        local platform = case30:FindFirstChild("Platform")
        local pp = platform and platform:FindFirstChild("PP")
        if not pp then return false end

        local lastPosition = hrp.CFrame
        hrp.CFrame = platform.CFrame + Vector3.new(0, 5, 0)
        task.wait(1)

        pcall(function()
            fireproximityprompt(pp)
        end)

        task.wait(2)
        hrp.CFrame = lastPosition
        return true
    end

    setupAutoformTool = function()
        local tool = findTool("Ice Death Senbons")
        if not tool then
            local requiredCash = 20000
            local cashValue = getCashValue()
            if cashValue >= requiredCash then
                if tryBuyIceDeathSenbons() then
                    task.wait(1)
                    tool = findTool("Ice Death Senbons")
                end
            else
                task.wait(10)
                return nil
            end
        end
        if not tool then
            task.wait(2)
            return nil
        end
        Autoform.Tool = tool
        return tool
    end

    setupAutoformTarget = function()
        local npc, torso = getTargetNPC()

        if not npc or not torso then
            local choice = Autoform.TargetEnemy
            if choice ~= "Auto" and STATUE_MAP[choice] then
                -- explicit statue-gated selection: (re)trigger that exact one
                if trySpawnViaStatue(choice) then
                    npc, torso = getTargetNPC()
                end
            elseif choice == "Auto" then
                -- Nothing alive: try spawning one statue-gated boss per call, rotating
                -- through the list (skipping anything farmed recently, if possible) so
                -- Auto mode doesn't just sit idle waiting for a natural-spawn NPC.
                local function isRecentTarget(name)
                    for _, recent in ipairs(Autoform.RecentTargetNames) do
                        if recent == name then return true end
                    end
                    return false
                end
                for i = 1, #STATUE_ENEMY_ORDER do
                    Autoform.StatueRotationIndex = (Autoform.StatueRotationIndex % #STATUE_ENEMY_ORDER) + 1
                    local candidateName = STATUE_ENEMY_ORDER[Autoform.StatueRotationIndex]
                    if not isRecentTarget(candidateName) or i == #STATUE_ENEMY_ORDER then
                        if trySpawnViaStatue(candidateName) then
                            npc, torso = getTargetNPC()
                        end
                        break
                    end
                end
            end
        end

        if not npc or not torso then
            task.wait(2)
            return nil, nil
        end

        Autoform.TargetNPC = npc
        Autoform.TargetTorso = torso

        -- Keep only the last RECENT_HISTORY_SIZE names so the exclusion above ages out.
        table.insert(Autoform.RecentTargetNames, npc.Name)
        while #Autoform.RecentTargetNames > RECENT_HISTORY_SIZE do
            table.remove(Autoform.RecentTargetNames, 1)
        end

        Autoform.OriginalTorsoSize = torso.Size
        Autoform.OriginalTorsoTransparency = torso.Transparency

        pcall(function()
            torso.Size = Vector3.new(100, 200, 100)
            torso.Transparency = 0.7
        end)

        local npcDead = false
        local deathConn
        local hum = npc:FindFirstChildOfClass("Humanoid")
        if hum then
            deathConn = hum.Died:Connect(function()
                npcDead = true
            end)
        end

        return npcDead, deathConn, hum, npc
    end
end -- Block 2 closes: frees the cash/tool/statue locals now that setupAutoformTool/setupAutoformTarget are defined

local function runAutoformPositionLoop(npcDead, hum, npc)
    local posConn = RS.RenderStepped:Connect(function()
        if not Autoform.Enabled or npcDead then return end
        if not npc or not npc.Parent then
            npcDead = true
            return
        end
        if hum and hum.Health <= 0 then
            npcDead = true
            return
        end
        local hrp = getFarmHRP()
        if not hrp then return end
        local targetTorso = Autoform.TargetTorso
        if not targetTorso or not targetTorso.Parent then
            npcDead = true
            return
        end
        local pillarTop = targetTorso.Position + Vector3.new(0, targetTorso.Size.Y/2, 0)
        local safePos = pillarTop + Vector3.new(0, 5, 0)
        hrp.CFrame = CFrame.new(safePos)
    end)
    return posConn
end

local function cleanupAutoformTarget(npcDead, deathConn, posConn, hum, npc)
    if posConn then posConn:Disconnect() end
    if deathConn then deathConn:Disconnect() end
    if Autoform.TargetTorso and Autoform.OriginalTorsoSize and Autoform.OriginalTorsoTransparency then
        pcall(function()
            Autoform.TargetTorso.Size = Autoform.OriginalTorsoSize
            Autoform.TargetTorso.Transparency = Autoform.OriginalTorsoTransparency
        end)
    end
    Autoform.TargetNPC = nil
    Autoform.TargetTorso = nil
end

local function runAutoformLoop(npcDead, deathConn, hum, npc)
    local posConn = runAutoformPositionLoop(npcDead, hum, npc)

    while Autoform.Enabled and not npcDead do
        if not npc or not npc.Parent then
            npcDead = true
            break
        end
        if hum and hum.Health <= 0 then
            npcDead = true
            break
        end
        equipAndFire()
        task.wait(Autoform.Delay)
    end

    cleanupAutoformTarget(npcDead, deathConn, posConn, hum, npc)
end

local function startAutoform()
    cleanupAutoform()
    Autoform.Enabled = true

    Autoform.FireThread = task.spawn(function()
        while Autoform.Enabled do
            local tool = setupAutoformTool()
            if not tool then
                if not Autoform.Enabled then break end
                continue
            end

            local npcDead, deathConn, hum, npc = setupAutoformTarget()
            if not npc then
                if not Autoform.Enabled then break end
                continue
            end

            runAutoformLoop(npcDead, deathConn, hum, npc)

            if Autoform.Enabled then
                task.wait(2)
            end
        end
    end)
end

TycoonFarmBox:AddDropdown('AutoformEnemy', {
    Values = {
        "Auto",
        "Jigan / Nisshiki",
        "Gimshiki",
        "Monashiki (Awakened)",
        "Tenth Beast",
        "Mizouki",
        "Oroshimaro",
        "Pain",
        "Juubito",
        "Nadara",
        "Kaguyai",
        "Clownjason",
        "Rogue Ninja",
        "Sound Ninja",
        "Reanimated Ninja",
    },
    Default = 1,
    Text = 'Enemy',
    Callback = function(v)
        Autoform.TargetEnemy = v
    end
})

TycoonFarmBox:AddToggle('AutoformEnabled', {
    Text = 'Enable Auto Farm',
    Default = false,
    Callback = function(state)
        if state then
            startAutoform()
        else
            cleanupAutoform()
        end
    end
})
end -- Tycoon Auto Farm scope



-- ===================== TRANSFORMATION MODE ACTIVATOR =====================
do -- Mode Activator Scope
    -- Each gamepass transformation button lives inside PlayerGui.RobuxShop.Frame.Buttons.<Name>
    -- and has a child RemoteEvent. Normally GamepassLocalScript checks ownership before firing it.
    -- We skip that check and fire the RemoteEvent directly.
    --
    -- RemoveMode fires directly with no gamepass check — included as a utility button.

    local ModeBox = Tabs.Visual:AddRightGroupbox('Mode Activator')

    -- Map of display name → button name in PlayerGui.RobuxShop.Frame.Buttons
    local MODES = {
        { name = "KCM (Kurama Chakra)",    btn = "KCM"           },
        { name = "Baryon Mode",             btn = "Baryon"        },
        { name = "Six Paths Mode",          btn = "SixPaths"      },
        { name = "8 Gates",                 btn = "8Gates"        },
        { name = "Curse Mark",              btn = "CurseMark"     },
        { name = "Demon Fox Cloak",         btn = "DemonFoxCloak" },
        { name = "ESS",                     btn = "ESS"           },
        { name = "Karma",                   btn = "Karma"         },
        { name = "Lightning Cloak",         btn = "LightningCloak"},
        { name = "Riku Rinne",              btn = "RikuRinne"     },
        { name = "Senju Sage",              btn = "SenjuSage"     },
        { name = "Snake Sage",              btn = "SnakeSage"     },
        { name = "TCM",                     btn = "TCM"           },
        { name = "Toad Sage",               btn = "ToadSage"      },
    }

    local modeNames = {}
    for _, m in ipairs(MODES) do
        table.insert(modeNames, m.name)
    end

    local selectedMode = nil

    -- Helper: fire the RemoteEvent for a button name
    local function fireMode(btnName)
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then
            Library:Notify("PlayerGui not found", 3)
            return false
        end
        local shop = pg:FindFirstChild("RobuxShop")
        if not shop then
            Library:Notify("RobuxShop not in PlayerGui — open it first", 4)
            return false
        end
        -- Navigate: RobuxShop → Frame → Buttons → <btnName> → RemoteEvent
        local frame = shop:FindFirstChild("Frame")
        local buttons = frame and frame:FindFirstChild("Buttons")
        local btn = buttons and buttons:FindFirstChild(btnName)
        local remote = btn and btn:FindFirstChild("RemoteEvent")
        if not remote then
            Library:Notify("Remote for " .. btnName .. " not found — is shop loaded?", 4)
            return false
        end
        remote:FireServer()
        return true
    end

    -- RemoveMode: direct fire, no gamepass
    local function fireRemoveMode()
        local pg = LP:FindFirstChild("PlayerGui")
        local shop = pg and pg:FindFirstChild("RobuxShop")
        local frame = shop and shop:FindFirstChild("Frame")
        local buttons = frame and frame:FindFirstChild("Buttons")
        local btn = buttons and buttons:FindFirstChild("RemoveMode")
        local remote = btn and btn:FindFirstChild("RemoteEvent")
        if remote then
            remote:FireServer()
            Library:Notify("Mode removed", 3)
        else
            Library:Notify("RemoveMode remote not found", 3)
        end
    end

    ModeBox:AddDropdown('ModeActivatorDropdown', {
        Values = modeNames,
        Default = 1,
        Text = 'Select Mode',
        Callback = function(v)
            selectedMode = v
        end
    })

    ModeBox:AddButton({
        Text = 'Activate Mode',
        Func = function()
            if not selectedMode then
                Library:Notify("Select a mode first", 3)
                return
            end
            -- Find btn name for selected display name
            local btnName
            for _, m in ipairs(MODES) do
                if m.name == selectedMode then
                    btnName = m.btn
                    break
                end
            end
            if not btnName then
                Library:Notify("Mode mapping not found", 3)
                return
            end
            local ok = fireMode(btnName)
            if ok then
                Library:Notify("Activated: " .. selectedMode, 3)
            end
        end
    })

    ModeBox:AddButton({
        Text = 'Remove Mode',
        Func = function()
            fireRemoveMode()
        end
    })

    ModeBox:AddLabel('Note: RobuxShop must be open/loaded in PlayerGui for remotes to exist.')

    -- Spam toggle: repeatedly fires the selected mode on a short interval
    local spamThread = nil
    ModeBox:AddToggle('ModeSpam', {
        Text = 'Spam Mode',
        Default = false,
        Tooltip = 'Repeatedly fires the selected mode every 0.1s',
        Callback = function(v)
            if v then
                spamThread = task.spawn(function()
                    while Toggles.ModeSpam.Value do
                        if selectedMode then
                            local btnName
                            for _, m in ipairs(MODES) do
                                if m.name == selectedMode then btnName = m.btn; break end
                            end
                            if btnName then fireMode(btnName) end
                        end
                        task.wait(0.1)
                    end
                end)
            else
                if spamThread then
                    task.cancel(spamThread)
                    spamThread = nil
                end
            end
        end
    })
end

-- ===================== RYO MODE ACTIVATOR =====================
do -- Ryo Mode Scope
    -- RyoShop buttons fire: button.Event:FireServer(LocalPlayer)
    -- The LocalScript checks debounce but NOT Ryo balance — server handles deduction.
    -- Firing the remote directly bypasses the debounce gate.
    -- NOTE: Server still checks Ryo balance. This just skips the 3s client debounce.

    local RyoModeBox = Tabs.Visual:AddRightGroupbox('Ryo Mode Activator')

    local RYO_MODES = {
        { name = "Lava",        btn = "Lava"        },
        { name = "Yellow Flash", btn = "YellowFlash" },
        { name = "Explosive",   btn = "Explo"       },
        { name = "Hallow",      btn = "Hallow"      },
        { name = "SOSB",        btn = "SOSB"        },
        { name = "Paper Angel", btn = "PaperAngel"  },
    }

    local ryoModeNames = {}
    for _, m in ipairs(RYO_MODES) do table.insert(ryoModeNames, m.name) end

    local selectedRyoMode = nil

    local function fireRyoMode(btnName)
        local pg = LP:FindFirstChild("PlayerGui")
        local shop = pg and pg:FindFirstChild("RyoShop")
        local frame = shop and shop:FindFirstChild("Frame")
        local buttons = frame and frame:FindFirstChild("Buttons")
        local btn = buttons and buttons:FindFirstChild(btnName)
        local remote = btn and btn:FindFirstChild("Event")
        if not remote then
            Library:Notify("RyoShop remote not found — open the shop first", 4)
            return false
        end
        remote:FireServer(LP)
        return true
    end

    RyoModeBox:AddDropdown('RyoModeDropdown', {
        Values = ryoModeNames,
        Default = 1,
        Text = 'Select Ryo Mode',
        Callback = function(v) selectedRyoMode = v end
    })

    RyoModeBox:AddButton({
        Text = 'Activate Ryo Mode',
        Func = function()
            if not selectedRyoMode then
                Library:Notify("Select a mode first", 3)
                return
            end
            local btnName
            for _, m in ipairs(RYO_MODES) do
                if m.name == selectedRyoMode then btnName = m.btn; break end
            end
            if fireRyoMode(btnName) then
                Library:Notify("Fired: " .. selectedRyoMode, 3)
            end
        end
    })

    RyoModeBox:AddButton({
        Text = 'Remove Mode (Ryo)',
        Func = function()
            local pg = LP:FindFirstChild("PlayerGui")
            local shop = pg and pg:FindFirstChild("RyoShop")
            local frame = shop and shop:FindFirstChild("Frame")
            local buttons = frame and frame:FindFirstChild("Buttons")
            local btn = buttons and buttons:FindFirstChild("RemoveMode")
            -- RyoShop RemoveMode uses GamepassLocalScript pattern (RemoteEvent child)
            local remote = btn and (btn:FindFirstChild("Event") or btn:FindFirstChild("RemoteEvent"))
            if remote then
                remote:FireServer(LP)
                Library:Notify("Mode removed", 3)
            else
                Library:Notify("Remove remote not found", 3)
            end
        end
    })

    local ryoSpamThread = nil
    RyoModeBox:AddToggle('RyoModeSpam', {
        Text = 'Spam Mode',
        Default = false,
        Tooltip = 'Repeatedly fires the selected Ryo mode every 0.1s',
        Callback = function(v)
            if v then
                ryoSpamThread = task.spawn(function()
                    while Toggles.RyoModeSpam.Value do
                        if selectedRyoMode then
                            local btnName
                            for _, m in ipairs(RYO_MODES) do
                                if m.name == selectedRyoMode then btnName = m.btn; break end
                            end
                            if btnName then fireRyoMode(btnName) end
                        end
                        task.wait(0.1)
                    end
                end)
            else
                if ryoSpamThread then
                    task.cancel(ryoSpamThread)
                    ryoSpamThread = nil
                end
            end
        end
    })
end

-- ===================== TRANSFORMATION CHANGER =====================
-- Confirmed mesh/anim IDs from live game inspection (Ninja Tycoon v4.7)
-- Structure matches what the server spawns: Model with Part "Middle" welded to char
-- Torso/HumanoidRootPart, then MeshPart "Cloak" welded to Middle via Weld.
-- HeadPart model welds Middle to Head with extra face/ear meshes.
-- AnimationController on the Model drives bone animations for skinned meshes.
do -- Transformation Changer Scope
    local TransformChangerBox = Tabs.Visual:AddLeftGroupbox('Transformation Changer')

    -- ── Active state ──
    local TC_Active = { models={}, animTracks={}, name=nil }

    -- ── Transformation definitions ──
    -- All values confirmed from live inspection of real Baryon player (Chasegta2010)
    local TRANSFORMS = {
        -- ── Byron Mode ──
        {
            name = "Byron Mode",
            -- Chest model: welded to Torso via Weld C0=identity C1=identity
            chest = {
                -- Middle Part (invisible anchor)
                middleSize = Vector3.new(2, 2, 1),
                -- Weld: Middle→Middle  C0 = rot(-90 around Z effectively), same C1
                middleSelfC0 = CFrame.new(0,0,0, 0,0,-1, 0,1,0, 1,0,0),
                -- Weld: Middle→Cloak
                cloakC1 = CFrame.new(0.000412, 0.347275, -2.491, 0,0,-1, 0,1,0, 1,0,0),
                -- Cloak MeshPart (skinned)
                cloakMesh = "rbxassetid://7525881516",
                cloakSize = Vector3.new(9.2173, 5.6080, 6.2245),
                -- Full bone hierarchy Transform values (exact from live game)
                bones = {
                    -- Bone hierarchy — Transform is the bind-pose offset (identity = no offset)
                    -- These match the real server-spawned structure exactly.
                    {n="Bone.013", p="",         t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                      {n="Bone.006", p="Bone.013", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                        {n="Bone.007", p="Bone.006", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                          {n="Bone.008", p="Bone.007", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                            {n="Bone.009", p="Bone.008", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                              {n="Bone.010", p="Bone.009", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                                {n="Bone.011", p="Bone.010", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                      {n="Bone",     p="Bone.013", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                        {n="Bone.001", p="Bone",     t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                          {n="Bone.002", p="Bone.001", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                            {n="Bone.005", p="Bone.002", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                              {n="Bone.003", p="Bone.005", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                                {n="Bone.004", p="Bone.003", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                      {n="Bone.014", p="Bone.013", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                        {n="Bone.017", p="Bone.014", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                          {n="Bone.015", p="Bone.017", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                            {n="Bone.016", p="Bone.015", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                      {n="Bone.018", p="Bone.013", t=CFrame.new(0,0,0, 0.462022,-0.330620,0.822937, -0.128831,0.893051,0.431118, -0.877461,-0.305206,0.370015)},
                        {n="Bone.024", p="Bone.018", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                          {n="Bone.019", p="Bone.024", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                            {n="Bone.021", p="Bone.019", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                      {n="Bone.020", p="Bone.013", t=CFrame.new(0,0,0, 0.462022,-0.330620,0.822937, -0.128831,0.893051,0.431118, -0.877461,-0.305206,0.370015)},
                        {n="Bone.025", p="Bone.020", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                          {n="Bone.022", p="Bone.025", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                            {n="Bone.023", p="Bone.022", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                      {n="Bone.038", p="Bone.013", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                        {n="Bone.039", p="Bone.038", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                          {n="Bone.040", p="Bone.039", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                            {n="Bone.041", p="Bone.040", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                      {n="Bone.026", p="Bone.013", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                        {n="Bone.027", p="Bone.026", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                          {n="Bone.028", p="Bone.027", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                            {n="Bone.029", p="Bone.028", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                      {n="Bone.030", p="Bone.013", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                        {n="Bone.031", p="Bone.030", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                          {n="Bone.032", p="Bone.031", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                            {n="Bone.033", p="Bone.032", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                      {n="Bone.034", p="Bone.013", t=CFrame.new(0,0,0, -0.441806,-0.220987,0.869467, -0.136896,0.974442,0.178106, -0.886604,-0.040338,-0.460767)},
                        {n="Bone.035", p="Bone.034", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                          {n="Bone.036", p="Bone.035", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                            {n="Bone.037", p="Bone.036", t=CFrame.new(0,0,0, 1,0,0, 0,1,0, 0,0,1)},
                },
                -- Particle on Cloak
                particleTex   = "rbxassetid://4662388553",
                particleColor = Color3.new(1, 0.356863, 0.356863),
                particleRate  = 100,
                -- AnimationController animation
                animId = "rbxassetid://8692139849",
            },
            -- HeadPart model: welded to Head via Weld C0=identity C1=identity
            head = {
                middleSize = Vector3.new(2, 1, 1),
                -- Middle self-weld
                middleSelfC0 = CFrame.new(0,0,0, 0,0,-1, 0,1,0, 1,0,0),
                -- BaryonFaceMarking weld C1
                faceC1   = CFrame.new(-0.312988, -0.372604, 0.000412, -1,0,0, 0,1,0, 0,0,-1),
                faceMesh = "rbxassetid://8697667025",
                faceSize = Vector3.new(0.4958, 1.2678, 1.2799),
                -- Ears weld C1
                earsC1   = CFrame.new(0.000412, -0.662460, 0.214539, 0,0,-1, 0,1,0, 1,0,0),
                earsMesh = "rbxassetid://7525872822",
                earsSize = Vector3.new(1.3229, 0.7993, 0.5419),
            },
        },
    }

    -- Build display names for dropdown
    local transformNames = {}
    for _, t in ipairs(TRANSFORMS) do table.insert(transformNames, t.name) end

    -- ── Helper: make invisible anchor Part ──
    local function makePart(name, size, parent)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size or Vector3.new(2,2,1)
        p.Transparency = 1
        p.Anchored = false
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.Massless = true
        p.CastShadow = false
        p.Parent = parent
        return p
    end

    -- ── Helper: make skinned MeshPart ──
    local function makeMeshPart(name, meshId, size, parent)
        local m = Instance.new("MeshPart")
        m.Name = name
        m.MeshId = meshId
        m.TextureID = ""
        m.Size = size
        m.Anchored = false
        m.CanCollide = false
        m.CanTouch = false
        m.CanQuery = false
        m.Massless = true
        m.CastShadow = false
        m.DoubleSided = true
        m.RenderFidelity = Enum.RenderFidelity.Precise
        m.Parent = parent
        return m
    end

    -- ── Helper: make Weld ──
    local function makeWeld(p0, p1, c0, c1, parent)
        local w = Instance.new("Weld")
        w.Part0 = p0
        w.Part1 = p1
        w.C0 = c0 or CFrame.new()
        w.C1 = c1 or CFrame.new()
        w.Parent = parent or p0
        return w
    end

    -- ── Build full Chest model with exact bones ──
    local function createBoneHierarchy(cloak, bones)
        local boneMap = {}
        for _, bd in ipairs(bones) do
            local bone = Instance.new("Bone")
            bone.Name = bd.n
            bone.Transform = bd.t
            boneMap[bd.n] = bone
        end
        for _, bd in ipairs(bones) do
            local bone = boneMap[bd.n]
            if bd.p == "" then
                bone.Parent = cloak
            else
                bone.Parent = boneMap[bd.p] or cloak
            end
        end
    end

    local function createParticleEmitter(cloak, def)
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "Droplets"
        pe.Texture = def.particleTex
        pe.Rate = def.particleRate
        pe.LightEmission = 1
        pe.LightInfluence = 0
        pe.Speed = NumberRange.new(3, 3)
        pe.Lifetime = NumberRange.new(1, 1)
        pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0.3), NumberSequenceKeypoint.new(1,0.3)})
        pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)})
        pe.Color = ColorSequence.new(def.particleColor)
        pe.SpreadAngle = Vector2.new(-360, 360)
        pe.VelocitySpread = 360
        pe.ZOffset = 1
        pe.Shape = Enum.ParticleEmitterShape.Sphere
        pe.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        pe.Enabled = true
        pe.Parent = cloak
    end

    local function createAnimationController(model, animId)
        local animCtrl = Instance.new("AnimationController")
        animCtrl.Name = "AnimationController"
        local animator = Instance.new("Animator"); animator.Parent = animCtrl
        animCtrl.Parent = model

        local animInst = Instance.new("Animation")
        animInst.Name = "Animation"
        animInst.AnimationId = animId
        animInst.Parent = model

        return animCtrl, animInst
    end

    local function buildChest(def, torso)
        local model = Instance.new("Model")
        model.Name = "Chest"

        local s = Instance.new("Script"); s.Disabled = true; s.Parent = model

        local middle = makePart("Middle", def.middleSize, model)
        middle.CFrame = torso.CFrame

        local cloak = makeMeshPart("Cloak", def.cloakMesh, def.cloakSize, model)
        pcall(function()
            if sethiddenproperty then
                sethiddenproperty(cloak, "HasSkinnedMesh", true)
                sethiddenproperty(cloak, "MeshId", "https://assetdelivery.roblox.com/v1/asset/?id=" .. (def.cloakMesh:match("%d+") or "7525881516"))
            end
        end)
        cloak.CFrame = torso.CFrame

        makeWeld(middle, middle, def.middleSelfC0, def.middleSelfC0, middle)
        makeWeld(middle, cloak, def.middleSelfC0, def.cloakC1, middle)

        createBoneHierarchy(cloak, def.bones)
        createParticleEmitter(cloak, def)

        local animCtrl, animInst = createAnimationController(model, def.animId)

        model.PrimaryPart = middle
        return model, animCtrl, animInst, middle
    end

    -- ── Build HeadPart model with exact welds ──
    local function buildHeadPart(def, head)
        local model = Instance.new("Model")
        model.Name = "HeadPart"

        local middle = makePart("Middle", def.middleSize, model)
        middle.CFrame = head.CFrame

        local face = makeMeshPart("BaryonFaceMarking", def.faceMesh, def.faceSize, model)
        face.CFrame = head.CFrame

        local ears = makeMeshPart("Ears", def.earsMesh, def.earsSize, model)
        ears.CFrame = head.CFrame

        makeWeld(middle, middle, def.middleSelfC0, def.middleSelfC0, middle)
        makeWeld(middle, face,   def.middleSelfC0, def.faceC1,       middle)
        makeWeld(middle, ears,   def.middleSelfC0, def.earsC1,       middle)

        model.PrimaryPart = middle
        return model, middle
    end

    -- ── Attach transformation to character ──
    local function attachTransform(def)
        local char = LP.Character
        if not char then Library:Notify("No character loaded", 3); return end

        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                   or char:FindFirstChild("HumanoidRootPart")
        local head  = char:FindFirstChild("Head")
        if not torso then Library:Notify("Torso not found", 3); return end

        -- Clean up any previous transformation
        for _, m in ipairs(TC_Active.models) do
            pcall(function() if m and m.Parent then m:Destroy() end end)
        end
        for _, t in ipairs(TC_Active.animTracks) do
            pcall(function() t:Stop(0) end)
        end
        TC_Active.models = {}
        TC_Active.animTracks = {}

        -- ── Build and attach Chest ──
        if def.chest then
            local chestModel, animCtrl, animInst, middle = buildChest(def.chest, torso)

            -- Build HeadPart
            if def.head and head then
                local hpModel, hpMiddle = buildHeadPart(def.head, head)
                hpModel.Parent = char
                for _, w in ipairs(head:GetChildren()) do
                    if (w:IsA("Weld") or w:IsA("WeldConstraint")) then
                        local p1 = w:IsA("Weld") and w.Part1 or nil
                        if p1 and p1.Name == "Middle" then
                            pcall(function() w:Destroy() end)
                        end
                    end
                end
                makeWeld(head, hpMiddle, CFrame.new(), CFrame.new(), head)
                table.insert(TC_Active.models, hpModel)
            end

            if chestModel and middle then
                chestModel.Parent = char
                -- Remove any stale Torso→Middle welds before adding a fresh one
                for _, w in ipairs(torso:GetChildren()) do
                    if (w:IsA("Weld") or w:IsA("WeldConstraint")) then
                        local p1 = w:IsA("Weld") and w.Part1 or nil
                        if p1 and p1.Name == "Middle" then
                            pcall(function() w:Destroy() end)
                        end
                    end
                end
                makeWeld(torso, middle, CFrame.new(), CFrame.new(), torso)

                -- Play bone animation
                if animCtrl and animInst then
                    pcall(function()
                        local animator = animCtrl:FindFirstChildOfClass("Animator")
                        if animator then
                            local track = animator:LoadAnimation(animInst)
                            track.Looped = true
                            track:Play()
                            table.insert(TC_Active.animTracks, track)
                        end
                    end)
                end
                table.insert(TC_Active.models, chestModel)
            end
        end

        -- ── HeadPart (only if not already added above) ──
        if def.head and head and #TC_Active.models < 2 then
            local model, middle = buildHeadPart(def.head, head)
            model.Parent = char
            -- Remove any stale Head→Middle welds first
            for _, w in ipairs(head:GetChildren()) do
                if (w:IsA("Weld") or w:IsA("WeldConstraint")) then
                    local p1 = w:IsA("Weld") and w.Part1 or nil
                    if p1 and p1.Name == "Middle" then
                        pcall(function() w:Destroy() end)
                    end
                end
            end
            -- Attach via Weld: Head → Middle (C0=identity, C1=identity)
            makeWeld(head, middle, CFrame.new(), CFrame.new(), head)
            table.insert(TC_Active.models, model)
        end

        TC_Active.name = def.name
        Library:Notify("Applied: " .. def.name, 4)
    end

    -- ── Remove transformation ──
    local function removeTransform()
        for _, m in ipairs(TC_Active.models) do
            pcall(function() if m and m.Parent then m:Destroy() end end)
        end
        for _, t in ipairs(TC_Active.animTracks) do
            pcall(function() t:Stop(0) end)
        end
        TC_Active.models = {}
        TC_Active.animTracks = {}
        TC_Active.name = nil
        local char = LP.Character
        if char then
            for _, c in ipairs(char:GetChildren()) do
                if c.Name == "Chest" or c.Name == "HeadPart" or c.Name == "TC_Cloak" then
                    pcall(function() c:Destroy() end)
                end
            end
            -- Remove welds we placed on Torso/Head targeting our Middle parts
            for _, part in ipairs({char:FindFirstChild("Torso"), char:FindFirstChild("Head"),
                                    char:FindFirstChild("UpperTorso")}) do
                if part then
                    for _, w in ipairs(part:GetChildren()) do
                        if (w:IsA("Weld") or w:IsA("WeldConstraint")) then
                            local p1 = w.Part1
                            if p1 and p1.Name == "Middle" and
                               (not p1.Parent or not p1.Parent:IsA("Model") or
                                p1.Parent.Name == "Chest" or p1.Parent.Name == "HeadPart") then
                                pcall(function() w:Destroy() end)
                            end
                        end
                    end
                end
            end
        end
        Library:Notify("Transformation removed", 3)
    end

    -- ── Reapply on respawn ──
    LP.CharacterAdded:Connect(function()
        if not TC_Active.name then return end
        if not (Toggles.TransformAutoReapply and Toggles.TransformAutoReapply.Value) then return end
        task.wait(1.5)
        TC_Active.models = {}
        TC_Active.animTracks = {}
        for _, def in ipairs(TRANSFORMS) do
            if def.name == TC_Active.name then
                attachTransform(def)
                break
            end
        end
    end)

    -- ── UI ──
    local selectedTransformDef = TRANSFORMS[1]

    TransformChangerBox:AddLabel('Client-side only | No gamepass needed')
    TransformChangerBox:AddDivider()

    TransformChangerBox:AddDropdown('TransformChangerDrop', {
        Values = transformNames,
        Default = 1,
        Text = 'Select Transformation',
        Callback = function(v)
            for _, def in ipairs(TRANSFORMS) do
                if def.name == v then selectedTransformDef = def; break end
            end
        end
    })

    TransformChangerBox:AddButton({
        Text = 'Apply Transformation',
        Func = function()
            if not selectedTransformDef then Library:Notify("Select a transformation first", 3); return end
            attachTransform(selectedTransformDef)
        end
    })

    TransformChangerBox:AddButton({
        Text = 'Remove Transformation',
        Func = function() removeTransform() end
    })

    TransformChangerBox:AddToggle('TransformAutoReapply', {
        Text = 'Auto Reapply on Respawn',
        Default = true,
        Tooltip = 'Automatically reapplies the transformation when your character respawns.',
        Callback = function(state)
            if not state then TC_Active.name = nil end
        end
    })
end

-- ===================== ANIM PACKS =====================
do
    local AnimPackBox = Tabs.Visual:AddLeftGroupbox('Anim Packs')
    local RS_svc = game:GetService("ReplicatedStorage")

    -- Map Pack folder name → display name using the Idle StringValue child name
    local function buildPackMap()
        local map = {}   -- displayName → packFolderName
        local names = {}
        local animPacks = RS_svc:FindFirstChild("AnimPacks")
        if animPacks then
            for _, pack in ipairs(animPacks:GetChildren()) do
                if not pack:IsA("Folder") then continue end
                local idleFolder = pack:FindFirstChild("Idle")
                local idleChild = idleFolder and (idleFolder:GetChildren()[1])
                local displayName = (idleChild and idleChild.Name ~= "Normal") and idleChild.Name or pack.Name
                map[displayName] = pack.Name
                table.insert(names, displayName)
            end
            table.sort(names)
        end
        if #names == 0 then
            table.insert(names, "No packs found")
        end
        return names, map
    end

    local function getAnimIdFromFolder(folder)
        if not folder then return nil end
        local child = folder:FindFirstChild("Normal") or folder:GetChildren()[1]
        if not child then return nil end
        if child:IsA("StringValue") and child.Value ~= "" then return child.Value end
        if child:IsA("Animation") then return child.AnimationId end
        return nil
    end

    local function patchAnimateScript(char, idleId, walkId)
        if not char then return false end
        local animScript = char:FindFirstChild("Animate")
        if not animScript then return false end
        local function injectAnim(slotName, animId)
            if not animId or animId == "" then return false end
            local slot = animScript:FindFirstChild(slotName)
            if not slot then
                slot = Instance.new("Folder")
                slot.Name = slotName
                slot.Parent = animScript
            end
            for _, ch in ipairs(slot:GetChildren()) do
                if ch:IsA("Animation") then ch:Destroy() end
            end
            local anim = Instance.new("Animation")
            anim.Name = slotName .. "_goathub"
            anim.AnimationId = animId
            anim.Parent = slot
            return true
        end
        local ok1 = idleId and injectAnim("idle", idleId)
        local ok2 = walkId and injectAnim("walk", walkId)
        return ok1 or ok2
    end

    local packNames, packMap = buildPackMap()
    local selectedAnimPack = nil

    AnimPackBox:AddDropdown('AnimPackDropdown', {
        Values = packNames,
        Default = 1,
        Text = 'Select Anim Pack',
        Callback = function(v)
            selectedAnimPack = (v and v ~= "No packs found") and v or nil
        end
    })

    AnimPackBox:AddButton({
        Text = 'Apply Pack',
        Func = function()
            if not selectedAnimPack then
                Library:Notify("Select an anim pack first", 3); return
            end
            local folderName = packMap[selectedAnimPack]
            local animPacks = RS_svc:FindFirstChild("AnimPacks")
            local pack = animPacks and folderName and animPacks:FindFirstChild(folderName)
            if not pack then
                Library:Notify("Pack not found: " .. tostring(selectedAnimPack), 3); return
            end
            local playerAnims = LP:FindFirstChild("PlayerAnims")
            if not playerAnims then
                Library:Notify("PlayerAnims not found — are you in-game?", 3); return
            end

            local applied, errors = {}, {}

            local idleId = getAnimIdFromFolder(pack:FindFirstChild("Idle"))
            local myIdleNormal = playerAnims:FindFirstChild("Idle") and playerAnims.Idle:FindFirstChild("Normal")
            if idleId and myIdleNormal then
                local ok, err = pcall(function() myIdleNormal.Value = idleId end)
                if ok then table.insert(applied, "Idle") else table.insert(errors, "Idle: " .. tostring(err)) end
            elseif not idleId then table.insert(errors, "No Idle ID")
            elseif not myIdleNormal then table.insert(errors, "PlayerAnims.Idle.Normal missing") end

            local walkId = getAnimIdFromFolder(pack:FindFirstChild("Walk"))
            local myWalkNormal = playerAnims:FindFirstChild("Walk") and playerAnims.Walk:FindFirstChild("Normal")
            if walkId and myWalkNormal then
                local ok, err = pcall(function() myWalkNormal.Value = walkId end)
                if ok then table.insert(applied, "Walk") else table.insert(errors, "Walk: " .. tostring(err)) end
            elseif not walkId then table.insert(errors, "No Walk ID")
            elseif not myWalkNormal then table.insert(errors, "PlayerAnims.Walk.Normal missing") end

            if (idleId or walkId) and LP.Character then
                if patchAnimateScript(LP.Character, idleId, walkId) then
                    table.insert(applied, "Animate patched")
                end
            end

            local packStance = pack:FindFirstChild("StanceValue")
            local myStance = playerAnims:FindFirstChild("StanceValue")
            if packStance and myStance then
                pcall(function() myStance.Value = packStance.Value end)
            end

            if #applied > 0 then
                Library:Notify("Applied " .. selectedAnimPack .. " (" .. table.concat(applied, ", ") .. ")", 5)
            end
            if #errors > 0 then
                Library:Notify("Errors: " .. table.concat(errors, " | "), 5)
            end
            if #applied == 0 and #errors == 0 then
                Library:Notify("Nothing applied", 4)
            end
        end
    })

    AnimPackBox:AddButton({
        Text = 'Refresh Pack List',
        Func = function()
            packNames, packMap = buildPackMap()
            pcall(function()
                if Options.AnimPackDropdown then
                    Options.AnimPackDropdown:SetValues(packNames)
                end
            end)
            local count = 0
            for _, v in ipairs(packNames) do
                if v ~= "No packs found" then count += 1 end
            end
            Library:Notify("Packs found: " .. count, 3)
        end
    })
end

-- ===================== VISUAL / MISC SETTINGS =====================
do -- Visual Misc Scope
    local VisualMiscBox = Tabs.Visual:AddLeftGroupbox('Visual Settings')

    -- ── Day / Night toggle ──
    -- Replicates the daynight Settingz button logic (pure Lighting service, client-only)
    local isDayMode = true

    local DAY_PRESET = {
        ClockTime           = 14,
        Ambient             = Color3.fromRGB(127, 127, 127),
        OutdoorAmbient      = Color3.fromRGB(128, 128, 128),
        FogColor            = Color3.fromRGB(192, 192, 192),
        FogEnd              = 100000,
        AtmosphereColor     = Color3.fromRGB(199, 170, 143),
        AtmosphereDecay     = Color3.fromRGB(93, 54, 22),
        AtmosphereGlare     = 0,
        AtmosphereHaze      = 1.75,
    }

    local NIGHT_PRESET = {
        ClockTime           = 3.8,
        Ambient             = Color3.fromRGB(25, 30, 55),
        OutdoorAmbient      = Color3.fromRGB(15, 20, 45),
        FogColor            = Color3.fromRGB(20, 20, 40),
        FogEnd              = 800,
        AtmosphereColor     = Color3.fromRGB(10, 10, 30),
        AtmosphereDecay     = Color3.fromRGB(5, 5, 20),
        AtmosphereGlare     = 0.1,
        AtmosphereHaze      = 2.5,
    }

    local function applyLightingPreset(preset)
        local Lighting = game:GetService("Lighting")
        pcall(function() Lighting.ClockTime      = preset.ClockTime      end)
        pcall(function() Lighting.Ambient        = preset.Ambient        end)
        pcall(function() Lighting.OutdoorAmbient = preset.OutdoorAmbient end)
        pcall(function() Lighting.FogColor       = preset.FogColor       end)
        pcall(function() Lighting.FogEnd         = preset.FogEnd         end)
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then
            pcall(function() atm.Color  = preset.AtmosphereColor  end)
            pcall(function() atm.Decay  = preset.AtmosphereDecay  end)
            pcall(function() atm.Glare  = preset.AtmosphereGlare  end)
            pcall(function() atm.Haze   = preset.AtmosphereHaze   end)
        end
    end

    VisualMiscBox:AddToggle('DayNightToggle', {
        Text = 'Night Mode',
        Default = false,
        Tooltip = 'Switches Lighting to a dark night preset. Client-only.',
        Callback = function(state)
            isDayMode = not state
            applyLightingPreset(state and NIGHT_PRESET or DAY_PRESET)
        end
    })

    -- ── Disable CamShake ──
    -- The CamShake LocalScript in your character is what produces screen shake.
    -- Disabling it stops all camera shake from boss hits, explosions, etc.
    local camShakeConn = nil
    VisualMiscBox:AddToggle('DisableCamShake', {
        Text = 'Disable Cam Shake',
        Default = false,
        Tooltip = 'Disables the CamShake script in your character so hits no longer shake your camera.',
        Callback = function(state)
            local function applyToChar(char)
                local cs = char:FindFirstChild("CamShake")
                    or char:WaitForChild("CamShake", 3)
                if cs then cs.Disabled = state end
            end
            local char = LP.Character
            if char then applyToChar(char) end
            if camShakeConn then camShakeConn:Disconnect() end
            if state then
                camShakeConn = LP.CharacterAdded:Connect(applyToChar)
            else
                camShakeConn = nil
            end
        end
    })

    -- ── Disable Damage Indicators ──
    local dmgIndConn = nil
    VisualMiscBox:AddToggle('DisableDmgInd', {
        Text = 'Disable Damage Numbers',
        Default = false,
        Tooltip = 'Hides floating damage numbers. Client-only.',
        Callback = function(state)
            local function applyToChar(char)
                local dmg = char:FindFirstChild("DmgIndScript")
                    or char:WaitForChild("DmgIndScript", 3)
                if dmg then dmg.Enabled = not state end
            end
            local char = LP.Character
            if char then applyToChar(char) end
            if dmgIndConn then dmgIndConn:Disconnect() end
            if state then
                dmgIndConn = LP.CharacterAdded:Connect(applyToChar)
            else
                dmgIndConn = nil
            end
        end
    })

    -- ── Low Graphics ──
    -- Replicates the LowGraphics LocalScript: sets all map parts to SmoothPlastic,
    -- disables shadows, bloom, atmosphere effects. Big FPS boost on low-end devices.
    local lowGfxApplied = false
    local lowGfxBackup  = {}

    VisualMiscBox:AddToggle('LowGraphics', {
        Text = 'Low Graphics Mode',
        Default = false,
        Tooltip = 'Sets all map parts to SmoothPlastic, disables shadows and post-processing. FPS boost.',
        Callback = function(state)
            local Lighting = game:GetService("Lighting")
            if state then
                -- Disable post-processing
                pcall(function() Lighting.GlobalShadows = false end)
                for _, effect in ipairs(Lighting:GetChildren()) do
                    if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect")
                    or effect:IsA("DepthOfFieldEffect") or effect:IsA("ColorCorrectionEffect") then
                        pcall(function()
                            lowGfxBackup[effect] = effect.Enabled
                            effect.Enabled = false
                        end)
                    end
                end
                local atm = Lighting:FindFirstChildOfClass("Atmosphere")
                if atm then
                    lowGfxBackup["atm_density"] = atm.Density
                    pcall(function() atm.Density = 0 end)
                end
                -- Set all map parts to SmoothPlastic (same as the game's own LowGraphics script)
                task.spawn(function()
                    for _, folder in ipairs({
                        workspace:FindFirstChild("Map"),
                        workspace:FindFirstChild("BossRooms"),
                        workspace:FindFirstChild("Zednov's Tycoon Kit"),
                        workspace:FindFirstChild("QuizMap"),
                    }) do
                        if not folder then continue end
                        for _, part in ipairs(folder:GetDescendants()) do
                            if part:IsA("BasePart") then
                                pcall(function()
                                    part.Material = Enum.Material.SmoothPlastic
                                    part.CastShadow = false
                                end)
                            end
                        end
                    end
                    lowGfxApplied = true
                end)
            else
                -- Restore post-processing
                pcall(function() Lighting.GlobalShadows = true end)
                for effect, wasEnabled in pairs(lowGfxBackup) do
                    if type(effect) ~= "string" then
                        pcall(function() effect.Enabled = wasEnabled end)
                    end
                end
                local atm = Lighting:FindFirstChildOfClass("Atmosphere")
                if atm and lowGfxBackup["atm_density"] then
                    pcall(function() atm.Density = lowGfxBackup["atm_density"] end)
                end
                lowGfxBackup = {}
                lowGfxApplied = false
                -- Note: material changes to map parts are not reversed (would require backup)
                Library:Notify("Post-FX restored. Map materials not reversed.", 3)
            end
        end
    })

    -- ── Boss Teleport ──
    -- The Teleporters in workspace have Enabled BoolValues gating them.
    -- We can just teleport directly to the boss room positions.
    -- Coordinates harvested from the live game (v4.7.5).
    local BOSS_LOCATIONS = {
        ["Juubi Boss Room"]    = CFrame.new(-1144.6, 2534, -410.9),
        ["Pain Boss Room"]     = CFrame.new(1972.0, 2421, -410.5),
        ["Madara Boss Room"]   = CFrame.new(692.8, 2420, 1490.3),
        ["Obito Boss Room"]    = CFrame.new(-1390.7, 2439, 1558.2),
        ["Juubito Boss Room"]  = CFrame.new(-1304.4, 2422, 1595.7),
        ["Kaguya Boss Room"]   = CFrame.new(-1597.1, 2365, -2336.5),
        ["Mizuki Boss Room"]   = CFrame.new(56.7, 2422, 2521.9),
        ["Nadara Boss Room"]   = CFrame.new(772.5, 2424, 1567.1),
        ["Orochimaru Boss Room"] = CFrame.new(99.3, 2457, -2728.1),
        ["Akatsuki Hideout"]   = CFrame.new(3831.6, 4325, -144.2),
        ["Pain's Paths"]       = CFrame.new(3970.9, 4426, 3090.3),
        ["Kamui Dimension"]    = CFrame.new(-4512.6, 2417, -1682.0),
        ["Shop Safe Zone"]     = CFrame.new(800.1, 817, -539.8),
        ["Spawn"]              = CFrame.new(-284.8, -112, 56.6),
    }

    local bossLocationNames = {}
    for name, _ in pairs(BOSS_LOCATIONS) do table.insert(bossLocationNames, name) end
    table.sort(bossLocationNames)

    VisualMiscBox:AddDropdown('BossTeleportDrop', {
        Values = bossLocationNames,
        Default = 1,
        Text = 'Boss Teleport',
        Tooltip = 'Teleport to boss rooms directly, bypassing the gated teleporters.',
        Callback = function(v) end
    })

    VisualMiscBox:AddButton({
        Text = 'Teleport',
        Func = function()
            local dest = Options.BossTeleportDrop and Options.BossTeleportDrop.Value
            if not dest then Library:Notify("Select a destination", 3); return end
            local cf = BOSS_LOCATIONS[dest]
            if not cf then Library:Notify("Location not mapped", 3); return end
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = cf
                Library:Notify("Teleported to " .. dest, 3)
            end
        end
    })
end

do -- Anim Packs Scope
    local AnimPackBox = Tabs.Visual:AddLeftGroupbox('Anim Packs')

    local RS_svc = game:GetService("ReplicatedStorage")

    local function getAnimPackNames()
        local names = {}
        local animPacks = RS_svc:FindFirstChild("AnimPacks")
        if animPacks then
            for _, pack in ipairs(animPacks:GetChildren()) do
                if pack:IsA("Folder") then
                    table.insert(names, pack.Name)
                end
            end
            table.sort(names)
        end
        if #names == 0 then
            table.insert(names, "No packs found")
        end
        return names
    end

    -- Helper: get the rbxassetid string from a StringValue or Animation inside a folder.
    -- Pack children are StringValues with .Value = "rbxassetid://XXXXXX"
    local function getAnimIdFromFolder(folder)
        if not folder then return nil end
        -- Try "Normal" first, then fall back to any child
        local child = folder:FindFirstChild("Normal") or folder:GetChildren()[1]
        if not child then return nil end
        -- StringValue stores the ID as .Value
        if child:IsA("StringValue") then
            local v = child.Value
            if v and v ~= "" then return v end
        end
        -- Fallback: Animation instance
        if child:IsA("Animation") then
            return child.AnimationId
        end
        return nil
    end

    -- Patch the running Animate LocalScript's animation table so new anims play immediately.
    -- The Animate script keeps a live u8 table keyed by animation type. We inject
    -- Animation instances under script.idle / script.walk so configureAnimationSet picks them up.
    local function patchAnimateScript(char, idleId, walkId)
        if not char then return false end
        local animScript = char:FindFirstChild("Animate")
        if not animScript then return false end

        local function injectAnim(slotName, animId)
            if not animId or animId == "" then return false end
            -- Remove old injected animations
            local slot = animScript:FindFirstChild(slotName)
            if not slot then
                slot = Instance.new("Folder")
                slot.Name = slotName
                slot.Parent = animScript
            end
            -- Clear previous entries in this slot
            for _, ch in ipairs(slot:GetChildren()) do
                if ch:IsA("Animation") then ch:Destroy() end
            end
            -- Insert fresh Animation
            local anim = Instance.new("Animation")
            anim.Name = slotName .. "_goathub"
            anim.AnimationId = animId
            anim.Parent = slot
            return true
        end

        local ok1 = idleId and injectAnim("idle", idleId)
        local ok2 = walkId and injectAnim("walk", walkId)
        return ok1 or ok2
    end

    local selectedAnimPack = nil

    AnimPackBox:AddDropdown('AnimPackDropdown', {
        Values = getAnimPackNames(),
        Default = 1,
        Text = 'Select Anim Pack',
        Callback = function(v)
            if v and v ~= "No packs found" then
                selectedAnimPack = v
            else
                selectedAnimPack = nil
            end
        end
    })

    AnimPackBox:AddButton({
        Text = 'Apply Pack',
        Func = function()
            if not selectedAnimPack then
                Library:Notify("Select an anim pack first", 3)
                return
            end

            local animPacks = RS_svc:FindFirstChild("AnimPacks")
            local pack = animPacks and animPacks:FindFirstChild(selectedAnimPack)
            if not pack then
                Library:Notify("Pack not found: " .. tostring(selectedAnimPack), 3)
                return
            end

            -- PlayerAnims lives at Players.LocalPlayer.PlayerAnims (not in Backpack)
            local playerAnims = LP:FindFirstChild("PlayerAnims")
            if not playerAnims then
                Library:Notify("PlayerAnims not found — are you in-game?", 3)
                return
            end

            local applied = {}
            local errors  = {}

            -- ── Idle ──
            -- Pack: AnimPacks.PackN.Idle.SomeName (StringValue, .Value = "rbxassetid://...")
            -- Target: Players.LP.PlayerAnims.Idle.Normal (StringValue, .Value = "rbxassetid://...")
            local packIdleFolder = pack:FindFirstChild("Idle")
            local myIdleNormal   = playerAnims:FindFirstChild("Idle")
                                   and playerAnims.Idle:FindFirstChild("Normal")

            local idleId = getAnimIdFromFolder(packIdleFolder)
            if idleId and myIdleNormal then
                local ok, err = pcall(function()
                    myIdleNormal.Value = idleId
                end)
                if ok then
                    table.insert(applied, "Idle → " .. idleId)
                else
                    table.insert(errors, "Idle write: " .. tostring(err))
                end
            elseif not packIdleFolder then
                table.insert(errors, "Pack missing Idle folder")
            elseif not idleId then
                table.insert(errors, "Pack Idle: no anim ID found")
            elseif not myIdleNormal then
                table.insert(errors, "PlayerAnims.Idle.Normal not found")
            end

            -- ── Walk ──
            local packWalkFolder = pack:FindFirstChild("Walk")
            local myWalkNormal   = playerAnims:FindFirstChild("Walk")
                                   and playerAnims.Walk:FindFirstChild("Normal")

            local walkId = getAnimIdFromFolder(packWalkFolder)
            if walkId and myWalkNormal then
                local ok, err = pcall(function()
                    myWalkNormal.Value = walkId
                end)
                if ok then
                    table.insert(applied, "Walk → " .. walkId)
                else
                    table.insert(errors, "Walk write: " .. tostring(err))
                end
            elseif not packWalkFolder then
                table.insert(errors, "Pack missing Walk folder")
            elseif not walkId then
                table.insert(errors, "Pack Walk: no anim ID found")
            elseif not myWalkNormal then
                table.insert(errors, "PlayerAnims.Walk.Normal not found")
            end

            -- ── Patch the running Animate script so animations change immediately ──
            -- The Animate LocalScript uses Animation children injected under script.idle/walk
            -- to override its defaults. This is the only client-side way to force new anims.
            if (idleId or walkId) and LP.Character then
                local patched = patchAnimateScript(LP.Character, idleId, walkId)
                if patched then
                    table.insert(applied, "Animate script patched")
                end
            end

            -- ── StanceValue — server-controlled, best-effort only ──
            local packStance = pack:FindFirstChild("StanceValue")
            local myStance   = playerAnims:FindFirstChild("StanceValue")
            if packStance and myStance then
                pcall(function() myStance.Value = packStance.Value end)
                -- Don't report success/failure — server will overwrite this anyway
            end

            -- ── Report ──
            if #applied > 0 then
                Library:Notify("✓ Applied " .. selectedAnimPack
                    .. " (" .. #applied .. " ok"
                    .. (#errors > 0 and ", " .. #errors .. " err" or "")
                    .. ")", 5)
            end
            if #errors > 0 then
                Library:Notify("⚠ " .. table.concat(errors, " | "), 5)
            end
            if #applied == 0 and #errors == 0 then
                Library:Notify("Nothing applied — pack may have no anim IDs accessible", 4)
            end
        end
    })

    AnimPackBox:AddButton({
        Text = 'Refresh Pack List',
        Func = function()
            local names = getAnimPackNames()
            local count = 0
            for _, v in ipairs(names) do
                if v ~= "No packs found" then count += 1 end
            end
            pcall(function()
                if Options.AnimPackDropdown then
                    Options.AnimPackDropdown:SetValues(names)
                end
            end)
            Library:Notify("Packs found: " .. tostring(count), 3)
        end
    })
end

-- ===================== NO MOVE COOLDOWN =====================
do -- No Cooldown Scope
    -- hookfunction patches the C-level function pointer directly, so it works
    -- on all threads including obfuscated bytecode that has wait/task.wait
    -- baked in at load time — unlike getgenv() replacement which only catches
    -- scripts that look up the global at call time.
    --
    -- Each move's cooldown script (confirmed via decompile of Sage Toad's "Rem"
    -- and Mystic Healing Palm's "Remote") just does debounce=true; FireServer();
    -- wait(N); debounce=false. We match on that literal N (same approach as
    -- Ninja Parkur.lua) — caller-script identification via debug.info was tried
    -- but this executor (Potassium) doesn't return usable stack info through the
    -- hookfunction/newcclosure boundary, so duration matching is the reliable
    -- option. Moves that share a duration (Primary Lotus / Tenths Beast /
    -- Byankogan are all 10s) can't be distinguished by value alone and share a
    -- single toggle.

    local NoCDGroupBox = Tabs.Main:AddRightGroupbox('No Cooldown')

    local NC = {
        Enabled = {}, -- [duration] = true
        waitHook     = nil,
        taskWaitHook = nil,
    }

    local function applyHooks()
        if NC.waitHook then return end -- already applied
        pcall(function()
            local origWait
            origWait = hookfunction(wait, newcclosure(function(t)
                local n = tonumber(t)
                if n and NC.Enabled[n] then
                    return origWait(0)
                end
                return origWait(t)
            end))
            NC.waitHook = origWait
        end)
        pcall(function()
            local origTaskWait
            origTaskWait = hookfunction(task.wait, newcclosure(function(t)
                local n = tonumber(t)
                if n and NC.Enabled[n] then
                    return origTaskWait(0)
                end
                return origTaskWait(t)
            end))
            NC.taskWaitHook = origTaskWait
        end)
    end

    local function removeHooks()
        pcall(function()
            if NC.waitHook then
                unhookfunction(wait)
                NC.waitHook = nil
            end
        end)
        pcall(function()
            if NC.taskWaitHook then
                unhookfunction(task.wait)
                NC.taskWaitHook = nil
            end
        end)
    end

    -- Move name → cooldown duration passed to wait()/task.wait()
    local MOVE_COOLDOWNS = {
        { Key = 'NoCDPhoenixVolley',  Text = 'Phoenix Volley',                            Duration = 7  },
        { Key = 'NoCDShadowControl',  Text = 'Shadow Control',                            Duration = 6  },
        { Key = 'NoCDPrimaryLotus',   Text = 'Primary Lotus / Tenths Beast / Byankogan',  Duration = 10 },
        { Key = 'NoCDSageToad',       Text = 'Sage Toad',                                 Duration = 4  },
        { Key = 'NoCDMysticHealing',  Text = 'Mystic Healing Palm',                       Duration = 12 },
    }

    for _, move in ipairs(MOVE_COOLDOWNS) do
        NoCDGroupBox:AddToggle(move.Key, {
            Text = 'No CD: ' .. move.Text,
            Default = false,
            Tooltip = 'Bypasses the ' .. move.Duration .. 's cooldown for ' .. move.Text .. ' only.',
            Callback = function(state)
                NC.Enabled[move.Duration] = state or nil
                applyHooks()
            end
        })
    end

    local NC_GuiConn = nil

    local function startGuiCleaner()
        if NC_GuiConn then NC_GuiConn:Disconnect() end
        -- Kill any already-existing cooldown slots
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then
            for _, child in ipairs(pg:GetDescendants()) do
                if child.Name == "CooldownSlot"
                or child.Name == "ToolSkillCooldownSlot"
                or child.Name == "CooldownGui" then
                    pcall(function() child:Destroy() end)
                end
            end
        end
        -- Destroy new ones as they spawn
        NC_GuiConn = game.DescendantAdded:Connect(function(obj)
            if obj.Name == "CooldownSlot"
            or obj.Name == "ToolSkillCooldownSlot"
            or obj.Name == "CooldownGui" then
                task.defer(function()
                    if obj and obj.Parent then
                        pcall(function() obj:Destroy() end)
                    end
                end)
            end
        end)
    end

    local function stopGuiCleaner()
        if NC_GuiConn then
            NC_GuiConn:Disconnect()
            NC_GuiConn = nil
        end
    end

    NoCDGroupBox:AddToggle('NoCooldownGuiHide', {
        Text = 'Hide Cooldown Bar',
        Default = false,
        Tooltip = 'Destroys CooldownSlot UI frames as they spawn so the cooldown bar is never visible.',
        Callback = function(state)
            if state then
                startGuiCleaner()
            else
                stopGuiCleaner()
            end
        end
    })
end

do -- Dash Lines Color Scope
    local DashColorBox = Tabs.Visual:AddLeftGroupbox('Dash Lines Color')

    DashColorBox:AddLabel('Dash Color'):AddColorPicker('DashLineColor', {
        Default = Color3.fromRGB(255, 255, 255),
        Title = 'Dash Lines Color',
        Transparency = 0,
        Callback = function(color)
            local RS2 = game:GetService("ReplicatedStorage")
            local dashLines = RS2:FindFirstChild("ModuleAssets")
                and RS2.ModuleAssets:FindFirstChild("DashLines")
            if not dashLines then
                Library:Notify("DashLines not found in ModuleAssets", 3)
                return
            end
            local changed = 0
            -- Set Color directly on DashLines itself if it has the property
            pcall(function()
                if dashLines:IsA("BasePart") or dashLines:IsA("PointLight") or dashLines:IsA("SpotLight") or dashLines:IsA("SurfaceLight") then
                    dashLines.Color = color
                    changed += 1
                elseif dashLines:IsA("Beam") or dashLines:IsA("Trail") or dashLines:IsA("ParticleEmitter") then
                    dashLines.Color = ColorSequence.new(color)
                    changed += 1
                end
            end)
            for _, part in ipairs(dashLines:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("ImageLabel") or part:IsA("Frame") then
                    pcall(function()
                        if part:IsA("BasePart") then
                            part.Color = color
                        else
                            part.BackgroundColor3 = color
                            part.ImageColor3 = color
                        end
                    end)
                    changed += 1
                end
            end
            -- Also try BeamColor / Trail Color
            for _, obj in ipairs(dashLines:GetDescendants()) do
                if obj:IsA("Beam") then
                    pcall(function()
                        obj.Color = ColorSequence.new(color)
                    end)
                    changed += 1
                elseif obj:IsA("Trail") then
                    pcall(function()
                        obj.Color = ColorSequence.new(color)
                    end)
                    changed += 1
                elseif obj:IsA("ParticleEmitter") then
                    pcall(function()
                        obj.Color = ColorSequence.new(color)
                    end)
                    changed += 1
                end
            end
        end
    })
end

-- ===================== MISC TAB =====================
do
    local MiscTeleportBox = Tabs.Misc:AddLeftGroupbox('Teleports')
    local MiscEspBox = Tabs.Misc:AddLeftGroupbox('Player ESP')

    -- ── Teleport to Player ──
    local function getOtherPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then table.insert(names, p.Name) end
        end
        table.sort(names)
        if #names == 0 then table.insert(names, "No players found") end
        return names
    end

    MiscTeleportBox:AddDropdown('TPPlayerDropdown', {
        Values = getOtherPlayerNames(),
        Default = 1,
        Text = 'Target Player',
        Tooltip = 'Player to teleport to',
        Callback = function() end
    })

    MiscTeleportBox:AddButton({
        Text = 'Refresh Players',
        Func = function()
            Options.TPPlayerDropdown:SetValues(getOtherPlayerNames())
        end
    })

    MiscTeleportBox:AddButton({
        Text = 'Teleport to Player',
        Func = function()
            local name = Options.TPPlayerDropdown and Options.TPPlayerDropdown.Value
            if not name or name == "No players found" then
                Library:Notify("Select a valid player first", 3); return
            end
            local target = Players:FindFirstChild(name)
            local tHRP = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if tHRP and myHRP then
                myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, 3)
                Library:Notify("Teleported to " .. name, 3)
            else
                Library:Notify("Target character not found", 3)
            end
        end
    })

    MiscTeleportBox:AddButton({
        Text = 'Teleport to My Tycoon',
        Func = function()
            local tycoon = getMyTycoon()
            if not tycoon then Library:Notify("You don't own a tycoon yet", 3); return end
            local target = nil
            local essentials = tycoon:FindFirstChild("Essentials")
            if essentials then
                target = essentials:FindFirstChild("Spawn") or essentials:FindFirstChildWhichIsA("BasePart", true)
            end
            if not target then
                local entrance = tycoon:FindFirstChild("Entrance")
                target = entrance and entrance:FindFirstChildWhichIsA("BasePart", true)
            end
            local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if target and myHRP then
                myHRP.CFrame = target.CFrame + Vector3.new(0, 5, 0)
                Library:Notify("Teleported to your tycoon", 3)
            else
                Library:Notify("Could not find a teleport spot", 3)
            end
        end
    })

    -- ── Player ESP ──
    local ESP = {
        Enabled = false,
        ShowNames = true,
        FillColor = Color3.fromRGB(140, 60, 255),
        Thread = nil,
        Highlights = {},   -- [player] = Highlight
        Billboards = {},   -- [player] = BillboardGui
    }

    local function ESP_remove(plr)
        if ESP.Highlights[plr] then pcall(function() ESP.Highlights[plr]:Destroy() end); ESP.Highlights[plr] = nil end
        if ESP.Billboards[plr] then pcall(function() ESP.Billboards[plr]:Destroy() end); ESP.Billboards[plr] = nil end
    end

    local function ESP_clear()
        for plr in pairs(ESP.Highlights) do ESP_remove(plr) end
        for plr in pairs(ESP.Billboards) do ESP_remove(plr) end
    end

    local function ESP_update()
        local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == LP then continue end
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not (hrp and hum and hum.Health > 0) then
                ESP_remove(plr)
                continue
            end
            local hl = ESP.Highlights[plr]
            if not hl or not hl.Parent then
                hl = Instance.new("Highlight")
                hl.FillTransparency = 0.6
                hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = char
                ESP.Highlights[plr] = hl
            end
            hl.Adornee = char
            hl.FillColor = ESP.FillColor
            hl.OutlineColor = ESP.FillColor

            if ESP.ShowNames then
                local bb = ESP.Billboards[plr]
                local label
                if not bb or not bb.Parent then
                    bb = Instance.new("BillboardGui")
                    bb.Name = "GOATHUB_ESP"
                    bb.Size = UDim2.new(0, 200, 0, 40)
                    bb.StudsOffset = Vector3.new(0, 3.2, 0)
                    bb.AlwaysOnTop = true
                    label = Instance.new("TextLabel")
                    label.Name = "Label"
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 1
                    label.TextColor3 = Color3.new(1, 1, 1)
                    label.TextStrokeTransparency = 0.2
                    label.TextSize = 14
                    label.Font = Enum.Font.GothamBold
                    label.Parent = bb
                    bb.Adornee = hrp
                    bb.Parent = hrp
                    ESP.Billboards[plr] = bb
                else
                    label = bb:FindFirstChild("Label")
                end
                if label then
                    local dist = myHRP and math.floor((myHRP.Position - hrp.Position).Magnitude) or 0
                    label.Text = string.format("%s\n[%d HP] [%dm]", plr.Name, math.floor(hum.Health), dist)
                end
            elseif ESP.Billboards[plr] then
                pcall(function() ESP.Billboards[plr]:Destroy() end)
                ESP.Billboards[plr] = nil
            end
        end
    end

    Players.PlayerRemoving:Connect(ESP_remove)

    MiscEspBox:AddToggle('PlayerEspEnabled', {
        Text = 'Enable Player ESP',
        Default = false,
        Callback = function(state)
            ESP.Enabled = state
            if state then
                if ESP.Thread then task.cancel(ESP.Thread) end
                ESP.Thread = task.spawn(function()
                    while ESP.Enabled and not Library.Unloaded do
                        pcall(ESP_update)
                        task.wait(0.25)
                    end
                    ESP_clear()
                    ESP.Thread = nil
                end)
            end
        end
    }):AddColorPicker('PlayerEspColor', {
        Default = Color3.fromRGB(140, 60, 255),
        Title = 'ESP Color',
        Callback = function(color) ESP.FillColor = color end
    })

    local EspDepbox = MiscEspBox:AddDependencyBox()
    EspDepbox:AddToggle('PlayerEspNames', {
        Text = 'Show Name / HP / Distance',
        Default = true,
        Callback = function(state) ESP.ShowNames = state end
    })
    EspDepbox:SetupDependencies({ { Toggles.PlayerEspEnabled, true } })
end

do -- Quiz Event scope (separate scope to stay under Luau's 200-local limit)
    -- ── Quiz Event section ──
    -- NPC model names are NOT reliable (candidates can all be named
    -- AnswerTarget). The real tell is the kill sound: the correct NPC has a
    -- Sound named "Correct" inside its Head. Its Sign also holds the answer
    -- text, and the QuizMap question signs hold the current question.
    local MiscQuizBox = Tabs.Misc:AddRightGroupbox('Quiz Event')
    local Quiz = {
        Enabled = false,
        ShowWrong = true,
        ShowQuestion = true,
        Thread = nil,
        Marks = {},      -- [npcModel] = { correct = bool, objs = {...} }
        Notified = {},   -- [questionModel] = true
        Gui = nil,
        QuestionLabel = nil,
        AnswerLabel = nil,
    }

    function Quiz.isCorrectNPC(model)
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("Sound") and d.Name == "Correct" then return true end
        end
        return false
    end

    function Quiz.getAnswerText(model)
        local sign = model:FindFirstChild("Sign")
        local lbl = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
        if lbl and #lbl.Text > 0 then return lbl.Text end
        return model.Name
    end

    function Quiz.getQuestionText()
        local qm = workspace:FindFirstChild("QuizMap")
        local signs = qm and qm:FindFirstChild("QuestionSigns")
        if signs then
            for _, lbl in ipairs(signs:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Name == "Contents"
                    and lbl:FindFirstAncestor("QuestionPart") and #lbl.Text > 0 then
                    return lbl.Text
                end
            end
        end
        return nil
    end

    function Quiz.buildGui()
        local sg = Instance.new("ScreenGui")
        sg.Name = "GOATHUB_QuizHUD"
        sg.ResetOnSpawn = false
        pcall(function() sg.Parent = game:GetService("CoreGui") end)
        if not sg.Parent then sg.Parent = LP:FindFirstChildOfClass("PlayerGui") end
        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0)
        frame.Position = UDim2.new(0.5, 0, 0.04, 0)
        frame.Size = UDim2.new(0, 520, 0, 66)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        frame.BackgroundTransparency = 0.25
        frame.BorderSizePixel = 0
        frame.Parent = sg
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        local qLabel = Instance.new("TextLabel")
        qLabel.Size = UDim2.new(1, -12, 0, 32)
        qLabel.Position = UDim2.new(0, 6, 0, 2)
        qLabel.BackgroundTransparency = 1
        qLabel.TextColor3 = Color3.new(1, 1, 1)
        qLabel.TextStrokeTransparency = 0.4
        qLabel.TextSize = 16
        qLabel.Font = Enum.Font.GothamBold
        qLabel.TextWrapped = true
        qLabel.Parent = frame
        local aLabel = qLabel:Clone()
        aLabel.Position = UDim2.new(0, 6, 0, 32)
        aLabel.TextColor3 = Color3.fromRGB(0, 255, 60)
        aLabel.Parent = frame
        Quiz.Gui, Quiz.QuestionLabel, Quiz.AnswerLabel = sg, qLabel, aLabel
    end

    function Quiz.updateGui(questionText, answerText)
        if not (Quiz.ShowQuestion and Quiz.Enabled) then
            if Quiz.Gui then Quiz.Gui.Enabled = false end
            return
        end
        if not Quiz.Gui or not Quiz.Gui.Parent then Quiz.buildGui() end
        Quiz.Gui.Enabled = true
        Quiz.QuestionLabel.Text = questionText and ("QUESTION: " .. questionText) or "QUESTION: (waiting for quiz event)"
        Quiz.AnswerLabel.Text = answerText and ("ANSWER: " .. answerText .. "  — kill the green NPC") or "ANSWER: (NPCs not spawned yet)"
    end

    function Quiz.mark(model, correct)
        if Quiz.Marks[model] then return end
        local color = correct and Color3.fromRGB(0, 255, 60) or Color3.fromRGB(255, 40, 40)
        local hl = Instance.new("Highlight")
        hl.FillColor = color
        hl.OutlineColor = color
        hl.FillTransparency = correct and 0.35 or 0.8
        hl.OutlineTransparency = correct and 0 or 0.4
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = model
        hl.Parent = model
        local objs = { hl }
        local adornee = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChildWhichIsA("BasePart")
        if correct and adornee then
            local bb = Instance.new("BillboardGui")
            bb.Name = "GOATHUB_QuizMark"
            bb.Size = UDim2.new(0, 260, 0, 44)
            bb.StudsOffset = Vector3.new(0, 3.5, 0)
            bb.AlwaysOnTop = true
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(0, 255, 60)
            label.TextStrokeTransparency = 0.2
            label.TextSize = 18
            label.Font = Enum.Font.GothamBold
            label.Text = "✔ CORRECT — " .. Quiz.getAnswerText(model)
            label.Parent = bb
            bb.Adornee = adornee
            bb.Parent = adornee
            table.insert(objs, bb)
        end
        Quiz.Marks[model] = { correct = correct, objs = objs }
    end

    function Quiz.clear()
        for inst, mark in pairs(Quiz.Marks) do
            for _, o in ipairs(mark.objs) do pcall(function() o:Destroy() end) end
            Quiz.Marks[inst] = nil
        end
        if Quiz.Gui then pcall(function() Quiz.Gui:Destroy() end) end
        Quiz.Gui, Quiz.QuestionLabel, Quiz.AnswerLabel = nil, nil, nil
    end

    function Quiz.scan()
        local answerText = nil
        local quiz = workspace:FindFirstChild("TimedEvent_Quiz")
        if quiz then
            for _, q in ipairs(quiz:GetChildren()) do
                if q:IsA("Model") and q.Name:find("Question") then
                    for _, npc in ipairs(q:GetChildren()) do
                        if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
                            if Quiz.isCorrectNPC(npc) then
                                answerText = Quiz.getAnswerText(npc)
                                Quiz.mark(npc, true)
                                if not Quiz.Notified[q] then
                                    Quiz.Notified[q] = true
                                    Library:Notify("Quiz answer: " .. tostring(answerText), 5)
                                end
                            elseif Quiz.ShowWrong then
                                Quiz.mark(npc, false)
                            end
                        end
                    end
                end
            end
        end
        Quiz.updateGui(Quiz.getQuestionText(), answerText)
        -- Remove marks for despawned NPCs, or wrong-marks if that option was turned off
        for inst, mark in pairs(Quiz.Marks) do
            if not inst:IsDescendantOf(workspace) or (not mark.correct and not Quiz.ShowWrong) then
                for _, o in ipairs(mark.objs) do pcall(function() o:Destroy() end) end
                Quiz.Marks[inst] = nil
            end
        end
        for q in pairs(Quiz.Notified) do
            if not q.Parent then Quiz.Notified[q] = nil end
        end
    end

    MiscQuizBox:AddToggle('QuizShowAnswer', {
        Text = 'Show Correct NPC',
        Default = false,
        Tooltip = 'Detects the correct quiz NPC by its "Correct" kill sound and highlights it green',
        Callback = function(state)
            Quiz.Enabled = state
            if state then
                if Quiz.Thread then task.cancel(Quiz.Thread) end
                Quiz.Thread = task.spawn(function()
                    while Quiz.Enabled and not Library.Unloaded do
                        pcall(Quiz.scan)
                        task.wait(0.5)
                    end
                    Quiz.clear()
                    Quiz.Thread = nil
                end)
            end
        end
    })

    MiscQuizBox:AddToggle('QuizShowQuestion', {
        Text = 'Display Question On Screen',
        Default = true,
        Tooltip = 'Shows the current question and answer at the top of your screen',
        Callback = function(state) Quiz.ShowQuestion = state end
    })

    MiscQuizBox:AddToggle('QuizShowWrong', {
        Text = 'Mark Wrong NPCs Red',
        Default = true,
        Callback = function(state) Quiz.ShowWrong = state end
    })

    MiscQuizBox:AddButton({
        Text = 'Teleport to Quiz Area',
        Func = function()
            local qm = workspace:FindFirstChild("QuizMap")
            local tp = qm and qm:FindFirstChild("TPPart")
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if tp and hrp then
                hrp.CFrame = tp.CFrame + Vector3.new(0, 4, 0)
                Library:Notify("Teleported to quiz area", 3)
            else
                Library:Notify("Quiz area not found", 3)
            end
        end
    })

    -- Auto Farm Quiz (kill correct NPC and collect scroll)
    local QuizFarm = { Enabled = false, Thread = nil }

    local function QuizFarm_getCorrectNPC()
        local quiz = workspace:FindFirstChild("TimedEvent_Quiz")
        if not quiz then return nil end
        for _, q in ipairs(quiz:GetChildren()) do
            if q:IsA("Model") and q.Name:find("Question") then
                for _, npc in ipairs(q:GetChildren()) do
                    if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
                        if Quiz.isCorrectNPC(npc) then return npc end
                    end
                end
            end
        end
        return nil
    end

    local function QuizFarm_killNPC(npc)
        -- Kill by setting Humanoid.Health to 0
        local hum = npc:FindFirstChildOfClass("Humanoid")
        if not hum then return false end

        pcall(function()
            hum.Health = 0
        end)

        -- Verify the NPC is dead
        task.wait(0.2)
        return hum.Health <= 0
    end

    local function QuizFarm_collectScroll(npcPos)
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        -- Wait a moment for Ryo scroll to spawn (drops at NPC death position)
        task.wait(0.5)
        -- Look for Ryo scroll dropped from the kill
        -- Ryo scrolls: EScroll, SScroll, AScroll, BScroll, etc. (NOT CashScroll)
        for attempt = 1, 30 do
            for _, obj in ipairs(workspace:GetChildren()) do
                -- Same logic as Auto Pick Up Ryo: scroll name + PP proximity prompt, no distance limit
                -- (scrolls can physics-settle well past 50 studs from the death position)
                if obj.Name:find("Scroll") and obj.Name ~= "CashScroll" then
                    local pp = obj:FindFirstChild("PP")
                    if pp and pp:IsA("ProximityPrompt") and pp.Enabled then
                        if obj:IsA("BasePart") then
                            -- Teleport to scroll and pick it up
                            pcall(function() hrp.CFrame = obj.CFrame + Vector3.new(0, 2, 0) end)
                            task.wait(0.15)
                            pcall(function() fireproximityprompt(pp) end)
                            Library:Notify("Collected Ryo scroll: " .. obj.Name, 3)
                            return true -- Successfully collected
                        end
                    end
                end
            end
            task.wait(0.3)
        end
        Library:Notify("Ryo scroll not found after kill (waited 9s)", 3)
        return false -- Failed to find scroll
    end

    local function QuizFarm_run()
        while QuizFarm.Enabled do
            local npc = QuizFarm_getCorrectNPC()
            if npc then
                -- Double-check this is still the correct NPC before killing
                if not Quiz.isCorrectNPC(npc) then
                    task.wait(0.5)
                    continue
                end

                local npcPos = npc:FindFirstChild("HumanoidRootPart")
                    and npc.HumanoidRootPart.Position
                    or (npc:FindFirstChild("Torso") and npc.Torso.Position)
                    or npc:GetPivot().Position
                local answerName = Quiz.getAnswerText(npc)
                Library:Notify("Killing correct quiz NPC: " .. answerName, 4)

                local killed = QuizFarm_killNPC(npc)
                if killed then
                    local collected = QuizFarm_collectScroll(npcPos)
                    if collected then
                        -- Successfully killed and collected, wait for next question
                        task.wait(2)
                    else
                        -- Killed but didn't find scroll, shorter wait before retry
                        task.wait(1)
                    end
                else
                    Library:Notify("Failed to kill NPC, retrying...", 3)
                    task.wait(1)
                end
            else
                task.wait(1) -- wait for next question to spawn
            end
        end
    end

    MiscQuizBox:AddToggle('QuizAutoFarm', {
        Text = 'Auto Farm Quiz',
        Default = false,
        Tooltip = 'Automatically kills the correct NPC and collects the Ryo scroll',
        Callback = function(state)
            QuizFarm.Enabled = state
            if state then
                if QuizFarm.Thread then task.cancel(QuizFarm.Thread) end
                QuizFarm.Thread = task.spawn(function()
                    pcall(QuizFarm_run)
                    QuizFarm.Thread = nil
                end)
            elseif QuizFarm.Thread then
                task.cancel(QuizFarm.Thread)
                QuizFarm.Thread = nil
            end
        end
    })

end

do -- Misc Utility scope
    local MiscUtilityBox = Tabs.Misc:AddRightGroupbox('Utility')

    -- ── Utility ──
    local antiAfkConn = nil
    MiscUtilityBox:AddToggle('AntiAFK', {
        Text = 'Anti-AFK',
        Default = false,
        Tooltip = 'Prevents the 20 minute idle kick',
        Callback = function(state)
            if state then
                if antiAfkConn then antiAfkConn:Disconnect() end
                antiAfkConn = LP.Idled:Connect(function()
                    local vu = game:GetService("VirtualUser")
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new())
                end)
            elseif antiAfkConn then
                antiAfkConn:Disconnect()
                antiAfkConn = nil
            end
        end
    })

    MiscUtilityBox:AddButton({
        Text = 'Rejoin Server',
        Func = function()
            local ts = game:GetService("TeleportService")
            if #Players:GetPlayers() <= 1 then
                pcall(function() ts:Teleport(game.PlaceId, LP) end)
            else
                pcall(function() ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
            end
        end
    })

    MiscUtilityBox:AddButton({
        Text = 'Server Hop',
        Func = function()
            Library:Notify("Searching for a server...", 3)
            task.spawn(function()
                local ts = game:GetService("TeleportService")
                local cursor = ""
                for _ = 1, 5 do
                    local url = string.format(
                        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&excludeFullGames=true&limit=100%s",
                        game.PlaceId, cursor ~= "" and ("&cursor=" .. cursor) or "")
                    local body = httpGet(url)
                    if not body then break end
                    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
                    if not ok or not data or not data.data then break end
                    for _, srv in ipairs(data.data) do
                        if srv.id ~= game.JobId and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
                            pcall(function() ts:TeleportToPlaceInstance(game.PlaceId, srv.id, LP) end)
                            return
                        end
                    end
                    cursor = data.nextPageCursor or ""
                    if cursor == "" then break end
                end
                Library:Notify("No suitable server found", 4)
            end)
        end
    })

    MiscUtilityBox:AddButton({
        Text = 'Copy Job ID',
        Func = function()
            if type(setclipboard) == "function" then
                setclipboard(game.JobId)
                Library:Notify("Job ID copied", 3)
            else
                Library:Notify("Executor lacks setclipboard", 3)
            end
        end
    })
end

-- ===================== WORLD CUSTOMIZATION =====================
do
    -- Boxes are kept in one table (instead of ~10 separate locals) so they only
    -- cost a single register against Luau's 200 file-scope local limit while
    -- still being created in this exact order (left/right stacking order is
    -- determined by call order, not by how the reference is stored).
    -- Skybox/Weather/Ambience and Bloom/Sun Ray are combined into tabboxes
    -- (each Tabbox:AddTab result behaves just like a groupbox for Add* calls).
    local WorldBoxes = {}

    do
        local ColorCorrectionAtmosphereBox = Tabs.World:AddLeftTabbox()
        WorldBoxes.ColorCorrection = ColorCorrectionAtmosphereBox:AddTab('Color Correction')
        WorldBoxes.Atmosphere = ColorCorrectionAtmosphereBox:AddTab('Atmosphere')
    end

    WorldBoxes.Lighting = Tabs.World:AddLeftGroupbox('Lighting & Sky')
    WorldBoxes.Nature = Tabs.World:AddLeftGroupbox('Nature')

    do
        local SkyWeatherAmbienceBox = Tabs.World:AddRightTabbox()
        WorldBoxes.Skybox = SkyWeatherAmbienceBox:AddTab('Skybox')
        WorldBoxes.Weather = SkyWeatherAmbienceBox:AddTab('Weather')
        WorldBoxes.Ambience = SkyWeatherAmbienceBox:AddTab('Ambience')
    end

    do
        local BloomSunRaysBox = Tabs.World:AddRightTabbox()
        WorldBoxes.Bloom = BloomSunRaysBox:AddTab('Bloom')
        WorldBoxes.SunRays = BloomSunRaysBox:AddTab('Sun Ray')
    end

    WorldBoxes.Terrain = Tabs.World:AddRightGroupbox('Terrain')
    WorldBoxes.Misc = Tabs.World:AddRightGroupbox('Misc')

    local Lighting = game:GetService("Lighting")

    -- Store original values to prevent auto-changes
    local OriginalValues = {
        ClockTime = Lighting.ClockTime,
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top = Lighting.ColorShift_Top,
        FogEnd = Lighting.FogEnd,
        FogColor = Lighting.FogColor,
        FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
        Technology = Lighting.Technology
    }

    -- Flag: prevent callbacks from firing during UI creation
    local _worldReady = false

    -- ═══════════════════ SKYBOX ═══════════════════
    -- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
    do
    local SkyboxPresets = {
        ['Purple Nebula Sky'] = {
            Bk = "rbxassetid://159454299", Dn = "rbxassetid://159454296", Ft = "rbxassetid://159454293",
            Lf = "rbxassetid://159454286", Rt = "rbxassetid://159454300", Up = "rbxassetid://159454288",
        },
        ['Red Sunset Sky'] = {
            Bk = "rbxassetid://150939022", Dn = "rbxassetid://150939038", Ft = "rbxassetid://150939047",
            Lf = "rbxassetid://150939056", Rt = "rbxassetid://150939063", Up = "rbxassetid://150939082",
        },
        ['Night Sky'] = {
            Bk = "rbxassetid://12064107", Dn = "rbxassetid://12064152", Ft = "rbxassetid://12064121",
            Lf = "rbxassetid://12063984", Rt = "rbxassetid://12064115", Up = "rbxassetid://12064131",
            ClockTime = 0,
        },
    }

    local selectedSkybox = 'Purple Nebula Sky'

    local function applySkybox(name)
        local preset = SkyboxPresets[name]
        if not preset then return end
        local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky", Lighting)
        sky.SkyboxBk = preset.Bk
        sky.SkyboxDn = preset.Dn
        sky.SkyboxFt = preset.Ft
        sky.SkyboxLf = preset.Lf
        sky.SkyboxRt = preset.Rt
        sky.SkyboxUp = preset.Up
        if preset.ClockTime then Lighting.ClockTime = preset.ClockTime end
        Library:Notify("Applied " .. name, 3)
    end

    WorldBoxes.Skybox:AddToggle('WorldSkyboxEnabled', {
        Text = 'Custom Skybox',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if state then
                applySkybox(selectedSkybox)
            else
                local sky = Lighting:FindFirstChildOfClass("Sky")
                if sky then
                    sky:Destroy()
                    Library:Notify("Removed skybox", 3)
                end
            end
        end
    })

    WorldBoxes.Skybox:AddDropdown('WorldSkyboxPreset', {
        Values = { 'Purple Nebula Sky', 'Red Sunset Sky', 'Night Sky' },
        Default = 1,
        Multi = false,
        Text = 'Skybox Preset',
        Callback = function(v)
            selectedSkybox = v
            if not _worldReady then return end
            if Toggles.WorldSkyboxEnabled and Toggles.WorldSkyboxEnabled.Value then
                applySkybox(v)
            end
        end
    })
    end -- Skybox scope

    -- ═══════════════════ COLOR CORRECTION ═══════════════════
    -- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
    do
    local function getColorCorrection()
        return Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    end

    WorldBoxes.ColorCorrection:AddToggle('WorldColorCorrection', {
        Text = 'Color Correction',
        Default = false,
        Callback = function(state)
            local cc = getColorCorrection()
            if state then
                if not cc then
                    cc = Instance.new("ColorCorrectionEffect", Lighting)
                    cc.Brightness = 0
                    cc.Contrast = 0.1
                    cc.Saturation = 0.2
                    cc.TintColor = Color3.fromRGB(255, 255, 255)
                end
                cc.Enabled = true
            elseif cc then
                cc.Enabled = false
            end
        end
    }):AddColorPicker('WorldColorCorrectionTint', {
        Default = Color3.fromRGB(255, 255, 255),
        Title = 'Tint Color',
        Callback = function(color)
            if Toggles.WorldColorCorrection and Toggles.WorldColorCorrection.Value then
                local cc = getColorCorrection()
                if cc then cc.TintColor = color end
            end
        end
    })

    local ColorCorrectionDepbox = WorldBoxes.ColorCorrection:AddDependencyBox()

    ColorCorrectionDepbox:AddSlider('WorldColorCorrectionBrightness', {
        Text = 'Brightness',
        Default = 0,
        Min = -1,
        Max = 1,
        Rounding = 2,
        Callback = function(v)
            local cc = getColorCorrection()
            if cc then cc.Brightness = v end
        end
    })

    ColorCorrectionDepbox:AddSlider('WorldColorCorrectionContrast', {
        Text = 'Contrast',
        Default = 0.1,
        Min = -1,
        Max = 1,
        Rounding = 2,
        Callback = function(v)
            local cc = getColorCorrection()
            if cc then cc.Contrast = v end
        end
    })

    ColorCorrectionDepbox:AddSlider('WorldColorCorrectionSaturation', {
        Text = 'Saturation',
        Default = 0.2,
        Min = -1,
        Max = 1,
        Rounding = 2,
        Callback = function(v)
            local cc = getColorCorrection()
            if cc then cc.Saturation = v end
        end
    })

    ColorCorrectionDepbox:SetupDependencies({ { Toggles.WorldColorCorrection, true } })
    end -- Color Correction scope

    -- ═══════════════════ AMBIENCE ═══════════════════

    WorldBoxes.Ambience:AddToggle('WorldFullbright', {
        Text = 'Fullbright',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if state then
                pcall(function()
                    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                    Lighting.Brightness = 5
                    Lighting.FogEnd = 100000
                end)
            else
                pcall(function()
                    Lighting.Ambient = OriginalValues.Ambient
                    Lighting.OutdoorAmbient = OriginalValues.OutdoorAmbient
                    Lighting.Brightness = OriginalValues.Brightness
                    Lighting.FogEnd = OriginalValues.FogEnd
                end)
            end
        end
    })

    WorldBoxes.Ambience:AddToggle('WorldRemoveShadows', {
        Text = 'Remove Shadows',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            pcall(function() Lighting.GlobalShadows = not state end)
        end
    })

    -- ═══════════════════ SUN RAYS ═══════════════════

    WorldBoxes.SunRays:AddToggle('WorldSunRays', {
        Text = 'Sun Rays',
        Default = false,
        Callback = function(state)
            local sunrays = Lighting:FindFirstChildOfClass("SunRaysEffect")
            if state then
                if not sunrays then
                    sunrays = Instance.new("SunRaysEffect", Lighting)
                    sunrays.Intensity = 0.25
                    sunrays.Spread = 1
                end
                sunrays.Enabled = true
            elseif sunrays then
                sunrays.Enabled = false
            end
        end
    })

    -- ═══════════════════ ATMOSPHERE ═══════════════════

    WorldBoxes.Atmosphere:AddToggle('WorldAtmosphere', {
        Text = 'Enhanced Atmosphere',
        Default = false,
        Callback = function(state)
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if state then
                if not atm then
                    atm = Instance.new("Atmosphere", Lighting)
                end
                atm.Density = 0.5
                atm.Offset = 0.5
                atm.Color = Color3.fromRGB(199, 199, 199)
                atm.Decay = Color3.fromRGB(106, 112, 125)
                atm.Glare = 0.4
                atm.Haze = 1.5
            elseif atm then
                atm.Density = 0
                atm.Offset = 0
            end
        end
    })

    -- ═══════════════════ LIGHTING & SKY ═══════════════════

    WorldBoxes.Lighting:AddLabel('Ambient & Color')

    WorldBoxes.Lighting:AddToggle('WorldCustomAmbient', {
        Text = 'Override Ambient',
        Default = false,
        Callback = function(state)
            if not state then
                pcall(function() Lighting.Ambient = OriginalValues.Ambient end)
            end
        end
    }):AddColorPicker('WorldAmbient', {
        Default = OriginalValues.Ambient,
        Title = 'Indoor Ambient',
        Callback = function(color)
            if Toggles.WorldCustomAmbient and Toggles.WorldCustomAmbient.Value then
                pcall(function() Lighting.Ambient = color end)
            end
        end
    })

    WorldBoxes.Lighting:AddToggle('WorldCustomOutdoorAmbient', {
        Text = 'Override Outdoor Ambient',
        Default = false,
        Callback = function(state)
            if not state then
                pcall(function() Lighting.OutdoorAmbient = OriginalValues.OutdoorAmbient end)
            end
        end
    }):AddColorPicker('WorldOutdoorAmbient', {
        Default = OriginalValues.OutdoorAmbient,
        Title = 'Outdoor Ambient',
        Callback = function(color)
            if Toggles.WorldCustomOutdoorAmbient and Toggles.WorldCustomOutdoorAmbient.Value then
                pcall(function() Lighting.OutdoorAmbient = color end)
            end
        end
    })

    WorldBoxes.Lighting:AddToggle('WorldColorShiftBottom', {
        Text = 'Override Color Shift (Bottom)',
        Default = false,
        Callback = function(state)
            if not state then
                pcall(function() Lighting.ColorShift_Bottom = OriginalValues.ColorShift_Bottom end)
            end
        end
    }):AddColorPicker('WorldColorShiftBottomColor', {
        Default = OriginalValues.ColorShift_Bottom,
        Title = 'Color Shift Bottom',
        Callback = function(color)
            if Toggles.WorldColorShiftBottom and Toggles.WorldColorShiftBottom.Value then
                pcall(function() Lighting.ColorShift_Bottom = color end)
            end
        end
    })

    WorldBoxes.Lighting:AddToggle('WorldColorShiftTop', {
        Text = 'Override Color Shift (Top)',
        Default = false,
        Callback = function(state)
            if not state then
                pcall(function() Lighting.ColorShift_Top = OriginalValues.ColorShift_Top end)
            end
        end
    }):AddColorPicker('WorldColorShiftTopColor', {
        Default = OriginalValues.ColorShift_Top,
        Title = 'Color Shift Top',
        Callback = function(color)
            if Toggles.WorldColorShiftTop and Toggles.WorldColorShiftTop.Value then
                pcall(function() Lighting.ColorShift_Top = color end)
            end
        end
    })

    WorldBoxes.Lighting:AddToggle('WorldCustomFogColor', {
        Text = 'Override Fog Color',
        Default = false,
        Callback = function(state)
            if not state then
                pcall(function() Lighting.FogColor = OriginalValues.FogColor end)
            end
        end
    }):AddColorPicker('WorldFogColor', {
        Default = OriginalValues.FogColor,
        Title = 'Fog Color',
        Callback = function(color)
            if Toggles.WorldCustomFogColor and Toggles.WorldCustomFogColor.Value then
                pcall(function() Lighting.FogColor = color end)
            end
        end
    })

    WorldBoxes.Lighting:AddLabel('Custom Lighting')

    -- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
    do
    WorldBoxes.Lighting:AddToggle('WorldCustomFogEnd', {
        Text = 'Fog Distance',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if not state then
                pcall(function() Lighting.FogEnd = OriginalValues.FogEnd end)
            end
        end
    })
    local FogEndDepbox = WorldBoxes.Lighting:AddDependencyBox()
    FogEndDepbox:AddSlider('WorldFogEnd', {
        Text = 'Fog Distance',
        Default = OriginalValues.FogEnd,
        Min = 100,
        Max = 10000,
        Rounding = 0,
        Callback = function(v)
            if not _worldReady then return end
            pcall(function() Lighting.FogEnd = v end)
        end
    })
    FogEndDepbox:SetupDependencies({ { Toggles.WorldCustomFogEnd, true } })

    WorldBoxes.Lighting:AddToggle('WorldCustomFogStart', {
        Text = 'Fog Start',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if not state then
                pcall(function() Lighting.FogStart = OriginalValues.FogStart end)
            end
        end
    })
    local FogStartDepbox = WorldBoxes.Lighting:AddDependencyBox()
    FogStartDepbox:AddSlider('WorldFogStart', {
        Text = 'Fog Start',
        Default = OriginalValues.FogStart,
        Min = 0,
        Max = 5000,
        Rounding = 0,
        Callback = function(v)
            if not _worldReady then return end
            pcall(function() Lighting.FogStart = v end)
        end
    })
    FogStartDepbox:SetupDependencies({ { Toggles.WorldCustomFogStart, true } })

    WorldBoxes.Lighting:AddToggle('WorldCustomBrightness', {
        Text = 'Brightness',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if not state then
                pcall(function() Lighting.Brightness = OriginalValues.Brightness end)
            end
        end
    })
    local BrightnessDepbox = WorldBoxes.Lighting:AddDependencyBox()
    BrightnessDepbox:AddSlider('WorldBrightness', {
        Text = 'Brightness',
        Default = OriginalValues.Brightness,
        Min = 0,
        Max = 5,
        Rounding = 1,
        Callback = function(v)
            if not _worldReady then return end
            pcall(function() Lighting.Brightness = v end)
        end
    })
    BrightnessDepbox:SetupDependencies({ { Toggles.WorldCustomBrightness, true } })

    WorldBoxes.Lighting:AddToggle('WorldCustomTimeOfDay', {
        Text = 'Time of Day',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if not state then
                pcall(function() Lighting.ClockTime = OriginalValues.ClockTime end)
            end
        end
    })
    local TimeOfDayDepbox = WorldBoxes.Lighting:AddDependencyBox()
    TimeOfDayDepbox:AddSlider('WorldTimeOfDay', {
        Text = 'Time of Day',
        Default = OriginalValues.ClockTime,
        Min = 0,
        Max = 24,
        Rounding = 1,
        Callback = function(v)
            if not _worldReady then return end
            pcall(function() Lighting.ClockTime = v end)
        end
    })
    TimeOfDayDepbox:SetupDependencies({ { Toggles.WorldCustomTimeOfDay, true } })

    WorldBoxes.Lighting:AddToggle('WorldCustomShadowTechnology', {
        Text = 'Shadow Technology',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if not state then
                pcall(function() Lighting.Technology = OriginalValues.Technology end)
            end
        end
    })
    local ShadowTechDepbox = WorldBoxes.Lighting:AddDependencyBox()
    ShadowTechDepbox:AddDropdown('WorldShadowTechnology', {
        Values = { 'Voxel', 'Compatibility', 'ShadowMap', 'Future' },
        Default = 4,
        Multi = false,
        Text = 'Shadow Technology',
        Callback = function(v)
            if not _worldReady then return end
            pcall(function() Lighting.Technology = Enum.Technology[v] end)
        end
    })
    ShadowTechDepbox:SetupDependencies({ { Toggles.WorldCustomShadowTechnology, true } })
    end -- Custom Lighting scope

    WorldBoxes.Lighting:AddToggle('WorldRemoveFog', {
        Text = 'Remove Fog Completely',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if state then
                pcall(function() Lighting.FogEnd = 100000 end)
            else
                pcall(function() Lighting.FogEnd = OriginalValues.FogEnd end)
            end
        end
    })

    -- ═══════════════════ NATURE (TREES) ═══════════════════

    WorldBoxes.Nature:AddLabel('Tree Colors')

    WorldBoxes.Nature:AddToggle('WorldCustomTreeLeaves', {
        Text = 'Override Leaves Color',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if not state then
                -- Reset to default green
                task.spawn(function()
                    local map = workspace:FindFirstChild("Map")
                    local trees = map and map:FindFirstChild("Team Trees")
                    if trees then
                        for _, tree in ipairs(trees:GetChildren()) do
                            if tree:IsA("Model") then
                                for _, part in ipairs(tree:GetChildren()) do
                                    if part:IsA("UnionOperation") and part.Name == "Union" then
                                        pcall(function() part.Color = Color3.fromRGB(170, 255, 127) end)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    }):AddColorPicker('WorldTreeLeaves', {
        Default = Color3.fromRGB(170, 255, 127),
        Title = 'Tree Leaves Color',
        Callback = function(color)
            if Toggles.WorldCustomTreeLeaves and Toggles.WorldCustomTreeLeaves.Value then
                task.spawn(function()
                    local map = workspace:FindFirstChild("Map")
                    local trees = map and map:FindFirstChild("Team Trees")
                    if trees then
                        for _, tree in ipairs(trees:GetChildren()) do
                            if tree:IsA("Model") then
                                for _, part in ipairs(tree:GetChildren()) do
                                    if part:IsA("UnionOperation") and part.Name == "Union" then
                                        pcall(function() part.Color = color end)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    })

    WorldBoxes.Nature:AddToggle('WorldCustomTreeTrunk', {
        Text = 'Override Trunk Color',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if not state then
                -- Reset to default brown
                task.spawn(function()
                    local map = workspace:FindFirstChild("Map")
                    local trees = map and map:FindFirstChild("Team Trees")
                    if trees then
                        for _, tree in ipairs(trees:GetChildren()) do
                            if tree:IsA("Model") then
                                for _, part in ipairs(tree:GetChildren()) do
                                    if part:IsA("BasePart") and part.Name == "Part" then
                                        pcall(function() part.Color = Color3.fromRGB(108, 88, 75) end)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    }):AddColorPicker('WorldTreeTrunk', {
        Default = Color3.fromRGB(108, 88, 75),
        Title = 'Tree Trunk Color',
        Callback = function(color)
            if Toggles.WorldCustomTreeTrunk and Toggles.WorldCustomTreeTrunk.Value then
                task.spawn(function()
                    local map = workspace:FindFirstChild("Map")
                    local trees = map and map:FindFirstChild("Team Trees")
                    if trees then
                        for _, tree in ipairs(trees:GetChildren()) do
                            if tree:IsA("Model") then
                                for _, part in ipairs(tree:GetChildren()) do
                                    if part:IsA("BasePart") and part.Name == "Part" then
                                        pcall(function() part.Color = color end)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    })

    WorldBoxes.Nature:AddSlider('WorldTreeSize', {
        Text = 'Tree Scale',
        Default = 1,
        Min = 0.1,
        Max = 3,
        Rounding = 1,
        Callback = function(v)
            if not _worldReady then return end
            task.spawn(function()
                local map = workspace:FindFirstChild("Map")
                local trees = map and map:FindFirstChild("Team Trees")
                if trees then
                    for _, tree in ipairs(trees:GetChildren()) do
                        if tree:IsA("Model") then
                            pcall(function()
                                local pivot = tree:GetPivot()
                                tree:ScaleTo(v)
                                tree:PivotTo(pivot)
                            end)
                        end
                    end
                end
            end)
        end
    })

    WorldBoxes.Nature:AddToggle('WorldRemoveTrees', {
        Text = 'Hide All Trees',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            local map = workspace:FindFirstChild("Map")
            local trees = map and map:FindFirstChild("Team Trees")
            if trees then
                pcall(function()
                    for _, tree in ipairs(trees:GetChildren()) do
                        if tree:IsA("Model") then
                            for _, part in ipairs(tree:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.Transparency = state and 1 or 0
                                end
                            end
                        end
                    end
                end)
            end
        end
    })

    -- ═══════════════════ TERRAIN ═══════════════════

    WorldBoxes.Terrain:AddLabel('Ground & Walls')

    WorldBoxes.Terrain:AddToggle('WorldCustomBaseplate', {
        Text = 'Override Baseplate',
        Default = false,
        Callback = function(state) end
    }):AddColorPicker('WorldBaseplate', {
        Default = Color3.fromRGB(128, 128, 128),
        Title = 'Baseplate Color',
        Callback = function(color)
            if Toggles.WorldCustomBaseplate and Toggles.WorldCustomBaseplate.Value then
                local map = workspace:FindFirstChild("Map")
                local baseplate = map and map:FindFirstChild("Baseplate")
                if baseplate and baseplate:IsA("BasePart") then
                    pcall(function() baseplate.Color = color end)
                end
            end
        end
    })

    WorldBoxes.Terrain:AddToggle('WorldCustomWalls', {
        Text = 'Override Walls',
        Default = false,
        Callback = function(state) end
    }):AddColorPicker('WorldWalls', {
        Default = Color3.fromRGB(163, 162, 165),
        Title = 'Wall Color',
        Callback = function(color)
            if Toggles.WorldCustomWalls and Toggles.WorldCustomWalls.Value then
                task.spawn(function()
                    local map = workspace:FindFirstChild("Map")
                    local walls = map and map:FindFirstChild("Wall")
                    if walls then
                        for _, wall in ipairs(walls:GetChildren()) do
                            if wall:IsA("BasePart") then
                                pcall(function() wall.Color = color end)
                            end
                        end
                    end
                end)
            end
        end
    })

    WorldBoxes.Terrain:AddToggle('WorldCustomRocks', {
        Text = 'Override Rocks',
        Default = false,
        Callback = function(state) end
    }):AddColorPicker('WorldRocks', {
        Default = Color3.fromRGB(163, 162, 165),
        Title = 'Rock Color',
        Callback = function(color)
            if Toggles.WorldCustomRocks and Toggles.WorldCustomRocks.Value then
                task.spawn(function()
                    local map = workspace:FindFirstChild("Map")
                    local rocks = map and map:FindFirstChild("Rocks")
                    if rocks then
                        for _, rock in ipairs(rocks:GetChildren()) do
                            if rock:IsA("BasePart") then
                                pcall(function() rock.Color = color end)
                            end
                        end
                    end
                end)
            end
        end
    })

    WorldBoxes.Terrain:AddToggle('WorldRemoveWalls', {
        Text = 'Hide Walls',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            local map = workspace:FindFirstChild("Map")
            local walls = map and map:FindFirstChild("Wall")
            if walls then
                for _, wall in ipairs(walls:GetChildren()) do
                    if wall:IsA("BasePart") then
                        pcall(function() wall.Transparency = state and 1 or 0 end)
                    end
                end
            end
        end
    })

    -- ═══════════════════ MISC ═══════════════════


    WorldBoxes.Misc:AddLabel('Post-Processing Effects')

    WorldBoxes.Misc:AddToggle('WorldBlur', {
        Text = 'Blur Effect',
        Default = false,
        Callback = function(state)
            local blur = Lighting:FindFirstChildOfClass("BlurEffect")
            if state then
                if not blur then
                    blur = Instance.new("BlurEffect", Lighting)
                    blur.Size = 10
                end
                blur.Enabled = true
            elseif blur then
                blur.Enabled = false
            end
        end
    })

    local BlurDepbox = WorldBoxes.Misc:AddDependencyBox()
    BlurDepbox:AddSlider('WorldBlurSize', {
        Text = 'Blur Intensity',
        Default = 10,
        Min = 0,
        Max = 56,
        Rounding = 0,
        Callback = function(v)
            local blur = Lighting:FindFirstChildOfClass("BlurEffect")
            if blur then blur.Size = v end
        end
    })
    BlurDepbox:SetupDependencies({ { Toggles.WorldBlur, true } })

    WorldBoxes.Bloom:AddToggle('WorldBloom', {
        Text = 'Bloom Effect',
        Default = false,
        Callback = function(state)
            local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
            if state then
                if not bloom then
                    bloom = Instance.new("BloomEffect", Lighting)
                    bloom.Intensity = 0.5
                    bloom.Size = 24
                    bloom.Threshold = 0.8
                end
                bloom.Enabled = true
            elseif bloom then
                bloom.Enabled = false
            end
        end
    })

    WorldBoxes.Misc:AddToggle('WorldDepthOfField', {
        Text = 'Depth of Field',
        Default = false,
        Callback = function(state)
            local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
            if state then
                if not dof then
                    dof = Instance.new("DepthOfFieldEffect", Lighting)
                    dof.FarIntensity = 0.3
                    dof.FocusDistance = 50
                    dof.InFocusRadius = 30
                    dof.NearIntensity = 0.5
                end
                dof.Enabled = true
            elseif dof then
                dof.Enabled = false
            end
        end
    })

    WorldBoxes.Misc:AddButton({
        Text = 'Remove All Effects',
        Func = function()
            for _, effect in ipairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") or effect:IsA("BlurEffect") or effect:IsA("Atmosphere") then
                    pcall(function() effect:Destroy() end)
                end
            end
            Library:Notify("Removed all post-processing effects", 3)
        end
    })

    WorldBoxes.Misc:AddButton({
        Text = 'Reset All World Settings',
        Func = function()
            -- Reset lighting to original values
            pcall(function()
                Lighting.Ambient = OriginalValues.Ambient
                Lighting.OutdoorAmbient = OriginalValues.OutdoorAmbient
                Lighting.Brightness = OriginalValues.Brightness
                Lighting.ClockTime = OriginalValues.ClockTime
                Lighting.FogEnd = OriginalValues.FogEnd
                Lighting.FogColor = OriginalValues.FogColor
                Lighting.GlobalShadows = OriginalValues.GlobalShadows
            end)
            -- Remove effects
            for _, effect in ipairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") or effect:IsA("BlurEffect") or effect:IsA("Atmosphere") then
                    pcall(function() effect:Destroy() end)
                end
            end
            Library:Notify("Reset world settings to original", 4)
        end
    })

    -- ═══════════════════ TIME PRESETS ═══════════════════
    WorldBoxes.Lighting:AddLabel('Time Presets')

    do
    local TimePresets = { Noon = 12, Midnight = 0, Sunset = 17.5 }
    local selectedTimePreset = 'Noon'

    WorldBoxes.Lighting:AddToggle('WorldTimePresetEnabled', {
        Text = 'Custom Time Preset',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if state then
                local t = TimePresets[selectedTimePreset]
                if t then
                    pcall(function() Lighting.ClockTime = t end)
                    Library:Notify("Set time to " .. selectedTimePreset, 2)
                end
            else
                pcall(function() Lighting.ClockTime = OriginalValues.ClockTime end)
                Library:Notify("Restored original time", 2)
            end
        end
    })

    WorldBoxes.Lighting:AddDropdown('WorldTimePreset', {
        Values = { 'Noon', 'Midnight', 'Sunset' },
        Default = 1,
        Multi = false,
        Text = 'Time Preset',
        Callback = function(v)
            selectedTimePreset = v
            if not _worldReady then return end
            if Toggles.WorldTimePresetEnabled and Toggles.WorldTimePresetEnabled.Value then
                local t = TimePresets[v]
                if t then
                    pcall(function() Lighting.ClockTime = t end)
                    Library:Notify("Set time to " .. v, 2)
                end
            end
        end
    })
    end -- Time Presets scope

    -- ═══════════════════ MATERIAL OVERRIDE ═══════════════════
    WorldBoxes.Terrain:AddLabel('Material Override')

    do
    local function applyMapMaterial(matName)
        local mat = Enum.Material[matName]
        if not mat then return end
        local map = workspace:FindFirstChild("Map")
        if map then
            for _, obj in ipairs(map:GetDescendants()) do
                if obj:IsA("BasePart") then
                    pcall(function() obj.Material = mat end)
                end
            end
        end
        Library:Notify("Applied " .. matName .. " material to map", 2)
    end

    local function resetMapMaterial()
        local map = workspace:FindFirstChild("Map")
        if map then
            for _, obj in ipairs(map:GetDescendants()) do
                if obj:IsA("BasePart") then
                    pcall(function() obj.Material = Enum.Material.SmoothPlastic end)
                end
            end
        end
    end

    WorldBoxes.Terrain:AddToggle('WorldApplyMaterial', {
        Text = 'Override Map Material',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if state then
                local matName = Options.WorldMaterialOverride and Options.WorldMaterialOverride.Value
                if matName then applyMapMaterial(matName) end
            else
                resetMapMaterial()
            end
        end
    })

    local MaterialDepbox = WorldBoxes.Terrain:AddDependencyBox()
    MaterialDepbox:AddDropdown('WorldMaterialOverride', {
        Text = 'Map Material',
        Values = {'SmoothPlastic', 'Wood', 'Slate', 'Grass', 'Cobblestone', 'Sand', 'Marble', 'Neon', 'Glass', 'DiamondPlate', 'Metal', 'Brick', 'Granite', 'CorrodedMetal', 'Fabric', 'Ice', 'Limestone', 'Foil'},
        Default = 1,
        Callback = function(v)
            if not _worldReady then return end
            if Toggles.WorldApplyMaterial and Toggles.WorldApplyMaterial.Value then
                applyMapMaterial(v)
            end
        end
    })
    MaterialDepbox:SetupDependencies({ { Toggles.WorldApplyMaterial, true } })
    end -- Material Override scope

    -- ═══════════════════ MAP REFLECTANCE ═══════════════════
    WorldBoxes.Terrain:AddToggle('WorldCustomReflectance', {
        Text = 'Override Map Reflectance',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if not state then
                local map = workspace:FindFirstChild("Map")
                if map then
                    for _, obj in ipairs(map:GetDescendants()) do
                        if obj:IsA("BasePart") then
                            pcall(function() obj.Reflectance = 0 end)
                        end
                    end
                end
            end
        end
    })

    local ReflectanceDepbox = WorldBoxes.Terrain:AddDependencyBox()
    ReflectanceDepbox:AddSlider('WorldReflectance', {
        Text = 'Map Reflectance',
        Default = 0,
        Min = 0,
        Max = 1,
        Rounding = 2,
        Callback = function(v)
            if not _worldReady then return end
            local map = workspace:FindFirstChild("Map")
            if map then
                for _, obj in ipairs(map:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        pcall(function() obj.Reflectance = v end)
                    end
                end
            end
        end
    })
    ReflectanceDepbox:SetupDependencies({ { Toggles.WorldCustomReflectance, true } })

    -- ═══════════════════ X-RAY & NOCLIP ═══════════════════
    WorldBoxes.Terrain:AddLabel('Visibility')

    WorldBoxes.Terrain:AddToggle('WorldXRay', {
        Text = 'X-Ray (Walls Transparent)',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            local map = workspace:FindFirstChild("Map")
            if map then
                local wallsFolder = map:FindFirstChild("Wall")
                if wallsFolder then
                    for _, wall in ipairs(wallsFolder:GetDescendants()) do
                        if wall:IsA("BasePart") then
                            wall.Transparency = state and 0.8 or 0
                        end
                    end
                end
            end
        end
    })

    -- ═══════════════════ WEATHER EFFECTS ═══════════════════
    -- Rain/StarFall/Thunder are ported from PortalVisuals (raycasted, per-frame
    -- simulated effects rather than a single static ParticleEmitter), each
    -- wrapped in its own do-end so their locals don't count against Luau's
    -- 200 file-scope local limit.
    do
    local Workspace = workspace
    local RunService = RS
    local LocalPlayer = LP
    local Rain = {}
    Rain.running = false
    Rain.heartbeatConn = nil
    Rain.rainFolder = nil
    Rain.rayParams = nil
    Rain.splashPool = {}
    Rain.splashIndex = 0
    Rain.activeSplashes = {}
    Rain.rainDrops = {}
    Rain.dropParts = {}
    Rain.mistParts = {}
    Rain.frameCount = 0
    Rain.CONFIG = {RAIN_COUNT=360,RAIN_RADIUS=45,RAIN_HEIGHT=35,FALL_SPEED=82,WIND_X=2.5,SPEED_VARIANCE=18,RAYCAST_EVERY=8,SPLASH_POOL=100,MIST_COUNT=20}
    Rain.windAngleCF = CFrame.Angles(math.rad(Rain.CONFIG.WIND_X * 3), 0, 0)
    Rain.LERP_SPEED = 25

    function Rain.getGroundY(pos)
        local result = Workspace:Raycast(pos, Vector3.new(0, -100, 0), Rain.rayParams)
        return result and result.Position.Y or (pos.Y - 100)
    end

    function Rain.playSplash(pos)
        Rain.splashIndex = (Rain.splashIndex % Rain.CONFIG.SPLASH_POOL) + 1
        local s = Rain.splashPool[Rain.splashIndex]
        if not s then return end
        s.Size = Vector3.new(0.1, 0.03, 0.1)
        s.Position = Vector3.new(pos.X, pos.Y + 0.06, pos.Z)
        s.Transparency = 0.2
        Rain.activeSplashes[s] = {timer = 0}
        local pe = s:FindFirstChildOfClass("ParticleEmitter")
        if pe then pe:Emit(5) end
    end

    function Rain.initRain()
        local character = LocalPlayer.Character
        if not character then return end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        local rootPos = rootPart.Position
        Rain.rayParams = RaycastParams.new()
        Rain.rayParams.FilterType = Enum.RaycastFilterType.Exclude
        Rain.rayParams.FilterDescendantsInstances = {Rain.rainFolder, character}

        for i = 1, Rain.CONFIG.SPLASH_POOL do
            local s = Instance.new("Part")
            s.Size = Vector3.new(0.12, 0.03, 0.12)
            s.Material = Enum.Material.Glass
            s.Color = Color3.fromRGB(200, 225, 255)
            s.Transparency = 0.4
            s.Anchored = true
            s.CanCollide = false
            s.CastShadow = false
            s.Parent = Rain.rainFolder
            local pe = Instance.new("ParticleEmitter")
            pe.Texture = "rbxassetid://5813005513"
            pe.Size = NumberSequence.new(0.06, 0)
            pe.Lifetime = NumberRange.new(0.15, 0.3)
            pe.Rate = 0
            pe.Speed = NumberRange.new(0.5, 1.5)
            pe.Transparency = NumberSequence.new(0.2, 1)
            pe.Color = ColorSequence.new(Color3.fromRGB(180, 210, 255))
            pe.Parent = s
            Rain.splashPool[i] = s
        end

        for i = 1, Rain.CONFIG.RAIN_COUNT do
            local angle = math.random() * math.pi * 2
            local radius = math.sqrt(math.random()) * Rain.CONFIG.RAIN_RADIUS
            local drop = Instance.new("Part")
            local len = 1.8 + math.random() * 1.2
            drop.Size = Vector3.new(0.04, len, 0.04)
            drop.Material = Enum.Material.Glass
            drop.Color = Color3.fromRGB(190, 220, 255)
            drop.Transparency = 0.3 + math.random() * 0.2
            drop.CanCollide = false
            drop.Anchored = true
            drop.CastShadow = false
            drop.Parent = Rain.rainFolder
            Rain.dropParts[i] = drop
            local spawnX = rootPos.X + math.cos(angle) * radius
            local spawnY = rootPos.Y + math.random(5, Rain.CONFIG.RAIN_HEIGHT)
            local spawnZ = rootPos.Z + math.sin(angle) * radius
            Rain.rainDrops[i] = {
                x = spawnX, y = spawnY, z = spawnZ,
                speed = Rain.CONFIG.FALL_SPEED + math.random(-Rain.CONFIG.SPEED_VARIANCE, Rain.CONFIG.SPEED_VARIANCE),
                groundY = spawnY - 100,
                rayTimer = math.random(1, Rain.CONFIG.RAYCAST_EVERY),
                px = spawnX, py = spawnY, pz = spawnZ, len = len,
            }
            drop.CFrame = CFrame.new(spawnX, spawnY, spawnZ) * Rain.windAngleCF
        end

        for i = 1, Rain.CONFIG.MIST_COUNT do
            local mist = Instance.new("Part")
            mist.Size = Vector3.new(2 + math.random() * 3, 0.3 + math.random() * 0.5, 2 + math.random() * 3)
            mist.Shape = Enum.PartType.Ball
            mist.Material = Enum.Material.Glass
            mist.Color = Color3.fromRGB(180, 200, 220)
            mist.Transparency = 0.7
            mist.Anchored = true
            mist.CanCollide = false
            mist.CastShadow = false
            mist.Parent = Rain.rainFolder
            table.insert(Rain.mistParts, mist)
        end
    end

    function Rain.onHeartbeat(dt)
        if not Rain.running then return end
        dt = math.min(dt, 0.05)
        Rain.frameCount = Rain.frameCount + 1
        local character = LocalPlayer.Character
        if not character then return end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        if Rain.frameCount % 60 == 0 then
            Rain.rayParams.FilterDescendantsInstances = {Rain.rainFolder, character}
        end
        local rootPos = rootPart.Position

        for i, mist in ipairs(Rain.mistParts) do
            local mAngle = (i / Rain.CONFIG.MIST_COUNT) * math.pi * 2 + Rain.frameCount * 0.002
            local mDist = 15 + math.sin(Rain.frameCount * 0.003 + i) * 10
            local mY = rootPos.Y + math.sin(Rain.frameCount * 0.01 + i) * 2 - 1.5
            mist.Position = rootPos + Vector3.new(math.cos(mAngle) * mDist + Rain.CONFIG.WIND_X * Rain.frameCount * 0.01, mY, math.sin(mAngle) * mDist)
            mist.Transparency = 0.65 + math.sin(Rain.frameCount * 0.02 + i) * 0.15
        end

        for s, data in pairs(Rain.activeSplashes) do
            data.timer = data.timer + dt
            local t = math.min(data.timer / 0.28, 1)
            local ease = 1 - (1 - t) * (1 - t)
            s.Size = Vector3.new(0.1 + 0.8 * ease, 0.03, 0.1 + 0.8 * ease)
            s.Transparency = 0.2 + 0.8 * ease
            if t >= 1 then Rain.activeSplashes[s] = nil end
        end

        for i = 1, Rain.CONFIG.RAIN_COUNT do
            local d = Rain.rainDrops[i]
            local drop = Rain.dropParts[i]
            if not d or not drop then continue end
            d.x = d.x + Rain.CONFIG.WIND_X * dt
            d.y = d.y - d.speed * dt
            local alpha = math.min(Rain.LERP_SPEED * dt, 1)
            d.px = d.px + (d.x - d.px) * alpha
            d.py = d.py + (d.y - d.py) * alpha
            d.pz = d.pz + (d.z - d.pz) * alpha
            d.rayTimer = d.rayTimer + 1
            if d.rayTimer >= Rain.CONFIG.RAYCAST_EVERY then
                d.rayTimer = 0
                d.groundY = Rain.getGroundY(Vector3.new(d.x, d.y + 5, d.z))
            end
            if d.y <= d.groundY + 1.1 then
                Rain.playSplash(Vector3.new(d.x, d.groundY, d.z))
                local angle = math.random() * math.pi * 2
                local radius = math.sqrt(math.random()) * Rain.CONFIG.RAIN_RADIUS
                d.x = rootPos.X + math.cos(angle) * radius
                d.y = rootPos.Y + Rain.CONFIG.RAIN_HEIGHT
                d.z = rootPos.Z + math.sin(angle) * radius
                d.px = d.x; d.py = d.y; d.pz = d.z
                d.groundY = d.y - 100
                d.rayTimer = 0
                d.len = 1.8 + math.random() * 1.2
            end
            drop.Size = Vector3.new(0.04, d.len, 0.04)
            drop.CFrame = CFrame.new(d.px, d.py, d.pz) * Rain.windAngleCF
        end
    end

    function Rain.enableRain()
        if Rain.running then return end
        Rain.running = true
        Rain.rainFolder = Instance.new("Folder")
        Rain.rainFolder.Name = "RainEffect"
        Rain.rainFolder.Parent = Workspace
        Rain.splashPool = {}
        Rain.splashIndex = 0
        Rain.activeSplashes = {}
        Rain.rainDrops = {}
        Rain.dropParts = {}
        Rain.mistParts = {}
        Rain.frameCount = 0
        Rain.initRain()
        Rain.heartbeatConn = RunService.Heartbeat:Connect(Rain.onHeartbeat)
    end

    function Rain.disableRain()
        Rain.running = false
        if Rain.heartbeatConn then Rain.heartbeatConn:Disconnect() end
        if Rain.rainFolder then Rain.rainFolder:Destroy() end
        Rain.splashPool = {}
        Rain.activeSplashes = {}
        Rain.rainDrops = {}
        Rain.dropParts = {}
        Rain.mistParts = {}
    end

    WorldBoxes.Weather:AddToggle('WorldRain', {
        Text = 'Rain Effect',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            local ok, err = pcall(function()
                if state then Rain.enableRain() else Rain.disableRain() end
            end)
            if not ok then
                Library:Notify("Rain error: " .. tostring(err), 4)
                return
            end
            Library:Notify(state and "Rain started" or "Rain stopped", 2)
        end
    })
    end -- Rain scope

    do
    local Workspace = workspace
    local RunService = RS
    local LocalPlayer = LP
    local TweenService = game:GetService("TweenService")
    local Debris = game:GetService("Debris")
    local Star = {}
    Star.running = false
    Star.Settings = {SpawnInterval=0.1,MaxActiveStars=35,StarColor=Color3.fromRGB(255,230,150),TrailColor=Color3.fromRGB(255,190,80),StarSize=Vector3.new(1.8,1.8,1.8),Speed=125,FallHeight=125,MinRadius=35,MaxRadius=135,TrailLifetime=0.55,StarLifetime=4.5}
    Star.ActiveStars = {}
    Star.SpawnConnection = nil
    Star.MovementConnection = nil
    Star.StarsFolder = nil
    Star.FrameCounter = 0
    Star.GlobalRaycastParams = RaycastParams.new()
    Star.GlobalRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

    function Star.GetStarsFolder()
        if not Star.StarsFolder or not Star.StarsFolder.Parent then
            Star.StarsFolder = Instance.new("Folder")
            Star.StarsFolder.Name = "PortalVisual_Stars_Optimized"
            Star.StarsFolder.Parent = Workspace
        end
        return Star.StarsFolder
    end

    function Star.UpdateRaycastFilter()
        local filter = {Star.GetStarsFolder()}
        if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
        Star.GlobalRaycastParams.FilterDescendantsInstances = filter
    end

    function Star.CreateImpactExplosion(position, normal)
        local folder = Star.GetStarsFolder()
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.05, 0.1, 0.1)
        ring.Material = Enum.Material.Neon
        ring.Color = Star.Settings.TrailColor
        ring.Transparency = 0.15
        ring.Anchored = true
        ring.CanCollide = false
        ring.CanQuery = false
        ring.CFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(math.rad(90), 0, 0)
        ring.Parent = folder
        local ringTween = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.QuadOut), {Size = Vector3.new(0.05, 10.0, 10.0), Transparency = 1})
        ringTween:Play()
        Debris:AddItem(ring, 0.4)

        local flash = Instance.new("Part")
        flash.Shape = Enum.PartType.Ball
        flash.Size = Vector3.new(0.5, 0.5, 0.5)
        flash.Material = Enum.Material.Neon
        flash.Color = Color3.fromRGB(255, 255, 255)
        flash.Transparency = 0.3
        flash.Anchored = true
        flash.CanCollide = false
        flash.CanQuery = false
        flash.Position = position
        flash.Parent = folder
        TweenService:Create(flash, TweenInfo.new(0.2, Enum.EasingStyle.QuadOut), {Size = Vector3.new(4, 4, 4), Transparency = 1}):Play()
        Debris:AddItem(flash, 0.3)

        local sparkPart = Instance.new("Part")
        sparkPart.Size = Vector3.new(0.1, 0.1, 0.1)
        sparkPart.Transparency = 1
        sparkPart.Anchored = true
        sparkPart.CanCollide = false
        sparkPart.Position = position
        sparkPart.Parent = folder
        local emitter = Instance.new("ParticleEmitter")
        emitter.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Star.Settings.StarColor), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 100))})
        emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 0)})
        emitter.Lifetime = NumberRange.new(0.35, 0.8)
        emitter.Speed = NumberRange.new(15, 35)
        emitter.SpreadAngle = Vector2.new(-180, 180)
        emitter.Acceleration = Vector3.new(0, -25, 0)
        emitter.Drag = 2
        emitter.LightEmission = 1.5
        emitter.Parent = sparkPart
        emitter:Emit(35)
        task.delay(1.0, function() sparkPart:Destroy() end)

        local glowBurst = Instance.new("ParticleEmitter")
        glowBurst.Color = ColorSequence.new(Color3.fromRGB(255, 230, 180))
        glowBurst.Size = NumberSequence.new(0.8, 0)
        glowBurst.Lifetime = NumberRange.new(0.15, 0.3)
        glowBurst.Speed = NumberRange.new(2, 5)
        glowBurst.SpreadAngle = Vector2.new(-180, 180)
        glowBurst.LightEmission = 2
        glowBurst.Rate = 0
        glowBurst.Parent = sparkPart
        glowBurst:Emit(18)
        task.delay(0.5, function() sparkPart:Destroy() end)
    end

    function Star.GetPlayerPosition()
        local character = LocalPlayer.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then return rootPart.Position end
        end
        if workspace.CurrentCamera then return workspace.CurrentCamera.CFrame.Position end
        return Vector3.new(0, 0, 0)
    end

    function Star.FadeOutStar(starData, instant)
        if starData.IsDying then return end
        starData.IsDying = true
        local star = starData.Instance
        if star and star.Parent then
            if instant then
                star.Transparency = 1
                star.Size = Vector3.new(0, 0, 0)
                task.delay(Star.Settings.TrailLifetime, function() star:Destroy() end)
            else
                local tween = TweenService:Create(star, TweenInfo.new(0.25), {Size = Vector3.new(0, 0, 0), Transparency = 1})
                tween:Play()
                task.delay(Star.Settings.TrailLifetime, function() star:Destroy() end)
            end
        end
        local index = table.find(Star.ActiveStars, starData)
        if index then table.remove(Star.ActiveStars, index) end
    end

    function Star.CreateStar()
        local center = Star.GetPlayerPosition()
        local folder = Star.GetStarsFolder()
        if #Star.ActiveStars >= Star.Settings.MaxActiveStars then
            Star.FadeOutStar(Star.ActiveStars[1], false)
        end
        local angle = math.random() * math.pi * 2
        local distance = math.random(Star.Settings.MinRadius, Star.Settings.MaxRadius)
        local targetPos = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local slowRotationAngle = tick() * 0.05
        local dynamicBaseDirection = Vector3.new(math.cos(slowRotationAngle) * 0.75, -1, math.sin(slowRotationAngle) * 0.75).Unit
        local wobble = Vector3.new((math.random() - 0.5) * 0.15, 0, (math.random() - 0.5) * 0.15)
        local finalDirection = (dynamicBaseDirection + wobble).Unit
        local spawnPos = targetPos - (finalDirection * (Star.Settings.FallHeight / -finalDirection.Y))

        local star = Instance.new("Part")
        star.Name = "ShootingStar"
        star.Size = Star.Settings.StarSize
        star.Shape = Enum.PartType.Ball
        star.Color = Star.Settings.StarColor
        star.Material = Enum.Material.Neon
        star.Anchored = true
        star.CanCollide = false
        star.CanQuery = false
        star.CanTouch = false
        star.CastShadow = false
        star.Position = spawnPos
        star.Parent = folder

        local starGlow = Instance.new("PointLight")
        starGlow.Color = Star.Settings.StarColor
        starGlow.Brightness = 4
        starGlow.Range = 12
        starGlow.Shadows = false
        starGlow.Parent = star

        local starHue = (math.random(0, 60) / 360)
        local starVariety = Color3.fromHSV(starHue, 0.6, 1)

        local att0 = Instance.new("Attachment")
        att0.Position = Vector3.new(0, Star.Settings.StarSize.Y / 2, 0)
        att0.Parent = star
        local att1 = Instance.new("Attachment")
        att1.Position = Vector3.new(0, -Star.Settings.StarSize.Y / 2, 0)
        att1.Parent = star

        local trail = Instance.new("Trail")
        trail.Attachment0 = att0
        trail.Attachment1 = att1
        trail.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, starVariety), ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0))})
        trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.0), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0.9)})
        trail.Lifetime = Star.Settings.TrailLifetime
        trail.LightEmission = 1.5
        trail.LightInfluence = 0
        trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0)})
        trail.Parent = star

        local dust = Instance.new("ParticleEmitter")
        dust.Color = ColorSequence.new(Star.Settings.StarColor)
        dust.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
        dust.Lifetime = NumberRange.new(0.2, 0.45)
        dust.Speed = NumberRange.new(0, 3)
        dust.Rate = 25
        dust.LightEmission = 1.0
        dust.Parent = star

        local starData = {Instance = star, Position = spawnPos, Direction = finalDirection, Speed = Star.Settings.Speed * (0.85 + math.random() * 0.3), SpawnTime = os.clock(), IsDying = false, Color = starVariety}
        table.insert(Star.ActiveStars, starData)
    end

    function Star.UpdateStars(deltaTime)
        local currentClock = os.clock()
        Star.FrameCounter = Star.FrameCounter + 1
        for i = #Star.ActiveStars, 1, -1 do
            local starData = Star.ActiveStars[i]
            local star = starData.Instance
            if not star or not star.Parent then
                table.remove(Star.ActiveStars, i)
                continue
            end
            if currentClock - starData.SpawnTime >= Star.Settings.StarLifetime then
                Star.FadeOutStar(starData, false)
                continue
            end
            local nextPosition = starData.Position + (starData.Direction * starData.Speed * deltaTime)
            starData.Position = nextPosition
            star.Position = nextPosition
            if Star.FrameCounter % 2 == 0 then
                local raycastResult = Workspace:Raycast(starData.Position, starData.Direction * (starData.Speed * deltaTime * 2.5), Star.GlobalRaycastParams)
                if raycastResult then
                    Star.CreateImpactExplosion(raycastResult.Position, raycastResult.Normal)
                    Star.FadeOutStar(starData, true)
                end
            end
        end
    end

    function Star.enableStarFall()
        if Star.running then return end
        Star.running = true
        Star.UpdateRaycastFilter()
        local lastSpawn = 0
        Star.SpawnConnection = RunService.Heartbeat:Connect(function(deltaTime)
            if not Star.running then return end
            lastSpawn = lastSpawn + deltaTime
            if lastSpawn >= Star.Settings.SpawnInterval then
                lastSpawn = 0
                Star.CreateStar()
            end
        end)
        Star.MovementConnection = RunService.RenderStepped:Connect(function(deltaTime)
            if Star.running then Star.UpdateStars(deltaTime) end
        end)
    end

    function Star.disableStarFall()
        if not Star.running then return end
        Star.running = false
        if Star.SpawnConnection then Star.SpawnConnection:Disconnect() end
        if Star.MovementConnection then Star.MovementConnection:Disconnect() end
        for _, starData in ipairs(Star.ActiveStars) do
            Star.FadeOutStar(starData, true)
        end
        table.clear(Star.ActiveStars)
        task.delay(Star.Settings.TrailLifetime + 0.1, function()
            if Star.StarsFolder then Star.StarsFolder:Destroy(); Star.StarsFolder = nil end
        end)
    end

    WorldBoxes.Weather:AddToggle('WorldStarFall', {
        Text = 'Star Fall',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            local ok, err = pcall(function()
                if state then Star.enableStarFall() else Star.disableStarFall() end
            end)
            if not ok then
                Library:Notify("Star Fall error: " .. tostring(err), 4)
                return
            end
            Library:Notify(state and "Star Fall started" or "Star Fall stopped", 2)
        end
    })
    end -- Star Fall scope

    do
    local Workspace = workspace
    local LocalPlayer = LP
    local TweenService = game:GetService("TweenService")
    local Debris = game:GetService("Debris")
    local Bolt = {}
    Bolt.running = false
    Bolt.Settings = {MinInterval=2.0,MaxInterval=5.0,StrikeRadiusMin=40,StrikeRadiusMax=150,StrikeHeight=300,LightningColor=Color3.fromRGB(190,225,255),Thickness=1.2,Segments=11,Displacement=13,FadeInDuration=0.04,FadeOutDuration=0.45,SegmentDelay=0.015,BranchDelay=0.06,PulseIntensity=0.35,GroundFlashSize=14}
    Bolt.LightningFolder = nil
    Bolt.CharConnection = nil
    Bolt.RayParams = RaycastParams.new()
    Bolt.RayParams.FilterType = Enum.RaycastFilterType.Exclude

    function Bolt.UpdateRayParams()
        local filter = {}
        if Bolt.LightningFolder then table.insert(filter, Bolt.LightningFolder) end
        if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
        Bolt.RayParams.FilterDescendantsInstances = filter
    end

    function Bolt.GetLightningFolder()
        if not Bolt.LightningFolder or not Bolt.LightningFolder.Parent then
            Bolt.LightningFolder = Instance.new("Folder")
            Bolt.LightningFolder.Name = "PortalVisual_Lightning_Local"
            Bolt.LightningFolder.Parent = Workspace
            Bolt.UpdateRayParams()
        end
        return Bolt.LightningFolder
    end

    function Bolt.DrawSegment(p1, p2, thickness, color, folder)
        local distance = (p1 - p2).Magnitude
        local part = Instance.new("Part")
        part.Size = Vector3.new(thickness, thickness, distance)
        part.CFrame = CFrame.lookAt((p1 + p2) / 2, p2)
        part.Color = color
        part.Material = Enum.Material.Neon
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Transparency = 1
        part.Parent = folder
        Debris:AddItem(part, 2.5)
        return part
    end

    function Bolt.SafeTween(obj, info, props)
        local ok, tw = pcall(TweenService.Create, TweenService, obj, info, props)
        if ok and tw then
            tw:Play()
            return tw
        else
            for k, v in pairs(props) do pcall(function() obj[k] = v end) end
            return nil
        end
    end

    function Bolt.AnimateLightning(mainParts, branchParts)
        for _, part in ipairs(mainParts) do
            if part and part.Parent then
                Bolt.SafeTween(part, TweenInfo.new(Bolt.Settings.FadeInDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0})
                task.wait(Bolt.Settings.SegmentDelay)
            end
        end
        task.wait(Bolt.Settings.BranchDelay)
        for _, part in ipairs(branchParts) do
            if part and part.Parent then
                Bolt.SafeTween(part, TweenInfo.new(Bolt.Settings.FadeInDuration * 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0.1})
            end
        end
        task.wait(0.06)
        for _, part in ipairs(mainParts) do
            if part and part.Parent then Bolt.SafeTween(part, TweenInfo.new(0.04, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.2}) end
        end
        task.wait(0.04)
        for _, part in ipairs(mainParts) do
            if part and part.Parent then Bolt.SafeTween(part, TweenInfo.new(0.04, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0}) end
        end
        task.wait(0.04)
        for _, part in ipairs(mainParts) do
            if part and part.Parent then Bolt.SafeTween(part, TweenInfo.new(0.04, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.25}) end
        end
        task.wait(0.04)
        for _, part in ipairs(mainParts) do
            if part and part.Parent then Bolt.SafeTween(part, TweenInfo.new(0.04, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0}) end
        end
        task.wait(0.2)
        local allParts = {}
        for _, p in ipairs(mainParts) do table.insert(allParts, p) end
        for _, p in ipairs(branchParts) do table.insert(allParts, p) end
        for _, part in ipairs(allParts) do
            if part and part.Parent then
                local tw = Bolt.SafeTween(part, TweenInfo.new(Bolt.Settings.FadeOutDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1})
                if tw then
                    tw.Completed:Connect(function() if part and part.Parent then part:Destroy() end end)
                else
                    part:Destroy()
                end
            end
        end
    end

    function Bolt.CreateGroundImpact(position, normal)
        local folder = Bolt.GetLightningFolder()
        local lightPart = Instance.new("Part")
        lightPart.Shape = Enum.PartType.Ball
        lightPart.Size = Vector3.new(0.1, 0.1, 0.1)
        lightPart.Color = Color3.fromRGB(255, 255, 255)
        lightPart.Material = Enum.Material.Neon
        lightPart.Position = position
        lightPart.Anchored = true
        lightPart.CanCollide = false
        lightPart.Transparency = 1
        lightPart.Parent = folder
        local pointLight = Instance.new("PointLight")
        pointLight.Color = Bolt.Settings.LightningColor
        pointLight.Brightness = 0
        pointLight.Range = Bolt.Settings.GroundFlashSize * 1.5
        pointLight.Parent = lightPart
        Bolt.SafeTween(pointLight, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 10})
        Bolt.SafeTween(lightPart, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(Bolt.Settings.GroundFlashSize, Bolt.Settings.GroundFlashSize, Bolt.Settings.GroundFlashSize)})
        task.delay(0.12, function()
            if lightPart.Parent then
                Bolt.SafeTween(pointLight, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Brightness = 0})
                Bolt.SafeTween(lightPart, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1})
                Debris:AddItem(lightPart, 0.4)
            end
        end)
        local ring = Instance.new("Part")
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.05, 1, 1)
        ring.Color = Bolt.Settings.LightningColor
        ring.Material = Enum.Material.Neon
        ring.Transparency = 0.3
        ring.Anchored = true
        ring.CanCollide = false
        ring.CFrame = CFrame.lookAt(position, position + normal) * CFrame.Angles(math.rad(90), 0, 0)
        ring.Parent = folder
        Bolt.SafeTween(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = Vector3.new(0.05, 28, 28), Transparency = 1})
        Debris:AddItem(ring, 0.5)
        pcall(function()
            Lighting.Brightness = 2
            task.delay(0.1, function() pcall(function() Lighting.Brightness = OriginalValues.Brightness end) end)
        end)
    end

    function Bolt.GenerateLightningBranch(startPos, endPos, segments, displacement, thickness, isBranch, folder, mainParts, branchParts)
        local points = {startPos}
        for i = 2, segments do
            local t = (i - 1) / (segments - 1)
            local basePos = startPos:Lerp(endPos, t)
            if i < segments then
                local offset = Vector3.new(math.random(-displacement, displacement), math.random(-displacement * 0.3, displacement * 0.3), math.random(-displacement, displacement))
                points[i] = basePos + offset
            else
                points[i] = endPos
            end
        end
        for i = 1, #points - 1 do
            local p1 = points[i]
            local p2 = points[i + 1]
            local currentThickness = isBranch and (thickness * 0.5) or thickness
            local part = Bolt.DrawSegment(p1, p2, currentThickness, Bolt.Settings.LightningColor, folder)
            if isBranch then
                table.insert(branchParts, part)
            else
                table.insert(mainParts, part)
            end
            if not isBranch and i > 2 and i < #points - 1 and math.random() < 0.25 then
                local branchDir = (p2 - p1).Unit + Vector3.new(math.random(-10, 10) / 10, -0.4, math.random(-10, 10) / 10).Unit
                local branchLength = (endPos - startPos).Magnitude * 0.35
                local branchEnd = p2 + (branchDir * branchLength)
                Bolt.GenerateLightningBranch(p2, branchEnd, 5, displacement * 0.5, thickness, true, folder, mainParts, branchParts)
            end
        end
    end

    function Bolt.TriggerLightningStrike()
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local center = rootPart and rootPart.Position or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.new(0, 0, 0))
        local angle = math.random() * math.pi * 2
        local distance = math.random(Bolt.Settings.StrikeRadiusMin, Bolt.Settings.StrikeRadiusMax)
        local targetPosXZ = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        local skyCheckPos = targetPosXZ + Vector3.new(0, 400, 0)
        local rayResult = Workspace:Raycast(skyCheckPos, Vector3.new(0, -800, 0), Bolt.RayParams)
        local endPos = rayResult and rayResult.Position or targetPosXZ
        local normal = rayResult and rayResult.Normal or Vector3.new(0, 1, 0)
        local startPos = endPos + Vector3.new(math.random(-40, 40), Bolt.Settings.StrikeHeight, math.random(-40, 40))
        local mainParts, branchParts = {}, {}
        Bolt.GenerateLightningBranch(startPos, endPos, Bolt.Settings.Segments, Bolt.Settings.Displacement, Bolt.Settings.Thickness, false, Bolt.GetLightningFolder(), mainParts, branchParts)
        Bolt.CreateGroundImpact(endPos, normal)
        task.spawn(Bolt.AnimateLightning, mainParts, branchParts)
    end

    Bolt.thunderThread = nil

    function Bolt.enableThunder()
        if Bolt.running then return end
        Bolt.running = true
        Bolt.UpdateRayParams()
        if not Bolt.CharConnection then
            Bolt.CharConnection = LocalPlayer.CharacterAdded:Connect(Bolt.UpdateRayParams)
        end
        Bolt.thunderThread = task.spawn(function()
            while Bolt.running do
                local waitTime = math.random(Bolt.Settings.MinInterval * 10, Bolt.Settings.MaxInterval * 10) / 10
                task.wait(waitTime)
                if not Bolt.running then break end
                local success, err = pcall(Bolt.TriggerLightningStrike)
                if not success then warn("[Thunder Error]: " .. tostring(err)) end
            end
        end)
    end

    function Bolt.disableThunder()
        Bolt.running = false
        if Bolt.thunderThread then task.cancel(Bolt.thunderThread); Bolt.thunderThread = nil end
        if Bolt.CharConnection then Bolt.CharConnection:Disconnect(); Bolt.CharConnection = nil end
        if Bolt.LightningFolder then Bolt.LightningFolder:Destroy(); Bolt.LightningFolder = nil end
    end

    WorldBoxes.Weather:AddToggle('WorldThunder', {
        Text = 'Thunder',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            local ok, err = pcall(function()
                if state then Bolt.enableThunder() else Bolt.disableThunder() end
            end)
            if not ok then
                Library:Notify("Thunder error: " .. tostring(err), 4)
                return
            end
            Library:Notify(state and "Thunder started" or "Thunder stopped", 2)
        end
    })
    end -- Thunder scope

    WorldBoxes.Weather:AddToggle('WorldSnow', {
        Text = 'Snow Effect',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if state then
                pcall(function()
                    local snowPart = Instance.new("Part")
                    snowPart.Name = "WorldSnow"
                    snowPart.Anchored = true
                    snowPart.CanCollide = false
                    snowPart.CanQuery = false
                    snowPart.CanTouch = false
                    snowPart.CastShadow = false
                    snowPart.Transparency = 1
                    snowPart.Size = Vector3.new(200, 1, 200)
                    local char = LP.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    snowPart.Position = hrp and (hrp.Position + Vector3.new(0, 80, 0)) or Vector3.new(0, 80, 0)
                    snowPart.Parent = workspace

                    local pe = Instance.new("ParticleEmitter")
                    pe.Color = ColorSequence.new(Color3.fromRGB(240, 245, 255))
                    pe.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.6),
                        NumberSequenceKeypoint.new(0.5, 0.5),
                        NumberSequenceKeypoint.new(1, 0.3)
                    })
                    pe.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.1),
                        NumberSequenceKeypoint.new(1, 0.5)
                    })
                    pe.Lifetime = NumberRange.new(4, 6)
                    pe.Rate = 200
                    pe.Speed = NumberRange.new(5, 12)
                    pe.SpreadAngle = Vector2.new(180, 180)
                    pe.RotSpeed = NumberRange.new(-30, 30)
                    pe.VelocityInheritance = -0.5
                    pe.Drag = 3
                    pe.LightEmission = 0.5
                    pe.Parent = snowPart
                    pe.EmissionDirection = Enum.NormalId.Bottom

                    task.spawn(function()
                        while snowPart and snowPart.Parent do
                            local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                            if h then snowPart.Position = h.Position + Vector3.new(0, 80, 0) end
                            task.wait(0.1)
                        end
                    end)
                end)
                Library:Notify("Snow started", 2)
            else
                pcall(function()
                    local snow = workspace:FindFirstChild("WorldSnow")
                    if snow then snow:Destroy() end
                end)
                Library:Notify("Snow stopped", 2)
            end
        end
    })

    WorldBoxes.Weather:AddToggle('WorldFireflies', {
        Text = 'Firefly Particles',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if state then
                pcall(function()
                    local ffPart = Instance.new("Part")
                    ffPart.Name = "WorldFireflies"
                    ffPart.Anchored = true
                    ffPart.CanCollide = false
                    ffPart.CanQuery = false
                    ffPart.CanTouch = false
                    ffPart.CastShadow = false
                    ffPart.Transparency = 1
                    ffPart.Size = Vector3.new(80, 40, 80)
                    local char = LP.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    ffPart.Position = hrp and (hrp.Position + Vector3.new(0, 10, 0)) or Vector3.new(0, 10, 0)
                    ffPart.Parent = workspace

                    local pe = Instance.new("ParticleEmitter")
                    pe.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 255, 50)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 50))
                    })
                    pe.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(0.3, 0.8),
                        NumberSequenceKeypoint.new(0.7, 0.8),
                        NumberSequenceKeypoint.new(1, 0)
                    })
                    pe.Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.5),
                        NumberSequenceKeypoint.new(0.5, 0),
                        NumberSequenceKeypoint.new(1, 0.5)
                    })
                    pe.Lifetime = NumberRange.new(3, 5)
                    pe.Rate = 30
                    pe.Speed = NumberRange.new(2, 5)
                    pe.SpreadAngle = Vector2.new(360, 360)
                    pe.RotSpeed = NumberRange.new(-20, 20)
                    pe.LightEmission = 1
                    pe.LightInfluence = 0
                    pe.Parent = ffPart

                    task.spawn(function()
                        while ffPart and ffPart.Parent do
                            local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                            if h then ffPart.Position = h.Position + Vector3.new(0, 10, 0) end
                            task.wait(0.2)
                        end
                    end)
                end)
                Library:Notify("Fireflies started", 2)
            else
                pcall(function()
                    local ff = workspace:FindFirstChild("WorldFireflies")
                    if ff then ff:Destroy() end
                end)
                Library:Notify("Fireflies stopped", 2)
            end
        end
    })

    -- ═══════════════════ PLAYER EFFECTS ═══════════════════
    WorldBoxes.Misc:AddLabel('Player Visual Effects')

    WorldBoxes.Misc:AddToggle('WorldPlayerAura', {
        Text = 'Player Aura (Glow)',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            local char = LP.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            if state then
                local aura = Instance.new("PointLight")
                aura.Name = "WorldPlayerAura"
                aura.Color = Color3.fromRGB(100, 150, 255)
                aura.Brightness = 3
                aura.Range = 20
                aura.Parent = hrp
                Library:Notify("Player aura enabled", 2)
            else
                local aura = hrp:FindFirstChild("WorldPlayerAura")
                if aura then aura:Destroy() end
                Library:Notify("Player aura disabled", 2)
            end
        end
    }):AddColorPicker('WorldAuraColor', {
        Default = Color3.fromRGB(100, 150, 255),
        Title = 'Aura Color',
        Callback = function(color)
            if Toggles.WorldPlayerAura and Toggles.WorldPlayerAura.Value then
                local char = LP.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local aura = hrp:FindFirstChild("WorldPlayerAura")
                        if aura then aura.Color = color end
                    end
                end
            end
        end
    })

    WorldBoxes.Misc:AddToggle('WorldSpeedTrails', {
        Text = 'Speed Trails',
        Default = false,
        Callback = function(state)
            if not _worldReady then return end
            if state then
                local trailConn
                local lastPos = nil
                local lastTime = 0
                trailConn = RS.Heartbeat:Connect(function()
                    if not Toggles.WorldSpeedTrails or not Toggles.WorldSpeedTrails.Value then
                        trailConn:Disconnect()
                        return
                    end
                    local char = LP.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end

                    local now = tick()
                    local speed = (hrp.Position - (lastPos or hrp.Position)).Magnitude / math.max(now - lastTime, 0.01)
                    lastPos = hrp.Position
                    lastTime = now

                    if speed > 30 then
                        local a0 = Instance.new("Attachment")
                        a0.Position = Vector3.new(0, 1, 1.5)
                        local a1 = Instance.new("Attachment")
                        a1.Position = Vector3.new(0, -1, -1.5)
                        local trail = Instance.new("Trail")
                        trail.Attachment0 = a0
                        trail.Attachment1 = a1
                        trail.Color = ColorSequence.new(Color3.fromRGB(100, 180, 255), Color3.fromRGB(255, 100, 100))
                        trail.Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0.3),
                            NumberSequenceKeypoint.new(1, 1)
                        })
                        trail.Lifetime = 0.5
                        trail.MinLength = 0.1
                        trail.LightEmission = 0.8
                        a0.Parent = hrp
                        a1.Parent = hrp
                        trail.Parent = hrp
                        task.delay(0.5, function()
                            trail:Destroy()
                            a0:Destroy()
                            a1:Destroy()
                        end)
                    end
                end)
            end
        end
    })

    -- ═══════════════════ GLOBAL RESET ═══════════════════
    WorldBoxes.Weather:AddButton({
        Text = 'Remove Weather Effects',
        Func = function()
            if not _worldReady then return end
            for _, name in ipairs({"WorldRain", "WorldSnow", "WorldFireflies"}) do
                local obj = workspace:FindFirstChild(name)
                if obj then obj:Destroy() end
            end
            Library:Notify("Removed all weather effects", 2)
        end
    })

    -- ═══════════════════ READY ═══════════════════
    _worldReady = true
end


-- ===================== UI SETTINGS =====================
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

-- I set NoUI so it does not show up in the keybinds menu
MenuGroup:AddButton('Unload', function() Library:Unload() end)

MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightShift', NoUI = true, Text = 'Menu keybind' })

MenuGroup:AddDivider()

MenuGroup:AddDropdown('ToggleStyle', {
    Text = 'Toggle Style',
    Values = { 'Modern', 'Old' },
    Default = 'Old'
})

-- Addons:
-- SaveManager (Allows you to have a configuration system)
-- ThemeManager (Allows you to have a menu theme system)

-- Hand the library over to our managers
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

-- Now set the keybind after everything is initialized
Library.ToggleKeybind = Options.MenuKeybind -- Allows you to have a custom keybind for the menu

-- Ignore keys that are used by ThemeManager.
-- (we dont want configs to save themes, do we?)
SaveManager:IgnoreThemeSettings()

-- Adds our MenuKeybind to the ignore list
-- (do you want each config to have a different menu key? probably not.)
SaveManager:SetIgnoreIndexes({ 'MenuKeybind', 'ToggleStyle' })

-- Setup the toggle style callback after Options is populated
Options.ToggleStyle:OnChanged(function(Value)
    Library.ToggleStyle = Value
    
    -- Rebuild all existing toggles with the new style
    if Library._TogglesList then
        for _, toggleEntry in next, Library._TogglesList do
            toggleEntry.RenderToggle()
        end
    end
end)

-- use case for doing it this way:
-- a script hub could have themes in a global folder
-- and game configs in a separate folder per game
ThemeManager:SetFolder('MyScriptHub')
SaveManager:SetFolder('MyScriptHub/specific-game')

-- Builds our config menu on the right side of our tab
SaveManager:BuildConfigSection(Tabs['UI Settings'])

-- Builds our theme menu (with plenty of built in themes) on the left side
-- NOTE: you can also call ThemeManager:ApplyToGroupbox to add it to a specific groupbox
ThemeManager:ApplyToTab(Tabs['UI Settings'])

-- You can use the SaveManager:LoadAutoloadConfig() to load a config
-- which has been marked to be one that auto loads!
SaveManager:LoadAutoloadConfig()

-- ===================== EXTENDED INVENTORY =====================
-- Roblox's stock Backpack Hotbar (PlayerGui.BackpackGui.Backpack.Hotbar) hardcodes a
-- max of 10 slot buttons; tools beyond the 10th never get a hotbar slot at all. This
-- widens the same row with cloned slots (same visual template) up to 20 tools total.
-- (Wrapped in do-end so its locals don't count against Luau's 200 file-scope local limit)
do
local ExtendedInventoryEnabled = false
local extendedHotbarFrame = nil
local extendedSlotTemplate = nil
local extendedConns = {}
local MAX_EXTENDED_SLOTS = 20

local function EI_getStockHotbar()
    local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
    local bg = pg and pg:FindFirstChild("BackpackGui")
    local backpackFrame = bg and bg:FindFirstChild("Backpack")
    return backpackFrame and backpackFrame:FindFirstChild("Hotbar")
end

-- Keeps each tool pinned to the slot it first appeared in; equipping/unequipping
-- only toggles the white border, it no longer reshuffles the tool to the front.
local extendedToolOrder = {}

local function EI_getOrderedTools()
    local plr = Players.LocalPlayer
    local char = plr.Character
    local current = {}
    local equipped = char and char:FindFirstChildOfClass("Tool")
    if equipped then current[equipped] = true end
    local backpack = plr:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then current[tool] = true end
        end
    end

    -- drop tools that no longer exist (destroyed/removed), keep the rest in place
    for i = #extendedToolOrder, 1, -1 do
        if not current[extendedToolOrder[i]] then
            table.remove(extendedToolOrder, i)
        end
    end

    local known = {}
    for _, tool in ipairs(extendedToolOrder) do
        known[tool] = true
    end

    -- append newly seen tools to the end, equipped-first only the first time it's seen
    if equipped and not known[equipped] then
        table.insert(extendedToolOrder, equipped)
        known[equipped] = true
    end
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and not known[tool] then
                table.insert(extendedToolOrder, tool)
                known[tool] = true
            end
        end
    end

    return extendedToolOrder
end

local function EI_equipTool(tool)
    local plr = Players.LocalPlayer
    local char = plr.Character
    local backpack = plr:FindFirstChild("Backpack")
    if not char or not backpack then return end
    if tool.Parent == char then
        tool.Parent = backpack
        return
    end
    local currentlyEquipped = char:FindFirstChildOfClass("Tool")
    if currentlyEquipped then
        currentlyEquipped.Parent = backpack
    end
    tool.Parent = char
end

local function EI_rebuild()
    if not extendedHotbarFrame or not extendedSlotTemplate then return end

    for _, child in ipairs(extendedHotbarFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local tools = EI_getOrderedTools()
    local count = math.min(#tools, MAX_EXTENDED_SLOTS)

    local SLOT_SIZE, GAP = 60, 5
    local STEP = SLOT_SIZE + GAP
    local totalWidth = count > 0 and (count * SLOT_SIZE + (count - 1) * GAP) or 0

    extendedHotbarFrame.Size = UDim2.new(0, math.max(totalWidth, 60), 0, 70)
    extendedHotbarFrame.Position = UDim2.new(0.5, -totalWidth / 2, 1, -70)

    local char = Players.LocalPlayer.Character

    for i = 1, count do
        local tool = tools[i]
        local slot = extendedSlotTemplate:Clone()
        slot.Name = tostring(i)
        slot.Visible = true
        slot.Position = UDim2.new(0, (i - 1) * STEP, 0, 5)

        local icon = slot:FindFirstChild("Icon")
        if icon then icon.Image = tool.TextureId or "" end

        local toolName = slot:FindFirstChild("ToolName")
        if toolName then toolName.Text = tool.Name end

        local numberLabel = slot:FindFirstChild("Number")
        if numberLabel then numberLabel.Text = tostring(i) end

        local toolTip = slot:FindFirstChild("ToolTip")
        if toolTip then toolTip.Text = tool.Name end

        if char and tool.Parent == char then
            Library:Create('UIStroke', {
                Name = 'Border',
                Color = Color3.new(1, 1, 1),
                Thickness = 5,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Parent = slot,
            })
        end

        slot.MouseButton1Click:Connect(function()
            EI_equipTool(tool)
            task.defer(EI_rebuild)
        end)

        slot.Parent = extendedHotbarFrame
    end
end

local function enableExtendedInventory()
    if ExtendedInventoryEnabled then return end
    local stockHotbar = EI_getStockHotbar()
    local templateSlot = stockHotbar and stockHotbar:FindFirstChild("1")
    if not templateSlot then
        Library:Notify('Extended Inventory: hotbar not found yet, try again once loaded in', 3)
        return
    end

    ExtendedInventoryEnabled = true
    stockHotbar.Visible = false

    extendedSlotTemplate = templateSlot:Clone()
    local existingBorder = extendedSlotTemplate:FindFirstChild("Border")
    if existingBorder then existingBorder:Destroy() end

    extendedHotbarFrame = Instance.new("Frame")
    extendedHotbarFrame.Name = "ExtendedHotbar"
    extendedHotbarFrame.BackgroundTransparency = 1
    extendedHotbarFrame.BorderSizePixel = 0
    extendedHotbarFrame.Parent = stockHotbar.Parent

    EI_rebuild()

    local plr = Players.LocalPlayer
    local backpack = plr:FindFirstChild("Backpack")
    if backpack then
        table.insert(extendedConns, backpack.ChildAdded:Connect(function() task.defer(EI_rebuild) end))
        table.insert(extendedConns, backpack.ChildRemoved:Connect(function() task.defer(EI_rebuild) end))
    end

    local function bindCharacter(char)
        table.insert(extendedConns, char.ChildAdded:Connect(function(c)
            if c:IsA("Tool") then task.defer(EI_rebuild) end
        end))
        table.insert(extendedConns, char.ChildRemoved:Connect(function(c)
            if c:IsA("Tool") then task.defer(EI_rebuild) end
        end))
    end

    if plr.Character then bindCharacter(plr.Character) end
    table.insert(extendedConns, plr.CharacterAdded:Connect(function(char)
        task.defer(EI_rebuild)
        bindCharacter(char)
    end))
end

local function disableExtendedInventory()
    if not ExtendedInventoryEnabled then return end
    ExtendedInventoryEnabled = false

    for _, c in ipairs(extendedConns) do
        pcall(function() c:Disconnect() end)
    end
    extendedConns = {}

    if extendedHotbarFrame then
        extendedHotbarFrame:Destroy()
        extendedHotbarFrame = nil
    end
    if extendedSlotTemplate then
        extendedSlotTemplate:Destroy()
        extendedSlotTemplate = nil
    end

    local stockHotbar = EI_getStockHotbar()
    if stockHotbar then
        stockHotbar.Visible = true
    end
end

PlayerGroupBox:AddToggle('ExtendedInventoryEnabled', {
    Text = 'Extended Inventory Slots',
    Default = false,
    Tooltip = "Widens the hotbar past Roblox's stock 10-slot cap so every tool gets a slot, click to equip.",
    Callback = function(state)
        if state then
            enableExtendedInventory()
        else
            disableExtendedInventory()
        end
    end
})
end -- Extended Inventory scope

Library:SetWatermarkVisibility(false)

-- Start live config polling (updates toggles every 5s from dashboard)
startLiveConfigPolling()
-- Hook in-game toggle changes to sync back to dashboard
hookTogglesToPush()
-- Tell the dashboard we're connected
startHeartbeat()

-- Final Notification
Library:Notify("Script loaded successfully! | GOATHUB Ninja Tycoon v1.0", 5)
