-- ═══════════════════════════════════════════════════════════════════════
-- PRIOR EXTINCTION // ULTIMATE (Full Merged)
-- ═══════════════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local LogService = game:GetService("LogService")
local LocalPlayer = Players.LocalPlayer

local Env = (type(getgenv) == "function" and getgenv()) or _G
if Env.PriorUI_Cleanup then pcall(Env.PriorUI_Cleanup) end

-- 1. Конфигурация и Состояние
Env.PriorUI_State = {
    Active = true, Minimized = false, Connections = {}, OriginalParts = {}, CachedModels = {},
    SilentAim = false, AimTargetPart = "Head", HitboxMaster = false, HitboxTransparency = 0.65, HitboxSizeLevel = 3, SelectedHitboxPart = "Head", NoAttackCD = false,
    ESPEnabled = false, ESPMaxDistance = 2000, ESP_Health = true, ESP_Stamina = true, ESPBones = false, ESPCorpses = false, WorldESPMaxDistance = 1500,
    NightVision = false, NoBlur = false, NoSleepScreen = false,
    AutoClean = false, AutoDrink = false, AutoEat = false,
    SaveDinoEnabled = false, SaveDinoMode = "Down", SaveDinoOffset = 70, SaveDinoOriginalCFrame = nil, SaveDinoTargetCFrame = nil, SaveDinoCurrentCFrame = nil, SaveDinoPhase = "idle", SaveDinoCollisions = {},
}
local State = Env.PriorUI_State

-- BridgeNet2 Переменные
Env.PE_CapturedCleanPacket = nil
Env.PE_CapturedEatPacket = nil
Env.PE_WaitingForCleanPacket = false
Env.PE_WaitingForEatPacket = false

local LightingOriginals = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, Brightness = Lighting.Brightness, GlobalShadows = Lighting.GlobalShadows, ClockTime = Lighting.ClockTime }
local Theme = { Background = Color3.fromRGB(12,12,14), Surface = Color3.fromRGB(18,18,22), Element = Color3.fromRGB(26,26,32), ElementActive = Color3.fromRGB(52,52,64), Stroke = Color3.fromRGB(45,45,54), TextPrimary = Color3.fromRGB(235,235,240), TextSecondary = Color3.fromRGB(145,145,155), Danger = Color3.fromRGB(40,22,24), DangerStroke = Color3.fromRGB(95,40,45) }
local HitboxSizes = { 10, 16, 22, 28, 35 }
local PartPatterns = { Jaw = { "jaw", "mandible", "snout", "mouth", "bite", "muzzle", "beak" }, Head = { "head", "skull", "cranium", "neckhead" }, Tail = { "tail1", "tail_1", "tailbase", "tail_base", "tailstart", "tailroot", "uppertail", "tail0", "tail_0", "tail" }, Body = { "chest", "ribcage", "abdomen", "bodyhitbox", "hitboxbody", "upperbody", "spine", "torso", "body", "pelvis", "hip" }, Leg = { "leg", "thigh", "calf", "shin", "foot", "ankle" } }

-- 2. Утилиты
local Utils = {}
function Utils.Track(c) if c then table.insert(State.Connections, c) end return c end
function Utils.Notify(t, x) pcall(function() StarterGui:SetCore("SendNotification", { Title = t, Text = x, Duration = 3 }) end) end
function Utils.GuiParent() local ok, p = pcall(function() if type(gethui) == "function" then return gethui() end return CoreGui end) if ok and p then return p end return LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 5) or CoreGui end
function Utils.Style(i, r, sc, sw) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = i; if sc then local s = Instance.new("UIStroke"); s.Color = sc; s.Thickness = sw or 1; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = i end end
function Utils.Drag(tr, tf, cb)
    local d, di, ds, sp, md = false, nil, nil, nil, 0
    Utils.Track(tr.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            d = true; ds = inp.Position; sp = tf.Position; md = 0
            local rc; rc = inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then d = false; if rc then rc:Disconnect() end; if md < 12 and cb then cb() end end end)
        end
    end))
    Utils.Track(tr.InputChanged:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then di = inp end end))
    Utils.Track(UserInputService.InputChanged:Connect(function(inp) if inp == di and d and ds and sp then local dl = inp.Position - ds; md = dl.Magnitude; tf.Position = UDim2.new(sp.X.Scale, sp.X.Offset + dl.X, sp.Y.Scale, sp.Y.Offset + dl.Y) end end))
