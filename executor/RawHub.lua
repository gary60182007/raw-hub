--!nocheck
-- Raw Hub v2.0 | Mid Eastern Conflict Sim
-- Custom executor runtime: detailed ESP, smooth aim and automatic ACS ballistic compensation.

local Env = (getgenv and getgenv()) or _G
local PreviousRuntime = Env.RawHubV2 or Env.RawHubExternal
if PreviousRuntime and type(PreviousRuntime.Unload) == "function" then
    pcall(PreviousRuntime.Unload)
end
Env.RawHubExternal = nil

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Camera = workspace.CurrentCamera

local Runtime = {
    Connections = {},
    Visuals = {},
    Cache = {},
    Running = true,
    Gui = nil,
}
Env.RawHubV2 = Runtime

local Theme = {
    Background = Color3.fromRGB(7, 9, 16),
    Sidebar = Color3.fromRGB(10, 13, 23),
    Surface = Color3.fromRGB(15, 19, 31),
    Surface2 = Color3.fromRGB(20, 25, 40),
    Surface3 = Color3.fromRGB(27, 33, 51),
    Border = Color3.fromRGB(58, 68, 96),
    Text = Color3.fromRGB(244, 247, 255),
    Muted = Color3.fromRGB(143, 153, 180),
    Accent = Color3.fromRGB(127, 100, 255),
    Accent2 = Color3.fromRGB(63, 205, 255),
    Green = Color3.fromRGB(66, 229, 157),
    Yellow = Color3.fromRGB(255, 200, 82),
    Red = Color3.fromRGB(255, 82, 115),
    Hidden = Color3.fromRGB(255, 113, 132),
}

local Config = {
    Aim = {
        Enabled = true,
        Prediction = true,
        AutoBallistics = true,
        TeamCheck = true,
        VisibleCheck = true,
        StickyTarget = true,
        FOV = 210,
        Smoothness = 12,
        MaxTurnRate = 540,
        MaxDistance = 3000,
        AimPart = "Auto",
        Method = "Camera",
        ManualVelocity = 1450,
        ManualGravity = 196.2,
        VelocityScale = 1,
        DropScale = 1,
    },
    ESP = {
        Enabled = true,
        TeamCheck = true,
        Boxes = true,
        Names = true,
        Health = true,
        Distance = true,
        Weapon = true,
        Tracers = true,
        Skeleton = true,
        Highlights = true,
        Prediction = true,
        Offscreen = true,
        MaxDistance = 3500,
    },
    Interface = {
        FOVCircle = true,
        TargetCard = true,
        MenuVisible = true,
    },
}

local function track(connection)
    table.insert(Runtime.Connections, connection)
    return connection
end

local function connect(signal, callback)
    return track(signal:Connect(callback))
end

local function create(className, properties)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        local ok = pcall(function()
            object[property] = value
        end)
        if not ok then
            warn("[Raw Hub] Property failed: " .. tostring(className) .. "." .. tostring(property))
        end
    end
    return object
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent,
    })
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = color or Theme.Border,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        Parent = parent,
    })
end

local function gradient(parent, colorA, colorB, rotation)
    return create("UIGradient", {
        Color = ColorSequence.new(colorA, colorB),
        Rotation = rotation or 0,
        Parent = parent,
    })
end

local function safeDestroy(object)
    if object then
        pcall(function()
            object:Destroy()
        end)
    end
end

local function safeRequire(module)
    if not module or not module:IsA("ModuleScript") then
        return nil
    end
    local ok, result = pcall(require, module)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local function safeRequireAny(module)
    if not module or not module:IsA("ModuleScript") then
        return nil
    end
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local uiParent = LocalPlayer:WaitForChild("PlayerGui")
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and typeof(result) == "Instance" then
        uiParent = result
    end
else
    local ok = pcall(function()
        return CoreGui.Name
    end)
    if ok then
        uiParent = CoreGui
    end
end

for _, parent in ipairs({uiParent, LocalPlayer.PlayerGui}) do
    local previous = parent and parent:FindFirstChild("RawHubV2")
    if previous then
        previous:Destroy()
    end
end

local ScreenGui = create("ScreenGui", {
    Name = "RawHubV2",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
    Parent = uiParent,
})
Runtime.Gui = ScreenGui

if syn and type(syn.protect_gui) == "function" then
    pcall(syn.protect_gui, ScreenGui)
end

local Overlay = create("Frame", {
    Name = "Overlay",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 5,
    Parent = ScreenGui,
})

local Interface = create("Frame", {
    Name = "Interface",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 100,
    Parent = ScreenGui,
})

local FOVCircle = create("Frame", {
    Name = "FOVCircle",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Accent,
    BackgroundTransparency = 0.965,
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(Config.Aim.FOV * 2, Config.Aim.FOV * 2),
    ZIndex = 80,
    Parent = Overlay,
})
corner(FOVCircle, 999)
local FOVStroke = stroke(FOVCircle, Theme.Accent2, 0.2, 1.35)
local FOVGradient = gradient(FOVStroke, Theme.Accent, Theme.Accent2, 45)

local FOVDot = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Text,
    BorderSizePixel = 0,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(4, 4),
    ZIndex = 81,
    Parent = FOVCircle,
})
corner(FOVDot, 999)

local TargetCard = create("Frame", {
    Name = "TargetCard",
    AnchorPoint = Vector2.new(0.5, 1),
    BackgroundColor3 = Theme.Surface,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, 0, 1, -36),
    Size = UDim2.fromOffset(430, 72),
    Visible = false,
    ZIndex = 110,
    Parent = Interface,
})
corner(TargetCard, 14)
stroke(TargetCard, Theme.Border, 0.22, 1)
gradient(TargetCard, Color3.fromRGB(24, 27, 48), Theme.Surface, 115)

local TargetAccent = create("Frame", {
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 4, 1, 0),
    ZIndex = 111,
    Parent = TargetCard,
})
corner(TargetAccent, 14)
gradient(TargetAccent, Theme.Accent, Theme.Accent2, 90)

local TargetName = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Position = UDim2.fromOffset(18, 10),
    Size = UDim2.new(0.48, -18, 0, 22),
    Text = "NO TARGET",
    TextColor3 = Theme.Text,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 112,
    Parent = TargetCard,
})

local TargetStats = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.RobotoMono,
    Position = UDim2.fromOffset(18, 34),
    Size = UDim2.new(0.54, -18, 0, 26),
    Text = "RANGE --  |  TOF --  |  DROP --",
    TextColor3 = Theme.Muted,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 112,
    Parent = TargetCard,
})

local TargetWeapon = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Position = UDim2.new(1, -14, 0, 11),
    Size = UDim2.fromOffset(178, 20),
    Text = "BALLISTICS: --",
    TextColor3 = Theme.Accent2,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 112,
    Parent = TargetCard,
})

local TargetLead = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.RobotoMono,
    Position = UDim2.new(1, -14, 0, 36),
    Size = UDim2.fromOffset(178, 20),
    Text = "LEAD --  |  LOS --",
    TextColor3 = Theme.Muted,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 112,
    Parent = TargetCard,
})

