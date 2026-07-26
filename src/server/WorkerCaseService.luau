-- Worker cases: spin for a worker rarity.
--   Normal case  -> in-game cash (GameData.NormalCaseCost)
--   Lucky crate  -> Robux developer product (GameData.LuckyCaseProductId)
-- A roll is applied to a random worker slot, hiring it and upgrading its
-- rarity if the roll beats what's already there. Better rarity = the worker
-- finishes phases faster and earns more (see DevelopmentService).

local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlotManager = require(script.Parent.PlotManager)

local WorkerCaseService = {}

local WORKER_TYPES = { "Coding", "MapBuilding", "Testing" }

-- Apply a rolled rarity to a random worker slot (hire + upgrade-if-better).
-- Returns the worker type and the rarity that slot ended up at.
-- Roll a normal-case rarity, honouring the 50-spin pity (guaranteed >= Epic).
local function rollNormalWithPity(data)
	data.normalPity = (data.normalPity or 0) + 1
	if data.normalPity >= GameData.NormalPityThreshold then
		data.normalPity = 0
		return GameData.rollCase(GameData.NormalPityWeights)
	end
	return GameData.rollCase(GameData.NormalCaseWeights)
end

-- Roll a lucky-crate rarity, honouring the 10-spin pity (guaranteed Mythic).
local function rollLuckyWithPity(data)
	data.luckyPity = (data.luckyPity or 0) + 1
	if data.luckyPity >= GameData.LuckyPityThreshold then
		data.luckyPity = 0
		return "Mythic"
	end
	return GameData.rollCase(GameData.LuckyCaseWeights)
end

local function applyRoll(data, rarity)
	local workerType = WORKER_TYPES[math.random(1, #WORKER_TYPES)]
	local worker = data.workers[workerType]
	worker.hired = true
	local currentOrder = worker.rarity and GameData.RarityOrder[worker.rarity] or 0
	if GameData.RarityOrder[rarity] > currentOrder then
		worker.rarity = rarity
	end
	return workerType, worker.rarity
end

function WorkerCaseService.start()
	-- BUY a spin -> adds it to the player's stack (does NOT roll yet). The
	-- normal spin costs cash; the lucky spin is a Robux purchase (below).
	Remotes.RequestBuySpin.OnServerEvent:Connect(function(player, caseType)
		if caseType ~= "normal" then
			return -- lucky spins are bought via the Robux prompt -> ProcessReceipt
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		if data.cash < GameData.NormalCaseCost then
			Remotes.PlayerStateUpdated:FireClient(player, data)
			return
		end
		data.cash -= GameData.NormalCaseCost
		data.normalSpinsOwned = (data.normalSpinsOwned or 0) + 1
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	-- SPIN one stacked spin -> rolls (with pity) and applies to a worker.
	Remotes.RequestSpin.OnServerEvent:Connect(function(player, caseType)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local rarity
		if caseType == "normal" then
			if (data.normalSpinsOwned or 0) < 1 then
				return
			end
			data.normalSpinsOwned -= 1
			rarity = rollNormalWithPity(data)
		elseif caseType == "lucky" then
			if (data.luckySpinsOwned or 0) < 1 then
				return
			end
			data.luckySpinsOwned -= 1
			rarity = rollLuckyWithPity(data)
		else
			return
		end
		local workerType, finalRarity = applyRoll(data, rarity)
		Remotes.PlayerStateUpdated:FireClient(player, data)
		Remotes.CaseResult:FireClient(player, caseType, rarity, workerType, finalRarity)
		PlotManager.refreshWorkerNPCs(player)
	end)
end

-- Add stacked lucky spins (called by MonetizationService's central receipt
-- handler when a Lucky Crate Robux product is purchased).
function WorkerCaseService.grantLuckySpins(data, n)
	data.luckySpinsOwned = (data.luckySpinsOwned or 0) + (n or 0)
end

-- Directly grant a worker of a given rarity (e.g. the Starter Pack's Rare
-- worker). Hires a random slot, upgrading it if the rarity is better, then
-- refreshes the seated worker NPCs.
function WorkerCaseService.grantWorker(player, data, rarity)
	local workerType, finalRarity = applyRoll(data, rarity)
	PlotManager.refreshWorkerNPCs(player)
	return workerType, finalRarity
end

return WorkerCaseService
