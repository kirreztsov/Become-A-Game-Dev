-- The "map building" mini-game screen: a horizontal track with a sweeping
-- marker and a highlighted green zone, plus a big "Place It!" button. This is
-- a "variant" implementation: it owns no remotes and no round logic -- it
-- just builds UI and calls the injected `report` callback on every tap. The
-- framework controller supplies `report`, decides round timing/targets (via
-- `roundInfo`), and owns the server round.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local PrecisionPlace = { id = "PrecisionPlace", station = "MapBuilding", inputKind = "timing" }

local container
local marker
local zoneHighlight
local placeButton
local reportFn
local renderConnection
local roundStartTime
local roundPeriod
local placed = false

function PrecisionPlace.init(parent, theme, report)
	reportFn = report

	container = Instance.new("Frame")
	container.Name = "PrecisionPlace"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -32, 0, 24)
	track.Position = UDim2.new(0, 16, 0, 40)
	track.BackgroundColor3 = theme.Panel
	track.BorderSizePixel = 0
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 12)
	trackCorner.Parent = track

	local zoneWidthScale = GameData.MapBuildingZoneHalfWidth * 2
	zoneHighlight = Instance.new("Frame")
	zoneHighlight.Size = UDim2.new(zoneWidthScale, 0, 1, 0)
	zoneHighlight.Position = UDim2.new(GameData.MapBuildingZoneCenter - GameData.MapBuildingZoneHalfWidth, 0, 0, 0)
	zoneHighlight.BackgroundColor3 = theme.Success
	zoneHighlight.BackgroundTransparency = 0.5
	zoneHighlight.BorderSizePixel = 0
	zoneHighlight.Parent = track

	marker = Instance.new("Frame")
	marker.Size = UDim2.fromOffset(6, 32)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.new(0, 0, 0.5, 0)
	marker.BackgroundColor3 = theme.Gold
	marker.BorderSizePixel = 0
	marker.Parent = track

	placeButton = Instance.new("TextButton")
	placeButton.Size = UDim2.new(1, -32, 0, 40)
	placeButton.Position = UDim2.new(0, 16, 0, 84)
	placeButton.BackgroundColor3 = theme.Accent
	placeButton.Text = "\240\159\147\141 Place It!"
	placeButton.Font = Enum.Font.FredokaOne
	placeButton.TextSize = 18
	placeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	placeButton.AutoButtonColor = false
	placeButton.BorderSizePixel = 0
	placeButton.Parent = container

	local placeCorner = Instance.new("UICorner")
	placeCorner.CornerRadius = UDim.new(0, 10)
	placeCorner.Parent = placeButton

	placeButton.MouseButton1Click:Connect(function()
		if placed then
			return
		end
		placed = true
		reportFn()
	end)
end

function PrecisionPlace.startRound(difficulty, params, roundInfo)
	roundStartTime = roundInfo.startTime
	roundPeriod = roundInfo.periodSeconds
	placed = false

	local zoneHalfWidth = roundInfo.zoneHalfWidth or GameData.MapBuildingZoneHalfWidth
	if zoneHighlight then
		zoneHighlight.Size = UDim2.new(zoneHalfWidth * 2, 0, 1, 0)
		zoneHighlight.Position = UDim2.new(GameData.MapBuildingZoneCenter - zoneHalfWidth, 0, 0, 0)
	end

	container.Visible = true

	if renderConnection then
		renderConnection:Disconnect()
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		local elapsed = Workspace:GetServerTimeNow() - roundStartTime
		local position = GameData.getMarkerPosition(elapsed, roundPeriod)
		marker.Position = UDim2.new(position, 0, 0.5, 0)
	end)
end

function PrecisionPlace.hide()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if container then
		container.Visible = false
	end
end

return PrecisionPlace
