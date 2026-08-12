-- Offline earnings (roadmap B3). While a player is away, their owned money rooms
-- earn 15% of their normal per-second income, up to a cap (2h + Deep Sleep perk
-- hours). Computed once at join from the loaded lastOnline stamp; granted on
-- Collect (server-authoritative -- the client's message carries no amount).
local Players = game:GetService("Players")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local PerkData = require(game.ReplicatedStorage.Shared.PerkData)
local PlayerData = require(script.Parent.PlayerData)
local PlotManager = require(script.Parent.PlotManager)

-- Fraction of a room's normal per-second income that keeps accruing while the
-- player is away. Deliberately well under half: coming back should feel like a
-- nice top-up, never a better way to earn than actually playing.
local OFFLINE_FRACTION = 0.15
local BASE_CAP_HOURS = 2

local OfflineEarnings = {}

-- Cash waiting to be collected this session, keyed by UserId. Cleared on Collect.
local pending = {}

local function computeFor(player)
	local data = PlayerData.get(player)
	if not data then
		return 0, 0
	end
	local last = data.lastOnline or 0
	if last <= 0 then
		return 0, 0 -- no baseline (new player / pre-feature save)
	end
	local elapsed = os.time() - last
	local capSeconds = 3600 * (BASE_CAP_HOURS + PerkData.offlineCapBonusHours(data))
	local ratePerSec = PlotManager.roomIncomePerSec(data)
		* OFFLINE_FRACTION
		* GameData.getPrestigeMultiplier(data.prestigeLevel or 0)
		* GameData.getPassCashMultiplier(data)
	local cash = GameData.getOfflineCash(ratePerSec, elapsed, capSeconds)
	return cash, math.clamp(elapsed, 0, capSeconds)
end

function OfflineEarnings.start()
	Remotes.CollectOfflineEarnings.OnServerEvent:Connect(function(player)
		local amount = pending[player.UserId]
		if not amount or amount <= 0 then
			return
		end
		pending[player.UserId] = nil
		local data = PlayerData.get(player)
		if not data then
			return
		end
		data.cash += amount
		PlayerData.save(player)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pending[player.UserId] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- Wait for this player's data to load (same pattern as ChallengeService).
			for _ = 1, 20 do
				if PlayerData.get(player) then
					break
				end
				task.wait(0.25)
			end
			local cash, seconds = computeFor(player)
			if cash > 0 then
				pending[player.UserId] = cash
				Remotes.OfflineEarningsReady:FireClient(player, cash, seconds)
			end
		end)
	end)
end

return OfflineEarnings
