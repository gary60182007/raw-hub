--!strict
-- Raw Hub Training Lab
-- Install as a LocalScript in StarterPlayerScripts.
-- The tool is intentionally limited to Roblox Studio and tagged NPC models.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

if not RunService:IsStudio() then
	warn("[Raw Training Lab] This developer overlay runs in Roblox Studio only.")
	return
end

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
local camera = workspace.CurrentCamera

local THEME = {
	Background = Color3.fromRGB(8, 11, 20),
	Panel = Color3.fromRGB(15, 20, 34),
	PanelRaised = Color3.fromRGB(22, 29, 47),
	Line = Color3.fromRGB(67, 79, 112),
	Text = Color3.fromRGB(242, 246, 255),
	Muted = Color3.fromRGB(145, 158, 188),
	Accent = Color3.fromRGB(117, 98, 255),
	Cyan = Color3.fromRGB(68, 214, 255),
	Green = Color3.fromRGB(72, 232, 164),
	Yellow = Color3.fromRGB(255, 202, 91),
	Red = Color3.fromRGB(255, 91, 124),
}

local config = {
	TargetTag = "TrainingTarget",
	OverlayEnabled = true,
	AimAssistEnabled = true,
	ShowHighlights = true,
	ShowTracers = true,
	ShowPrediction = true,
	RequireLineOfSight = true,
	MaxDistance = 1400,
	FieldOfView = 180,
	ProjectileSpeed = 1800,
	Gravity = workspace.Gravity,
	Smoothing = 13,
}

type TargetInfo = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	distance: number,
	aimPoint: Vector3,
	timeOfFlight: number,
	holdover: number,
	screenDistance: number,
	visible: boolean,
}

type Visual = {
	box: Frame,
	stroke: UIStroke,
	name: TextLabel,
	info: TextLabel,
	healthBack: Frame,
	healthFill: Frame,
	tracer: Frame,
	prediction: Frame,
	highlight: Highlight,
}

local function make(className: string, properties: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for property, value in pairs(properties) do
		(instance :: any)[property] = value
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	return instance
end

local function addCorner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function addStroke(parent: Instance, color: Color3, transparency: number?, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		Parent = parent,
	})
end

local oldGui = playerGui:FindFirstChild("RawTrainingLab")
if oldGui then
	oldGui:Destroy()
end

local screenGui = make("ScreenGui", {
	Name = "RawTrainingLab",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 50,
	Parent = playerGui,
}) :: ScreenGui

local dimmer = make("Frame", {
	Name = "Dimmer",
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.62,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 1,
	Parent = screenGui,
}) :: Frame

local fovRing = make("Frame", {
	Name = "FOV",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(config.FieldOfView * 2, config.FieldOfView * 2),
	ZIndex = 8,
	Parent = screenGui,
}) :: Frame
addCorner(fovRing, 1000)
local fovStroke = addStroke(fovRing, THEME.Accent, 0.25, 1.5)

local fovGlow = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	ZIndex = 7,
	Parent = fovRing,
}) :: Frame
addCorner(fovGlow, 1000)
addStroke(fovGlow, THEME.Cyan, 0.83, 5)

local crosshairDot = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = THEME.Text,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(5, 5),
	ZIndex = 12,
	Parent = screenGui,
}) :: Frame
addCorner(crosshairDot, 100)
addStroke(crosshairDot, THEME.Accent, 0, 1)

local panel = make("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundColor3 = THEME.Panel,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
	Position = UDim2.new(1, -24, 0.5, 0),
	Size = UDim2.fromOffset(330, 608),
	ZIndex = 20,
	Parent = screenGui,
}) :: Frame
addCorner(panel, 18)
addStroke(panel, THEME.Line, 0.18, 1)

make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(23, 28, 48)),
		ColorSequenceKeypoint.new(1, THEME.Background),
	}),
	Rotation = 115,
	Parent = panel,
})

local accentBar = make("Frame", {
	BackgroundColor3 = THEME.Accent,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, 0, 0, 4),
	ZIndex = 21,
	Parent = panel,
}) :: Frame
addCorner(accentBar, 18)
make("UIGradient", {
	Color = ColorSequence.new(THEME.Accent, THEME.Cyan),
	Parent = accentBar,
})

local content = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 18),
	Size = UDim2.new(1, -36, 1, -36),
	ZIndex = 22,
	Parent = panel,
}) :: Frame

make("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = content,
})

local header = make("Frame", {
	BackgroundTransparency = 1,
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 58),
	ZIndex = 23,
	Parent = content,
}) :: Frame

