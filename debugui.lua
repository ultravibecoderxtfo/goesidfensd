local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local SECTION = "AltasAutomationSection"
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

local hopLeft = settings.hopMin * 60
local rejoinLeft = settings.rejoinMin * 60

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
		if server.id and server.id ~= game.JobId and playing < maxPlayers then
			table.insert(options, server.id)
		end
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

local function createToggle(parent, y, labelText, state, onChange)
	local button = Instance.new("TextButton")
	button.Position = UDim2.new(0, 0, 0, y)
	button.Size = UDim2.new(1, 0, 0, 24)
	button.BackgroundColor3 = state and Color3.fromRGB(46, 82, 58) or Color3.fromRGB(30, 30, 34)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.Code
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(230, 230, 230)
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.Text = "  " .. labelText .. ": " .. (state and "ON" or "OFF")
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	local on = state
	button.MouseButton1Click:Connect(function()
		on = not on
		button.Text = "  " .. labelText .. ": " .. (on and "ON" or "OFF")
		button.BackgroundColor3 = on and Color3.fromRGB(46, 82, 58) or Color3.fromRGB(30, 30, 34)
		onChange(on)
	end)
end

local function createSlider(parent, y, labelText, minValue, maxValue, initial, onChange)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 0, 0, y)
	label.Size = UDim2.new(1, 0, 0, 14)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = 11
	label.TextColor3 = Color3.fromRGB(210, 210, 210)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText .. ": " .. initial .. " min"
	label.Parent = parent
	local bar = Instance.new("Frame")
	bar.Position = UDim2.new(0, 0, 0, y + 17)
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.BackgroundColor3 = Color3.fromRGB(50, 50, 56)
	bar.BorderSizePixel = 0
	bar.Parent = parent
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

local injected = false

local function build(page)
	if injected or not page or page:FindFirstChild(SECTION, true) then return end

	local section = Instance.new("Frame")
	section.Name = SECTION
	section.BackgroundTransparency = 1

	if page:FindFirstChildOfClass("UIListLayout") then
		section.LayoutOrder = 10000
		section.Size = UDim2.new(1, 0, 0, 176)
	else
		local bottom = 0
		for _, child in ipairs(page:GetChildren()) do
			if child:IsA("GuiObject") then
				local childBottom = child.Position.Y.Offset + child.Size.Y.Offset
				if childBottom > bottom then bottom = childBottom end
			end
		end
		section.Position = UDim2.new(0, 0, 0, bottom + 12)
		section.Size = UDim2.new(1, 0, 0, 176)
	end

	section.Parent = page

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 16)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.Code
	header.TextSize = 12
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "Auto Server Hop / Rejoin"
	header.Parent = section

	createToggle(section, 18, "Auto Server Hop", settings.hop, function(state)
		settings.hop = state
		hopLeft = settings.hopMin * 60
		dirty = true
		setStatus()
	end)

	createSlider(section, 46, "Hop every", 1, 60, settings.hopMin, function(value)
		settings.hopMin = value
		hopLeft = value * 60
		dirty = true
	end)

	createToggle(section, 78, "Auto Rejoin", settings.rejoin, function(state)
		settings.rejoin = state
		rejoinLeft = settings.rejoinMin * 60
		dirty = true
		setStatus()
	end)

	createSlider(section, 106, "Rejoin every", 1, 60, settings.rejoinMin, function(value)
		settings.rejoinMin = value
		rejoinLeft = value * 60
		dirty = true
	end)

	local status = Instance.new("TextLabel")
	status.Position = UDim2.new(0, 0, 0, 138)
	status.Size = UDim2.new(1, 0, 0, 14)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Code
	status.TextSize = 10
	status.TextColor3 = Color3.fromRGB(160, 200, 160)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = ""
	status.Parent = section

	if page:IsA("ScrollingFrame") then
		pcall(function()
			local needed = section.Position.Y.Offset + 196
			if page.CanvasSize.Y.Offset < needed then
				page.CanvasSize = UDim2.new(page.CanvasSize.X.Scale, page.CanvasSize.X.Offset, 0, needed)
			end
		end)
	end

	injected = true

	task.spawn(function()
		while true do
			task.wait(1)
			pcall(function() status.Text = _G.atlasAutomationStatus or "" end)
		end
	end)
end

local function hasButtons(page)
	for _, child in ipairs(page:GetDescendants()) do
		if child:IsA("GuiButton") then return true end
	end
	return false
end

local function pageForTab(button)
	local bar = button.Parent
	if not bar or not bar.Parent then return nil end

	local index, i = nil, 0
	for _, child in ipairs(bar:GetChildren()) do
		if child:IsA("GuiObject") then
			i += 1
			if child == button then index = i end
		end
	end

	if not index then return nil end

	for _, sibling in ipairs(bar.Parent:GetChildren()) do
		if sibling ~= bar and sibling:IsA("GuiObject") then
			local j, page = 0, nil
			for _, child in ipairs(sibling:GetChildren()) do
				if child:IsA("GuiObject") then
					j += 1
					if j == index then page = child end
				end
			end
			if page and (page:IsA("ScrollingFrame") or page:FindFirstChildOfClass("UIListLayout")) then
				return page
			end
		end
	end

	return nil
end

local pageVisible = {}

local function snapshot()
	for _, root in ipairs(roots()) do
		for _, object in ipairs(root:GetDescendants()) do
			if object:IsA("ScrollingFrame") or (object:IsA("Frame") and object:FindFirstChildOfClass("UIListLayout")) then
				pageVisible[object] = object.Visible
			end
		end
	end
end

local function tryPage(button)
	if injected then return end

	for _, root in ipairs(roots()) do
		for _, object in ipairs(root:GetDescendants()) do
			if (object:IsA("ScrollingFrame") or object:IsA("Frame"))
				and object.Visible
				and pageVisible[object] == false
				and hasButtons(object) then
				build(object)
				if injected then return end
			end
		end
	end

	local page = pageForTab(button)
	if page then build(page) end
	if injected then return end

	local best, area = nil, 0
	for _, root in ipairs(roots()) do
		for _, object in ipairs(root:GetDescendants()) do
			if object:IsA("ScrollingFrame") and object.Visible and hasButtons(object) then
				local size = object.AbsoluteSize.X * object.AbsoluteSize.Y
				if size > area then best, area = object, size end
			end
		end
	end

	if best then build(best) end
end

local watched = {}

local function watch()
	for _, root in ipairs(roots()) do
		for _, object in ipairs(root:GetDescendants()) do
			if object:IsA("GuiButton") and not watched[object] then
				local text = string.lower(object.Text or "")
				local isDebug = string.find(text, "debug", 1, true) ~= nil

				if not isDebug then
					for _, child in ipairs(object:GetChildren()) do
						if child:IsA("TextLabel") and string.find(string.lower(child.Text or ""), "debug", 1, true) then
							isDebug = true
							break
						end
					end
				end

				if isDebug then
					watched[object] = true
					object.MouseButton1Click:Connect(function()
						task.delay(0.45, function() pcall(tryPage, object) end)
					end)

					local page = pageForTab(object)
					if page and page.Visible then build(page) end
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.5)
		pcall(snapshot)
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		pcall(watch)
		if injected then break end
	end
end)
