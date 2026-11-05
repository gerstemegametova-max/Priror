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

Env.PriorUI_State = {
    Active = true, Minimized = false, Connections = {}, OriginalParts = {}, CachedModels = {},
    SilentAim = false, AimTargetPart = "Head", HitboxMaster = false, HitboxTransparency = 0.65, HitboxSizeLevel = 3, SelectedHitboxPart = "Head", NoAttackCD = false,
    ESPEnabled = false, ESPMaxDistance = 2000, ESP_Health = true, ESP_Stamina = true, ESPBones = false, ESPCorpses = false, WorldESPMaxDistance = 1500,
    NightVision = false, NoBlur = false, NoSleepScreen = false,
    AutoClean = false, AutoDrink = false, AutoEat = false,
    SaveDinoEnabled = false, SaveDinoMode = "Down", SaveDinoOffset = 70, SaveDinoOriginalCFrame = nil, SaveDinoTargetCFrame = nil, SaveDinoCurrentCFrame = nil, SaveDinoPhase = "idle", SaveDinoCollisions = {},
}
local State = Env.PriorUI_State

Env.PE_CapturedCleanPacket = nil
Env.PE_CapturedEatPacket = nil
Env.PE_WaitingForCleanPacket = false
Env.PE_WaitingForEatPacket = false

local LightingOriginals = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, Brightness = Lighting.Brightness, GlobalShadows = Lighting.GlobalShadows, ClockTime = Lighting.ClockTime }
local Theme = { Background = Color3.fromRGB(12,12,14), Surface = Color3.fromRGB(18,18,22), Element = Color3.fromRGB(26,26,32), ElementActive = Color3.fromRGB(52,52,64), Stroke = Color3.fromRGB(45,45,54), TextPrimary = Color3.fromRGB(235,235,240), TextSecondary = Color3.fromRGB(145,145,155), Danger = Color3.fromRGB(40,22,24), DangerStroke = Color3.fromRGB(95,40,45) }
local HitboxSizes = { 10, 16, 22, 28, 35 }
local PartPatterns = { Jaw = { "jaw", "mandible", "snout", "mouth", "bite", "muzzle", "beak" }, Head = { "head", "skull", "cranium", "neckhead" }, Tail = { "tail1", "tail_1", "tailbase", "tail_base", "tailstart", "tailroot", "uppertail", "tail0", "tail_0", "tail" }, Body = { "chest", "ribcage", "abdomen", "bodyhitbox", "hitboxbody", "upperbody", "spine", "torso", "body", "pelvis", "hip" }, Leg = { "leg", "thigh", "calf", "shin", "foot", "ankle" } }

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
endlocal Visuals = {}
function Visuals.Init()
    Utils.Track(RunService.Heartbeat:Connect(function()
        if not State.Active then return end
        if State.NightVision then Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255); Lighting.Brightness=3; Lighting.GlobalShadows=false
        else Lighting.Ambient=LightingOriginals.Ambient; Lighting.OutdoorAmbient=LightingOriginals.OutdoorAmbient; Lighting.Brightness=LightingOriginals.Brightness; Lighting.GlobalShadows=LightingOriginals.GlobalShadows end
        if State.NoBlur then for _,e in ipairs(Lighting:GetChildren()) do if e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") then e.Enabled=false end end end
    end))
end
function Visuals.Restore() Lighting.Ambient=LightingOriginals.Ambient; Lighting.OutdoorAmbient=LightingOriginals.OutdoorAmbient; Lighting.Brightness=LightingOriginals.Brightness; Lighting.GlobalShadows=LightingOriginals.GlobalShadows; Lighting.ClockTime=LightingOriginals.ClockTime end