end
function Utils.DeepClone(tbl, seen)
    if type(tbl) ~= "table" then return tbl end
    seen = seen or {}
    if seen[tbl] then return seen[tbl] end
    local copy = {}; seen[tbl] = copy
    for k, v in pairs(tbl) do copy[Utils.DeepClone(k, seen)] = Utils.DeepClone(v, seen) end
    return copy
end

-- 3. Visuals
local Visuals = {}
function Visuals.Init()
    Utils.Track(RunService.Heartbeat:Connect(function()
        if not State.Active then return end
        if State.NightVision then Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255); Lighting.Brightness=3; Lighting.GlobalShadows=false
        else Lighting.Ambient=LightingOriginals.Ambient; Lighting.OutdoorAmbient=LightingOriginals.OutdoorAmbient; Lighting.Brightness=LightingOriginals.Brightness; Lighting.GlobalShadows=LightingOriginals.GlobalShadows end
        if State.NoBlur then for _,e in ipairs(Lighting:GetChildren()) do if e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") then e.Enabled=false end end end
    end))
end
function Visuals.Restore() Lighting.Ambient=LightingOriginals.Ambient; Lighting.OutdoorAmbient=LightingOriginals.OutdoorAmbient; Lighting.Brightness=LightingOriginals.Brightness; Lighting.GlobalShadows=LightingOriginals.GlobalShadows; Lighting.ClockTime=LightingOriginals.ClockTime end

-- 4. Auto Clean & Eat (BridgeNet2)
local Survival = {}
LogService.MessageOut:Connect(function(msg)
    if string.find(msg, "CleanlinessStart", 1, true) then Env.PE_WaitingForCleanPacket = os.clock() end
    if string.find(msg, "EatStart", 1, true) or string.find(msg, "Consume", 1, true) then Env.PE_WaitingForEatPacket = os.clock() end
end)

function Survival.Init()
    task.spawn(function()
        while State.Active do
            if State.AutoClean and Env.PE_CapturedCleanPacket then
                pcall(function() Env.PE_CapturedCleanPacket.Remote:FireServer(table.unpack(Utils.DeepClone(Env.PE_CapturedCleanPacket.Args))) end)
            end
            if State.AutoEat and Env.PE_CapturedEatPacket then
                pcall(function() Env.PE_CapturedEatPacket.Remote:FireServer(table.unpack(Utils.DeepClone(Env.PE_CapturedEatPacket.Args))) end)
            end
            task.wait(1.2)
        end
    end)
end

-- 5. Save Dino
local SaveDino = { Pad = nil }
local function ensurePad() if SaveDino.Pad and SaveDino.Pad.Parent then return SaveDino.Pad end local p=Instance.new("Part"); p.Name="PE_UPad"; p.Size=Vector3.new(60,3,60); p.Anchored=true; p.CanCollide=true; p.Transparency=0.85; p.Color=Color3.fromRGB(30,30,35); p.Parent=Workspace; SaveDino.Pad=p; return p end
local function killPad() if SaveDino.Pad then pcall(function() SaveDino.Pad:Destroy() end) SaveDino.Pad=nil end end
local function noclip(c, en) if not c then return end; if en then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then if State.SaveDinoCollisions[p]==nil then State.SaveDinoCollisions[p]=p.CanCollide end p.CanCollide=false end end else for p,o in pairs(State.SaveDinoCollisions) do if p and p.Parent then pcall(function() p.CanCollide=o end) end end table.clear(State.SaveDinoCollisions) end end
local function zero(c) if not c then return end for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.AssemblyLinearVelocity=Vector3.zero; p.AssemblyAngularVelocity=Vector3.zero end) end end end
local function feetOff(c) local ok,_,sz=pcall(function() return c:GetBoundingBox() end) if ok and sz then return math.clamp(sz.Y*0.5,3,25) end return 6 end

