-- Rebirth perk tree (roadmap A4). Each rebirth grants Prestige Points; players
-- spend them on permanent, stacking perks. Effects plug into the same economy
-- formulas as the game passes (cash / subs / worker-speed multipliers), plus a
-- flat head-start-cash bonus applied on rebirth. All logic here is pure so the
-- client can render the tree and the server can validate a buy from one source.
-- Tested in RunTests.
local PerkData = {}

PerkData.POINTS_PER_PRESTIGE = 1

-- kind drives which economy hook the perk feeds:
--   cash / subs / workerSpeed -> a (1 + level*value) multiplier
--   startCash               -> a flat (level*value) cash bonus on rebirth
PerkData.PERKS = {
	{ id = "p_cash", name = "Cash Boost", desc = "+10% cash from every game, forever", icon = "💰", kind = "cash", value = 0.10, maxLevel = 10, cost = 1 },
	{ id = "p_subs", name = "Fame Boost", desc = "+10% subscribers from every release", icon = "⭐", kind = "subs", value = 0.10, maxLevel = 10, cost = 1 },
	{ id = "p_speed", name = "Fast Hands", desc = "+8% worker speed", icon = "⚡", kind = "workerSpeed", value = 0.08, maxLevel = 5, cost = 1 },
	{ id = "p_headstart", name = "Head Start", desc = "Start each rebirth with +$1,000", icon = "🚀", kind = "startCash", value = 1000, maxLevel = 5, cost = 2 },
}

local byId = {}
for _, p in ipairs(PerkData.PERKS) do
	byId[p.id] = p
end

function PerkData.get(id)
	return byId[id]
end

function PerkData.level(data, id)
	return (data.perks or {})[id] or 0
end

-- Combined (1 + sum level*value) multiplier for all perks of a kind.
local function multiplierFor(data, kind)
	local m = 1
	for _, p in ipairs(PerkData.PERKS) do
		if p.kind == kind then
			m += PerkData.level(data, p.id) * p.value
		end
	end
	return m
end

function PerkData.cashMult(data)
	return multiplierFor(data, "cash")
end

function PerkData.subsMult(data)
	return multiplierFor(data, "subs")
end

function PerkData.speedMult(data)
	return multiplierFor(data, "workerSpeed")
end

-- Flat cash a player starts a fresh rebirth with, from Head Start perks.
function PerkData.startCashBonus(data)
	local bonus = 0
	for _, p in ipairs(PerkData.PERKS) do
		if p.kind == "startCash" then
			bonus += PerkData.level(data, p.id) * p.value
		end
	end
	return bonus
end

function PerkData.isMaxed(data, id)
	local p = byId[id]
	return p ~= nil and PerkData.level(data, id) >= p.maxLevel
end

-- Can the player buy one more level of this perk right now?
function PerkData.canBuy(data, id)
	local p = byId[id]
	if not p then
		return false
	end
	if PerkData.level(data, id) >= p.maxLevel then
		return false
	end
	return (data.perkPoints or 0) >= p.cost
end

-- Buy one level: deduct points, bump the level. Pure; caller saves. Returns
-- true on success, false if it couldn't be bought.
function PerkData.applyBuy(data, id)
	if not PerkData.canBuy(data, id) then
		return false
	end
	local p = byId[id]
	data.perks = data.perks or {}
	data.perks[id] = (data.perks[id] or 0) + 1
	data.perkPoints = (data.perkPoints or 0) - p.cost
	return true
end

-- Render list for the client.
function PerkData.list(data)
	local out = {}
	for i, p in ipairs(PerkData.PERKS) do
		local lvl = PerkData.level(data, p.id)
		out[i] = {
			id = p.id,
			name = p.name,
			desc = p.desc,
			icon = p.icon,
			level = lvl,
			maxLevel = p.maxLevel,
			cost = p.cost,
			maxed = lvl >= p.maxLevel,
			affordable = (data.perkPoints or 0) >= p.cost,
		}
	end
	return out
end

return PerkData
