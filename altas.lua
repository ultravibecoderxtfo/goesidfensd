-- Altas 1.0 Modified by rust96
-- Entry point for the Altas source (main.lua) in this repository.
--
-- Applied at load time:
--   * per-account config storage: atlas/accounts/<UserId>/
--   * one-time copy of existing global configs into that account folder
--   * window title: Altas 1.0 Modified by rust96
--   * background image: workspace cache -> repo background.png -> local PNG
--
-- Run:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/altas.lua"))()

local SOURCE_URL = "https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/main.lua"

local function replaceOnce(source, needle, replacement)
	local index = string.find(source, needle, 1, true)

	if not index then
		return source, false
	end

	return string.sub(source, 1, index - 1) .. replacement .. string.sub(source, index + #needle), true
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

local backgroundPatch = [==[
do
	local bgFile = "altas_bg.png"
	local bgRemote = "https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/background.png"
	local bgLocal = "/home/alex/Downloads/92132-972537-sweetie-fox-gamer.png"
	local asset = nil

	local function fileSize(path)
		local ok, data = pcall(readfile, path)

		if ok and type(data) == "string" then
			return #data
		end

		return 0
	end

	local cached = 0

	if isfile then
		pcall(function()
			if isfile(bgFile) then
				cached = fileSize(bgFile)
			end
		end)
	end

	if cached > 100 then
		local ok, result = pcall(getcustomasset, bgFile)

		if ok then
			asset = result
		end

		warn("[Altas] background: cached file, " .. cached .. " bytes")
	else
		local fetchOk, data = pcall(function()
			return game:HttpGet(bgRemote)
		end)

		if fetchOk and type(data) == "string" and #data > 100 then
			local writeOk = pcall(writefile, bgFile, data)

			warn("[Altas] background: downloaded " .. #data .. " bytes, write=" .. tostring(writeOk))

			if writeOk then
				local ok, result = pcall(getcustomasset, bgFile)

				if ok then
					asset = result
				end
			end
		else
			warn("[Altas] background: repo download failed (" .. tostring(data) .. ")")

			local localData = nil
			pcall(function()
				localData = readfile(bgLocal)
			end)

			if type(localData) == "string" and #localData > 100 then
				writefile(bgFile, localData)

				local ok, result = pcall(getcustomasset, bgFile)

				if ok then
					asset = result
				end

				warn("[Altas] background: copied local PNG, " .. #localData .. " bytes")
			else
				warn("[Altas] background: local PNG not readable")
			end
		end
	end

	if type(asset) ~= "string" or #asset == 0 then
		local ok, result = pcall(getcustomasset, bgLocal)

		if ok and type(result) == "string" and #result > 0 then
			asset = result
			warn("[Altas] background: getcustomasset accepted the absolute path")
		end
	end

	if type(asset) == "string" and #asset > 0 then
		_G.background = asset
	else
		warn("[Altas] background: unavailable, keeping the default window")
	end
end
]==]

local source = game:HttpGet(SOURCE_URL)

if type(source) ~= "string" or #source < 1000 then
	return warn("[Altas] failed to download main.lua")
end

local report = {}
local ok

source = configShim .. "\n" .. source
table.insert(report, "configs=per-account")

source, ok = replaceOnce(source, "local title = _G.title and", "local title = \"Altas 1.0 Modified by rust96\" or _G.title and")

if not ok then
	source, ok = replaceOnce(source, "\"deobfuscated by skynex - .gg/syncrypt\"", "\"Altas 1.0 Modified by rust96\"")
end

table.insert(report, ok and "title=patched" or "title=NOT patched")

local screenNeedle = "local ScreenGui = Instance.new(\"ScreenGui\")"
source, ok = replaceOnce(source, screenNeedle, backgroundPatch .. "\n" .. screenNeedle)
table.insert(report, ok and "background=patched" or "background=NOT patched")

local chunk, compileError = loadstring(source)

if not chunk then
	return warn("[Altas] compile error: " .. tostring(compileError))
end

warn("[Altas] " .. table.concat(report, " "))

chunk()
