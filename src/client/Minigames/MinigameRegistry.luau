-- Indexes every mini-game "variant" module by station and by id so a
-- MinigameHost can look up which variants to init/show for its station. Add
-- new variants to ALL below as their tasks migrate them in.
local Coding = script.Parent.Coding
local MapBuilding = script.Parent.MapBuilding
local Testing = script.Parent.Testing

local ALL = {
	require(Coding.CodeSprint),
	require(Coding.BugSquash),
	require(MapBuilding.PrecisionPlace),
	require(Testing.QAQuiz),
	-- later tasks append: KeyCombo, CompileCheck, BlueprintMemory,
	-- TileDrop, PathConnect, BugHunt, PassOrFail, CrashFix
}

local Registry = { byStation = {}, byId = {} }
for _, v in ipairs(ALL) do
	Registry.byStation[v.station] = Registry.byStation[v.station] or {}
	table.insert(Registry.byStation[v.station], v)
	Registry.byId[v.id] = v
end

function Registry.get(id)
	return Registry.byId[id]
end

function Registry.forStation(station)
	return Registry.byStation[station]
end

return Registry
