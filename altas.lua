-- Altas 1.0 Modified by rust96
-- Entry point for the Altas source (main.lua) in this repository.
--
-- Applies:
--   * per-account config storage: atlas/accounts/<UserId>/
--   * window title: Altas 1.0 Modified by rust96
--   * background image, resolved before the UI is built
--   * walkspeed slider max 90, tween slider max 100
--   * tween speed clamp removed (not just unlocked)
--   * walk slider applies WalkSpeed on every change, up and down
--   * black-screen anti-lag HUD with uptime, server uptime, honey, rate, heading
--   * auto server hop (10 min default) and rejoin (10 min default) with sliders
--
-- Run (add ?v= to skip any cached copy):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/altas.lua?v=10"))()

local REPO = "https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/"
local NONCE = tostring(os.time()) .. tostring(math.random(1000, 9999))
local SOURCE_URL = REPO .. "main.lua?v=" .. NONCE

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Altas",
			Text = tostring(text),
			Duration = 8,
		})
	end)
end

local function replaceOnce(source, needle, replacement)
	local index = string.find(source, needle, 1, true)

	if not index then
		return source, false
	end

	return string.sub(source, 1, index - 1) .. replacement .. string.sub(source, index + #needle), true
end

local function replaceAll(source, needle, replacement)
	local count = 0
	local index = 1

	while true do
		local start = string.find(source, needle, index, true)

		if not start then
			break
		end

		source = string.sub(source, 1, start - 1) .. replacement .. string.sub(source, start + #needle)
		index = start + #replacement
		count += 1
	end

	return source, count
end

local HUD

do
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local sessionStart = os.clock()

	local gui = Instance.new("ScreenGui")
	gui.Name = "AltasAntiLagHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.Enabled = false
	gui.Parent = gethui and gethui() or game:GetService("CoreGui")

	local black = Instance.new("Frame")
	black.Name = "Black"
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Position = UDim2.new(0, 24, 0, 24)
	panel.Size = UDim2.new(0, 340, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 3)
	layout.Parent = panel

	local order = 0

	local function addLabel(text, size, color)
		order += 1

		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextSize = size or 14
		label.TextColor3 = color or Color3.fromRGB(240, 240, 240)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = text
		label.Size = UDim2.new(1, 0, 0, (size or 14) + 4)
		label.Parent = panel

		return label
	end

	local rows = {}

	addLabel("Altas 1.0 - Anti-Lag", 15, Color3.fromRGB(255, 255, 255))
	rows.uptime = addLabel("Uptime: 00:00:00")
	rows.server = addLabel("Server Uptime: 00:00:00")
	rows.honey = addLabel("Session Honey: 0")
	rows.rate = addLabel("Honey per Hour: 0")
	rows.heading = addLabel("Heading: -", 13, Color3.fromRGB(180, 220, 255))

	local function formatTime(seconds)
		seconds = math.max(0, math.floor(tonumber(seconds) or 0))
		return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end

	local function formatNumber(value)
		value = tonumber(value) or 0

		local suffixes = { "", "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "O", "N" }
		local index = 1
		local absolute = math.abs(value)

		while absolute >= 1000 and index < #suffixes do
			absolute /= 1000
			value /= 1000
			index += 1
		end

		if index == 1 then
			return tostring(math.floor(value))
		end

		return string.format("%.2f%s", value, suffixes[index])
	end

	local function currentHoney()
		local ok, value = pcall(function()
			return player.CoreStats.Honey.Value
		end)

		if ok and type(value) == "number" then
			return value
		end

		return nil
	end

	local honeyStart = currentHoney()

	local function lastConsoleLine()
		local root = _G.atlas

		if not root then
			return nil
		end

		local bar = nil

		for _, object in ipairs(root:GetDescendants()) do
			if object:IsA("TextLabel") and object.Text == "Atlas Console" then
				bar = object
				break
			end
		end

		if not bar or not bar.Parent or not bar.Parent.Parent then
			return nil
		end

		local scrolling = nil

		for _, object in ipairs(bar.Parent.Parent:GetDescendants()) do
			if object:IsA("ScrollingFrame") then
				scrolling = object
				break
			end
		end

		if not scrolling then
			return nil
		end

		local text = nil

		for _, child in ipairs(scrolling:GetChildren()) do
			if child:IsA("TextLabel") and #child.Text > 0 then
				text = child.Text
			end
		end

		if text then
			text = string.gsub(text, "^%[[^%]]*%] %[[^%]]*%] ", "")
		end

		return text
	end

	local function refresh()
		local session = os.clock() - sessionStart
		local honey = currentHoney()
		local gained = 0

		if honey and honeyStart then
			gained = honey - honeyStart
		end

		rows.uptime.Text = "Uptime: " .. formatTime(session)
		rows.server.Text = "Server Uptime: " .. formatTime(workspace.DistributedGameTime)
		rows.honey.Text = "Session Honey: " .. formatNumber(gained)
		rows.rate.Text = "Honey per Hour: " .. formatNumber(session > 5 and gained / (session / 3600) or 0)

		local heading = lastConsoleLine()
		rows.heading.Text = "Heading: " .. (heading and string.sub(heading, 1, 42) or "-")
	end

	HUD = {}
	HUD.gui = gui
	HUD.show = function(visible)
		gui.Enabled = visible and true or false

		if gui.Enabled then
			pcall(refresh)
		end
	end
	HUD.refresh = refresh

	_G.atlasHud = HUD.show

	task.spawn(function()
		while true do
			task.wait(1)

			if gui.Enabled then
				pcall(refresh)
			end
		end
	end)
end

local Automation

do
	local Players = game:GetService("Players")
	local TeleportService = game:GetService("TeleportService")
	local HttpService = game:GetService("HttpService")
	local UserInputService = game:GetService("UserInputService")
	local player = Players.LocalPlayer
	local accountId = tostring(player.UserId)
	local settingsPath = "atlas/accounts/" .. accountId .. "/automation.json"

	local settings = {
		hopEnabled = false,
		hopMinutes = 10,
		rejoinEnabled = false,
		rejoinMinutes = 10,
	}

	pcall(function()
		if makefolder and isfolder then
			for _, folder in ipairs({ "atlas", "atlas/accounts", "atlas/accounts/" .. accountId }) do
				if not isfolder(folder) then
					makefolder(folder)
				end
			end
		end
	end)

	pcall(function()
		if isfile and isfile(settingsPath) and readfile then
			local data = readfile(settingsPath)
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(data)
			end)

			if ok and type(decoded) == "table" then
				settings.hopEnabled = decoded.hopEnabled == true
				settings.hopMinutes = math.clamp(tonumber(decoded.hopMinutes) or 10, 1, 60)
				settings.rejoinEnabled = decoded.rejoinEnabled == true
				settings.rejoinMinutes = math.clamp(tonumber(decoded.rejoinMinutes) or 10, 1, 60)
			end
		end
	end)

	local dirty = false

	local function save()
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode(settings)
		end)

		if ok and writefile then
			pcall(writefile, settingsPath, encoded)
		end
	end

	local function hop()
		local ok, body = pcall(function()
			return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100")
		end)

		if not ok or type(body) ~= "string" then
			notify("server hop: request failed")
			return
		end

		local decoded

		pcall(function()
			decoded = HttpService:JSONDecode(body)
		end)

		local servers = decoded and decoded.data

		if type(servers) ~= "table" then
			notify("server hop: no server list")
			return
		end

		local options = {}

		for _, server in ipairs(servers) do
			local playing = tonumber(server.playing) or 0
			local maxPlayers = tonumber(server.maxPlayers) or 0

			if server.id and server.id ~= game.JobId and playing < maxPlayers then
				table.insert(options, server.id)
			end
		end

		if #options == 0 then
			notify("server hop: no open servers")
			return
		end

		local target = options[math.random(1, #options)]

		notify("server hopping")

		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, target, player)
		end)
	end

	local function rejoin()
		notify("rejoining")

		pcall(function()
			TeleportService:Teleport(game.PlaceId, player)
		end)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AltasAutomation"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 90
	gui.Parent = gethui and gethui() or game:GetService("CoreGui")

	local frame = Instance.new("Frame")
	frame.Position = UDim2.new(0, 20, 1, -216)
	frame.Size = UDim2.new(0, 250, 0, 196)
	frame.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 6)
	frameCorner.Parent = frame

	local header = Instance.new("TextButton")
	header.Size = UDim2.new(1, 0, 0, 26)
	header.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	header.BorderSizePixel = 0
	header.Font = Enum.Font.Code
	header.TextSize = 13
	header.TextColor3 = Color3.fromRGB(235, 235, 235)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "  Altas Automation"
	header.Parent = frame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 6)
	headerCorner.Parent = header

	local collapse = Instance.new("TextButton")
	collapse.AnchorPoint = Vector2.new(1, 0)
	collapse.Position = UDim2.new(1, -6, 0, 3)
	collapse.Size = UDim2.new(0, 20, 0, 20)
	collapse.BackgroundTransparency = 1
	collapse.Font = Enum.Font.Code
	collapse.TextSize = 16
	collapse.TextColor3 = Color3.fromRGB(200, 200, 200)
	collapse.Text = "-"
	collapse.Parent = header

	local content = Instance.new("Frame")
	content.Position = UDim2.new(0, 8, 0, 34)
	content.Size = UDim2.new(1, -16, 1, -42)
	content.BackgroundTransparency = 1
	content.Parent = frame

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 4)
	contentLayout.Parent = content

	local order = 0

	local function makeToggle(text, value, onChange)
		order += 1

		local button = Instance.new("TextButton")
		button.LayoutOrder = order
		button.Size = UDim2.new(1, 0, 0, 26)
		button.BackgroundColor3 = value and Color3.fromRGB(52, 92, 64) or Color3.fromRGB(40, 40, 44)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.Code
		button.TextSize = 12
		button.TextColor3 = Color3.fromRGB(235, 235, 235)
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.Text = "  " .. text .. ": " .. (value and "ON" or "OFF")
		button.Parent = content

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = button

		local state = value

		button.MouseButton1Click:Connect(function()
			state = not state
			button.Text = "  " .. text .. ": " .. (state and "ON" or "OFF")
			button.BackgroundColor3 = state and Color3.fromRGB(52, 92, 64) or Color3.fromRGB(40, 40, 44)
			onChange(state)
		end)
	end

	local function makeSlider(text, minValue, maxValue, initial, onChange)
		order += 1

		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundTransparency = 1
		row.Parent = content

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextSize = 12
		label.TextColor3 = Color3.fromRGB(220, 220, 220)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Size = UDim2.new(1, 0, 0, 14)
		label.Text = text .. ": " .. initial .. " min"
		label.Parent = row

		local bar = Instance.new("Frame")
		bar.Position = UDim2.new(0, 0, 0, 22)
		bar.Size = UDim2.new(1, 0, 0, 8)
		bar.BackgroundColor3 = Color3.fromRGB(48, 48, 54)
		bar.BorderSizePixel = 0
		bar.Parent = row

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = bar

		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale((initial - minValue) / math.max(maxValue - minValue, 1), 1)
		fill.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
		fill.BorderSizePixel = 0
		fill.Parent = bar

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		local current = initial
		local dragging = false

		local function apply(x)
			local relative = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
			local value = math.floor(minValue + (maxValue - minValue) * relative + 0.5)

			if value ~= current then
				current = value
				label.Text = text .. ": " .. value .. " min"
				fill.Size = UDim2.fromScale((value - minValue) / math.max(maxValue - minValue, 1), 1)
				onChange(value)
			end
		end

		bar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				apply(input.Position.X)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				apply(input.Position.X)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	makeToggle("Auto Server Hop", settings.hopEnabled, function(state)
		settings.hopEnabled = state
		dirty = true
	end)

	makeSlider("Hop every", 1, 60, settings.hopMinutes, function(value)
		settings.hopMinutes = value
		dirty = true
	end)

	makeToggle("Auto Rejoin", settings.rejoinEnabled, function(state)
		settings.rejoinEnabled = state
		dirty = true
	end)

	makeSlider("Rejoin every", 1, 60, settings.rejoinMinutes, function(value)
		settings.rejoinMinutes = value
		dirty = true
	end)

	order += 1

	local status = Instance.new("TextLabel")
	status.LayoutOrder = order
	status.Size = UDim2.new(1, 0, 0, 18)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Code
	status.TextSize = 11
	status.TextColor3 = Color3.fromRGB(160, 200, 160)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = "Idle"
	status.Parent = content

	collapse.MouseButton1Click:Connect(function()
		content.Visible = not content.Visible
		frame.Size = content.Visible and UDim2.new(0, 250, 0, 196) or UDim2.new(0, 250, 0, 26)
		collapse.Text = content.Visible and "-" or "+"
	end)

	local draggingFrame = false
	local dragStart = nil
	local dragOrigin = nil

	header.MouseButton1Down:Connect(function()
		draggingFrame = true
		dragStart = UserInputService:GetMouseLocation()
		dragOrigin = frame.Position
	end)

	UserInputService.InputChanged:Connect(function(input)
		if draggingFrame and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = UserInputService:GetMouseLocation() - dragStart
			frame.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset + delta.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset + delta.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingFrame = false
		end
	end)

	local hopRemaining = settings.hopMinutes * 60
	local rejoinRemaining = settings.rejoinMinutes * 60

	task.spawn(function()
		local last = os.clock()

		while true do
			task.wait(1)

			local now = os.clock()
			local delta = now - last
			last = now

			if settings.hopEnabled then
				hopRemaining -= delta

				if hopRemaining <= 0 then
					hopRemaining = settings.hopMinutes * 60
					hop()
				end
			else
				hopRemaining = settings.hopMinutes * 60
			end

			if settings.rejoinEnabled then
				rejoinRemaining -= delta

				if rejoinRemaining <= 0 then
					rejoinRemaining = settings.rejoinMinutes * 60
					rejoin()
				end
			else
				rejoinRemaining = settings.rejoinMinutes * 60
			end

			local function clock(seconds)
				seconds = math.max(0, math.floor(seconds))
				return string.format("%02d:%02d", seconds // 60, seconds % 60)
			end

			if settings.hopEnabled and settings.rejoinEnabled then
				status.Text = "Hop " .. clock(hopRemaining) .. "  |  Rejoin " .. clock(rejoinRemaining)
			elseif settings.hopEnabled then
				status.Text = "Hop in " .. clock(hopRemaining)
			elseif settings.rejoinEnabled then
				status.Text = "Rejoin in " .. clock(rejoinRemaining)
			else
				status.Text = "Idle"
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(2)

			if dirty then
				dirty = false
				save()
			end
		end
	end)

	Automation = {
		settings = settings,
		hop = hop,
		rejoin = rejoin,
	}
end

local configShim = [==[
do
	local player = game:GetService("Players").LocalPlayer
	local accountId = player and tostring(player.UserId) or "unknown"
	local configRoot = "atlas/accounts/" .. accountId

	local rawWrite, rawRead = writefile, readfile
	local rawIsFile, rawDelete = isfile, delfile
	local rawIsFolder, rawMakeFolder = isfolder, makefolder
	local rawList = listfiles

	local function scope(path)
		if type(path) ~= "string" then
			return path
		end

		local lowered = string.lower(path)

		if string.find(lowered, "atlas/accounts/", 1, true) then
			return path
		end
		if lowered == "atlas" then
			return configRoot
		end
		if string.sub(lowered, 1, 6) == "atlas/" then
			return configRoot .. "/" .. string.sub(path, 7)
		end
		if string.find(lowered, "atlas", 1, true) == 1 then
			return configRoot .. "/" .. path
		end

		return path
	end

	if rawMakeFolder then
		for _, folder in ipairs({ "atlas", "atlas/accounts", configRoot }) do
			if not (rawIsFolder and rawIsFolder(folder)) then
				pcall(rawMakeFolder, folder)
			end
		end
	end

	if rawList and rawRead and rawWrite and rawIsFile then
		local ok, entries = pcall(rawList, "atlas")

		if ok and type(entries) == "table" then
			for _, entry in ipairs(entries) do
				local lowered = string.lower(entry)

				if string.sub(lowered, -5) == ".json"
					and not string.find(lowered, "atlas/accounts", 1, true)
					and not string.find(lowered, "atlascache", 1, true) then
					local name = string.match(entry, "([^/\\]+)$")
					local sourcePath = entry

					if not string.find(lowered, "atlas", 1, true) then
						sourcePath = "atlas/" .. entry
					end

					if name and not rawIsFile(configRoot .. "/" .. name) then
						local readOk, data = pcall(rawRead, sourcePath)

						if readOk and type(data) == "string" and #data > 0 then
							pcall(rawWrite, configRoot .. "/" .. name, data)
						end
					end
				end
			end
		end
	end

	if rawWrite then writefile = function(path, data) return rawWrite(scope(path), data) end end
	if rawRead then readfile = function(path) return rawRead(scope(path)) end end
	if rawIsFile then isfile = function(path) return rawIsFile(scope(path)) end end
	if rawDelete then delfile = function(path) return rawDelete(scope(path)) end end
	if rawList then listfiles = function(path) return rawList(scope(path)) end end
	if rawMakeFolder then makefolder = function(path) return rawMakeFolder(scope(path)) end end
	if rawIsFolder then isfolder = function(path) return rawIsFolder(scope(path)) end end
end
]==]

local sliderGuard = [==[
	local sliderLabel = string.lower(tostring(sliderTitle or ""))
	local sliderName = string.gsub(sliderLabel, "%s+", "")
	local sliderKey = string.lower(tostring(configKey or ""))
	local maxNumber = tonumber(maxValue) or 0
	local isWalkSpeed = sliderKey == "walkspeed" or sliderName == "walkspeed" or (string.find(sliderName, "walk", 1, true) and string.find(sliderName, "speed", 1, true))
	local isTweenSpeed = sliderKey == "tweenspeed" or sliderName == "tweenspeed" or (string.find(sliderName, "tween", 1, true) and string.find(sliderName, "speed", 1, true))

	if isWalkSpeed and maxNumber ~= 90 then
		maxValue = 90
	end

	if isTweenSpeed and maxNumber < 100 then
		maxValue = 100
	end

	if isWalkSpeed and callback then
		local userCallback = callback

		callback = function(newValue)
			userCallback(newValue)

			if cfg and cfg.vars and cfg.vars.walkspeedenabled then
				pcall(function()
					local character = game:GetService("Players").LocalPlayer.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")

					if humanoid then
						humanoid.WalkSpeed = tonumber(newValue) or humanoid.WalkSpeed
					end
				end)
			end
		end
	end

	if _G.atlasSliderLog and (isWalkSpeed or isTweenSpeed) then
		table.insert(_G.atlasSliderLog, tostring(sliderTitle) .. " " .. tostring(minValue) .. "-" .. tostring(maxValue) .. " key=" .. tostring(configKey))
	end
]==]

local BG_FILE = "altas_bg.png"
local BG_LOCAL = "/home/alex/Downloads/92132-972537-sweetie-fox-gamer.png"
local BG_NAMES = { "background.png", "92132-972537-sweetie-fox-gamer.png" }

local function isPng(data)
	return type(data) == "string" and #data > 100 and string.sub(data, 1, 4) == "\137PNG"
end

local function assetFromWorkspace()
	local ok, result = pcall(getcustomasset, BG_FILE)

	if ok and type(result) == "string" and #result > 0 then
		return result
	end

	if getsynasset then
		local ok2, result2 = pcall(getsynasset, BG_FILE)

		if ok2 and type(result2) == "string" and #result2 > 0 then
			return result2
		end
	end

	return nil
end

local background = nil

local cached = nil

pcall(function()
	if isfile and isfile(BG_FILE) then
		cached = readfile(BG_FILE)
	end
end)

if isPng(cached) then
	background = assetFromWorkspace()
end

if not background then
	for _, name in ipairs(BG_NAMES) do
		local ok, data = pcall(function()
			return game:HttpGet(REPO .. name .. "?v=" .. NONCE)
		end)

		if ok and isPng(data) then
			local wrote = pcall(writefile, BG_FILE, data)

			if wrote then
				background = assetFromWorkspace()
			end

			if background then
				break
			end
		end
	end
end

if not background then
	local data = nil

	pcall(function()
		data = readfile(BG_LOCAL)
	end)

	if isPng(data) then
		local wrote = pcall(writefile, BG_FILE, data)

		if wrote then
			background = assetFromWorkspace()
		end
	end
end

if background then
	_G.background = background
end

_G.unlocktween = true

if getgenv then
	pcall(function()
		getgenv().unlocktween = true
	end)
end

if getrenv then
	pcall(function()
		getrenv().unlocktween = true
	end)
end

_G.atlasSliderLog = {}

local runService = game:GetService("RunService")
local hudHooked = false

if type(hookfunction) == "function" and type(runService.Set3dRenderingEnabled) == "function" then
	pcall(function()
		local original
		original = hookfunction(runService.Set3dRenderingEnabled, function(self, enabled, ...)
			HUD.show(not enabled)
			return original(self, enabled, ...)
		end)

		hudHooked = true
	end)
end

local source = game:HttpGet(SOURCE_URL)

if type(source) ~= "string" or #source < 1000 then
	return notify("main.lua download failed")
end

local titlePatched = false
source, titlePatched = replaceOnce(source, "local title = _G.title and", "local title = \"Altas 1.0 Modified by rust96\" or _G.title and")

if not titlePatched then
	source, titlePatched = replaceOnce(source, "\"deobfuscated by skynex - .gg/syncrypt\"", "\"Altas 1.0 Modified by rust96\"")
end

local tweenClampPatched = false
source, tweenClampPatched = replaceOnce(source, "if cfg.vars.tweenspeed > 12 and _G.unlocktween ~= true then", "if false then")

local addSliderNeedle = "folderApi.AddSlider = function(sliderTitle, callback, minValue, maxValue, configSource, configKey, options)"
local sliderCount = 0
source, sliderCount = replaceAll(source, addSliderNeedle, addSliderNeedle .. "\n" .. sliderGuard)
local sliderPatched = sliderCount > 0

source = configShim .. "\n" .. source

local chunk, compileError = loadstring(source)

if not chunk then
	return notify("compile error: " .. tostring(compileError))
end

notify("walk=90 tween=100 hud=" .. (hudHooked and "hooked" or "manual") .. " hop/rejoin sliders ready")

chunk()
