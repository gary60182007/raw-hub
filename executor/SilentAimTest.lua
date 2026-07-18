--!nocheck
-- Raw Hub | Mid Eastern Conflict Sim silent-aim compatibility test
-- Separate test runtime. It does not replace the main Raw Hub script.

local Env = (getgenv and getgenv()) or _G
if Env.RawHubSilentTest and type(Env.RawHubSilentTest.Unload) == "function" then
    pcall(Env.RawHubSilentTest.Unload)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

if not game:IsLoaded() then game.Loaded:Wait() end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Camera = workspace.CurrentCamera
local Config = {
    Enabled = true,
    TeamCheck = true,
    VisibleCheck = true,
    HeadSync = false,
    FOV = 180,
    MaxDistance = 3000,
    AimPart = "Head",
    DropScale = 1,
    VelocityScale = 1,
}

local Runtime = {
    Running = true,
    Connections = {},
    Shots = {},
    Pending = {},
    Redirected = 0,
    Processed = 0,
    Confirmed = 0,
    ConfirmedDamage = 0,
    LastHit = "NONE",
    LastShotAt = 0,
    OriginalNamecall = nil,
    OriginalAddProjectile = nil,
    ClientHB = nil,
    Gui = nil,
}
Env.RawHubSilentTest = Runtime

local function track(connection)
    table.insert(Runtime.Connections, connection)
    return connection
end

local function safeRequire(module)
    if not module or not module:IsA("ModuleScript") then return nil end
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local function sameTeam(player)
    local gameSystem = ReplicatedStorage:FindFirstChild("GameSystem")
    if gameSystem and gameSystem:GetAttribute("FreeForAll") == true then return false end
    return LocalPlayer.Team ~= nil and player.Team ~= nil
        and (player.Team == LocalPlayer.Team or player.TeamColor == LocalPlayer.TeamColor)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
pcall(function() rayParams.CollisionGroup = "Raycast" end)

local function isVisible(character, point)
    local filter = {}
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    if Camera then table.insert(filter, Camera) end
    local acs = workspace:FindFirstChild("ACS_WorkSpace")
    if acs and acs:FindFirstChild("Client") then table.insert(filter, acs.Client) end
    rayParams.FilterDescendantsInstances = filter
    local origin = Camera.CFrame.Position
    local hit = workspace:Raycast(origin, point - origin, rayParams)
    return hit == nil or (hit.Instance and hit.Instance:IsDescendantOf(character))
end

local function getBallistics()
    local speed = 1450
    local gravity = tonumber(workspace:GetAttribute("BulletGravity")) or workspace.Gravity
    local weapon = "FALLBACK"
    local character = LocalPlayer.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    local engine = ReplicatedStorage:FindFirstChild("ACS_Engine")
    local configs = engine and engine:FindFirstChild("WeaponConfigs")
    local attachments = engine and engine:FindFirstChild("AttachmentConfigs")
    local config = tool and configs and safeRequire(configs:FindFirstChild(tool.Name))

    if tool and type(config) == "table" and tonumber(config.MuzzleVelocity) then
        local multiplier = 1
        for _, attributeName in ipairs({"Sight", "Barrel", "UnderBarrel", "Other", "Ammo"}) do
            local attachmentName = tool:GetAttribute(attributeName)
            local attachment = attachmentName and attachments and safeRequire(attachments:FindFirstChild(tostring(attachmentName)))
            if type(attachment) == "table" and tonumber(attachment.MuzzleVelocity) then
                multiplier = multiplier * tonumber(attachment.MuzzleVelocity)
            end
        end
        speed = tonumber(config.MuzzleVelocity) * multiplier
        gravity = gravity * (tonumber(config.GravCoeff) or 1)
        weapon = tool.Name
    end

    return speed * Config.VelocityScale, gravity * Config.DropScale, weapon
end

local function solve(origin, targetPosition, targetVelocity, projectileSpeed, gravity)
    projectileSpeed = math.max(projectileSpeed, 1)
    if targetVelocity.Magnitude > 180 then targetVelocity = targetVelocity.Unit * 180 end
    local time = (targetPosition - origin).Magnitude / projectileSpeed
    local future = targetPosition
    local aimPoint = targetPosition
    local drop = 0
    for _ = 1, 8 do
        future = targetPosition + targetVelocity * time
        drop = 0.5 * gravity * time * time
        aimPoint = future + Vector3.new(0, drop, 0)
        local nextTime = (aimPoint - origin).Magnitude / projectileSpeed
        if math.abs(nextTime - time) < 0.0005 then
            time = nextTime
            break
        end
        time = nextTime
    end
    return aimPoint, time, drop, (future - targetPosition).Magnitude