make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, 0, 0, 29),
	Text = "RAW // TRAINING LAB",
	TextColor3 = THEME.Text,
	TextSize = 19,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 24,
	Parent = header,
})

make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Position = UDim2.fromOffset(0, 29),
	Size = UDim2.new(1, 0, 0, 22),
	Text = "STUDIO • TAGGED NPC TARGETS",
	TextColor3 = THEME.Green,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 24,
	Parent = header,
})

local statusCard = make("Frame", {
	BackgroundColor3 = THEME.PanelRaised,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 116),
	ZIndex = 23,
	Parent = content,
}) :: Frame
addCorner(statusCard, 12)
addStroke(statusCard, THEME.Line, 0.5, 1)

local statusTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(12, 9),
	Size = UDim2.new(1, -24, 0, 18),
	Text = "NO TARGET",
	TextColor3 = THEME.Muted,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 24,
	Parent = statusCard,
}) :: TextLabel

local statusMetrics = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.RobotoMono,
	Position = UDim2.fromOffset(12, 31),
	Size = UDim2.new(1, -24, 0, 68),
	Text = "RANGE     -- studs\nTIME      -- ms\nHOLDOVER  -- studs\nLOS       --",
	TextColor3 = THEME.Text,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 24,
	Parent = statusCard,
}) :: TextLabel

local controlsTitle = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 18),
	Text = "SYSTEMS",
	TextColor3 = THEME.Muted,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 23,
	Parent = content,
}) :: TextLabel

local rowOrder = 4

local function createRow(height: number): Frame
	local row = make("Frame", {
		BackgroundColor3 = THEME.PanelRaised,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		LayoutOrder = rowOrder,
		Size = UDim2.new(1, 0, 0, height),
		ZIndex = 23,
		Parent = content,
	}) :: Frame
	rowOrder += 1
	addCorner(row, 10)
	addStroke(row, THEME.Line, 0.68, 1)
	return row
end

local function createToggle(labelText: string, initialValue: boolean, callback: (boolean) -> ()): (boolean) -> ()
	local row = createRow(40)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -72, 1, 0),
		Text = labelText,
		TextColor3 = THEME.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = row,
	})

	local toggle = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = THEME.Line,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(46, 22),
		Text = "",
		ZIndex = 24,
		Parent = row,
	}) :: TextButton
	addCorner(toggle, 100)

	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = THEME.Text,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 25,
		Parent = toggle,
	}) :: Frame
	addCorner(knob, 100)

	local state = initialValue
	local function render()
		toggle.BackgroundColor3 = if state then THEME.Accent else THEME.Line
		knob.Position = if state then UDim2.new(1, -19, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
	end

	local function set(value: boolean)
		state = value
		render()
		callback(state)
	end

	toggle.Activated:Connect(function()
		set(not state)
	end)
	render()
	return set
end

local function createStepper(
	labelText: string,
	initialValue: number,
	step: number,
	minimum: number,
	maximum: number,
	formatter: (number) -> string,
	callback: (number) -> ()
): (number) -> ()
	local row = createRow(42)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(0.48, 0, 1, 0),
		Text = labelText,
		TextColor3 = THEME.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 24,
		Parent = row,
	})

	local minus = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = THEME.Line,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(1, -91, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		Text = "−",
		TextColor3 = THEME.Text,
		TextSize = 17,
		ZIndex = 24,
		Parent = row,
	}) :: TextButton
	addCorner(minus, 7)

	local valueLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Font = Enum.Font.RobotoMono,
		Position = UDim2.new(1, -38, 0.5, 0),
		Size = UDim2.fromOffset(50, 26),
		Text = formatter(initialValue),
		TextColor3 = THEME.Cyan,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 24,
		Parent = row,
	}) :: TextLabel

	local plus = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = THEME.Line,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		Text = "+",
		TextColor3 = THEME.Text,
		TextSize = 16,
		ZIndex = 24,
		Parent = row,
	}) :: TextButton
	addCorner(plus, 7)

	local value = initialValue
	local function set(newValue: number)
		value = math.clamp(newValue, minimum, maximum)
		valueLabel.Text = formatter(value)
		callback(value)
	end

	minus.Activated:Connect(function()
		set(value - step)
	end)
	plus.Activated:Connect(function()
		set(value + step)
	end)
	return set
end

