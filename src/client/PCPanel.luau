-- Physical PC Store controller (no screen menu). Each shelf in the town PC
-- Store shows THIS player's next component + price on a floating label, and you
-- buy at the shelf's "Buy" prompt. Stepping into the store rolls the shopkeeper's
-- per-visit deal, which shows as a slashed SALE price on that shelf.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Sound = require(script.Parent.Sound)
local Fx = require(script.Parent.Fx)

local PCPanel = {}

local function withCommas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function PCPanel.init(player, theme, playerState)
	local myParts = (playerState and playerState.pcParts) or {}
	local myCash = (playerState and playerState.cash) or 0
	local dealPartId, dealDiscount = nil, nil
	local shelfLabels = {} -- [partId] = the shelf's floating TextLabel

	-- Fill every shelf's floating label from THIS player's state (client-set text
	-- is local, so each player sees their own next model / price / deal).
	local function updateShelves()
		for _, part in ipairs(GameData.PCParts) do
			local lbl = shelfLabels[part.id]
			if lbl then
				local level = myParts[part.id] or 0
				local maxLevel = GameData.getPCPartMaxLevel(part.id)
				local kindHex = (part.kind == "money") and "#7CE38B" or "#FFD166"
				if level >= maxLevel then
					local cur = GameData.getPCPartModel(part.id, level)
					lbl.Text = ("%s <b>%s</b>\n<font color=\"%s\" size=\"22\">%s</font>\n<font color=\"#B9BCC7\" size=\"20\">\226\156\148 MAXED</font>")
						:format(part.icon, part.name, kindHex, cur and cur.name or "")
				else
					local nextModel = GameData.getPCPartModel(part.id, level + 1)
					local cost = GameData.getPCPartUpgradeCost(part.id, level) or 0
					local priceStr
					if part.id == dealPartId and dealDiscount then
						local dc = math.floor(cost * (1 - dealDiscount))
						priceStr = ("<font color=\"#B9BCC7\" size=\"18\"><s>$%s</s></font>  <font color=\"#FF8A3D\">$%s \240\159\148\165-%d%%</font>")
							:format(withCommas(cost), withCommas(dc), math.floor(dealDiscount * 100 + 0.5))
					else
						local affordHex = (myCash >= cost) and "#FFFFFF" or "#FF7A7A"
						priceStr = ("<font color=\"%s\">$%s</font>"):format(affordHex, withCommas(cost))
					end
					lbl.Text = ("%s <b>%s</b>\n<font color=\"%s\" size=\"20\">%s</font>\n%s")
						:format(part.icon, part.name, kindHex, nextModel and nextModel.name or "?", priceStr)
				end
			end
		end
	end

	-- Locate the shelves (they replicate with the lobby); cache each label.
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 20)
		if not lobby then
			return
		end
		for _, part in ipairs(GameData.PCParts) do
			local ped
			for _ = 1, 100 do
				ped = lobby:FindFirstChild("PCShelf_" .. part.id)
				if ped then
					break
				end
				task.wait(0.2)
			end
			local bb = ped and ped:FindFirstChild("Info")
			local lbl = bb and bb:FindFirstChild("Text")
			if lbl then
				shelfLabels[part.id] = lbl
			end
		end
		updateShelves()
	end)

	-- Stepping into the store rolls a fresh shopkeeper deal (debounced).
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 20)
		local zone = lobby and lobby:WaitForChild("PCStoreZone", 20)
		if not zone then
			return
		end
		local lastRoll = 0
		zone.Touched:Connect(function(hit)
			local char = player.Character
			if char and hit:IsDescendantOf(char) and (os.clock() - lastRoll) > 4 then
				lastRoll = os.clock()
				Remotes.RequestPCStore:FireServer()
			end
		end)
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		if data then
			myParts = data.pcParts or myParts
			myCash = data.cash or myCash
		end
		updateShelves()
	end)

	Remotes.PCStoreOpen.OnClientEvent:Connect(function(partId, discount)
		dealPartId, dealDiscount = partId, discount
		updateShelves()
		if partId then
			Sound.play("PanelOpen")
		end
	end)

	Remotes.PCActionResult.OnClientEvent:Connect(function(success)
		if success then
			Sound.play("Purchase")
			local cam = workspace.CurrentCamera
			if cam then
				Fx.coinBurst(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.55, 7)
			end
		else
			Sound.play("Error")
		end
		-- The shelf labels refresh via the PlayerStateUpdated that follows a buy.
	end)

	-- Buy at a shelf: the prompt carries which part it sells.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer == player and prompt.Name == "PCBuyPrompt" then
			Remotes.RequestUpgradePart:FireServer(prompt:GetAttribute("PartId"))
		end
	end)
end

return PCPanel
