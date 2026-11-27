-- Stable Altas entry. This URL never needs to change again:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/run.lua"))()

local BASE = "https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/altas.lua"
local TOPIC = "altasdiag-rust96-9c41"
local COUNTER = "https://api.counterapi.dev/v1/altasdiag-rust96/run/up"

local function notify(text)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Altas", Text = tostring(text), Duration = 8 })
	end)
end

-- GET ping: works even in executors without request/POST support.
pcall(function()
	game:HttpGet(COUNTER)
end)

local function publish(message)
	pcall(function()
		local body = game:GetService("HttpService"):JSONEncode({ topic = TOPIC, message = string.sub(message, 1, 3500) })
		local requestFn = request or (syn and syn.request) or http_request or httprequest

		if type(requestFn) == "function" then
			requestFn({
				Url = "https://ntfy.sh",
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json" },
				Body = body,
			})
		end
	end)
end

publish("loader start " .. tostring(os.time()))

local url = BASE .. "?v=" .. tostring(os.time()) .. tostring(math.random(100000, 999999))
local ok, source = pcall(function()
	return game:HttpGet(url)
end)

if not ok or type(source) ~= "string" or #source < 100 then
	notify("loader download failed: " .. tostring(source))
	publish("download failed: " .. tostring(source))
	return
end

task.delay(12, function()
	pcall(function()
		local roots = {}
		local okHidden, hidden = pcall(function()
			return gethui and gethui() or nil
		end)

		if okHidden and hidden then
			table.insert(roots, hidden)
		end

		if _G.atlas then
			table.insert(roots, _G.atlas)
		end

		local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")

		if playerGui then
			table.insert(roots, playerGui)
		end

		pcall(function()
			local coreGui = game:GetService("CoreGui")
			for _, child in ipairs(coreGui:GetChildren()) do
				if child:IsA("ScreenGui") then
					table.insert(roots, child)
				end
			end
		end)

		local lines = {}

		for _, root in ipairs(roots) do
			for _, object in ipairs(root:GetDescendants()) do
				if object:IsA("GuiButton") or object:IsA("ScrollingFrame") then
					local text = object:IsA("GuiButton") and (object.Text or "") or ""
					table.insert(lines, object.ClassName .. "\t" .. object.Name .. "\t" .. string.sub(text, 1, 40) .. "\t" .. tostring(object.Visible))

					if #lines >= 150 then
						break
					end
				end
			end

			if #lines >= 150 then
				break
			end
		end

		publish("UI " .. #lines .. "\n" .. table.concat(lines, "\n"))
	end)
end)

local chunk, err = loadstring(source)

if not chunk then
	notify("loader compile error: " .. tostring(err))
	publish("compile error: " .. tostring(err))
	return
end

notify("Altas loaded at " .. tostring(os.time()))
publish("altas executed " .. tostring(os.time()))
chunk()