function SaveDino.RecalculateTarget() if not State.SaveDinoOriginalCFrame then return end local y=(State.SaveDinoMode=="Down") and -State.SaveDinoOffset or (State.SaveDinoOffset*4); State.SaveDinoTargetCFrame=State.SaveDinoOriginalCFrame+Vector3.new(0,y,0) end
function SaveDino.SetEnabled(en)
    State.SaveDinoEnabled=en; local c=LocalPlayer.Character; if not c then State.SaveDinoPhase="idle"; return end
    if en then
        if State.SaveDinoPhase=="idle" or not State.SaveDinoOriginalCFrame then local ok,pv=pcall(function() return c:GetPivot() end) if not ok or not pv then Utils.Notify("Save Dino","Позиция не определена"); State.SaveDinoEnabled=false; return end State.SaveDinoOriginalCFrame=pv; State.SaveDinoCurrentCFrame=pv end
        SaveDino.RecalculateTarget(); State.SaveDinoPhase="moving_to_safe"
        local h=c:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Freefall,false); h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false) end) end
        ensurePad(); Utils.Notify("Save Dino","Погружение...")
    elseif State.SaveDinoPhase~="idle" then State.SaveDinoPhase="returning"; Utils.Notify("Save Dino","Возврат...") end
end
function SaveDino.ForceReset()
    State.SaveDinoEnabled=false; State.SaveDinoPhase="idle"; local c=LocalPlayer.Character
    if c then noclip(c,false); zero(c); local h=c:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Freefall,true); h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,true); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,true); h:ChangeState(Enum.HumanoidStateType.Running) end) end end
    State.SaveDinoOriginalCFrame=nil; State.SaveDinoTargetCFrame=nil; State.SaveDinoCurrentCFrame=nil; killPad()
end
function SaveDino.Init()
    Utils.Track(LocalPlayer.CharacterAdded:Connect(function() SaveDino.ForceReset() end))
    Utils.Track(RunService.Heartbeat:Connect(function(dt)
        if State.SaveDinoPhase=="idle" then return end
        local c=LocalPlayer.Character; if not c or not c.Parent then SaveDino.ForceReset(); return end
        local ok,cur=pcall(function() return c:GetPivot() end) if not ok or not cur then return end
        if not State.SaveDinoCurrentCFrame then State.SaveDinoCurrentCFrame=cur end
        local pad=ensurePad(); local fo=feetOff(c)
        if State.SaveDinoPhase=="moving_to_safe" then
            noclip(c,true); local df=State.SaveDinoTargetCFrame.Position-State.SaveDinoCurrentCFrame.Position; local di=df.Magnitude; local st=math.min(di,120*dt)
            if di<=1.5 then State.SaveDinoCurrentCFrame=State.SaveDinoTargetCFrame; State.SaveDinoPhase="holding"; Utils.Notify("Save Dino","В безопасности") else State.SaveDinoCurrentCFrame=State.SaveDinoCurrentCFrame+df.Unit*st end
            pad.CFrame=CFrame.new(State.SaveDinoCurrentCFrame.Position-Vector3.new(0,fo,0)); pcall(function() c:PivotTo(State.SaveDinoCurrentCFrame) end); zero(c)
        elseif State.SaveDinoPhase=="holding" then
            noclip(c,true); pad.CFrame=CFrame.new(State.SaveDinoTargetCFrame.Position-Vector3.new(0,fo,0)); pcall(function() c:PivotTo(State.SaveDinoTargetCFrame) end); zero(c)
        elseif State.SaveDinoPhase=="returning" then
            noclip(c,true); local sf=State.SaveDinoOriginalCFrame+Vector3.new(0,2.5,0); local df=sf.Position-State.SaveDinoCurrentCFrame.Position; local di=df.Magnitude; local st=math.min(di,110*dt)
            if di<=1.5 then noclip(c,false); pcall(function() c:PivotTo(sf) end); zero(c); SaveDino.ForceReset(); Utils.Notify("Save Dino","На поверхности!") else State.SaveDinoCurrentCFrame=State.SaveDinoCurrentCFrame+df.Unit*st; pad.CFrame=CFrame.new(State.SaveDinoCurrentCFrame.Position-Vector3.new(0,fo,0)); pcall(function() c:PivotTo(State.SaveDinoCurrentCFrame) end); zero(c) end
        end
    end))