local Survival = {}
LogService.MessageOut:Connect(function(msg)
    if string.find(msg, "CleanlinessStart", 1, true) then Env.PE_WaitingForCleanPacket = os.clock() end
    if string.find(msg, "EatStart", 1, true) or string.find(msg, "Consume", 1, true) then Env.PE_WaitingForEatPacket = os.clock() end
end)
function Survival.Init()
    task.spawn(function()
        while State.Active do
            if State.AutoClean and Env.PE_CapturedCleanPacket then pcall(function() Env.PE_CapturedCleanPacket.Remote:FireServer(table.unpack(Utils.DeepClone(Env.PE_CapturedCleanPacket.Args))) end) end
            if State.AutoEat and Env.PE_CapturedEatPacket then pcall(function() Env.PE_CapturedEatPacket.Remote:FireServer(table.unpack(Utils.DeepClone(Env.PE_CapturedEatPacket.Args))) end) end
            task.wait(1.2)
        end
    end)
end

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
    endlocal Combat = {}
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

local ESPModule = {}
local espGuis, worldGuis, trackedWorld, stamTrack = {}, {}, {}, {}
local worldScanDone, worldScanning = false, false
local ESPFolder = Instance.new("Folder"); ESPFolder.Name="PE_ESP_Container"; pcall(function() ESPFolder.Parent=Utils.GuiParent() end)
local function getESPHead(c) if not c or not c:IsA("Model") then return nil end local h=c:FindFirstChild("Head",true) if h and h:IsA("BasePart") then return h end for _,d in ipairs(c:GetDescendants()) do if d:IsA("BasePart") and string.find(string.lower(d.Name),"head",1,true) then return d end end return c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart",true) end
local function ExtractNumber(v) if type(v)=="number" then return v end if type(v)=="string" then return tonumber(v) or tonumber(string.match(v,"[-]?%d+%.?%d*")) end return nil end
local function GetDinoStats(player, model, headPart)
    local hp,maxHp=100,100; local realStam,realMaxStam=nil,nil; local hum=model:FindFirstChildOfClass("Humanoid"); if hum then hp=hum.Health; maxHp=hum.MaxHealth end
    local function CheckKV(rawName, rawVal) local num=ExtractNumber(rawVal) if not num then return end local n=string.lower(tostring(rawName)) if n=="health" or n=="hp" or n=="currenthealth" then hp=num elseif n=="maxhealth" or n=="maxhp" then if num>0 then maxHp=num end elseif string.find(n,"maxstam",1,true) then if num>0 then realMaxStam=num end elseif string.find(n,"stam",1,true) or n=="energy" then realStam=num end end
    for _,inst in ipairs({model,hum,player}) do if inst then local ok,attrs=pcall(function() return inst:GetAttributes() end) if ok and type(attrs)=="table" then for k,v in pairs(attrs) do CheckKV(k,v) end end end end
    for _,obj in ipairs(model:GetDescendants()) do if obj:IsA("ValueBase") then pcall(function() CheckKV(obj.Name,obj.Value) end) end end
    if not maxHp or maxHp<=0 then maxHp=math.max(hp,100) end
    local defaultMaxStam=(realMaxStam and realMaxStam>0) and realMaxStam or 100
    if realStam and realStam>0 then return hp,maxHp,realStam,math.max(defaultMaxStam,realStam) end
    local now=os.clock(); local pos=headPart and headPart.Position or Vector3.zero; local track=stamTrack[player]
    if not track or track.char~=model then track={char=model,stam=defaultMaxStam,maxStam=defaultMaxStam,lastTime=now,lastPos=pos,lastSprintTime=0} stamTrack[player]=track
    else track.maxStam=defaultMaxStam; local dt=math.clamp(now-track.lastTime,0.05,1.0); local distMoved=Vector3.new(pos.X-track.lastPos.X,0,pos.Z-track.lastPos.Z).Magnitude; local posSpeed=distMoved/dt; local velSpeed=0; pcall(function() local v=headPart.AssemblyLinearVelocity; velSpeed=Vector3.new(v.X,0,v.Z).Magnitude end)
        local speed=math.max(posSpeed,velSpeed); if speed>160 then speed=0 end
        if speed>22 then track.stam=math.clamp(track.stam-(track.maxStam*0.05*dt),0,track.maxStam); track.lastSprintTime=now
        elseif (now-(track.lastSprintTime or 0))>=3.0 then if speed>5 then track.stam=math.clamp(track.stam+(track.maxStam*0.0035*dt),0,track.maxStam) else track.stam=math.clamp(track.stam+(track.maxStam*0.0135*dt),0,track.maxStam) end end
        track.lastTime=now; track.lastPos=pos end
    return hp,maxHp,track.stam,track.maxStam
