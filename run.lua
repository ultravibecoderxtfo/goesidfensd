-- Stable Altas entry. This URL never needs to change again:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/run.lua"))()

local BASE = "https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/"
local NONCE = tostring(os.time()) .. tostring(math.random(100000, 999999))

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Altas", Text = tostring(text), Duration = 8 })
	end)
end

local function fetch(name)
	local ok, data = pcall(function()
		return game:HttpGet(BASE .. name .. "?v=" .. NONCE)
	end)

	if ok and type(data) == "string" and #data > 100 then
		return data
	end

	return nil
end

local ui = fetch("debugui.lua")

if ui then
	local uiChunk = loadstring(ui)

	if uiChunk then
		pcall(uiChunk)
	end
end

local source = fetch("altas.lua")

if not source then
	notify("altas.lua download failed")
	return
end

local chunk, err = loadstring(source)

if not chunk then
	notify("compile error: " .. tostring(err))
	return
end

notify("Altas loaded at " .. tostring(os.time()))
chunk()
