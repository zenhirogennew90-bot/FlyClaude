-- ZeFera Hub v4 (LocalScript / loadstring compatible)
-- Fitur: Fly, Noclip, Airwalk, NoClip+Airwalk, Speed Up, Jalan Dinding, Bunuh Diri, TP (acak / bawah kaki),
--        ESP + Target (maks 3), Hitbox + Zona, Sembunyikan Avatar + Skeleton ESP, Optimasi Aman/Ekstrem,
--        Popup pilihan sendiri, Suara klik, Config manual (CFG), Unload (DEL)
-- Key: F = fly | N = noclip | RightShift = buka/tutup menu | Space/Shift = naik/turun

local __ok, __err = xpcall(function()

if not game:IsLoaded() then game.Loaded:Wait() end

local conns = {}
local function track(c) table.insert(conns, c) return c end

local Players = game:GetService("Players")
local RunService = (function()
	local rs = game:GetService("RunService")
	local function wrap(sig)
		return { Connect = function(_, fn) return track(sig:Connect(fn)) end }
	end
	return { Heartbeat = wrap(rs.Heartbeat), RenderStepped = wrap(rs.RenderStepped), Stepped = wrap(rs.Stepped) }
end)()
local UIS = (function()
	local u = game:GetService("UserInputService")
	local function wrap(sig)
		return { Connect = function(_, fn) return track(sig:Connect(fn)) end }
	end
	return { InputBegan = wrap(u.InputBegan), InputChanged = wrap(u.InputChanged), InputEnded = wrap(u.InputEnded) }
end)()
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
pcall(function()
	local g = getgenv()
	if g.ZeFeraUnload then g.ZeFeraUnload() end
end)
for _, p in ipairs({ playerGui, guiParent }) do
	for _, n in ipairs({ "ZeFeraHub", "ZeFeraTint" }) do
		local old = p:FindFirstChild(n)
		if old then old:Destroy() end
	end
end

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local flySpeed, walkSpeed = 60, 50
local up, down = false, false
local flying, noclip, airwalk, speedUp = false, false, false, false
local flyLockOn, flyLockCF = false, nil
local espOn = false
local hbOn, hbHide, hbSkipTeam = false, false, false
local hbSize, hbTrans = 12, 0.7
local hbRgb, tintOn, tintStrength = false, true, 45
local wallOn, wallN, wallFacing, wallSpeed = false, Vector3.yAxis, Vector3.zAxis, 24
local tpDepth = 8
local targets, targetEspOn = {}, false
local avatarHideOn, skelOn = false, false
local clickOn, clickVol = true, 0.6
local isOpen = false
local unloadHub, toggleCfg
local targetEspToggle, avatarToggle, skelToggle, skelFolder, gfxToggle, xToggle
local bv, bg, airPart, platY, origWalk

----------------------------------------------------------------
-- GUI dasar
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ZeFeraHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = guiParent

-- Overlay warna layar (saat masuk area hitbox)
local tintGui = Instance.new("ScreenGui")
tintGui.Name = "ZeFeraTint"
tintGui.ResetOnSpawn = false
tintGui.IgnoreGuiInset = true
tintGui.DisplayOrder = 500
tintGui.Parent = guiParent

local tint = Instance.new("Frame")
tint.Size = UDim2.fromScale(1, 1)
tint.BackgroundTransparency = 1
tint.BorderSizePixel = 0
tint.Active = false
tint.Parent = tintGui

local tintTarget, tintColor = 1, Color3.new(1, 1, 1)
RunService.RenderStepped:Connect(function(dt)
	tint.BackgroundColor3 = tintColor
	local a = tint.BackgroundTransparency
	tint.BackgroundTransparency = a + (tintTarget - a) * math.min(1, dt * 10)
end)

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

local function toast(text)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromOffset(250, 30)
	t.Position = UDim2.new(0.5, -125, 0, 12)
	t.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	t.BackgroundTransparency = 0.2
	t.Text = text
	t.Font = Enum.Font.GothamBold
	t.TextSize = 13
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = gui
	corner(t, 10)
	local st = Instance.new("UIStroke", t)
	st.Thickness = 1
	st.Transparency = 0.5
	task.delay(1.8, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		t:Destroy()
	end)
end

-- Suara klik lucu: 3 efek bawaan Roblox dengan nada acak (pop / boing / cicit)
local SoundService = game:GetService("SoundService")
local clickSounds = {}
for _, id in ipairs({
	"rbxasset://sounds/clickfast.wav",
	"rbxasset://sounds/button.wav",
	"rbxasset://sounds/electronicpingshort.wav",
}) do
	local snd = Instance.new("Sound")
	snd.SoundId = id
	snd.Volume = clickVol
	snd.Parent = SoundService
	table.insert(clickSounds, snd)
end
local function playClick()
	if not clickOn then return end
	local snd = clickSounds[math.random(1, #clickSounds)]
	snd.Volume = clickVol
	snd.PlaybackSpeed = 0.7 + math.random() * 1.6
	snd:Play()
end

local vp = camera.ViewportSize
local MENU_W = math.clamp(vp.X - 90, 380, 620)
local MENU_H = math.clamp(vp.Y - 40, 220, 280)
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
title.Text = "ZEFERA HUB"
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
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = header
corner(closeBtn, 8)

local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.fromOffset(34, 28)
unloadBtn.Position = UDim2.new(1, -76, 0, 6)
unloadBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 45)
unloadBtn.Text = "DEL"
unloadBtn.Font = Enum.Font.GothamBold
unloadBtn.TextSize = 11
unloadBtn.TextColor3 = Color3.new(1, 1, 1)
unloadBtn.Parent = header
corner(unloadBtn, 8)
do
	local armed = false
	unloadBtn.MouseButton1Click:Connect(function()
		if armed then
			if unloadHub then unloadHub() end
			return
		end
		armed = true
		unloadBtn.Text = "OK?"
		task.delay(2, function()
			armed = false
			if unloadBtn.Parent then unloadBtn.Text = "DEL" end
		end)
	end)
end

local cfgBtn = Instance.new("TextButton")
cfgBtn.Size = UDim2.fromOffset(34, 28)
cfgBtn.Position = UDim2.new(1, -114, 0, 6)
cfgBtn.BackgroundColor3 = Color3.fromRGB(40, 70, 140)
cfgBtn.Text = "CFG"
cfgBtn.Font = Enum.Font.GothamBold
cfgBtn.TextSize = 11
cfgBtn.TextColor3 = Color3.new(1, 1, 1)
cfgBtn.Parent = header
corner(cfgBtn, 8)
cfgBtn.MouseButton1Click:Connect(function() if toggleCfg then toggleCfg() end end)

-- Navigasi tab (kategori) + halaman, tiap halaman punya 2 kolom
local TAB_Y = 42
local tabBar = Instance.new("ScrollingFrame")
tabBar.Position = UDim2.fromOffset(10, TAB_Y)
tabBar.Size = UDim2.new(1, -20, 0, 30)
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.ScrollBarThickness = 0
tabBar.CanvasSize = UDim2.new()
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.Parent = main
local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local pageHolder = Instance.new("Frame")
pageHolder.Position = UDim2.fromOffset(0, TAB_Y + 34)
pageHolder.Size = UDim2.new(1, 0, 1, -(TAB_Y + 34))
pageHolder.BackgroundTransparency = 1
pageHolder.ClipsDescendants = true
pageHolder.Parent = main

local scrolls = {}
local function makeColumn(parent, index)
	local s = Instance.new("ScrollingFrame")
	s.Position = UDim2.new(index / 2, index == 0 and 10 or 4, 0, 0)
	s.Size = UDim2.new(0.5, -14, 1, -6)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 4
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.Parent = parent
	local l = Instance.new("UIListLayout", s)
	l.Padding = UDim.new(0, 7)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	local p = Instance.new("UIPadding", s)
	p.PaddingTop = UDim.new(0, 2)
	p.PaddingBottom = UDim.new(0, 6)
	p.PaddingRight = UDim.new(0, 8)
	p.PaddingLeft = UDim.new(0, 2)
	table.insert(scrolls, s)
	return s
end

local tabs, pages = {}, {}
local currentTab = 0
local function showTab(i)
	if currentTab == i then return end
	currentTab = i
	for k, p in ipairs(pages) do
		if k == i then
			p.Visible = true
			p.Position = UDim2.fromOffset(18, 0)
			TweenService:Create(p, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
		else
			p.Visible = false
		end
		tabs[k].BackgroundColor3 = (k == i) and Color3.fromRGB(50, 90, 170) or Color3.fromRGB(26, 26, 36)
	end
end

local function addTab(label)
	local idx = #tabs + 1
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(94, 26)
	btn.LayoutOrder = idx
	btn.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	btn.Text = label
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextTruncate = Enum.TextTruncate.AtEnd
	btn.Parent = tabBar
	corner(btn, 9)
	addStroke(btn, 1.5, idx * 0.2)
	registerPanel(btn)

	local page = Instance.new("Frame")
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = pageHolder

	tabs[idx], pages[idx] = btn, page
	btn.MouseButton1Click:Connect(function() showTab(idx) end)
	return makeColumn(page, 0), makeColumn(page, 1)
end

local gA, gB = addTab("GERAK")
local tA, tB = addTab("TELEPORT")
local vA, vB = addTab("VISUAL")
local rA, rB = addTab("TARGET")
local aA, aB = addTab("AVATAR")
local oA, oB = addTab("OPTIMASI")
local pA, pB = addTab("POPUP")
local sA, sB = addTab("PENGATURAN")
showTab(1)

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(46, 46)
openBtn.Position = UDim2.new(0, 12, 0.1, 0)
openBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
openBtn.Text = "ZF"
openBtn.Font = Enum.Font.GothamBlack
openBtn.TextSize = 16
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Parent = gui
corner(openBtn, 23)
addStroke(openBtn, 2.5, 0.15)

----------------------------------------------------------------
-- Builder komponen
----------------------------------------------------------------
local toggleReg, sliderReg = {}, {}

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

local function addNote(parent, text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 11
	l.TextWrapped = true
	l.TextColor3 = Color3.fromRGB(150, 150, 170)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.LayoutOrder = nextOrder()
	l.Parent = parent
end

local function addToggle(parent, text, callback)
	local obj = { on = false }
	toggleReg[text] = obj

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
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
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

local function addButton(parent, text, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.LayoutOrder = nextOrder()
	b.Parent = parent
	corner(b, 10)
	addStroke(b, 1.5, order * 0.07)
	registerPanel(b)
	b.MouseButton1Click:Connect(callback)
	return b
end

local function addSlider(parent, scrollFrame, labelText, min, max, initial, onChange, suffix, typeMax)
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

	local box
	if typeMax then
		label.Size = UDim2.new(1, -84, 0, 22)
		box = Instance.new("TextBox")
		box.Size = UDim2.fromOffset(56, 20)
		box.Position = UDim2.new(1, -66, 0, 4)
		box.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
		box.Font = Enum.Font.GothamBold
		box.TextSize = 12
		box.TextColor3 = Color3.new(1, 1, 1)
		box.ClearTextOnFocus = true
		box.Text = tostring(value)
		box.Parent = row
		corner(box, 6)
	end

	local function refresh()
		local rel = math.clamp((value - min) / (max - min), 0, 1)
		fill.Size = UDim2.fromScale(rel, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		if box then
			label.Text = labelText
			box.Text = tostring(value)
		else
			label.Text = labelText .. ": " .. value .. suffix
		end
	end
	refresh()

	if box then
		box.FocusLost:Connect(function()
			local n = tonumber(box.Text)
			if n then
				value = math.clamp(math.floor(n + 0.5), min, typeMax)
				onChange(value)
			end
			refresh()
		end)
	end

	sliderReg[labelText] = {
		get = function() return value end,
		set = function(v)
			value = math.clamp(math.floor(v + 0.5), min, typeMax or max)
			refresh()
			onChange(value)
		end,
	}

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
addHeader(gA, "GERAK")

local flyToggle
flyToggle = addToggle(gA, "Fly", function(on)
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
		flyLockCF = nil
		bg.Parent = root
	else
		flying = false
		if bv then bv:Destroy() bv = nil end
		if bg then bg:Destroy() bg = nil end
		if hum then hum.PlatformStand = false end
	end
end)

addToggle(gA, "Fly Bebas Lihat", function(on) flyLockOn = on end)
local noclipToggle = addToggle(gA, "Noclip", function(on) noclip = on end)

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
airToggle = addToggle(gA, "Airwalk", function(on)
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

local comboToggle
comboToggle = addToggle(gA, "NoClip+Airwalk", function(on)
	if noclipToggle.on ~= on then noclipToggle.set(on) end
	if airToggle.on ~= on then airToggle.set(on) end
end)

local speedToggle = addToggle(gA, "Speed Up", function(on)
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

-- Jalan di dinding: kamera ikut permukaan, gerak & kamera halus, animasi jalan normal
addHeader(gB, "MOVEMENT+")
local wallRay = RaycastParams.new()
wallRay.FilterType = Enum.RaycastFilterType.Exclude
wallRay.RespectCanCollide = true

-- sensitivitas putar kamera (kalau arah terbalik, ubah tandanya jadi minus)
local WALL_SENS_TOUCH, WALL_SENS_MOUSE = 0.0055, 0.004
local wallS = { ns = Vector3.yAxis, up = Vector3.yAxis, look = Vector3.zAxis, dist = 12, dx = 0, dy = 0, touches = {}, rmb = false }

-- input analog bawaan Roblox (joystick: pelan = jalan, penuh = lari)
local wallControls
pcall(function()
	wallControls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 3)):GetControls()
end)
if wallControls and not wallControls.GetMoveVector then wallControls = nil end

local function rotBetween(a, b)
	local d = math.clamp(a:Dot(b), -1, 1)
	if d > 0.9999 then return CFrame.new() end
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-4 then return CFrame.new() end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end

local wallTracks = {}
local function wallAnimStop()
	for _, t in pairs(wallTracks) do
		pcall(function() t:Stop(0.1) end)
	end
	wallTracks = {}
end
local function wallAnimLoad(char, hum)
	wallAnimStop()
	local animate = char and char:FindFirstChild("Animate")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not (animate and animator) then return end
	local function load(folder, name, prio)
		local f = animate:FindFirstChild(folder)
		local a = f and (f:FindFirstChild(name) or f:FindFirstChildWhichIsA("Animation"))
		if not a then return nil end
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok and tr then
			tr.Priority = prio
			tr.Looped = true
			return tr
		end
	end
	wallTracks.walk = load("walk", "WalkAnim", Enum.AnimationPriority.Movement)
	wallTracks.idle = load("idle", "Animation1", Enum.AnimationPriority.Idle)
end

local suicideArmed = false
local function doSuicide()
	if not suicideArmed then
		suicideArmed = true
		toast("Tekan sekali lagi (2 dtk) untuk konfirmasi")
		task.delay(2, function() suicideArmed = false end)
		return
	end
	suicideArmed = false
	local char, _, hum = getChar()
	if hum then pcall(function() hum.Health = 0 end) end
	if char then pcall(function() char:BreakJoints() end) end
end
addButton(gB, "Bunuh Diri", doSuicide)

local savedLight
addHeader(oA, "PENCAHAYAAN")
local darkToggle = addToggle(oA, "Anti Gelap", function(on)
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

addNote(oA, "Terangkan area gelap (fullbright). Pengaturan cahaya asli dikembalikan saat dimatikan.")

----------------------------------------------------------------
-- TP Sayang Nyawa (teleport ke pemain acak) + tombol pintas
----------------------------------------------------------------
local function tpRandom()
	local _, root = getChar()
	if not root then return end
	local pool = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local c = plr.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then table.insert(pool, plr) end
		end
	end
	if #pool == 0 then
		toast("Tidak ada pemain lain")
		return
	end
	local plr = pool[math.random(1, #pool)]
	local target = plr.Character.HumanoidRootPart
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = target.CFrame * CFrame.new(math.random(-3, 3), 0, 5)
	toast("TP ke " .. plr.DisplayName)
end

local function livePlayers(list)
	local out = {}
	for _, plr in ipairs(list) do
		if plr ~= player then
			local c = plr.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then table.insert(out, plr) end
		end
	end
	return out
end

-- TP tepat di bawah kaki pemain (target terpilih, kalau kosong acak), jarak vertikal diatur slider
local function tpUnder()
	local _, root = getChar()
	if not root then return end
	local pool = livePlayers(#targets > 0 and targets or Players:GetPlayers())
	if #pool == 0 then
		toast("Target tidak ditemukan")
		return
	end
	local plr = pool[math.random(1, #pool)]
	local tr = plr.Character.HumanoidRootPart
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(tr.Position.X, tr.Position.Y - 3 - tpDepth, tr.Position.Z)
	toast("TP bawah kaki " .. plr.DisplayName)
end

addHeader(tA, "TP PEMAIN")
addButton(tA, "TP Sayang Nyawa", tpRandom)
addButton(tA, "TP Bawah Kaki", tpUnder)
addSlider(tA, tA, "Jarak Vertikal", 1, 100, tpDepth, function(v) tpDepth = v end, " st", 500)
addNote(tA, "TP Bawah Kaki memakai target dari tab TARGET (kalau kosong: acak). Aktifkan NoClip+Airwalk dulu supaya tidak jatuh ke bawah.")

-- Tombol pintas melayang (bisa di-drag, bisa dikunci)
local tpLocked = false
local tpBtn = Instance.new("TextButton")
tpBtn.Name = "TPShortcut"
tpBtn.Size = UDim2.fromOffset(54, 54)
tpBtn.Position = UDim2.new(1, -150, 0.5, -27)
tpBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
tpBtn.Text = "TP"
tpBtn.Font = Enum.Font.GothamBlack
tpBtn.TextSize = 16
tpBtn.TextColor3 = Color3.new(1, 1, 1)
tpBtn.Parent = gui
corner(tpBtn, 27)
addStroke(tpBtn, 2.5, 0.5)

do
	local dragStart, startPos, moved
	tpBtn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			moved = false
			if not tpLocked then dragStart, startPos = i.Position, tpBtn.Position end
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragStart and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			if d.Magnitude > 8 then moved = true end
			if moved then
				tpBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragStart = nil
		end
	end)
	tpBtn.MouseButton1Click:Connect(function()
		if not moved then tpRandom() end
	end)
end

addHeader(pB, "KUNCI POP-UP")
tpBtn.Visible = false
addToggle(pB, "Kunci Pop-up", function(on)
	tpLocked = on
	toast(on and "Semua pop-up dikunci" or "Pop-up dibuka")
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

local function isTarget(plr)
	for _, t in ipairs(targets) do
		if t == plr then return true end
	end
	return false
end

local function espWanted(plr)
	return plr ~= player and (espOn or (targetEspOn and isTarget(plr)))
end

local function refreshEsp()
	for _, plr in ipairs(Players:GetPlayers()) do
		if espWanted(plr) then
			if not espObjs[plr] then buildEsp(plr) end
		else
			clearEsp(plr)
		end
	end
end

addHeader(vA, "ESP & HITBOX")
local espToggle = addToggle(vA, "ESP Nama + Jarak", function(on)
	espOn = on
	refreshEsp()
end)

local function hookPlayer(plr)
	if plr == player then return end
	track(plr.CharacterAdded:Connect(function()
		if espWanted(plr) then
			task.wait(0.3)
			buildEsp(plr)
		end
	end))
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
track(Players.PlayerAdded:Connect(hookPlayer))
track(Players.PlayerRemoving:Connect(clearEsp))

do
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not (espOn or targetEspOn) then return end
		acc += dt
		if acc < 0.1 then return end
		acc = 0

		local _, myRoot = getChar()
		for plr, e in pairs(espObjs) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not espWanted(plr) then
				clearEsp(plr)
			elseif not root or not e.gui.Adornee or not e.gui.Adornee.Parent then
				clearEsp(plr)
				if char and espWanted(plr) then task.defer(buildEsp, plr) end
			elseif myRoot then
				local d = math.floor((root.Position - myRoot.Position).Magnitude + 0.5)
				local nameCol = isTarget(plr) and "rgb(255,215,90)" or "rgb(255,255,255)"
				e.label.Text = string.format(
					'<font color="%s"><b>%s</b></font>\n<font size="11" color="rgb(185,185,205)">%d m</font>',
					nameCol, escapeRich(plr.DisplayName), d
				)
				e.hl.OutlineColor = e.ps.Color
			end
		end
	end)
end

----------------------------------------------------------------
-- TARGET: cari & pilih maks 3 player untuk ESP target
----------------------------------------------------------------
do
local MAX_TARGETS = 3
addHeader(rA, "CARI PLAYER")

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, 0, 0, 34)
searchBox.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
searchBox.Font = Enum.Font.GothamBold
searchBox.TextSize = 13
searchBox.TextColor3 = Color3.new(1, 1, 1)
searchBox.PlaceholderText = "Cari username / display name"
searchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 150)
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.LayoutOrder = nextOrder()
searchBox.Parent = rA
corner(searchBox, 10)
addStroke(searchBox, 1.5, 0.2)
registerPanel(searchBox)

local function makeListFrame(parent)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 1
	f.LayoutOrder = nextOrder()
	f.Parent = parent
	local l = Instance.new("UIListLayout", f)
	l.Padding = UDim.new(0, 5)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	return f
end

local function listButton(parent, text, color, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 28)
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = parent
	corner(b, 8)
	b.MouseButton1Click:Connect(cb)
	return b
end

local function clearList(f)
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function listLabel(parent, text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 22)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 11
	l.TextColor3 = Color3.fromRGB(150, 150, 170)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
end

local resultsFrame = makeListFrame(rA)
addHeader(rB, "TARGET TERPILIH")
local targetsFrame = makeListFrame(rB)

local refreshResults
local function refreshTargets()
	for i = #targets, 1, -1 do
		if not targets[i].Parent then table.remove(targets, i) end
	end
	clearList(targetsFrame)
	if #targets == 0 then
		listLabel(targetsFrame, "Belum ada target (maks " .. MAX_TARGETS .. ")")
	end
	for _, plr in ipairs(targets) do
		listButton(targetsFrame, plr.DisplayName .. " (@" .. plr.Name .. ")  [x]", Color3.fromRGB(100, 40, 55), function()
			for i, t in ipairs(targets) do
				if t == plr then table.remove(targets, i) break end
			end
			refreshTargets()
		end)
	end
	refreshEsp()
	if refreshResults then refreshResults() end
end

refreshResults = function()
	clearList(resultsFrame)
	local q = string.lower(searchBox.Text)
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local hay = string.lower(plr.Name .. " " .. plr.DisplayName)
			if q == "" or string.find(hay, q, 1, true) then table.insert(list, plr) end
		end
	end
	table.sort(list, function(a, b) return string.lower(a.DisplayName) < string.lower(b.DisplayName) end)
	if #list == 0 then listLabel(resultsFrame, "Tidak ada hasil") end
	for i = 1, math.min(#list, 6) do
		local plr = list[i]
		local color = isTarget(plr) and Color3.fromRGB(40, 100, 60) or Color3.fromRGB(26, 26, 36)
		listButton(resultsFrame, plr.DisplayName .. " (@" .. plr.Name .. ")", color, function()
			if isTarget(plr) then
				for k, t in ipairs(targets) do
					if t == plr then table.remove(targets, k) break end
				end
			elseif #targets >= MAX_TARGETS then
				toast("Target penuh (maks " .. MAX_TARGETS .. ")")
				return
			else
				table.insert(targets, plr)
			end
			refreshTargets()
		end)
	end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function() refreshResults() end)
track(Players.PlayerAdded:Connect(function()
	task.wait(0.3)
	refreshResults()
end))
track(Players.PlayerRemoving:Connect(function()
	task.defer(refreshTargets)
end))

targetEspToggle = addToggle(rB, "ESP Target", function(on)
	targetEspOn = on
	refreshEsp()
end)
addNote(rB, "ESP target menampilkan nama (emas) + jarak hanya untuk target. Ketuk nama di hasil untuk memilih / membatalkan.")
refreshTargets()

----------------------------------------------------------------
-- AVATAR: sembunyikan avatar pemain lain + skeleton ESP
----------------------------------------------------------------
local avatarSaved = setmetatable({}, { __mode = "k" })
local skelObjs = {}
local skelOnlyTarget = false
skelFolder = Instance.new("Folder")
skelFolder.Name = "ZeFeraSkeleton"
skelFolder.Parent = camera

local R15_BONES = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local R6_BONES = {
	{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function hideAvatar(char)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name ~= "HumanoidRootPart" then
				if avatarSaved[d] == nil then avatarSaved[d] = d.Transparency end
				d.Transparency = 1
			end
		elseif d:IsA("Decal") or d:IsA("Texture") then
			if avatarSaved[d] == nil then avatarSaved[d] = d.Transparency end
			d.Transparency = 1
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and avatarSaved[hum] == nil then
		avatarSaved[hum] = hum.DisplayDistanceType
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function restoreAvatars()
	for inst, v in pairs(avatarSaved) do
		pcall(function()
			if inst:IsA("Humanoid") then inst.DisplayDistanceType = v else inst.Transparency = v end
		end)
		avatarSaved[inst] = nil
	end
end

local function clearSkeleton(plr)
	local sk = skelObjs[plr]
	if sk then
		for _, b in ipairs(sk.bones) do b.box:Destroy() end
		skelObjs[plr] = nil
	end
end

local function clearAllSkeletons()
	for plr in pairs(skelObjs) do clearSkeleton(plr) end
end

local function buildSkeleton(plr)
	clearSkeleton(plr)
	local char = plr.Character
	if not char then return end
	local list = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
	local bones = {}
	for _, pair in ipairs(list) do
		local pa, pb = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
		if pa and pb and pa:IsA("BasePart") and pb:IsA("BasePart") then
			local box = Instance.new("BoxHandleAdornment")
			box.Adornee = pa
			box.AlwaysOnTop = true
			box.ZIndex = 5
			box.Size = Vector3.new(0.14, 0.14, 0.5)
			box.Transparency = 0
			box.Color3 = Color3.new(1, 1, 1)
			box.Parent = skelFolder
			table.insert(bones, { a = pa, b = pb, box = box })
		end
	end
	skelObjs[plr] = { char = char, bones = bones }
end

local function skelWanted(plr)
	return skelOn and plr ~= player and (not skelOnlyTarget or isTarget(plr))
end

do
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 then return end
		acc = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local char = plr.Character
				if avatarHideOn and char then hideAvatar(char) end
				if skelWanted(plr) and char then
					local sk = skelObjs[plr]
					if not sk or sk.char ~= char then buildSkeleton(plr) end
				elseif skelObjs[plr] then
					clearSkeleton(plr)
				end
			end
		end
		for plr in pairs(skelObjs) do
			if not plr.Parent then clearSkeleton(plr) end
		end
	end)
end

RunService.RenderStepped:Connect(function()
	if not next(skelObjs) then return end
	local hue = Color3.fromHSV((tick() * 0.25) % 1, 1, 1)
	for _, sk in pairs(skelObjs) do
		for _, b in ipairs(sk.bones) do
			local pa, pb = b.a, b.b
			if pa.Parent and pb.Parent then
				local rel = pa.CFrame:PointToObjectSpace(pb.Position)
				local len = rel.Magnitude
				if len > 0.05 then
					local upv = (math.abs(rel.Y / len) > 0.98) and Vector3.xAxis or Vector3.yAxis
					b.box.Size = Vector3.new(0.14, 0.14, len)
					b.box.CFrame = CFrame.lookAt(rel / 2, rel, upv)
					b.box.Color3 = hue
				end
			end
		end
	end
end)

addHeader(aA, "AVATAR PLAYER LAIN")
avatarToggle = addToggle(aA, "Sembunyikan Avatar", function(on)
	avatarHideOn = on
	if not on then restoreAvatars() end
end)
skelToggle = addToggle(aA, "Skeleton ESP", function(on)
	skelOn = on
	if not on then clearAllSkeletons() end
end)
(aA, "Sembunyikan Avatar hanya berlaku di layarmu. Nyalakan Skeleton ESP bersamaan agar posisi pemain lain tetap terlihat sebagai rangka.")
addHeader(aB, "OPSI SKELETON")
addToggle(aB, "Skeleton Hanya Target", function(on) skelOnlyTarget = on end)
addNote(aB, "Kalau aktif, skeleton hanya muncul untuk target yang dipilih di tab TARGET.")
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

local hbToggle = addToggle(vA, "Hitbox Bulat", function(on)
	hbOn = on
	if not on then restoreAllHb() end
end)
addToggle(vA, "Sembunyikan Hitbox", function(on) hbHide = on end)
addToggle(vA, "Abaikan Tim", function(on) hbSkipTeam = on end)
addHeader(vB, "ZONA & UKURAN")
local tintToggle = addToggle(vB, "Zona Hitbox", function(on) tintOn = on end)
tintToggle.set(true)
addSlider(vB, vB, "Kekuatan Zona", 10, 90, tintStrength, function(v) tintStrength = v end, "%")
addSlider(vB, vB, "Besar Hitbox", 2, 350, hbSize, function(v) hbSize = v end, " st")
addSlider(vB, vB, "Transparansi Hitbox", 0, 100, math.floor(hbTrans * 100), function(v) hbTrans = v / 100 end, "%")

RunService.Heartbeat:Connect(function()
	if not hbOn then
		if next(hbSaved) then restoreAllHb() end
		tintTarget = 1
		return
	end
	local hbColor = hbRgb and Color3.fromHSV((tick() * 0.25) % 1, 1, 1) or Color3.fromRGB(255, 60, 120)
	local camPos = camera.CFrame.Position
	local insideColor = nil
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
						hrp.Color = hbColor
						if (hrp.Position - camPos).Magnitude < hbSize / 2 then insideColor = hbColor end
					end
				end
			end
		end
	end
	if insideColor and tintOn then
		tintTarget = 1 - tintStrength / 100
		tintColor = insideColor
	else
		tintTarget = 1
	end
end)

----------------------------------------------------------------
-- OPTIMASI
----------------------------------------------------------------
addHeader(oB, "PERFORMA")

do
-- Optimasi Aman: efek, kabut, bayangan. TEKSTUR & MATERIAL MAP TIDAK DIUBAH
local gfxOn = false
local gfxSaved = setmetatable({}, { __mode = "k" })
local gfxEnv, gfxTerr
local gfxConns = {}

local function gfxStrip(inst)
	local props
	if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("PostEffect")
		or inst:IsA("Clouds") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
		if inst.Enabled then
			props = { Enabled = true }
			inst.Enabled = false
		end
	elseif inst:IsA("Atmosphere") then
		props = { Density = inst.Density, Haze = inst.Haze }
		inst.Density = 0
		inst.Haze = 0
	elseif inst:IsA("BasePart") and not inst:IsA("Terrain") and inst.CastShadow and inst.Name ~= "HumanoidRootPart" then
		props = { CastShadow = true }
		inst.CastShadow = false
	end
	if props and not gfxSaved[inst] then gfxSaved[inst] = props end
end

local function gfxApply()
	gfxOn = true
	gfxEnv, gfxTerr = {}, {}
	local lightProps = { GlobalShadows = false, FogEnd = 1e6, FogStart = 1e6, ShadowSoftness = 0 }
	for k, v in pairs(lightProps) do
		pcall(function()
			gfxEnv[k] = Lighting[k]
			Lighting[k] = v
		end)
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local tp = { WaterWaveSize = 0, WaterWaveSpeed = 0, WaterReflectance = 0 }
		for k, v in pairs(tp) do
			pcall(function()
				gfxTerr[k] = terrain[k]
				terrain[k] = v
			end)
		end
	end
	for _, d in ipairs(Lighting:GetDescendants()) do pcall(gfxStrip, d) end
	table.insert(gfxConns, workspace.DescendantAdded:Connect(function(d) pcall(gfxStrip, d) end))
	table.insert(gfxConns, Lighting.DescendantAdded:Connect(function(d) pcall(gfxStrip, d) end))
	task.spawn(function()
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if not gfxOn then return end
			pcall(gfxStrip, d)
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

local function gfxRevert()
	gfxOn = false
	for _, c in ipairs(gfxConns) do c:Disconnect() end
	gfxConns = {}
	if gfxEnv then
		for k, v in pairs(gfxEnv) do pcall(function() Lighting[k] = v end) end
		gfxEnv = nil
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and gfxTerr then
		for k, v in pairs(gfxTerr) do pcall(function() terrain[k] = v end) end
	end
	gfxTerr = nil
	task.spawn(function()
		local n = 0
		for inst, props in pairs(gfxSaved) do
			pcall(function()
				for k, v in pairs(props) do inst[k] = v end
			end)
			gfxSaved[inst] = nil
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

gfxToggle = addToggle(oB, "Optimasi Aman", function(on)
	if on then gfxApply() else gfxRevert() end
end)
addNote(oB, "Hapus efek, partikel, kabut & bayangan agar FPS naik. Tekstur dan material map TIDAK diubah.")
end

do
-- Optimasi Ekstrem: tambahan, mengubah tampilan map (material polos, rumput terrain off, kualitas terendah)
local xOn = false
local xSaved = setmetatable({}, { __mode = "k" })
local xTerr, xQuality
local xConns = {}

local function xStrip(inst)
	if inst:IsA("BasePart") and not inst:IsA("Terrain") and inst.Name ~= "HumanoidRootPart"
		and inst.Name ~= "AirwalkPlatform"
		and not (inst.Parent and inst.Parent:FindFirstChildOfClass("Humanoid")) then
		if inst.Material ~= Enum.Material.SmoothPlastic and not xSaved[inst] then
			xSaved[inst] = inst.Material
			inst.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function xApply()
	xOn = true
	xTerr = {}
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		pcall(function()
			xTerr.Decoration = terrain.Decoration
			terrain.Decoration = false
		end)
	end
	pcall(function()
		local r = settings().Rendering
		xQuality = r.QualityLevel
		r.QualityLevel = Enum.QualityLevel.Level01
	end)
	table.insert(xConns, workspace.DescendantAdded:Connect(function(d) pcall(xStrip, d) end))
	task.spawn(function()
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if not xOn then return end
			pcall(xStrip, d)
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

local function xRevert()
	xOn = false
	for _, c in ipairs(xConns) do c:Disconnect() end
	xConns = {}
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and xTerr then
		for k, v in pairs(xTerr) do pcall(function() terrain[k] = v end) end
	end
	xTerr = nil
	if xQuality then
		pcall(function() settings().Rendering.QualityLevel = xQuality end)
		xQuality = nil
	end
	task.spawn(function()
		local n = 0
		for inst, mat in pairs(xSaved) do
			pcall(function() inst.Material = mat end)
			xSaved[inst] = nil
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

xToggle = addToggle(oB, "Optimasi Ekstrem", function(on)
	if on then xApply() else xRevert() end
end)
addNote(oB, "PERINGATAN: mengubah tampilan map (material jadi polos, rumput terrain off, kualitas terendah). Matikan untuk mengembalikan.")
end

----------------------------------------------------------------
-- POPUP: tombol melayang pilihan sendiri
----------------------------------------------------------------
local floats = {}
do
local floatSlots = {}

local function makeFloat(label, onClick, obj)
	local n = 1
	while floatSlots[n] do n += 1 end
	floatSlots[n] = true

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(50, 50)
	btn.Position = UDim2.new(1, -66 - math.floor((n - 1) / 6) * 58, 0.1, ((n - 1) % 6) * 56)
	btn.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	btn.Text = label
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 11
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextWrapped = true
	btn.Parent = gui
	corner(btn, 25)
	addStroke(btn, 2.5, (n * 0.13) % 1)

	local dragStart, startPos, moved
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			moved = false
			if not tpLocked then dragStart, startPos = i.Position, btn.Position end
		end
	end)
	local c1 = UIS.InputChanged:Connect(function(i)
		if dragStart and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			if d.Magnitude > 8 then moved = true end
			if moved then
				btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
	local c2 = UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragStart = nil
		end
	end)
	btn.MouseButton1Click:Connect(function()
		if not moved then onClick() end
	end)
	btn.Destroying:Connect(function()
		floatSlots[n] = nil
		pcall(function() c1:Disconnect() end)
		pcall(function() c2:Disconnect() end)
	end)

	table.insert(floats, { btn = btn, obj = obj })
	return btn
end

local function addPopup(parent, text, label, onClick, obj)
	local fl
	addToggle(parent, "Popup " .. text, function(on)
		if on then
			if not fl or not fl.Parent then fl = makeFloat(label, onClick, obj) end
		elseif fl then
			fl:Destroy()
			fl = nil
		end
	end)
end

addHeader(pA, "TOMBOL ON/OFF")
addPopup(pA, "Fly", "FLY", function() flyToggle.set(not flyToggle.on) end, flyToggle)
addPopup(pA, "Noclip", "NOCLIP", function() noclipToggle.set(not noclipToggle.on) end, noclipToggle)
addPopup(pA, "Airwalk", "AIR", function() airToggle.set(not airToggle.on) end, airToggle)
addPopup(pA, "NoClip+Airwalk", "NC+A", function() comboToggle.set(not comboToggle.on) end, comboToggle)
addPopup(pA, "Speed Up", "SPEED", function() speedToggle.set(not speedToggle.on) end, speedToggle)
addPopup(pA, "ESP", "ESP", function() espToggle.set(not espToggle.on) end, espToggle)
addPopup(pA, "ESP Target", "TARGET", function() targetEspToggle.set(not targetEspToggle.on) end, targetEspToggle)
addPopup(pA, "Hitbox", "HIT", function() hbToggle.set(not hbToggle.on) end, hbToggle)
addPopup(pA, "Hide Avatar", "AVA", function() avatarToggle.set(not avatarToggle.on) end, avatarToggle)
addPopup(pA, "Skeleton", "SKEL", function() skelToggle.set(not skelToggle.on) end, skelToggle)

addHeader(pB, "TOMBOL AKSI")
addPopup(pB, "TP Acak", "TP", tpRandom)
addPopup(pB, "TP Bawah Kaki", "TP\nBAWAH", tpUnder)
addPopup(pB, "Bunuh Diri", "DEAD", doSuicide)
addNote(pB, "Nyalakan 'Popup ...' untuk memunculkan tombol melayang. Geser untuk memindahkan. Kunci posisinya lewat 'Kunci Pop-up' di tab POPUP. Tombol ON/OFF berwarna hijau saat fiturnya aktif.")
end

----------------------------------------------------------------
-- PENGATURAN
----------------------------------------------------------------
addHeader(sA, "KECEPATAN")
addHeader(sB, "TAMPILAN MENU")
addSlider(sA, sA, "Fly Speed", 10, 300, flySpeed, function(v) flySpeed = v end, nil, 1000)
addSlider(sA, sA, "Walk Speed", 16, 200, walkSpeed, function(v) walkSpeed = v end, nil, 500)
addSlider(sB, sB, "Transparansi Menu", 0, 80, 0, function(v) applyMenuTransparency(v / 100) end, "%")
local maxW = math.max(420, math.floor(camera.ViewportSize.X - 20))
addSlider(sB, sB, "Lebar Menu", 360, maxW, math.min(MENU_W, maxW), function(v)
	MENU_W = v
	FULL = UDim2.fromOffset(MENU_W, MENU_H)
	CLOSED = UDim2.fromOffset(MENU_W, 0)
	if isOpen then
		TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = FULL }):Play()
	end
end, " px")

local soundToggle = addToggle(sB, "Suara Klik Lucu", function(on) clickOn = on end)
soundToggle.set(true)
addSlider(sB, sB, "Volume Klik", 0, 100, math.floor(clickVol * 100), function(v) clickVol = v / 100 end, "%")

do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder()
	row.Parent = sA

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
	mk("UP", 0, 0, function(v) up = v end)
	mk("DOWN", 0.5, 4, function(v) down = v end)
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
	if flyLockOn then
		flyLockCF = flyLockCF or root.CFrame.Rotation
		bg.CFrame = flyLockCF
	else
		flyLockCF = nil
		bg.CFrame = cf
	end
end)

----------------------------------------------------------------
-- Animasi buka/tutup + drag
----------------------------------------------------------------
local function setOpen(v)
	isOpen = v
	if v then
		main.Visible = true
		main.Size = CLOSED
		TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = FULL }):Play()
	else
		local t = TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = CLOSED })
		t.Completed:Connect(function()
			if not isOpen then main.Visible = false end
		end)
		t:Play()
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
	elseif k == Enum.KeyCode.T then tpRandom()
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
	for i = #floats, 1, -1 do
		local f = floats[i]
		if not f.btn.Parent then
			table.remove(floats, i)
		elseif f.obj then
			f.btn.BackgroundColor3 = f.obj.on and Color3.fromRGB(26, 90, 52) or Color3.fromRGB(14, 14, 20)
		end
	end
end)

----------------------------------------------------------------
-- Panel Config (simpan / muat manual, 3 slot) - jendela terpisah
----------------------------------------------------------------
do
local HttpService = game:GetService("HttpService")
local CFG_DIR = "ZeFera"
local function cfgPath(slot) return CFG_DIR .. "/slot" .. slot .. ".json" end

local function collectCfg()
	local data = { toggles = {}, sliders = {} }
	for k, t in pairs(toggleReg) do data.toggles[k] = t.on end
	for k, sl in pairs(sliderReg) do data.sliders[k] = sl.get() end
	local p = tpBtn.Position
	data.tp = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
	return data
end

local function applyCfg(data)
	if type(data) ~= "table" then return end
	for k, v in pairs(data.sliders or {}) do
		local sl = sliderReg[k]
		if sl and type(v) == "number" then sl.set(v) end
	end
	-- toggle: NoClip+Airwalk dulu supaya urutannya konsisten
	local keys = {}
	for k, v in pairs(data.toggles or {}) do
		if toggleReg[k] and type(v) == "boolean" then table.insert(keys, k) end
	end
	table.sort(keys, function(a, b)
		if a == "NoClip+Airwalk" then return b ~= a end
		if b == "NoClip+Airwalk" then return false end
		return a < b
	end)
	for _, k in ipairs(keys) do
		local t = toggleReg[k]
		local v = data.toggles[k]
		if t.on ~= v then t.set(v) end
	end
	if type(data.tp) == "table" and #data.tp == 4 then
		tpBtn.Position = UDim2.new(data.tp[1], data.tp[2], data.tp[3], data.tp[4])
	end
end

local cfgDefaults = collectCfg()

local function saveSlot(slot)
	if not (writefile and readfile and isfile) then
		return false, "Executor tidak mendukung simpan file"
	end
	pcall(function()
		if makefolder and not (isfolder and isfolder(CFG_DIR)) then makefolder(CFG_DIR) end
	end)
	local ok = pcall(function()
		writefile(cfgPath(slot), HttpService:JSONEncode(collectCfg()))
	end)
	if ok then return true, "Tersimpan di Slot " .. slot end
	return false, "Gagal menyimpan"
end

local function loadSlot(slot)
	if not (readfile and isfile) then
		return false, "Executor tidak mendukung baca file"
	end
	local path = cfgPath(slot)
	if not isfile(path) then return false, "Slot " .. slot .. " masih kosong" end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
	if not ok then return false, "File config rusak" end
	applyCfg(data)
	return true, "Slot " .. slot .. " dimuat"
end

local CFG_W, CFG_H = 250, 176
local cfgFrame = Instance.new("Frame")
cfgFrame.Size = UDim2.fromOffset(CFG_W, 0)
cfgFrame.Position = UDim2.new(0.5, -125, 0.3, 0)
cfgFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
cfgFrame.BorderSizePixel = 0
cfgFrame.ClipsDescendants = true
cfgFrame.Visible = false
cfgFrame.Parent = gui
corner(cfgFrame, 14)
addStroke(cfgFrame, 2.5, 0.5)
registerPanel(cfgFrame)

local cfgHeader = Instance.new("Frame")
cfgHeader.Size = UDim2.new(1, 0, 0, 36)
cfgHeader.BackgroundTransparency = 1
cfgHeader.Active = true
cfgHeader.Parent = cfgFrame

local cfgTitle = Instance.new("TextLabel")
cfgTitle.Size = UDim2.new(1, -50, 1, 0)
cfgTitle.Position = UDim2.fromOffset(12, 0)
cfgTitle.BackgroundTransparency = 1
cfgTitle.Text = "CONFIG"
cfgTitle.Font = Enum.Font.GothamBlack
cfgTitle.TextSize = 15
cfgTitle.TextColor3 = Color3.new(1, 1, 1)
cfgTitle.TextXAlignment = Enum.TextXAlignment.Left
cfgTitle.Parent = cfgHeader

local cfgClose = Instance.new("TextButton")
cfgClose.Size = UDim2.fromOffset(28, 26)
cfgClose.Position = UDim2.new(1, -36, 0, 5)
cfgClose.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
cfgClose.Text = "X"
cfgClose.Font = Enum.Font.GothamBold
cfgClose.TextSize = 14
cfgClose.TextColor3 = Color3.new(1, 1, 1)
cfgClose.Parent = cfgHeader
corner(cfgClose, 8)

local function cfgButton(text, x, y, w, h, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, h)
	b.Position = UDim2.fromOffset(x, y)
	b.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = cfgFrame
	corner(b, 10)
	addStroke(b, 1.5, x / 250)
	registerPanel(b)
	b.MouseButton1Click:Connect(cb)
	return b
end

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.fromOffset(230, 36)
statusLbl.Position = UDim2.fromOffset(10, 124)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.GothamMedium
statusLbl.TextSize = 12
statusLbl.TextWrapped = true
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextYAlignment = Enum.TextYAlignment.Top
statusLbl.TextColor3 = Color3.fromRGB(185, 185, 205)
statusLbl.Text = ""
statusLbl.Parent = cfgFrame

local COL_OK, COL_ERR, COL_INFO = Color3.fromRGB(90, 230, 130), Color3.fromRGB(255, 100, 110), Color3.fromRGB(185, 185, 205)
local function setStatus(text, color)
	statusLbl.Text = text
	statusLbl.TextColor3 = color or COL_INFO
end

local cfgSlot = 1
local slotBtns = {}
local function selectSlot(n)
	cfgSlot = n
	for i, b in ipairs(slotBtns) do
		b.BackgroundColor3 = (i == n) and Color3.fromRGB(50, 90, 170) or Color3.fromRGB(26, 26, 36)
	end
	local has = false
	if isfile then pcall(function() has = isfile(cfgPath(n)) end) end
	setStatus("Slot " .. n .. (has and ": ada config tersimpan" or ": masih kosong"), COL_INFO)
end

for i = 1, 3 do
	slotBtns[i] = cfgButton("Slot " .. i, 10 + (i - 1) * 78, 42, 74, 30, function() selectSlot(i) end)
end

cfgButton("Save", 10, 80, 74, 34, function()
	local ok, msg = saveSlot(cfgSlot)
	setStatus(msg, ok and COL_OK or COL_ERR)
end)
cfgButton("Load", 88, 80, 74, 34, function()
	local ok, msg = loadSlot(cfgSlot)
	setStatus(msg, ok and COL_OK or COL_ERR)
end)
cfgButton("Reset", 166, 80, 74, 34, function()
	applyCfg(cfgDefaults)
	setStatus("Pengaturan dikembalikan ke default", COL_OK)
end)

local cfgOpen = false
toggleCfg = function()
	cfgOpen = not cfgOpen
	if cfgOpen then
		cfgFrame.Visible = true
		cfgFrame.Size = UDim2.fromOffset(CFG_W, 0)
		TweenService:Create(cfgFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(CFG_W, CFG_H) }):Play()
		selectSlot(cfgSlot)
	else
		local t = TweenService:Create(cfgFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(CFG_W, 0) })
		t.Completed:Connect(function()
			if not cfgOpen then cfgFrame.Visible = false end
		end)
		t:Play()
	end
end
cfgClose.MouseButton1Click:Connect(function() if cfgOpen then toggleCfg() end end)

do
	local dragging, dragStart, startPos
	cfgHeader.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, cfgFrame.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			cfgFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

end

----------------------------------------------------------------
-- Respawn
----------------------------------------------------------------
track(player.CharacterAdded:Connect(function()
	bv, bg = nil, nil
	flying = false
	if flyToggle.on then flyToggle.on = false flyToggle.set(false) end
	if comboToggle.on then comboToggle.on = false comboToggle.set(false) end
	if airToggle.on then airToggle.set(false) end

end))

----------------------------------------------------------------
-- Unload (tombol DEL): matikan semua fitur, kembalikan kondisi, hapus menu
----------------------------------------------------------------
unloadHub = function()
	for _, t in ipairs({ comboToggle, flyToggle, noclipToggle, airToggle, speedToggle, darkToggle, espToggle, targetEspToggle, hbToggle, avatarToggle, skelToggle, gfxToggle, xToggle }) do
		if t.on then pcall(t.set, false) end
	end
	tintTarget = 1
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() tintGui:Destroy() end)
	pcall(function() skelFolder:Destroy() end)
	for _, snd in ipairs(clickSounds) do pcall(function() snd:Destroy() end) end
	pcall(function() gui:Destroy() end)
	pcall(function() getgenv().ZeFeraUnload = nil end)
end
pcall(function() getgenv().ZeFeraUnload = unloadHub end)

-- Suara klik untuk semua tombol (termasuk yang dibuat belakangan)
local function hookClick(d)
	if d:IsA("GuiButton") then d.MouseButton1Click:Connect(playClick) end
end
for _, d in ipairs(gui:GetDescendants()) do hookClick(d) end
gui.DescendantAdded:Connect(hookClick)

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
-- ZeFera Hub v4 (LocalScript / loadstring compatible)
-- Fitur: Fly, Noclip, Airwalk, NoClip+Airwalk, Speed Up, Jalan Dinding, Bunuh Diri, TP (acak / bawah kaki),
--        ESP + Target (maks 3), Hitbox + Zona, Sembunyikan Avatar + Skeleton ESP, Optimasi Aman/Ekstrem,
--        Popup pilihan sendiri, Suara klik, Config manual (CFG), Unload (DEL)
-- Key: F = fly | N = noclip | RightShift = buka/tutup menu | Space/Shift = naik/turun

local __ok, __err = xpcall(function()

if not game:IsLoaded() then game.Loaded:Wait() end

local conns = {}
local function track(c) table.insert(conns, c) return c end

local Players = game:GetService("Players")
local RunService = (function()
	local rs = game:GetService("RunService")
	local function wrap(sig)
		return { Connect = function(_, fn) return track(sig:Connect(fn)) end }
	end
	return { Heartbeat = wrap(rs.Heartbeat), RenderStepped = wrap(rs.RenderStepped), Stepped = wrap(rs.Stepped) }
end)()
local UIS = (function()
	local u = game:GetService("UserInputService")
	local function wrap(sig)
		return { Connect = function(_, fn) return track(sig:Connect(fn)) end }
	end
	return { InputBegan = wrap(u.InputBegan), InputChanged = wrap(u.InputChanged), InputEnded = wrap(u.InputEnded) }
end)()
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
pcall(function()
	local g = getgenv()
	if g.ZeFeraUnload then g.ZeFeraUnload() end
end)
for _, p in ipairs({ playerGui, guiParent }) do
	for _, n in ipairs({ "ZeFeraHub", "ZeFeraTint" }) do
		local old = p:FindFirstChild(n)
		if old then old:Destroy() end
	end
end

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local flySpeed, walkSpeed = 60, 50
local up, down = false, false
local flying, noclip, airwalk, speedUp = false, false, false, false
local flyLockOn, flyLockCF = false, nil
local espOn = false
local hbOn, hbHide, hbSkipTeam = false, false, false
local hbSize, hbTrans = 12, 0.7
local hbRgb, tintOn, tintStrength = false, true, 45
local wallOn, wallN, wallFacing, wallSpeed = false, Vector3.yAxis, Vector3.zAxis, 24
local tpDepth = 8
local targets, targetEspOn = {}, false
local avatarHideOn, skelOn = false, false
local clickOn, clickVol = true, 0.6
local isOpen = false
local unloadHub, toggleCfg
local targetEspToggle, avatarToggle, skelToggle, skelFolder, gfxToggle, xToggle
local bv, bg, airPart, platY, origWalk

----------------------------------------------------------------
-- GUI dasar
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ZeFeraHub"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = guiParent

-- Overlay warna layar (saat masuk area hitbox)
local tintGui = Instance.new("ScreenGui")
tintGui.Name = "ZeFeraTint"
tintGui.ResetOnSpawn = false
tintGui.IgnoreGuiInset = true
tintGui.DisplayOrder = 500
tintGui.Parent = guiParent

local tint = Instance.new("Frame")
tint.Size = UDim2.fromScale(1, 1)
tint.BackgroundTransparency = 1
tint.BorderSizePixel = 0
tint.Active = false
tint.Parent = tintGui

local tintTarget, tintColor = 1, Color3.new(1, 1, 1)
RunService.RenderStepped:Connect(function(dt)
	tint.BackgroundColor3 = tintColor
	local a = tint.BackgroundTransparency
	tint.BackgroundTransparency = a + (tintTarget - a) * math.min(1, dt * 10)
end)

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

local function toast(text)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromOffset(250, 30)
	t.Position = UDim2.new(0.5, -125, 0, 12)
	t.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	t.BackgroundTransparency = 0.2
	t.Text = text
	t.Font = Enum.Font.GothamBold
	t.TextSize = 13
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = gui
	corner(t, 10)
	local st = Instance.new("UIStroke", t)
	st.Thickness = 1
	st.Transparency = 0.5
	task.delay(1.8, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		t:Destroy()
	end)
end

-- Suara klik lucu: 3 efek bawaan Roblox dengan nada acak (pop / boing / cicit)
local SoundService = game:GetService("SoundService")
local clickSounds = {}
for _, id in ipairs({
	"rbxasset://sounds/clickfast.wav",
	"rbxasset://sounds/button.wav",
	"rbxasset://sounds/electronicpingshort.wav",
}) do
	local snd = Instance.new("Sound")
	snd.SoundId = id
	snd.Volume = clickVol
	snd.Parent = SoundService
	table.insert(clickSounds, snd)
end
local function playClick()
	if not clickOn then return end
	local snd = clickSounds[math.random(1, #clickSounds)]
	snd.Volume = clickVol
	snd.PlaybackSpeed = 0.7 + math.random() * 1.6
	snd:Play()
end

local vp = camera.ViewportSize
local MENU_W = math.clamp(vp.X - 90, 380, 620)
local MENU_H = math.clamp(vp.Y - 40, 220, 280)
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
title.Text = "ZEFERA HUB"
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
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = header
corner(closeBtn, 8)

local unloadBtn = Instance.new("TextButton")
unloadBtn.Size = UDim2.fromOffset(34, 28)
unloadBtn.Position = UDim2.new(1, -76, 0, 6)
unloadBtn.BackgroundColor3 = Color3.fromRGB(120, 30, 45)
unloadBtn.Text = "DEL"
unloadBtn.Font = Enum.Font.GothamBold
unloadBtn.TextSize = 11
unloadBtn.TextColor3 = Color3.new(1, 1, 1)
unloadBtn.Parent = header
corner(unloadBtn, 8)
do
	local armed = false
	unloadBtn.MouseButton1Click:Connect(function()
		if armed then
			if unloadHub then unloadHub() end
			return
		end
		armed = true
		unloadBtn.Text = "OK?"
		task.delay(2, function()
			armed = false
			if unloadBtn.Parent then unloadBtn.Text = "DEL" end
		end)
	end)
end

local cfgBtn = Instance.new("TextButton")
cfgBtn.Size = UDim2.fromOffset(34, 28)
cfgBtn.Position = UDim2.new(1, -114, 0, 6)
cfgBtn.BackgroundColor3 = Color3.fromRGB(40, 70, 140)
cfgBtn.Text = "CFG"
cfgBtn.Font = Enum.Font.GothamBold
cfgBtn.TextSize = 11
cfgBtn.TextColor3 = Color3.new(1, 1, 1)
cfgBtn.Parent = header
corner(cfgBtn, 8)
cfgBtn.MouseButton1Click:Connect(function() if toggleCfg then toggleCfg() end end)

-- Navigasi tab (kategori) + halaman, tiap halaman punya 2 kolom
local TAB_Y = 42
local tabBar = Instance.new("ScrollingFrame")
tabBar.Position = UDim2.fromOffset(10, TAB_Y)
tabBar.Size = UDim2.new(1, -20, 0, 30)
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.ScrollBarThickness = 0
tabBar.CanvasSize = UDim2.new()
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.Parent = main
local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local pageHolder = Instance.new("Frame")
pageHolder.Position = UDim2.fromOffset(0, TAB_Y + 34)
pageHolder.Size = UDim2.new(1, 0, 1, -(TAB_Y + 34))
pageHolder.BackgroundTransparency = 1
pageHolder.ClipsDescendants = true
pageHolder.Parent = main

local scrolls = {}
local function makeColumn(parent, index)
	local s = Instance.new("ScrollingFrame")
	s.Position = UDim2.new(index / 2, index == 0 and 10 or 4, 0, 0)
	s.Size = UDim2.new(0.5, -14, 1, -6)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 4
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.Parent = parent
	local l = Instance.new("UIListLayout", s)
	l.Padding = UDim.new(0, 7)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	local p = Instance.new("UIPadding", s)
	p.PaddingTop = UDim.new(0, 2)
	p.PaddingBottom = UDim.new(0, 6)
	p.PaddingRight = UDim.new(0, 8)
	p.PaddingLeft = UDim.new(0, 2)
	table.insert(scrolls, s)
	return s
end

local tabs, pages = {}, {}
local currentTab = 0
local function showTab(i)
	if currentTab == i then return end
	currentTab = i
	for k, p in ipairs(pages) do
		if k == i then
			p.Visible = true
			p.Position = UDim2.fromOffset(18, 0)
			TweenService:Create(p, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
		else
			p.Visible = false
		end
		tabs[k].BackgroundColor3 = (k == i) and Color3.fromRGB(50, 90, 170) or Color3.fromRGB(26, 26, 36)
	end
end

local function addTab(label)
	local idx = #tabs + 1
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(94, 26)
	btn.LayoutOrder = idx
	btn.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	btn.Text = label
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextTruncate = Enum.TextTruncate.AtEnd
	btn.Parent = tabBar
	corner(btn, 9)
	addStroke(btn, 1.5, idx * 0.2)
	registerPanel(btn)

	local page = Instance.new("Frame")
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = pageHolder

	tabs[idx], pages[idx] = btn, page
	btn.MouseButton1Click:Connect(function() showTab(idx) end)
	return makeColumn(page, 0), makeColumn(page, 1)
end

local gA, gB = addTab("GERAK")
local tA, tB = addTab("TELEPORT")
local vA, vB = addTab("VISUAL")
local rA, rB = addTab("TARGET")
local aA, aB = addTab("AVATAR")
local oA, oB = addTab("OPTIMASI")
local pA, pB = addTab("POPUP")
local sA, sB = addTab("PENGATURAN")
showTab(1)

local openBtn = Instance.new("TextButton")
openBtn.Size = UDim2.fromOffset(46, 46)
openBtn.Position = UDim2.new(0, 12, 0.1, 0)
openBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
openBtn.Text = "ZF"
openBtn.Font = Enum.Font.GothamBlack
openBtn.TextSize = 16
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Parent = gui
corner(openBtn, 23)
addStroke(openBtn, 2.5, 0.15)

----------------------------------------------------------------
-- Builder komponen
----------------------------------------------------------------
local toggleReg, sliderReg = {}, {}

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

local function addNote(parent, text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 11
	l.TextWrapped = true
	l.TextColor3 = Color3.fromRGB(150, 150, 170)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.LayoutOrder = nextOrder()
	l.Parent = parent
end

local function addToggle(parent, text, callback)
	local obj = { on = false }
	toggleReg[text] = obj

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
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
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

local function addButton(parent, text, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 34)
	b.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.LayoutOrder = nextOrder()
	b.Parent = parent
	corner(b, 10)
	addStroke(b, 1.5, order * 0.07)
	registerPanel(b)
	b.MouseButton1Click:Connect(callback)
	return b
end

local function addSlider(parent, scrollFrame, labelText, min, max, initial, onChange, suffix, typeMax)
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

	local box
	if typeMax then
		label.Size = UDim2.new(1, -84, 0, 22)
		box = Instance.new("TextBox")
		box.Size = UDim2.fromOffset(56, 20)
		box.Position = UDim2.new(1, -66, 0, 4)
		box.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
		box.Font = Enum.Font.GothamBold
		box.TextSize = 12
		box.TextColor3 = Color3.new(1, 1, 1)
		box.ClearTextOnFocus = true
		box.Text = tostring(value)
		box.Parent = row
		corner(box, 6)
	end

	local function refresh()
		local rel = math.clamp((value - min) / (max - min), 0, 1)
		fill.Size = UDim2.fromScale(rel, 1)
		knob.Position = UDim2.fromScale(rel, 0.5)
		if box then
			label.Text = labelText
			box.Text = tostring(value)
		else
			label.Text = labelText .. ": " .. value .. suffix
		end
	end
	refresh()

	if box then
		box.FocusLost:Connect(function()
			local n = tonumber(box.Text)
			if n then
				value = math.clamp(math.floor(n + 0.5), min, typeMax)
				onChange(value)
			end
			refresh()
		end)
	end

	sliderReg[labelText] = {
		get = function() return value end,
		set = function(v)
			value = math.clamp(math.floor(v + 0.5), min, typeMax or max)
			refresh()
			onChange(value)
		end,
	}

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
addHeader(gA, "GERAK")

local flyToggle
flyToggle = addToggle(gA, "Fly", function(on)
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
		flyLockCF = nil
		bg.Parent = root
	else
		flying = false
		if bv then bv:Destroy() bv = nil end
		if bg then bg:Destroy() bg = nil end
		if hum then hum.PlatformStand = false end
	end
end)

addToggle(gA, "Fly Bebas Lihat", function(on) flyLockOn = on end)
local noclipToggle = addToggle(gA, "Noclip", function(on) noclip = on end)

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
airToggle = addToggle(gA, "Airwalk", function(on)
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

local comboToggle
comboToggle = addToggle(gA, "NoClip+Airwalk", function(on)
	if noclipToggle.on ~= on then noclipToggle.set(on) end
	if airToggle.on ~= on then airToggle.set(on) end
end)

local speedToggle = addToggle(gA, "Speed Up", function(on)
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

-- Jalan di dinding: kamera ikut permukaan, gerak & kamera halus, animasi jalan normal
addHeader(gB, "MOVEMENT+")
local wallRay = RaycastParams.new()
wallRay.FilterType = Enum.RaycastFilterType.Exclude
wallRay.RespectCanCollide = true

-- sensitivitas putar kamera (kalau arah terbalik, ubah tandanya jadi minus)
local WALL_SENS_TOUCH, WALL_SENS_MOUSE = 0.0055, 0.004
local wallS = { ns = Vector3.yAxis, up = Vector3.yAxis, look = Vector3.zAxis, dist = 12, dx = 0, dy = 0, touches = {}, rmb = false }

-- input analog bawaan Roblox (joystick: pelan = jalan, penuh = lari)
local wallControls
pcall(function()
	wallControls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 3)):GetControls()
end)
if wallControls and not wallControls.GetMoveVector then wallControls = nil end

local function rotBetween(a, b)
	local d = math.clamp(a:Dot(b), -1, 1)
	if d > 0.9999 then return CFrame.new() end
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-4 then return CFrame.new() end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(d))
end

local wallTracks = {}
local function wallAnimStop()
	for _, t in pairs(wallTracks) do
		pcall(function() t:Stop(0.1) end)
	end
	wallTracks = {}
end
local function wallAnimLoad(char, hum)
	wallAnimStop()
	local animate = char and char:FindFirstChild("Animate")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not (animate and animator) then return end
	local function load(folder, name, prio)
		local f = animate:FindFirstChild(folder)
		local a = f and (f:FindFirstChild(name) or f:FindFirstChildWhichIsA("Animation"))
		if not a then return nil end
		local ok, tr = pcall(function() return animator:LoadAnimation(a) end)
		if ok and tr then
			tr.Priority = prio
			tr.Looped = true
			return tr
		end
	end
	wallTracks.walk = load("walk", "WalkAnim", Enum.AnimationPriority.Movement)
	wallTracks.idle = load("idle", "Animation1", Enum.AnimationPriority.Idle)
end

local suicideArmed = false
local function doSuicide()
	if not suicideArmed then
		suicideArmed = true
		toast("Tekan sekali lagi (2 dtk) untuk konfirmasi")
		task.delay(2, function() suicideArmed = false end)
		return
	end
	suicideArmed = false
	local char, _, hum = getChar()
	if hum then pcall(function() hum.Health = 0 end) end
	if char then pcall(function() char:BreakJoints() end) end
end
addButton(gB, "Bunuh Diri", doSuicide)

local savedLight
addHeader(oA, "PENCAHAYAAN")
local darkToggle = addToggle(oA, "Anti Gelap", function(on)
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

addNote(oA, "Terangkan area gelap (fullbright). Pengaturan cahaya asli dikembalikan saat dimatikan.")

----------------------------------------------------------------
-- TP Sayang Nyawa (teleport ke pemain acak) + tombol pintas
----------------------------------------------------------------
local function tpRandom()
	local _, root = getChar()
	if not root then return end
	local pool = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local c = plr.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then table.insert(pool, plr) end
		end
	end
	if #pool == 0 then
		toast("Tidak ada pemain lain")
		return
	end
	local plr = pool[math.random(1, #pool)]
	local target = plr.Character.HumanoidRootPart
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = target.CFrame * CFrame.new(math.random(-3, 3), 0, 5)
	toast("TP ke " .. plr.DisplayName)
end

local function livePlayers(list)
	local out = {}
	for _, plr in ipairs(list) do
		if plr ~= player then
			local c = plr.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if r and h and h.Health > 0 then table.insert(out, plr) end
		end
	end
	return out
end

-- TP tepat di bawah kaki pemain (target terpilih, kalau kosong acak), jarak vertikal diatur slider
local function tpUnder()
	local _, root = getChar()
	if not root then return end
	local pool = livePlayers(#targets > 0 and targets or Players:GetPlayers())
	if #pool == 0 then
		toast("Target tidak ditemukan")
		return
	end
	local plr = pool[math.random(1, #pool)]
	local tr = plr.Character.HumanoidRootPart
	root.AssemblyLinearVelocity = Vector3.zero
	root.CFrame = CFrame.new(tr.Position.X, tr.Position.Y - 3 - tpDepth, tr.Position.Z)
	toast("TP bawah kaki " .. plr.DisplayName)
end

addHeader(tA, "TP PEMAIN")
addButton(tA, "TP Sayang Nyawa", tpRandom)
addButton(tA, "TP Bawah Kaki", tpUnder)
addSlider(tA, tA, "Jarak Vertikal", 1, 100, tpDepth, function(v) tpDepth = v end, " st", 500)
addNote(tA, "TP Bawah Kaki memakai target dari tab TARGET (kalau kosong: acak). Aktifkan NoClip+Airwalk dulu supaya tidak jatuh ke bawah.")

-- Tombol pintas melayang (bisa di-drag, bisa dikunci)
local tpLocked = false
local tpBtn = Instance.new("TextButton")
tpBtn.Name = "TPShortcut"
tpBtn.Size = UDim2.fromOffset(54, 54)
tpBtn.Position = UDim2.new(1, -150, 0.5, -27)
tpBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
tpBtn.Text = "TP"
tpBtn.Font = Enum.Font.GothamBlack
tpBtn.TextSize = 16
tpBtn.TextColor3 = Color3.new(1, 1, 1)
tpBtn.Parent = gui
corner(tpBtn, 27)
addStroke(tpBtn, 2.5, 0.5)

do
	local dragStart, startPos, moved
	tpBtn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			moved = false
			if not tpLocked then dragStart, startPos = i.Position, tpBtn.Position end
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragStart and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			if d.Magnitude > 8 then moved = true end
			if moved then
				tpBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragStart = nil
		end
	end)
	tpBtn.MouseButton1Click:Connect(function()
		if not moved then tpRandom() end
	end)
end

addHeader(pB, "KUNCI POP-UP")
tpBtn.Visible = false
addToggle(pB, "Kunci Pop-up", function(on)
	tpLocked = on
	toast(on and "Semua pop-up dikunci" or "Pop-up dibuka")
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

local function isTarget(plr)
	for _, t in ipairs(targets) do
		if t == plr then return true end
	end
	return false
end

local function espWanted(plr)
	return plr ~= player and (espOn or (targetEspOn and isTarget(plr)))
end

local function refreshEsp()
	for _, plr in ipairs(Players:GetPlayers()) do
		if espWanted(plr) then
			if not espObjs[plr] then buildEsp(plr) end
		else
			clearEsp(plr)
		end
	end
end

addHeader(vA, "ESP & HITBOX")
local espToggle = addToggle(vA, "ESP Nama + Jarak", function(on)
	espOn = on
	refreshEsp()
end)

local function hookPlayer(plr)
	if plr == player then return end
	track(plr.CharacterAdded:Connect(function()
		if espWanted(plr) then
			task.wait(0.3)
			buildEsp(plr)
		end
	end))
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
track(Players.PlayerAdded:Connect(hookPlayer))
track(Players.PlayerRemoving:Connect(clearEsp))

do
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not (espOn or targetEspOn) then return end
		acc += dt
		if acc < 0.1 then return end
		acc = 0

		local _, myRoot = getChar()
		for plr, e in pairs(espObjs) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not espWanted(plr) then
				clearEsp(plr)
			elseif not root or not e.gui.Adornee or not e.gui.Adornee.Parent then
				clearEsp(plr)
				if char and espWanted(plr) then task.defer(buildEsp, plr) end
			elseif myRoot then
				local d = math.floor((root.Position - myRoot.Position).Magnitude + 0.5)
				local nameCol = isTarget(plr) and "rgb(255,215,90)" or "rgb(255,255,255)"
				e.label.Text = string.format(
					'<font color="%s"><b>%s</b></font>\n<font size="11" color="rgb(185,185,205)">%d m</font>',
					nameCol, escapeRich(plr.DisplayName), d
				)
				e.hl.OutlineColor = e.ps.Color
			end
		end
	end)
end

----------------------------------------------------------------
-- TARGET: cari & pilih maks 3 player untuk ESP target
----------------------------------------------------------------
do
local MAX_TARGETS = 3
addHeader(rA, "CARI PLAYER")

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, 0, 0, 34)
searchBox.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
searchBox.Font = Enum.Font.GothamBold
searchBox.TextSize = 13
searchBox.TextColor3 = Color3.new(1, 1, 1)
searchBox.PlaceholderText = "Cari username / display name"
searchBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 150)
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.LayoutOrder = nextOrder()
searchBox.Parent = rA
corner(searchBox, 10)
addStroke(searchBox, 1.5, 0.2)
registerPanel(searchBox)

local function makeListFrame(parent)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 1
	f.LayoutOrder = nextOrder()
	f.Parent = parent
	local l = Instance.new("UIListLayout", f)
	l.Padding = UDim.new(0, 5)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	return f
end

local function listButton(parent, text, color, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 28)
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = parent
	corner(b, 8)
	b.MouseButton1Click:Connect(cb)
	return b
end

local function clearList(f)
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function listLabel(parent, text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 22)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 11
	l.TextColor3 = Color3.fromRGB(150, 150, 170)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
end

local resultsFrame = makeListFrame(rA)
addHeader(rB, "TARGET TERPILIH")
local targetsFrame = makeListFrame(rB)

local refreshResults
local function refreshTargets()
	for i = #targets, 1, -1 do
		if not targets[i].Parent then table.remove(targets, i) end
	end
	clearList(targetsFrame)
	if #targets == 0 then
		listLabel(targetsFrame, "Belum ada target (maks " .. MAX_TARGETS .. ")")
	end
	for _, plr in ipairs(targets) do
		listButton(targetsFrame, plr.DisplayName .. " (@" .. plr.Name .. ")  [x]", Color3.fromRGB(100, 40, 55), function()
			for i, t in ipairs(targets) do
				if t == plr then table.remove(targets, i) break end
			end
			refreshTargets()
		end)
	end
	refreshEsp()
	if refreshResults then refreshResults() end
end

refreshResults = function()
	clearList(resultsFrame)
	local q = string.lower(searchBox.Text)
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local hay = string.lower(plr.Name .. " " .. plr.DisplayName)
			if q == "" or string.find(hay, q, 1, true) then table.insert(list, plr) end
		end
	end
	table.sort(list, function(a, b) return string.lower(a.DisplayName) < string.lower(b.DisplayName) end)
	if #list == 0 then listLabel(resultsFrame, "Tidak ada hasil") end
	for i = 1, math.min(#list, 6) do
		local plr = list[i]
		local color = isTarget(plr) and Color3.fromRGB(40, 100, 60) or Color3.fromRGB(26, 26, 36)
		listButton(resultsFrame, plr.DisplayName .. " (@" .. plr.Name .. ")", color, function()
			if isTarget(plr) then
				for k, t in ipairs(targets) do
					if t == plr then table.remove(targets, k) break end
				end
			elseif #targets >= MAX_TARGETS then
				toast("Target penuh (maks " .. MAX_TARGETS .. ")")
				return
			else
				table.insert(targets, plr)
			end
			refreshTargets()
		end)
	end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function() refreshResults() end)
track(Players.PlayerAdded:Connect(function()
	task.wait(0.3)
	refreshResults()
end))
track(Players.PlayerRemoving:Connect(function()
	task.defer(refreshTargets)
end))

targetEspToggle = addToggle(rB, "ESP Target", function(on)
	targetEspOn = on
	refreshEsp()
end)
addNote(rB, "ESP target menampilkan nama (emas) + jarak hanya untuk target. Ketuk nama di hasil untuk memilih / membatalkan.")
refreshTargets()

----------------------------------------------------------------
-- AVATAR: sembunyikan avatar pemain lain + skeleton ESP
----------------------------------------------------------------
local avatarSaved = setmetatable({}, { __mode = "k" })
local skelObjs = {}
local skelOnlyTarget = false
skelFolder = Instance.new("Folder")
skelFolder.Name = "ZeFeraSkeleton"
skelFolder.Parent = camera

local R15_BONES = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local R6_BONES = {
	{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local function hideAvatar(char)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name ~= "HumanoidRootPart" then
				if avatarSaved[d] == nil then avatarSaved[d] = d.Transparency end
				d.Transparency = 1
			end
		elseif d:IsA("Decal") or d:IsA("Texture") then
			if avatarSaved[d] == nil then avatarSaved[d] = d.Transparency end
			d.Transparency = 1
		end
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and avatarSaved[hum] == nil then
		avatarSaved[hum] = hum.DisplayDistanceType
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function restoreAvatars()
	for inst, v in pairs(avatarSaved) do
		pcall(function()
			if inst:IsA("Humanoid") then inst.DisplayDistanceType = v else inst.Transparency = v end
		end)
		avatarSaved[inst] = nil
	end
end

local function clearSkeleton(plr)
	local sk = skelObjs[plr]
	if sk then
		for _, b in ipairs(sk.bones) do b.box:Destroy() end
		skelObjs[plr] = nil
	end
end

local function clearAllSkeletons()
	for plr in pairs(skelObjs) do clearSkeleton(plr) end
end

local function buildSkeleton(plr)
	clearSkeleton(plr)
	local char = plr.Character
	if not char then return end
	local list = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
	local bones = {}
	for _, pair in ipairs(list) do
		local pa, pb = char:FindFirstChild(pair[1]), char:FindFirstChild(pair[2])
		if pa and pb and pa:IsA("BasePart") and pb:IsA("BasePart") then
			local box = Instance.new("BoxHandleAdornment")
			box.Adornee = pa
			box.AlwaysOnTop = true
			box.ZIndex = 5
			box.Size = Vector3.new(0.14, 0.14, 0.5)
			box.Transparency = 0
			box.Color3 = Color3.new(1, 1, 1)
			box.Parent = skelFolder
			table.insert(bones, { a = pa, b = pb, box = box })
		end
	end
	skelObjs[plr] = { char = char, bones = bones }
end

local function skelWanted(plr)
	return skelOn and plr ~= player and (not skelOnlyTarget or isTarget(plr))
end

do
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 then return end
		acc = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local char = plr.Character
				if avatarHideOn and char then hideAvatar(char) end
				if skelWanted(plr) and char then
					local sk = skelObjs[plr]
					if not sk or sk.char ~= char then buildSkeleton(plr) end
				elseif skelObjs[plr] then
					clearSkeleton(plr)
				end
			end
		end
		for plr in pairs(skelObjs) do
			if not plr.Parent then clearSkeleton(plr) end
		end
	end)
end

RunService.RenderStepped:Connect(function()
	if not next(skelObjs) then return end
	local hue = Color3.fromHSV((tick() * 0.25) % 1, 1, 1)
	for _, sk in pairs(skelObjs) do
		for _, b in ipairs(sk.bones) do
			local pa, pb = b.a, b.b
			if pa.Parent and pb.Parent then
				local rel = pa.CFrame:PointToObjectSpace(pb.Position)
				local len = rel.Magnitude
				if len > 0.05 then
					local upv = (math.abs(rel.Y / len) > 0.98) and Vector3.xAxis or Vector3.yAxis
					b.box.Size = Vector3.new(0.14, 0.14, len)
					b.box.CFrame = CFrame.lookAt(rel / 2, rel, upv)
					b.box.Color3 = hue
				end
			end
		end
	end
end)

addHeader(aA, "AVATAR PLAYER LAIN")
avatarToggle = addToggle(aA, "Sembunyikan Avatar", function(on)
	avatarHideOn = on
	if not on then restoreAvatars() end
end)
skelToggle = addToggle(aA, "Skeleton ESP", function(on)
	skelOn = on
	if not on then clearAllSkeletons() end
end)
addNote(aA, "Sembunyikan Avatar hanya berlaku di layarmu. Nyalakan Skeleton ESP bersamaan agar posisi pemain lain tetap terlihat sebagai rangka.")
addHeader(aB, "OPSI SKELETON")
addToggle(aB, "Skeleton Hanya Target", function(on) skelOnlyTarget = on end)
addNote(aB, "Kalau aktif, skeleton hanya muncul untuk target yang dipilih di tab TARGET.")
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

local hbToggle = addToggle(vA, "Hitbox Bulat", function(on)
	hbOn = on
	if not on then restoreAllHb() end
end)
addToggle(vA, "Sembunyikan Hitbox", function(on) hbHide = on end)
addToggle(vA, "Abaikan Tim", function(on) hbSkipTeam = on end)
addHeader(vB, "ZONA & UKURAN")
local tintToggle = addToggle(vB, "Zona Hitbox", function(on) tintOn = on end)
tintToggle.set(true)
addSlider(vB, vB, "Kekuatan Zona", 10, 90, tintStrength, function(v) tintStrength = v end, "%")
addSlider(vB, vB, "Besar Hitbox", 2, 350, hbSize, function(v) hbSize = v end, " st")
addSlider(vB, vB, "Transparansi Hitbox", 0, 100, math.floor(hbTrans * 100), function(v) hbTrans = v / 100 end, "%")

RunService.Heartbeat:Connect(function()
	if not hbOn then
		if next(hbSaved) then restoreAllHb() end
		tintTarget = 1
		return
	end
	local hbColor = hbRgb and Color3.fromHSV((tick() * 0.25) % 1, 1, 1) or Color3.fromRGB(255, 60, 120)
	local camPos = camera.CFrame.Position
	local insideColor = nil
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
						hrp.Color = hbColor
						if (hrp.Position - camPos).Magnitude < hbSize / 2 then insideColor = hbColor end
					end
				end
			end
		end
	end
	if insideColor and tintOn then
		tintTarget = 1 - tintStrength / 100
		tintColor = insideColor
	else
		tintTarget = 1
	end
end)

----------------------------------------------------------------
-- OPTIMASI
----------------------------------------------------------------
addHeader(oB, "PERFORMA")

do
-- Optimasi Aman: efek, kabut, bayangan. TEKSTUR & MATERIAL MAP TIDAK DIUBAH
local gfxOn = false
local gfxSaved = setmetatable({}, { __mode = "k" })
local gfxEnv, gfxTerr
local gfxConns = {}

local function gfxStrip(inst)
	local props
	if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("PostEffect")
		or inst:IsA("Clouds") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
		if inst.Enabled then
			props = { Enabled = true }
			inst.Enabled = false
		end
	elseif inst:IsA("Atmosphere") then
		props = { Density = inst.Density, Haze = inst.Haze }
		inst.Density = 0
		inst.Haze = 0
	elseif inst:IsA("BasePart") and not inst:IsA("Terrain") and inst.CastShadow and inst.Name ~= "HumanoidRootPart" then
		props = { CastShadow = true }
		inst.CastShadow = false
	end
	if props and not gfxSaved[inst] then gfxSaved[inst] = props end
end

local function gfxApply()
	gfxOn = true
	gfxEnv, gfxTerr = {}, {}
	local lightProps = { GlobalShadows = false, FogEnd = 1e6, FogStart = 1e6, ShadowSoftness = 0 }
	for k, v in pairs(lightProps) do
		pcall(function()
			gfxEnv[k] = Lighting[k]
			Lighting[k] = v
		end)
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local tp = { WaterWaveSize = 0, WaterWaveSpeed = 0, WaterReflectance = 0 }
		for k, v in pairs(tp) do
			pcall(function()
				gfxTerr[k] = terrain[k]
				terrain[k] = v
			end)
		end
	end
	for _, d in ipairs(Lighting:GetDescendants()) do pcall(gfxStrip, d) end
	table.insert(gfxConns, workspace.DescendantAdded:Connect(function(d) pcall(gfxStrip, d) end))
	table.insert(gfxConns, Lighting.DescendantAdded:Connect(function(d) pcall(gfxStrip, d) end))
	task.spawn(function()
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if not gfxOn then return end
			pcall(gfxStrip, d)
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

local function gfxRevert()
	gfxOn = false
	for _, c in ipairs(gfxConns) do c:Disconnect() end
	gfxConns = {}
	if gfxEnv then
		for k, v in pairs(gfxEnv) do pcall(function() Lighting[k] = v end) end
		gfxEnv = nil
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and gfxTerr then
		for k, v in pairs(gfxTerr) do pcall(function() terrain[k] = v end) end
	end
	gfxTerr = nil
	task.spawn(function()
		local n = 0
		for inst, props in pairs(gfxSaved) do
			pcall(function()
				for k, v in pairs(props) do inst[k] = v end
			end)
			gfxSaved[inst] = nil
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

gfxToggle = addToggle(oB, "Optimasi Aman", function(on)
	if on then gfxApply() else gfxRevert() end
end)
addNote(oB, "Hapus efek, partikel, kabut & bayangan agar FPS naik. Tekstur dan material map TIDAK diubah.")
end

do
-- Optimasi Ekstrem: tambahan, mengubah tampilan map (material polos, rumput terrain off, kualitas terendah)
local xOn = false
local xSaved = setmetatable({}, { __mode = "k" })
local xTerr, xQuality
local xConns = {}

local function xStrip(inst)
	if inst:IsA("BasePart") and not inst:IsA("Terrain") and inst.Name ~= "HumanoidRootPart"
		and inst.Name ~= "AirwalkPlatform"
		and not (inst.Parent and inst.Parent:FindFirstChildOfClass("Humanoid")) then
		if inst.Material ~= Enum.Material.SmoothPlastic and not xSaved[inst] then
			xSaved[inst] = inst.Material
			inst.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function xApply()
	xOn = true
	xTerr = {}
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		pcall(function()
			xTerr.Decoration = terrain.Decoration
			terrain.Decoration = false
		end)
	end
	pcall(function()
		local r = settings().Rendering
		xQuality = r.QualityLevel
		r.QualityLevel = Enum.QualityLevel.Level01
	end)
	table.insert(xConns, workspace.DescendantAdded:Connect(function(d) pcall(xStrip, d) end))
	task.spawn(function()
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do
			if not xOn then return end
			pcall(xStrip, d)
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

local function xRevert()
	xOn = false
	for _, c in ipairs(xConns) do c:Disconnect() end
	xConns = {}
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and xTerr then
		for k, v in pairs(xTerr) do pcall(function() terrain[k] = v end) end
	end
	xTerr = nil
	if xQuality then
		pcall(function() settings().Rendering.QualityLevel = xQuality end)
		xQuality = nil
	end
	task.spawn(function()
		local n = 0
		for inst, mat in pairs(xSaved) do
			pcall(function() inst.Material = mat end)
			xSaved[inst] = nil
			n += 1
			if n % 300 == 0 then task.wait() end
		end
	end)
end

xToggle = addToggle(oB, "Optimasi Ekstrem", function(on)
	if on then xApply() else xRevert() end
end)
addNote(oB, "PERINGATAN: mengubah tampilan map (material jadi polos, rumput terrain off, kualitas terendah). Matikan untuk mengembalikan.")
end

----------------------------------------------------------------
-- POPUP: tombol melayang pilihan sendiri
----------------------------------------------------------------
local floats = {}
do
local floatSlots = {}

local function makeFloat(label, onClick, obj)
	local n = 1
	while floatSlots[n] do n += 1 end
	floatSlots[n] = true

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(50, 50)
	btn.Position = UDim2.new(1, -66 - math.floor((n - 1) / 6) * 58, 0.1, ((n - 1) % 6) * 56)
	btn.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	btn.Text = label
	btn.Font = Enum.Font.GothamBlack
	btn.TextSize = 11
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextWrapped = true
	btn.Parent = gui
	corner(btn, 25)
	addStroke(btn, 2.5, (n * 0.13) % 1)

	local dragStart, startPos, moved
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			moved = false
			if not tpLocked then dragStart, startPos = i.Position, btn.Position end
		end
	end)
	local c1 = UIS.InputChanged:Connect(function(i)
		if dragStart and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			if d.Magnitude > 8 then moved = true end
			if moved then
				btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
	local c2 = UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragStart = nil
		end
	end)
	btn.MouseButton1Click:Connect(function()
		if not moved then onClick() end
	end)
	btn.Destroying:Connect(function()
		floatSlots[n] = nil
		pcall(function() c1:Disconnect() end)
		pcall(function() c2:Disconnect() end)
	end)

	table.insert(floats, { btn = btn, obj = obj })
	return btn
end

local function addPopup(parent, text, label, onClick, obj)
	local fl
	addToggle(parent, "Popup " .. text, function(on)
		if on then
			if not fl or not fl.Parent then fl = makeFloat(label, onClick, obj) end
		elseif fl then
			fl:Destroy()
			fl = nil
		end
	end)
end

addHeader(pA, "TOMBOL ON/OFF")
addPopup(pA, "Fly", "FLY", function() flyToggle.set(not flyToggle.on) end, flyToggle)
addPopup(pA, "Noclip", "NOCLIP", function() noclipToggle.set(not noclipToggle.on) end, noclipToggle)
addPopup(pA, "Airwalk", "AIR", function() airToggle.set(not airToggle.on) end, airToggle)
addPopup(pA, "NoClip+Airwalk", "NC+A", function() comboToggle.set(not comboToggle.on) end, comboToggle)
addPopup(pA, "Speed Up", "SPEED", function() speedToggle.set(not speedToggle.on) end, speedToggle)
addPopup(pA, "ESP", "ESP", function() espToggle.set(not espToggle.on) end, espToggle)
addPopup(pA, "ESP Target", "TARGET", function() targetEspToggle.set(not targetEspToggle.on) end, targetEspToggle)
addPopup(pA, "Hitbox", "HIT", function() hbToggle.set(not hbToggle.on) end, hbToggle)
addPopup(pA, "Hide Avatar", "AVA", function() avatarToggle.set(not avatarToggle.on) end, avatarToggle)
addPopup(pA, "Skeleton", "SKEL", function() skelToggle.set(not skelToggle.on) end, skelToggle)

addHeader(pB, "TOMBOL AKSI")
addPopup(pB, "TP Acak", "TP", tpRandom)
addPopup(pB, "TP Bawah Kaki", "TP\nBAWAH", tpUnder)
addPopup(pB, "Bunuh Diri", "DEAD", doSuicide)
addNote(pB, "Nyalakan 'Popup ...' untuk memunculkan tombol melayang. Geser untuk memindahkan. Kunci posisinya lewat 'Kunci Pop-up' di tab POPUP. Tombol ON/OFF berwarna hijau saat fiturnya aktif.")
end

----------------------------------------------------------------
-- PENGATURAN
----------------------------------------------------------------
addHeader(sA, "KECEPATAN")
addHeader(sB, "TAMPILAN MENU")
addSlider(sA, sA, "Fly Speed", 10, 300, flySpeed, function(v) flySpeed = v end, nil, 1000)
addSlider(sA, sA, "Walk Speed", 16, 200, walkSpeed, function(v) walkSpeed = v end, nil, 500)
addSlider(sB, sB, "Transparansi Menu", 0, 80, 0, function(v) applyMenuTransparency(v / 100) end, "%")
local maxW = math.max(420, math.floor(camera.ViewportSize.X - 20))
addSlider(sB, sB, "Lebar Menu", 360, maxW, math.min(MENU_W, maxW), function(v)
	MENU_W = v
	FULL = UDim2.fromOffset(MENU_W, MENU_H)
	CLOSED = UDim2.fromOffset(MENU_W, 0)
	if isOpen then
		TweenService:Create(main, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = FULL }):Play()
	end
end, " px")

local soundToggle = addToggle(sB, "Suara Klik Lucu", function(on) clickOn = on end)
soundToggle.set(true)
addSlider(sB, sB, "Volume Klik", 0, 100, math.floor(clickVol * 100), function(v) clickVol = v / 100 end, "%")

do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder()
	row.Parent = sA

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
	mk("UP", 0, 0, function(v) up = v end)
	mk("DOWN", 0.5, 4, function(v) down = v end)
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
	if flyLockOn then
		flyLockCF = flyLockCF or root.CFrame.Rotation
		bg.CFrame = flyLockCF
	else
		flyLockCF = nil
		bg.CFrame = cf
	end
end)

----------------------------------------------------------------
-- Animasi buka/tutup + drag
----------------------------------------------------------------
local function setOpen(v)
	isOpen = v
	if v then
		main.Visible = true
		main.Size = CLOSED
		TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = FULL }):Play()
	else
		local t = TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = CLOSED })
		t.Completed:Connect(function()
			if not isOpen then main.Visible = false end
		end)
		t:Play()
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
	elseif k == Enum.KeyCode.T then tpRandom()
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
	for i = #floats, 1, -1 do
		local f = floats[i]
		if not f.btn.Parent then
			table.remove(floats, i)
		elseif f.obj then
			f.btn.BackgroundColor3 = f.obj.on and Color3.fromRGB(26, 90, 52) or Color3.fromRGB(14, 14, 20)
		end
	end
end)

----------------------------------------------------------------
-- Panel Config (simpan / muat manual, 3 slot) - jendela terpisah
----------------------------------------------------------------
do
local HttpService = game:GetService("HttpService")
local CFG_DIR = "ZeFera"
local function cfgPath(slot) return CFG_DIR .. "/slot" .. slot .. ".json" end

local function collectCfg()
	local data = { toggles = {}, sliders = {} }
	for k, t in pairs(toggleReg) do data.toggles[k] = t.on end
	for k, sl in pairs(sliderReg) do data.sliders[k] = sl.get() end
	local p = tpBtn.Position
	data.tp = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
	return data
end

local function applyCfg(data)
	if type(data) ~= "table" then return end
	for k, v in pairs(data.sliders or {}) do
		local sl = sliderReg[k]
		if sl and type(v) == "number" then sl.set(v) end
	end
	-- toggle: NoClip+Airwalk dulu supaya urutannya konsisten
	local keys = {}
	for k, v in pairs(data.toggles or {}) do
		if toggleReg[k] and type(v) == "boolean" then table.insert(keys, k) end
	end
	table.sort(keys, function(a, b)
		if a == "NoClip+Airwalk" then return b ~= a end
		if b == "NoClip+Airwalk" then return false end
		return a < b
	end)
	for _, k in ipairs(keys) do
		local t = toggleReg[k]
		local v = data.toggles[k]
		if t.on ~= v then t.set(v) end
	end
	if type(data.tp) == "table" and #data.tp == 4 then
		tpBtn.Position = UDim2.new(data.tp[1], data.tp[2], data.tp[3], data.tp[4])
	end
end

local cfgDefaults = collectCfg()

local function saveSlot(slot)
	if not (writefile and readfile and isfile) then
		return false, "Executor tidak mendukung simpan file"
	end
	pcall(function()
		if makefolder and not (isfolder and isfolder(CFG_DIR)) then makefolder(CFG_DIR) end
	end)
	local ok = pcall(function()
		writefile(cfgPath(slot), HttpService:JSONEncode(collectCfg()))
	end)
	if ok then return true, "Tersimpan di Slot " .. slot end
	return false, "Gagal menyimpan"
end

local function loadSlot(slot)
	if not (readfile and isfile) then
		return false, "Executor tidak mendukung baca file"
	end
	local path = cfgPath(slot)
	if not isfile(path) then return false, "Slot " .. slot .. " masih kosong" end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
	if not ok then return false, "File config rusak" end
	applyCfg(data)
	return true, "Slot " .. slot .. " dimuat"
end

local CFG_W, CFG_H = 250, 176
local cfgFrame = Instance.new("Frame")
cfgFrame.Size = UDim2.fromOffset(CFG_W, 0)
cfgFrame.Position = UDim2.new(0.5, -125, 0.3, 0)
cfgFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
cfgFrame.BorderSizePixel = 0
cfgFrame.ClipsDescendants = true
cfgFrame.Visible = false
cfgFrame.Parent = gui
corner(cfgFrame, 14)
addStroke(cfgFrame, 2.5, 0.5)
registerPanel(cfgFrame)

local cfgHeader = Instance.new("Frame")
cfgHeader.Size = UDim2.new(1, 0, 0, 36)
cfgHeader.BackgroundTransparency = 1
cfgHeader.Active = true
cfgHeader.Parent = cfgFrame

local cfgTitle = Instance.new("TextLabel")
cfgTitle.Size = UDim2.new(1, -50, 1, 0)
cfgTitle.Position = UDim2.fromOffset(12, 0)
cfgTitle.BackgroundTransparency = 1
cfgTitle.Text = "CONFIG"
cfgTitle.Font = Enum.Font.GothamBlack
cfgTitle.TextSize = 15
cfgTitle.TextColor3 = Color3.new(1, 1, 1)
cfgTitle.TextXAlignment = Enum.TextXAlignment.Left
cfgTitle.Parent = cfgHeader

local cfgClose = Instance.new("TextButton")
cfgClose.Size = UDim2.fromOffset(28, 26)
cfgClose.Position = UDim2.new(1, -36, 0, 5)
cfgClose.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
cfgClose.Text = "X"
cfgClose.Font = Enum.Font.GothamBold
cfgClose.TextSize = 14
cfgClose.TextColor3 = Color3.new(1, 1, 1)
cfgClose.Parent = cfgHeader
corner(cfgClose, 8)

local function cfgButton(text, x, y, w, h, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, h)
	b.Position = UDim2.fromOffset(x, y)
	b.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = cfgFrame
	corner(b, 10)
	addStroke(b, 1.5, x / 250)
	registerPanel(b)
	b.MouseButton1Click:Connect(cb)
	return b
end

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.fromOffset(230, 36)
statusLbl.Position = UDim2.fromOffset(10, 124)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.GothamMedium
statusLbl.TextSize = 12
statusLbl.TextWrapped = true
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextYAlignment = Enum.TextYAlignment.Top
statusLbl.TextColor3 = Color3.fromRGB(185, 185, 205)
statusLbl.Text = ""
statusLbl.Parent = cfgFrame

local COL_OK, COL_ERR, COL_INFO = Color3.fromRGB(90, 230, 130), Color3.fromRGB(255, 100, 110), Color3.fromRGB(185, 185, 205)
local function setStatus(text, color)
	statusLbl.Text = text
	statusLbl.TextColor3 = color or COL_INFO
end

local cfgSlot = 1
local slotBtns = {}
local function selectSlot(n)
	cfgSlot = n
	for i, b in ipairs(slotBtns) do
		b.BackgroundColor3 = (i == n) and Color3.fromRGB(50, 90, 170) or Color3.fromRGB(26, 26, 36)
	end
	local has = false
	if isfile then pcall(function() has = isfile(cfgPath(n)) end) end
	setStatus("Slot " .. n .. (has and ": ada config tersimpan" or ": masih kosong"), COL_INFO)
end

for i = 1, 3 do
	slotBtns[i] = cfgButton("Slot " .. i, 10 + (i - 1) * 78, 42, 74, 30, function() selectSlot(i) end)
end

cfgButton("Save", 10, 80, 74, 34, function()
	local ok, msg = saveSlot(cfgSlot)
	setStatus(msg, ok and COL_OK or COL_ERR)
end)
cfgButton("Load", 88, 80, 74, 34, function()
	local ok, msg = loadSlot(cfgSlot)
	setStatus(msg, ok and COL_OK or COL_ERR)
end)
cfgButton("Reset", 166, 80, 74, 34, function()
	applyCfg(cfgDefaults)
	setStatus("Pengaturan dikembalikan ke default", COL_OK)
end)

local cfgOpen = false
toggleCfg = function()
	cfgOpen = not cfgOpen
	if cfgOpen then
		cfgFrame.Visible = true
		cfgFrame.Size = UDim2.fromOffset(CFG_W, 0)
		TweenService:Create(cfgFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(CFG_W, CFG_H) }):Play()
		selectSlot(cfgSlot)
	else
		local t = TweenService:Create(cfgFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(CFG_W, 0) })
		t.Completed:Connect(function()
			if not cfgOpen then cfgFrame.Visible = false end
		end)
		t:Play()
	end
end
cfgClose.MouseButton1Click:Connect(function() if cfgOpen then toggleCfg() end end)

do
	local dragging, dragStart, startPos
	cfgHeader.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, cfgFrame.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			cfgFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

end

----------------------------------------------------------------
-- Respawn
----------------------------------------------------------------
track(player.CharacterAdded:Connect(function()
	bv, bg = nil, nil
	flying = false
	if flyToggle.on then flyToggle.on = false flyToggle.set(false) end
	if comboToggle.on then comboToggle.on = false comboToggle.set(false) end
	if airToggle.on then airToggle.set(false) end

end))

----------------------------------------------------------------
-- Unload (tombol DEL): matikan semua fitur, kembalikan kondisi, hapus menu
----------------------------------------------------------------
unloadHub = function()
	for _, t in ipairs({ comboToggle, flyToggle, noclipToggle, airToggle, speedToggle, darkToggle, espToggle, targetEspToggle, hbToggle, avatarToggle, skelToggle, gfxToggle, xToggle }) do
		if t.on then pcall(t.set, false) end
	end
	tintTarget = 1
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() tintGui:Destroy() end)
	pcall(function() skelFolder:Destroy() end)
	for _, snd in ipairs(clickSounds) do pcall(function() snd:Destroy() end) end
	pcall(function() gui:Destroy() end)
	pcall(function() getgenv().ZeFeraUnload = nil end)
end
pcall(function() getgenv().ZeFeraUnload = unloadHub end)

-- Suara klik untuk semua tombol (termasuk yang dibuat belakangan)
local function hookClick(d)
	if d:IsA("GuiButton") then d.MouseButton1Click:Connect(playClick) end
end
for _, d in ipairs(gui:GetDescendants()) do hookClick(d) end
gui.DescendantAdded:Connect(hookClick)

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
