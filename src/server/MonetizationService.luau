-- Central monetization: owns the single MarketplaceService.ProcessReceipt for
-- ALL Robux developer products (Lucky Crates, Starter Pack, Mega Boost) and
-- handles game-pass ownership. Passes are permanent perks, re-verified from
-- Roblox on join; products are one-shot grants via the receipt handler.
--
-- Effects (2x Cash, VIP, Faster Workers, 2x Subs) are read in-memory from
-- data.passes by the GameData.getPass* helpers at the earning sites; this
-- service only records ownership + grants products.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local WorkerCaseService = require(script.Parent.WorkerCaseService)

local MonetizationService = {}

-- Resolve a real (non-zero) game-pass id to its GameData key.
local function passKeyForId(id)
	for key, info in pairs(GameData.GamePasses) do
		if id ~= 0 and info.id == id then
			return key
		end
	end
	return nil
end

-- VIP look: a "💎 VIP" nametag over the head + a replicated IsVIP attribute
-- (read by the client chat-tag handler). No body recolour -- players didn't
-- want their character's own colour changed.
local function applyVIPCosmetic(player)
	player:SetAttribute("IsVIP", true) -- drives the chat tag on all clients
	local char = player.Character
	if not char then
		return
	end
	local head = char:FindFirstChild("Head")
	if head and not head:FindFirstChild("VIPTag") then
		local bb = Instance.new("BillboardGui")
		bb.Name = "VIPTag"
		bb.Size = UDim2.fromOffset(74, 24)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = head
		bb.Parent = head
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = "\240\159\146\142 VIP"
		lbl.TextColor3 = Color3.fromRGB(240, 200, 90)
		lbl.TextStrokeTransparency = 0.3
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Parent = bb
	end
end

-- Record a pass as owned, apply its live effect, and update the client.
local function grantPass(player, data, key)
	data.passes[key] = true
	if key == "VIP" then
		applyVIPCosmetic(player)
	end
	Remotes.PlayerStateUpdated:FireClient(player, data)
end

-- One-time Starter Pack bundle: cash + a boost + a guaranteed Rare worker.
local function grantStarterPack(player, data)
	if data.starterPackBought then
		return
	end
	data.starterPackBought = true
	local sp = GameData.Products.StarterPack
	data.cash += sp.cash
	GameData.applyBoost(data, sp.boostMult, sp.boostDur, sp.icon, "Starter Pack", Workspace:GetServerTimeNow())
	WorkerCaseService.grantWorker(player, data, sp.worker)
end

-- Verify a player's owned passes from Roblox (id 0 = not created yet, skip).
local function refreshOwnedPasses(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local changed = false
	for key, info in pairs(GameData.GamePasses) do
		if info.id and info.id > 0 and not data.passes[key] then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.id)
			end)
			if ok and owns then
				data.passes[key] = true
				if key == "VIP" then
					applyVIPCosmetic(player)
				end
				changed = true
			end
		end
	end
	if changed then
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end
end

function MonetizationService.start()
	-- The ONE receipt handler for every Robux product.
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = PlayerData.get(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local id = receiptInfo.ProductId

		local luckyGrant = GameData.LuckyCaseProducts[id]
		if luckyGrant then
			WorkerCaseService.grantLuckySpins(data, luckyGrant)
			Remotes.PlayerStateUpdated:FireClient(player, data)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		if id ~= 0 and id == GameData.Products.StarterPack.id then
			grantStarterPack(player, data)
			Remotes.PlayerStateUpdated:FireClient(player, data)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		if id ~= 0 and id == GameData.Products.MegaBoost.id then
			local mb = GameData.Products.MegaBoost
			GameData.applyBoost(data, mb.boostMult, mb.boostDur, mb.icon, "Mega Boost", Workspace:GetServerTimeNow())
			Remotes.PlayerStateUpdated:FireClient(player, data)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Live game-pass purchase completes.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		if not wasPurchased then
			return
		end
		local key = passKeyForId(gamePassId)
		if not key then
			return
		end
		local data = PlayerData.get(player)
		if data then
			grantPass(player, data, key)
		end
	end)

	-- Verify ownership after the player's data has loaded (the server bootstrap
	-- loads it on PlayerAdded; we wait for it), and re-apply VIP on respawn.
	local function onPlayer(player)
		local waited = 0
		while not PlayerData.get(player) and player.Parent and waited < 15 do
			task.wait(0.2)
			waited += 0.2
		end
		refreshOwnedPasses(player)
		-- Ownership is now known; apply VIP to the current character (it may
		-- have spawned before the ownership check finished) and to any respawn.
		local function applyIfVIP()
			local data = PlayerData.get(player)
			if data and data.passes and data.passes.VIP then
				applyVIPCosmetic(player)
			end
		end
		local function applySpeed()
			local data = PlayerData.get(player)
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if data and hum and data.passes and data.passes.Speed2x then
				hum.WalkSpeed = GameData.GamePasses.Speed2x.walkSpeed
			end
		end
		if player.Character then
			applyIfVIP()
			applySpeed()
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			applyIfVIP()
			applySpeed()
		end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayer, p)
	end
	Players.PlayerAdded:Connect(function(p)
		task.spawn(onPlayer, p)
	end)
end

return MonetizationService