end

local function mousePosition()
    return UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
end

local CurrentTarget = nil
local function selectTarget(origin, projectileSpeed, gravity)
    Camera = workspace.CurrentCamera or Camera
    if not Camera then return nil end
    local best, bestScore
    local mouse = mousePosition()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and (not Config.TeamCheck or not sameTeam(player)) then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local part = character and (character:FindFirstChild(Config.AimPart) or character:FindFirstChild("Head") or root)
            if humanoid and root and part and humanoid.Health > 0 then
                local distance = (part.Position - origin).Magnitude
                if distance <= Config.MaxDistance then
                    local visible = isVisible(character, part.Position)
                    if not Config.VisibleCheck or visible then
                        local aimPoint, flightTime, drop, lead = solve(origin, part.Position, root.AssemblyLinearVelocity, projectileSpeed, gravity)
                        local viewport, onScreen = Camera:WorldToViewportPoint(aimPoint)
                        if onScreen and viewport.Z > 0 then
                            local screen = Vector2.new(viewport.X, viewport.Y)
                            local screenDistance = (screen - mouse).Magnitude
                            if screenDistance <= Config.FOV then
                                local score = screenDistance + distance * 0.003
                                if not bestScore or score < bestScore then
                                    bestScore = score
                                    best = {
                                        Player = player,
                                        Character = character,
                                        Root = root,
                                        Part = part,
                                        AimPoint = aimPoint,
                                        Screen = screen,
                                        Distance = distance,
                                        FlightTime = flightTime,
                                        Drop = drop,
                                        Lead = lead,
                                        Visible = visible,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local uiParent = LocalPlayer:WaitForChild("PlayerGui")
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and typeof(result) == "Instance" then uiParent = result end
else
    pcall(function() uiParent = CoreGui end)
end

local oldGui = uiParent:FindFirstChild("RawHubSilentTest")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "RawHubSilentTest"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1001
gui.Parent = uiParent
Runtime.Gui = gui

local circle = Instance.new("Frame")
circle.AnchorPoint = Vector2.new(0.5, 0.5)
circle.BackgroundColor3 = Color3.fromRGB(118, 91, 255)
circle.BackgroundTransparency = 0.97
circle.BorderSizePixel = 0
circle.Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2)
circle.ZIndex = 10
circle.Parent = gui
local circleCorner = Instance.new("UICorner")
circleCorner.CornerRadius = UDim.new(1, 0)
circleCorner.Parent = circle
local circleStroke = Instance.new("UIStroke")
circleStroke.Color = Color3.fromRGB(65, 214, 255)
circleStroke.Transparency = 0.2
circleStroke.Thickness = 1.25
circleStroke.Parent = circle

local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.BackgroundTransparency = 1
marker.BorderSizePixel = 0
marker.Size = UDim2.fromOffset(20, 20)
marker.Visible = false
marker.ZIndex = 20
marker.Parent = gui
local markerCorner = Instance.new("UICorner")
markerCorner.CornerRadius = UDim.new(1, 0)
markerCorner.Parent = marker
local markerStroke = Instance.new("UIStroke")
markerStroke.Color = Color3.fromRGB(255, 205, 85)
markerStroke.Thickness = 1.5
markerStroke.Parent = marker
local markerH = Instance.new("Frame")
markerH.AnchorPoint = Vector2.new(0.5, 0.5)
markerH.BackgroundColor3 = markerStroke.Color
markerH.BorderSizePixel = 0
markerH.Position = UDim2.fromScale(0.5, 0.5)
markerH.Size = UDim2.fromOffset(28, 1)
markerH.Parent = marker
local markerV = markerH:Clone()
markerV.Size = UDim2.fromOffset(1, 28)
markerV.Parent = marker

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.BackgroundColor3 = Color3.fromRGB(10, 13, 23)
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Position = UDim2.new(0.5, 0, 0, 18)
panel.Size = UDim2.fromOffset(470, 128)
panel.ZIndex = 30
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(73, 84, 119)
panelStroke.Transparency = 0.2
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Position = UDim2.fromOffset(14, 8)
title.Size = UDim2.new(1, -28, 0, 20)
title.Text = "RAW HUB // SILENT AIM TEST"
title.TextColor3 = Color3.fromRGB(244, 247, 255)
title.TextSize = 11
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 31
title.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.RobotoMono
statusLabel.Position = UDim2.fromOffset(14, 31)
statusLabel.Size = UDim2.new(1, -28, 0, 38)
statusLabel.Text = "INITIALIZING HOOKS..."
statusLabel.TextColor3 = Color3.fromRGB(143, 153, 180)
statusLabel.TextSize = 9
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.ZIndex = 31
statusLabel.Parent = panel