local Main = create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = Theme.Background,
    BackgroundTransparency = 0.035,
    BorderSizePixel = 0,
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(650, 548),
    ZIndex = 200,
    Parent = Interface,
})
corner(Main, 20)
stroke(Main, Theme.Border, 0.2, 1)
gradient(Main, Color3.fromRGB(16, 18, 33), Theme.Background, 130)

local Shadow = create("ImageLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Image = "rbxassetid://6014261993",
    ImageColor3 = Color3.new(0, 0, 0),
    ImageTransparency = 0.36,
    Position = UDim2.fromScale(0.5, 0.5),
    ScaleType = Enum.ScaleType.Slice,
    Size = UDim2.new(1, 52, 1, 52),
    SliceCenter = Rect.new(49, 49, 450, 450),
    ZIndex = 199,
    Parent = Main,
})

local Sidebar = create("Frame", {
    BackgroundColor3 = Theme.Sidebar,
    BackgroundTransparency = 0.16,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 166, 1, 0),
    ZIndex = 201,
    Parent = Main,
})
corner(Sidebar, 20)

local SidebarCover = create("Frame", {
    BackgroundColor3 = Theme.Sidebar,
    BackgroundTransparency = 0.16,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -20, 0, 0),
    Size = UDim2.new(0, 20, 1, 0),
    ZIndex = 201,
    Parent = Sidebar,
})

local Brand = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBlack,
    Position = UDim2.fromOffset(18, 17),
    Size = UDim2.fromOffset(128, 27),
    Text = "RAW HUB",
    TextColor3 = Theme.Text,
    TextSize = 21,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 203,
    Parent = Sidebar,
})

local BrandSub = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Position = UDim2.fromOffset(19, 45),
    Size = UDim2.fromOffset(128, 18),
    Text = "COMBAT SYSTEM v2.0",
    TextColor3 = Theme.Accent2,
    TextSize = 8,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 203,
    Parent = Sidebar,
})

local BrandLine = create("Frame", {
    BackgroundColor3 = Theme.Accent,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(18, 72),
    Size = UDim2.fromOffset(128, 2),
    ZIndex = 203,
    Parent = Sidebar,
})
corner(BrandLine, 2)
gradient(BrandLine, Theme.Accent, Theme.Accent2, 0)

local TabsHolder = create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 94),
    Size = UDim2.new(1, -24, 0, 230),
    ZIndex = 203,
    Parent = Sidebar,
})
create("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = TabsHolder,
})

local SidebarStatus = create("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    BackgroundColor3 = Theme.Surface,
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 12, 1, -14),
    Size = UDim2.new(1, -24, 0, 86),
    ZIndex = 203,
    Parent = Sidebar,
})
corner(SidebarStatus, 12)
stroke(SidebarStatus, Theme.Border, 0.55, 1)

local StatusDot = create("Frame", {
    BackgroundColor3 = Theme.Green,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(12, 13),
    Size = UDim2.fromOffset(8, 8),
    ZIndex = 204,
    Parent = SidebarStatus,
})
corner(StatusDot, 99)

local StatusTitle = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Position = UDim2.fromOffset(27, 7),
    Size = UDim2.new(1, -35, 0, 20),
    Text = "SYSTEM ONLINE",
    TextColor3 = Theme.Green,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 204,
    Parent = SidebarStatus,
})

local StatusText = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Position = UDim2.fromOffset(12, 31),
    Size = UDim2.new(1, -24, 0, 42),
    Text = "Read-only ESP\nCamera aim mode",
    TextColor3 = Theme.Muted,
    TextSize = 9,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 204,
    Parent = SidebarStatus,
})

local Header = create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(166, 0),
    Size = UDim2.new(1, -166, 0, 78),
    ZIndex = 202,
    Parent = Main,
})

local HeaderTitle = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Position = UDim2.fromOffset(22, 16),
    Size = UDim2.new(1, -180, 0, 26),
    Text = "AIM ASSIST",
    TextColor3 = Theme.Text,
    TextSize = 17,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 203,
    Parent = Header,
})

local HeaderSub = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Position = UDim2.fromOffset(22, 43),
    Size = UDim2.new(1, -180, 0, 18),
    Text = "MID EASTERN CONFLICT SIM",
    TextColor3 = Theme.Muted,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 203,
    Parent = Header,
})

local LiveBadge = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundColor3 = Color3.fromRGB(22, 73, 58),
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Position = UDim2.new(1, -20, 0.5, 0),
    Size = UDim2.fromOffset(106, 28),
    Text = "●  LIVE ROUTE",
    TextColor3 = Theme.Green,
    TextSize = 9,
    ZIndex = 203,
    Parent = Header,
})
corner(LiveBadge, 99)
stroke(LiveBadge, Theme.Green, 0.7, 1)

local Divider = create("Frame", {
    BackgroundColor3 = Theme.Border,
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 184, 0, 77),
    Size = UDim2.new(1, -204, 0, 1),
    ZIndex = 202,
    Parent = Main,
})

local Pages = create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(184, 88),
    Size = UDim2.new(1, -204, 1, -108),
    ClipsDescendants = true,
    ZIndex = 202,
    Parent = Main,
})

local pageObjects = {}
local tabButtons = {}
local activeTab = "Aim"

local function makePage(name)
    local page = create("ScrollingFrame", {
        Name = name,
        Active = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ScrollBarImageColor3 = Theme.Accent,
        ScrollBarThickness = 3,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 203,
        Parent = Pages,
    })
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 12),
        Parent = page,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })
    pageObjects[name] = page
    return page
end

local AimPage = makePage("Aim")
local ESPPage = makePage("Visuals")
local BallisticsPage = makePage("Ballistics")
local SettingsPage = makePage("Settings")

local tabMeta = {
    {"Aim", "◎", "AIMBOT"},
    {"Visuals", "◇", "VISUALS"},
    {"Ballistics", "⌁", "BALLISTICS"},
    {"Settings", "⚙", "SETTINGS"},
}

local function switchTab(name)
    activeTab = name
    for pageName, page in pairs(pageObjects) do
        page.Visible = pageName == name
    end
    for buttonName, data in pairs(tabButtons) do
        local active = buttonName == name
        data.Button.BackgroundTransparency = active and 0.08 or 1
        data.Button.BackgroundColor3 = active and Theme.Surface3 or Theme.Sidebar
        data.Label.TextColor3 = active and Theme.Text or Theme.Muted
        data.Icon.TextColor3 = active and Theme.Accent2 or Theme.Muted
        data.Bar.Visible = active
    end
    HeaderTitle.Text = name == "Aim" and "AIM ASSIST" or string.upper(name)
end

for order, item in ipairs(tabMeta) do
    local name, iconText, labelText = item[1], item[2], item[3]
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Theme.Surface3,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 43),
        Text = "",
        ZIndex = 204,
        Parent = TabsHolder,
    })
    corner(button, 10)
    local bar = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.Accent2,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(3, 22),
        Visible = false,
        ZIndex = 205,
        Parent = button,
    })
    corner(bar, 3)
    local icon = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.fromOffset(26, 43),
        Text = iconText,
        TextColor3 = Theme.Muted,
        TextSize = 17,
        ZIndex = 205,
        Parent = button,
    })
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Position = UDim2.fromOffset(43, 0),
        Size = UDim2.new(1, -48, 1, 0),
        Text = labelText,
        TextColor3 = Theme.Muted,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 205,
        Parent = button,
    })
    tabButtons[name] = {Button = button, Bar = bar, Icon = icon, Label = label}
    connect(button.Activated, function()
        switchTab(name)
    end)
