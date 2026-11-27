local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local SECTION = "AltasHopSection"
local FILE = "atlas/accounts/" .. tostring(player.UserId) .. "/debug_automation.json"
local settings = { hop = false, hopMin = 10, rejoin = false, rejoinMin = 10 }

pcall(function()
	if isfile and isfile(FILE) and readfile then
		local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
		if ok and type(decoded) == "table" then
			settings.hop = decoded.hop == true
			settings.hopMin = math.clamp(tonumber(decoded.hopMin) or 10, 1, 60)
			settings.rejoin = decoded.rejoin == true
			settings.rejoinMin = math.clamp(tonumber(decoded.rejoinMin) or 10, 1, 60)
		end
	end
end)

pcall(function()
	if makefolder and isfolder then
		for _, folder in ipairs({ "atlas", "atlas/accounts", "atlas/accounts/" .. tostring(player.UserId) }) do
			if not isfolder(folder) then makefolder(folder) end
		end
	end
end)

local dirty = false
local function save()
	local ok, encoded = pcall(function() return HttpService:JSONEncode(settings) end)
	if ok and writefile then pcall(writefile, FILE, encoded) end
end

local hopLeft, rejoinLeft = settings.hopMin * 60, settings.rejoinMin * 60

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local function setStatus()
	if settings.hop and settings.rejoin then
		_G.atlasAutomationStatus = "Hop " .. clock(hopLeft) .. "  Rejoin " .. clock(rejoinLeft)
	elseif settings.hop then
		_G.atlasAutomationStatus = "Hop in " .. clock(hopLeft)
	elseif settings.rejoin then
		_G.atlasAutomationStatus = "Rejoin in " .. clock(rejoinLeft)
	else
		_G.atlasAutomationStatus = ""
	end
end

local function hopNow()
	local ok, body = pcall(function()
		return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100")
	end)
	if not ok or type(body) ~= "string" then return end
	local decoded
	pcall(function() decoded = HttpService:JSONDecode(body) end)
	local servers = decoded and decoded.data
	if type(servers) ~= "table" then return end
	local options = {}
	for _, server in ipairs(servers) do
		local playing = tonumber(server.playing) or 0
		local maxPlayers = tonumber(server.maxPlayers) or 0
		if server.id and server.id ~= game.JobId and playing < maxPlayers then table.insert(options, server.id) end
	end
	if #options == 0 then return end
	pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, options[math.random(1, #options)], player) end)
end

local function rejoinNow()
	pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
end

task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(1)
		local now = os.clock()
		local delta = now - last
		last = now
		if settings.hop then
			hopLeft -= delta
			if hopLeft <= 0 then hopLeft = settings.hopMin * 60; hopNow() end
		else
			hopLeft = settings.hopMin * 60
		end
		if settings.rejoin then
			rejoinLeft -= delta
			if rejoinLeft <= 0 then rejoinLeft = settings.rejoinMin * 60; rejoinNow() end
		else
			rejoinLeft = settings.rejoinMin * 60
		end
		setStatus()
	end
end)

task.spawn(function()
	while true do
		task.wait(2)
		if dirty then dirty = false; save() end
	end
end)

local function roots()
	local list = {}
	local ok, hidden = pcall(function() return gethui and gethui() or nil end)
	if ok and hidden then table.insert(list, hidden) end
	if _G.atlas then table.insert(list, _G.atlas) end
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then table.insert(list, playerGui) end
	pcall(function()
		local coreGui = game:GetService("CoreGui")
		for _, child in ipairs(coreGui:GetChildren()) do
			if child:IsA("ScreenGui") then table.insert(list, child) end
		end
	end)
	return list
end

local function normalized(object)
	if not object:IsA("TextLabel") and not object:IsA("TextButton") then return "" end
	return string.lower((object.Text or ""):match("^%s*(.-)%s*$")) or ""
end

local function containsText(root, target)
	for _, object in ipairs(root:GetDescendants()) do
		local text = normalized(object)
		if text == target then return true end
	end
	return false
end

-- The left column of the Debug page: contains Debug, Detected Features and Rares List,
-- but none of the Anti Lag toggles.
local function findLeftColumn()
	for _, root in ipairs(roots()) do
		for _, object in ipairs(root:GetDescendants()) do
			if normalized(object) == "rares list" then
				local ancestor, depth = object, 0
				while ancestor and depth < 8 do
					if ancestor:IsA("GuiObject")
						and containsText(ancestor, "detected features")
						and containsText(ancestor, "debug")
						and not containsText(ancestor, "hide tokens") then
						return ancestor
					end
					ancestor = ancestor.Parent
					depth += 1
				end
			end
		end
	end
	return nil
end

local function createToggle(parent, y, labelText, state, onChange)
	local button = Instance.new("TextButton")
	button.Position = UDim2.new(0, 4, 0, y)
	button.Size = UDim2.new(1, -8, 0, 22)
	button.BackgroundColor3 = state and Color3.fromRGB(46, 82, 58) or Color3.fromRGB(34, 34, 40)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.Code
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(235, 235, 235)
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Text = "  " .. labelText .. ": " .. (state and "ON" or "OFF")
	button.ZIndex = 41
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	local on = state
	button.MouseButton1Click:Connect(function()
		on = not on
		button.Text = "  " .. labelText .. ": " .. (on and "ON" or "OFF")
		button.BackgroundColor3 = on and Color3.fromRGB(46, 82, 58) or Color3.fromRGB(34, 34, 40)
		onChange(on)
	end)
end

local function createSlider(parent, y, labelText, minValue, maxValue, initial, onChange)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 6, 0, y)
	label.Size = UDim2.new(1, -12, 0, 12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = 10
	label.TextColor3 = Color3.fromRGB(215, 215, 215)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText .. ": " .. initial .. " min"
	label.ZIndex = 41
	label.Parent = parent

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 6, 0, y + 14)
	bar.Size = UDim2.new(1, -12, 0, 6)
	bar.BackgroundColor3 = Color3.fromRGB(52, 52, 60)
	bar.BorderSizePixel = 0
	bar.ZIndex = 41
	bar.Parent = parent
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale((initial - minValue) / math.max(maxValue - minValue, 1), 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 160, 240)
	fill.BorderSizePixel = 0
	fill.ZIndex = 41
	fill.Parent = bar
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill

	local current, dragging = initial, false
	local function applyX(x)
		local relative = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		local value = math.floor(minValue + (maxValue - minValue) * relative + 0.5)
		if value ~= current then
			current = value
			label.Text = labelText .. ": " .. value .. " min"
			fill.Size = UDim2.fromScale((value - minValue) / math.max(maxValue - minValue, 1), 1)
			onChange(value)
		end
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			applyX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			applyX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

