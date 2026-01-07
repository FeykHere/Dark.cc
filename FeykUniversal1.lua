-- FeykHub | Universal (Final Build – ESP with Tracers, Crosshair, Movement, Teamcheck, Home Tab)
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local StarterGui = game:GetService("StarterGui")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local setclipboard = setclipboard or toclipboard

-- Core Vars
local enabled, showFOV, espEnabled, tracersEnabled, noClipEnabled, infJumpEnabled = false, false, false, false, false, false
local walkSpeedEnabled, jumpPowerEnabled, crosshairEnabled, teamCheckEnabled = false, false, false, true
local selectedTeams, allTeams, espObjects = {["All"] = true}, {}, {}
local fovRadius, smoothness, walkSpeed, jumpPower = 75, 0.4, 16, 50
local defaultWalkSpeed, defaultJumpPower = 16, 50 -- Default Roblox values
local espColor, crosshairColor = Color3.new(1, 1, 1), Color3.new(1, 0, 0)
local crosshairSize = 10
local tracerOrigin = "Center"
local lockedTarget = nil
local targetPart = "Head"

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

-- ESP Cleanup
local function clearESP()
    for _, data in pairs(espObjects) do
        if data.Text then pcall(function() data.Text:Remove() end) end
        if data.Tracer then pcall(function() data.Tracer:Remove() end) end
        if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
    end
    espObjects = {}
end

-- ESP and Tracers Update
local function updateESP()
    for player, data in pairs(espObjects) do
        if not player or not player.Parent or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character:FindFirstChild("Humanoid").Health <= 0 or (teamCheckEnabled and not selectedTeams["All"] and not selectedTeams[tostring(player.Team)]) then
            if data.Text then pcall(function() data.Text:Remove() end) end
            if data.Tracer then pcall(function() data.Tracer:Remove() end) end
            if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
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
                        if tagData.Highlight then pcall(function() tagData.Highlight:Destroy() end) end

                        local hl = Instance.new("Highlight")
                        hl.FillColor = espColor
                        hl.FillTransparency = 0.7
                        hl.OutlineTransparency = 1
                        hl.Adornee = char
                        hl.Parent = char

                        tagData.Highlight = hl
                    end

                    local dist = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)

                    if onScreen then
                        local textLine = string.format("%s [%dm] | health : %d", player.Name, dist, math.floor(humanoid.Health))
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
                            else -- Top
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

-- Update Crosshair
local function updateCrosshair()
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    crosshairV.From = Vector2.new(center.X, center.Y - crosshairSize)
    crosshairV.To = Vector2.new(center.X, center.Y + crosshairSize)
    crosshairV.Color = crosshairColor
    crosshairV.Visible = crosshairEnabled

    crosshairH.From = Vector2.new(center.X - crosshairSize, center.Y)
    crosshairH.To = Vector2.new(center.X + crosshairSize, center.Y)
    crosshairH.Color = crosshairColor
    crosshairH.Visible = crosshairEnabled
end

-- Target System
local function getClosestTarget()
    local closest, shortest = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(targetPart) then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                if not teamCheckEnabled or selectedTeams["All"] or selectedTeams[tostring(player.Team)] then
                    local part = player.Character:FindFirstChild(targetPart)
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist <= fovRadius then
                            local params = RaycastParams.new()
                            params.FilterDescendantsInstances = {LocalPlayer.Character}
                            params.FilterType = Enum.RaycastFilterType.Blacklist
                            local ray = workspace:Raycast(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 999, params)
                            if ray and ray.Instance:IsDescendantOf(player.Character) then
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

-- NoClip Function
local function updateNoClip()
    if noClipEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
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

-- Notify
Rayfield:Notify({
    Title = "Dark.cc | Universal",
    Content = "Join Our Discord Server For More Scripts",
    Duration = 6.5,
    Actions = {
        Accept = { Name = "Alright Bet!", Callback = function() end }
    }
})

-- UI Setup
local Window = Rayfield:CreateWindow({
    Name = "Dark.cc | Universal",
    LoadingTitle = "Dark.cc Universal Loading...",
    LoadingSubtitle = "by Feyk",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "FeykHubUniversal",
        FileName = "feykhub"
    },
    KeySystem = false,
})

-- Home Tab (Welcome and Discord)
local HomeTab = Window:CreateTab("Home", 4483362458)
HomeTab:CreateLabel("Join our Discord Server For More Scripts")

HomeTab:CreateButton({
    Name = "Copy Discord Link",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/yeKPEZpMMu")
            Rayfield:Notify({
                Title = "Dark.cc",
                Content = "Discord link copied!",
                Duration = 5
            })
        end
    end,
})

-- Combat Tab (Aimbot and Team Settings)
local CombatTab = Window:CreateTab("Combat", 4483362458)
CombatTab:CreateLabel("Aimbot and Targeting")

CombatTab:CreateToggle({
    Name = "Aimbot",
    CurrentValue = false,
    Callback = function(Value)
        enabled = Value
        if not Value then lockedTarget = nil end
    end,
})

CombatTab:CreateToggle({
    Name = "FOV Visual",
    CurrentValue = false,
    Callback = function(Value)
        showFOV = Value
    end,
})

CombatTab:CreateSlider({
    Name = "FOV Radius",
    Range = {1, 200},
    Increment = 1,
    Suffix = "Radius",
    CurrentValue = 75,
    Callback = function(Value)
        fovRadius = Value
        fovCircle.Radius = Value
    end,
})

CombatTab:CreateSlider({
    Name = "Smoothness",
    Range = {0.3, 1},
    Increment = 0.01,
    Suffix = "",
    CurrentValue = 0.4,
    Callback = function(Value)
        smoothness = Value
    end,
})

CombatTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = true,
    Callback = function(Value)
        teamCheckEnabled = Value
    end,
})

for _, team in ipairs(Teams:GetChildren()) do
    table.insert(allTeams, team.Name)
end
table.insert(allTeams, "All")

CombatTab:CreateDropdown({
    Name = "Target Teams",
    Options = allTeams,
    MultiSelection = true,
    CurrentOption = {"All"},
    Callback = function(Options)
        selectedTeams = {}
        for _, v in pairs(Options) do
            selectedTeams[v] = true
        end
    end,
})

CombatTab:CreateDropdown({
    Name = "Part Target",
    Options = {
        "Head",
        "UpperTorso",
        "LowerTorso",
        "RightUpperArm",
        "LeftUpperArm",
        "RightUpperLeg",
        "LeftUpperLeg"
    },
    CurrentOption = {"Head"},
    Callback = function(Option)
        targetPart = Option[1]
    end,
})

-- Visuals Tab (ESP, Tracers, Crosshair)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
VisualsTab:CreateLabel("ESP and Visual Settings")

VisualsTab:CreateToggle({
    Name = "ESP",
    CurrentValue = false,
    Callback = function(Value)
        espEnabled = Value
        if not Value then clearESP() end
    end,
})

VisualsTab:CreateToggle({
    Name = "Tracers",
    CurrentValue = false,
    Callback = function(Value)
        tracersEnabled = Value
        for _, data in pairs(espObjects) do
            if data.Tracer then
                data.Tracer.Visible = Value and data.Text.Visible
            end
        end
    end,
})

VisualsTab:CreateDropdown({
    Name = "Tracer Origin",
    Options = {"Center", "Bottom", "Top"},
    CurrentOption = {"Center"},
    Callback = function(Option)
        tracerOrigin = Option[1]
    end,
})

VisualsTab:CreateColorPicker({
    Name = "ESP Color",
    Color = Color3.new(1, 1, 1),
    Callback = function(Value)
        espColor = Value
        for _, data in pairs(espObjects) do
            if data.Highlight then
                data.Highlight.FillColor = espColor
            end
            if data.Text then
                data.Text.Color = espColor
            end
            if data.Tracer then
                data.Tracer.Color = espColor
            end
        end
    end,
})

VisualsTab:CreateToggle({
    Name = "Custom Crosshair",
    CurrentValue = false,
    Callback = function(Value)
        crosshairEnabled = Value
    end,
})

VisualsTab:CreateColorPicker({
    Name = "Crosshair Color",
    Color = Color3.new(1, 0, 0),
    Callback = function(Value)
        crosshairColor = Value
        crosshairV.Color = Value
        crosshairH.Color = Value
    end,
})

VisualsTab:CreateSlider({
    Name = "Crosshair Size",
    Range = {5, 50},
    Increment = 1,
    Suffix = "Px",
    CurrentValue = 10,
    Callback = function(Value)
        crosshairSize = Value
    end,
})

-- Movement Tab (Walkspeed, Jump, NoClip)
local MovementTab = Window:CreateTab("Movement", 4483362458)
MovementTab:CreateLabel("Movement Enhancements")

MovementTab:CreateToggle({
    Name = "Custom Walkspeed",
    CurrentValue = false,
    Callback = function(Value)
        walkSpeedEnabled = Value
        updateMovement()
    end,
})

MovementTab:CreateSlider({
    Name = "Walkspeed",
    Range = {16, 100},
    Increment = 1,
    Suffix = "Speed",
    CurrentValue = 16,
    Callback = function(Value)
        walkSpeed = Value
        if walkSpeedEnabled then
            updateMovement()
        end
    end,
})

MovementTab:CreateToggle({
    Name = "Custom Jump Power",
    CurrentValue = false,
    Callback = function(Value)
        jumpPowerEnabled = Value
        updateMovement()
    end,
})

MovementTab:CreateSlider({
    Name = "Jump Power",
    Range = {50, 200},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 50,
    Callback = function(Value)
        jumpPower = Value
        if jumpPowerEnabled then
            updateMovement()
        end
    end,
})

MovementTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = false,
    Callback = function(Value)
        infJumpEnabled = Value
    end,
})

MovementTab:CreateToggle({
    Name = "NoClip",
    CurrentValue = false,
    Callback = function(Value)
        noClipEnabled = Value
    end,
})

-- Misc Tab (Anti-AFK)
local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateLabel("Miscellaneous Features")

MiscTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            antiAFK = LocalPlayer.Idled:Connect(function()
                VirtualUser = game:GetService("VirtualUser")
                VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                wait(1)
                VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end)
        else
            if antiAFK then
                antiAFK:Disconnect()
            end
        end
    end,
})

-- Store Default Movement Values
LocalPlayer.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid")
    defaultWalkSpeed = humanoid.WalkSpeed
    defaultJumpPower = humanoid.JumpPower
    updateMovement()
end)

-- Infinite Jump Handler
UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Runtime Loop
RunService.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Visible = showFOV

    if espEnabled then
        updateESP()
    else
        for _, data in pairs(espObjects) do
            if data.Text then data.Text.Visible = false end
            if data.Tracer then data.Tracer.Visible = false end
        end
    end

    if crosshairEnabled then
        updateCrosshair()
    else
        crosshairV.Visible = false
        crosshairH.Visible = false
    end

    if enabled then
        local target = getClosestTarget()
        if target then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Position), smoothness)
        end
    end

    if noClipEnabled then
        updateNoClip()
    end
end)