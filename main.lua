-- 3. Visuals & Unlock Camera (Исправленный No Sleep Screen без лагов)
local Visuals = {}
local wasNightVision = false
local wasUnlockCam = false
local SleepBlackouts = {}

local function CheckIfSleepOverlay(g)
    if not g or not g.Parent then return end
    if g:IsDescendantOf(MainFrame) or g.Name == "PE_UPad" then return end
    if g:IsA("Frame") or g:IsA("ImageLabel") or g:IsA("CanvasGroup") then
        local n = string.lower(g.Name)
        local pn = g.Parent and string.lower(g.Parent.Name) or ""
        -- Ловим по названию (Sleep, Rest, Blink, Vignette, Blackout, Fade, Eyes) или по полноэкранному размеру
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
            task.defer(function() pcall(CheckIfSleepOverlay, desc) end)
        end))
    end

    -- Быстрый перехват черного экрана сна и размытия без нагрузки на телефон
    Utils.Track(RunService.RenderStepped:Connect(function()
        if not State.Active then return end

        if State.NoBlur or State.NoSleepScreen then
            ProcessPostEffects(Lighting)
            if Workspace.CurrentCamera then
                ProcessPostEffects(Workspace.CurrentCamera)
            end
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
                            local ic = g.ImageColor3
                            local bc = g.BackgroundColor3
                            if (ic.R < 0.25 and ic.G < 0.25 and ic.B < 0.25 and g.ImageTransparency < 0.98) then
                                g.ImageTransparency = 1
                            end
                            if (bc.R < 0.22 and bc.G < 0.22 and bc.B < 0.22 and g.BackgroundTransparency < 0.98) then
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

    -- Таймер для камеры и ночного зрения (раз в 0.2 сек)
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
            task.wait(0.2)
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
