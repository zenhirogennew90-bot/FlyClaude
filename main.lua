-- RGB Fly Hub v2 (LocalScript / loadstring compatible)
-- Fitur: Fly, Noclip, Airwalk, Anti Gelap (Fullbright), Slider Speed, Menu Scroll, Animasi Buka/Tutup
-- Key: F = fly | N = noclip | RightShift = buka/tutup menu | Space/Shift = naik/turun

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local old = player:WaitForChild("PlayerGui"):FindFirstChild("RGBHub")
if old then old:Destroy() end

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local speed = 60
local MIN_SPEED, MAX_SPEED = 10, 300
local up, down = false, false
local flying, noclip, airwalk = false, false, false
local bv, bg, airPart, platY

----------------------------------------------------------------
-- GUI dasar
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RGBHub"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local rgbStrokes = {} -- { stroke, offset }
local function addStroke(parent, thickness, offset)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	table.insert(rgbStrokes, { s, offset or 0 })
	return s
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
	return c
end

local FULL = UDim2.fromOffset(250, 330)
local CLOSED = UDim2.fromOffset(250, 0)

local main = Instance.new("Frame")
main.Size = CLOSED
main.Position = UDim2.new(0, 70, 0.25, 0)
main.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Visible = false
main.Parent = gui
corner(main, 14)
addStroke(main, 2.5, 0)

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -44, 1, 0)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "✦ RGB HUB ✦"
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header
local titleGrad = Instance.new("UIGradient", title)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = header
corner(closeBtn, 8)

-- Scroll area
local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(8, 46)
scroll.Size = UDim2.new(1, -16, 1, -54)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Parent = main

local list = Instance.new("UIListLayout", scroll)
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
local pad = Instance.new("UIPadding", scroll)
pad.PaddingTop = UDim.new(0, 4)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 2)

-- Tombol buka/tutup (melayang)
local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(46, 46)
openBtn.Position = UDim2.new(0, 12, 0.25, 0)
openBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
openBtn.Text = "☰"
openBtn.Font = Enum.Font.GothamBlack
openBtn.TextSize = 22
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Parent = gui
corner(openBtn, 23)
addStroke(openBtn, 2.5, 0.15)

----------------------------------------------------------------
-- Builder komponen
----------------------------------------------------------------
local order = 0
local function nextOrder() order += 1 return order end

local function addToggle(text, callback)
	local obj = { on = false }

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 38)
	b.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	b.Text = ""
	b.LayoutOrder = nextOrder()
	b.Parent = scroll
	corner(b, 10)
	addStroke(b, 1.5, nextOrder() * 0.07)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -70, 1, 0)
	lbl.Position = UDim2.fromOffset(12, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = b

	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(42, 20)
	pill.Position = UDim2.new(1, -52, 0.5, -10)
	pill.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	pill.Parent = b
	corner(pill, 10)

	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(16, 16)
	dot.Position = UDim2.fromOffset(2, 2)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.Parent = pill
	corner(dot, 8)

	function obj.set(v)
		obj.on = v
		TweenService:Create(dot, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Position = v and UDim2.fromOffset(24, 2) or UDim2.fromOffset(2, 2),
		}):Play()
		TweenService:Create(pill, TweenInfo.new(0.2), {
			BackgroundColor3 = v and Color3.fromRGB(70, 220, 120) or Color3.fromRGB(60, 60, 75),
		}):Play()
		callback(v)
	end

	b.MouseButton1Click:Connect(function() obj.set(not obj.on) end)
	return obj
end

