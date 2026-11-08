-- Prior Extinction // Tablet & Mobile Ultra-Optimized (Zero-Lag Strict SilentAim + Multi-Part Hitbox/Reach + NoSleep + Species ESP)
print("[PE] Запуск исправленной версии (Silent Aim без лагов)...")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local Env = (type(getgenv) == "function" and getgenv()) or _G
if Env.PriorUI_Cleanup then pcall(Env.PriorUI_Cleanup) end

-- 1. State & Config
local State = {
    Active = true, Minimized = false, Connections = {}, OriginalParts = {}, LocalOriginalParts = {}, CachedModels = {},
    NeedsEnemyRestore = false, NeedsLocalRestore = false,
    -- Strict Silent Aim (Zero-Lag)
    SilentAim = false, AimTargetPart = "Head", StrictCancelNonTarget = true,
    -- Enemy Hitbox Expander (Мульти-выбор + Шея)
    HitboxMaster = false, HitboxTransparency = 0.75, HitboxTransLevel = 3, HitboxSizeLevel = 3,
    EnemyHitboxParts = { Head = true, Neck = true, Jaw = false, Body = false, Tail = false, Leg = false },
    NoAttackCD = false,
    -- Local Reach (Мульти-выбор + Шея)
    ReachEnabled = false, ReachScaleLevel = 3, ReachTransparency = 0.75, ReachTransLevel = 3,
    ReachParts = { Jaw = true, Head = true, Neck = false, Tail = false, Leg = false, Body = false },
    -- Render & Camera
    ESPEnabled = false, ESPMaxDistance = 2000, ESP_Health = true, ESP_Stamina = true, ESP_Species = true,
    ESPBones = false, ESPCorpses = false, WorldESPMaxDistance = 2000,
    NightVision = false, NoBlur = false, NoSleepScreen = false,
    UnlockCamera = false,
    -- Tools
    AutoClean = false,
    SaveDinoEnabled = false, SaveDinoMode = "Down", SaveDinoOffset = 70,
    SaveDinoOriginalCFrame = nil, SaveDinoTargetCFrame = nil, SaveDinoCurrentCFrame = nil,
    SaveDinoPhase = "idle", SaveDinoCollisions = {},
}
Env.PriorUI_State = State

local CLEAN_ACTION_BYTE = string.char(136)
local CLEAN_PREFIX_BYTE = string.char(1)
local CLEAN_BRIDGE_ID = string.char(202, 62, 227, 254, 171, 38, 70, 171, 180, 233, 209, 163, 17, 33, 119, 42)
local DEFAULT_WATER_COORDS = { -4864.8583984375, 144.86546325683594, 2668.1396484375 }

local origAtmo = Lighting:FindFirstChildOfClass("Atmosphere")
local LO = {
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness, GlobalShadows = Lighting.GlobalShadows,
    ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
    ExposureCompensation = Lighting.ExposureCompensation,
    AtmoDensity = origAtmo and origAtmo.Density or 0.3,
    AtmoHaze = origAtmo and origAtmo.Haze or 0,
    MaxZoom = LocalPlayer.CameraMaxZoomDistance,
    MinZoom = LocalPlayer.CameraMinZoomDistance,
    Occlusion = LocalPlayer.DevCameraOcclusionMode,
}

local Theme = {
    Background = Color3.fromRGB(12, 12, 14), Surface = Color3.fromRGB(18, 18, 22),
    Element = Color3.fromRGB(26, 26, 32), ElementActive = Color3.fromRGB(52, 52, 64),
    Stroke = Color3.fromRGB(45, 45, 54), TextPrimary = Color3.fromRGB(235, 235, 240),
    TextSecondary = Color3.fromRGB(145, 145, 155), Danger = Color3.fromRGB(40, 22, 24),
    DangerStroke = Color3.fromRGB(95, 40, 45)
}

local HitboxSizes = { 12, 18, 25, 32, 42 }
local ReachRanges = { -0.5, 14, 22, 30, 40, 55 }
local ReachLabels = { "0.5x (Уменьш.)", "14м (Форма)", "22м (Форма)", "30м (Форма)", "40м (Форма)", "55м (Форма)" }

local TransValues = { 0.2, 0.5, 0.75, 0.9, 1.0 }
local TransLabels = { "0.2 (Яркий)", "0.5 (Средний)", "0.75 (Слабый)", "0.9 (Почти невид.)", "1.0 (Невидимый)" }

local PartPatterns = {
    Jaw = { "jaw", "mandible", "snout", "mouth", "bite", "muzzle", "beak", "fang", "teeth" },
    Head = { "head", "skull", "cranium", "horn", "crest", "frill" },
    Neck = { "neck", "throat", "cervical", "gullet" },
    Tail = { "tail", "thago", "club", "rattle", "spike", "fluke" },
    Leg = { "leg", "thigh", "calf", "shin", "foot", "ankle", "claw", "arm", "hand", "forelimb", "toe", "wing", "talon" },
    Body = { "chest", "ribcage", "abdomen", "bodyhitbox", "hitboxbody", "upperbody", "spine", "torso", "body", "pelvis", "hip", "back", "stomach" }
}

-- 2. Utils
local Utils = {}
function Utils.Track(c) if c then table.insert(State.Connections, c) end return c end
function Utils.Notify(t, x) pcall(function() StarterGui:SetCore("SendNotification", { Title = t, Text = x, Duration = 3 }) end) end
function Utils.GuiParent()
    local ok, p = pcall(function() if type(gethui) == "function" then return gethui() end return CoreGui end)
    if ok and p then return p end
    return LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 5) or CoreGui
end
function Utils.Style(i, r, sc, sw)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = i
    if sc then
        local s = Instance.new("UIStroke"); s.Color = sc; s.Thickness = sw or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = i
    end
end
function Utils.Drag(tr, tf, cb)
    local d, di, ds, sp, md = false, nil, nil, nil, 0
    Utils.Track(tr.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            d = true; ds = inp.Position; sp = tf.Position; md = 0
            local rc; rc = inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    d = false; if rc then rc:Disconnect() end
                    if md < 12 and cb then cb() end
                end
            end)
        end
    end))
    Utils.Track(tr.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then di = inp end
    end))
    Utils.Track(UserInputService.InputChanged:Connect(function(inp)
        if inp == di and d and ds and sp then
            local dl = inp.Position - ds; md = dl.Magnitude
            tf.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dl.X, sp.Y.Scale, sp.Y.Offset + dl.Y)
        end
    end))
end
function Utils.DeepClone(tbl, seen)
    if type(tbl) ~= "table" then return tbl end
    seen = seen or {}
    if seen[tbl] then return seen[tbl] end
    local copy = {}; seen[tbl] = copy
    for k, v in pairs(tbl) do copy[Utils.DeepClone(k, seen)] = Utils.DeepClone(v, seen) end
    return copy
end

-- 3. Visuals & Unlock Camera
local Visuals = {}
local wasNightVision = false
local wasUnlockCam = false
local SleepBlackouts = {}
local MainFrameRef = nil

local function CheckIfSleepOverlay(g)
    if not g or not g.Parent then return end
    if MainFrameRef and g:IsDescendantOf(MainFrameRef) then return end
    if g:IsA("Frame") or g:IsA("ImageLabel") or g:IsA("CanvasGroup") then
        local n = string.lower(g.Name)
        local pn = g.Parent and string.lower(g.Parent.Name) or ""
        local isSleepName = string.find(n, "sleep", 1, true) or string.find(n, "rest", 1, true)
            or string.find(n, "blink", 1, true) or string.find(n, "black", 1, true)
            or string.find(n, "fade", 1, true) or string.find(n, "vignette", 1, true)
            or string.find(n, "blind", 1, true) or string.find(n, "eye", 1, true)
            or string.find(pn, "sleep", 1, true) or string.find(pn, "vignette", 1, true)

        local isFullScreen = (g.Size.X.Scale >= 0.85 and g.Size.Y.Scale >= 0.85)
        if isSleepName or isFullScreen then
            SleepBlackouts[g] = true
        end
    end
end

local function ProcessPostEffects(container)
    if not container then return end
    for _, e in ipairs(container:GetChildren()) do
        if State.NoBlur and (e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("SunRaysEffect")) then
            e.Enabled = false
            if e:IsA("BlurEffect") then e.Size = 0 end
        end
        if State.NoSleepScreen and e:IsA("ColorCorrectionEffect") then
            local en = string.lower(e.Name)
            if string.find(en, "sleep", 1, true) or string.find(en, "rest", 1, true) or string.find(en, "blind", 1, true) or string.find(en, "dark", 1, true) then
                e.Enabled = false
            end
            if e.Brightness < 0 then e.Brightness = 0 end
            if e.Contrast < 0 then e.Contrast = 0 end
            if e.Saturation < -0.2 then e.Saturation = 0 end
            if e.TintColor.R < 0.85 or e.TintColor.G < 0.85 or e.TintColor.B < 0.85 then
                e.TintColor = Color3.fromRGB(255, 255, 255)
            end
        end
    end
end

function Visuals.ScanSleepGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    pcall(function()
        for _, g in ipairs(pg:GetDescendants()) do
            CheckIfSleepOverlay(g)
        end
    end)
end

