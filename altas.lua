local REPO = "https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/"
local NONCE = tostring(os.time()) .. tostring(math.random(1000, 9999))
local SOURCE_URL = REPO .. "main.lua?v=" .. NONCE

_G.background = ""
_G.unlocktween = true
if getgenv then pcall(function() getgenv().unlocktween = true end) end
if getrenv then pcall(function() getrenv().unlocktween = true end) end

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Altas", Text = tostring(text), Duration = 10 })
	end)
end

local function replaceOnce(source, needle, replacement)
	local index = string.find(source, needle, 1, true)
	if not index then return source, false end
	return string.sub(source, 1, index - 1) .. replacement .. string.sub(source, index + #needle), true
end

local function replaceAll(source, needle, replacement)
	local count, index = 0, 1
	while true do
		local start = string.find(source, needle, index, true)
		if not start then break end
		source = string.sub(source, 1, start - 1) .. replacement .. string.sub(source, start + #needle)
		index = start + #replacement
		count += 1
	end
	return source, count
end

-- Load the hop/rejoin UI module here too, so altas.lua works on its own.
pcall(function()
	local ui = game:HttpGet(REPO .. "debugui.lua?v=" .. NONCE)
	if type(ui) == "string" and #ui > 100 then
		local uiChunk = loadstring(ui)
		if uiChunk then pcall(uiChunk) end
	end
end)

local HUD

do
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local sessionStart = os.clock()

	local gui = Instance.new("ScreenGui")
	gui.Name = "AltasAntiLagHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.Enabled = false
	pcall(function() gui.Parent = gethui and gethui() or game:GetService("CoreGui") end)
	if not gui.Parent then pcall(function() gui.Parent = game:GetService("CoreGui") end) end

	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.Parent = gui

	local panel = Instance.new("Frame")
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
	addLabel("Altas 1.0 - Anti-Lag", 14, Color3.fromRGB(255, 255, 255))
	rows.uptime = addLabel("Uptime: 00:00:00")
	rows.server = addLabel("Server Uptime: 00:00:00")
	rows.honey = addLabel("Session Honey: 0")
	rows.rate = addLabel("Honey per Hour: 0")
	rows.heading = addLabel("Heading: -", 13, Color3.fromRGB(180, 220, 255))
	rows.auto = addLabel("", 12, Color3.fromRGB(190, 200, 150))

	local function formatTime(seconds)
		seconds = math.max(0, math.floor(tonumber(seconds) or 0))
		return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end

	local function formatNumber(value)
		value = tonumber(value) or 0
		local suffixes = { "", "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "O", "N" }
		local index, absolute = 1, math.abs(value)
		while absolute >= 1000 and index < #suffixes do
			absolute /= 1000
			value /= 1000
			index += 1
		end
		if index == 1 then return tostring(math.floor(value)) end
		return string.format("%.2f%s", value, suffixes[index])
	end

	local function currentHoney()
		local ok, value = pcall(function() return player.CoreStats.Honey.Value end)
		if ok and type(value) == "number" then return value end
		return nil
	end

	local honeyStart = currentHoney()

	local function candidateRoots()
		local roots, seen = {}, {}
		local function add(root)
			if root and not seen[root] then seen[root] = true; table.insert(roots, root) end
		end
		local ok, hidden = pcall(function() return gethui and gethui() or nil end)
		if ok then add(hidden) end
		add(_G.atlas)
		local okCore, coreGui = pcall(function() return game:GetService("CoreGui") end)
		if okCore and coreGui then
			for _, child in ipairs(coreGui:GetChildren()) do
				if child:IsA("ScreenGui") then add(child) end
			end
		end
		local playerGui = player:FindFirstChild("PlayerGui")
		if playerGui then
			for _, child in ipairs(playerGui:GetChildren()) do
				if child:IsA("ScreenGui") then add(child) end
			end
		end
		return roots
	end

	local function atlasScreen()
		for _, root in ipairs(candidateRoots()) do
			for _, object in ipairs(root:GetDescendants()) do
				if object:IsA("TextLabel") and string.find(object.Text or "", "Altas 1.0 Modified", 1, true) then
					local ancestor = object
					while ancestor do
						if ancestor:IsA("ScreenGui") then return ancestor, object end
						ancestor = ancestor.Parent
					end
				end
			end
		end
		return nil, nil
	end

	local function ensureAtlasScreen()
		local screen = atlasScreen()
		if screen and not screen.Enabled then screen.Enabled = true end
	end

	local function ensureAtlasWindow()
		local _, title = atlasScreen()
		if not title then return end
		local ancestor, depth = title.Parent, 0
		while ancestor and depth < 5 do
			if ancestor:IsA("GuiObject") and ancestor.AbsoluteSize.X > 280 and ancestor.AbsoluteSize.Y > 140 and not ancestor.Visible then
				ancestor.Visible = true
			end
			ancestor = ancestor.Parent
			depth += 1
		end
	end

	local function lastConsoleLine()
		for _, root in ipairs(candidateRoots()) do
			local bar = nil
			for _, object in ipairs(root:GetDescendants()) do
				if object:IsA("TextLabel") and object.Text == "Atlas Console" then bar = object; break end
			end
			if bar and bar.Parent and bar.Parent.Parent then
				local scrolling = nil
				for _, object in ipairs(bar.Parent.Parent:GetDescendants()) do
					if object:IsA("ScrollingFrame") then scrolling = object; break end
				end
				if scrolling then
					local text = nil
					for _, child in ipairs(scrolling:GetChildren()) do
						if child:IsA("TextLabel") and #child.Text > 0 then text = child.Text end
					end
					if text then return (string.gsub(text, "^%[[^%]]*%] %[[^%]]*%] ", "")) end
				end
			end
		end
		return nil
	end

	local function refresh()
		local session = os.clock() - sessionStart
		local honey = currentHoney()
		local gained = 0
		if honey and honeyStart then gained = honey - honeyStart end
		rows.uptime.Text = "Uptime: " .. formatTime(session)
		rows.server.Text = "Server Uptime: " .. formatTime(workspace.DistributedGameTime)
		rows.honey.Text = "Session Honey: " .. formatNumber(gained)
		rows.rate.Text = "Honey per Hour: " .. formatNumber(session > 5 and gained / (session / 3600) or 0)
		rows.auto.Text = _G.atlasAutomationStatus or ""
		local heading = lastConsoleLine()
		rows.heading.Text = "Heading: " .. (heading and string.sub(heading, 1, 42) or "-")
	end

	local manual, hookVisible = nil, false

	local function apply()
		local visible = manual ~= nil and manual or hookVisible
		gui.Enabled = visible and true or false
		if gui.Enabled then
			pcall(refresh)
			pcall(ensureAtlasWindow)
		end
	end

	HUD = { gui = gui }
	HUD.setHook = function(enabled)
		hookVisible = not enabled
		if enabled then manual = nil end
		apply()
	end

	local watched = {}
	local function attach(button)
		if not button or not button:IsA("GuiButton") or watched[button] then return end
		watched[button] = true
		button.MouseButton1Click:Connect(function()
			manual = not gui.Enabled
			apply()
		end)
	end

	local function matchesRenderingToggle(text)
		if not text then return false end
		return string.find(text, "render", 1, true) ~= nil
			and (string.find(text, "3rd", 1, true) ~= nil or string.find(text, "3d", 1, true) ~= nil or string.find(text, "disab", 1, true) ~= nil)
	end

	local function connectRenderingToggle()
		for _, root in ipairs(candidateRoots()) do
			for _, object in ipairs(root:GetDescendants()) do
				local text = nil
				if object:IsA("TextLabel") or object:IsA("TextButton") then text = string.lower(object.Text or "") end
				if matchesRenderingToggle(text) then
					attach(object)
					local ancestor, depth = object.Parent, 0
					while ancestor and depth < 4 do
						attach(ancestor)
						depth += 1
						ancestor = ancestor.Parent
					end
					if object.Parent then
						local buttons = {}
						for _, sibling in ipairs(object.Parent:GetDescendants()) do
							if sibling:IsA("GuiButton") then table.insert(buttons, sibling) end
						end
						if #buttons <= 6 then
							for _, button in ipairs(buttons) do attach(button) end
						end
					end
				end
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			pcall(connectRenderingToggle)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			pcall(ensureAtlasScreen)
			if gui.Enabled then pcall(refresh); pcall(ensureAtlasWindow) end
		end
	end)
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
		if type(path) ~= "string" then return path end
		local lowered = string.lower(path)
		if string.find(lowered, "atlas/accounts/", 1, true) then return path end
		if lowered == "atlas" then return configRoot end
		if string.sub(lowered, 1, 6) == "atlas/" then return configRoot .. "/" .. string.sub(path, 7) end
		if string.find(lowered, "atlas", 1, true) == 1 then return configRoot .. "/" .. path end
		return path
	end
	if rawMakeFolder then
		for _, folder in ipairs({ "atlas", "atlas/accounts", configRoot }) do
			if not (rawIsFolder and rawIsFolder(folder)) then pcall(rawMakeFolder, folder) end
		end
	end
	if rawList and rawRead and rawWrite and rawIsFile then
		local ok, entries = pcall(rawList, "atlas")
		if ok and type(entries) == "table" then
			for _, entry in ipairs(entries) do
				local lowered = string.lower(entry)
				if string.sub(lowered, -5) == ".json" and not string.find(lowered, "atlas/accounts", 1, true) and not string.find(lowered, "atlascache", 1, true) then
					local name = string.match(entry, "([^/\\]+)$")
					local sourcePath = entry
					if not string.find(lowered, "atlas", 1, true) then sourcePath = "atlas/" .. entry end
					if name and not rawIsFile(configRoot .. "/" .. name) then
						local readOk, data = pcall(rawRead, sourcePath)
						if readOk and type(data) == "string" and #data > 0 then pcall(rawWrite, configRoot .. "/" .. name, data) end
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
	if isWalkSpeed and maxNumber ~= 90 then maxValue = 90 end
	if isTweenSpeed and maxNumber < 100 then maxValue = 100 end
	if isWalkSpeed and callback then
		local userCallback = callback
		callback = function(newValue)
			userCallback(newValue)
			if cfg and cfg.vars and cfg.vars.walkspeedenabled then
				pcall(function()
					local character = game:GetService("Players").LocalPlayer.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid then humanoid.WalkSpeed = tonumber(newValue) or humanoid.WalkSpeed end
				end)
			end
		end
	end
]==]

