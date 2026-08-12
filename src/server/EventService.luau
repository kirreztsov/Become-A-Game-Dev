-- Server side of the Sunday Showdown event (roadmap B2). Mirrors
-- ChallengeService: roll each player onto the current Sunday arc (snapshot the
-- baseline + clear claims) on join and across the day boundary, and handle a
-- sequential CLAIM. Claims are Sunday-gated (server-authoritative) and re-check
-- completion via EventData. Finishing the final quest grants a random Champion
-- PC part (or scaled consolation cash when all 7 are already collected).
local Players = game:GetService("Players")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local EventData = require(game.ReplicatedStorage.Shared.EventData)
local PlayerData = require(script.Parent.PlayerData)

local EventService = {}

-- Roll a player onto today's arc if their stored event day is stale; push an
-- update if so.
local function rollover(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if EventData.rolloverIfNeeded(data, EventData.dayIndex(os.time())) then
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end
end

function EventService.start()
	Remotes.RequestClaimEventQuest.OnServerEvent:Connect(function(player, index)
		-- Reject anything that isn't a real integer index: NaN (index ~= index),
		-- infinities, and fractional values all pass a bare type() check.
		if type(index) ~= "number" or index ~= index or index % 1 ~= 0 then
			return
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local now = os.time()
		-- The event only exists on Sundays; reject any off-day claim.
		if not EventData.isEventActive(now) then
			return
		end
		-- Make sure we're on today's arc before validating a claim.
		EventData.rolloverIfNeeded(data, EventData.dayIndex(now))
		local result = EventData.applyQuestClaim(data, index)
		if not result then
			return -- not complete, locked, already claimed, or bad index
		end
		if result.cash then
			data.cash += result.cash
			data.totalCashEarned = (data.totalCashEarned or 0) + result.cash
		end
		-- Finishing the final quest grants a random un-owned Champion part, or
		-- scaled consolation cash if the player has already collected all 7.
		if result.final then
			local partId, bonus = EventData.rollChampionPart(data)
			if partId then
				EventData.applyChampionGrant(data, partId, bonus)
			else
				local consolation = EventData.consolationCash(data)
				data.cash += consolation
				data.totalCashEarned = (data.totalCashEarned or 0) + consolation
			end
		end
		PlayerData.save(player)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	-- Roll over on join (once the player's data has loaded).
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			for _ = 1, 20 do
				if PlayerData.get(player) then
					break
				end
				task.wait(0.5)
			end
			rollover(player)
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			rollover(p)
		end)
	end

	-- Catch the day boundary for players who stay online across midnight.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, p in ipairs(Players:GetPlayers()) do
				rollover(p)
			end
		end
	end)
end

return EventService