end

local function makeSection(parent, title, description)
    local section = create("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.13,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 0),
        ZIndex = 204,
        Parent = parent,
    })
    corner(section, 14)
    stroke(section, Theme.Border, 0.5, 1)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 13),
        PaddingBottom = UDim.new(0, 13),
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
        Parent = section,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 9),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = section,
    })
    local heading = create("Frame", {
        BackgroundTransparency = 1,
        LayoutOrder = 0,
        Size = UDim2.new(1, 0, 0, description and 39 or 22),
        ZIndex = 205,
        Parent = section,
    })
    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Size = UDim2.new(1, 0, 0, 20),
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 206,
        Parent = heading,
    })
    if description then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Position = UDim2.fromOffset(0, 20),
            Size = UDim2.new(1, 0, 0, 17),
            Text = description,
            TextColor3 = Theme.Muted,
            TextSize = 8,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 206,
            Parent = heading,
        })
    end
    return section
end

local function makeToggle(parent, title, description, initial, callback)
    local row = create("Frame", {
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, description and 50 or 42),
        ZIndex = 205,
        Parent = parent,
    })
    corner(row, 10)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Position = UDim2.fromOffset(11, description and 7 or 0),
        Size = UDim2.new(1, -78, 0, 25),
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 206,
        Parent = row,
    })
    if description then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Position = UDim2.fromOffset(11, 28),
            Size = UDim2.new(1, -78, 0, 15),
            Text = description,
            TextColor3 = Theme.Muted,
            TextSize = 8,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 206,
            Parent = row,
        })
    end
    local toggle = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        AutoButtonColor = false,
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(48, 24),
        Text = "",
        ZIndex = 206,
        Parent = row,
    })
    corner(toggle, 99)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 4, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        ZIndex = 207,
        Parent = toggle,
    })
    corner(knob, 99)
    local state = initial == true
    local function render(animated)
        local targetColor = state and Theme.Accent or Theme.Border
        local targetPosition = state and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)
        if animated then
            TweenService:Create(toggle, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {Position = targetPosition}):Play()
        else
            toggle.BackgroundColor3 = targetColor
            knob.Position = targetPosition
        end
    end
    local function set(value, silent)
        state = value == true
        render(not silent)
        if callback then
            callback(state)
        end
    end
    connect(toggle.Activated, function()
        set(not state)
    end)
    render(false)
    return set
end

local function makeSlider(parent, title, minimum, maximum, step, initial, suffix, callback)
    local row = create("Frame", {
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 65),
        ZIndex = 205,
        Parent = parent,
    })
    corner(row, 10)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Position = UDim2.fromOffset(11, 5),
        Size = UDim2.new(1, -100, 0, 24),
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 206,
        Parent = row,
    })
    local valueLabel = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.RobotoMono,
        Position = UDim2.new(1, -11, 0, 5),
        Size = UDim2.fromOffset(90, 24),
        Text = "",
        TextColor3 = Theme.Accent2,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 206,
        Parent = row,
    })
    local bar = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = Theme.Border,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 11, 0, 40),
        Size = UDim2.new(1, -22, 0, 7),
        Text = "",
        ZIndex = 206,
        Parent = row,
    })
    corner(bar, 99)
    local fill = create("Frame", {
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = 207,
        Parent = bar,
    })
    corner(fill, 99)
    gradient(fill, Theme.Accent, Theme.Accent2, 0)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Text,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(13, 13),
        ZIndex = 208,
        Parent = bar,
    })
    corner(knob, 99)
    stroke(knob, Theme.Accent2, 0.25, 1)
    local value = initial
    local dragging = false
    local function formatValue(number)
        if step < 1 then
            return string.format("%.2f%s", number, suffix or "")
        end
        return string.format("%d%s", math.floor(number + 0.5), suffix or "")
    end
    local function set(newValue, silent)
        newValue = math.clamp(newValue, minimum, maximum)
        newValue = math.floor((newValue - minimum) / step + 0.5) * step + minimum
        value = math.clamp(newValue, minimum, maximum)
        local alpha = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = formatValue(value)
        if callback and not silent then
            callback(value)
        end
    end
    local function updateFromX(x)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        set(minimum + (maximum - minimum) * alpha)
    end
    connect(bar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    set(initial, true)
    return set
end

local function makeCycle(parent, title, values, initial, callback)
    local row = create("Frame", {
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 46),
        ZIndex = 205,
        Parent = parent,
    })
    corner(row, 10)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Position = UDim2.fromOffset(11, 0),
        Size = UDim2.new(0.55, 0, 1, 0),
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 206,
        Parent = row,
    })
    local button = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        AutoButtonColor = false,
        BackgroundColor3 = Theme.Surface3,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Position = UDim2.new(1, -9, 0.5, 0),
        Size = UDim2.fromOffset(125, 29),
        Text = initial,
        TextColor3 = Theme.Accent2,
        TextSize = 9,
        ZIndex = 206,
        Parent = row,
    })
    corner(button, 8)
    stroke(button, Theme.Border, 0.55, 1)
    local index = table.find(values, initial) or 1
    connect(button.Activated, function()
        index = index % #values + 1
        button.Text = values[index]
        if callback then
            callback(values[index])
        end
    end)
    return function(value)
        index = table.find(values, value) or 1
        button.Text = values[index]
        if callback then
            callback(values[index])
        end
    end
end

local setAimEnabled
local setESPEnabled

local aimCore = makeSection(AimPage, "TARGETING CORE", "Smooth camera guidance with sticky target selection")
setAimEnabled = makeToggle(aimCore, "Aim assist", "Hold right mouse button to engage", Config.Aim.Enabled, function(value)
    Config.Aim.Enabled = value
end)
makeToggle(aimCore, "Sticky target", "Keep the current target while it remains valid", Config.Aim.StickyTarget, function(value)
    Config.Aim.StickyTarget = value
end)
makeToggle(aimCore, "Visibility check", "Only lock targets with a clear ballistic path", Config.Aim.VisibleCheck, function(value)
    Config.Aim.VisibleCheck = value
end)
makeToggle(aimCore, "Team check", "Ignore players on your current team", Config.Aim.TeamCheck, function(value)
    Config.Aim.TeamCheck = value
end)
makeCycle(aimCore, "Aim part", {"Auto", "Head", "UpperTorso", "HumanoidRootPart"}, Config.Aim.AimPart, function(value)
    Config.Aim.AimPart = value
end)
makeCycle(aimCore, "Aim method", {"Camera", "Mouse"}, Config.Aim.Method, function(value)
    Config.Aim.Method = value
end)

