local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlotManager = require(script.Parent.PlotManager)

local WorkerService = {}

function WorkerService.start()
	Remotes.RequestHireWorker.OnServerEvent:Connect(function(player, role)
		local data = PlayerData.get(player)
		if not data or not data.workers[role] then
			return
		end

		local worker = data.workers[role]
		if worker.hired then
			return
		end

		local hireCost = GameData.getWorkerHireCost(data.houseTier)
		if data.cash < hireCost then
			Remotes.WorkerActionResult:FireClient(player, role, "hire", false)
			return
		end

		data.cash -= hireCost
		worker.hired = true

		Remotes.WorkerActionResult:FireClient(player, role, "hire", true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
		PlotManager.refreshWorkerNPCs(player)
	end)

	Remotes.RequestUpgradeWorker.OnServerEvent:Connect(function(player, role)
		local data = PlayerData.get(player)
		if not data or not data.workers[role] then
			return
		end

		local worker = data.workers[role]
		if not worker.hired then
			return
		end

		local cost = GameData.getWorkerUpgradeCost(worker.level, data.houseTier)
		if data.cash < cost then
			Remotes.WorkerActionResult:FireClient(player, role, "upgrade", false)
			return
		end

		data.cash -= cost
		worker.level += 1

		Remotes.WorkerActionResult:FireClient(player, role, "upgrade", true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)
end

return WorkerService