function Visuals.Init()
    Visuals.ScanSleepGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        Utils.Track(pg.DescendantAdded:Connect(function(desc)
            if State.NoSleepScreen then
                task.defer(function() pcall(CheckIfSleepOverlay, desc) end)
            end
        end))
    end

    local lastVisTick = 0
    Utils.Track(RunService.RenderStepped:Connect(function()
        if not State.Active or (not State.NoBlur and not State.NoSleepScreen) then return end
        local now = os.clock()
        if (now - lastVisTick) < 0.08 then return end
        lastVisTick = now

        ProcessPostEffects(Lighting)
        if Workspace.CurrentCamera then
            ProcessPostEffects(Workspace.CurrentCamera)
        end

        if State.NoSleepScreen then
            local cam = Workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
            for g in pairs(SleepBlackouts) do
                if not g or not g.Parent then
                    SleepBlackouts[g] = nil
                elseif g.Visible then
                    local isBig = (g.AbsoluteSize.X >= vp.X * 0.75 and g.AbsoluteSize.Y >= vp.Y * 0.75) or (g.Size.X.Scale >= 0.85 and g.Size.Y.Scale >= 0.85)
                    if isBig then
                        if g:IsA("Frame") then
                            local c = g.BackgroundColor3
                            if c.R < 0.22 and c.G < 0.22 and c.B < 0.22 and g.BackgroundTransparency < 0.98 then
                                g.BackgroundTransparency = 1
                            end
                        elseif g:IsA("ImageLabel") then
                            local ic, bc = g.ImageColor3, g.BackgroundColor3
                            if ic.R < 0.25 and ic.G < 0.25 and ic.B < 0.25 and g.ImageTransparency < 0.98 then
                                g.ImageTransparency = 1
                            end
                            if bc.R < 0.22 and bc.G < 0.22 and bc.B < 0.22 and g.BackgroundTransparency < 0.98 then
                                g.BackgroundTransparency = 1
                            end
                        elseif g:IsA("CanvasGroup") and g.GroupTransparency < 0.98 then
                            local c = g.GroupColor3
                            if c.R < 0.25 and c.G < 0.25 and c.B < 0.25 then
                                g.GroupTransparency = 1
                            end
                        end
                    end
                end
            end
        end
    end))

    task.spawn(function()
        while State.Active do
            pcall(function()
                if State.UnlockCamera then
                    wasUnlockCam = true
                    LocalPlayer.CameraMaxZoomDistance = 100000
                    LocalPlayer.CameraMinZoomDistance = 0.5
                    LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
                elseif wasUnlockCam then
                    wasUnlockCam = false
                    LocalPlayer.CameraMaxZoomDistance = LO.MaxZoom
                    LocalPlayer.CameraMinZoomDistance = LO.MinZoom
                    LocalPlayer.DevCameraOcclusionMode = LO.Occlusion
                end

                if State.NightVision then
                    wasNightVision = true
                    Lighting.Ambient = Color3.fromRGB(230, 230, 230)
                    Lighting.OutdoorAmbient = Color3.fromRGB(230, 230, 230)
                    Lighting.Brightness = 3
                    Lighting.ClockTime = 14
                    Lighting.FogEnd = 100000
                    Lighting.GlobalShadows = false
                    Lighting.ExposureCompensation = 0.5
                    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
                    if atmo then atmo.Density = 0; atmo.Haze = 0 end
                elseif wasNightVision then
                    wasNightVision = false
                    Visuals.RestoreLighting()
                end
            end)
            task.wait(0.3)
        end
    end)
end

function Visuals.RestoreLighting()
    pcall(function()
        Lighting.Ambient = LO.Ambient; Lighting.OutdoorAmbient = LO.OutdoorAmbient
        Lighting.Brightness = LO.Brightness; Lighting.GlobalShadows = LO.GlobalShadows
        Lighting.ClockTime = LO.ClockTime; Lighting.FogEnd = LO.FogEnd; Lighting.FogStart = LO.FogStart
        Lighting.ExposureCompensation = LO.ExposureCompensation
        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmo then atmo.Density = LO.AtmoDensity; atmo.Haze = LO.AtmoHaze end
    end)
end

function Visuals.Restore()
    Visuals.RestoreLighting()
    pcall(function()
        LocalPlayer.CameraMaxZoomDistance = LO.MaxZoom
        LocalPlayer.CameraMinZoomDistance = LO.MinZoom
        LocalPlayer.DevCameraOcclusionMode = LO.Occlusion
    end)
end

-- 4. Survival (Auto Clean)
local Survival = {}
local DataRemote = nil
local function FindDataRemote()
    if DataRemote and DataRemote.Parent then return DataRemote end
    local found = ReplicatedStorage:FindFirstChild("dataRemoteEvent", true)
    if found and found:IsA("RemoteEvent") then DataRemote = found; return found end
    return nil
end
function Survival.Init()
    task.spawn(function()
        while State.Active do
            if State.AutoClean then
                pcall(function()
                    if Env.PE_CapturedCleanPacket and Env.PE_CapturedCleanPacket.Remote then
                        Env.PE_CapturedCleanPacket.Remote:FireServer(table.unpack(Utils.DeepClone(Env.PE_CapturedCleanPacket.Args)))
                    else
                        local rem = FindDataRemote()
                        if rem then
                            local packet = {
                                [1] = { [1] = CLEAN_PREFIX_BYTE, [2] = CLEAN_BRIDGE_ID, [3] = { DEFAULT_WATER_COORDS[1], DEFAULT_WATER_COORDS[2], DEFAULT_WATER_COORDS[3] } },
                                [2] = CLEAN_ACTION_BYTE
                            }
                            rem:FireServer(packet)
                        end
                    end
                end)
            end
            task.wait(1.2)
        end
    end)
end

-- 5. Save Dino
local SaveDino = { Pad = nil }
local function ensurePad()
    if SaveDino.Pad and SaveDino.Pad.Parent then return SaveDino.Pad end
    local p = Instance.new("Part"); p.Name = "PE_UPad"; p.Size = Vector3.new(60, 3, 60)
    p.Anchored = true; p.CanCollide = true; p.Transparency = 0.85; p.Color = Color3.fromRGB(30, 30, 35)
    p.Parent = Workspace; SaveDino.Pad = p; return p
end
local function killPad() if SaveDino.Pad then pcall(function() SaveDino.Pad:Destroy() end) SaveDino.Pad = nil end end
local function noclip(c, en)
    if not c then return end
    if en then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                if State.SaveDinoCollisions[p] == nil then State.SaveDinoCollisions[p] = p.CanCollide end
                p.CanCollide = false
            end
        end
    else
        for p, o in pairs(State.SaveDinoCollisions) do if p and p.Parent then pcall(function() p.CanCollide = o end) end end
        table.clear(State.SaveDinoCollisions)
    end
end
local function zero(c)
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.AssemblyLinearVelocity = Vector3.zero; p.AssemblyAngularVelocity = Vector3.zero end) end end
end
local function feetOff(c)
    local ok, _, sz = pcall(function() return c:GetBoundingBox() end)
    if ok and sz then return math.clamp(sz.Y * 0.5, 3, 25) end
    return 6
end
function SaveDino.RecalculateTarget()
    if not State.SaveDinoOriginalCFrame then return end
    local y = (State.SaveDinoMode == "Down") and -State.SaveDinoOffset or (State.SaveDinoOffset * 4)
    State.SaveDinoTargetCFrame = State.SaveDinoOriginalCFrame + Vector3.new(0, y, 0)
end
function SaveDino.SetEnabled(en)
    State.SaveDinoEnabled = en; local c = LocalPlayer.Character
    if not c then State.SaveDinoPhase = "idle"; return end
    if en then
        if State.SaveDinoPhase == "idle" or not State.SaveDinoOriginalCFrame then
            local ok, pv = pcall(function() return c:GetPivot() end)
            if not ok or not pv then Utils.Notify("Save Dino", "Позиция не определена"); State.SaveDinoEnabled = false; return end
            State.SaveDinoOriginalCFrame = pv; State.SaveDinoCurrentCFrame = pv
        end
        SaveDino.RecalculateTarget(); State.SaveDinoPhase = "moving_to_safe"
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Freefall, false); h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end) end
        ensurePad(); Utils.Notify("Save Dino", "Погружение...")
    elseif State.SaveDinoPhase ~= "idle" then
        State.SaveDinoPhase = "returning"; Utils.Notify("Save Dino", "Возврат...")
    end
end
function SaveDino.ForceReset()
    State.SaveDinoEnabled = false; State.SaveDinoPhase = "idle"; local c = LocalPlayer.Character
    if c then
        noclip(c, false); zero(c)
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Freefall, true); h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true); h:ChangeState(Enum.HumanoidStateType.Running) end) end
    end
    State.SaveDinoOriginalCFrame = nil; State.SaveDinoTargetCFrame = nil; State.SaveDinoCurrentCFrame = nil; killPad()
