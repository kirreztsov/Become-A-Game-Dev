local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local LoungeService = {}

local function inZone(pos, zone)
	local o = zone.CFrame:PointToObjectSpace(pos)
	local h = zone.Size / 2
	return math.abs(o.X) <= h.X and math.abs(o.Y) <= h.Y and math.abs(o.Z) <= h.Z
end

function LoungeService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			local lobby = Workspace:FindFirstChild("Lobby")
			local zone = lobby and lobby:FindFirstChild("LoungeZone")
			if zone then
				for _, player in ipairs(Players:GetPlayers()) do
					pcall(function()
						local data = PlayerData.get(player)
						local char = player.Character
						local root = char and char:FindFirstChild("HumanoidRootPart")
						if data and root and data.passes and data.passes.VIPPlus and inZone(root.Position, zone) then
							data.cash += GameData.getLoungeRate(data)
							Remotes.PlayerStateUpdated:FireClient(player, data)
						end
					end)
				end
			end
		end
	end)
end

return LoungeService
