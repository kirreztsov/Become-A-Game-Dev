local GameData = require(script.Parent.Parent.GameData)
local TestHarness = require(script.TestHarness)

local t = TestHarness.new()

t:assertEqual(GameData.getDevTime(0), 30, "getDevTime(0) is the base time")
t:assertEqual(GameData.getDevTime(1), 30 * 0.95, "getDevTime(1) applies one decay step")
t:assertEqual(GameData.getDevSpeedCost(0), 10, "getDevSpeedCost(0) is the base cost")
t:assertEqual(GameData.getDevSpeedCost(1), 11, "getDevSpeedCost(1) grows 15%, floored")
t:assertEqual(GameData.getQualityMultiplier(0), 1, "getQualityMultiplier(0) is 1x")
t:assertEqual(GameData.getQualityMultiplier(5), 1.5, "getQualityMultiplier(5) is +50%")
t:assertEqual(GameData.getQualityBoostCost(0), 15, "getQualityBoostCost(0) is the base cost")
t:assertEqual(GameData.getBaseCash(0), 10, "getBaseCash(0) equals the payout multiplier")
t:assertEqual(GameData.getBaseCash(5), 15, "getBaseCash(5) scales with quality multiplier")

t:summary()
