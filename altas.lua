-- Altas 1.0 Modified by rust96
-- Entry point for the Altas source (main.lua) in this repository.
--
-- Applies:
--   * per-account config storage: atlas/accounts/<UserId>/
--   * window title: Altas 1.0 Modified by rust96 v13
--   * background image, resolved before the UI is built
--   * walkspeed slider max 90, tween slider max 100
--   * tween speed clamp removed (not just unlocked)
--   * walk slider applies WalkSpeed on every change, up and down
--   * black-screen anti-lag HUD with uptime, server uptime, honey, rate, heading
--   * auto server hop / rejoin, driven from the debug console (no extra UI)
--
-- Run (add ?v= to skip any cached copy):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/altas.lua?v=13"))()
--
-- HUD: opens when you click "Disable 3rd Rendering", or press RightShift.
--
-- Debug console:
--   _G.atlasAutomation.hop(10)      auto server hop every 10 min
--   _G.atlasAutomation.rejoin(10)   auto rejoin every 10 min
--   _G.atlasAutomation.stopHop()    _G.atlasAutomation.stopRejoin()
--   _G.atlasAutomation.status()
--   _G.atlasHud(true)               show the black-screen HUD now, false hides it

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
	local UserInputService = game:GetService("UserInputService")
	local player = Players.LocalPlayer
	local sessionStart = os.clock()

	local gui = Instance.new("ScreenGui")
	gui.Name = "AltasAntiLagHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.Enabled = false

	pcall(function()
		gui.Parent = gethui and gethui() or game:GetService("CoreGui")
	end)

	if not gui.Parent then
		pcall(function()
			gui.Parent = game:GetService("CoreGui")
		end)
	end

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

	addLabel("Altas 1.0 - Anti-Lag v13 (RightShift)", 14, Color3.fromRGB(255, 255, 255))
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

	local function hiddenRoot()
		local ok, value = pcall(function()
			return gethui and gethui() or nil
		end)

		if ok then
			return value
		end

		return nil
	end

	local function candidateRoots()
		local roots = {}
		local seen = {}

		local function add(root)
			if root and not seen[root] then
				seen[root] = true
				table.insert(roots, root)
			end
		end

		add(hiddenRoot())
		add(_G.atlas)

		local ok, coreGui = pcall(function()
			return game:GetService("CoreGui")
		end)

		if ok and coreGui then
			for _, child in ipairs(coreGui:GetChildren()) do
				if child:IsA("ScreenGui") then
					add(child)
				end
			end
		end

		local playerGui = player:FindFirstChild("PlayerGui")

		if playerGui then
			for _, child in ipairs(playerGui:GetChildren()) do
				if child:IsA("ScreenGui") then
					add(child)
				end
			end
		end

		return roots
	end

	local function lastConsoleLine()
		for _, root in ipairs(candidateRoots()) do
			local bar = nil

			for _, object in ipairs(root:GetDescendants()) do
				if object:IsA("TextLabel") and object.Text == "Atlas Console" then
					bar = object
					break
				end
			end

			if bar and bar.Parent and bar.Parent.Parent then
				local scrolling = nil

				for _, object in ipairs(bar.Parent.Parent:GetDescendants()) do
					if object:IsA("ScrollingFrame") then
						scrolling = object
						break
					end
				end

				if scrolling then
					local text = nil

					for _, child in ipairs(scrolling:GetChildren()) do
						if child:IsA("TextLabel") and #child.Text > 0 then
							text = child.Text
						end
					end

					if text then
						text = string.gsub(text, "^%[[^%]]*%] %[[^%]]*%] ", "")
						return text
					end
				end
			end
		end

		return nil
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
		rows.auto.Text = _G.atlasAutomationStatus or ""

		local heading = lastConsoleLine()
		rows.heading.Text = "Heading: " .. (heading and string.sub(heading, 1, 42) or "-")
	end

	local function isBlackFullScreen(object)
		if not object:IsA("Frame") or not object.Visible or object.BackgroundTransparency > 0.05 then
			return false
		end

		if object:IsDescendantOf(gui) then
			return false
		end

		local color = object.BackgroundColor3

		if color.R > 0.03 or color.G > 0.03 or color.B > 0.03 then
			return false
		end

		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
		local size = object.AbsoluteSize

		return size.X >= viewport.X * 0.98 and size.Y >= viewport.Y * 0.98
	end

	local function blackScreenShowing()
		for _, root in ipairs(candidateRoots()) do
			for _, object in ipairs(root:GetDescendants()) do
				if isBlackFullScreen(object) then
					return true
				end
			end
		end

		return false
	end

	local manual = nil
	local hookVisible = false
	local autoVisible = false

	local function apply()
		local visible

		if manual ~= nil then
			visible = manual
		else
			visible = hookVisible or autoVisible
		end

		gui.Enabled = visible and true or false

		if gui.Enabled then
			pcall(refresh)
		end
	end

	HUD = {}
	HUD.gui = gui
	HUD.setHook = function(enabled)
		hookVisible = not enabled
		apply()
	end

	_G.atlasHud = function(visible)
		manual = visible
		apply()
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if input.KeyCode == Enum.KeyCode.RightShift then
			manual = not gui.Enabled
			apply()
		end
	end)

	-- Attach to the real "Disable 3rd Rendering" control: clicking it toggles this HUD.
	local watched = {}

	local function connectRenderingToggle()
		for _, root in ipairs(candidateRoots()) do
			for _, object in ipairs(root:GetDescendants()) do
				local text = nil

				if object:IsA("TextLabel") or object:IsA("TextButton") then
					text = string.lower(object.Text or "")
				end

				if text and (string.find(text, "3rd rendering", 1, true) or string.find(text, "3d rendering", 1, true)) then
					local clickable = object
					local depth = 0

					while clickable and not clickable:IsA("GuiButton") and depth < 6 do
						clickable = clickable.Parent
						depth += 1
					end

					if clickable and clickable:IsA("GuiButton") and not watched[clickable] then
						watched[clickable] = true

						clickable.MouseButton1Click:Connect(function()
							manual = not gui.Enabled
							apply()
						end)
					end
				end
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(2)
			pcall(connectRenderingToggle)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)

			if manual == nil then
				local ok, detected = pcall(blackScreenShowing)

				if ok then
					autoVisible = detected
					apply()
				end
			end
		end
	end)

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

	local hopRemaining = settings.hopMinutes * 60
	local rejoinRemaining = settings.rejoinMinutes * 60

	local function clock(seconds)
		seconds = math.max(0, math.floor(seconds))
		return string.format("%02d:%02d", seconds // 60, seconds % 60)
	end

	local function setStatus()
		if settings.hopEnabled and settings.rejoinEnabled then
			_G.atlasAutomationStatus = "Hop " .. clock(hopRemaining) .. "  Rejoin " .. clock(rejoinRemaining)
		elseif settings.hopEnabled then
			_G.atlasAutomationStatus = "Hop in " .. clock(hopRemaining)
		elseif settings.rejoinEnabled then
			_G.atlasAutomationStatus = "Rejoin in " .. clock(rejoinRemaining)
		else
			_G.atlasAutomationStatus = ""
		end
	end

	local function startHop(minutes)
		settings.hopMinutes = math.clamp(tonumber(minutes) or settings.hopMinutes or 10, 1, 60)
		settings.hopEnabled = true
		hopRemaining = settings.hopMinutes * 60
		dirty = true
		setStatus()
		notify("auto server hop every " .. settings.hopMinutes .. " min")
	end

	local function stopHop()
		settings.hopEnabled = false
		dirty = true
		setStatus()
		notify("auto server hop off")
	end

	local function startRejoin(minutes)
		settings.rejoinMinutes = math.clamp(tonumber(minutes) or settings.rejoinMinutes or 10, 1, 60)
		settings.rejoinEnabled = true
		rejoinRemaining = settings.rejoinMinutes * 60
		dirty = true
		setStatus()
		notify("auto rejoin every " .. settings.rejoinMinutes .. " min")
	end

	local function stopRejoin()
		settings.rejoinEnabled = false
		dirty = true
		setStatus()
		notify("auto rejoin off")
	end

	_G.atlasAutomation = {
		hop = startHop,
		stopHop = stopHop,
		rejoin = startRejoin,
		stopRejoin = stopRejoin,
		status = function()
			return {
				hopEnabled = settings.hopEnabled,
				hopMinutes = settings.hopMinutes,
				rejoinEnabled = settings.rejoinEnabled,
				rejoinMinutes = settings.rejoinMinutes,
			}
		end,
	}

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

			setStatus()
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

	print("[Altas] debug: _G.atlasAutomation.hop(10) | .rejoin(10) | .stopHop() | .stopRejoin() | .status()")
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
local set3d = nil

pcall(function()
	set3d = runService.Set3dRenderingEnabled
end)

if type(hookfunction) == "function" and type(set3d) == "function" then
	pcall(function()
		local original
		original = hookfunction(set3d, function(self, enabled, ...)
			HUD.setHook(enabled)
			return original(self, enabled, ...)
		end)

		hudHooked = true
	end)
end

local source = game:HttpGet(SOURCE_URL)

if type(source) ~= "string" or #source < 1000 then
	return notify("main.lua download failed")
end

local dumpNotes = {}

local function dumpAround(marker, path, before, after)
	local index = string.find(source, marker, 1, true)

	if not index then
		return false
	end

	local first = math.max(1, index - (before or 2500))
	local last = math.min(#source, index + (after or 3500))
	local ok = pcall(writefile, path, "-- marker: " .. marker .. "\n" .. string.sub(source, first, last))

	if ok then
		table.insert(dumpNotes, path)
	end

	return ok
end

if type(writefile) == "function" then
	if not dumpAround("Disable 3rd Rendering", "atlas_antilag.txt", 3000, 4500) then
		if not dumpAround("3d Rendering", "atlas_antilag.txt", 3000, 4500) then
			dumpAround("3D Rendering", "atlas_antilag.txt", 3000, 4500)
		end
	end

	dumpAround('"Debug"', "atlas_debug.txt", 2000, 3500)
end

local titlePatched = false
source, titlePatched = replaceOnce(source, "local title = _G.title and", "local title = \"Altas 1.0 Modified by rust96 v13\" or _G.title and")

if not titlePatched then
	source, titlePatched = replaceOnce(source, "\"deobfuscated by skynex - .gg/syncrypt\"", "\"Altas 1.0 Modified by rust96 v13\"")
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

notify("Altas v13 loaded | RightShift = HUD | dumps: " .. (#dumpNotes > 0 and table.concat(dumpNotes, " ") or "none"))

chunk()
