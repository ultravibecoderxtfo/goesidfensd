-- Altas 1.0 Modified by rust96
-- Entry point for the Altas source (main.lua) in this repository.
--
-- Applies:
--   * per-account config storage: atlas/accounts/<UserId>/
--   * window title: Altas 1.0 Modified by rust96
--   * background image, resolved before the UI is built
--   * walkspeed slider max 180, tween slider max 100
--   * tween speed clamp removed (not just unlocked)
--   * walk slider applies WalkSpeed on every change, up and down
--
-- Run (add ?v= to skip any cached copy):
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/altas.lua?v=6"))()

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

	if isWalkSpeed and maxNumber < 180 then
		maxValue = 180
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
local reason = "no source"

local cached = nil

pcall(function()
	if isfile and isfile(BG_FILE) then
		cached = readfile(BG_FILE)
	end
end)

if isPng(cached) then
	background = assetFromWorkspace()

	if background then
		reason = "cache, " .. #cached .. " bytes"
	else
		reason = "cache present, getcustomasset failed"
	end
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

				if background then
					reason = name .. ", " .. #data .. " bytes"
					break
				end

				reason = name .. ": getcustomasset failed"
			else
				reason = name .. ": writefile failed"
			end
		else
			reason = name .. ": " .. tostring(ok and "not a PNG" or data)
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
			reason = background and ("local file, " .. #data .. " bytes") or "local file: getcustomasset failed"
		else
			reason = "local file: writefile failed"
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

task.delay(8, function()
	local entries = _G.atlasSliderLog

	if type(entries) == "table" and #entries > 0 then
		notify("speed sliders: " .. table.concat(entries, " | "))
	else
		notify("no speed sliders were created")
	end
end)

notify("sliders=" .. (sliderPatched and ("x" .. sliderCount) or "NOT patched") .. " clamp=" .. (tweenClampPatched and "off" or "still on") .. " bg=" .. (background and "ok" or "fail"))

chunk()
