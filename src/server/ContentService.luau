-- Server side of buying a paid genre/topic content unlock (A1) with CASH.
-- Robux unlocks are handled separately, by MonetizationService.ProcessReceipt.
-- Validate the id, that it's a cash unlock, that the player doesn't already
-- own it, and that they can afford it -- then deduct, mark owned, save, and
-- push state. No `loadFailed` guard: this is game cash and must work in
-- Studio, matching quests/challenges/event/daily.
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local PlayerData = require(script.Parent.PlayerData)

local ContentService = {}

function ContentService.start()
	Remotes.RequestBuyContent.OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" then
			return
		end

		local entry = GameData.ContentUnlocks[id]
		if not entry then
			return -- unknown id, or a free genre/topic (nothing to buy)
		end

		if not entry.price then
			return -- a Robux unlock, not a cash one -- buy via the Store instead
		end

		local data = PlayerData.get(player)
		if not data then
			return
		end

		if GameData.ownsContent(data, id) then
			return -- already owned; refuse before any deduction
		end

		if data.cash < entry.price then
			return -- can't afford it
		end

		data.cash -= entry.price
		data.contentOwned = data.contentOwned or {}
		data.contentOwned[id] = true

		PlayerData.save(player)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)
end

return ContentService
