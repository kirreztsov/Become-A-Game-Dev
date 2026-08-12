-- Anti-cheat helpers for the development minigames (roadmap E1).
--
-- The minigame remotes are the one place a player's own client tells the server
-- how well they did, so every claim that arrives has to be treated as hostile
-- until it is checked. This module holds the pure decision logic so it can be
-- unit-tested (see RunTests); DevelopmentService owns the round state and calls
-- in here.
--
-- What was wrong before:
--   * mash rounds counted every remote call, so firing it in a loop scored a
--     perfect round instantly;
--   * sequence rounds took the client's word for how many inputs it got right;
--   * the round payload sent to the client contained the ANSWERS (which option
--     is correct, which items should ship), so they could just be read out.
local MinigameGuard = {}

-- How fast inputs can legitimately arrive. Humans top out around 10-12 taps a
-- second, so 20/sec leaves plenty of headroom while still blocking a script
-- that fires hundreds of times in one frame.
MinigameGuard.MIN_TAP_INTERVAL = 0.05
MinigameGuard.MIN_SECONDS_PER_SEQUENCE_ITEM = 0.06
MinigameGuard.MIN_CHOICE_REACTION = 0.15

-- Fields the client must NOT be told, per variant. QAQuiz/CompileCheck never
-- read correctIndex client-side, and PassOrFail no longer needs truth now that
-- the server scores its answers.
-- BugHunt deliberately keeps correctIndex: the client draws that tile glitched,
-- so the round cannot be rendered without it. The reaction floor guards it.
MinigameGuard.SECRET_FIELDS = {
	QAQuiz = { "correctIndex" },
	CompileCheck = { "correctIndex" },
	PassOrFail = { "truth" },
}

-- A copy of the round content with the answers stripped out. Returns the
-- original table when a variant has no secrets (nothing to hide, no garbage).
function MinigameGuard.sanitizeRoundInfo(variantId, roundInfo)
	local secrets = MinigameGuard.SECRET_FIELDS[variantId]
	if not secrets or not roundInfo then
		return roundInfo
	end
	local copy = {}
	for k, v in pairs(roundInfo) do
		copy[k] = v
	end
	for _, field in ipairs(secrets) do
		copy[field] = nil
	end
	return copy
end

-- True when a mash tap is far enough after the previous one to be real.
-- lastTap is nil for the first tap of a round.
function MinigameGuard.acceptTap(lastTap, now)
	if not lastTap then
		return true
	end
	return (now - lastTap) >= MinigameGuard.MIN_TAP_INTERVAL
end

-- Taps never help past the round's target (scoreMash clamps there anyway), so
-- the running count is capped. A missing/zero target means "no cap".
function MinigameGuard.addTap(count, target)
	local nextCount = (count or 0) + 1
	if target and target > 0 then
		return math.min(nextCount, target)
	end
	return nextCount
end

-- A self-reported sequence score, made safe: never more than the round actually
-- contained, never negative or NaN, and zero if the round was finished faster
-- than a person could physically finish it.
function MinigameGuard.clampSequenceScore(claimed, total, elapsed)
	claimed = tonumber(claimed) or 0
	total = total or 0
	if claimed ~= claimed or claimed < 0 then -- NaN or negative
		return 0
	end
	if (elapsed or 0) < total * MinigameGuard.MIN_SECONDS_PER_SEQUENCE_ITEM then
		return 0
	end
	return math.min(claimed, total)
end

-- True when a multiple-choice answer arrived slower than a human reaction.
function MinigameGuard.acceptChoice(elapsed)
	return (elapsed or 0) >= MinigameGuard.MIN_CHOICE_REACTION
end

-- Scores a PassOrFail round from the player's OWN answers rather than a
-- client-reported tally. answers[i] is 1 (ship), 0 (don't ship), or -1/absent
-- for never answered -- which can never match.
function MinigameGuard.scorePassOrFail(truth, total, answers)
	truth = truth or {}
	total = total or #truth
	if type(answers) ~= "table" then
		return 0
	end
	local correct = 0
	for i = 1, total do
		local a = answers[i]
		if a == 1 or a == 0 then
			if (a == 1) == (truth[i] == true) then
				correct += 1
			end
		end
	end
	return correct
end

return MinigameGuard
