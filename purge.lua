-- Run once to delete every saved Atlas config and cache:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/ultravibecoderxtfo/goesidfensd/main/purge.lua"))()

local removed = 0

local function wipe(path)
	local ok, entries = pcall(listfiles, path)

	if ok and type(entries) == "table" then
		for _, entry in ipairs(entries) do
			if isfolder and isfolder(entry) then
				wipe(entry)
			elseif delfile and pcall(delfile, entry) then
				removed += 1
			end
		end
	end

	if delfolder then
		pcall(delfolder, path)
	end
end

wipe("atlas")

if listfiles then
	local ok, entries = pcall(listfiles, "")

	if ok and type(entries) == "table" then
		for _, entry in ipairs(entries) do
			if string.find(string.lower(entry), "atlascache", 1, true) and delfile then
				if pcall(delfile, entry) then removed += 1 end
			end
		end
	end
end

pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "Altas",
		Text = "configs deleted: " .. tostring(removed) .. " files",
		Duration = 10,
	})
end)

print("[Altas] configs deleted: " .. tostring(removed))