end
local function GetMyPosition() local myChar=LocalPlayer.Character if myChar then local ok,pivot=pcall(function() return myChar:GetPivot().Position end) if ok and pivot then return pivot end end return Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position or Vector3.zero end
local function IsPartOfPlayerCharacter(obj) for _,p in ipairs(Players:GetPlayers()) do if p.Character and (obj==p.Character or obj:IsDescendantOf(p.Character)) then return true end end return false end
local BoneKeywords={"fossil","bone","skeleton","amber","relic","digsite","dig_site","excavat"}
local CorpseKeywords={"carcass","corpse","deadbody","meat","gore","chunk","edible","food","prey"}
local function ClassifyWorldObject(obj) if not obj or not obj.Parent or IsPartOfPlayerCharacter(obj) then return nil end local text=string.lower(obj.Name) if obj.Parent and obj.Parent~=Workspace then text=text.." "..string.lower(obj.Parent.Name) end local prompt=obj:FindFirstChildWhichIsA("ProximityPrompt",true) if prompt then text=text.." "..string.lower(prompt.ActionText.." "..prompt.ObjectText) end for _,kw in ipairs(BoneKeywords) do if string.find(text,kw,1,true) then return "Bone" end end for _,kw in ipairs(CorpseKeywords) do if string.find(text,kw,1,true) then return "Corpse" end end return nil end
function ESPModule.ScanWorldItems()
    if worldScanDone or worldScanning then return end
    worldScanning = true; local newItems = {}
    pcall(function()
        local descendants = Workspace:GetDescendants()
        for i, desc in ipairs(descendants) do
            if i % 2500 == 0 then task.wait() end
            if desc:IsA("ProximityPrompt") and desc.Parent then local targetObj=desc.Parent local part=targetObj:IsA("BasePart") and targetObj or targetObj:FindFirstAncestorWhichIsA("BasePart") or targetObj:FindFirstChildWhichIsA("BasePart",true) if part and not newItems[targetObj] then local cat=ClassifyWorldObject(targetObj) if cat then newItems[targetObj]={Category=cat,Part=part} end end
            elseif (desc:IsA("Model") or desc:IsA("MeshPart")) and desc.Parent then local n=string.lower(desc.Name) if string.find(n,"fossil",1,true) or string.find(n,"bone",1,true) or string.find(n,"carcass",1,true) or string.find(n,"corpse",1,true) or string.find(n,"meat",1,true) then local rootModel=desc:IsA("Model") and desc or (desc.Parent:IsA("Model") and desc.Parent or desc) if not newItems[rootModel] and not IsPartOfPlayerCharacter(rootModel) then local part=rootModel:IsA("BasePart") and rootModel or rootModel:FindFirstChildWhichIsA("BasePart",true) local cat=ClassifyWorldObject(rootModel) if cat and part then newItems[rootModel]={Category=cat,Part=part} end end end end
        end
    end)
    trackedWorld = newItems; worldScanDone = true; worldScanning = false
end
function ESPModule.Cleanup()
    for _,d in pairs(espGuis) do if d.gui then pcall(function() d.gui:Destroy() end) end end
    for _,d in pairs(worldGuis) do if d.gui then pcall(function() d.gui:Destroy() end) end end
    table.clear(espGuis); table.clear(worldGuis); table.clear(stamTrack); table.clear(trackedWorld)
    if ESPFolder then pcall(function() ESPFolder:Destroy() end) end
