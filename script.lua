local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local setclipboard = setclipboard or toclipboard
local isMobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)

-- Core Aimbot Vars
local enabled, showFOV, espEnabled, tracersEnabled = false, false, false, false
local noClipEnabled, infJumpEnabled, walkSpeedEnabled, jumpPowerEnabled = false, false, false, false
local crosshairEnabled, teamCheckEnabled = false, true
local selectedTeams, allTeams, espObjects = {["All"] = true}, {}, {}
local fovRadius, smoothness, walkSpeed, jumpPower = 75, 0.4, 16, 50
local defaultWalkSpeed, defaultJumpPower = 16, 50
local espColor, crosshairColor = Color3.new(1, 1, 1), Color3.new(1, 0, 0)
local crosshairSize = 10
local tracerOrigin = "Center"
local targetPart = "Head"

-- Trigger Bot Vars
local triggerBotEnabled = false
local triggerBotDelay = 0.1
local targetPriority = "Closest to Center"

-- Hitbox Expander Vars
local hitboxEnabled = false
local hitboxTargetPart = "Head"
local hitboxSize = 10
local hitboxTransparency = 0.5
local originalHitboxSizes = {}
local hitboxVisuals = {} -- Store forcefield objects

-- Player Management Vars
local whitelistedPlayers = {}
local playerListData = {}
local selectedPlayer = nil

-- Movement Vars
local cframeFlyEnabled = false
local flightSpeed = 16
local flyingConnection = nil
local gravityEnabled = false
local originalGravity = workspace.Gravity
local customGravity = 50

-- World Vars
local fullbrightEnabled = false
local timeChangerEnabled = false
local currentTime = 12
local ambienceEnabled = false
local brightnessLevel = 1
local greySkyEnabled = false
local noTextureEnabled = false
local noEffectsEnabled = false
local originalLightingSettings = {}
local instantInteractEnabled = false
local autoInteractEnabled = false

-- Client Vars
local infiniteZoomEnabled = false
local originalMaxZoomDistance = LocalPlayer.CameraMaxZoomDistance
local aspectRatioEnabled = false
local aspectRatioValue = 1.778
local instantRespawnEnabled = false
local korbloxLegEnabled = false
local headlessEnabled = false
local fpsEnhancerEnabled = false

-- Anti-AFK
local antiAFKConnection = nil

-- FOV Circle
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.Thickness = 1.5
fovCircle.Radius = fovRadius
fovCircle.NumSides = 90
fovCircle.Filled = false
fovCircle.Visible = false

-- Custom Crosshair
local crosshairV = Drawing.new("Line")
crosshairV.Thickness = 1
crosshairV.Color = crosshairColor
crosshairV.Visible = false

local crosshairH = Drawing.new("Line")
crosshairH.Thickness = 1
crosshairH.Color = crosshairColor
crosshairH.Visible = false

-- Utility Functions
local function safeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("Error in safeCall:", result)
    end
    return success, result
end

local function getPlayerFromPartial(partial)
    partial = partial:lower()
    for _, player in ipairs(Players:GetPlayers()) do
        if (player.Name and player.Name:lower():find(partial)) or (player.DisplayName and player.DisplayName:lower():find(partial)) then
            return player
        end
    end
    return nil
end

local function isWhitelisted(player)
    for _, name in ipairs(whitelistedPlayers) do
        if (player.Name and player.Name:lower() == name:lower()) or (player.DisplayName and player.DisplayName:lower() == name:lower()) then
            return true
        end
    end
    return false
end

local function updatePlayerList()
    playerListData = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerListData, string.format("%s @%s", player.DisplayName or player.Name, player.Name))
        end
    end
    return playerListData
end

-- ESP Cleanup
local function clearESP()
    for _, data in pairs(espObjects) do
        safeCall(function()
            if data.Text then data.Text:Remove() end
            if data.Tracer then data.Tracer:Remove() end
            if data.Highlight then
                if data.Highlight.Destroy then
                    data.Highlight:Destroy()
                end
            end
        end)
    end
    espObjects = {}
end

