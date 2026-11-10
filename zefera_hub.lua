-- ZeFera Hub v4 (LocalScript / loadstring compatible)
-- Fitur: Fly, Noclip, Airwalk, Speed Up, Anti Gelap, ESP (nama + jarak), Hitbox bulat,
--        Slider (fly/walk/hitbox/transparansi), Transparansi Menu, Menu 3 kolom landscape
-- Key: F = fly | N = noclip | RightShift = buka/tutup menu | Space/Shift = naik/turun

local __ok, __err = xpcall(function()

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local playerGui = player:WaitForChild("PlayerGui")
local guiParent = playerGui
do
	local ok, h = pcall(function() return (not (getgenv and getgenv().ZF_PLAYERGUI)) and gethui and gethui() end)
	if ok and typeof(h) == "Instance" then guiParent = h end
end
for _, p in ipairs({ playerGui, guiParent }) do
	local old = p:FindFirstChild("ZeFeraHub")
	if old then old:Destroy() end
end

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local flySpeed, walkSpeed = 60, 50
local up, down = false, false
local flying, noclip, airwalk, speedUp = false, false, false, false
local espOn = false
local hbOn, hbHide, hbSkipTeam = false, false, false
local hbSize, hbTrans = 12, 0.7
local bv, bg, airPart, platY, origWalk

----------------------------------------------------------------
-- GUI dasar
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ZeFeraHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = guiParent

local rgbStrokes = {}
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

-- Frame yang ikut diatur transparansinya
local panels = {}
local menuTrans = 0
local function registerPanel(f)
	table.insert(panels, f)
	f.BackgroundTransparency = menuTrans
end

local vp = camera.ViewportSize
local MENU_W = math.clamp(vp.X - 90, 380, 620)
local MENU_H = math.clamp(vp.Y - 40, 200, 250)
local FULL = UDim2.fromOffset(MENU_W, MENU_H)
local CLOSED = UDim2.fromOffset(MENU_W, 0)

local main = Instance.new("Frame")
main.Size = CLOSED
main.Position = UDim2.new(0, 70, 0.1, 0)
main.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Visible = false
main.Parent = gui
corner(main, 14)
addStroke(main, 2.5, 0)

local function applyMenuTransparency(t)
	menuTrans = t
	main.BackgroundTransparency = t
	for _, f in ipairs(panels) do f.BackgroundTransparency = t end
end

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -44, 1, 0)
title.Position = UDim2.fromOffset(14, 0)
title.BackgroundTransparency = 1
title.Text = "✦ ZEFERA HUB ✦"
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header
local titleGrad = Instance.new("UIGradient", title)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = header
corner(closeBtn, 8)

-- 3 kolom
local function makeColumn(index)
	local s = Instance.new("ScrollingFrame")
	s.Position = UDim2.new(index / 3, index == 0 and 10 or 4, 0, 44)
	s.Size = UDim2.new(1 / 3, -14, 1, -52)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 4
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.Parent = main
	local l = Instance.new("UIListLayout", s)
	l.Padding = UDim.new(0, 7)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	local p = Instance.new("UIPadding", s)
	p.PaddingTop = UDim.new(0, 2)
	p.PaddingBottom = UDim.new(0, 6)
	p.PaddingRight = UDim.new(0, 8)
	p.PaddingLeft = UDim.new(0, 2)
	return s
end

local colMove = makeColumn(0)
local colVisual = makeColumn(1)
local colSet = makeColumn(2)
local scrolls = { colMove, colVisual, colSet }

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(46, 46)
openBtn.Position = UDim2.new(0, 12, 0.1, 0)
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

local function addHeader(parent, text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 16)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamBold
	l.TextSize = 11
	l.TextColor3 = Color3.fromRGB(150, 150, 170)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.LayoutOrder = nextOrder()
	l.Parent = parent
end

local function addToggle(parent, text, callback)
	local obj = { on = false }

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	b.Text = ""
	b.LayoutOrder = nextOrder()
	b.Parent = parent
	corner(b, 10)
	addStroke(b, 1.5, order * 0.07)
	registerPanel(b)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -66, 1, 0)
	lbl.Position = UDim2.fromOffset(10, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = b

	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(40, 20)
	pill.Position = UDim2.new(1, -48, 0.5, -10)
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
			Position = v and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
		}):Play()
		TweenService:Create(pill, TweenInfo.new(0.2), {
			BackgroundColor3 = v and Color3.fromRGB(70, 220, 120) or Color3.fromRGB(60, 60, 75),
		}):Play()
		callback(v)
	end

	b.MouseButton1Click:Connect(function() obj.set(not obj.on) end)
	return obj
end