end
function SaveDino.Init()
    Utils.Track(LocalPlayer.CharacterAdded:Connect(function() SaveDino.ForceReset() end))
    Utils.Track(RunService.Heartbeat:Connect(function(dt)
        if State.SaveDinoPhase == "idle" then return end
        local c = LocalPlayer.Character; if not c or not c.Parent then SaveDino.ForceReset(); return end
        local ok, cur = pcall(function() return c:GetPivot() end) if not ok or not cur then return end
        if not State.SaveDinoCurrentCFrame then State.SaveDinoCurrentCFrame = cur end
        local pad = ensurePad(); local fo = feetOff(c)
        if State.SaveDinoPhase == "moving_to_safe" then
            noclip(c, true)
            local df = State.SaveDinoTargetCFrame.Position - State.SaveDinoCurrentCFrame.Position
            local di = df.Magnitude; local st = math.min(di, 120 * dt)
            if di <= 1.5 then State.SaveDinoCurrentCFrame = State.SaveDinoTargetCFrame; State.SaveDinoPhase = "holding"; Utils.Notify("Save Dino", "В безопасности")
            else State.SaveDinoCurrentCFrame = State.SaveDinoCurrentCFrame + df.Unit * st end
            pad.CFrame = CFrame.new(State.SaveDinoCurrentCFrame.Position - Vector3.new(0, fo, 0))
            pcall(function() c:PivotTo(State.SaveDinoCurrentCFrame) end); zero(c)
        elseif State.SaveDinoPhase == "holding" then
            noclip(c, true); pad.CFrame = CFrame.new(State.SaveDinoTargetCFrame.Position - Vector3.new(0, fo, 0))
            pcall(function() c:PivotTo(State.SaveDinoTargetCFrame) end); zero(c)
        elseif State.SaveDinoPhase == "returning" then
            noclip(c, true); local sf = State.SaveDinoOriginalCFrame + Vector3.new(0, 2.5, 0)
            local df = sf.Position - State.SaveDinoCurrentCFrame.Position; local di = df.Magnitude; local st = math.min(di, 110 * dt)
            if di <= 1.5 then noclip(c, false); pcall(function() c:PivotTo(sf) end); zero(c); SaveDino.ForceReset(); Utils.Notify("Save Dino", "На поверхности!")
            else
                State.SaveDinoCurrentCFrame = State.SaveDinoCurrentCFrame + df.Unit * st
                pad.CFrame = CFrame.new(State.SaveDinoCurrentCFrame.Position - Vector3.new(0, fo, 0))
                pcall(function() c:PivotTo(State.SaveDinoCurrentCFrame) end); zero(c)
            end
        end
    end))
end

-- 6. Combat (Ультра-легкий Silent Aim без GetDescendants в хуке и без пересчета физики каждого кадра)
local Combat = {}
local ZP = PhysicalProperties.new(0.0001, 0, 0, 0, 0)
local CachedLocalGroups = nil

local function matchCat(partName, fullTail)
    local l = string.lower(partName)
    for _, c in ipairs({ "Jaw", "Neck", "Head", "Tail", "Leg", "Body" }) do
        for _, p in ipairs(PartPatterns[c]) do
            if string.find(l, p, 1, true) then
                if c == "Tail" and not fullTail then
                    if string.find(l, "tip", 1, true) or string.match(l, "tail[_%s]*[3-9]") then
                        return nil
                    end
                end
                return c
            end
        end
    end
    return nil
end

local function isLocal(m)
    return LocalPlayer.Character and (m == LocalPlayer.Character or m:IsDescendantOf(LocalPlayer.Character))
end

local function isCritRoot(model, part)
    if not part or not model then return true end
    local l = string.lower(part.Name)
    if l == "humanoidrootpart" or l == "rootpart" or l == "root" or l == "primary" or model.PrimaryPart == part then
        return true
    end
    local ok, ar = pcall(function() return part.AssemblyRootPart end)
    return ok and ar == part
end

-- МГНОВЕННЫЙ поиск целевой детали ТОЛЬКО по готовому кэшу (0 вызовов GetDescendants внутри хука = 0 лагов!)
local function findStrictTargetPartFast(model, cat)
    local c = State.CachedModels[model]
    if not c then return nil end
    if c[cat] then
        for _, p in ipairs(c[cat]) do
            if p and p.Parent then return p end
        end
    end
    if (cat == "Jaw" or cat == "Neck") and c.Head and c.Head[1] then
        return c.Head[1]
    elseif cat == "Head" and c.Jaw and c.Jaw[1] then
        return c.Jaw[1]
    end
    return nil
end

-- Мгновенная проверка: принадлежит ли деталь врагу из нашего кэша (за O(1) без циклов while)
local PartToEnemyModel = setmetatable({}, { __mode = "k" })
local PartToCategory = setmetatable({}, { __mode = "k" })

local function getEnemyFast(part)
    if not part then return nil end
    local cached = PartToEnemyModel[part]
    if cached and cached.Parent then return cached end
    return nil
end

function Combat.ScanModel(model, isSelf)
    local cats = { Head = {}, Neck = {}, Jaw = {}, Body = {}, Tail = {}, Leg = {} }
    local added = { Head = {}, Neck = {}, Jaw = {}, Body = {}, Tail = {}, Leg = {} }

    local function addUnique(cat, part)
        if cats[cat] and not added[cat][part] then
            added[cat][part] = true
            table.insert(cats[cat], part)
            if not isSelf then
                PartToEnemyModel[part] = model
                if not PartToCategory[part] then
                    PartToCategory[part] = cat
                end
            end
        end
    end

    pcall(function()
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") and not isCritRoot(model, d) then
                if not isSelf then PartToEnemyModel[d] = model end
                local c = matchCat(d.Name, isSelf)
                if c and cats[c] then
                    addUnique(c, d)
                end
                if isSelf and d:FindFirstChildOfClass("TouchTransmitter") then
                    addUnique("Jaw", d)
                end
            end
        end

        if #cats.Jaw == 0 and #cats.Head > 0 then
            for _, hp in ipairs(cats.Head) do addUnique("Jaw", hp) end
        elseif #cats.Head == 0 and #cats.Jaw > 0 then
            for _, jp in ipairs(cats.Jaw) do addUnique("Head", jp) end
        end
        if #cats.Neck == 0 and #cats.Head > 0 then
            for _, hp in ipairs(cats.Head) do addUnique("Neck", hp) end
        end

        if #cats.Body == 0 then
            for _, d in ipairs(model:GetDescendants()) do
                if d:IsA("BasePart") and not isCritRoot(model, d) then
                    local n = string.lower(d.Name)
                    if string.find(n, "hit", 1, true) or string.find(n, "spine", 1, true) or string.find(n, "rib", 1, true) or string.find(n, "torso", 1, true) then
                        addUnique("Body", d)
                    end
                end
            end
        end
    end)
    return cats
end

local function GetProportionalSize(origSize, targetRange)
    if targetRange < 0 then
        return origSize * math.abs(targetRange)
    end
    local maxAxis = math.max(origSize.X, origSize.Y, origSize.Z, 0.5)
    local ratio = Vector3.new(
        math.clamp(origSize.X / maxAxis, 0.72, 1.0),
        math.clamp(origSize.Y / maxAxis, 0.72, 1.0),
        math.clamp(origSize.Z / maxAxis, 0.72, 1.0)
    )
    return ratio * targetRange
end

local function IsCleanBridgePacket(arg1)
    if type(arg1) ~= "table" then return false end
    if arg1[2] == CLEAN_ACTION_BYTE then return true end
    local inner = arg1[1]
    if type(inner) == "table" and inner[2] == CLEAN_BRIDGE_ID then return true end
    if type(inner) == "table" and inner[1] == CLEAN_PREFIX_BYTE and type(inner[3]) == "table" and type(inner[3][1]) == "number" and type(inner[3][2]) == "number" and type(inner[3][3]) == "number" then
        return true
    end
    return false
end

-- Ультра-быстрый обработчик таблиц в __namecall:
-- Игнорирует обычные пакеты ходьбы/камеры и срабатывает ТОЛЬКО тогда, когда в пакете реально передан BasePart врага!
local function ProcessFastSilentAimTable(tbl, aimCat, depth)
    if depth > 4 then return false, false end
    local changed = false
    local shouldCancel = false
    local resolvedTargetPart = nil

    for k, v in pairs(tbl) do
        local tv = typeof(v)
        if tv == "Instance" then
            if v:IsA("BasePart") then
                local em = getEnemyFast(v)
                if em then
                    local hitCat = PartToCategory[v] or matchCat(v.Name, false)
                    if hitCat == aimCat then
                        resolvedTargetPart = v
                    else
                        local tp = findStrictTargetPartFast(em, aimCat)
                        if tp then
                            tbl[k] = tp
                            resolvedTargetPart = tp
                            changed = true
                        else
                            shouldCancel = true
                        end
                    end
                end
            end
        elseif tv == "table" then
            local subChanged, subCancel = ProcessFastSilentAimTable(v, aimCat, depth + 1)
            if subChanged then changed = true end
            if subCancel then shouldCancel = true end
        end
    end

    if resolvedTargetPart then
        for k, v in pairs(tbl) do
            local tv = typeof(v)
            if tv == "Vector3" then
                tbl[k] = resolvedTargetPart.Position
                changed = true
            elseif tv == "CFrame" then
                tbl[k] = resolvedTargetPart.CFrame
                changed = true
            elseif tv == "string" and #v >= 3 and #v <= 20 then
                local sc = matchCat(v, false)
                if sc and sc ~= aimCat then
                    tbl[k] = resolvedTargetPart.Name
                    changed = true
                end
            end
        end
    end

    return changed, shouldCancel
end

if not Env.PriorUI_HookInstalled then
    pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            local cs = Env.PriorUI_State
            if not (cs and cs.Active) then return old(self, ...) end
            local m = getnamecallmethod()
            if m == "FireServer" or m == "InvokeServer" then
                local rName = tostring(self.Name)

                if cs.SaveDinoPhase ~= "idle" and string.find(string.lower(rName), "fall", 1, true) then
                    return nil
                end

                local args = { ... }

                if m == "FireServer" and rName == "dataRemoteEvent" and not Env.PE_CapturedCleanPacket then
                    if IsCleanBridgePacket(args[1]) then
                        Env.PE_CapturedCleanPacket = { Remote = self, Args = Utils.DeepClone(args) }
                    end
                end

                if cs.SilentAim then
                    local modified = false
                    local cancelAttack = false
                    for i = 1, #args do
                        local arg = args[i]
                        local ta = typeof(arg)
                        if ta == "Instance" and arg:IsA("BasePart") then
                            local em = getEnemyFast(arg)
                            if em then
                                local hitCat = PartToCategory[arg] or matchCat(arg.Name, false)
                                if hitCat ~= cs.AimTargetPart then
                                    local tp = findStrictTargetPartFast(em, cs.AimTargetPart)
                                    if tp then
                                        args[i] = tp
                                        modified = true
                                    else
                                        cancelAttack = true
                                    end
                                end
                            end
                        elseif ta == "table" then
                            local subMod, subCancel = ProcessFastSilentAimTable(arg, cs.AimTargetPart, 1)
                            if subMod then modified = true end
                            if subCancel then cancelAttack = true end
                        end
                    end

                    if cancelAttack and cs.StrictCancelNonTarget then
                        return nil
                    end
                    if modified then
                        return old(self, table.unpack(args))
                    end
                end
            end
            return old(self, ...)
        end)
        Env.PriorUI_HookInstalled = true
    end)
