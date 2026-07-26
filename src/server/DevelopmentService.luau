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

local function isValidGenre(genre)
	return table.find(GameData.Genres, genre) ~= nil
end

local function isValidTopic(topic)
	return table.find(GameData.Topics, topic) ~= nil
end

local function runCodingRound(player, roundIndex)
	activeRounds[player.UserId] = { kind = "tap", tapCount = 0 }
	Remotes.RoundStarted:FireClient(player, "Coding", roundIndex, {})
	task.wait(GameData.CodingRoundSeconds)

	local round = activeRounds[player.UserId]
	activeRounds[player.UserId] = nil

	if not round then
		return 0
	end

	return math.clamp(round.tapCount / GameData.CodingTargetTaps, 0, 1)
end

local function runMapBuildingRound(player, roundIndex)
	local startTime = Workspace:GetServerTimeNow()
	activeRounds[player.UserId] = { kind = "timing", placed = false, startTime = startTime }

	Remotes.RoundStarted:FireClient(player, "MapBuilding", roundIndex, {
		startTime = startTime,
		periodSeconds = GameData.MapBuildingRoundSeconds,
	})

	local waited = 0
	while waited < GameData.MapBuildingMaxWaitSeconds do
		local round = activeRounds[player.UserId]
		if not round or round.placed then
			break
		end
		task.wait(0.1)
		waited += 0.1
	end

	local round = activeRounds[player.UserId]
	activeRounds[player.UserId] = nil

	if not round or not round.placed then
		return 0
	end

	local elapsed = round.placementTime - round.startTime
	local markerPosition = GameData.getMarkerPosition(elapsed, GameData.MapBuildingRoundSeconds)
	local distance = math.abs(markerPosition - GameData.MapBuildingZoneCenter)

	if distance > GameData.MapBuildingZoneHalfWidth then
		return 0
	end

	return 1 - (distance / GameData.MapBuildingZoneHalfWidth)
end

local function runTestingRound(player, roundIndex)
	local question = GameData.TestingQuestions[math.random(1, #GameData.TestingQuestions)]
	local options = question.options
	local correctIndex = question.correctIndex

	if math.random() < 0.5 then
		options = { options[2], options[1] }
		correctIndex = (correctIndex == 1) and 2 or 1
	end

	activeRounds[player.UserId] = { kind = "choice", chosen = false, correctIndex = correctIndex }

	Remotes.RoundStarted:FireClient(player, "Testing", roundIndex, {
		prompt = question.prompt,
		options = options,
	})

	local waited = 0
	while waited < GameData.TestingMaxWaitSeconds do
		local round = activeRounds[player.UserId]
		if not round or round.chosen then
			break
		end
		task.wait(0.1)
		waited += 0.1
	end

	local round = activeRounds[player.UserId]
	activeRounds[player.UserId] = nil

	if not round or not round.chosen then
		return 0
	end

	if round.chosenIndex == round.correctIndex then
		return 1
	end

	return GameData.TestingWrongAnswerScore
end

local ROUND_RUNNERS = {
	Coding = runCodingRound,
	MapBuilding = runMapBuildingRound,
	Testing = runTestingRound,
}

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

	local total = 0
	for roundIndex = 1, GameData.RoundsPerPhase do
		if not player.Parent then
			return 0
		end

		local roundScore = ROUND_RUNNERS[phase](player, roundIndex)
		total += roundScore
		Remotes.RoundComplete:FireClient(player, phase, roundIndex, roundScore)
	end

	local phaseScore = total / GameData.RoundsPerPhase
	Remotes.PhaseComplete:FireClient(player, phase, phaseScore)
	return phaseScore
end

function DevelopmentService.start()
	Remotes.ReportTap.OnServerEvent:Connect(function(player)
		local round = activeRounds[player.UserId]
		if round and round.kind == "tap" then
			round.tapCount += 1
		end
	end)

	Remotes.ReportPlacement.OnServerEvent:Connect(function(player)
		local round = activeRounds[player.UserId]
		if round and round.kind == "timing" and not round.placed then
			round.placed = true
			round.placementTime = Workspace:GetServerTimeNow()
		end
	end)

	Remotes.ReportChoice.OnServerEvent:Connect(function(player, optionIndex)
		local round = activeRounds[player.UserId]
		if round and round.kind == "choice" and not round.chosen then
			round.chosen = true
			round.chosenIndex = optionIndex
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
end

return DevelopmentService