local function addSlider(parent, scrollFrame, labelText, min, max, initial, onChange, suffix)
	local value = initial
	suffix = suffix or ""

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	row.LayoutOrder = nextOrder()
	row.Parent = parent
	corner(row, 10)
	addStroke(row, 1.5, order * 0.07)
	registerPanel(row)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 0, 22)
	label.Position = UDim2.fromOffset(10, 3)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local hit = Instance.new("Frame")
	hit.Size = UDim2.new(1, -24, 0, 26)
	hit.Position = UDim2.fromOffset(12, 23)
	hit.BackgroundTransparency = 1
	hit.Active = true
	hit.Parent = row

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Position = UDim2.new(0, 0, 0.5, -3)
	bar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	bar.BorderSizePixel = 0
	bar.Parent = hit
	corner(bar, 3)

	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Parent = bar
	corner(fill, 3)
	local fg = Instance.new("UIGradient", fill)
	fg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 200, 255)),
	})

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(16, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = hit
	corner(knob, 8)

	local function refresh()
		local rel = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(rel, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		label.Text = labelText .. ": " .. value .. suffix
	end
	refresh()

	local dragging = false
	local function setFromX(x)
		local rel = math.clamp((x - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
		value = math.floor(min + rel * (max - min) + 0.5)
		refresh()
		onChange(value)
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			scrollFrame.ScrollingEnabled = false
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
			scrollFrame.ScrollingEnabled = true
		end
	end)
end

local function getChar()
	local c = player.Character
	return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

registerPanel(closeBtn)
registerPanel(openBtn)

----------------------------------------------------------------
-- KOLOM 1: GERAK
----------------------------------------------------------------
addHeader(colMove, "GERAK")

local flyToggle
flyToggle = addToggle(colMove, "Fly", function(on)
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

local noclipToggle = addToggle(colMove, "Noclip", function(on) noclip = on end)

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

local function destroyAir()
	if airPart then airPart:Destroy() airPart = nil end
end

local airToggle
airToggle = addToggle(colMove, "Airwalk", function(on)
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
	if not (airwalk and airPart) then return end
	local _, root = getChar()
	if not root then return end
	if up then platY += 25 * dt end
	if down then platY -= 25 * dt end
	airPart.CFrame = CFrame.new(root.Position.X, platY, root.Position.Z)
	airPart.Color = Color3.fromHSV((tick() * 0.25) % 1, 1, 1)
end)

addToggle(colMove, "Speed Up", function(on)
	speedUp = on
	local _, _, hum = getChar()
	if on then
		if hum then origWalk = hum.WalkSpeed end
	elseif hum and origWalk then
		hum.WalkSpeed = origWalk
	end
end)

RunService.Heartbeat:Connect(function()
	if not speedUp then return end
	local _, _, hum = getChar()
	if hum then hum.WalkSpeed = walkSpeed end
end)

local savedLight
addToggle(colMove, "Anti Gelap", function(on)
	if on then
		savedLight = {
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
	elseif savedLight then
		for k, v in pairs(savedLight) do Lighting[k] = v end
	end
end)

----------------------------------------------------------------
-- ESP (nama + jarak)
----------------------------------------------------------------
local espObjs = {}

local function escapeRich(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function clearEsp(plr)
	local e = espObjs[plr]
	if e then
		if e.gui then e.gui:Destroy() end
		if e.hl then e.hl:Destroy() end
		espObjs[plr] = nil
	end
end

local function buildEsp(plr)
	if plr == player then return end
	local char = plr.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if not head then return end
	clearEsp(plr)

	local bb = Instance.new("BillboardGui")
	bb.Name = "ESP_" .. plr.Name
	bb.Adornee = head
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(120, 34)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.MaxDistance = 5000
	bb.Parent = gui

	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	pill.BackgroundTransparency = 0.35
	pill.BorderSizePixel = 0
	pill.Parent = bb
	corner(pill, 8)
	local ps = Instance.new("UIStroke", pill)
	ps.Thickness = 1.5
	table.insert(rgbStrokes, { ps, 0.3 })

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 1, 0)
	label.Position = UDim2.fromOffset(4, 0)
	label.BackgroundTransparency = 1
	label.RichText = true
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = escapeRich(plr.DisplayName)
	label.Parent = pill

	local hl = Instance.new("Highlight")
	hl.Adornee = char
	hl.FillTransparency = 1
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = char

	espObjs[plr] = { gui = bb, hl = hl, label = label, ps = ps }
end

local function clearAllEsp()
	for plr in pairs(espObjs) do clearEsp(plr) end
end

local function rebuildAllEsp()
	for _, plr in ipairs(Players:GetPlayers()) do buildEsp(plr) end
end

addHeader(colVisual, "VISUAL & HITBOX")
addToggle(colVisual, "ESP Nama + Jarak", function(on)
	espOn = on
	if on then rebuildAllEsp() else clearAllEsp() end
end)

local function hookPlayer(plr)
	if plr == player then return end
	plr.CharacterAdded:Connect(function()
		if espOn then
			task.wait(0.3)
			buildEsp(plr)
		end
	end)
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)
Players.PlayerRemoving:Connect(clearEsp)

do
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not espOn then return end
		acc += dt
		if acc < 0.1 then return end
		acc = 0

		local _, myRoot = getChar()
		for plr, e in pairs(espObjs) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not root or not e.gui.Adornee or not e.gui.Adornee.Parent then
				clearEsp(plr)
				if char then task.defer(buildEsp, plr) end
			elseif myRoot then
				local d = math.floor((root.Position - myRoot.Position).Magnitude + 0.5)
				e.label.Text = string.format(
					'<b>%s</b>\n<font size="11" color="rgb(185,185,205)">%d m</font>',
					escapeRich(plr.DisplayName), d
				)
				e.hl.OutlineColor = e.ps.Color
			end
		end
	end)
end

----------------------------------------------------------------
-- Hitbox bulat
----------------------------------------------------------------
local hbSaved = setmetatable({}, { __mode = "k" })

local function restoreHb(part, s)
	if part and part.Parent then
		pcall(function()
			part.Size = s.Size
			part.Shape = s.Shape
			part.Transparency = s.Transparency
			part.CanCollide = s.CanCollide
			part.Material = s.Material
			part.Color = s.Color
		end)
	end
	hbSaved[part] = nil
end

local function restoreAllHb()
	for part, s in pairs(hbSaved) do restoreHb(part, s) end
end

addToggle(colVisual, "Hitbox Bulat", function(on)
	hbOn = on
	if not on then restoreAllHb() end
end)
addToggle(colVisual, "Sembunyikan Hitbox", function(on) hbHide = on end)
addToggle(colVisual, "Abaikan Tim", function(on) hbSkipTeam = on end)
addSlider(colVisual, colVisual, "Besar Hitbox", 2, 40, hbSize, function(v) hbSize = v end, " st")
addSlider(colVisual, colVisual, "Transparansi Hitbox", 0, 100, math.floor(hbTrans * 100), function(v) hbTrans = v / 100 end, "%")

RunService.Heartbeat:Connect(function()
	if not hbOn then
		if next(hbSaved) then restoreAllHb() end
		return
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				local skip = hbSkipTeam and player.Team ~= nil and plr.Team == player.Team
				if skip then
					if hbSaved[hrp] then restoreHb(hrp, hbSaved[hrp]) end
				else
					if not hbSaved[hrp] then
						local ok, shape = pcall(function() return hrp.Shape end)
						hbSaved[hrp] = {
							Size = hrp.Size,
							Shape = ok and shape or Enum.PartType.Block,
							Transparency = hrp.Transparency,
							CanCollide = hrp.CanCollide,
							Material = hrp.Material,
							Color = hrp.Color,
						}
					end
					hrp.Size = Vector3.new(hbSize, hbSize, hbSize)
					pcall(function() hrp.Shape = Enum.PartType.Ball end)
					hrp.CanCollide = false
					if hbHide then
						hrp.Transparency = 1
					else
						hrp.Transparency = hbTrans
						hrp.Material = Enum.Material.Neon
						hrp.Color = Color3.fromRGB(255, 60, 120)
					end
				end
			end
		end
	end
end)

----------------------------------------------------------------
-- KOLOM 3: PENGATURAN
----------------------------------------------------------------
addHeader(colSet, "PENGATURAN")
addSlider(colSet, colSet, "Fly Speed", 10, 300, flySpeed, function(v) flySpeed = v end)
addSlider(colSet, colSet, "Walk Speed", 16, 200, walkSpeed, function(v) walkSpeed = v end)
addSlider(colSet, colSet, "Transparansi Menu", 0, 80, 0, function(v) applyMenuTransparency(v / 100) end, "%")

do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder()
	row.Parent = colSet

	local function mk(text, xScale, xOff, setter)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.5, -4, 1, 0)
		b.Position = UDim2.new(xScale, xOff, 0, 0)
		b.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
		b.Text = text
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = row
		corner(b, 10)
		addStroke(b, 1.5, xScale + 0.6)
		registerPanel(b)
		b.MouseButton1Down:Connect(function() setter(true) end)
		b.MouseButton1Up:Connect(function() setter(false) end)
		b.MouseLeave:Connect(function() setter(false) end)
	end
	mk("▲ UP", 0, 0, function(v) up = v end)
	mk("▼ DOWN", 0.5, 4, function(v) down = v end)
end

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

	bv.Velocity = dir * flySpeed
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
		if e[1].Parent then
			e[1].Color = Color3.fromHSV((h + e[2]) % 1, 1, 1)
		end
	end
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(h, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromHSV((h + 0.33) % 1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV((h + 0.66) % 1, 1, 1)),
	})
	titleGrad.Rotation = (t * 90) % 360
	for _, s in ipairs(scrolls) do
		s.ScrollBarImageColor3 = Color3.fromHSV(h, 1, 1)
	end
end)

----------------------------------------------------------------
-- Respawn
----------------------------------------------------------------
player.CharacterAdded:Connect(function()
	bv, bg = nil, nil
	flying = false
	if flyToggle.on then flyToggle.on = false flyToggle.set(false) end
	if airToggle.on then airToggle.set(false) end
end)

setOpen(true)

end, function(e) return debug.traceback(tostring(e), 2) end)

if not __ok then
	warn("[ZeFera Hub] ERROR:\n" .. tostring(__err))
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "ZeFera Hub error",
			Text = tostring(__err):sub(1, 150),
			Duration = 10,
		})
	end)
end