end

function Combat.RestoreEnemyParts()
    for p, o in pairs(State.OriginalParts) do
        pcall(function()
            if p and p.Parent then
                p.Size = o.Size; p.Transparency = o.Transparency; p.CanCollide = o.CanCollide
                p.CanQuery = o.CanQuery; p.CanTouch = o.CanTouch; p.Massless = o.Massless
                p.CustomPhysicalProperties = o.CustomPhysicalProperties; p.RootPriority = o.RootPriority
            end
        end)
    end
    table.clear(State.OriginalParts)
    State.NeedsEnemyRestore = false
end

function Combat.RestoreLocalParts()
    for p, o in pairs(State.LocalOriginalParts) do
        pcall(function()
            if p and p.Parent then
                p.Size = o.Size; p.Transparency = o.Transparency
                if State.SaveDinoPhase == "idle" then p.CanCollide = o.CanCollide end
                p.CanQuery = o.CanQuery; p.CanTouch = o.CanTouch; p.Massless = o.Massless
                p.CustomPhysicalProperties = o.CustomPhysicalProperties; p.RootPriority = o.RootPriority
            end
        end)
    end
    table.clear(State.LocalOriginalParts)
    State.NeedsLocalRestore = false
end

function Combat.RestoreAll()
    Combat.RestoreEnemyParts()
    Combat.RestoreLocalParts()
end

function Combat.Init()
    task.spawn(function()
        while State.Active do
            pcall(function()
                if State.HitboxMaster or State.SilentAim then
                    local nc = {}
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            nc[p.Character] = Combat.ScanModel(p.Character, false)
                        end
                    end
                    State.CachedModels = nc
                end

                if State.ReachEnabled then
                    local myChar = LocalPlayer.Character
                    if myChar then
                        CachedLocalGroups = Combat.ScanModel(myChar, true)
                    else
                        CachedLocalGroups = nil
                    end
                end
            end)
            task.wait(1.5)
        end
    end)

    -- Умное удержание без лишней перезаписи .Size (полное отсутствие лагов физики!)
    local lastApply = 0
    Utils.Track(RunService.Heartbeat:Connect(function()
        if not State.Active then return end
        local now = os.clock()
        if (now - lastApply) < 0.12 then return end
        lastApply = now

        if State.NeedsEnemyRestore then Combat.RestoreEnemyParts() end
        if State.NeedsLocalRestore then Combat.RestoreLocalParts() end

        if State.HitboxMaster or (State.SilentAim and State.StrictCancelNonTarget) then
            local tSize = HitboxSizes[State.HitboxSizeLevel] or 25
            local aimCat = State.AimTargetPart

            for model, groups in pairs(State.CachedModels) do
                if model and model.Parent and not isLocal(model) then
                    for cat, parts in pairs(groups) do
                        local expandThisCat = State.HitboxMaster and (State.EnemyHitboxParts[cat] == true)
                        local isAimTargetCat = State.SilentAim and (cat == aimCat)
                        local disableNonTargetTouch = State.SilentAim and State.StrictCancelNonTarget and (not isAimTargetCat) and (not expandThisCat)

                        if expandThisCat or isAimTargetCat or disableNonTargetTouch then
                            for idx, part in ipairs(parts) do
                                if part and part.Parent and not isCritRoot(model, part) then
                                    local o = State.OriginalParts[part]
                                    if not o then
                                        o = {
                                            Size = part.Size, Transparency = part.Transparency, CanCollide = part.CanCollide,
                                            CanQuery = part.CanQuery, CanTouch = part.CanTouch, Massless = part.Massless,
                                            CustomPhysicalProperties = part.CustomPhysicalProperties, RootPriority = part.RootPriority
                                        }
                                        State.OriginalParts[part] = o
                                    end

                                    if expandThisCat and idx <= 6 then
                                        local targetVec = GetProportionalSize(o.Size, tSize)
                                        if (part.Size - targetVec).Magnitude > 0.1 then
                                            part.Massless = true
                                            part.CanCollide = false
                                            part.CustomPhysicalProperties = ZP
                                            part.RootPriority = -127
                                            part.Size = targetVec
                                        end
                                        if math.abs(part.Transparency - State.HitboxTransparency) > 0.02 then
                                            part.Transparency = State.HitboxTransparency
                                        end
                                        if not part.CanTouch then part.CanTouch = true end
                                        if not part.CanQuery then part.CanQuery = true end
                                    elseif disableNonTargetTouch then
                                        -- Только выключаем CanTouch/CanQuery 1 раз, НЕ дергая part.Size каждый тик!
                                        if part.CanTouch then part.CanTouch = false end
                                        if part.CanQuery then part.CanQuery = false end
                                    elseif isAimTargetCat then
                                        if not part.CanTouch then part.CanTouch = true end
                                        if not part.CanQuery then part.CanQuery = true end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if State.ReachEnabled and CachedLocalGroups then
            local myChar = LocalPlayer.Character
            if myChar and myChar.Parent then
                local targetRange = ReachRanges[State.ReachScaleLevel] or 22
                for cat, parts in pairs(CachedLocalGroups) do
                    if State.ReachParts[cat] == true then
                        for _, part in ipairs(parts) do
                            if part and part.Parent and not isCritRoot(myChar, part) then
                                local orig = State.LocalOriginalParts[part]
                                if not orig then
                                    orig = {
                                        Size = part.Size, Transparency = part.Transparency, CanCollide = part.CanCollide,
                                        CanQuery = part.CanQuery, CanTouch = part.CanTouch, Massless = part.Massless,
                                        CustomPhysicalProperties = part.CustomPhysicalProperties, RootPriority = part.RootPriority
                                    }
                                    State.LocalOriginalParts[part] = orig
                                end
                                local targetVec = GetProportionalSize(orig.Size, targetRange)
                                if (part.Size - targetVec).Magnitude > 0.1 then
                                    part.Massless = true
                                    part.CanCollide = false
                                    part.CustomPhysicalProperties = ZP
                                    part.RootPriority = -127
                                    part.Size = targetVec
                                end
                                if math.abs(part.Transparency - State.ReachTransparency) > 0.02 then
                                    part.Transparency = State.ReachTransparency
                                end
                                if not part.CanTouch then part.CanTouch = true end
                                if not part.CanQuery then part.CanQuery = true end
                            end
                        end
                    end
                end
            end
        end
    end))

    task.spawn(function()
        while State.Active do
            if State.NoAttackCD then
                pcall(function()
                    local ch = LocalPlayer.Character
                    if ch then
                        for _, inst in ipairs({ ch, LocalPlayer }) do
                            local ok, at = pcall(function() return inst:GetAttributes() end)
                            if ok and type(at) == "table" then
                                for k, v in pairs(at) do
                                    local kn = string.lower(k)
                                    if (string.find(kn, "cooldown", 1, true) or string.find(kn, "attackcd", 1, true) or string.find(kn, "bitecd", 1, true) or string.find(kn, "debounce", 1, true)) and type(v) == "number" then inst:SetAttribute(k, 0)
                                    elseif (kn == "canattack" or kn == "canbite") and type(v) == "boolean" then inst:SetAttribute(k, true) end
                                end
                            end
                        end
                    end
                end)
            end
            task.wait(0.12)
        end
    end)
end

-- 7. ESP
local ESPModule = {}
local espGuis, worldGuis, trackedWorld, stamTrack, headCache, speciesCache = {}, {}, {}, {}, {}, {}
local worldScanDone, worldScanning = false, false
local ESPFolder = Instance.new("Folder"); ESPFolder.Name = "PE_ESP_Container"; pcall(function() ESPFolder.Parent = Utils.GuiParent() end)

local function getESPHead(c)
    if not c or not c:IsA("Model") then return nil end
    if headCache[c] and headCache[c].Parent then return headCache[c] end
    local h = c:FindFirstChild("Head", true)
    if h and h:IsA("BasePart") then headCache[c] = h; return h end
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") and string.find(string.lower(d.Name), "head", 1, true) then
            headCache[c] = d; return d
        end
    end
    local fb = c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart", true)
    headCache[c] = fb
    return fb
end

local function getDinoRoot(c)
    if not c then return nil end
    return c.PrimaryPart or c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("RootPart") or getESPHead(c)
end

local function ExtractNumber(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v) or tonumber(string.match(v, "[-]?%d+%.?%d*")) end
    return nil
end

local InvalidSpeciesWords = {
    ["rig"] = true, ["model"] = true, ["default"] = true, ["male"] = true, ["female"] = true,
    ["adult"] = true, ["juvenile"] = true, ["baby"] = true, ["subadult"] = true, ["hatchling"] = true,
    ["hitboxes"] = true, ["hitbox"] = true, ["parts"] = true, ["character"] = true, ["humanoid"] = true,
    ["custom"] = true, ["none"] = true, ["null"] = true, ["true"] = true, ["false"] = true,
    ["alive"] = true, ["dead"] = true, ["herbivore"] = true, ["carnivore"] = true, ["omnivore"] = true,
}