local keysLabel = Instance.new("TextLabel")
keysLabel.BackgroundTransparency = 1
keysLabel.Font = Enum.Font.GothamMedium
keysLabel.Position = UDim2.fromOffset(14, 71)
keysLabel.Size = UDim2.new(1, -28, 0, 15)
keysLabel.Text = "F3 toggle   F4 visibility   F5 head sync   [ / ] FOV   F8 unload"
keysLabel.TextColor3 = Color3.fromRGB(99, 112, 145)
keysLabel.TextSize = 8
keysLabel.TextXAlignment = Enum.TextXAlignment.Left
keysLabel.ZIndex = 31
keysLabel.Parent = panel

local quickControls = Instance.new("Frame")
quickControls.BackgroundTransparency = 1
quickControls.Position = UDim2.fromOffset(12, 92)
quickControls.Size = UDim2.new(1, -24, 0, 27)
quickControls.ZIndex = 31
quickControls.Parent = panel
local quickLayout = Instance.new("UIListLayout")
quickLayout.FillDirection = Enum.FillDirection.Horizontal
quickLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
quickLayout.Padding = UDim.new(0, 6)
quickLayout.Parent = quickControls

local function quickButton(text, width, color)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundColor3 = color or Color3.fromRGB(30, 36, 56)
    button.BackgroundTransparency = 0.08
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Size = UDim2.fromOffset(width, 27)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(235, 240, 255)
    button.TextSize = 8
    button.ZIndex = 32
    button.Parent = quickControls
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 7)
    buttonCorner.Parent = button
    return button
end

local toggleButton = quickButton("SILENT ON", 72, Color3.fromRGB(35, 112, 83))
local losButton = quickButton("LOS ON", 61, Color3.fromRGB(35, 83, 112))
local syncButton = quickButton("SYNC ON", 64, Color3.fromRGB(77, 57, 125))
local fovMinusButton = quickButton("FOV −", 55)
local fovPlusButton = quickButton("FOV +", 55)
local unloadButton = quickButton("UNLOAD", 72, Color3.fromRGB(125, 42, 61))

local Events = ReplicatedStorage:WaitForChild("ACS_Engine"):WaitForChild("Events")
local ShootRemote = Events:WaitForChild("Shoot")
local ProcessRemote = Events:WaitForChild("Process")
local HeadRotRemote = Events:WaitForChild("HeadRot")
local HitmarkerRemote = Events:WaitForChild("Hitmarker")
local clientHBModule = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("ClientHB")
local ClientHB = safeRequire(clientHBModule)
Runtime.ClientHB = ClientHB

local function sendHeadSync(target)
    if not Config.HeadSync or not target or not target.AimPoint then return end
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local direction = target.AimPoint - root.Position
    if direction.Magnitude < 0.01 then return end
    local localDirection = root.CFrame:VectorToObjectSpace(direction.Unit)
    local pitch = math.deg(math.asin(math.clamp(localDirection.Y, -1, 1)))
    local yaw = math.deg(-math.asin(math.clamp(localDirection.X / 1.15, -1, 1)))
    pcall(function()
        HeadRotRemote:FireServer(math.round(pitch), math.round(yaw))
    end)
end

track(HitmarkerRemote.OnClientEvent:Connect(function(payload)
    if not Runtime.Running or not Config.Enabled or type(payload) ~= "table" then return end
    if os.clock() - Runtime.LastShotAt > 4 then return end
    local damage = tonumber(payload.Damage) or 0
    if damage <= 0 and not payload.Kill then return end
    Runtime.Confirmed = Runtime.Confirmed + 1
    Runtime.ConfirmedDamage = Runtime.ConfirmedDamage + damage
    local model = payload.DamageModel
    local player = typeof(model) == "Instance" and Players:GetPlayerFromCharacter(model)
    Runtime.LastHit = string.format(
        "%s %.1f%s%s",
        player and player.Name or (typeof(model) == "Instance" and model.Name or "UNKNOWN"),
        damage,
        payload.Headshot and " HS" or "",
        payload.Kill and " KILL" or ""
    )
    print("[Raw Hub Silent Test] SERVER HIT", Runtime.LastHit)
end))

