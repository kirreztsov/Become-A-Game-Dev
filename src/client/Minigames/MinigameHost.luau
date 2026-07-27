-- One Host per station panel. Inits every registered variant for that
-- station (each builds its own hidden UI once, under `panel`), then swaps
-- between them as the server picks a variant per round via `show`. Owns no
-- round logic itself -- it just hides the previous variant and hands off to
-- the named one, and wires every variant's `report` callback to the single
-- ReportMinigameInput remote.
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.MinigameRegistry)

local Host = {}
Host.__index = Host

function Host.new(station, panel, theme)
	local self = setmetatable({ station = station, active = nil, variants = {} }, Host)
	for _, v in ipairs(Registry.forStation(station) or {}) do
		v.init(panel, theme, function(value)
			Remotes.ReportMinigameInput:FireServer(value)
		end)
		v.hide()
		self.variants[v.id] = v
	end
	return self
end

function Host:show(variantId, difficulty, params, roundInfo)
	if self.active and self.active ~= variantId and self.variants[self.active] then
		self.variants[self.active].hide()
	end
	self.active = variantId
	local v = self.variants[variantId]
	if v then
		v.startRound(difficulty, params, roundInfo)
	end
end

function Host:hide()
	if self.active and self.variants[self.active] then
		self.variants[self.active].hide()
	end
	self.active = nil
end

return Host
