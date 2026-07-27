local Workspace = game:GetService("Workspace")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local TrendMatch = require(game.ReplicatedStorage.Shared.TrendMatch)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local TrendsService = require(script.Parent.TrendsService)
local PlotManager = require(script.Parent.PlotManager)

local DevelopmentService = {}

local developing = {}
local activeRounds = {}
local lastVariantByStation = {}
local rng = Random.new()

local function isValidGenre(genre)
	return table.find(GameData.Genres, genre) ~= nil
end

local function isValidTopic(topic)
	return table.find(GameData.Topics, topic) ~= nil
end

local STATION_SEAT_NAMES = {
	Coding = "CodingSeat",
	MapBuilding = "MapBuildingSeat",
	Testing = "TestingSeat",
}

local SEAT_WAIT_TIMEOUT_SECONDS = 30

-- A player is "seated at" a station if they occupy ANY seat of that type in
-- their plot -- ground floor or any upper floor. Upper-floor seats are named
-- with a floor prefix (e.g. "F2_CodingSeat") and live inside the building
-- folder, so we scan all descendants and match by the seat-name suffix. This
-- is what lets you develop games on any floor, not just the ground floor.
local function isPlayerSeatedAt(player, seatName)
	local plotIndex = PlotManager.getPlayerPlotIndex(player)
	local plotFolder = PlotManager.getPlotFolder(plotIndex)
	if not plotFolder then
		return false
	end

	if not player.Character then
		return false
	end

	for _, inst in ipairs(plotFolder:GetDescendants()) do
		if inst:IsA("Seat") and (inst.Name == seatName or inst.Name:sub(-#seatName) == seatName) then
			if inst.Occupant ~= nil and inst.Occupant.Parent == player.Character then
				return true
			end
		end
	end

	return false
end

local function waitForPlayerSeated(player, phase)
	local seatName = STATION_SEAT_NAMES[phase]
	local waited = 0

	while waited < SEAT_WAIT_TIMEOUT_SECONDS do
		if not player.Parent then
			return
		end

		if isPlayerSeatedAt(player, seatName) then
			return
		end

		task.wait(0.25)
		waited += 0.25
	end
end

local STATION_FOR_PHASE = { Coding = "Coding", MapBuilding = "MapBuilding", Testing = "Testing" }

-- Builds the server-authoritative content for a round (quiz question, timing
-- window, etc). Mash variants (CodeSprint) need no content beyond params, so
-- they fall through to the empty table. Every later variant task adds its own
-- branch here.
local function generateRoundInfo(variantId, difficulty, params)
	if variantId == "PrecisionPlace" then
		return {
			startTime = Workspace:GetServerTimeNow(),
			periodSeconds = params.periodSeconds,
			zoneHalfWidth = params.zoneHalfWidth,
		}
	elseif variantId == "QAQuiz" then
		local q = GameData.TestingQuestions[rng:NextInteger(1, #GameData.TestingQuestions)]
		local correctText = q.options[q.correctIndex]

		-- Distractor pool: every other option this question carries. Shuffled
		-- so which ones get used (when the question has more distractors than
		-- optionCount-1 needs) varies round to round.
		local distractorPool = {}
		for i, opt in ipairs(q.options) do
			if i ~= q.correctIndex then
				table.insert(distractorPool, opt)
			end
		end
		for i = #distractorPool, 2, -1 do
			local j = rng:NextInteger(1, i)
			distractorPool[i], distractorPool[j] = distractorPool[j], distractorPool[i]
		end

		-- Clamp to what the question can actually supply (some questions only
		-- have 2 options even though optionCount can ask for up to 4).
		local wantCount = math.min(params.optionCount or 2, 1 + #distractorPool)
		local options = { correctText }
		for i = 1, wantCount - 1 do
			table.insert(options, distractorPool[i])
		end

		-- Fisher-Yates shuffle, tracking where the correct option (originally
		-- index 1) lands -- same pattern as CompileCheck below.
		local correctIndex = 1
		for i = #options, 2, -1 do
			local j = rng:NextInteger(1, i)
			options[i], options[j] = options[j], options[i]
			if correctIndex == i then
				correctIndex = j
			elseif correctIndex == j then
				correctIndex = i
			end
		end

		return { prompt = q.prompt, options = options, correctIndex = correctIndex }
	elseif variantId == "KeyCombo" then
		local glyphs = { "↑", "↓", "←", "→", "{", "}", ";", "(" }
		local seq = {}
		for i = 1, params.len do
			seq[i] = glyphs[rng:NextInteger(1, #glyphs)]
		end
		return { keys = seq, total = params.len, maxWait = params.peekSeconds + params.inputSeconds + 2 }
	elseif variantId == "BlueprintMemory" then
		local cells = params.gridN * params.gridN
		local pattern, used = {}, {}
		while #pattern < math.min(params.patternLen, cells) do
			local c = rng:NextInteger(1, cells)
			if not used[c] then
				used[c] = true
				table.insert(pattern, c)
			end
		end
		return { gridN = params.gridN, pattern = pattern, total = #pattern, maxWait = params.peekSeconds + 12 }
	elseif variantId == "TileDrop" then
		return { pieces = params.pieces, fallSeconds = params.fallSeconds, total = params.pieces, maxWait = params.pieces * params.fallSeconds + 5 }
	elseif variantId == "PathConnect" then
		local n = params.gridN
		local startRow = rng:NextInteger(0, n - 1)
		local exitRow = rng:NextInteger(0, n - 1)
		local startCell = startRow * n + 1 -- left column (col 0)
		local exitCell = exitRow * n + n -- right column (col n-1)
		local pathLen = (n - 1) + math.abs(exitRow - startRow) -- Manhattan shortest path in tiles-moved
		return { gridN = n, startCell = startCell, exitCell = exitCell, total = pathLen, maxWait = params.timeSeconds + 2 }
	elseif variantId == "CompileCheck" then
		local s = GameData.CompileSnippets[rng:NextInteger(1, #GameData.CompileSnippets)]
		local lines = { s.good, s.bad[1], s.bad[2] }
		-- Fisher-Yates shuffle, tracking where the good line (originally index 1) lands.
		local correctIndex = 1
		for i = #lines, 2, -1 do
			local j = rng:NextInteger(1, i)
			lines[i], lines[j] = lines[j], lines[i]
			if correctIndex == i then
				correctIndex = j
			elseif correctIndex == j then
				correctIndex = i
			end
		end
		return { lines = lines, correctIndex = correctIndex }
	elseif variantId == "BugHunt" then
		local cells = params.gridN * params.gridN
		return { gridN = params.gridN, correctIndex = rng:NextInteger(1, cells), answerSeconds = params.answerSeconds }
	elseif variantId == "PassOrFail" then
		local items, truth = {}, {}
		for i = 1, params.count do
			local it = GameData.PassOrFailItems[rng:NextInteger(1, #GameData.PassOrFailItems)]
			items[i] = it.text
			truth[i] = it.ship
		end
		return {
			items = items,
			truth = truth,
			total = params.count,
			flashSeconds = params.flashSeconds,
			maxWait = params.count * params.flashSeconds + 3,
		}
	end
	return {} -- mash variants need no content
end

-- Waits for the client to report input (per input kind, with a timeout so an
-- AFK/disconnected player doesn't stall the round forever) then scores the
-- round from what was reported.
local function waitAndScore(player, variantId, kind, params, roundInfo)
	local uid = player.UserId

	if kind == "mash" then
		task.wait(params.windowSeconds)
		local r = activeRounds[uid]
		activeRounds[uid] = nil
		local target = params.targetTaps or params.targetBugs or params.targetCrashes
		return r and GameData.scoreMash(r.count or 0, target) or 0
	elseif kind == "timing" then
		local waited = 0
		while waited < GameData.MapBuildingMaxWaitSeconds do
			local r = activeRounds[uid]
			if not r or r.placed then
				break
			end
			task.wait(0.1)
			waited += 0.1
		end
		local r = activeRounds[uid]
		activeRounds[uid] = nil
		if not r or not r.placed then
			return 0
		end
		local elapsed = r.placementTime - roundInfo.startTime
		local pos = GameData.getMarkerPosition(elapsed, params.periodSeconds)
		return GameData.scoreTiming(pos, GameData.MapBuildingZoneCenter, params.zoneHalfWidth)
	elseif kind == "sequence" then
		local maxWait = roundInfo.maxWait or 12
		local waited = 0
		while waited < maxWait do
			local r = activeRounds[uid]
			if not r or r.reported then
				break
			end
			task.wait(0.1)
			waited += 0.1
		end
		local r = activeRounds[uid]
		activeRounds[uid] = nil
		if not r or not r.reported then
			return 0
		end
		return GameData.scoreSequence(r.correctCount or 0, roundInfo.total)
	elseif kind == "choice" then
		local waited = 0
		while waited < (params.answerSeconds or GameData.TestingMaxWaitSeconds) do
			local r = activeRounds[uid]
			if not r or r.chosen then
				break
			end
			task.wait(0.1)
			waited += 0.1
		end
		local r = activeRounds[uid]
		activeRounds[uid] = nil
		if not r or not r.chosen then
			return 0
		end
		return GameData.scoreChoice(r.chosenIndex, roundInfo.correctIndex, GameData.TestingWrongAnswerScore)
	end

	return 0
end

local function runPhase(player, data, phase)
	local worker = data.workers[phase]

	if worker.hired then
		Remotes.PhaseStarted:FireClient(player, phase, true)
		-- Rarer workers finish faster and produce higher quality; the Faster
		-- Workers game pass speeds them up further.
		local speed = GameData.getRaritySpeed(worker.rarity) * GameData.getPassWorkerSpeedMultiplier(data)
		local mult = GameData.getRarityMultiplier(worker.rarity)
		local dur = GameData.WorkerAutoCompleteSeconds / speed
		PlotManager.playWorkerTyping(player, phase, dur) -- typing animation while they work
		task.wait(dur)
		local score = GameData.getWorkerScore(worker.level) * mult
		Remotes.PhaseComplete:FireClient(player, phase, score)
		return score
	end

	Remotes.PhaseStarted:FireClient(player, phase, false)
	waitForPlayerSeated(player, phase)

	if not player.Parent then
		return 0
	end

	local uid = player.UserId
	local station = STATION_FOR_PHASE[phase]
	local difficulty = GameData.getDifficulty(GameData.getStudioLevel(data))
	lastVariantByStation[uid] = lastVariantByStation[uid] or {}
	local variantId = GameData.pickVariantId(station, lastVariantByStation[uid][station], function()
		return rng:NextNumber()
	end)
	lastVariantByStation[uid][station] = variantId
	local kind = GameData.VariantInputKind[variantId]
	local params = GameData.getVariantParams(variantId, difficulty)

	local total = 0
	for roundIndex = 1, GameData.RoundsPerPhase do
		if not player.Parent then
			return 0
		end

		local roundInfo = generateRoundInfo(variantId, difficulty, params)
		activeRounds[uid] = { kind = kind, params = params, roundInfo = roundInfo }
		Remotes.RoundStarted:FireClient(player, station, roundIndex, {
			variantId = variantId,
			difficulty = difficulty,
			params = params,
			roundInfo = roundInfo,
		})
		local roundScore = waitAndScore(player, variantId, kind, params, roundInfo)
		total += roundScore
		Remotes.RoundComplete:FireClient(player, phase, roundIndex, roundScore)
	end

	local phaseScore = total / GameData.RoundsPerPhase
	Remotes.PhaseComplete:FireClient(player, phase, phaseScore)
	return phaseScore
end

function DevelopmentService.start()
	Remotes.ReportMinigameInput.OnServerEvent:Connect(function(player, value)
		local round = activeRounds[player.UserId]
		if not round then
			return
		end
		if round.kind == "mash" then
			round.count = (round.count or 0) + 1
		elseif round.kind == "timing" and not round.placed then
			round.placed = true
			round.placementTime = Workspace:GetServerTimeNow()
		elseif round.kind == "sequence" and not round.reported then
			round.reported = true
			round.correctCount = tonumber(value) or 0
		elseif round.kind == "choice" and not round.chosen then
			round.chosen = true
			round.chosenIndex = tonumber(value)
		end
	end)

	Remotes.RequestStartDevelopment.OnServerEvent:Connect(function(player, genre, topic)
		if developing[player.UserId] then
			return
		end

		if not isValidGenre(genre) or not isValidTopic(topic) then
			return
		end

		local data = PlayerData.get(player)
		if not data then
			return
		end

		developing[player.UserId] = true

		task.spawn(function()
			local totalQuality = 0

			for _, phase in ipairs(GameData.Phases) do
				if not player.Parent then
					developing[player.UserId] = nil
					return
				end

				totalQuality += runPhase(player, data, phase)
			end

			developing[player.UserId] = nil

			if not player.Parent then
				return
			end

			-- Quality is a percentage capped at MaxDevQuality (250%). Solo play
			-- tops out near 100%; rare workers push it higher, up to a maxed
			-- Mythic's 2.5x. We clamp here so no worker can run away past the
			-- ceiling (the old bug let a 6x Mythic make 600% games and print
			-- money). Rarer workers also finish FASTER (more games/min).
			local devQuality = math.min(GameData.MaxDevQuality, totalQuality / #GameData.Phases)
			local trend1, trend2 = TrendsService.getCurrent()
			local cash, classification, hitBonus = TrendMatch.computeCash(genre, topic, trend1, trend2, devQuality)
			-- Higher floors both cost 2x more AND pay 2x more, so income
			-- scales with the studio's floor count the same way costs do; an
			-- active shop boost multiplies on top of that.
			-- Subscribers give a permanent multiplier on cash you earn, on top
			-- of the PC / floor / boost multipliers.
			cash = math.floor(cash * GameData.getPCCashMultiplier(data.pcTier) * GameData.getFloorMultiplier(data.houseTier) * GameData.getBoostMultiplier(data, Workspace:GetServerTimeNow()) * GameData.getSubscriberMultiplier(data.subscribers) * GameData.getPrestigeMultiplier(data.prestigeLevel) * GameData.getPassCashMultiplier(data))

			data.cash += cash
			data.gamesReleased += 1

			-- Releasing a game grows your channel: more subscribers for a better
			-- game, with a big bonus when it matched a trend. This can cross a
			-- Play Button milestone (bonus cash + a trophy in the studio).
			local subsGained = math.floor(GameData.getSubsForRelease(devQuality, hitBonus) * GameData.getPassSubsMultiplier(data))
			local milestoneReached = PlotManager.grantSubscribers(player, data, subsGained)

			Remotes.DevelopmentComplete:FireClient(player, cash, classification == "copy", hitBonus)
			Remotes.PlayerStateUpdated:FireClient(player, data)
			Remotes.SubscribersGained:FireClient(player, subsGained, milestoneReached)
		end)
	end)
end

function DevelopmentService.cleanupPlayer(player)
	activeRounds[player.UserId] = nil
	developing[player.UserId] = nil
	lastVariantByStation[player.UserId] = nil
end

return DevelopmentService