end
function ESPModule.Init()
    Utils.Track(Players.PlayerRemoving:Connect(function(plr) if espGuis[plr] then if espGuis[plr].gui then pcall(function() espGuis[plr].gui:Destroy() end) end espGuis[plr]=nil end stamTrack[plr]=nil end))
    task.spawn(function() while State.Active do if State.ESPBones or State.ESPCorpses then ESPModule.ScanWorldItems() end task.wait(8) end end)
    task.spawn(function()
        while State.Active do
            pcall(function()
                local myPos=GetMyPosition()
                if not State.ESPEnabled then for _,data in pairs(espGuis) do if data.gui then data.gui.Enabled=false end end
                else
                    for _,player in ipairs(Players:GetPlayers()) do
                        if player~=LocalPlayer then
                            local char=player.Character; local targetPart=char and getESPHead(char)
                            if char and targetPart then
                                local dist=(myPos-targetPart.Position).Magnitude; local inRange=dist<=State.ESPMaxDistance
                                if not espGuis[player] or not espGuis[player].gui or not espGuis[player].gui.Parent then
                                    local bb=Instance.new("BillboardGui"); bb.Name="PE_ESP_"..player.Name; bb.Size=UDim2.fromOffset(175,52); bb.StudsOffset=Vector3.new(0,5,0); bb.AlwaysOnTop=true; bb.ResetOnSpawn=false; bb.Enabled=false; bb.Parent=ESPFolder
                                    local nm=Instance.new("TextLabel"); nm.Size=UDim2.new(1,0,0,15); nm.BackgroundTransparency=1; nm.TextColor3=Color3.fromRGB(255,255,255); nm.TextStrokeTransparency=0.1; nm.Font=Enum.Font.GothamBold; nm.TextSize=12; nm.Parent=bb
                                    local hb=Instance.new("Frame"); hb.Size=UDim2.new(1,0,0,14); hb.Position=UDim2.new(0,0,0,17); hb.BackgroundColor3=Color3.fromRGB(24,24,28); hb.BorderSizePixel=0; hb.Parent=bb; Utils.Style(hb,4,Color3.fromRGB(0,0,0),1)
                                    local hf=Instance.new("Frame"); hf.Size=UDim2.new(1,0,1,0); hf.BackgroundColor3=Color3.fromRGB(65,235,85); hf.BorderSizePixel=0; hf.Parent=hb; Utils.Style(hf,4,nil)
                                    local ht=Instance.new("TextLabel"); ht.Size=UDim2.fromScale(1,1); ht.BackgroundTransparency=1; ht.TextColor3=Color3.fromRGB(255,255,255); ht.TextStrokeTransparency=0.05; ht.Font=Enum.Font.GothamBold; ht.TextSize=10; ht.ZIndex=3; ht.Parent=hb
                                    local sb=Instance.new("Frame"); sb.Size=UDim2.new(1,0,0,14); sb.Position=UDim2.new(0,0,0,34); sb.BackgroundColor3=Color3.fromRGB(24,24,28); sb.BorderSizePixel=0; sb.Parent=bb; Utils.Style(sb,4,Color3.fromRGB(0,0,0),1)
                                    local sf=Instance.new("Frame"); sf.Size=UDim2.new(1,0,1,0); sf.BackgroundColor3=Color3.fromRGB(55,170,255); sf.BorderSizePixel=0; sf.Parent=sb; Utils.Style(sf,4,nil)
                                    local st=Instance.new("TextLabel"); st.Size=UDim2.fromScale(1,1); st.BackgroundTransparency=1; st.TextColor3=Color3.fromRGB(255,255,255); st.TextStrokeTransparency=0.05; st.Font=Enum.Font.GothamBold; st.TextSize=10; st.ZIndex=3; st.Parent=sb
                                    espGuis[player]={gui=bb,name=nm,hpBg=hb,hpFill=hf,hpText=ht,stamBg=sb,stamFill=sf,stamText=st}
                                end
                                local data=espGuis[player]; data.gui.Adornee=targetPart
                                if inRange then
                                    local hp,maxHp,stam,maxStam=GetDinoStats(player,char,targetPart)
                                    local hpRatio=math.clamp(hp/maxHp,0,1); local stamRatio=math.clamp(stam/maxStam,0,1)
                                    data.name.Text=string.format("[%dm] %s",math.floor(dist),player.DisplayName or player.Name)
                                    data.hpBg.Visible=State.ESP_Health
                                    if State.ESP_Health then data.hpFill.Size=UDim2.new(hpRatio,0,1,0); data.hpText.Text=string.format("HP: %d / %d",math.floor(hp+0.5),math.floor(maxHp+0.5)) if hpRatio<0.3 then data.hpFill.BackgroundColor3=Color3.fromRGB(235,65,65) elseif hpRatio<0.65 then data.hpFill.BackgroundColor3=Color3.fromRGB(240,190,50) else data.hpFill.BackgroundColor3=Color3.fromRGB(60,215,80) end end
                                    data.stamBg.Visible=State.ESP_Stamina
                                    if State.ESP_Stamina then data.stamFill.Size=UDim2.new(stamRatio,0,1,0); data.stamText.Text=string.format("ST: %d / %d",math.floor(stam+0.5),math.floor(maxStam+0.5)) if stamRatio<0.25 then data.stamFill.BackgroundColor3=Color3.fromRGB(245,135,45) else data.stamFill.BackgroundColor3=Color3.fromRGB(50,160,245) end end
                                    data.gui.Enabled=true
                                else data.gui.Enabled=false end
                            elseif espGuis[player] and espGuis[player].gui then espGuis[player].gui.Enabled=false end
                        end
                    end
                end
                for obj,gData in pairs(worldGuis) do if not obj or not obj.Parent or not trackedWorld[obj] then if gData.gui then pcall(function() gData.gui:Destroy() end) end worldGuis[obj]=nil end end
                if State.ESPBones or State.ESPCorpses then
                    for obj,info in pairs(trackedWorld) do
                        local part=info.Part
                        if obj and obj.Parent and part and part.Parent then
                            local isBone=(info.Category=="Bone"); local isCorpse=(info.Category=="Corpse")
                            local show=(isBone and State.ESPBones) or (isCorpse and State.ESPCorpses); local dist=(myPos-part.Position).Magnitude
                            if show and dist<=State.WorldESPMaxDistance then
                                if not worldGuis[obj] or not worldGuis[obj].gui or not worldGuis[obj].gui.Parent then
                                    local bGui=Instance.new("BillboardGui"); bGui.Name="PE_WorldESP"; bGui.Size=UDim2.fromOffset(150,26); bGui.StudsOffset=Vector3.new(0,2.5,0); bGui.AlwaysOnTop=true; bGui.Parent=ESPFolder
                                    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.fromScale(1,1); lbl.BackgroundTransparency=1; lbl.TextStrokeTransparency=0.1; lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12; lbl.TextColor3=isBone and Color3.fromRGB(255,235,150) or Color3.fromRGB(255,110,90); lbl.Parent=bGui
                                    worldGuis[obj]={gui=bGui,label=lbl}
                                endlocal TargetSize = UDim2.fromOffset(530, 340)
local IconSize = UDim2.fromOffset(50, 50)
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.Name="PriorExtinction_UI"; ScreenGui.ResetOnSpawn=false; ScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; pcall(function() ScreenGui.Parent=Utils.GuiParent() end)
local MainFrame = Instance.new("Frame"); MainFrame.AnchorPoint=Vector2.new(0.5,0.5); MainFrame.Position=UDim2.fromScale(0.5,0.5); MainFrame.Size=UDim2.fromOffset(0,0); MainFrame.BackgroundColor3=Theme.Background; MainFrame.ClipsDescendants=true; MainFrame.Parent=ScreenGui; Utils.Style(MainFrame,12,Theme.Stroke,1.2)
local TopBar = Instance.new("Frame"); TopBar.Size=UDim2.new(1,0,0,42); TopBar.BackgroundColor3=Theme.Surface; TopBar.Parent=MainFrame; Utils.Style(TopBar,12,nil)
local TitleLabel = Instance.new("TextLabel"); TitleLabel.Size=UDim2.new(1,-120,1,0); TitleLabel.Position=UDim2.fromOffset(15,0); TitleLabel.BackgroundTransparency=1; TitleLabel.Text="PRIOR EXTINCTION // ULTIMATE"; TitleLabel.TextColor3=Theme.TextPrimary; TitleLabel.Font=Enum.Font.GothamBold; TitleLabel.TextSize=13; TitleLabel.TextXAlignment=Enum.TextXAlignment.Left; TitleLabel.Parent=TopBar
local MinimizeBtn = Instance.new("TextButton"); MinimizeBtn.Size=UDim2.fromOffset(32,28); MinimizeBtn.Position=UDim2.new(1,-40,0.5,-14); MinimizeBtn.BackgroundColor3=Theme.Element; MinimizeBtn.Text="—"; MinimizeBtn.TextColor3=Theme.TextPrimary; MinimizeBtn.Font=Enum.Font.GothamBold; MinimizeBtn.TextSize=14; MinimizeBtn.Parent=TopBar; Utils.Style(MinimizeBtn,6,Theme.Stroke,1)
local MiniIcon = Instance.new("TextButton"); MiniIcon.AnchorPoint=Vector2.new(0.5,0.5); MiniIcon.Position=UDim2.new(0.1,0,0.2,0); MiniIcon.Size=UDim2.fromOffset(0,0); MiniIcon.BackgroundColor3=Theme.Surface; MiniIcon.Text="PE"; MiniIcon.TextColor3=Theme.TextPrimary; MiniIcon.Font=Enum.Font.GothamBold; MiniIcon.TextSize=14; MiniIcon.Visible=false; MiniIcon.Parent=ScreenGui; Utils.Style(MiniIcon,25,Theme.Stroke,1.5)
local Sidebar = Instance.new("Frame"); Sidebar.Size=UDim2.new(0,145,1,-42); Sidebar.Position=UDim2.fromOffset(0,42); Sidebar.BackgroundColor3=Theme.Surface; Sidebar.Parent=MainFrame
local TabList = Instance.new("ScrollingFrame"); TabList.Size=UDim2.new(1,-16,1,-66); TabList.Position=UDim2.fromOffset(8,10); TabList.BackgroundTransparency=1; TabList.ScrollBarThickness=0; TabList.CanvasSize=UDim2.new(0,0,0,0); TabList.AutomaticCanvasSize=Enum.AutomaticSize.Y; TabList.Parent=Sidebar
local TabListLayout = Instance.new("UIListLayout"); TabListLayout.Padding=UDim.new(0,6); TabListLayout.Parent=TabList
local DeactivateBtn = Instance.new("TextButton"); DeactivateBtn.Size=UDim2.new(1,-16,0,38); DeactivateBtn.Position=UDim2.new(0,8,1,-46); DeactivateBtn.BackgroundColor3=Theme.Danger; DeactivateBtn.Text="Deactivate"; DeactivateBtn.TextColor3=Theme.TextPrimary; DeactivateBtn.Font=Enum.Font.GothamSemibold; DeactivateBtn.TextSize=13; DeactivateBtn.Parent=Sidebar; Utils.Style(DeactivateBtn,8,Theme.DangerStroke,1)
local PagesContainer = Instance.new("Frame"); PagesContainer.Size=UDim2.new(1,-145,1,-42); PagesContainer.Position=UDim2.fromOffset(145,42); PagesContainer.BackgroundTransparency=1; PagesContainer.Parent=MainFrame
local Tabs = {}; local CurrentTab = nil
local function SelectTab(tabName) for name,data in pairs(Tabs) do local isSelected=(name==tabName); data.Page.Visible=isSelected; data.Button.BackgroundColor3=isSelected and Theme.ElementActive or Theme.Element; data.Button.TextColor3=isSelected and Theme.TextPrimary or Theme.TextSecondary end; CurrentTab=tabName end
local function CreateTab(tabName)
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,0,38); btn.BackgroundColor3=Theme.Element; btn.Text=tabName; btn.TextColor3=Theme.TextSecondary; btn.Font=Enum.Font.GothamMedium; btn.TextSize=13; btn.Parent=TabList; Utils.Style(btn,8,Theme.Stroke,1)
    local page=Instance.new("ScrollingFrame"); page.Size=UDim2.new(1,-20,1,-20); page.Position=UDim2.fromOffset(10,10); page.BackgroundTransparency=1; page.ScrollBarThickness=2; page.CanvasSize=UDim2.new(0,0,0,0); page.AutomaticCanvasSize=Enum.AutomaticSize.Y; page.Visible=false; page.Parent=PagesContainer
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,8); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=page
    Utils.Track(btn.Activated:Connect(function() SelectTab(tabName) end))
    Tabs[tabName]={Button=btn,Page=page}; if not CurrentTab then SelectTab(tabName) end; return page
