local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local WorkersPanel = require(script.Parent.WorkersPanel)
local Fx = require(script.Parent.Fx)

local WorkerHub = {}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

function WorkerHub.init(player, theme)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkerHubGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Windows-style desktop background.
	local desktop = Instance.new("Frame")
	desktop.Size = UDim2.fromScale(1, 1)
	desktop.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
	desktop.BorderSizePixel = 0
	desktop.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(78, 165, 246), Color3.fromRGB(16, 84, 188))
	grad.Rotation = 28
	grad.Parent = desktop

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(44, 44)
	closeBtn.Position = UDim2.new(1, -16, 0, 16)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(210, 70, 70)
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 22
	closeBtn.Text = "X"
	closeBtn.Parent = desktop
	corner(closeBtn, 10)
	closeBtn.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)

	-- ---- Home view: two app tiles ------------------------------------------
	local home = Instance.new("Frame")
	home.Size = UDim2.fromScale(1, 1)
	home.BackgroundTransparency = 1
	home.Parent = desktop

	local function appTile(text, icon, xScale, onClick)
		local tile = Instance.new("TextButton")
		tile.Size = UDim2.fromOffset(220, 240)
		tile.Position = UDim2.fromScale(xScale, 0.5)
		tile.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		tile.BackgroundTransparency = 0.06
		tile.Text = ""
		tile.AutoButtonColor = true
		tile.Parent = home
		corner(tile, 24)
		local ic = Instance.new("TextLabel")
		ic.Size = UDim2.new(1, 0, 0.62, 0)
		ic.BackgroundTransparency = 1
		ic.Text = icon
		ic.TextScaled = true
		ic.Font = Enum.Font.FredokaOne
		ic.Parent = tile
		local nm = Instance.new("TextLabel")
		nm.Size = UDim2.new(1, 0, 0.28, 0)
		nm.Position = UDim2.fromScale(0, 0.66)
		nm.BackgroundTransparency = 1
		nm.Text = text
		nm.TextColor3 = Color3.fromRGB(30, 40, 60)
		nm.Font = Enum.Font.FredokaOne
		nm.TextScaled = true
		nm.Parent = tile
		tile.MouseButton1Click:Connect(onClick)
		return tile
	end

	-- ---- Cases view --------------------------------------------------------
	local casesView = Instance.new("Frame")
	casesView.Size = UDim2.fromScale(1, 1)
	casesView.BackgroundTransparency = 1
	casesView.Visible = false
	casesView.Parent = desktop

	local backBtn = Instance.new("TextButton")
	backBtn.Size = UDim2.fromOffset(90, 38)
	backBtn.Position = UDim2.fromOffset(16, 16)
	backBtn.BackgroundColor3 = theme.Neutral
	backBtn.TextColor3 = theme.Text
	backBtn.Font = Enum.Font.FredokaOne
	backBtn.TextSize = 16
	backBtn.Text = "\226\134\169 Back"
	backBtn.Parent = casesView
	corner(backBtn, 10)
	backBtn.MouseButton1Click:Connect(function()
		casesView.Visible = false
		home.Visible = true
	end)

	-- spin/result overlay
	local resultLabel = Instance.new("TextLabel")
	resultLabel.Size = UDim2.fromOffset(700, 70)
	resultLabel.Position = UDim2.fromScale(0.5, 0.13)
	resultLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Font = Enum.Font.FredokaOne
	resultLabel.TextScaled = true
	resultLabel.Text = "Open a case!"
	resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	resultLabel.Parent = casesView

	local function oddsText(weights)
		local lines = {}
		for _, w in ipairs(weights) do
			local info = GameData.getRarityInfo(w.rarity)
			local hex = ("#%02X%02X%02X"):format(info.color.R * 255, info.color.G * 255, info.color.B * 255)
			lines[#lines + 1] = ("<font color=\"%s\">%s</font>  %s%%"):format(hex, w.rarity, tostring(w.weight))
		end
		return table.concat(lines, "\n")
	end

	-- Per-case UI (count label + spin button) so we can refresh from state.
	local spinUI = {}
	local ownedCounts = { normal = 0, lucky = 0 }
	local spinning = false -- true while a spin animation is playing (locks SPIN)
	local refreshCounts -- forward declaration (defined below)

	-- buyOptions: a list of { label, onClick }. One option = a full-width
	-- button; several = a row (used by the Lucky Crate's x1 / x5 / x10 bundles).
	local function caseCard(title, costText, weights, xScale, caseType, buyOptions)
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(300, 380)
		card.Position = UDim2.fromScale(xScale, 0.58)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.BackgroundColor3 = theme.Panel
		card.Parent = casesView
		corner(card, 18)
		local st = Instance.new("UIStroke")
		st.Color = theme.Accent
		st.Thickness = 2
		st.Transparency = 0.3
		st.Parent = card
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 0, 38)
		t.Position = UDim2.fromOffset(0, 10)
		t.BackgroundTransparency = 1
		t.Text = title
		t.TextColor3 = theme.Gold
		t.Font = Enum.Font.FredokaOne
		t.TextSize = 24
		t.Parent = card
		local odds = Instance.new("TextLabel")
		odds.Size = UDim2.new(1, -30, 0, 150)
		odds.Position = UDim2.fromOffset(15, 52)
		odds.BackgroundTransparency = 1
		odds.RichText = true
		odds.TextYAlignment = Enum.TextYAlignment.Top
		odds.TextXAlignment = Enum.TextXAlignment.Center
		odds.Text = oddsText(weights)
		odds.TextColor3 = theme.Text
		odds.Font = Enum.Font.GothamBold
		odds.TextSize = 19
		odds.Parent = card

		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(1, 0, 0, 26)
		countLabel.Position = UDim2.fromOffset(0, 206)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "You own: 0 spins"
		countLabel.TextColor3 = theme.TextMuted
		countLabel.Font = Enum.Font.GothamBold
		countLabel.TextSize = 16
		countLabel.Parent = card

		-- Buy button row (1 full-width, or several bundle buttons side by side).
		local buyRow = Instance.new("Frame")
		buyRow.Size = UDim2.fromOffset(264, 48)
		buyRow.Position = UDim2.new(0.5, 0, 0, 240)
		buyRow.AnchorPoint = Vector2.new(0.5, 0)
		buyRow.BackgroundTransparency = 1
		buyRow.Parent = card
		local n = #buyOptions
		local gap = 6
		local btnW = (264 - gap * (n - 1)) / n
		for i, opt in ipairs(buyOptions) do
			local b = Instance.new("TextButton")
			b.Size = UDim2.fromOffset(btnW, 48)
			b.Position = UDim2.fromOffset((i - 1) * (btnW + gap), 0)
			b.BackgroundColor3 = theme.Neutral
			b.TextColor3 = Color3.fromRGB(255, 255, 255)
			b.Font = Enum.Font.FredokaOne
			b.TextSize = n == 1 and 18 or 16
			b.Text = opt.label
			b.Parent = buyRow
			corner(b, 10)
			b.MouseButton1Click:Connect(opt.onClick)
		end

		local spinBtn = Instance.new("TextButton")
		spinBtn.Size = UDim2.fromOffset(260, 52)
		spinBtn.Position = UDim2.new(0.5, 0, 1, -16)
		spinBtn.AnchorPoint = Vector2.new(0.5, 1)
		spinBtn.BackgroundColor3 = theme.Accent
		spinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		spinBtn.Font = Enum.Font.FredokaOne
		spinBtn.TextSize = 22
		spinBtn.Text = "SPIN"
		spinBtn.AutoButtonColor = true
		spinBtn.Parent = card
		corner(spinBtn, 10)
		spinBtn.MouseButton1Click:Connect(function()
			-- Ignore extra clicks while a spin is animating or if none are owned,
			-- so you can't burn multiple spins with one flurry of clicks.
			if spinning or (ownedCounts[caseType] or 0) < 1 then
				return
			end
			spinning = true
			if refreshCounts then
				refreshCounts()
			end
			Remotes.RequestSpin:FireServer(caseType)
			-- Safety: if no result comes back, unlock after a few seconds.
			task.delay(4, function()
				if spinning then
					spinning = false
					if refreshCounts then
						refreshCounts()
					end
				end
			end)
		end)

		spinUI[caseType] = { count = countLabel, spin = spinBtn }
		return card
	end

	caseCard("\240\159\147\166 Normal Case", ("$%d"):format(GameData.NormalCaseCost), GameData.NormalCaseWeights, 0.32, "normal", {
		{ label = "Buy a spin  \194\183  $" .. GameData.NormalCaseCost, onClick = function()
			Remotes.RequestBuySpin:FireServer("normal")
		end },
	})

	local luckyBuyOptions = {}
	for _, bundle in ipairs(GameData.LuckyCaseBundles) do
		luckyBuyOptions[#luckyBuyOptions + 1] = {
			label = bundle.label,
			onClick = function()
				MarketplaceService:PromptProductPurchase(player, bundle.productId)
			end,
		}
	end
	caseCard("\240\159\146\142 Lucky Crate", (GameData.LuckyCaseRobux .. " R$"), GameData.LuckyCaseWeights, 0.68, "lucky", luckyBuyOptions)

	-- Keep the owned-spin counts + spin buttons in sync. Buttons are disabled
	-- while spinning (locked) or when you own none.
	refreshCounts = function()
		for caseType, ui in pairs(spinUI) do
			local n = ownedCounts[caseType] or 0
			local canSpin = n > 0 and not spinning
			ui.count.Text = ("You own: %d spin%s"):format(n, n == 1 and "" or "s")
			ui.spin.Text = spinning and "Spinning..." or (n > 0 and ("SPIN  (%d)"):format(n) or "SPIN")
			ui.spin.BackgroundColor3 = canSpin and theme.Accent or theme.Neutral
			ui.spin.AutoButtonColor = canSpin
			ui.spin.Active = canSpin
		end
	end
	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		ownedCounts.normal = data.normalSpinsOwned or 0
		ownedCounts.lucky = data.luckySpinsOwned or 0
		refreshCounts()
	end)

	-- Manual spin animation (TweenService is unreliable here) landing on the
	-- rolled rarity, then the final result. `spinning` is already true (set on
	-- the button click that fired this spin).
	local function playSpin(rolledRarity, workerType)
		spinning = true
		local scale = resultLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = resultLabel
		task.spawn(function()
			local order = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
			local delay = 0.03
			for i = 1, 16 do
				local r = order[((i - 1) % #order) + 1]
				local info = GameData.getRarityInfo(r)
				resultLabel.Text = r .. "?"
				resultLabel.TextColor3 = info.color
				scale.Scale = (i % 2 == 0) and 1.0 or 1.05 -- flicker for tension
				task.wait(delay)
				delay = delay + 0.006 -- decelerate toward the end
			end
			-- brief suspense beat
			scale.Scale = 1
			resultLabel.Text = "\226\128\166" -- …
			resultLabel.TextColor3 = Color3.fromRGB(120, 126, 142)
			task.wait(0.2)
			-- reveal with a big pop
			local info = GameData.getRarityInfo(rolledRarity)
			resultLabel.TextColor3 = info.color
			resultLabel.Text = ("\240\159\142\137 %s!  Your %s worker leveled up!"):format(rolledRarity, workerType)
			for _, s in ipairs({ 1.5, 1.2, 1.35, 1.12, 1.0 }) do
				scale.Scale = s
				task.wait(0.045)
			end
			scale.Scale = 1
			-- celebrate the good pulls
			local rank = GameData.RarityOrder[rolledRarity] or 1
			if rank >= 4 then
				Fx.celebrate(("\240\159\140\159 %s WORKER!"):format(rolledRarity:upper()), info.color)
			elseif rank == 3 then
				Fx.confetti(28)
			end
			spinning = false
			refreshCounts()
		end)
	end

	Remotes.CaseResult.OnClientEvent:Connect(function(_caseType, rolledRarity, workerType, _finalRarity)
		if gui.Enabled then
			playSpin(rolledRarity, workerType)
		end
	end)

	appTile("Worker Cases", "\240\159\142\129", 0.34, function()
		home.Visible = false
		casesView.Visible = true
		resultLabel.Text = "Open a case!"
		resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end)
	appTile("Upgrade Workers", "\240\159\148\167", 0.66, function()
		gui.Enabled = false
		WorkersPanel.open()
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer == player and prompt.Name == "WorkersPrompt" then
			home.Visible = true
			casesView.Visible = false
			gui.Enabled = true
		end
	end)
end

return WorkerHub