local setOverlay = createToggle("Target overlay", config.OverlayEnabled, function(value)
	config.OverlayEnabled = value
end)
local setAimAssist = createToggle("Aim guidance (hold RMB)", config.AimAssistEnabled, function(value)
	config.AimAssistEnabled = value
end)
createToggle("Line-of-sight filter", config.RequireLineOfSight, function(value)
	config.RequireLineOfSight = value
end)
createStepper("Projectile speed", config.ProjectileSpeed, 100, 200, 5000, function(value)
	return string.format("%d", value)
end, function(value)
	config.ProjectileSpeed = value
end)
createStepper("FOV radius", config.FieldOfView, 20, 60, 420, function(value)
	return string.format("%d px", value)
end, function(value)
	config.FieldOfView = value
	fovRing.Size = UDim2.fromOffset(value * 2, value * 2)
end)
createStepper("Aim smoothing", config.Smoothing, 1, 2, 30, function(value)
	return string.format("%.0f", value)
end, function(value)
	config.Smoothing = value
end)

local hint = make("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	LayoutOrder = rowOrder + 1,
	Size = UDim2.new(1, 0, 0, 34),
	Text = "F1 overlay   F2 guidance   RightShift panel",
	TextColor3 = THEME.Muted,
	TextSize = 10,
	TextWrapped = true,
	ZIndex = 23,
	Parent = content,
}) :: TextLabel

local visuals: { [Model]: Visual } = {}
local aimHeld = false
local selectedTarget: TargetInfo? = nil

local function createVisual(model: Model): Visual
	local box = make("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 10,
		Parent = screenGui,
	}) :: Frame
	local stroke = addStroke(box, THEME.Cyan, 0.05, 1.4)

	local nameLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = THEME.Background,
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(0.5, 0, 0, -5),
		Size = UDim2.fromOffset(150, 19),
		Text = string.upper(model.Name),
		TextColor3 = THEME.Text,
		TextSize = 10,
		ZIndex = 11,
		Parent = box,
	}) :: TextLabel
	addCorner(nameLabel, 5)

	local infoLabel = make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = THEME.Background,
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Font = Enum.Font.RobotoMono,
		Position = UDim2.new(0.5, 0, 1, 5),
		Size = UDim2.fromOffset(150, 18),
		Text = "-- studs • -- ms",
		TextColor3 = THEME.Cyan,
		TextSize = 9,
		ZIndex = 11,
		Parent = box,
	}) :: TextLabel
	addCorner(infoLabel, 5)

	local healthBack = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = THEME.Background,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-5, 0),
		Size = UDim2.new(0, 4, 1, 0),
		ZIndex = 11,
		Parent = box,
	}) :: Frame
	addCorner(healthBack, 2)

	local healthFill = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = THEME.Green,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 12,
		Parent = healthBack,
	}) :: Frame
	addCorner(healthFill, 2)

	local tracer = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = THEME.Cyan,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 9,
		Parent = screenGui,
	}) :: Frame

	local prediction = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = THEME.Yellow,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(8, 8),
		Visible = false,
		ZIndex = 13,
		Parent = screenGui,
	}) :: Frame
	addCorner(prediction, 100)
	addStroke(prediction, THEME.Text, 0.1, 1)

	local highlight = make("Highlight", {
		Name = "TrainingTargetHighlight",
		Adornee = model,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillColor = THEME.Accent,
		FillTransparency = 0.84,
		OutlineColor = THEME.Cyan,
		OutlineTransparency = 0.12,
		Enabled = false,
		Parent = model,
	}) :: Highlight

	local visual: Visual = {
		box = box,
		stroke = stroke,
		name = nameLabel,
		info = infoLabel,
		healthBack = healthBack,
		healthFill = healthFill,
		tracer = tracer,
		prediction = prediction,
		highlight = highlight,
	}
	visuals[model] = visual
	return visual
end

local function destroyVisual(model: Model)
	local visual = visuals[model]
	if not visual then
		return
	end
	visual.box:Destroy()
	visual.tracer:Destroy()
	visual.prediction:Destroy()
	visual.highlight:Destroy()
	visuals[model] = nil
end

local function getNpcParts(model: Model): (Humanoid?, BasePart?, BasePart?)
	if Players:GetPlayerFromCharacter(model) then
		return nil, nil, nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if not humanoid or not root or not root:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nil, nil, nil
	end
	if humanoid.Health <= 0 then
		return nil, nil, nil
	end
	return humanoid, root, head
end