local aimTuning = makeSection(AimPage, "AIM TUNING", "Adjust target acquisition and camera response")
makeSlider(aimTuning, "FOV radius", 40, 500, 5, Config.Aim.FOV, " px", function(value)
    Config.Aim.FOV = value
    FOVCircle.Size = UDim2.fromOffset(value * 2, value * 2)
end)
makeSlider(aimTuning, "Smoothness", 2, 30, 1, Config.Aim.Smoothness, "", function(value)
    Config.Aim.Smoothness = value
end)
makeSlider(aimTuning, "Maximum turn rate", 45, 900, 15, Config.Aim.MaxTurnRate, "°/s", function(value)
    Config.Aim.MaxTurnRate = value
end)
makeSlider(aimTuning, "Maximum distance", 250, 5000, 50, Config.Aim.MaxDistance, " st", function(value)
    Config.Aim.MaxDistance = value
end)

local espCore = makeSection(ESPPage, "PLAYER ESP", "Detailed live information for player characters")
setESPEnabled = makeToggle(espCore, "Master ESP", "Enable all configured visual elements", Config.ESP.Enabled, function(value)
    Config.ESP.Enabled = value
end)
makeToggle(espCore, "Corner boxes", nil, Config.ESP.Boxes, function(value) Config.ESP.Boxes = value end)
makeToggle(espCore, "Names and team", nil, Config.ESP.Names, function(value) Config.ESP.Names = value end)
makeToggle(espCore, "Health bars", nil, Config.ESP.Health, function(value) Config.ESP.Health = value end)
makeToggle(espCore, "Distance", nil, Config.ESP.Distance, function(value) Config.ESP.Distance = value end)
makeToggle(espCore, "Equipped weapon", nil, Config.ESP.Weapon, function(value) Config.ESP.Weapon = value end)

local espAdvanced = makeSection(ESPPage, "ADVANCED VISUALS", "Extra positional and ballistic information")
makeToggle(espAdvanced, "Skeleton", nil, Config.ESP.Skeleton, function(value) Config.ESP.Skeleton = value end)
makeToggle(espAdvanced, "Tracers", nil, Config.ESP.Tracers, function(value) Config.ESP.Tracers = value end)
makeToggle(espAdvanced, "Character highlights", nil, Config.ESP.Highlights, function(value) Config.ESP.Highlights = value end)
makeToggle(espAdvanced, "Prediction marker", nil, Config.ESP.Prediction, function(value) Config.ESP.Prediction = value end)
makeToggle(espAdvanced, "Off-screen arrows", nil, Config.ESP.Offscreen, function(value) Config.ESP.Offscreen = value end)
makeToggle(espAdvanced, "ESP team check", nil, Config.ESP.TeamCheck, function(value) Config.ESP.TeamCheck = value end)
makeSlider(espAdvanced, "ESP maximum distance", 250, 6000, 50, Config.ESP.MaxDistance, " st", function(value)
    Config.ESP.MaxDistance = value
end)

local BallisticCard = makeSection(BallisticsPage, "LIVE BALLISTICS", "Values are read from the equipped ACS weapon and attachments")
local BallisticName = create("TextLabel", {
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Size = UDim2.new(1, 0, 0, 42),
    Text = "  WEAPON  --",
    TextColor3 = Theme.Text,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 206,
    Parent = BallisticCard,
})
corner(BallisticName, 10)
local BallisticValues = create("TextLabel", {
    BackgroundColor3 = Theme.Surface2,
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Font = Enum.Font.RobotoMono,
    Size = UDim2.new(1, 0, 0, 64),
    Text = "  VELOCITY  -- studs/s\n  GRAVITY   -- studs/s²\n  SOURCE    --",
    TextColor3 = Theme.Accent2,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 206,
    Parent = BallisticCard,
})
corner(BallisticValues, 10)

local ballisticControl = makeSection(BallisticsPage, "PREDICTION ENGINE", "Iterative target lead and distance-based bullet drop")
makeToggle(ballisticControl, "Enable prediction", "Compensate for target velocity and bullet travel time", Config.Aim.Prediction, function(value)
    Config.Aim.Prediction = value
end)
makeToggle(ballisticControl, "Automatic weapon values", "Read MuzzleVelocity, GravCoeff and attachment multipliers", Config.Aim.AutoBallistics, function(value)
    Config.Aim.AutoBallistics = value
end)
makeSlider(ballisticControl, "Manual projectile velocity", 100, 3000, 25, Config.Aim.ManualVelocity, "", function(value)
    Config.Aim.ManualVelocity = value
end)
makeSlider(ballisticControl, "Manual gravity", 0, 400, 5, Config.Aim.ManualGravity, "", function(value)
    Config.Aim.ManualGravity = value
end)
makeSlider(ballisticControl, "Velocity calibration", 0.7, 1.3, 0.01, Config.Aim.VelocityScale, "×", function(value)
    Config.Aim.VelocityScale = value
end)
makeSlider(ballisticControl, "Drop calibration", 0, 2, 0.05, Config.Aim.DropScale, "×", function(value)
    Config.Aim.DropScale = value
end)

local interfaceSection = makeSection(SettingsPage, "INTERFACE", "Raw Hub display and hotkey settings")
makeToggle(interfaceSection, "FOV circle", nil, Config.Interface.FOVCircle, function(value)
    Config.Interface.FOVCircle = value
end)
makeToggle(interfaceSection, "Target telemetry card", nil, Config.Interface.TargetCard, function(value)
    Config.Interface.TargetCard = value
end)

local hotkeySection = makeSection(SettingsPage, "HOTKEYS", "Keyboard and mouse controls")
for _, item in ipairs({
    {"RIGHT MOUSE", "Hold aim assist"},
    {"F1", "Toggle ESP"},
    {"F2", "Toggle aim assist"},
    {"RIGHT SHIFT", "Show or hide menu"},
    {"END", "Unload Raw Hub"},
}) do
    local row = create("Frame", {
        BackgroundColor3 = Theme.Surface2,
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 39),
        ZIndex = 205,
        Parent = hotkeySection,
    })
    corner(row, 9)
    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.RobotoMono,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.fromOffset(110, 39),
        Text = item[1],
        TextColor3 = Theme.Accent2,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 206,
        Parent = row,
    })
    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Position = UDim2.fromOffset(120, 0),
        Size = UDim2.new(1, -130, 1, 0),
        Text = item[2],
        TextColor3 = Theme.Muted,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 206,
        Parent = row,
    })
end

local unloadSection = makeSection(SettingsPage, "SESSION", "Cleanly remove every connection, visual and interface element")
local UnloadButton = create("TextButton", {
    AutoButtonColor = false,
    BackgroundColor3 = Theme.Red,
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Size = UDim2.new(1, 0, 0, 42),
    Text = "UNLOAD RAW HUB",
    TextColor3 = Theme.Text,
    TextSize = 10,
    ZIndex = 206,
    Parent = unloadSection,
})
corner(UnloadButton, 10)
stroke(UnloadButton, Theme.Red, 0.45, 1)

local ToastHolder = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundTransparency = 1,
    Position = UDim2.new(0.5, 0, 0, 20),
    Size = UDim2.fromOffset(360, 180),
    ZIndex = 500,
    Parent = Interface,
})
create("UIListLayout", {
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = ToastHolder,
})