end
local function CreateToggle(parent,text,defaultState,order,callback)
    local btn=Instance.new("TextButton"); btn.LayoutOrder=order; btn.Size=UDim2.new(1,0,0,42); btn.BackgroundColor3=Theme.Surface; btn.Text=""; btn.AutoButtonColor=false; btn.Parent=parent; Utils.Style(btn,8,Theme.Stroke,1)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-70,1,0); lbl.Position=UDim2.fromOffset(12,0); lbl.BackgroundTransparency=1; lbl.Text=text; lbl.TextColor3=Theme.TextPrimary; lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Parent=btn
    local ind=Instance.new("Frame"); ind.Size=UDim2.fromOffset(40,22); ind.Position=UDim2.new(1,-52,0.5,-11); ind.BackgroundColor3=defaultState and Theme.ElementActive or Theme.Element; ind.Parent=btn; Utils.Style(ind,11,Theme.Stroke,1)
    local kn=Instance.new("Frame"); kn.Size=UDim2.fromOffset(16,16); kn.Position=defaultState and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3); kn.BackgroundColor3=defaultState and Theme.TextPrimary or Theme.TextSecondary; kn.Parent=ind; Utils.Style(kn,8,nil)
    local state=defaultState
    Utils.Track(btn.Activated:Connect(function() state=not state; ind.BackgroundColor3=state and Theme.ElementActive or Theme.Element; kn.Position=state and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3); kn.BackgroundColor3=state and Theme.TextPrimary or Theme.TextSecondary; if callback then pcall(callback,state) end end))