local function solveBallistics(origin: Vector3, targetPosition: Vector3, targetVelocity: Vector3): (Vector3, number, number)
	local speed = math.max(config.ProjectileSpeed, 1)
	local gravity = math.max(config.Gravity, 0)
	local time = (targetPosition - origin).Magnitude / speed
	local aimPoint = targetPosition

	for _ = 1, 5 do
		local futurePosition = targetPosition + targetVelocity * time
		local holdover = Vector3.new(0, 0.5 * gravity * time * time, 0)
		aimPoint = futurePosition + holdover
		time = (aimPoint - origin).Magnitude / speed
	end

	return aimPoint, time, 0.5 * gravity * time * time
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function hasLineOfSight(model: Model, worldPoint: Vector3): boolean
	local exclusions: { Instance } = {}
	if localPlayer.Character then
		table.insert(exclusions, localPlayer.Character)
	end
	raycastParams.FilterDescendantsInstances = exclusions
	local origin = camera.CFrame.Position
	local result = workspace:Raycast(origin, worldPoint - origin, raycastParams)
	return result == nil or result.Instance:IsDescendantOf(model)
end

local function getBounds(model: Model): (Vector2?, Vector2?)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local half = boxSize * 0.5
	local minimum = Vector2.new(math.huge, math.huge)
	local maximum = Vector2.new(-math.huge, -math.huge)
	local pointInFront = false

	for x = -1, 1, 2 do
		for y = -1, 1, 2 do
			for z = -1, 1, 2 do
				local worldCorner = boxCFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
				local viewportPoint = camera:WorldToViewportPoint(worldCorner)
				if viewportPoint.Z > 0 then
					pointInFront = true
					minimum = Vector2.new(math.min(minimum.X, viewportPoint.X), math.min(minimum.Y, viewportPoint.Y))
					maximum = Vector2.new(math.max(maximum.X, viewportPoint.X), math.max(maximum.Y, viewportPoint.Y))
				end
			end
		end
	end

	if not pointInFront then
		return nil, nil
	end
	return minimum, maximum
end

local function setLine(frame: Frame, from: Vector2, to: Vector2, thickness: number)
	local delta = to - from
	local length = delta.Magnitude
	frame.Position = UDim2.fromOffset((from.X + to.X) * 0.5, (from.Y + to.Y) * 0.5)
	frame.Size = UDim2.fromOffset(length, thickness)
	frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

local function collectTargets(): { TargetInfo }
	local results: { TargetInfo } = {}
	local origin = camera.CFrame.Position
	local viewportCenter = camera.ViewportSize * 0.5

	for _, tagged in ipairs(CollectionService:GetTagged(config.TargetTag)) do
		if tagged:IsA("Model") and tagged:IsDescendantOf(workspace) then
			local humanoid, root, head = getNpcParts(tagged)
			if humanoid and root and head then
				local distance = (head.Position - origin).Magnitude
				if distance <= config.MaxDistance then
					local aimPoint, timeOfFlight, holdover = solveBallistics(origin, head.Position, root.AssemblyLinearVelocity)
					local viewportPoint, onScreen = camera:WorldToViewportPoint(aimPoint)
					local screenDistance = if onScreen
						then (Vector2.new(viewportPoint.X, viewportPoint.Y) - viewportCenter).Magnitude
						else math.huge
					table.insert(results, {
						model = tagged,
						humanoid = humanoid,
						root = root,
						head = head,
						distance = distance,
						aimPoint = aimPoint,
						timeOfFlight = timeOfFlight,
						holdover = holdover,
						screenDistance = screenDistance,
						visible = hasLineOfSight(tagged, aimPoint),
					})
				end
			end
		end
	end

	return results
end

local function selectBestTarget(targets: { TargetInfo }): TargetInfo?
	local best: TargetInfo? = nil
	local bestScore = math.huge
	for _, target in ipairs(targets) do
		if target.screenDistance <= config.FieldOfView then
			if not config.RequireLineOfSight or target.visible then
				local distanceWeight = math.clamp(target.distance / config.MaxDistance, 0, 1) * 20
				local score = target.screenDistance + distanceWeight
				if score < bestScore then
					best = target
					bestScore = score
				end
			end
		end
	end
	return best
end

