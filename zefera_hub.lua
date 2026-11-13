xTorque = Vector3.new(1e5, 1e5, 1e5)
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
addHeader(vB, "PENCAHAYAAN")
local darkToggle = addToggle(vB, "Anti Gelap", function(on)
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

addNote(vB, "Terangkan area gelap (fullbright). Pengaturan cahaya asli dikembalikan saat dimatikan.")

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

addHeader(tB, "POP-UP TP")
local tpToggle = addToggle(tB, "Pintasan TP", function(on) tpBtn.Visible = on end)
tpToggle.set(true)
addToggle(tB, "Kunci Pop-up", function(on)
	tpLocked = on
	toast(on and "Semua pop-up dikunci" or "Pop-up dibuka")
end)
addNote(tB, "Kunci Pop-up berlaku untuk tombol TP dan semua tombol pop-up lain.")

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
addNote(pB, "Nyalakan 'Popup ...' untuk memunculkan tombol melayang. Geser untuk memindahkan. Kunci posisinya lewat 'Kunci Pop-up' di tab TELEPORT. Tombol ON/OFF berwarna hijau saat fiturnya aktif.")
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
	for _, t in ipairs({ comboToggle, flyToggle, wallToggle, noclipToggle, airToggle, speedToggle, darkToggle, espToggle, targetEspToggle, hbToggle, avatarToggle, skelToggle, gfxToggle, xToggle }) do
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
