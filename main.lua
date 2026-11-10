-- RGB Fly GUI (LocalScript / loadstring compatible)
-- Kontrol: WASD / joystick = gerak, Space/Shift atau tombol UP/DOWN = naik/turun
-- F = toggle fly, klik judul untuk drag

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Hapus GUI lama
local old = player:WaitForChild("PlayerGui"):FindFirstChild("RGBFlyGui")
if old then old:Destroy() end

local flying, speed = false, 60
local up, down = false, false
local bv, bg

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RGBFlyGui"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(230, 190)
main.Position = UDim2.new(0.5, -115, 0.3, 0)
main.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke", main)
stroke.Thickness = 2.5
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundTransparency = 1
title.Text = "✦ RGB FLY ✦"
title.Font = Enum.Font.GothamBlack
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.Parent = main

local titleGrad = Instance.new("UIGradient", title)

local function makeButton(text, pos, size)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Parent = main
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", b)
	s.Thickness = 1.5
	return b, s
end

local toggleBtn, toggleStroke = makeButton("FLY: OFF", UDim2.new(0, 15, 0, 45), UDim2.new(1, -30, 0, 38))
local minus, minusStroke = makeButton("-", UDim2.new(0, 15, 0, 95), UDim2.fromOffset(40, 34))
local plus, plusStroke = makeButton("+", UDim2.new(1, -55, 0, 95), UDim2.fromOffset(40, 34))
local upBtn, upStroke = makeButton("▲ UP", UDim2.new(0, 15, 0, 140), UDim2.new(0.5, -20, 0, 36))
local downBtn, downStroke = makeButton("▼ DOWN", UDim2.new(0.5, 5, 0, 140), UDim2.new(0.5, -20, 0, 36))

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -120, 0, 34)
speedLabel.Position = UDim2.new(0, 60, 0, 95)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.GothamMedium
speedLabel.TextSize = 14
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.Text = "Speed: " .. speed
speedLabel.Parent = main

-- Drag lewat judul
do
	local dragging, dragStart, startPos
	title.InputBegan:Connect(function(i)
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
-- RGB animasi
----------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local t = tick()
	local h = (t * 0.25) % 1
	local c1, c2, c3 = Color3.fromHSV(h, 1, 1), Color3.fromHSV((h + 0.33) % 1, 1, 1), Color3.fromHSV((h + 0.66) % 1, 1, 1)

	stroke.Color = c1
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(0.5, c2),
		ColorSequenceKeypoint.new(1, c3),
	})
	titleGrad.Rotation = (t * 90) % 360

	toggleStroke.Color = Color3.fromHSV((h + 0.1) % 1, 1, 1)
	minusStroke.Color = Color3.fromHSV((h + 0.2) % 1, 1, 1)
	plusStroke.Color = Color3.fromHSV((h + 0.3) % 1, 1, 1)
	upStroke.Color = Color3.fromHSV((h + 0.4) % 1, 1, 1)
	downStroke.Color = Color3.fromHSV((h + 0.5) % 1, 1, 1)
end)

----------------------------------------------------------------
-- Fly logic
----------------------------------------------------------------
local function stopFly()
	flying = false
	if bv then bv:Destroy() bv = nil end
	if bg then bg:Destroy() bg = nil end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = false end
	toggleBtn.Text = "FLY: OFF"
end

local function startFly()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then return end

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

	toggleBtn.Text = "FLY: ON"
end

local function toggle()
	if flying then stopFly() else startFly() end
end

toggleBtn.MouseButton1Click:Connect(toggle)
minus.MouseButton1Click:Connect(function()
	speed = math.max(10, speed - 10)
	speedLabel.Text = "Speed: " .. speed
end)
plus.MouseButton1Click:Connect(function()
	speed = math.min(300, speed + 10)
	speedLabel.Text = "Speed: " .. speed
end)

upBtn.MouseButton1Down:Connect(function() up = true end)
upBtn.MouseButton1Up:Connect(function() up = false end)
downBtn.MouseButton1Down:Connect(function() down = true end)
downBtn.MouseButton1Up:Connect(function() down = false end)

UIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.F then toggle()
	elseif i.KeyCode == Enum.KeyCode.Space then up = true
	elseif i.KeyCode == Enum.KeyCode.LeftShift then down = true end
end)
UIS.InputEnded:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.Space then up = false
	elseif i.KeyCode == Enum.KeyCode.LeftShift then down = false end
end)

RunService.RenderStepped:Connect(function()
	if not flying then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and bv and bg) then return end

	local cf = camera.CFrame
	local md = hum.MoveDirection
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	flatLook = flatLook.Magnitude > 0 and flatLook.Unit or Vector3.zero
	flatRight = flatRight.Magnitude > 0 and flatRight.Unit or Vector3.zero

	local fwd, right = md:Dot(flatLook), md:Dot(flatRight)
	local dir = cf.LookVector * fwd + cf.RightVector * right
	if up then dir += Vector3.yAxis end
	if down then dir -= Vector3.yAxis end

	bv.Velocity = dir * speed
	bg.CFrame = cf
end)

player.CharacterAdded:Connect(function()
	flying = false
	bv, bg = nil, nil
	toggleBtn.Text = "FLY: OFF"
end)