end
local function CreateCycleButton(parent,labelPrefix,options,defaultIndex,order,callback)
    local idx=defaultIndex or 1
    local btn=Instance.new("TextButton"); btn.LayoutOrder=order; btn.Size=UDim2.new(1,0,0,42); btn.BackgroundColor3=Theme.Element; btn.Text=labelPrefix..": "..tostring(options[idx]); btn.TextColor3=Theme.TextPrimary; btn.Font=Enum.Font.GothamSemibold; btn.TextSize=13; btn.Parent=parent; Utils.Style(btn,8,Theme.Stroke,1)
    Utils.Track(btn.Activated:Connect(function() idx=(idx%#options)+1; btn.Text=labelPrefix..": "..tostring(options[idx]); if callback then pcall(callback,options[idx],idx) end end))
end
local CombatPage=CreateTab("Combat"); local RenderPage=CreateTab("Render"); local ToolsPage=CreateTab("Tools")
CreateToggle(CombatPage,"Silent Aim",State.SilentAim,1,function(v) State.SilentAim=v end)
CreateCycleButton(CombatPage,"Цель Silent Aim",{"Head","Jaw","Body","Tail","Leg"},1,2,function(opt) State.AimTargetPart=opt end)
CreateToggle(CombatPage,"Hitbox Expander",State.HitboxMaster,3,function(v) State.HitboxMaster=v end)
CreateCycleButton(CombatPage,"Часть тела Хитбокса",{"Head","Jaw","Body","Tail","Leg"},1,4,function(opt) State.SelectedHitboxPart=opt end)
CreateCycleButton(CombatPage,"Уровень размера Хитбокса",{"1 (10)","2 (16)","3 (22)","4 (28)","5 (35)"},State.HitboxSizeLevel,5,function(_,idx) State.HitboxSizeLevel=idx end)
CreateToggle(CombatPage,"No Attack CD",State.NoAttackCD,6,function(v) State.NoAttackCD=v end)
CreateToggle(RenderPage,"ESP Игроков",State.ESPEnabled,1,function(v) State.ESPEnabled=v end)
CreateToggle(RenderPage,"Показывать Полоску HP",State.ESP_Health,2,function(v) State.ESP_Health=v end)
CreateToggle(RenderPage,"Показывать Полоску Стамины",State.ESP_Stamina,3,function(v) State.ESP_Stamina=v end)
CreateCycleButton(RenderPage,"Дистанция ESP Игроков",{1000,2000,3500,5000},2,4,function(val) State.ESPMaxDistance=val end)
CreateToggle(RenderPage,"ESP Костей",State.ESPBones,5,function(v) State.ESPBones=v; if v then task.spawn(ESPModule.ScanWorldItems) end end)
CreateToggle(RenderPage,"ESP Еды / Трупов",State.ESPCorpses,6,function(v) State.ESPCorpses=v; if v then task.spawn(ESPModule.ScanWorldItems) end end)
CreateToggle(RenderPage,"Night Vision",State.NightVision,7,function(v) State.NightVision=v end)
CreateToggle(RenderPage,"No Blur",State.NoBlur,8,function(v) State.NoBlur=v end)
CreateToggle(RenderPage,"No Sleep Screen",State.NoSleepScreen,9,function(v) State.NoSleepScreen=v end)
CreateToggle(ToolsPage,"Auto Clean (Вечный)",State.AutoClean,1,function(v) State.AutoClean=v; if v then Utils.Notify("Auto Clean","Помойся 1 раз для перехвата!") end end)
CreateToggle(ToolsPage,"Auto Eat (Вечный)",State.AutoEat,2,function(v) State.AutoEat=v; if v then Utils.Notify("Auto Eat","Съешь 1 раз для перехвата!") end end)
CreateToggle(ToolsPage,"Save Dino",false,3,function(v) SaveDino.SetEnabled(v) end)
CreateCycleButton(ToolsPage,"Направление Save Dino",{"Down","Up"},1,4,function(_,idx) State.SaveDinoMode=(idx==1) and "Down" or "Up"; SaveDino.RecalculateTarget(); if State.SaveDinoPhase=="holding" then State.SaveDinoPhase="moving_to_safe" end end)
CreateCycleButton(ToolsPage,"Глубина Save Dino",{50,70,95,120},2,5,function(val) State.SaveDinoOffset=val; SaveDino.RecalculateTarget(); if State.SaveDinoPhase=="holding" then State.SaveDinoPhase="moving_to_safe" end end)
local function MinimizeUI() if State.Minimized then return end State.Minimized=true; MainFrame.Visible=false; MiniIcon.Size=IconSize; MiniIcon.Visible=true end
local function RestoreUI() if not State.Minimized then return end State.Minimized=false; MiniIcon.Visible=false; MainFrame.Visible=true end
local function DeactivateScript()
    if not State.Active then return end
    State.Active=false; State.SilentAim=false; State.HitboxMaster=false; State.ESPEnabled=false; State.ESPBones=false; State.ESPCorpses=false; State.NoAttackCD=false; State.AutoClean=false; State.AutoEat=false
    Visuals.Restore(); SaveDino.ForceReset(); Combat.RestoreAll(); ESPModule.Cleanup()
    for _,conn in ipairs(State.Connections) do pcall(function() conn:Disconnect() end) end; table.clear(State.Connections)
    pcall(function() ScreenGui:Destroy() end); Env.PriorUI_Cleanup=nil; Utils.Notify("Prior Extinction","Скрипт выгружен.")
end
Env.PriorUI_Cleanup=DeactivateScript
Utils.Drag(TopBar,MainFrame,nil); Utils.Drag(MiniIcon,MiniIcon,RestoreUI)
Utils.Track(MinimizeBtn.Activated:Connect(MinimizeUI)); Utils.Track(DeactivateBtn.Activated:Connect(DeactivateScript))
Visuals.Init(); Survival.Init(); SaveDino.Init(); Combat.Init(); ESPModule.Init()
task.spawn(function() pcall(function() TweenService:Create(MainFrame,TweenInfo.new(0.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=TargetSize}):Play() end) end)
        
