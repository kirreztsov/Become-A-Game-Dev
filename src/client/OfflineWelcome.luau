-- "Welcome back" popup: on join the server may report offline earnings; show a
-- card with the amount + away time and a Collect button. Collect tells the
-- server to grant it (server-authoritative). Reuses the white-card Theme + Fx.
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Fx = require(script.Parent.Fx)

local OfflineWelcome = {}

local function formatMoney(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function formatAway(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	return string.format("%dm", m)
end

function OfflineWelcome.init(player, Theme)
	local gui = Instance.new("ScreenGui")
	gui.Name = "OfflineWelcomeGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(360, 220)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Theme.Panel
	card.Parent = backdrop
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
	local stroke = Instance.new("UIStroke", card)
	stroke.Color = Theme.Line
	stroke.Thickness = 1

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -32, 0, 40)
	title.Position = UDim2.fromOffset(16, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 26
	title.TextColor3 = Theme.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Welcome back! 👋"
	title.Parent = card

	local amount = Instance.new("TextLabel")
	amount.BackgroundTransparency = 1
	amount.Size = UDim2.new(1, -32, 0, 48)
	amount.Position = UDim2.fromOffset(16, 74)
	amount.Font = Enum.Font.GothamBlack
	amount.TextSize = 40
	amount.TextColor3 = Theme.Gold
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.Text = "$0"
	amount.Parent = card

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -32, 0, 24)
	sub.Position = UDim2.fromOffset(16, 122)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 16
	sub.TextColor3 = Theme.TextMuted
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = "earned while you were away"
	sub.Parent = card

	local collect = Instance.new("TextButton")
	collect.Name = "Collect"
	collect.Size = UDim2.new(1, -32, 0, 44)
	collect.Position = UDim2.new(0, 16, 1, -60)
	collect.BackgroundColor3 = Theme.Accent
	collect.Font = Enum.Font.GothamBold
	collect.TextSize = 20
	collect.TextColor3 = Color3.new(1, 1, 1)
	collect.Text = "Collect"
	collect.AutoButtonColor = true
	collect.Parent = card
	Instance.new("UICorner", collect).CornerRadius = UDim.new(0, 12)

	local claimed = false
	local function claimOnce()
		if claimed then
			return
		end
		claimed = true
		Remotes.CollectOfflineEarnings:FireServer()
	end

	collect.Activated:Connect(function()
		claimOnce()
		local cam = workspace.CurrentCamera
		if cam then
			Fx.coinBurst(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5, 12)
		end
		gui.Enabled = false
	end)
	backdrop.Activated:Connect(function()
		-- tapping outside also collects (never lose the reward)
		claimOnce()
		gui.Enabled = false
	end)

	Remotes.OfflineEarningsReady.OnClientEvent:Connect(function(cash, seconds)
		if not cash or cash <= 0 then
			return
		end
		claimed = false
		amount.Text = "$" .. formatMoney(cash)
		sub.Text = "earned while away (" .. formatAway(seconds) .. ")"
		gui.Enabled = true
		Fx.popIn(card)
	end)
end

return OfflineWelcome