-- ESP and Tracers Update
local function updateESP()
    for player, data in pairs(espObjects) do
        if not player or not player.Parent or not player.Character or 
           not player.Character:FindFirstChild("Humanoid") or 
           player.Character:FindFirstChild("Humanoid").Health <= 0 or 
           (teamCheckEnabled and not selectedTeams["All"] and not selectedTeams[tostring(player.Team)]) then
            safeCall(function()
                if data.Text then data.Text:Remove() end
                if data.Tracer then data.Tracer:Remove() end
                if data.Highlight and data.Highlight.Destroy then data.Highlight:Destroy() end
            end)
            espObjects[player] = nil
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not teamCheckEnabled or selectedTeams["All"] or selectedTeams[tostring(player.Team)] then
                local char = player.Character
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local humanoid = char:FindFirstChildOfClass("Humanoid")

                if hrp and humanoid and humanoid.Health > 0 then
                    local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
                    -- skip far players (>1000)
                    if distance <= 1000 then
                        local tagData = espObjects[player]

                        if not tagData then
                            local text = Drawing.new("Text")
                            text.Size = 13
                            text.Center = true
                            text.Outline = true
                            text.Color = espColor
                            text.Visible = true

                            local tracer = Drawing.new("Line")
                            tracer.Thickness = 1
                            tracer.Color = espColor
                            tracer.Visible = tracersEnabled

                            tagData = {Text = text, Tracer = tracer}
                            espObjects[player] = tagData
                        end

                        if not tagData.Highlight or not tagData.Highlight.Parent or tagData.Highlight.Adornee ~= char then
                            safeCall(function()
                                if tagData.Highlight then tagData.Highlight:Destroy() end
                            end)

                            local success, hl = safeCall(function()
                                local highlight = Instance.new("Highlight")
                                highlight.FillColor = espColor
                                highlight.FillTransparency = 0.7
                                highlight.OutlineTransparency = 1
                                highlight.Adornee = char
                                highlight.Parent = char
                                return highlight
                            end)

                            if success then
                                tagData.Highlight = hl
                            end
                        end

                        local dist = math.floor(distance)
                        local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

                        if onScreen then
                            local textLine = string.format("%s [%dm] | HP: %d", player.Name, dist, math.floor(humanoid.Health))
                            tagData.Text.Text = textLine
                            tagData.Text.Position = Vector2.new(screenPos.X, screenPos.Y - 20)
                            tagData.Text.Visible = true
                            tagData.Text.Color = espColor

                            if tagData.Tracer and tracersEnabled then
                                local fromPos
                                if tracerOrigin == "Center" then
                                    fromPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                                elseif tracerOrigin == "Bottom" then
                                    fromPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                else
                                    fromPos = Vector2.new(Camera.ViewportSize.X / 2, 0)
                                end
                                tagData.Tracer.From = fromPos
                                tagData.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                                tagData.Tracer.Visible = true
                                tagData.Tracer.Color = espColor
                            end

                            if tagData.Highlight then tagData.Highlight.FillColor = espColor end
                        else
                            tagData.Text.Visible = false
                            if tagData.Tracer then tagData.Tracer.Visible = false end
                        end
                    end
                end
            end
        end
    end
end

-- Update Crosshair
local function updateCrosshair()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    crosshairV.From = Vector2.new(center.X, center.Y - crosshairSize)
    crosshairV.To = Vector2.new(center.X, center.Y + crosshairSize)
    crosshairV.Color = crosshairColor
    crosshairV.Visible = false -- Controlled by updateCrosshair visibility check

    crosshairH.From = Vector2.new(center.X - crosshairSize, center.Y)
    crosshairH.To = Vector2.new(center.X + crosshairSize, center.Y)
    crosshairH.Color = crosshairColor
    crosshairH.Visible = false -- Controlled by updateCrosshair visibility check
end

-- Aimbot FOV Check
local function isInsideFOV(part)
    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if onScreen then
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local mousePos = UserInputService:GetMouseLocation()
        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        return dist <= fovRadius
    end
    return false
end