local function notify(title, message, color)
    local toast = create("Frame", {
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(340, 0),
        ClipsDescendants = true,
        ZIndex = 501,
        Parent = ToastHolder,
    })
    corner(toast, 12)
    stroke(toast, color or Theme.Accent, 0.3, 1)
    local accent = create("Frame", {
        BackgroundColor3 = color or Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 4, 1, 0),
        ZIndex = 502,
        Parent = toast,
    })
    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Position = UDim2.fromOffset(16, 8),
        Size = UDim2.new(1, -28, 0, 18),
        Text = title,
        TextColor3 = Theme.Text,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 502,
        Parent = toast,
    })
    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Position = UDim2.fromOffset(16, 27),
        Size = UDim2.new(1, -28, 0, 20),
        Text = message,
        TextColor3 = Theme.Muted,
        TextSize = 8,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 502,
        Parent = toast,
    })
    TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.fromOffset(340, 56)}):Play()
    task.delay(3.25, function()
        if toast.Parent then
            local tween = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = UDim2.fromOffset(340, 0), BackgroundTransparency = 1})
            tween:Play()
            tween.Completed:Wait()
            safeDestroy(toast)
        end
    end)
end

local draggingWindow = false
local dragStart
local startPosition
connect(Header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingWindow = true
        dragStart = input.Position
        startPosition = Main.Position
    end
end)
connect(UserInputService.InputChanged, function(input)
    if draggingWindow and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingWindow = false
    end
end)

switchTab("Aim")
Main.Visible = Config.Interface.MenuVisible

local Ballistics = {
    Weapon = "No weapon",
    Speed = Config.Aim.ManualVelocity,
    Gravity = Config.Aim.ManualGravity,
    GravCoeff = 1,
    Source = "Manual fallback",
    Tool = nil,
}

local function getCharacter()
    return LocalPlayer.Character
end

local function isFreeForAll()
    local gameSystem = ReplicatedStorage:FindFirstChild("GameSystem")
    return gameSystem and gameSystem:GetAttribute("FreeForAll") == true
end

local function sameTeam(player)
    if isFreeForAll() then
        return false
    end
    if not LocalPlayer.Team or not player.Team then
        return false
    end
    return player.Team == LocalPlayer.Team or player.TeamColor == LocalPlayer.TeamColor
end

local function updateBallistics()
    local result = {
        Weapon = "Manual fallback",
        Speed = Config.Aim.ManualVelocity,
        Gravity = Config.Aim.ManualGravity,
        GravCoeff = 1,
        Source = "Manual",
        Tool = nil,
    }

    if Config.Aim.AutoBallistics then
        local character = getCharacter()
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local seat = humanoid and humanoid.SeatPart
        local mountedCommon = ReplicatedStorage:FindFirstChild("Mounted Gun Common")
        if seat and mountedCommon then
            local gunType = seat:FindFirstChild("GunType")
            local modules = mountedCommon:FindFirstChild("Modules")
            local weaponConfigModule = modules and modules:FindFirstChild("WeaponsConfig")
            local mountedFactory = safeRequireAny(weaponConfigModule)
            local allMounted = mountedFactory
            if type(mountedFactory) == "function" then
                local ok, result = pcall(mountedFactory)
                allMounted = ok and result or nil
            end
            local config = gunType and allMounted and allMounted[gunType.Value]
            if type(config) == "table" and tonumber(config.projectileSpeed) then
                result.Weapon = tostring(gunType.Value)
                result.Speed = tonumber(config.projectileSpeed)
                result.Gravity = tonumber(workspace:GetAttribute("MountedBulletGravity")) or Config.Aim.ManualGravity
                result.Source = "Mounted weapon config"
                result.Tool = seat
                Ballistics = result
                return
            end
        end

        local tool = character and character:FindFirstChildOfClass("Tool")
        local engine = ReplicatedStorage:FindFirstChild("ACS_Engine")
        local weaponConfigs = engine and engine:FindFirstChild("WeaponConfigs")
        local attachmentConfigs = engine and engine:FindFirstChild("AttachmentConfigs")
        local configModule = tool and weaponConfigs and weaponConfigs:FindFirstChild(tool.Name)
        local config = safeRequire(configModule)
        if tool and config and tonumber(config.MuzzleVelocity) then
            local multiplier = 1
            for _, attributeName in ipairs({"Sight", "Barrel", "UnderBarrel", "Other", "Ammo"}) do
                local attachmentName = tool:GetAttribute(attributeName)
                local attachmentModule = attachmentName and attachmentConfigs and attachmentConfigs:FindFirstChild(tostring(attachmentName))
                local attachment = safeRequire(attachmentModule)
                if attachment and tonumber(attachment.MuzzleVelocity) then
                    multiplier = multiplier * tonumber(attachment.MuzzleVelocity)
                end
            end
            local gravityBase = tonumber(workspace:GetAttribute("BulletGravity")) or workspace.Gravity
            local gravCoeff = tonumber(config.GravCoeff) or 1
            result.Weapon = tool.Name
            result.Speed = tonumber(config.MuzzleVelocity) * multiplier
            result.Gravity = gravityBase * gravCoeff
            result.GravCoeff = gravCoeff
            result.Source = multiplier ~= 1 and "ACS + attachments" or "ACS weapon config"
            result.Tool = tool
        end
    end
    Ballistics = result
end

local function currentBallistics()
    local speed = math.max((Ballistics.Speed or Config.Aim.ManualVelocity) * Config.Aim.VelocityScale, 1)
    local gravity = math.max((Ballistics.Gravity or Config.Aim.ManualGravity) * Config.Aim.DropScale, 0)
    return speed, gravity
end

local function solveBallistic(origin, targetPosition, targetVelocity)
    local speed, gravity = currentBallistics()
    if not Config.Aim.Prediction then
        return targetPosition, 0, 0, 0
    end
    if targetVelocity.Magnitude > 180 then
        targetVelocity = targetVelocity.Unit * 180
    end
    local flightTime = (targetPosition - origin).Magnitude / speed
    local futurePosition = targetPosition
    local aimPoint = targetPosition
    local drop = 0
    for _ = 1, 8 do
        futurePosition = targetPosition + targetVelocity * flightTime
        drop = 0.5 * gravity * flightTime * flightTime
        aimPoint = futurePosition + Vector3.new(0, drop, 0)
        local nextTime = (aimPoint - origin).Magnitude / speed
        if math.abs(nextTime - flightTime) < 0.0005 then
            flightTime = nextTime
            break
        end
        flightTime = nextTime
    end
    local lead = (futurePosition - targetPosition).Magnitude
    return aimPoint, flightTime, drop, lead
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
pcall(function()
    rayParams.CollisionGroup = "Raycast"
end)

local function visibleTo(model, worldPosition)
    local filter = {}
    local character = getCharacter()
    if character then
        table.insert(filter, character)
    end
    if Camera then
        table.insert(filter, Camera)
    end
    local acs = workspace:FindFirstChild("ACS_WorkSpace")
    local clientFolder = acs and acs:FindFirstChild("Client")
    if clientFolder then
        table.insert(filter, clientFolder)
    end
    rayParams.FilterDescendantsInstances = filter
    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, worldPosition - origin, rayParams)
    return result == nil or (result.Instance and result.Instance:IsDescendantOf(model))
end