local runService = game:GetService("RunService")
local set3d = nil
pcall(function() set3d = runService.Set3dRenderingEnabled end)
if type(hookfunction) == "function" and type(set3d) == "function" then
	pcall(function()
		local original
		original = hookfunction(set3d, function(self, enabled, ...)
			HUD.setHook(enabled)
			return original(self, enabled, ...)
		end)
	end)
end

local source = game:HttpGet(SOURCE_URL)
if type(source) ~= "string" or #source < 1000 then return notify("main.lua download failed") end

source = replaceOnce(source, "local title = _G.title and", "local title = \"Altas 1.0 Modified by rust96\" or _G.title and")
source = replaceOnce(source, "if cfg.vars.tweenspeed > 12 and _G.unlocktween ~= true then", "if false then")

local addSliderNeedle = "folderApi.AddSlider = function(sliderTitle, callback, minValue, maxValue, configSource, configKey, options)"
source = replaceAll(source, addSliderNeedle, addSliderNeedle .. "\n" .. sliderGuard)

source = configShim .. "\n" .. source

local chunk, compileError = loadstring(source)
if not chunk then return notify("compile error: " .. tostring(compileError)) end

notify("Altas loaded " .. NONCE)

local ok, runtimeError = pcall(chunk)
if not ok then
	notify("script error: " .. tostring(runtimeError))
	print("[Altas] script error: " .. tostring(runtimeError))
end