-- Target System
local function getClosestTarget()
    local closest, shortest = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(targetPart) and not isWhitelisted(player) then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                if not teamCheckEnabled or selectedTeams["All"] or selectedTeams[tostring(player.Team)] then
                    local part = player.Character:FindFirstChild(targetPart)
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist
                        
                        if targetPriority == "Closest to Center" then
                            dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        elseif targetPriority == "Closest to Player" then
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                dist = (part.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                            else
                                dist = math.huge
                            end
                        elseif targetPriority == "Lowest HP" then
                            dist = humanoid.Health
                        end

                        if dist <= fovRadius or targetPriority ~= "Closest to Center" then
                            local params = RaycastParams.new()
                            params.FilterDescendantsInstances = {LocalPlayer.Character, workspace.CurrentCamera}
                            params.FilterType = Enum.RaycastFilterType.Blacklist
                            
                            local success, ray = safeCall(function()
                                return workspace:Raycast(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 1000, params)
                            end)

                            if success and (not ray or ray.Instance:IsDescendantOf(player.Character)) then
                                if dist < shortest then
                                    shortest = dist
                                    closest = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return closest
end

-- Trigger Bot
local lastTriggerTime = 0
local function updateTriggerBot()
    if not triggerBotEnabled or not LocalPlayer.Character then return end
    
    local currentTime = tick()
    if currentTime - lastTriggerTime < triggerBotDelay then return end
    
    local target = getClosestTarget()
    if target then
        lastTriggerTime = currentTime
        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            safeCall(function()
                tool:Activate()
            end)
        end
    end
end

-- Hitbox Expander
local function expandHitboxes()
    if not hitboxEnabled then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and not isWhitelisted(player) then
            local part = player.Character:FindFirstChild(hitboxTargetPart)
            if part and part:IsA("BasePart") then
                if not originalHitboxSizes[player] then
                    originalHitboxSizes[player] = {Size = part.Size, Transparency = part.Transparency}
                end
                
                safeCall(function()
                    part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                    part.Transparency = 1 -- Make actual part invisible
                    part.CanCollide = false
                    part.Massless = true -- Prevent movement interference
                    
                    -- Visual Forcefield
                    local visual = hitboxVisuals[player]
                    if not visual or visual.Parent ~= part then
                        if visual then visual:Destroy() end
                        visual = Instance.new("Part")
                        visual.Name = "HitboxVisual"
                        visual.Shape = Enum.PartType.Ball
                        visual.Material = Enum.Material.ForceField
                        visual.CastShadow = false
                        visual.CanCollide = false
                        visual.Anchored = false
                        visual.Massless = true
                        visual.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                        visual.CFrame = part.CFrame
                        visual.Parent = part
                        
                        local weld = Instance.new("WeldConstraint")
                        weld.Part0 = part
                        weld.Part1 = visual
                        weld.Parent = visual
                        
                        hitboxVisuals[player] = visual
                    else
                        visual.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                    end
                end)
            end
        end
    end
end

local function restoreHitboxes()
    for player, data in pairs(originalHitboxSizes) do
        if player and player.Character then
            local part = player.Character:FindFirstChild(hitboxTargetPart)
            if part and part:IsA("BasePart") then
                safeCall(function()
                    part.Size = data.Size
                    part.Transparency = data.Transparency
                    part.CanCollide = true
                end)
            end
        end
    end
    for _, visual in pairs(hitboxVisuals) do
        if visual then visual:Destroy() end
    end
    hitboxVisuals = {}
    originalHitboxSizes = {}
end

-- NoClip Function
local originalCollisions = {}
local function updateNoClip()
    if noClipEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                if not originalCollisions[part] then
                    originalCollisions[part] = part.CanCollide
                end
                part.CanCollide = false
            end
        end
    else
        for part, original in pairs(originalCollisions) do
            if part and part.Parent then
                part.CanCollide = original
            end
        end
        originalCollisions = {}
    end
end

-- CFrame Fly
local function startCFrameFly()
    if flyingConnection then flyingConnection:Disconnect() end
    
    flyingConnection = RunService.Heartbeat:Connect(function()
        if not cframeFlyEnabled or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
        
        local hrp = LocalPlayer.Character.HumanoidRootPart
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
        
        local moveDir = Vector3.new(0,0,0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - Vector3.new(0,1,0) end
        
        if moveDir.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (moveDir.Unit * flightSpeed * RunService.Heartbeat:Wait())
        end
        hrp.Velocity = Vector3.new(0,0,0)
    end)
end

local function stopCFrameFly()
    if flyingConnection then
        flyingConnection:Disconnect()
        flyingConnection = nil
    end
end

-- Gravity Control
local function updateGravity()
    if gravityEnabled then
        workspace.Gravity = customGravity
    else
        workspace.Gravity = originalGravity
    end
end

-- Instant Interaction
local function setupInstantInteraction()
    if instantInteractEnabled then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                safeCall(function()
                    obj.HoldDuration = 0
                end)
            end
        end
    end
end

-- Auto Interact
local autoInteractConnection = nil
local function updateAutoInteract()
    if autoInteractConnection then
        autoInteractConnection:Disconnect()
        autoInteractConnection = nil
    end
    
    if autoInteractEnabled then
        autoInteractConnection = RunService.Heartbeat:Connect(function()
            if not LocalPlayer.Character then return end
            
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") and obj.Enabled then
                    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position - obj.Parent.Position).Magnitude <= obj.MaxActivationDistance then
                        safeCall(function()
                            fireproximityprompt(obj)
                        end)
                    end
                end
            end
        end)
    end
end

-- World Modifications
local function saveLightingSettings()
    safeCall(function()
        originalLightingSettings = {
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
        }
    end)
end

local function applyFullbright()
    if fullbrightEnabled then
        safeCall(function()
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        end)
    else
        safeCall(function()
            Lighting.Brightness = originalLightingSettings.Brightness or 1
            Lighting.ClockTime = originalLightingSettings.ClockTime or 12
            Lighting.FogEnd = originalLightingSettings.FogEnd or 100000
            Lighting.GlobalShadows = originalLightingSettings.GlobalShadows ~= false
            Lighting.OutdoorAmbient = originalLightingSettings.OutdoorAmbient or Color3.new(0.5, 0.5, 0.5)
            Lighting.Ambient = originalLightingSettings.Ambient or Color3.new(0.5, 0.5, 0.5)
        end)
    end
end

local function updateTimeChanger()
    if timeChangerEnabled then
        safeCall(function()
            Lighting.ClockTime = currentTime
        end)
    else
        safeCall(function()
            Lighting.ClockTime = originalLightingSettings.ClockTime or 12
        end)
    end
end

local function updateAmbience()
    if ambienceEnabled then
        safeCall(function()
            Lighting.Brightness = brightnessLevel
        end)
    else
        safeCall(function()
            Lighting.Brightness = originalLightingSettings.Brightness or 1
        end)
    end
end

local function applyGreySky()
    if greySkyEnabled then
        safeCall(function()
            for _, obj in pairs(Lighting:GetChildren()) do
                if obj:IsA("Sky") then
                    obj:Destroy()
                end
            end
            local sky = Instance.new("Sky")
            sky.Name = "GreySkyAsset"
            sky.SkyboxBk = "rbxassetid://6008304405"
            sky.SkyboxDn = "rbxassetid://6008304405"
            sky.SkyboxFt = "rbxassetid://6008304405"
            sky.SkyboxLf = "rbxassetid://6008304405"
            sky.SkyboxRt = "rbxassetid://6008304405"
            sky.SkyboxUp = "rbxassetid://6008304405"
            sky.Parent = Lighting
            
            Lighting.OutdoorAmbient = Color3.new(0.2, 0.2, 0.2)
            Lighting.Ambient = Color3.new(0.2, 0.2, 0.2)
            Lighting.Brightness = 0.5
        end)
    else
        safeCall(function()
            for _, obj in pairs(Lighting:GetChildren()) do
                if obj.Name == "GreySkyAsset" or obj:IsA("Sky") then obj:Destroy() end
            end
            -- Re-apply default/stored settings
            Lighting.OutdoorAmbient = originalLightingSettings.OutdoorAmbient or Color3.new(0.5, 0.5, 0.5)
            Lighting.Ambient = originalLightingSettings.Ambient or Color3.new(0.5, 0.5, 0.5)
            Lighting.Brightness = originalLightingSettings.Brightness or 1
        end)
    end
end

local function applyNoTexture()
    if noTextureEnabled then
        for _, obj in pairs(workspace:GetDescendants()) do
            safeCall(function()
                if obj:IsA("BasePart") then
                    obj.Material = Enum.Material.SmoothPlastic
                end
                if obj:IsA("Decal") or obj:IsA("Texture") then
                    obj:Destroy()
                end
            end)
        end
    end
end

local function applyNoEffects()
    if noEffectsEnabled then
        safeCall(function()
            for _, obj in pairs(Lighting:GetChildren()) do
                if obj:IsA("PostEffect") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or 
                   obj:IsA("ColorCorrectionEffect") or obj:IsA("SunRaysEffect") then
                    obj.Enabled = false
                end
            end
        end)
    end
end

-- Client Modifications
local function applyKorbloxLeg()
    if korbloxLegEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("RightLowerLeg") then
        safeCall(function()
            local leg = LocalPlayer.Character.RightLowerLeg
            if leg:FindFirstChildOfClass("SpecialMesh") then
                leg:FindFirstChildOfClass("SpecialMesh").MeshId = "rbxassetid://902942093"
            end
            leg.Transparency = 1
        end)
    end
end

local function applyHeadless()
    if headlessEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
        safeCall(function()
            LocalPlayer.Character.Head.Transparency = 1
            for _, obj in pairs(LocalPlayer.Character.Head:GetChildren()) do
                if obj:IsA("Decal") or obj:IsA("Part") then
                    obj:Destroy()
                end
            end
        end)
    end
end

local function updateZoom()
    if infiniteZoomEnabled then
        LocalPlayer.CameraMaxZoomDistance = 100000
    else
        LocalPlayer.CameraMaxZoomDistance = originalMaxZoomDistance
    end
end

local function updateAspectRatio()
    if aspectRatioEnabled then
        Camera.FieldOfView = 70 * aspectRatioValue
    else
        Camera.FieldOfView = 70
    end
end

local function instantRespawn()
    if instantRespawnEnabled and LocalPlayer.Character then
        LocalPlayer.Character:BreakJoints()
    end
end

-- Anti-AFK
local function startAntiAFK()
    if antiAFKConnection then antiAFKConnection:Disconnect() end
    antiAFKConnection = LocalPlayer.Idled:Connect(function()
        VirtualUser:Button2Down(Vector2.new(0,0), Camera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), Camera.CFrame)
    end)