local function getAimPart(character)
    if not character then
        return nil
    end
    if Config.Aim.AimPart ~= "Auto" then
        return character:FindFirstChild(Config.Aim.AimPart) or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    end
    local candidates = {
        character:FindFirstChild("Head"),
        character:FindFirstChild("UpperTorso"),
        character:FindFirstChild("Torso"),
        character:FindFirstChild("HumanoidRootPart"),
    }
    for _, part in ipairs(candidates) do
        if part and part:IsA("BasePart") and visibleTo(character, part.Position) then
            return part
        end
    end
    for _, part in ipairs(candidates) do
        if part and part:IsA("BasePart") then
            return part
        end
    end
    return nil
end

local function getPreferredPart(character)
    if not character then return nil end
    if Config.Aim.AimPart ~= "Auto" then
        return character:FindFirstChild(Config.Aim.AimPart) or character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    end
    return character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")
end

local function getMousePosition()
    local inset = GuiService:GetGuiInset()
    return UserInputService:GetMouseLocation() - inset
end

local function getPlayerData(player)
    if player == LocalPlayer then
        return nil
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local head = character and character:FindFirstChild("Head")
    if not character or not humanoid or not root or not head then
        return nil
    end
    if humanoid.Health <= 0 or not character:IsDescendantOf(workspace) then
        return nil
    end
    local distance = (head.Position - Camera.CFrame.Position).Magnitude
    local cache = Runtime.Cache[player] or {}
    local now = os.clock()
    if not cache.NextVisibility or now >= cache.NextVisibility then
        cache.Visible = visibleTo(character, head.Position)
        cache.NextVisibility = now + 0.09
    end
    cache.Character = character
    cache.Humanoid = humanoid
    cache.Root = root
    cache.Head = head
    cache.Distance = distance
    cache.Player = player
    Runtime.Cache[player] = cache
    return cache
end

local function getWeaponName(character)
    local tool = character and character:FindFirstChildOfClass("Tool")
    return tool and tool.Name or "UNARMED"
end

local selectedTarget = nil
local aimHeld = false

local function evaluateTarget(player, allowSticky)
    local data = getPlayerData(player)
    if not data then
        return nil
    end
    if Config.Aim.TeamCheck and sameTeam(player) then
        return nil
    end
    if data.Distance > Config.Aim.MaxDistance then
        return nil
    end
    local aimPart
    if Config.Aim.AimPart == "Auto" and data.Visible then
        aimPart = data.Head
    else
        aimPart = getAimPart(data.Character)
    end
    if not aimPart then
        return nil
    end
    local isVisible = aimPart == data.Head and data.Visible or visibleTo(data.Character, aimPart.Position)
    if Config.Aim.VisibleCheck and not isVisible then
        return nil
    end
    local aimPoint, flightTime, drop, lead = solveBallistic(Camera.CFrame.Position, aimPart.Position, data.Root.AssemblyLinearVelocity)
    local viewport, onScreen = Camera:WorldToViewportPoint(aimPoint)
    if not onScreen or viewport.Z <= 0 then
        return nil
    end
    local mousePosition = getMousePosition()
    local screenPosition = Vector2.new(viewport.X, viewport.Y)
    local screenDistance = (screenPosition - mousePosition).Magnitude
    local allowedFOV = Config.Aim.FOV * (allowSticky and 1.25 or 1)
    if screenDistance > allowedFOV then
        return nil
    end
    return {
        Player = player,
        Character = data.Character,
        Humanoid = data.Humanoid,
        Root = data.Root,
        Head = data.Head,
        AimPart = aimPart,
        AimPoint = aimPoint,
        BasePoint = aimPart.Position,
        Distance = data.Distance,
        ScreenDistance = screenDistance,
        ScreenPosition = screenPosition,
        FlightTime = flightTime,
        Drop = drop,
        Lead = lead,
        Visible = isVisible,
    }
end

local function selectTarget()
    if Config.Aim.StickyTarget and selectedTarget and selectedTarget.Player then
        local sticky = evaluateTarget(selectedTarget.Player, true)
        if sticky then
            return sticky
        end
    end
    local best = nil
    local bestScore = math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local candidate = evaluateTarget(player, false)
        if candidate then
            local score = candidate.ScreenDistance + candidate.Distance * 0.004
            if score < bestScore then
                best = candidate
                bestScore = score
            end
        end
    end
    return best
end

local function setLine(frame, from, to, thickness)
    local delta = to - from
    local length = delta.Magnitude
    frame.Position = UDim2.fromOffset((from.X + to.X) * 0.5, (from.Y + to.Y) * 0.5)
    frame.Size = UDim2.fromOffset(length, thickness or 1)
    frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

local skeletonPairsR15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local skeletonPairsR6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local function createVisual(player)
    local visual = {Lines = {}, Skeleton = {}}
    visual.Name = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.24,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Size = UDim2.fromOffset(190, 18),
        Text = "PLAYER",
        TextColor3 = Theme.Text,
        TextSize = 9,
        Visible = false,
        ZIndex = 31,
        Parent = Overlay,
    })
    corner(visual.Name, 5)
    visual.Info = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.24,
        BorderSizePixel = 0,
        Font = Enum.Font.RobotoMono,
        Size = UDim2.fromOffset(210, 17),
        Text = "-- HP • -- ST • --",
        TextColor3 = Theme.Accent2,
        TextSize = 8,
        Visible = false,
        ZIndex = 31,
        Parent = Overlay,
    })
    corner(visual.Info, 5)
    visual.Ballistic = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Enum.Font.RobotoMono,
        Size = UDim2.fromOffset(220, 16),
        Text = "DROP -- • LEAD --",
        TextColor3 = Theme.Yellow,
        TextSize = 8,
        Visible = false,
        ZIndex = 31,
        Parent = Overlay,
    })
    visual.HealthBack = create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(5, 100),
        Visible = false,
        ZIndex = 31,
        Parent = Overlay,
    })
    corner(visual.HealthBack, 3)
    visual.HealthFill = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = Theme.Green,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 32,
        Parent = visual.HealthBack,
    })
    corner(visual.HealthFill, 3)
    visual.Tracer = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Accent2,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 25,
        Parent = Overlay,
    })
    visual.Prediction = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme.Yellow,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(9, 9),
        Visible = false,
        ZIndex = 34,
        Parent = Overlay,
    })
    corner(visual.Prediction, 99)
    stroke(visual.Prediction, Theme.Text, 0.05, 1)
    visual.Arrow = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBlack,
        Size = UDim2.fromOffset(28, 28),
        Text = "▲",
        TextColor3 = Theme.Accent2,
        TextSize = 22,
        Visible = false,
        ZIndex = 35,
        Parent = Overlay,
    })
    visual.Highlight = create("Highlight", {
        Name = "RawHubHighlight",
        Adornee = nil,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        Enabled = false,
        FillColor = Theme.Accent,
        FillTransparency = 0.84,
        OutlineColor = Theme.Accent2,
        OutlineTransparency = 0.08,
        Parent = Overlay,
    })
    for _ = 1, 8 do
        table.insert(visual.Lines, create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Accent2,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 30,
            Parent = Overlay,
        }))
    end
    for _ = 1, 14 do
        table.insert(visual.Skeleton, create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Theme.Accent2,
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 28,
            Parent = Overlay,
        }))
    end
    Runtime.Visuals[player] = visual
    return visual
end

