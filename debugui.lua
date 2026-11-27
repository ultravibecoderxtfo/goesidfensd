local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local DOCK = "AltasHopDock"
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

local function findWindow()
	for _, root in ipairs(roots()) do
		for _, object in ipairs(root:GetDescendants()) do
			if object:IsA("TextLabel") and string.find(object.Text or "", "Altas 1.0 Modified", 1, true) then
				local best, area = nil, 0
				local ancestor, depth = object.Parent, 0
				while ancestor and depth < 6 do
					if ancestor:IsA("GuiObject") then
						local size = ancestor.AbsoluteSize.X * ancestor.AbsoluteSize.Y
						if ancestor.AbsoluteSize.X > 300 and size > area then best, area = ancestor, size end
					end
					ancestor = ancestor.Parent
					depth += 1
				end
				if best then return best end
			end
		end
	end
	return nil
end

local function toggleButton(parent, position, labelText, state, onChange)
	local button = Instance.new("TextButton")
	button.Position = position
	button.Size = UDim2.new(0.5, -6, 0, 22)
	button.BackgroundColor3 = state and Color3.fromRGB(46, 82, 58) or Color3.fromRGB(32, 32, 36)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.Code
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(235, 235, 235)
	button.Text = labelText .. ": " .. (state and "ON" or "OFF")
	button.ZIndex = 31
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	local on = state
	button.MouseButton1Click:Connect(function()
		on = not on
		button.Text = labelText .. ": " .. (on and "ON" or "OFF")
		button.BackgroundColor3 = on and Color3.fromRGB(46, 82, 58) or Color3.fromRGB(32, 32, 36)
		onChange(on)
	end)
end

local function slider(parent, y, labelText, minValue, maxValue, initial, onChange)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 4, 0, y)
	label.Size = UDim2.new(1, -8, 0, 12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = 10
	label.TextColor3 = Color3.fromRGB(215, 215, 215)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText .. ": " .. initial .. " min"
	label.ZIndex = 31
	label.Parent = parent

	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 4, 0, y + 14)
	bar.Size = UDim2.new(1, -8, 0, 5)
	bar.BackgroundColor3 = Color3.fromRGB(52, 52, 58)
	bar.BorderSizePixel = 0
	bar.ZIndex = 31
	bar.Parent = parent
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale((initial - minValue) / math.max(maxValue - minValue, 1), 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 170, 255)
	fill.BorderSizePixel = 0
	fill.ZIndex = 31
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
	local docked = false

	while true do
		task.wait(1)

		if docked then
			continue
		end

		local window = findWindow()

		if window and not window:FindFirstChild(DOCK) then
			local dock = Instance.new("Frame")
			dock.Name = DOCK
			dock.Position = UDim2.new(0, 0, 1, -104)
			dock.Size = UDim2.new(1, 0, 0, 100)
			dock.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
			dock.BackgroundTransparency = 0.08
			dock.BorderSizePixel = 0
			dock.ZIndex = 30
			dock.Parent = window

			toggleButton(dock, UDim2.new(0, 4, 0, 2), "Auto Hop", settings.hop, function(state)
				settings.hop = state
				hopLeft = settings.hopMin * 60
				dirty = true
				setStatus()
			end)

			toggleButton(dock, UDim2.new(0.5, 2, 0, 2), "Auto Rejoin", settings.rejoin, function(state)
				settings.rejoin = state
				rejoinLeft = settings.rejoinMin * 60
				dirty = true
				setStatus()
			end)

			slider(dock, 28, "Hop every", 1, 60, settings.hopMin, function(value)
				settings.hopMin = value
				hopLeft = value * 60
				dirty = true
			end)

			slider(dock, 52, "Rejoin every", 1, 60, settings.rejoinMin, function(value)
				settings.rejoinMin = value
				rejoinLeft = value * 60
				dirty = true
			end)

			local status = Instance.new("TextLabel")
			status.Position = UDim2.new(0, 4, 0, 78)
			status.Size = UDim2.new(1, -8, 0, 12)
			status.BackgroundTransparency = 1
			status.Font = Enum.Font.Code
			status.TextSize = 10
			status.TextColor3 = Color3.fromRGB(160, 200, 160)
			status.TextXAlignment = Enum.TextXAlignment.Left
			status.Text = ""
			status.ZIndex = 31
			status.Parent = dock

			docked = true

			task.spawn(function()
				while true do
					task.wait(1)
					pcall(function() status.Text = _G.atlasAutomationStatus or "" end)
				end
			end)
		end
	end
end)