end

local function stopAntiAFK()
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end
end

-- Main Loop
RunService.RenderStepped:Connect(function()
    if showFOV then
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Radius = fovRadius
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end

    if crosshairEnabled then
        updateCrosshair()
        crosshairV.Visible = true
        crosshairH.Visible = true
    else
        crosshairV.Visible = false
        crosshairH.Visible = false
    end

    if espEnabled then
        updateESP()
    else
        clearESP()
    end
    
    if enabled then
        local target = getClosestTarget()
        if target then
            local screenPos, onScreen = Camera:WorldToViewportPoint(target.Position)
            if onScreen then
                local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                local targetPos = Vector2.new(screenPos.X, screenPos.Y)
                
                if isMobile then
                    local currentCFrame = Camera.CFrame
                    local targetCFrame = CFrame.new(currentCFrame.Position, target.Position)
                    Camera.CFrame = currentCFrame:Lerp(targetCFrame, 1 - smoothness)
                else
                    local diff = (targetPos - center) * (1 - smoothness)
                    if mousemoverel then
                        mousemoverel(diff.X, diff.Y)
                    elseif setrbxcursorrelative then
                        setrbxcursorrelative(diff.X, diff.Y)
                    end
                end
            end
        end
    end
    
    if triggerBotEnabled then
        updateTriggerBot()
    end
    
    if hitboxEnabled then
        expandHitboxes()
    end
end)

