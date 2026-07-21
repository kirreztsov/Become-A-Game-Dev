local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
	"RequestStartDevelopment",
	"PhaseStarted",
	"RoundStarted",
	"ReportTap",
	"ReportPlacement",
	"ReportChoice",
	"RoundComplete",
	"PhaseComplete",
	"DevelopmentComplete",
	"RequestHireWorker",
	"RequestUpgradeWorker",
	"WorkerActionResult",
	"RequestUpgradeHouse",
	"HouseActionResult",
	"PlayerStateUpdated",
	"TrendsUpdated",
}

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage

	for _, name in ipairs(REMOTE_NAMES) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in ipairs(REMOTE_NAMES) do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