local function CleanSpeciesString(raw, player)
    if type(raw) ~= "string" then return nil end
    local s = string.gsub(raw, "^%s+", ""):gsub("%s+$", "")
    if #s < 3 or #s > 32 then return nil end
    if s == player.Name or s == player.DisplayName then return nil end
    if tonumber(s) then return nil end

    s = string.gsub(s, player.Name, "")
    s = string.gsub(s, "^[%s_%-]+", ""):gsub("[%s_%-]+$", "")

    local low = string.lower(s)
    if InvalidSpeciesWords[low] then return nil end
    if string.find(low, "hitbox", 1, true) or string.find(low, "rig", 1, true) or string.find(low, "effect", 1, true) or string.find(low, "saddle", 1, true) or string.find(low, "anim", 1, true) then
        return nil
    end
    return s
end

local ExactSpeciesKeys = {
    "dinosaur", "species", "dinoname", "dinosaur_name", "speciesname", "currentdino",
    "selecteddino", "selecteddinosaur", "creature", "creaturename", "playable", "dino"
}

local function GetDinoSpeciesName(player, model)
    if not model then return nil end
    if speciesCache[model] and (os.clock() - speciesCache[model].time) < 5.0 then
        return speciesCache[model].name
    end

    local foundName = nil

    for _, inst in ipairs({ model, player, model:FindFirstChildOfClass("Humanoid") }) do
        if inst and not foundName then
            local ok, attrs = pcall(function() return inst:GetAttributes() end)
            if ok and type(attrs) == "table" then
                for _, targetKey in ipairs(ExactSpeciesKeys) do
                    for k, v in pairs(attrs) do
                        if string.lower(k) == targetKey or string.find(string.lower(k), targetKey, 1, true) then
                            local cleaned = CleanSpeciesString(v, player)
                            if cleaned then foundName = cleaned; break end
                        end
                    end
                    if foundName then break end
                end
            end
        end
    end

    if not foundName then
        for _, cont in ipairs({
            model, player,
            player:FindFirstChild("Data"), player:FindFirstChild("PlayerData"),
            player:FindFirstChild("Stats"), player:FindFirstChild("leaderstats"),
            model:FindFirstChild("Data"), model:FindFirstChild("Stats")
        }) do
            if cont and not foundName then
                for _, obj in ipairs(cont:GetChildren()) do
                    local on = string.lower(obj.Name)
                    for _, targetKey in ipairs(ExactSpeciesKeys) do
                        if on == targetKey or string.find(on, targetKey, 1, true) then
                            if obj:IsA("StringValue") then
                                local cleaned = CleanSpeciesString(obj.Value, player)
                                if cleaned then foundName = cleaned; break end
                            elseif obj:IsA("ObjectValue") and obj.Value then
                                local cleaned = CleanSpeciesString(obj.Value.Name, player)
                                if cleaned then foundName = cleaned; break end
                            end
                        end
                    end
                    if foundName then break end
                end
            end
        end
    end

    if not foundName then
        local cleanedModelName = CleanSpeciesString(model.Name, player)
        if cleanedModelName then foundName = cleanedModelName end
    end

    if not foundName then
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum then
            local cleanedHum = CleanSpeciesString(hum.DisplayName, player)
            if cleanedHum then foundName = cleanedHum end
        end
    end

    speciesCache[model] = { name = foundName, time = os.clock() }
    return foundName
end

local function GetDinoStats(player, model, headPart)
    local hp, maxHp = 100, 100
    local realStam, realMaxStam = nil, nil
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then hp = hum.Health; maxHp = hum.MaxHealth end

    local function CheckKV(rawName, rawVal)
        local num = ExtractNumber(rawVal); if not num then return end
        local n = string.lower(tostring(rawName))
        if n == "health" or n == "hp" or n == "currenthealth" then hp = num
        elseif n == "maxhealth" or n == "maxhp" then if num > 0 then maxHp = num end
        elseif string.find(n, "maxstam", 1, true) or string.find(n, "max_stamina", 1, true) or string.find(n, "maxenergy", 1, true) then if num > 0 then realMaxStam = num end
        elseif string.find(n, "stam", 1, true) or n == "energy" or n == "currentstamina" then realStam = num end
    end

    for _, inst in ipairs({ model, hum, player }) do
        if inst then
            local ok, attrs = pcall(function() return inst:GetAttributes() end)
            if ok and type(attrs) == "table" then for k, v in pairs(attrs) do CheckKV(k, v) end end
        end
    end
    for _, obj in ipairs(model:GetChildren()) do if obj:IsA("ValueBase") then pcall(function() CheckKV(obj.Name, obj.Value) end) end end

    if not maxHp or maxHp <= 0 then maxHp = math.max(hp, 100) end
    local maxStam = (realMaxStam and realMaxStam > 0) and realMaxStam or 100

    local movePart = getDinoRoot(model) or headPart
    local now = os.clock()
    local pos = movePart and movePart.Position or Vector3.zero
    local track = stamTrack[player]

    if not track or track.char ~= model then
        track = { char = model, stam = maxStam, smoothSpeed = 0, lastTime = now, lastPos = pos, lastSprintTime = 0, srvChanged = false, initSrv = realStam }
        stamTrack[player] = track
    else
        if realStam and track.initSrv and math.abs(realStam - track.initSrv) > 0.5 then track.srvChanged = true end
        if track.srvChanged and realStam then
            track.stam = math.clamp(realStam, 0, maxStam)
            track.lastTime = now; track.lastPos = pos
            return hp, maxHp, track.stam, maxStam
        end
        local dt = math.clamp(now - track.lastTime, 0.05, 1.0)
        local distMoved = Vector3.new(pos.X - track.lastPos.X, 0, pos.Z - track.lastPos.Z).Magnitude
        local posSpeed = distMoved / dt
        if posSpeed > 150 then posSpeed = 0 end
        track.smoothSpeed = (track.smoothSpeed * 0.65) + (posSpeed * 0.35)
        local speed = track.smoothSpeed
        if speed > 29 then
            track.stam = math.clamp(track.stam - (maxStam * 0.024 * dt), 0, maxStam)
            track.lastSprintTime = now
        else
            if (now - (track.lastSprintTime or 0)) >= 3.0 then
                if speed > 6 then track.stam = math.clamp(track.stam + (maxStam * 0.004 * dt), 0, maxStam)
                else track.stam = math.clamp(track.stam + (maxStam * 0.014 * dt), 0, maxStam) end
            end
        end
        track.lastTime = now; track.lastPos = pos
    end
    return hp, maxHp, track.stam, maxStam
end

local function GetMyPosition()
    local myChar = LocalPlayer.Character
    if myChar then local ok, pivot = pcall(function() return myChar:GetPivot().Position end) if ok and pivot then return pivot end end
    return Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position or Vector3.zero
end
local function IsPartOfPlayerCharacter(obj)
    for _, p in ipairs(Players:GetPlayers()) do if p.Character and (obj == p.Character or obj:IsDescendantOf(p.Character)) then return true end end
    return false
end

local BoneKeywords = { "fossil", "bone", "skeleton", "amber", "relic", "digsite", "dig_site", "excavat", "skull", "remains" }
local CorpseKeywords = { "carcass", "corpse", "deadbody", "dead_body", "meat", "gore", "chunk", "edible", "food", "prey", "ribcage", "flesh", "steak" }
local IgnoredFolders = { trees = true, foliage = true, rocks = true, grass = true, plants = true, leaves = true, clouds = true, lighting = true, water = true }

local function MatchCategoryFromText(tx)
    for _, k in ipairs(BoneKeywords) do if string.find(tx, k, 1, true) then return "Bone" end end
    for _, k in ipairs(CorpseKeywords) do if string.find(tx, k, 1, true) then return "Corpse" end end
    return nil
end

local function TryRegisterWorldObject(d)
    if not d or not d.Parent or d == SaveDino.Pad or IsPartOfPlayerCharacter(d) then return end
    if d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
        local target = d.Parent
        if not target or target == Workspace or trackedWorld[target] then return end
        local pName = target.Parent and target.Parent ~= Workspace and target.Parent.Name or ""
        local tx = string.lower(d.Name .. " " .. target.Name .. " " .. pName)
        if d:IsA("ProximityPrompt") then tx = tx .. " " .. string.lower(d.ActionText .. " " .. d.ObjectText) end
        local cat = MatchCategoryFromText(tx)
        if cat then
            local part = target:IsA("BasePart") and target or target:FindFirstAncestorWhichIsA("BasePart") or target:FindFirstChildWhichIsA("BasePart", true)
            if part then trackedWorld[target] = { Category = cat, Part = part } end
        end
        return
    end
    if d:IsA("Model") or d:IsA("BasePart") then
        local ancestorModel = d:FindFirstAncestorOfClass("Model")
        if ancestorModel and ancestorModel ~= Workspace and trackedWorld[ancestorModel] then return end
        local parentName = (d.Parent and d.Parent ~= Workspace) and string.lower(d.Parent.Name) or ""
        local grandParentName = (d.Parent and d.Parent.Parent and d.Parent.Parent ~= Workspace) and string.lower(d.Parent.Parent.Name) or ""
        local fullCheck = string.lower(d.Name) .. " " .. parentName .. " " .. grandParentName
        local cat = MatchCategoryFromText(fullCheck)
        if cat then
            local rootTarget = (d:IsA("BasePart") and ancestorModel and ancestorModel ~= Workspace and not IsPartOfPlayerCharacter(ancestorModel)) and ancestorModel or d
            if not trackedWorld[rootTarget] then
                local part = rootTarget:IsA("BasePart") and rootTarget or rootTarget.PrimaryPart or rootTarget:FindFirstChildWhichIsA("BasePart", true)
                if part then trackedWorld[rootTarget] = { Category = cat, Part = part } end
            end
        end
    end