local function rejoinServer()
    safeCall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

local function copyServerLink()
    if setclipboard then
        local link = string.format("Roblox.GameLauncher.joinGameInstance(%d, '%s')", game.PlaceId, game.JobId)
        setclipboard(link)
        Library:Notify({
            Title = "Server Link",
            Description = "Server link copied to clipboard!",
            Time = 3
        })
    end
end

-- Update Movement Settings
local function updateMovement()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local humanoid = LocalPlayer.Character.Humanoid
        humanoid.WalkSpeed = walkSpeedEnabled and walkSpeed or defaultWalkSpeed
        humanoid.JumpPower = jumpPowerEnabled and jumpPower or defaultJumpPower
    end
end

-- Initialize
saveLightingSettings()
updatePlayerList()

-- Update team list
for _, team in ipairs(Teams:GetChildren()) do
    table.insert(allTeams, team.Name)
end
table.insert(allTeams, "All")

-- UI Setup
local Window = Library:CreateWindow({
    Title = "Dark.cc Enhanced",
    Footer = "by Feyk",
    Icon = 4483362458,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

Library:Notify({
    Title = "Dark.cc | Universal Enhanced",
    Description = "Join Our Discord Server For More Scripts",
    Time = 6.5,
})

local Tabs = {
    Home = Window:AddTab("Home", "home"),
    Combat = Window:AddTab("Combat", "crosshair"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Player = Window:AddTab("Player", "users"),
    Movement = Window:AddTab("Movement", "move"),
    World = Window:AddTab("World", "globe"),
    Client = Window:AddTab("Client", "monitor"),
    Misc = Window:AddTab("Misc", "settings"),
    ["UI Settings"] = Window:AddTab("UI Settings", "wrench"),
}

-- Home Tab
local HomeGroupBox = Tabs.Home:AddLeftGroupbox("Welcome", "home")
HomeGroupBox:AddLabel("Dark.cc Enhanced Edition", true)
HomeGroupBox:AddLabel("Join our Discord for more scripts", true)

HomeGroupBox:AddButton({
    Text = "Copy Discord Link",
    Func = function()
        if setclipboard then
            setclipboard("https://discord.gg/yeKPEZpMMu")
            Library:Notify({
                Title = "Dark.cc",
                Description = "Discord link copied! ",
                Time = 3
            })
        end
    end,
})

local HomeGroupBox2 = Tabs.Home:AddRightGroupbox("Features", "list")
HomeGroupBox2:AddLabel("✓ Advanced Aimbot & Trigger Bot", true)
HomeGroupBox2:AddLabel("✓ Hitbox Expander", true)
HomeGroupBox2:AddLabel("✓ Full ESP System", true)
HomeGroupBox2:AddLabel("✓ Player Management", true)
HomeGroupBox2:AddLabel("✓ CFrame Fly & Movement", true)
HomeGroupBox2:AddLabel("✓ World Modifications", true)
HomeGroupBox2:AddLabel("✓ Client Customization", true)

-- Combat Tab - Aimbot
local CombatGroupBox = Tabs.Combat:AddLeftGroupbox("Aimbot", "crosshair")

CombatGroupBox:AddToggle("AimbotEnabled", {
    Text = "Enable Aimbot",
    Default = false,
    Callback = function(Value)
        enabled = Value
    end,
})

CombatGroupBox:AddToggle("ShowFOV", {
    Text = "Show FOV Circle",
    Default = false,
    Callback = function(Value)
        showFOV = Value
    end,
})

CombatGroupBox:AddSlider("FOVRadius", {
    Text = "FOV Radius",
    Default = 75,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        fovRadius = Value
    end,
})

CombatGroupBox:AddSlider("Smoothness", {
    Text = "Smoothness",
    Default = 0.4,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        smoothness = Value
    end,
})

CombatGroupBox:AddDropdown("TargetPart", {
    Values = {"Head", "HumanoidRootPart", "Torso"},
    Default = 1,
    Multi = false,
    Text = "Target Part",
    Callback = function(Value)
        targetPart = Value
    end,
})

CombatGroupBox:AddDropdown("Priority", {
    Values = {"Closest to Center", "Closest to Player", "Lowest HP"},
    Default = 1,
    Multi = false,
    Text = "Target Priority",
    Callback = function(Value)
        targetPriority = Value
    end,
})

CombatGroupBox:AddDropdown("TargetTeams", {
    Values = allTeams,
    Default = {"All"},
    Multi = true,
    Text = "Target Teams",
    Callback = function(Values)
        selectedTeams = Values
    end,
})

CombatGroupBox:AddToggle("TeamCheck", {
    Text = "Team Check",
    Default = true,
    Callback = function(Value)
        teamCheckEnabled = Value
    end,
})

local CombatGroupBox2 = Tabs.Combat:AddRightGroupbox("Trigger Bot", "zap")

CombatGroupBox2:AddToggle("TriggerBotEnabled", {
    Text = "Enable Trigger Bot",
    Default = false,
    Callback = function(Value)
        triggerBotEnabled = Value
    end,
})

CombatGroupBox2:AddSlider("TriggerDelay", {
    Text = "Trigger Delay (s)",
    Default = 0.1,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        triggerBotDelay = Value
    end,
})

local CombatGroupBox3 = Tabs.Combat:AddRightGroupbox("Hitbox Expander", "maximize")

CombatGroupBox3:AddToggle("HitboxEnabled", {
    Text = "Enable Hitbox Expander",
    Default = false,
    Callback = function(Value)
        hitboxEnabled = Value
        if not Value then
            restoreHitboxes()
        end
    end,
})

CombatGroupBox3:AddSlider("HitboxSize", {
    Text = "Hitbox Size",
    Default = 10,
    Min = 2,
    Max = 50,
    Rounding = 1,
    Callback = function(Value)
        hitboxSize = Value
    end,
})

CombatGroupBox3:AddSlider("HitboxTransparency", {
    Text = "Hitbox Transparency",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        hitboxTransparency = Value
    end,
})

-- Visuals Tab
local VisualsGroupBox = Tabs.Visuals:AddLeftGroupbox("ESP Settings", "eye")

VisualsGroupBox:AddToggle("ESPEnabled", {
    Text = "Enable ESP Highlights",
    Default = false,
    Callback = function(Value)
        espEnabled = Value
        if not Value then clearESP() end
    end,
})

VisualsGroupBox:AddToggle("TracersEnabled", {
    Text = "Enable Tracers",
    Default = false,
    Callback = function(Value)
        tracersEnabled = Value
    end,
})

VisualsGroupBox:AddLabel("ESP Color"):AddColorPicker("ESPColor", {
    Default = Color3.new(1, 1, 1),
    Title = "ESP Color",
    Callback = function(Value)
        espColor = Value
    end,
})

VisualsGroupBox:AddDropdown("TracerOrigin", {
    Values = {"Top", "Center", "Bottom"},
    Default = 3,
    Multi = false,
    Text = "Tracer Origin",
    Callback = function(Value)
        tracerOrigin = Value
    end,
})

local VisualsGroupBox2 = Tabs.Visuals:AddRightGroupbox("Crosshair", "plus")

VisualsGroupBox2:AddToggle("CrosshairEnabled", {
    Text = "Enable Custom Crosshair",
    Default = false,
    Callback = function(Value)
        crosshairEnabled = Value
    end,
})

VisualsGroupBox2:AddSlider("CrosshairSize", {
    Text = "Crosshair Size",
    Default = 10,
    Min = 5,
    Max = 30,
    Rounding = 0,
    Callback = function(Value)
        crosshairSize = Value
    end,
})

VisualsGroupBox2:AddLabel("Crosshair Color"):AddColorPicker("CrosshairColor", {
    Default = Color3.new(1, 0, 0),
    Title = "Crosshair Color",
    Callback = function(Value)
        crosshairColor = Value
    end,
})

-- Player Tab
local PlayerGroupBox = Tabs.Player:AddLeftGroupbox("Player List", "users")

local PlayerDropdown = PlayerGroupBox:AddDropdown("PlayerList", {
    Values = playerListData,
    Default = 1,
    Multi = false,
    Text = "Select Player",
})

PlayerGroupBox:AddButton("Refresh List", function()
    PlayerDropdown:SetValues(updatePlayerList())
end)

PlayerGroupBox:AddButton("Whitelist Selected", function()
    local selected = PlayerDropdown.Value
    if selected then
        local name = selected:split("@")[2]
        if name and not table.find(whitelistedPlayers, name) then
            table.insert(whitelistedPlayers, name)
            Library:Notify({Title = "Whitelist", Description = "Whitelisted " .. name})
        end
    end
end)

PlayerGroupBox:AddButton("Clear Whitelist", function()
    whitelistedPlayers = {}
    Library:Notify({Title = "Whitelist", Description = "Whitelist cleared!"})
end)

-- Movement Tab
local MovementGroupBox = Tabs.Movement:AddLeftGroupbox("Main", "zap")

MovementGroupBox:AddToggle("WalkSpeedEnabled", {
    Text = "Enable WalkSpeed",
    Default = false,
    Callback = function(Value)
        walkSpeedEnabled = Value
        updateMovement()
    end,
})

MovementGroupBox:AddSlider("WalkSpeed", {
    Text = "WalkSpeed Value",
    Default = 16,
    Min = 16,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        walkSpeed = Value
        if walkSpeedEnabled then updateMovement() end
    end,
})

MovementGroupBox:AddToggle("JumpPowerEnabled", {
    Text = "Enable JumpPower",
    Default = false,
    Callback = function(Value)
        jumpPowerEnabled = Value
        updateMovement()
    end,
})

MovementGroupBox:AddSlider("JumpPower", {
    Text = "JumpPower Value",
    Default = 50,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(Value)
        jumpPower = Value
        if jumpPowerEnabled then updateMovement() end
    end,
})

local MovementGroupBox2 = Tabs.Movement:AddRightGroupbox("Flight", "plane")

MovementGroupBox2:AddToggle("CFrameFly", {
    Text = "CFrame Fly",
    Default = false,
    Callback = function(Value)
        cframeFlyEnabled = Value
        if Value then
            startCFrameFly()
        else
            stopCFrameFly()
        end
    end,
})

MovementGroupBox2:AddSlider("FlightSpeed", {
    Text = "Flight Speed",
    Default = 16,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Callback = function(Value)
        flightSpeed = Value
    end,
})

MovementGroupBox2:AddLabel("Controls:  WASD + Space/Shift", true)

-- Movement Tab - Other
local MovementGroupBox3 = Tabs.Movement:AddLeftGroupbox("Other", "settings")

MovementGroupBox3:AddToggle("InfiniteJump", {
    Text = "Infinite Jump",
    Default = false,
    Callback = function(Value)
        infJumpEnabled = Value
    end,
})

MovementGroupBox3:AddToggle("NoClip", {
    Text = "NoClip",
    Default = false,
    Callback = function(Value)
        noClipEnabled = Value
        if not Value then
            updateNoClip()
        end
    end,
})

MovementGroupBox3:AddToggle("GravityControl", {
    Text = "Gravity Control",
    Default = false,
    Callback = function(Value)
        gravityEnabled = Value
        updateGravity()
    end,
})

MovementGroupBox3:AddSlider("CustomGravity", {
    Text = "Custom Gravity",
    Default = 50,
    Min = 1,
    Max = 196.2,
    Rounding = 1,
    Callback = function(Value)
        customGravity = Value
        if gravityEnabled then
            updateGravity()
        end
    end,
})

-- World Tab - Lighting
local WorldGroupBox = Tabs.World:AddLeftGroupbox("Lighting", "lightbulb")

WorldGroupBox:AddToggle("Fullbright", {
    Text = "Enable Fullbright",
    Default = false,
    Callback = function(Value)
        fullbrightEnabled = Value
        applyFullbright()
    end,
})

WorldGroupBox:AddToggle("TimeChanger", {
    Text = "Time Changer",
    Default = false,
    Callback = function(Value)
        timeChangerEnabled = Value
        updateTimeChanger()
    end,
})

WorldGroupBox:AddSlider("ClockTime", {
    Text = "Clock Time",
    Default = 12,
    Min = 0,
    Max = 24,
    Rounding = 1,
    Callback = function(Value)
        currentTime = Value
        if timeChangerEnabled then
            updateTimeChanger()
        end
    end,
})

WorldGroupBox:AddToggle("Ambience", {
    Text = "Ambience Control",
    Default = false,
    Callback = function(Value)
        ambienceEnabled = Value
        updateAmbience()
    end,
})

WorldGroupBox:AddSlider("BrightnessLevel", {
    Text = "Brightness",
    Default = 1,
    Min = 0,
    Max = 10,
    Rounding = 1,
    Callback = function(Value)
        brightnessLevel = Value
        if ambienceEnabled then updateAmbience() end
    end,
})

local WorldGroupBox2 = Tabs.World:AddRightGroupbox("World Effects", "image")

WorldGroupBox2:AddToggle("GreySky", {
    Text = "Grey Sky",
    Default = false,
    Callback = function(Value)
        greySkyEnabled = Value
        applyGreySky()
    end,
})

WorldGroupBox2:AddToggle("NoTexture", {
    Text = "No Textures",
    Default = false,
    Callback = function(Value)
        noTextureEnabled = Value
        if Value then applyNoTexture() end
    end,
})

WorldGroupBox2:AddToggle("NoEffects", {
    Text = "Disable Post Effects",
    Default = false,
    Callback = function(Value)
        noEffectsEnabled = Value
        if Value then applyNoEffects() end
    end,
})

WorldGroupBox2:AddToggle("InstantInteract", {
    Text = "Instant Interaction",
    Default = false,
    Callback = function(Value)
        instantInteractEnabled = Value
        if Value then setupInstantInteraction() end
    end,
})

WorldGroupBox2:AddToggle("AutoInteract", {
    Text = "Auto Interaction",
    Default = false,
    Callback = function(Value)
        autoInteractEnabled = Value
        updateAutoInteract()
    end,
})

-- Client Tab
local ClientGroupBox = Tabs.Client:AddLeftGroupbox("Camera", "video")

ClientGroupBox:AddToggle("InfiniteZoom", {
    Text = "Infinite Zoom",
    Default = false,
    Callback = function(Value)
        infiniteZoomEnabled = Value
        updateZoom()
    end,
})

ClientGroupBox:AddToggle("AspectRatio", {
    Text = "Aspect Ratio Changer",
    Default = false,
    Callback = function(Value)
        aspectRatioEnabled = Value
        updateAspectRatio()
    end,
})

ClientGroupBox:AddSlider("AspectRatioValue", {
    Text = "Aspect Ratio",
    Default = 1.778,
    Min = 0.1,
    Max = 4,
    Rounding = 3,
    Callback = function(Value)
        aspectRatioValue = Value
        if aspectRatioEnabled then updateAspectRatio() end
    end,
})

local ClientGroupBox2 = Tabs.Client:AddRightGroupbox("Character", "user")

ClientGroupBox2:AddToggle("AntiAFK", {
    Text = "Anti-AFK",
    Default = false,
    Callback = function(Value)
        if Value then startAntiAFK() else stopAntiAFK() end
    end,
})

ClientGroupBox2:AddToggle("KorbloxLeg", {
    Text = "Korblox Leg",
    Default = false,
    Callback = function(Value)
        korbloxLegEnabled = Value
        if Value then applyKorbloxLeg() end
    end,
})

ClientGroupBox2:AddToggle("Headless", {
    Text = "Headless",
    Default = false,
    Callback = function(Value)
        headlessEnabled = Value
        if Value then applyHeadless() end
    end,
})

ClientGroupBox2:AddButton("Instant Respawn", function()
    LocalPlayer.Character:BreakJoints()
end)

-- Misc Tab
local MiscGroupBox = Tabs.Misc:AddLeftGroupbox("Server", "server")

MiscGroupBox:AddButton("Rejoin Server", rejoinServer)
MiscGroupBox:AddButton("Copy Server Link", copyServerLink)

-- UI Settings Tab
local UIGroupBox = Tabs["UI Settings"]:AddLeftGroupbox("Settings", "wrench")

UIGroupBox:AddButton("Unload Script", function()
    Library:Unload()
end)

UIGroupBox:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "End",
    NoUI = true,
    Text = "Menu Keybind"
})

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

ThemeManager:SetFolder("DarkCC")
SaveManager:SetFolder("DarkCC/Universal")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

SaveManager:LoadAutoloadConfig()

-- Initial Movement Update
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    updateMovement()
    saveLightingSettings()
    if korbloxLegEnabled then applyKorbloxLeg() end
    if headlessEnabled then applyHeadless() end
end)

-- Infinite Jump implementation
UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
    end
end)
