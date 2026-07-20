local TestHarness = {}
TestHarness.__index = TestHarness

function TestHarness.new()
	return setmetatable({ passed = 0, failed = 0 }, TestHarness)
end

function TestHarness:assertEqual(actual, expected, message)
	if actual == expected then
		self.passed += 1
		print(("PASS: %s"):format(message))
	else
		self.failed += 1
		warn(("FAIL: %s -- expected %s, got %s"):format(message, tostring(expected), tostring(actual)))
	end
end

function TestHarness:summary()
	print(("Tests complete: %d passed, %d failed"):format(self.passed, self.failed))
end

return TestHarness