end

function ESPModule.ScanWorldItems()
    if worldScanning then return end
    worldScanning = true
    task.spawn(function()
        local count = 0
        local function scanNode(node)
            local ok, ch = pcall(function() return node:GetChildren() end)
            if not ok or not ch then return end
            for _, child in ipairs(ch) do
                if not State.Active then return end
                count = count + 1
                if count % 200 == 0 then task.wait() end
                if child ~= Workspace.Terrain and not IsPartOfPlayerCharacter(child) then
                    TryRegisterWorldObject(child)
                    local cn = string.lower(child.Name)
                    if not IgnoredFolders[cn] and not trackedWorld[child] then scanNode(child) end
                end
            end
        end
        scanNode(Workspace)
        worldScanDone = true; worldScanning = false
    end)
end

function ESPModule.Cleanup()
    for _, data in pairs(espGuis) do if data.gui then pcall(function() data.gui:Destroy() end) end end
    for _, data in pairs(worldGuis) do if data.gui then pcall(function() data.gui:Destroy() end) end end
    table.clear(espGuis); table.clear(worldGuis); table.clear(stamTrack); table.clear(trackedWorld); table.clear(headCache); table.clear(speciesCache)
    if ESPFolder then pcall(function() ESPFolder:Destroy() end) end
end

function ESPModule.Init()
    Utils.Track(Players.PlayerRemoving:Connect(function(plr)
        if espGuis[plr] then if espGuis[plr].gui then pcall(function() espGuis[plr].gui:Destroy() end) end espGuis[plr] = nil end
        stamTrack[plr] = nil
    end))
    Utils.Track(Workspace.DescendantAdded:Connect(function(desc)
        if State.ESPBones or State.ESPCorpses then task.defer(function() pcall(TryRegisterWorldObject, desc) end) end
    end))

    task.spawn(function()
        while State.Active do
            pcall(function()
                local myPos = GetMyPosition()
                if not State.ESPEnabled then
                    for _, data in pairs(espGuis) do if data.gui and data.gui.Enabled then data.gui.Enabled = false end end
                else
                    for _, player in ipairs(Players:GetPlayers()) do
                        if player ~= LocalPlayer then
                            local char = player.Character; local targetPart = char and getESPHead(char)
                            if char and targetPart then
                                local dist = (myPos - targetPart.Position).Magnitude
                                if dist <= State.ESPMaxDistance then
                                    if not espGuis[player] or not espGuis[player].gui or not espGuis[player].gui.Parent then
                                        local billboard = Instance.new("BillboardGui"); billboard.Name = "PE_ESP_" .. player.Name
                                        billboard.Size = UDim2.fromOffset(180, 68)
                                        billboard.StudsOffset = Vector3.new(0, 5.5, 0)
                                        billboard.AlwaysOnTop = true; billboard.ResetOnSpawn = false; billboard.Enabled = false; billboard.Parent = ESPFolder

                                        local speciesLabel = Instance.new("TextLabel")
                                        speciesLabel.Size = UDim2.new(1, 0, 0, 15)
                                        speciesLabel.Position = UDim2.new(0, 0, 0, 0)
                                        speciesLabel.BackgroundTransparency = 1
                                        speciesLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
                                        speciesLabel.TextStrokeTransparency = 0.05
                                        speciesLabel.Font = Enum.Font.GothamBold
                                        speciesLabel.TextSize = 12
                                        speciesLabel.Parent = billboard

                                        local nameLabel = Instance.new("TextLabel")
                                        nameLabel.Size = UDim2.new(1, 0, 0, 15)
                                        nameLabel.Position = UDim2.new(0, 0, 0, 15)
                                        nameLabel.BackgroundTransparency = 1
                                        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                                        nameLabel.TextStrokeTransparency = 0.1
                                        nameLabel.Font = Enum.Font.GothamBold
                                        nameLabel.TextSize = 11
                                        nameLabel.Parent = billboard

                                        local hpBarBg = Instance.new("Frame"); hpBarBg.Size = UDim2.new(1, 0, 0, 14); hpBarBg.Position = UDim2.new(0, 0, 0, 32); hpBarBg.BackgroundColor3 = Color3.fromRGB(24, 24, 28); hpBarBg.BorderSizePixel = 0; hpBarBg.Parent = billboard; Utils.Style(hpBarBg, 4, Color3.fromRGB(0, 0, 0), 1)
                                        local hpBarFill = Instance.new("Frame"); hpBarFill.Size = UDim2.new(1, 0, 1, 0); hpBarFill.BackgroundColor3 = Color3.fromRGB(65, 235, 85); hpBarFill.BorderSizePixel = 0; hpBarFill.Parent = hpBarBg; Utils.Style(hpBarFill, 4, nil)
                                        local hpText = Instance.new("TextLabel"); hpText.Size = UDim2.fromScale(1, 1); hpText.BackgroundTransparency = 1; hpText.TextColor3 = Color3.fromRGB(255, 255, 255); hpText.TextStrokeTransparency = 0.05; hpText.Font = Enum.Font.GothamBold; hpText.TextSize = 10; hpText.ZIndex = 3; hpText.Parent = hpBarBg

                                        local stamBarBg = Instance.new("Frame"); stamBarBg.Size = UDim2.new(1, 0, 0, 14); stamBarBg.Position = UDim2.new(0, 0, 0, 49); stamBarBg.BackgroundColor3 = Color3.fromRGB(24, 24, 28); stamBarBg.BorderSizePixel = 0; stamBarBg.Parent = billboard; Utils.Style(stamBarBg, 4, Color3.fromRGB(0, 0, 0), 1)
                                        local stamBarFill = Instance.new("Frame"); stamBarFill.Size = UDim2.new(1, 0, 1, 0); stamBarFill.BackgroundColor3 = Color3.fromRGB(55, 170, 255); stamBarFill.BorderSizePixel = 0; stamBarFill.Parent = stamBarBg; Utils.Style(stamBarFill, 4, nil)
                                        local stamText = Instance.new("TextLabel"); stamText.Size = UDim2.fromScale(1, 1); stamText.BackgroundTransparency = 1; stamText.TextColor3 = Color3.fromRGB(255, 255, 255); stamText.TextStrokeTransparency = 0.05; stamText.Font = Enum.Font.GothamBold; stamText.TextSize = 10; stamText.ZIndex = 3; stamText.Parent = stamBarBg

                                        espGuis[player] = {
                                            gui = billboard, species = speciesLabel, name = nameLabel,
                                            hpBg = hpBarBg, hpFill = hpBarFill, hpText = hpText,
                                            stamBg = stamBarBg, stamFill = stamBarFill, stamText = stamText
                                        }
                                    end
                                    local data = espGuis[player]; data.gui.Adornee = targetPart
                                    local hp, maxHp, stam, maxStam = GetDinoStats(player, char, targetPart)
                                    local dinoName = State.ESP_Species and GetDinoSpeciesName(player, char) or nil
                                    local hpRatio = math.clamp(hp / maxHp, 0, 1); local stamRatio = math.clamp(stam / maxStam, 0, 1)

                                    if dinoName then
                                        data.species.Visible = true
                                        data.species.Text = "[" .. tostring(dinoName) .. "]"
                                    else
                                        data.species.Visible = false
                                    end

                                    data.name.Text = string.format("[%dm] %s", math.floor(dist), player.DisplayName or player.Name)

                                    data.hpBg.Visible = State.ESP_Health
                                    if State.ESP_Health then
                                        data.hpFill.Size = UDim2.new(hpRatio, 0, 1, 0); data.hpText.Text = string.format("HP: %d / %d", math.floor(hp + 0.5), math.floor(maxHp + 0.5))
                                        data.hpFill.BackgroundColor3 = (hpRatio < 0.3 and Color3.fromRGB(235, 65, 65)) or (hpRatio < 0.65 and Color3.fromRGB(240, 190, 50)) or Color3.fromRGB(60, 215, 80)
                                    end
                                    data.stamBg.Visible = State.ESP_Stamina
                                    if State.ESP_Stamina then
                                        data.stamFill.Size = UDim2.new(stamRatio, 0, 1, 0); data.stamText.Text = string.format("ST: %d / %d", math.floor(stam + 0.5), math.floor(maxStam + 0.5))
                                        data.stamFill.BackgroundColor3 = (stamRatio < 0.25 and Color3.fromRGB(245, 135, 45)) or Color3.fromRGB(50, 160, 245)
                                    end
                                    data.gui.Enabled = true
                                elseif espGuis[player] and espGuis[player].gui then espGuis[player].gui.Enabled = false end
                            elseif espGuis[player] and espGuis[player].gui then espGuis[player].gui.Enabled = false end
                        end
                    end
                end

                if State.ESPBones or State.ESPCorpses then
                    if not worldScanDone and not worldScanning then ESPModule.ScanWorldItems() end
                    for obj, info in pairs(trackedWorld) do
                        local part = info.Part
                        if not obj or not obj.Parent or not part or not part.Parent then
                            if worldGuis[obj] and worldGuis[obj].gui then pcall(function() worldGuis[obj].gui:Destroy() end) end
                            worldGuis[obj] = nil; trackedWorld[obj] = nil
                        else
                            local isBone = (info.Category == "Bone")
                            local show = (isBone and State.ESPBones) or (not isBone and State.ESPCorpses)
                            local dist = (myPos - part.Position).Magnitude
                            if show and dist <= State.WorldESPMaxDistance then
                                if not worldGuis[obj] or not worldGuis[obj].gui or not worldGuis[obj].gui.Parent then
                                    local bGui = Instance.new("BillboardGui"); bGui.Name = "PE_WorldESP"; bGui.Size = UDim2.fromOffset(150, 26); bGui.StudsOffset = Vector3.new(0, 2.5, 0); bGui.AlwaysOnTop = true; bGui.Parent = ESPFolder
                                    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1; lbl.TextStrokeTransparency = 0.1; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12; lbl.TextColor3 = isBone and Color3.fromRGB(255, 235, 150) or Color3.fromRGB(255, 110, 90); lbl.Parent = bGui
                                    worldGuis[obj] = { gui = bGui, label = lbl }
                                end
                                local wGui = worldGuis[obj]; wGui.gui.Adornee = part
                                wGui.label.Text = string.format("[%dm] %s", math.floor(dist), isBone and "КОСТЬ" or "ЕДА/ТРУП")
                                wGui.gui.Enabled = true
                            elseif worldGuis[obj] and worldGuis[obj].gui then worldGuis[obj].gui.Enabled = false end
                        end
                    end
                else
                    for _, gData in pairs(worldGuis) do if gData.gui and gData.gui.Enabled then gData.gui.Enabled = false end end
                end
            end)
            task.wait(0.28)
        end
    end)
