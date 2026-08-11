-- Layout + pure helpers for the PC-install workbench minigame. All Layout
-- CFrames are LOCAL to PCInstall.BenchCFrame; the client multiplies the bench
-- world CFrame by these to place slots, trays and the camera. The 7 parts each
-- get one fixed spot; only the current part's slot glows during a round.
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local PCInstall = {}

-- Workbench origin in the PC Store (bench-top, front-center). Tuned in playtest.
PCInstall.BenchCFrame = CFrame.new(165, 4.6, -12) * CFrame.Angles(0, math.rad(180), 0)

-- Camera sits in front of the bench looking back at the open tower.
local CAM = CFrame.new(Vector3.new(0, 1.6, 6), Vector3.new(0, 1.2, 0))

-- Per-part local offsets. slot = where the part seats; tray = where the new
-- part starts; snap = generous drop radius (studs); size = target model height.
PCInstall.Layout = {
	CPU = { slot = CFrame.new(-1.0, 0.6, -0.4), tray = CFrame.new(-2.6, 0.5, 2.2), camera = CAM, snap = 1.4, size = 1.4 },
	RAM = { slot = CFrame.new(0.6, 0.9, -0.4), tray = CFrame.new(-1.3, 0.5, 2.2), camera = CAM, snap = 1.4, size = 1.8 },
	Storage = { slot = CFrame.new(1.4, 0.4, 0.2), tray = CFrame.new(0.0, 0.5, 2.2), camera = CAM, snap = 1.4, size = 1.6 },
	Cooling = { slot = CFrame.new(-1.0, 1.2, -0.4), tray = CFrame.new(1.3, 0.5, 2.2), camera = CAM, snap = 1.6, size = 2.2 },
	GPU = { slot = CFrame.new(0.2, 0.5, 0.6), tray = CFrame.new(2.6, 0.5, 2.2), camera = CAM, snap = 1.6, size = 1.8 },
	Monitor = { slot = CFrame.new(3.0, 1.2, 0.0), tray = CFrame.new(0.0, 0.5, 2.6), camera = CAM, snap = 1.8, size = 2.4 },
	RGB = { slot = CFrame.new(0.0, 1.4, 0.0), tray = CFrame.new(0.0, 0.5, 3.0), camera = CAM, snap = 2.0, size = 3.0 },
}

function PCInstall.isWithinSnap(dropPos, slotPos, radius)
	return (dropPos - slotPos).Magnitude <= radius
end

function PCInstall.worldSlot(partId)
	return PCInstall.BenchCFrame * PCInstall.Layout[partId].slot
end

function PCInstall.worldTray(partId)
	return PCInstall.BenchCFrame * PCInstall.Layout[partId].tray
end

function PCInstall.worldCamera(partId)
	return PCInstall.BenchCFrame * PCInstall.Layout[partId].camera
end

return PCInstall