local hookReady = type(hookmetamethod) == "function"
    and type(getnamecallmethod) == "function"
    and type(newcclosure) == "function"
    and type(checkcaller) == "function"
if not ClientHB or type(ClientHB.AddACSProjectile) ~= "function" then
    hookReady = false
end

if hookReady then
    Runtime.OriginalAddProjectile = ClientHB.AddACSProjectile
    local addWrapper = function(self, projectile, replicated, ...)
        if Runtime.Running and Config.Enabled and type(projectile) == "table"
            and projectile.Owner == LocalPlayer and not replicated and projectile.ID
        then
            local shot = Runtime.Shots[projectile.ID]
            if shot and os.clock() <= shot.Expires then
                local magnitude = projectile.Velocity and projectile.Velocity.Magnitude or shot.Speed
                projectile.Velocity = shot.Direction * magnitude
                Runtime.Shots[projectile.ID] = nil
            end
        end
        return Runtime.OriginalAddProjectile(self, projectile, replicated, ...)
    end

    local addAssigned = pcall(function()
        ClientHB.AddACSProjectile = addWrapper
    end)
    if not addAssigned then
        hookReady = false
    end

    if hookReady then
        local originalNamecall
        local okHook, hookResult = pcall(function()
            originalNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = table.pack(...)
                if Runtime.Running and Config.Enabled and not checkcaller() and method == "FireServer" then
                    if self == ShootRemote then
                        local payload = args[1]
                        if type(payload) == "table" and typeof(payload.BP) == "Vector3"
                            and typeof(payload.D) == "Vector3" and not payload.Swing
                        then
                            local speed, gravity = getBallistics()
                            speed = speed * (tonumber(payload.SP) or 1)
                            local target = selectTarget(payload.BP, speed, gravity)
                            if target then
                                local direction = target.AimPoint - payload.BP
                                if direction.Magnitude > 0.01 then
                                    direction = direction.Unit
                                    local modified = table.clone(payload)
                                    modified.D = direction
                                    args[1] = modified
                                    if payload.ID then
                                        Runtime.Shots[payload.ID] = {
                                            Direction = direction,
                                            Speed = speed,
                                            Expires = os.clock() + 1.5,
                                        }
                                        Runtime.Pending[payload.ID] = {
                                            Expires = os.clock() + 3,
                                        }
                                    end
                                    Runtime.Redirected = Runtime.Redirected + 1
                                    Runtime.LastShotAt = os.clock()
                                    CurrentTarget = target
                                end
                            end
                        end
                    elseif self == ProcessRemote then
                        local shotId = args[3]
                        local pending = shotId and Runtime.Pending[shotId]
                        if pending then
                            Runtime.Processed = Runtime.Processed + 1
                            Runtime.Pending[shotId] = nil
                        end
                    end
                end
                return originalNamecall(self, table.unpack(args, 1, args.n))
            end))
            return originalNamecall
        end)
        if okHook and hookResult then
            Runtime.OriginalNamecall = hookResult
        else
            hookReady = false
            pcall(function() ClientHB.AddACSProjectile = Runtime.OriginalAddProjectile end)
        end
    end
end

function Runtime.Unload()
    if not Runtime.Running then return end
    Runtime.Running = false
    for _, connection in ipairs(Runtime.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    if Runtime.ClientHB and Runtime.OriginalAddProjectile then
        pcall(function() Runtime.ClientHB.AddACSProjectile = Runtime.OriginalAddProjectile end)
    end
    if Runtime.OriginalNamecall and type(hookmetamethod) == "function" then
        pcall(function() hookmetamethod(game, "__namecall", Runtime.OriginalNamecall) end)
    end
    pcall(function() gui:Destroy() end)
    if Env.RawHubSilentTest == Runtime then Env.RawHubSilentTest = nil end
end

local function refreshQuickControls()
    toggleButton.Text = Config.Enabled and "SILENT ON" or "SILENT OFF"
    toggleButton.BackgroundColor3 = Config.Enabled and Color3.fromRGB(35, 112, 83) or Color3.fromRGB(92, 48, 58)
    losButton.Text = Config.VisibleCheck and "LOS ON" or "LOS OFF"
    losButton.BackgroundColor3 = Config.VisibleCheck and Color3.fromRGB(35, 83, 112) or Color3.fromRGB(78, 62, 42)
    syncButton.Text = Config.HeadSync and "SYNC ON" or "SYNC OFF"
    syncButton.BackgroundColor3 = Config.HeadSync and Color3.fromRGB(77, 57, 125) or Color3.fromRGB(72, 54, 54)
end

local function changeFOV(amount)
    Config.FOV = math.clamp(Config.FOV + amount, 40, 500)
    circle.Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2)