end

-- 8. UI & Init
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name = "PriorExtinction_UI"; ScreenGui.ResetOnSpawn = false; ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; pcall(function() ScreenGui.Parent = Utils.GuiParent() end)
local TargetSize, IconSize = UDim2.fromOffset(530, 340), UDim2.fromOffset(50, 50)
local MainFrame = Instance.new("Frame"); MainFrame.AnchorPoint = Vector2.new(0.5, 0.5); MainFrame.Position = UDim2.fromScale(0.5, 0.5); MainFrame.Size = UDim2.fromOffset(0, 0); MainFrame.BackgroundColor3 = Theme.Background; MainFrame.ClipsDescendants = true; MainFrame.Parent = ScreenGui; Utils.Style(MainFrame, 12, Theme.Stroke, 1.2)
MainFrameRef = MainFrame
local TopBar = Instance.new("Frame"); TopBar.Size = UDim2.new(1, 0, 0, 42); TopBar.BackgroundColor3 = Theme.Surface; TopBar.Parent = MainFrame; Utils.Style(TopBar, 12, nil)
local TitleLabel = Instance.new("TextLabel"); TitleLabel.Size = UDim2.new(1, -120, 1, 0); TitleLabel.Position = UDim2.fromOffset(15, 0); TitleLabel.BackgroundTransparency = 1; TitleLabel.Text = "PRIOR EXTINCTION // ULTIMATE"; TitleLabel.TextColor3 = Theme.TextPrimary; TitleLabel.Font = Enum.Font.GothamBold; TitleLabel.TextSize = 13; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left; TitleLabel.Parent = TopBar
local MinimizeBtn = Instance.new("TextButton"); MinimizeBtn.Size = UDim2.fromOffset(32, 28); MinimizeBtn.Position = UDim2.new(1, -40, 0.5, -14); MinimizeBtn.BackgroundColor3 = Theme.Element; MinimizeBtn.Text = "—"; MinimizeBtn.TextColor3 = Theme.TextPrimary; MinimizeBtn.Font = Enum.Font.GothamBold; MinimizeBtn.TextSize = 14; MinimizeBtn.Parent = TopBar; Utils.Style(MinimizeBtn, 6, Theme.Stroke, 1)
local MiniIcon = Instance.new("TextButton"); MiniIcon.AnchorPoint = Vector2.new(0.5, 0.5); MiniIcon.Position = UDim2.new(0.1, 0, 0.2, 0); MiniIcon.Size = UDim2.fromOffset(0, 0); MiniIcon.BackgroundColor3 = Theme.Surface; MiniIcon.Text = "PE"; MiniIcon.TextColor3 = Theme.TextPrimary; MiniIcon.Font = Enum.Font.GothamBold; MiniIcon.TextSize = 14; MiniIcon.Visible = false; MiniIcon.Parent = ScreenGui; Utils.Style(MiniIcon, 25, Theme.Stroke, 1.5)
local Sidebar = Instance.new("Frame"); Sidebar.Size = UDim2.new(0, 145, 1, -42); Sidebar.Position = UDim2.fromOffset(0, 42); Sidebar.BackgroundColor3 = Theme.Surface; Sidebar.Parent = MainFrame
local TabList = Instance.new("ScrollingFrame"); TabList.Size = UDim2.new(1, -16, 1, -66); TabList.Position = UDim2.fromOffset(8, 10); TabList.BackgroundTransparency = 1; TabList.ScrollBarThickness = 0; TabList.CanvasSize = UDim2.new(0, 0, 0, 0); TabList.AutomaticCanvasSize = Enum.AutomaticSize.Y; TabList.Parent = Sidebar
local TabListLayout = Instance.new("UIListLayout"); TabListLayout.Padding = UDim.new(0, 6); TabListLayout.Parent = TabList
local DeactivateBtn = Instance.new("TextButton"); DeactivateBtn.Size = UDim2.new(1, -16, 0, 38); DeactivateBtn.Position = UDim2.new(0, 8, 1, -46); DeactivateBtn.BackgroundColor3 = Theme.Danger; DeactivateBtn.Text = "Deactivate"; DeactivateBtn.TextColor3 = Theme.TextPrimary; DeactivateBtn.Font = Enum.Font.GothamSemibold; DeactivateBtn.TextSize = 13; DeactivateBtn.Parent = Sidebar; Utils.Style(DeactivateBtn, 8, Theme.DangerStroke, 1)
local PagesContainer = Instance.new("Frame"); PagesContainer.Size = UDim2.new(1, -145, 1, -42); PagesContainer.Position = UDim2.fromOffset(145, 42); PagesContainer.BackgroundTransparency = 1; PagesContainer.Parent = MainFrame
local Tabs = {}; local CurrentTab = nil
local function SelectTab(tabName) for name, data in pairs(Tabs) do local isSelected = (name == tabName); data.Page.Visible = isSelected; data.Button.BackgroundColor3 = isSelected and Theme.ElementActive or Theme.Element; data.Button.TextColor3 = isSelected and Theme.TextPrimary or Theme.TextSecondary end; CurrentTab = tabName end
local function CreateTab(tabName)
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(1, 0, 0, 38); btn.BackgroundColor3 = Theme.Element; btn.Text = tabName; btn.TextColor3 = Theme.TextSecondary; btn.Font = Enum.Font.GothamMedium; btn.TextSize = 13; btn.Parent = TabList; Utils.Style(btn, 8, Theme.Stroke, 1)
    local page = Instance.new("ScrollingFrame"); page.Size = UDim2.new(1, -20, 1, -20); page.Position = UDim2.fromOffset(10, 10); page.BackgroundTransparency = 1; page.ScrollBarThickness = 2; page.CanvasSize = UDim2.new(0, 0, 0, 0); page.AutomaticCanvasSize = Enum.AutomaticSize.Y; page.Visible = false; page.Parent = PagesContainer
    local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = page
    Utils.Track(btn.Activated:Connect(function() SelectTab(tabName) end))
    Tabs[tabName] = { Button = btn, Page = page }; if not CurrentTab then SelectTab(tabName) end; return page
end
local function CreateToggle(parent, text, defaultState, order, callback)
    local btn = Instance.new("TextButton"); btn.LayoutOrder = order; btn.Size = UDim2.new(1, 0, 0, 42); btn.BackgroundColor3 = Theme.Surface; btn.Text = ""; btn.AutoButtonColor = false; btn.Parent = parent; Utils.Style(btn, 8, Theme.Stroke, 1)
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, -70, 1, 0); lbl.Position = UDim2.fromOffset(12, 0); lbl.BackgroundTransparency = 1; lbl.Text = text; lbl.TextColor3 = Theme.TextPrimary; lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 13; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = btn
    local ind = Instance.new("Frame"); ind.Size = UDim2.fromOffset(40, 22); ind.Position = UDim2.new(1, -52, 0.5, -11); ind.BackgroundColor3 = defaultState and Theme.ElementActive or Theme.Element; ind.Parent = btn; Utils.Style(ind, 11, Theme.Stroke, 1)
    local kn = Instance.new("Frame"); kn.Size = UDim2.fromOffset(16, 16); kn.Position = defaultState and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3); kn.BackgroundColor3 = defaultState and Theme.TextPrimary or Theme.TextSecondary; kn.Parent = ind; Utils.Style(kn, 8, nil)
    local state = defaultState
    Utils.Track(btn.Activated:Connect(function() state = not state; ind.BackgroundColor3 = state and Theme.ElementActive or Theme.Element; kn.Position = state and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3); kn.BackgroundColor3 = state and Theme.TextPrimary or Theme.TextSecondary; if callback then pcall(callback, state) end end))