local function hideVisual(visual)
    visual.Name.Visible = false
    visual.Info.Visible = false
    visual.Ballistic.Visible = false
    visual.HealthBack.Visible = false
    visual.Tracer.Visible = false
    visual.Prediction.Visible = false
    visual.Arrow.Visible = false
    visual.Highlight.Enabled = false
    for _, line in ipairs(visual.Lines) do line.Visible = false end
    for _, line in ipairs(visual.Skeleton) do line.Visible = false end
end

local function destroyVisual(player)
    local visual = Runtime.Visuals[player]
    if not visual then return end
    for _, object in pairs(visual) do
        if typeof(object) == "Instance" then
            safeDestroy(object)
        elseif type(object) == "table" then
            for _, child in ipairs(object) do safeDestroy(child) end
        end
    end
    Runtime.Visuals[player] = nil
    Runtime.Cache[player] = nil
end

local function screenBox(data)
    local humanoid, root, head = data.Humanoid, data.Root, data.Head
    local topWorld = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.35, 0)
    local bottomWorld = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y * 0.5 + 0.25, 0)
    local top, topOn = Camera:WorldToViewportPoint(topWorld)
    local bottom, bottomOn = Camera:WorldToViewportPoint(bottomWorld)
    if top.Z <= 0 or bottom.Z <= 0 then
        return nil
    end
    local height = math.max(math.abs(bottom.Y - top.Y), 12)
    local width = math.max(height * 0.56, 8)
    local centerX = (top.X + bottom.X) * 0.5
    return {centerX - width * 0.5, math.min(top.Y, bottom.Y), width, height, topOn or bottomOn}
end

local function drawCornerBox(visual, x, y, width, height, color)
    local segmentW = math.max(width * 0.26, 5)
    local segmentH = math.max(height * 0.20, 5)
    local points = {
        {Vector2.new(x, y), Vector2.new(x + segmentW, y)},
        {Vector2.new(x, y), Vector2.new(x, y + segmentH)},
        {Vector2.new(x + width, y), Vector2.new(x + width - segmentW, y)},
        {Vector2.new(x + width, y), Vector2.new(x + width, y + segmentH)},
        {Vector2.new(x, y + height), Vector2.new(x + segmentW, y + height)},
        {Vector2.new(x, y + height), Vector2.new(x, y + height - segmentH)},
        {Vector2.new(x + width, y + height), Vector2.new(x + width - segmentW, y + height)},
        {Vector2.new(x + width, y + height), Vector2.new(x + width, y + height - segmentH)},
    }
    for index, pair in ipairs(points) do
        local line = visual.Lines[index]
        line.BackgroundColor3 = color
        line.Visible = Config.ESP.Boxes
        setLine(line, pair[1], pair[2], 1.5)
    end
end

local function drawSkeleton(visual, character, color)
    local pairsList = character:FindFirstChild("UpperTorso") and skeletonPairsR15 or skeletonPairsR6
    for index, line in ipairs(visual.Skeleton) do
        local pair = pairsList[index]
        if Config.ESP.Skeleton and pair then
            local a = character:FindFirstChild(pair[1])
            local b = character:FindFirstChild(pair[2])
            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                local pointA, onA = Camera:WorldToViewportPoint(a.Position)
                local pointB, onB = Camera:WorldToViewportPoint(b.Position)
                if pointA.Z > 0 and pointB.Z > 0 and (onA or onB) then
                    line.BackgroundColor3 = color
                    line.Visible = true
                    setLine(line, Vector2.new(pointA.X, pointA.Y), Vector2.new(pointB.X, pointB.Y), 1)
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

local function updateOffscreen(visual, worldPosition, color)
    if not Config.ESP.Offscreen then
        visual.Arrow.Visible = false
        return
    end
    local viewport = Camera.ViewportSize
    local center = viewport * 0.5
    local point = Camera:WorldToViewportPoint(worldPosition)
    local direction = Vector2.new(point.X, point.Y) - center
    if point.Z < 0 then
        direction = -direction
    end
    if direction.Magnitude < 1 then
        direction = Vector2.new(0, -1)
    else
        direction = direction.Unit
    end
    local radius = math.min(viewport.X, viewport.Y) * 0.43
    local position = center + direction * radius
    visual.Arrow.Position = UDim2.fromOffset(position.X, position.Y)
    visual.Arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
    visual.Arrow.TextColor3 = color
    visual.Arrow.Visible = true
end

local function updateVisual(player, visual)
    local data = getPlayerData(player)
    if not Config.ESP.Enabled or not data then
        hideVisual(visual)
        return
    end
    if Config.ESP.TeamCheck and sameTeam(player) then
        hideVisual(visual)
        return
    end
    if data.Distance > Config.ESP.MaxDistance then
        hideVisual(visual)
        return
    end
    local box = screenBox(data)
    local selected = selectedTarget and selectedTarget.Player == player
    local color = selected and Theme.Yellow or (data.Visible and Theme.Accent2 or Theme.Hidden)
    visual.Highlight.Adornee = data.Character
    visual.Highlight.OutlineColor = color
    visual.Highlight.FillColor = selected and Theme.Yellow or Theme.Accent
    visual.Highlight.Enabled = Config.ESP.Highlights

    if not box or not box[5] then
        visual.Name.Visible = false
        visual.Info.Visible = false
        visual.Ballistic.Visible = false
        visual.HealthBack.Visible = false
        visual.Tracer.Visible = false
        visual.Prediction.Visible = false
        for _, line in ipairs(visual.Lines) do line.Visible = false end
        for _, line in ipairs(visual.Skeleton) do line.Visible = false end
        updateOffscreen(visual, data.Root.Position, color)
        return
    end

    visual.Arrow.Visible = false
    local x, y, width, height = box[1], box[2], box[3], box[4]
    drawCornerBox(visual, x, y, width, height, color)
    drawSkeleton(visual, data.Character, color)

    local displayName = player.DisplayName
    if displayName ~= player.Name then
        displayName = displayName .. "  @" .. player.Name
    end
    visual.Name.Text = string.upper(displayName)
    visual.Name.TextColor3 = color
    visual.Name.Position = UDim2.fromOffset(x + width * 0.5, y - 5)
    visual.Name.Visible = Config.ESP.Names

    local pieces = {}
    if Config.ESP.Health then table.insert(pieces, string.format("%d HP", data.Humanoid.Health)) end
    if Config.ESP.Distance then table.insert(pieces, string.format("%d ST", data.Distance)) end
    if Config.ESP.Weapon then table.insert(pieces, getWeaponName(data.Character)) end
    visual.Info.Text = table.concat(pieces, " • ")
    visual.Info.TextColor3 = color
    visual.Info.Position = UDim2.fromOffset(x + width * 0.5, y + height + 5)
    visual.Info.Visible = #pieces > 0

    local aimPart = getPreferredPart(data.Character) or data.Head
    local predicted, flightTime, drop, lead = solveBallistic(Camera.CFrame.Position, aimPart.Position, data.Root.AssemblyLinearVelocity)
    visual.Ballistic.Text = string.format("DROP %.1f • LEAD %.1f • %dms", drop, lead, flightTime * 1000)
    visual.Ballistic.Position = UDim2.fromOffset(x + width * 0.5, y + height + 22)
    visual.Ballistic.Visible = Config.ESP.Prediction and Config.Aim.Prediction

    local healthRatio = math.clamp(data.Humanoid.Health / math.max(data.Humanoid.MaxHealth, 1), 0, 1)
    visual.HealthBack.Position = UDim2.fromOffset(x - 6, y)
    visual.HealthBack.Size = UDim2.fromOffset(4, height)
    visual.HealthBack.Visible = Config.ESP.Health
    visual.HealthFill.Size = UDim2.fromScale(1, healthRatio)
    visual.HealthFill.BackgroundColor3 = Theme.Red:Lerp(Theme.Green, healthRatio)

    visual.Tracer.BackgroundColor3 = color
    visual.Tracer.Visible = Config.ESP.Tracers
    if Config.ESP.Tracers then
        setLine(visual.Tracer, Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y - 4), Vector2.new(x + width * 0.5, y + height), 1)
    end

    local predictionPoint, predictionOn = Camera:WorldToViewportPoint(predicted)
    visual.Prediction.Position = UDim2.fromOffset(predictionPoint.X, predictionPoint.Y)
    visual.Prediction.BackgroundColor3 = color
    visual.Prediction.Visible = Config.ESP.Prediction and Config.Aim.Prediction and predictionOn and predictionPoint.Z > 0