-- Slider speed
local speedLabel, sliderFill, sliderKnob, sliderHit
do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	row.LayoutOrder = nextOrder()
	row.Parent = scroll
	corner(row, 10)
	addStroke(row, 1.5, 0.5)

	speedLabel = Instance.new("TextLabel")
	speedLabel.Size = UDim2.new(1, -24, 0, 22)
	speedLabel.Position = UDim2.fromOffset(12, 4)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.TextSize = 14
	speedLabel.TextColor3 = Color3.new(1, 1, 1)
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Parent = row

	sliderHit = Instance.new("Frame")
	sliderHit.Size = UDim2.new(1, -28, 0, 26)
	sliderHit.Position = UDim2.fromOffset(14, 26)
	sliderHit.BackgroundTransparency = 1
	sliderHit.Active = true
	sliderHit.Parent = row

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Position = UDim2.new(0, 0, 0.5, -3)
	bar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	bar.BorderSizePixel = 0
	bar.Parent = sliderHit
	corner(bar, 3)

	sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.fromScale(0, 1)
	sliderFill.BorderSizePixel = 0
	sliderFill.BackgroundColor3 = Color3.new(1, 1, 1)
	sliderFill.Parent = bar
	corner(sliderFill, 3)
	local fg = Instance.new("UIGradient", sliderFill)
	fg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 200, 255)),
	})

	sliderKnob = Instance.new("Frame")
	sliderKnob.Size = UDim2.fromOffset(16, 16)
	sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	sliderKnob.Position = UDim2.fromScale(0, 0.5)
	sliderKnob.BackgroundColor3 = Color3.new(1, 1, 1)
	sliderKnob.Parent = sliderHit
	corner(sliderKnob, 8)
end

local function refreshSlider()
	local rel = (speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED)
	sliderFill.Size = UDim2.fromScale(rel, 1)
	sliderKnob.Position = UDim2.fromScale(rel, 0.5)
	speedLabel.Text = "Speed: " .. speed
end
refreshSlider()

do
	local dragging = false
	local function setFromX(x)
		local rel = math.clamp((x - sliderHit.AbsolutePosition.X) / sliderHit.AbsoluteSize.X, 0, 1)
		speed = math.floor(MIN_SPEED + rel * (MAX_SPEED - MIN_SPEED))
		refreshSlider()
	end
	sliderHit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			scroll.ScrollingEnabled = false
			setFromX(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			setFromX(i.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			scroll.ScrollingEnabled = true
		end
	end)
end

-- Tombol naik/turun (HP)
do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder()
	row.Parent = scroll

	local function mk(text, xScale, xOff, setter)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.5, -4, 1, 0)
		b.Position = UDim2.new(xScale, xOff, 0, 0)
		b.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
		b.Text = text
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = row
		corner(b, 10)
		addStroke(b, 1.5, xScale + 0.6)
		b.MouseButton1Down:Connect(function() setter(true) end)
		b.MouseButton1Up:Connect(function() setter(false) end)
		b.MouseLeave:Connect(function() setter(false) end)
	end
	mk("▲ UP", 0, 0, function(v) up = v end)
	mk("▼ DOWN", 0.5, 4, function(v) down = v end)
end

----------------------------------------------------------------
-- Fitur: Fly
----------------------------------------------------------------
local function getChar()
	local c = player.Character
	return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local flyToggle
flyToggle = addToggle("Fly", function(on)
	local _, root, hum = getChar()
	if on then
		if not (root and hum) then flying = false return end
		flying = true
		hum.PlatformStand = true
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Velocity = Vector3.zero
		bv.Parent = root
		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
		bg.P = 9e3
		bg.CFrame = root.CFrame
		bg.Parent = root
	else
		flying = false
		if bv then bv:Destroy() bv = nil end
		if bg then bg:Destroy() bg = nil end
		if hum then hum.PlatformStand = false end
	end
end)

----------------------------------------------------------------
-- Fitur: Noclip
----------------------------------------------------------------
local noclipToggle = addToggle("Noclip", function(on) noclip = on end)

RunService.Stepped:Connect(function()
	if not noclip then return end
	local char = player.Character
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			p.CanCollide = false
		end
	end
end)

----------------------------------------------------------------
-- Fitur: Airwalk
----------------------------------------------------------------
local function destroyAir()
	if airPart then airPart:Destroy() airPart = nil end
end