end
local function CreateCycleButton(parent, labelPrefix, options, defaultIndex, order, callback)
    local idx = defaultIndex or 1
    local btn = Instance.new("TextButton"); btn.LayoutOrder = order; btn.Size = UDim2.new(1, 0, 0, 42); btn.BackgroundColor3 = Theme.Element; btn.Text = labelPrefix .. ": " .. tostring(options[idx]); btn.TextColor3 = Theme.TextPrimary; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 13; btn.Parent = parent; Utils.Style(btn, 8, Theme.Stroke, 1)
    Utils.Track(btn.Activated:Connect(function() idx = (idx % #options) + 1; btn.Text = labelPrefix .. ": " .. tostring(options[idx]); if callback then pcall(callback, options[idx], idx) end end))
end

local CombatPage = CreateTab("Combat"); local RenderPage = CreateTab("Render"); local ToolsPage = CreateTab("Tools")

-- Вкладка Combat: Reach (Мульти-выбор + Шея)
CreateToggle(CombatPage, "Reach (Дальность + Форма частей тела)", State.ReachEnabled, 1, function(v)
    State.ReachEnabled = v
    if not v then State.NeedsLocalRestore = true end
end)
CreateCycleButton(CombatPage, "Дистанция / Форма Reach", ReachLabels, State.ReachScaleLevel, 2, function(_, idx) State.ReachScaleLevel = idx end)
CreateCycleButton(CombatPage, "Прозрачность Reach", TransLabels, State.ReachTransLevel, 3, function(_, idx)
    State.ReachTransLevel = idx
    State.ReachTransparency = TransValues[idx] or 0.75
end)
CreateToggle(CombatPage, "[Reach] Челюсть / Укус (Jaw)", State.ReachParts.Jaw, 4, function(v) State.ReachParts.Jaw = v; State.NeedsLocalRestore = true end)
CreateToggle(CombatPage, "[Reach] Голова (Head)", State.ReachParts.Head, 5, function(v) State.ReachParts.Head = v; State.NeedsLocalRestore = true end)
CreateToggle(CombatPage, "[Reach] Шея (Neck)", State.ReachParts.Neck, 6, function(v) State.ReachParts.Neck = v; State.NeedsLocalRestore = true end)
CreateToggle(CombatPage, "[Reach] Весь Хвост (Full Tail)", State.ReachParts.Tail, 7, function(v) State.ReachParts.Tail = v; State.NeedsLocalRestore = true end)
CreateToggle(CombatPage, "[Reach] Ноги и Лапы (Legs)", State.ReachParts.Leg, 8, function(v) State.ReachParts.Leg = v; State.NeedsLocalRestore = true end)
CreateToggle(CombatPage, "[Reach] Тело (Body)", State.ReachParts.Body, 9, function(v) State.ReachParts.Body = v; State.NeedsLocalRestore = true end)

-- Строгий Silent Aim (Без лагов!)
CreateToggle(CombatPage, "Silent Aim (Строгий: только в цель)", State.SilentAim, 10, function(v)
    State.SilentAim = v
    State.NeedsEnemyRestore = true
end)
CreateCycleButton(CombatPage, "Цель Silent Aim", { "Head", "Neck", "Jaw", "Body", "Tail", "Leg" }, 1, 11, function(opt)
    State.AimTargetPart = opt
    State.NeedsEnemyRestore = true
end)
CreateToggle(CombatPage, "Не регать урон мимо цели Silent Aim", State.StrictCancelNonTarget, 12, function(v)
    State.StrictCancelNonTarget = v
    State.NeedsEnemyRestore = true
end)

-- Enemy Hitbox Expander (Мульти-выбор + Шея)
CreateToggle(CombatPage, "Enemy Hitbox Expander (Враги)", State.HitboxMaster, 13, function(v)
    State.HitboxMaster = v
    State.NeedsEnemyRestore = true
end)
CreateCycleButton(CombatPage, "Размер Хитбокса Врага", { "1 (12)", "2 (18)", "3 (25)", "4 (32)", "5 (42)" }, State.HitboxSizeLevel, 14, function(_, idx) State.HitboxSizeLevel = idx end)
CreateCycleButton(CombatPage, "Прозрачность Хитбокса Врага", TransLabels, State.HitboxTransLevel, 15, function(_, idx)
    State.HitboxTransLevel = idx
    State.HitboxTransparency = TransValues[idx] or 0.75
end)
CreateToggle(CombatPage, "[Hitbox Врага] Голова (Head)", State.EnemyHitboxParts.Head, 16, function(v) State.EnemyHitboxParts.Head = v; State.NeedsEnemyRestore = true end)
CreateToggle(CombatPage, "[Hitbox Врага] Шея (Neck)", State.EnemyHitboxParts.Neck, 17, function(v) State.EnemyHitboxParts.Neck = v; State.NeedsEnemyRestore = true end)
CreateToggle(CombatPage, "[Hitbox Врага] Челюсть (Jaw)", State.EnemyHitboxParts.Jaw, 18, function(v) State.EnemyHitboxParts.Jaw = v; State.NeedsEnemyRestore = true end)
CreateToggle(CombatPage, "[Hitbox Врага] Тело / Торс (Body)", State.EnemyHitboxParts.Body, 19, function(v) State.EnemyHitboxParts.Body = v; State.NeedsEnemyRestore = true end)
CreateToggle(CombatPage, "[Hitbox Врага] Хвост (Tail)", State.EnemyHitboxParts.Tail, 20, function(v) State.EnemyHitboxParts.Tail = v; State.NeedsEnemyRestore = true end)
CreateToggle(CombatPage, "[Hitbox Врага] Ноги / Лапы (Legs)", State.EnemyHitboxParts.Leg, 21, function(v) State.EnemyHitboxParts.Leg = v; State.NeedsEnemyRestore = true end)
CreateToggle(CombatPage, "No Attack CD", State.NoAttackCD, 22, function(v) State.NoAttackCD = v end)

-- Вкладка Render
CreateToggle(RenderPage, "Unlock Camera (Отдаление без лимита)", State.UnlockCamera, 1, function(v) State.UnlockCamera = v end)
CreateToggle(RenderPage, "ESP Игроков (Ник + Динозавр + Полоски)", State.ESPEnabled, 2, function(v) State.ESPEnabled = v end)
CreateToggle(RenderPage, "Показывать Название Динозавра", State.ESP_Species, 3, function(v) State.ESP_Species = v end)
CreateToggle(RenderPage, "Показывать Полоску HP", State.ESP_Health, 4, function(v) State.ESP_Health = v end)
CreateToggle(RenderPage, "Показывать Полоску Стамины", State.ESP_Stamina, 5, function(v) State.ESP_Stamina = v end)
CreateCycleButton(RenderPage, "Дистанция ESP Игроков", { 1000, 2000, 3500, 5000 }, 2, 6, function(val) State.ESPMaxDistance = val end)
CreateToggle(RenderPage, "ESP Костей", State.ESPBones, 7, function(v) State.ESPBones = v; if v then ESPModule.ScanWorldItems() end end)
CreateToggle(RenderPage, "ESP Еды / Трупов", State.ESPCorpses, 8, function(v) State.ESPCorpses = v; if v then ESPModule.ScanWorldItems() end end)
CreateToggle(RenderPage, "Night Vision (Без тумана)", State.NightVision, 9, function(v) State.NightVision = v end)
CreateToggle(RenderPage, "No Blur (Убрать размытие)", State.NoBlur, 10, function(v) State.NoBlur = v end)
CreateToggle(RenderPage, "No Sleep Screen (Убрать темный экран)", State.NoSleepScreen, 11, function(v)
    State.NoSleepScreen = v
    if v then Visuals.ScanSleepGui() end
end)

-- Вкладка Tools
CreateToggle(ToolsPage, "Auto Clean (Вшитый пакет мытья)", State.AutoClean, 1, function(v)
    State.AutoClean = v
    if v then Utils.Notify("Auto Clean", "Пакетное мытье активировано!") end
end)
CreateToggle(ToolsPage, "Save Dino", false, 2, function(v) SaveDino.SetEnabled(v) end)
CreateCycleButton(ToolsPage, "Направление Save Dino", { "Down", "Up" }, 1, 3, function(_, idx) State.SaveDinoMode = (idx == 1) and "Down" or "Up"; SaveDino.RecalculateTarget(); if State.SaveDinoPhase == "holding" then State.SaveDinoPhase = "moving_to_safe" end end)
CreateCycleButton(ToolsPage, "Глубина Save Dino", { 50, 70, 95, 120 }, 2, 4, function(val) State.SaveDinoOffset = val; SaveDino.RecalculateTarget(); if State.SaveDinoPhase == "holding" then State.SaveDinoPhase = "moving_to_safe" end end)

local function MinimizeUI() if State.Minimized then return end State.Minimized = true; MainFrame.Visible = false; MiniIcon.Size = IconSize; MiniIcon.Visible = true end
local function RestoreUI() if not State.Minimized then return end State.Minimized = false; MiniIcon.Visible = false; MainFrame.Visible = true end
local function DeactivateScript()
    if not State.Active then return end
    State.Active = false; State.SilentAim = false; State.HitboxMaster = false; State.ReachEnabled = false; State.ESPEnabled = false; State.ESPBones = false; State.ESPCorpses = false; State.NoAttackCD = false; State.AutoClean = false; State.UnlockCamera = false
    Visuals.Restore(); SaveDino.ForceReset(); Combat.RestoreAll(); ESPModule.Cleanup()
    for _, conn in ipairs(State.Connections) do pcall(function() conn:Disconnect() end) end; table.clear(State.Connections)
    pcall(function() ScreenGui:Destroy() end); Env.PriorUI_Cleanup = nil; Utils.Notify("Prior Extinction", "Скрипт выгружен.")
end
Env.PriorUI_Cleanup = DeactivateScript
Utils.Drag(TopBar, MainFrame, nil); Utils.Drag(MiniIcon, MiniIcon, RestoreUI)
Utils.Track(MinimizeBtn.Activated:Connect(MinimizeUI)); Utils.Track(DeactivateBtn.Activated:Connect(DeactivateScript))

Visuals.Init(); Survival.Init(); SaveDino.Init(); Combat.Init(); ESPModule.Init()
task.spawn(function() pcall(function() TweenService:Create(MainFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = TargetSize }):Play() end) end)