end

local lastBallisticUpdate = 0
local lastTargetUpdate = 0
local mouseMove = mousemoverel
if not mouseMove and type(Env.mousemoverel) == "function" then
    mouseMove = Env.mousemoverel
end

local function applyAim(deltaTime)
    if not Config.Aim.Enabled or not aimHeld or not selectedTarget or not Camera then
        return
    end
    if Config.Aim.VisibleCheck and not selectedTarget.Visible then
        return
    end
    if Config.Aim.Method == "Mouse" and type(mouseMove) == "function" then
        local point, onScreen = Camera:WorldToViewportPoint(selectedTarget.AimPoint)
        if onScreen and point.Z > 0 then
            local mousePosition = getMousePosition()
            local delta = Vector2.new(point.X, point.Y) - mousePosition
            local divisor = math.max(Config.Aim.Smoothness * 0.42, 1)
            pcall(mouseMove, delta.X / divisor, delta.Y / divisor)
        end
        return
    end
    local position = Camera.CFrame.Position
    local direction = selectedTarget.AimPoint - position
    if direction.Magnitude < 0.01 then
        return
    end
    local desired = CFrame.lookAt(position, selectedTarget.AimPoint, Camera.CFrame.UpVector)
    local dot = math.clamp(Camera.CFrame.LookVector:Dot(desired.LookVector), -1, 1)
    local angle = math.acos(dot)
    local alpha = 1 - math.exp(-Config.Aim.Smoothness * deltaTime)
    if angle > 0 then
        local maxStep = math.rad(Config.Aim.MaxTurnRate) * deltaTime
        alpha = math.min(alpha, maxStep / angle)
    end
    Camera.CFrame = Camera.CFrame:Lerp(desired, math.clamp(alpha, 0, 1))
end

local function updateTelemetry()
    if not selectedTarget then
        TargetCard.Visible = false
        FOVStroke.Color = Theme.Accent2
        return
    end
    TargetCard.Visible = Config.Interface.TargetCard
    TargetName.Text = string.upper(selectedTarget.Player.DisplayName .. "  @" .. selectedTarget.Player.Name)
    TargetName.TextColor3 = selectedTarget.Visible and Theme.Green or Theme.Red
    TargetStats.Text = string.format("RANGE %d  |  TOF %dms  |  DROP %.1f", selectedTarget.Distance, selectedTarget.FlightTime * 1000, selectedTarget.Drop)
    local speed = currentBallistics()
    TargetWeapon.Text = string.format("%s  •  %d STUDS/S", string.upper(Ballistics.Weapon), speed)
    TargetLead.Text = string.format("LEAD %.1f  |  LOS %s", selectedTarget.Lead, selectedTarget.Visible and "CLEAR" or "BLOCKED")
    FOVStroke.Color = selectedTarget.Visible and Theme.Green or Theme.Red
end

local function render(deltaTime)
    if not Runtime.Running then return end
    Camera = workspace.CurrentCamera or Camera
    if not Camera then return end

    local mousePosition = getMousePosition()
    FOVCircle.Position = UDim2.fromOffset(mousePosition.X, mousePosition.Y)
    FOVCircle.Visible = Config.Interface.FOVCircle and Config.Aim.Enabled

    local now = os.clock()
    if now - lastBallisticUpdate >= 0.35 then
        lastBallisticUpdate = now
        updateBallistics()
        local speed, gravity = currentBallistics()
        BallisticName.Text = "  WEAPON  " .. string.upper(Ballistics.Weapon)
        BallisticValues.Text = string.format("  VELOCITY  %.0f studs/s\n  GRAVITY   %.2f studs/s²\n  SOURCE    %s", speed, gravity, string.upper(Ballistics.Source))
    end
    if now - lastTargetUpdate >= 1 / 45 then
        lastTargetUpdate = now
        selectedTarget = selectTarget()
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local visual = Runtime.Visuals[player] or createVisual(player)
            updateVisual(player, visual)
        end
    end
    for player in pairs(Runtime.Visuals) do
        if not player.Parent then
            destroyVisual(player)
        end
    end

    updateTelemetry()
    applyAim(deltaTime)
end

connect(UserInputService.InputBegan, function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimHeld = true
    end
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Config.Interface.MenuVisible = not Config.Interface.MenuVisible
        Main.Visible = Config.Interface.MenuVisible
    elseif input.KeyCode == Enum.KeyCode.F1 then
        setESPEnabled(not Config.ESP.Enabled)
        notify("VISUALS", Config.ESP.Enabled and "Detailed player ESP enabled" or "Player ESP disabled", Config.ESP.Enabled and Theme.Green or Theme.Red)
    elseif input.KeyCode == Enum.KeyCode.F2 then
        setAimEnabled(not Config.Aim.Enabled)
        notify("AIM ASSIST", Config.Aim.Enabled and "Hold RMB to engage" or "Aim assist disabled", Config.Aim.Enabled and Theme.Green or Theme.Red)
    elseif input.KeyCode == Enum.KeyCode.End then
        Runtime.Unload()
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimHeld = false
    end
end)

connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    Camera = workspace.CurrentCamera
end)

connect(Players.PlayerRemoving, function(player)
    destroyVisual(player)
end)

function Runtime.Unload()
    if not Runtime.Running then return end
    Runtime.Running = false
    for _, connection in ipairs(Runtime.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    for player in pairs(Runtime.Visuals) do
        destroyVisual(player)
    end
    safeDestroy(ScreenGui)
    if Env.RawHubV2 == Runtime then
        Env.RawHubV2 = nil
    end
end

connect(UnloadButton.Activated, function()
    Runtime.Unload()
end)

connect(RunService.RenderStepped, render)

notify("RAW HUB v2.0", "ESP, smooth aim and automatic ACS ballistics loaded", Theme.Green)
print("[Raw Hub v2.0] Loaded | RMB aim | F1 ESP | F2 aim | RightShift menu | END unload")