end

-- 6. Combat (Silent Aim + Hitbox + NoAttackCD + Перехват)
local Combat = {}
local ZP = PhysicalProperties.new(0.0001, 0, 0, 0, 0)
local function matchCat(n) local l=string.lower(n) for _,c in ipairs({"Jaw","Head","Tail","Leg","Body"}) do for _,p in ipairs(PartPatterns[c]) do if string.find(l,p,1,true) then if c=="Tail" and (string.find(l,"tip",1,true) or string.match(l,"tail[_%s]*[3-9]")) then return nil end return c end end end return nil end
local function isLocal(m) return LocalPlayer.Character and (m==LocalPlayer.Character or m:IsDescendantOf(LocalPlayer.Character)) end
local function isCritRoot(model, part) if not part or not model then return true end local l=string.lower(part.Name) if l=="humanoidrootpart" or l=="rootpart" or l=="root" or l=="primary" or model.PrimaryPart==part then return true end local ok,ar=pcall(function() return part.AssemblyRootPart end) return ok and ar==part end
local function findPart(model, cat) local c=State.CachedModels[model] if c and c[cat] then for _,p in ipairs(c[cat]) do if p and p.Parent then return p end end end for _,d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") and matchCat(d.Name)==cat then return d end end return nil end
local function getEnemy(part) if not part or not part:IsA("BasePart") or isLocal(part) then return nil end local cur=part.Parent while cur and cur~=Workspace do if cur:IsA("Model") and (cur:FindFirstChildOfClass("Humanoid") or cur:FindFirstChild("Head",true)) then if not isLocal(cur) then return cur end end cur=cur.Parent end return nil end

function Combat.ScanModel(model)
    local cats={Head={},Jaw={},Body={},Tail={},Leg={}}
    pcall(function()
        for _,d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then local c=matchCat(d.Name) if c and cats[c] and not isCritRoot(model,d) then table.insert(cats[c],d) end end end
        if #cats.Body==0 then for _,d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") and not isCritRoot(model,d) then local n=string.lower(d.Name) if string.find(n,"hit",1,true) or string.find(n,"spine",1,true) or string.find(n,"rib",1,true) then table.insert(cats.Body,d) end end end end
    end)
    return cats
end

if not Env.PriorUI_HookInstalled then
    pcall(function()
        local old = hookmetamethod(game, "__namecall", function(self, ...)
            local cs = Env.PriorUI_State
            if cs and cs.Active then
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    local args = { ... }
                    if tostring(self.Name) == "dataRemoteEvent" then
                        local isClean = (os.clock() - (Env.PE_WaitingForCleanPacket or 0)) < 1.5
                        local isEat = (os.clock() - (Env.PE_WaitingForEatPacket or 0)) < 1.5
                        if isClean and not Env.PE_CapturedCleanPacket then Env.PE_CapturedCleanPacket = { Remote = self, Args = Utils.DeepClone(args) }; Utils.Notify("Auto Clean", "Пакет мытья перехвачен!") end
                        if isEat and not Env.PE_CapturedEatPacket then Env.PE_CapturedEatPacket = { Remote = self, Args = Utils.DeepClone(args) }; Utils.Notify("Auto Eat", "Пакет еды перехвачен!") end
                    end
                    if cs.SilentAim then
                        local mod = false
                        for i, arg in ipairs(args) do
                            if typeof(arg)=="Instance" and arg:IsA("BasePart") then local em=getEnemy(arg) if em then local tp=findPart(em,cs.AimTargetPart) if tp then args[i]=tp; mod=true end end end
                        end
                        if mod then return old(self, table.unpack(args)) end
                    end
                end
            end
            return old(self, ...)
        end)
        Env.PriorUI_HookInstalled = true
    end)