local function updateVisual(target: TargetInfo, visual: Visual, selected: boolean)
	local minimum, maximum = getBounds(target.model)
	local aimViewport, aimOnScreen = camera:WorldToViewportPoint(target.aimPoint)
	local color = if selected then THEME.Yellow else if target.visible then THEME.Cyan else THEME.Red
	visual.stroke.Color = color
	visual.highlight.OutlineColor = color
	visual.highlight.FillColor = if selected then THEME.Yellow else THEME.Accent
	visual.highlight.Enabled = config.OverlayEnabled and config.ShowHighlights

	if minimum and maximum and config.OverlayEnabled then
		local size = maximum - minimum
		visual.box.Position = UDim2.fromOffset(minimum.X, minimum.Y)
		visual.box.Size = UDim2.fromOffset(math.max(size.X, 4), math.max(size.Y, 4))
		visual.box.Visible = true
		visual.name.Text = string.upper(target.model.Name)
		visual.info.Text = string.format("%d studs • %d ms", target.distance, target.timeOfFlight * 1000)
		visual.info.TextColor3 = color
		local healthRatio = math.clamp(target.humanoid.Health / math.max(target.humanoid.MaxHealth, 1), 0, 1)
		visual.healthFill.Size = UDim2.fromScale(1, healthRatio)
		visual.healthFill.BackgroundColor3 = THEME.Red:Lerp(THEME.Green, healthRatio)

		if config.ShowTracers then
			setLine(
				visual.tracer,
				Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y - 28),
				Vector2.new((minimum.X + maximum.X) * 0.5, maximum.Y),
				1
			)
			visual.tracer.BackgroundColor3 = color
			visual.tracer.Visible = true
		else
			visual.tracer.Visible = false
		end
	else
		visual.box.Visible = false
		visual.tracer.Visible = false
	end

	visual.prediction.Visible = config.OverlayEnabled and config.ShowPrediction and aimOnScreen
	if visual.prediction.Visible then
		visual.prediction.Position = UDim2.fromOffset(aimViewport.X, aimViewport.Y)
		visual.prediction.BackgroundColor3 = color
	end
end

local function hideUnusedVisuals(activeModels: { [Model]: boolean })
	for model, visual in pairs(visuals) do
		if not activeModels[model] then
			visual.box.Visible = false
			visual.tracer.Visible = false
			visual.prediction.Visible = false
			visual.highlight.Enabled = false
			if not model.Parent then
				destroyVisual(model)
			end
		end
	end
end

local function updateStatus(target: TargetInfo?)
	if not target then
		statusTitle.Text = "NO TARGET"
		statusTitle.TextColor3 = THEME.Muted
		statusMetrics.Text = "RANGE     -- studs\nTIME      -- ms\nHOLDOVER  -- studs\nLOS       --"
		fovStroke.Color = THEME.Accent
		return
	end

	statusTitle.Text = string.upper(target.model.Name)
	statusTitle.TextColor3 = if target.visible then THEME.Green else THEME.Red
	statusMetrics.Text = string.format(
		"RANGE     %d studs\nTIME      %d ms\nHOLDOVER  %.2f studs\nLOS       %s",
		target.distance,
		target.timeOfFlight * 1000,
		target.holdover,
		if target.visible then "CLEAR" else "BLOCKED"
	)
	fovStroke.Color = if target.visible then THEME.Green else THEME.Red
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimHeld = true
	elseif input.KeyCode == Enum.KeyCode.RightShift then
		panel.Visible = not panel.Visible
	elseif input.KeyCode == Enum.KeyCode.F1 then
		setOverlay(not config.OverlayEnabled)
	elseif input.KeyCode == Enum.KeyCode.F2 then
		setAimAssist(not config.AimAssistEnabled)
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimHeld = false
	end
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = workspace.CurrentCamera
end)

local accumulated = 0
local cachedTargets: { TargetInfo } = {}

RunService.RenderStepped:Connect(function(deltaTime: number)
	if not camera then
		return
	end

	config.Gravity = workspace.Gravity
	accumulated += deltaTime
	if accumulated >= 1 / 30 then
		accumulated = 0
		cachedTargets = collectTargets()
		selectedTarget = selectBestTarget(cachedTargets)
	end

	local activeModels: { [Model]: boolean } = {}
	for _, target in ipairs(cachedTargets) do
		activeModels[target.model] = true
		local visual = visuals[target.model] or createVisual(target.model)
		updateVisual(target, visual, selectedTarget ~= nil and target.model == selectedTarget.model)
	end
	hideUnusedVisuals(activeModels)
	updateStatus(selectedTarget)

	fovRing.Visible = config.OverlayEnabled
	crosshairDot.Visible = config.OverlayEnabled
	dimmer.Visible = false

	if config.AimAssistEnabled and aimHeld and selectedTarget then
		if not config.RequireLineOfSight or selectedTarget.visible then
			local cameraPosition = camera.CFrame.Position
			local goal = CFrame.lookAt(cameraPosition, selectedTarget.aimPoint, camera.CFrame.UpVector)
			local alpha = 1 - math.exp(-config.Smoothing * deltaTime)
			camera.CFrame = camera.CFrame:Lerp(goal, alpha)
		end
	end
end)

CollectionService:GetInstanceRemovedSignal(config.TargetTag):Connect(function(instance: Instance)
	if instance:IsA("Model") then
		destroyVisual(instance)
	end
end)

print("[Raw Training Lab] Ready. Tag NPC models with CollectionService tag 'TrainingTarget'.")