task.spawn(function()
	local placed = false

	while true do
		task.wait(1)

		if placed then continue end

		local host = findLeftColumn()

		if host and not host:FindFirstChild(SECTION, true) then
			local section = Instance.new("Frame")
			section.Name = SECTION
			section.BackgroundTransparency = 1

			if host:FindFirstChildOfClass("UIListLayout") then
				section.LayoutOrder = 10000
				section.Size = UDim2.new(1, 0, 0, 140)
			else
				local bottom = 0
				for _, child in ipairs(host:GetChildren()) do
					if child:IsA("GuiObject") then
						local childBottom = child.Position.Y.Offset + child.Size.Y.Offset
						if childBottom > bottom then bottom = childBottom end
					end
				end
				section.Position = UDim2.new(0, 0, 0, bottom + 10)
				section.Size = UDim2.new(1, 0, 0, 140)
			end

			section.Parent = host

			local header = Instance.new("TextLabel")
			header.Position = UDim2.new(0, 6, 0, 0)
			header.Size = UDim2.new(1, -12, 0, 16)
			header.BackgroundTransparency = 1
			header.Font = Enum.Font.Code
			header.TextSize = 12
			header.TextColor3 = Color3.fromRGB(255, 255, 255)
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.Text = "Auto Server Hop / Rejoin"
			header.ZIndex = 41
			header.Parent = section

			createToggle(section, 18, "Auto Server Hop", settings.hop, function(state)
				settings.hop = state
				hopLeft = settings.hopMin * 60
				dirty = true
				setStatus()
			end)

			createSlider(section, 44, "Hop every", 1, 60, settings.hopMin, function(value)
				settings.hopMin = value
				hopLeft = value * 60
				dirty = true
			end)

			createToggle(section, 70, "Auto Rejoin", settings.rejoin, function(state)
				settings.rejoin = state
				rejoinLeft = settings.rejoinMin * 60
				dirty = true
				setStatus()
			end)

			createSlider(section, 96, "Rejoin every", 1, 60, settings.rejoinMin, function(value)
				settings.rejoinMin = value
				rejoinLeft = value * 60
				dirty = true
			end)

			local status = Instance.new("TextLabel")
			status.Position = UDim2.new(0, 6, 0, 122)
			status.Size = UDim2.new(1, -12, 0, 12)
			status.BackgroundTransparency = 1
			status.Font = Enum.Font.Code
			status.TextSize = 10
			status.TextColor3 = Color3.fromRGB(160, 200, 160)
			status.TextXAlignment = Enum.TextXAlignment.Left
			status.Text = ""
			status.ZIndex = 41
			status.Parent = section

			if host:IsA("ScrollingFrame") then
				pcall(function()
					local needed = section.Position.Y.Offset + 150
					if host.CanvasSize.Y.Offset < needed then
						host.CanvasSize = UDim2.new(host.CanvasSize.X.Scale, host.CanvasSize.X.Offset, 0, needed)
					end
				end)
			end

			placed = true

			task.spawn(function()
				while true do
					task.wait(1)
					pcall(function() status.Text = _G.atlasAutomationStatus or "" end)
				end
			end)
		end
	end
end)