addToggle("Airwalk", function(on)
	airwalk = on
	if on then
		local _, root, hum = getChar()
		if not (root and hum) then airwalk = false return end
		airPart = Instance.new("Part")
		airPart.Name = "AirwalkPlatform"
		airPart.Size = Vector3.new(7, 1, 7)
		airPart.Anchored = true
		airPart.CanCollide = true
		airPart.Material = Enum.Material.Neon
		airPart.Transparency = 0.45
		airPart.TopSurface = Enum.SurfaceType.Smooth
		airPart.BottomSurface = Enum.SurfaceType.Smooth
		airPart.Parent = workspace
		local feet = (hum.RigType == Enum.HumanoidRigType.R15) and (hum.HipHeight + root.Size.Y / 2) or 3
		platY = root.Position.Y - feet - airPart.Size.Y / 2
	else
		destroyAir()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not airwalk then return end
	local _, root = getChar()
	if not root then return end
	if not airPart then return end
	if up then platY += 25 * dt end
	if down then platY -= 25 * dt end
	airPart.CFrame = CFrame.new(root.Position.X, platY, root.Position.Z)
	airPart.Color = Color3.fromHSV((tick() * 0.25) % 1, 1, 1)
end)

----------------------------------------------------------------
-- Fitur: Anti Gelap (Fullbright)
----------------------------------------------------------------
local saved
addToggle("Anti Gelap", function(on)
	if on then
		saved = {
			Brightness = Lighting.Brightness,
			ClockTime = Lighting.ClockTime,
			FogEnd = Lighting.FogEnd,
			GlobalShadows = Lighting.GlobalShadows,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
		}
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
		Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
	elseif saved then
		for k, v in pairs(saved) do Lighting[k] = v end
	end
end)

----------------------------------------------------------------
-- Gerakan fly
----------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	if not flying then return end
	local _, root, hum = getChar()
	if not (root and hum and bv and bg) then return end

	local cf = camera.CFrame
	local md = hum.MoveDirection
	local fl = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local fr = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	fl = fl.Magnitude > 0 and fl.Unit or Vector3.zero
	fr = fr.Magnitude > 0 and fr.Unit or Vector3.zero

	local dir = cf.LookVector * md:Dot(fl) + cf.RightVector * md:Dot(fr)
	if up then dir += Vector3.yAxis end
	if down then dir -= Vector3.yAxis end

	bv.Velocity = dir * speed
	bg.CFrame = cf
end)

----------------------------------------------------------------
-- Animasi buka/tutup + drag
----------------------------------------------------------------
local isOpen = false
local function setOpen(v)
	isOpen = v
	if v then
		main.Visible = true
		main.Size = CLOSED
		TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = FULL }):Play()
		TweenService:Create(openBtn, TweenInfo.new(0.3), { Rotation = 90 }):Play()
	else
		local t = TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = CLOSED })
		t.Completed:Connect(function()
			if not isOpen then main.Visible = false end
		end)
		t:Play()
		TweenService:Create(openBtn, TweenInfo.new(0.3), { Rotation = 0 }):Play()
	end
end

openBtn.MouseButton1Click:Connect(function() setOpen(not isOpen) end)
closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)

do
	local dragging, dragStart, startPos
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, main.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

----------------------------------------------------------------
-- Keybind
----------------------------------------------------------------
UIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	local k = i.KeyCode
	if k == Enum.KeyCode.F then flyToggle.set(not flyToggle.on)
	elseif k == Enum.KeyCode.N then noclipToggle.set(not noclipToggle.on)
	elseif k == Enum.KeyCode.RightShift then setOpen(not isOpen)
	elseif k == Enum.KeyCode.Space then up = true
	elseif k == Enum.KeyCode.LeftShift then down = true end
end)
UIS.InputEnded:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.Space then up = false
	elseif i.KeyCode == Enum.KeyCode.LeftShift then down = false end
end)

----------------------------------------------------------------
-- Animasi RGB
----------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local t = tick()
	local h = (t * 0.25) % 1
	for _, e in ipairs(rgbStrokes) do
		e[1].Color = Color3.fromHSV((h + e[2]) % 1, 1, 1)
	end
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(h, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromHSV((h + 0.33) % 1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV((h + 0.66) % 1, 1, 1)),
	})
	titleGrad.Rotation = (t * 90) % 360
	scroll.ScrollBarImageColor3 = Color3.fromHSV(h, 1, 1)
end)

----------------------------------------------------------------
-- Respawn
----------------------------------------------------------------
player.CharacterAdded:Connect(function()
	bv, bg = nil, nil
	flying = false
	if flyToggle.on then flyToggle.on = false flyToggle.set(false) end
end)

setOpen(true)