end

track(toggleButton.Activated:Connect(function()
    Config.Enabled = not Config.Enabled
    refreshQuickControls()
end))
track(losButton.Activated:Connect(function()
    Config.VisibleCheck = not Config.VisibleCheck
    refreshQuickControls()
end))
track(syncButton.Activated:Connect(function()
    Config.HeadSync = not Config.HeadSync
    refreshQuickControls()
end))
track(fovMinusButton.Activated:Connect(function() changeFOV(-20) end))
track(fovPlusButton.Activated:Connect(function() changeFOV(20) end))
track(unloadButton.Activated:Connect(function() Runtime.Unload() end))
refreshQuickControls()

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F3 then
        Config.Enabled = not Config.Enabled
        refreshQuickControls()
    elseif input.KeyCode == Enum.KeyCode.F4 then
        Config.VisibleCheck = not Config.VisibleCheck
        refreshQuickControls()
    elseif input.KeyCode == Enum.KeyCode.F5 then
        Config.HeadSync = not Config.HeadSync
        refreshQuickControls()
    elseif input.KeyCode == Enum.KeyCode.RightBracket then
        changeFOV(20)
    elseif input.KeyCode == Enum.KeyCode.LeftBracket then
        changeFOV(-20)
    elseif input.KeyCode == Enum.KeyCode.F8 then
        Runtime.Unload()
    end
end))

local lastHeadSync = 0
track(RunService.RenderStepped:Connect(function()
    if not Runtime.Running then return end
    Camera = workspace.CurrentCamera or Camera
    if not Camera then return end
    local mouse = mousePosition()
    circle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
    circle.Visible = Config.Enabled

    local speed, gravity, weapon = getBallistics()
    CurrentTarget = selectTarget(Camera.CFrame.Position, speed, gravity)
    if CurrentTarget and Config.Enabled and Config.HeadSync and os.clock() - lastHeadSync >= 0.1 then
        lastHeadSync = os.clock()
        sendHeadSync(CurrentTarget)
    end
    if CurrentTarget then
        marker.Position = UDim2.fromOffset(CurrentTarget.Screen.X, CurrentTarget.Screen.Y)
        marker.Visible = Config.Enabled
        markerStroke.Color = CurrentTarget.Visible and Color3.fromRGB(73, 235, 165) or Color3.fromRGB(255, 91, 124)
        markerH.BackgroundColor3 = markerStroke.Color
        markerV.BackgroundColor3 = markerStroke.Color
    else
        marker.Visible = false
    end

    if not hookReady then
        statusLabel.Text = "HOOK STATUS  INCOMPATIBLE EXECUTOR\nRequires hookmetamethod + ClientHB access"
        statusLabel.TextColor3 = Color3.fromRGB(255, 91, 124)
    else
        local targetText = CurrentTarget and (CurrentTarget.Player.Name .. string.format("  %dst", CurrentTarget.Distance)) or "NONE"
        statusLabel.Text = string.format(
            "STATUS %s   TARGET %s   S/P/H %d/%d/%d\n%s  %.0f studs/s  SYNC %s  LOS %s  FOV %d",
            Config.Enabled and "ON" or "OFF",
            targetText,
            Runtime.Redirected,
            Runtime.Processed,
            Runtime.Confirmed,
            string.upper(weapon),
            speed,
            Config.HeadSync and "ON" or "OFF",
            Config.VisibleCheck and "ON" or "OFF",
            Config.FOV
        )
        statusLabel.TextColor3 = Config.Enabled and Color3.fromRGB(73, 235, 165) or Color3.fromRGB(255, 205, 85)
    end

    local now = os.clock()
    for id, shot in pairs(Runtime.Shots) do
        if now > shot.Expires then Runtime.Shots[id] = nil end
    end
    for id, pending in pairs(Runtime.Pending) do
        if now > pending.Expires then Runtime.Pending[id] = nil end
    end
end))

print("[Raw Hub Silent Test] Guarded rollback loaded | PULSE/SPOOF removed | S/P/H uses server Hitmarker")
