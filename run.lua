local BASE = "https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/"
local NONCE = tostring(os.time()) .. tostring(math.random(100000, 999999))

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Altas", Text = tostring(text), Duration = 8 })
	end)
end

local function roots()
	local list = {}
	local ok, hidden = pcall(function() return gethui and gethui() or nil end)
	if ok and hidden then table.insert(list, hidden) end
	if _G.atlas then table.insert(list, _G.atlas) end
	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
	if pg then table.insert(list, pg) end
	pcall(function()
		local cg = game:GetService("CoreGui")
		for _, child in ipairs(cg:GetChildren()) do
			if child:IsA("ScreenGui") then table.insert(list, child) end
		end
	end)
	return list
end

-- Keep stripping the background for the first 40 seconds of the session.
task.spawn(function()
	for _ = 1, 26 do
		task.wait(1.5)

		pcall(function()
			if isfile and isfile("altas_bg.png") and delfile then
				pcall(delfile, "altas_bg.png")
			end
		end)

		pcall(function()
			for _, root in ipairs(roots()) do
				for _, object in ipairs(root:GetDescendants()) do
					if object:IsA("ImageLabel") and object.Image ~= ""
						and object.AbsoluteSize.X > 250 and object.AbsoluteSize.Y > 180 then
						object.Image = ""
					end
				end
			end
		end)
	end
end)

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

notify("Altas loaded " .. NONCE)
chunk()