end

function Combat.Init()
    task.spawn(function()
        while State.Active do
            pcall(function()
                local nc={}
                for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character then nc[p.Character]=Combat.ScanModel(p.Character) end end
                State.CachedModels=nc
            end)
            task.wait(1)
        end
    end)
    task.spawn(function()
        while State.Active do
            pcall(function()
                for model,groups in pairs(State.CachedModels) do
                    if model and model.Parent and not isLocal(model) then
                        local tCat=State.SelectedHitboxPart; local tSize=HitboxSizes[State.HitboxSizeLevel]
                        for cat,parts in pairs(groups) do
                            for idx,part in ipairs(parts) do
                                if part and part.Parent and not isCritRoot(model,part) then
                                    if not State.OriginalParts[part] then State.OriginalParts[part]={Size=part.Size,Transparency=part.Transparency,CanCollide=part.CanCollide,CanQuery=part.CanQuery,CanTouch=part.CanTouch,Massless=part.Massless,CustomPhysicalProperties=part.CustomPhysicalProperties,RootPriority=part.RootPriority} end
                                    local o=State.OriginalParts[part]
                                    if State.HitboxMaster and cat==tCat and idx<=2 then part.Massless=true; part.CanCollide=false; part.CustomPhysicalProperties=ZP; part.RootPriority=-127; part.Size=Vector3.new(tSize,tSize,tSize); part.Transparency=State.HitboxTransparency; part.CanTouch=true; part.CanQuery=true
                                    else part.Size=o.Size; part.Transparency=o.Transparency; part.CanCollide=o.CanCollide; part.Massless=o.Massless; part.CanTouch=o.CanTouch; part.CanQuery=o.CanQuery; part.CustomPhysicalProperties=o.CustomPhysicalProperties; part.RootPriority=o.RootPriority end
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(0.2)
        end
    end)
    task.spawn(function()
        while State.Active do
            if State.NoAttackCD then pcall(function() local ch=LocalPlayer.Character if ch then for _,inst in ipairs({ch,LocalPlayer}) do local ok,at=pcall(function() return inst:GetAttributes() end) if ok and type(at)=="table" then for k,v in pairs(at) do local kn=string.lower(k) if (string.find(kn,"cooldown",1,true) or string.find(kn,"attackcd",1,true) or string.find(kn,"bitecd",1,true) or string.find(kn,"debounce",1,true)) and type(v)=="number" then inst:SetAttribute(k,0) elseif (kn=="canattack" or kn=="canbite") and type(v)=="boolean" then inst:SetAttribute(k,true) end end end end end end) end
            task.wait(0.08)
        end
    end)
end
function Combat.RestoreAll() for p,o in pairs(State.OriginalParts) do pcall(function() if p and p.Parent then p.Size=o.Size; p.Transparency=o.Transparency; p.CanCollide=o.CanCollide; p.CanQuery=o.CanQuery; p.CanTouch=o.CanTouch; p.Massless=o.Massless; p.CustomPhysicalProperties=o.CustomPhysicalProperties; p.RootPriority=o.RootPriority end end) end table.clear(State.OriginalParts) end

-- 7. ESP
local ESPModule = {}
local espGuis, worldGuis, trackedWorld, stamTrack = {}, {}, {}, {}
local worldScanDone, worldScanning = false, false
local ESPFolder = Instance.new("Folder"); ESPFolder.Name="PE_ESP_Container"; pcall(function() ESPFolder.Parent=Utils.GuiParent() end)
local function getESPHead(c) if not c or not c:IsA("Model") then return nil end local h=c:FindFirstChild("Head",true) if h and h:IsA("BasePart") then return h end for _,d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") and string.find(string.lower(d.Name),"head",1,true) then return d end end return c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart",true) end
local function ExtractNumber(v) if type(v)=="number" then return v end if type(v)=="string" then return tonumber(v) or tonumber(st
