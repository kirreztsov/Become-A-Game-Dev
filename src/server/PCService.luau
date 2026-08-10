local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PCVisuals = require(game.ReplicatedStorage.Shared.PCVisuals)
local Players = game:GetService("Players")

local PCService = {}

-- Per-visit deal the PC Store shopkeeper is offering each player, keyed by
-- UserId: { partId = <id>, discount = <fraction> }. Re-rolled every time the
-- player opens the store (RequestPCStore); the discount applies to buys of that
-- part while it's set, and is validated server-side so it can't be spoofed.
local currentDeal = {}
local DEAL_CHANCE = 0.5
local DEAL_DISCOUNTS = { 0.20, 0.25, 0.30, 0.40 }

-- Reserved-but-not-yet-installed upgrades, keyed by Player:
-- { partId = <id>, cost = <number>, targetLevel = <number> }. In-memory only.
local pendingInstall = {}

local function rollDeal(data)
	if math.random() > DEAL_CHANCE then
		return nil
	end
	-- Only offer a deal on a part that isn't already maxed (so it's useful).
	local candidates = {}
	for _, p in ipairs(GameData.PCParts) do
		if (data.pcParts[p.id] or 0) < GameData.getPCPartMaxLevel(p.id) then
			candidates[#candidates + 1] = p.id
		end
	end
	if #candidates == 0 then
		return nil
	end
	return {
		partId = candidates[math.random(#candidates)],
		discount = DEAL_DISCOUNTS[math.random(#DEAL_DISCOUNTS)],
	}
end

--- Pure buy check. Returns (ok, cost, targetLevel) without mutating `data`.
--- `deal` is nil or { partId = <id>, discount = <fraction> }.
function PCService.reserveDecision(data, partId, deal)
	local part = GameData.getPCPart(partId)
	if not part then
		return false
	end
	local level = (data.pcParts and data.pcParts[partId]) or 0
	if level >= GameData.getPCPartMaxLevel(partId) then
		return false
	end
	local cost = GameData.getPCPartUpgradeCost(partId, level)
	if not cost then
		return false
	end
	if deal and deal.partId == partId then
		cost = math.floor(cost * (1 - deal.discount))
	end
	if (data.cash or 0) < cost then
		return false
	end
	return true, cost, level + 1
end

--- Re-validate a reserved install and, on success, apply it (mutates `data`).
--- `pending` is { partId, cost, targetLevel }. Returns true if applied.
function PCService.applyInstall(data, pending)
	data.pcParts = data.pcParts or {}
	local level = data.pcParts[pending.partId] or 0
	if level ~= pending.targetLevel - 1 then
		return false
	end
	if (data.cash or 0) < pending.cost then
		return false
	end
	data.cash -= pending.cost
	data.pcParts[pending.partId] = pending.targetLevel
	return true
end

function PCService.start()
	-- Opening the PC Store (walk up to the shopkeeper): roll a fresh per-visit
	-- deal and tell the client so it can highlight the discounted part.
	Remotes.RequestPCStore.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		data.pcParts = data.pcParts or {}
		local deal = rollDeal(data)
		currentDeal[player.UserId] = deal
		Remotes.PCStoreOpen:FireClient(player, deal and deal.partId or nil, deal and deal.discount or nil)
	end)

	-- Buy the next model of a part: validate + RESERVE it (no charge yet), then
	-- launch the install minigame. The upgrade is applied on PCInstallComplete.
	Remotes.RequestUpgradePart.OnServerEvent:Connect(function(player, partId)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		data.pcParts = data.pcParts or {}
		if pendingInstall[player] then
			-- an install is already in flight; ignore
			Remotes.PCActionResult:FireClient(player, false)
			return
		end
		local deal = currentDeal[player.UserId]
		local ok, cost, targetLevel = PCService.reserveDecision(data, partId, deal)
		if not ok then
			Remotes.PCActionResult:FireClient(player, false)
			return
		end
		pendingInstall[player] = { partId = partId, cost = cost, targetLevel = targetLevel }
		local currentLevel = targetLevel - 1
		local oldTier = currentLevel > 0 and PCVisuals.getVisualTier(currentLevel) or nil
		local newTier = PCVisuals.getVisualTier(targetLevel)
		Remotes.PCInstallStart:FireClient(player, partId, oldTier, newTier)
	end)

	-- Correct install reported by the client: re-validate and apply.
	Remotes.PCInstallComplete.OnServerEvent:Connect(function(player, partId)
		local data = PlayerData.get(player)
		local pending = pendingInstall[player]
		if not data or not pending or pending.partId ~= partId then
			pendingInstall[player] = nil
			Remotes.PCActionResult:FireClient(player, false)
			return
		end
		local applied = PCService.applyInstall(data, pending)
		pendingInstall[player] = nil
		if not applied then
			Remotes.PCActionResult:FireClient(player, false)
			return
		end
		local RIG_VISUAL_PARTS = { Monitor = true, GPU = true, RGB = true, Cooling = true }
		if RIG_VISUAL_PARTS[partId] then
			local HomeService = require(script.Parent.HomeService)
			HomeService.rebuildHome(player)
		end
		Remotes.PCActionResult:FireClient(player, true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	-- Player cancelled or backed out: drop the reservation, nothing charged.
	Remotes.PCInstallCancel.OnServerEvent:Connect(function(player)
		pendingInstall[player] = nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingInstall[player] = nil
		currentDeal[player.UserId] = nil
	end)
end

return PCService
