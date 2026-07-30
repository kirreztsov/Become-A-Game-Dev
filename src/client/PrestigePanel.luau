local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Fx = require(script.Parent.Fx)
local Sound = require(script.Parent.Sound)

local PrestigePanel = {}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

-- 12345 -> "12,345" for readable subscriber counts.
local function withCommas(n)
	local s = tostring(math.floor(n or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function PrestigePanel.init(player, theme, playerState)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PrestigeGui"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Small "prestige level" badge (top-right), shown once you've rebirthed.
	local badge = Instance.new("TextLabel")
	badge.Name = "PrestigeBadge"
	badge.Size = UDim2.fromOffset(120, 34)
	badge.Position = UDim2.new(1, -20, 0, 20)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.BackgroundColor3 = theme.Panel
	badge.TextColor3 = theme.Gold
	badge.Font = Enum.Font.FredokaOne
	badge.TextSize = 18
	badge.Text = "\226\173\144 P0"
	badge.Visible = false
	badge.Parent = gui
	corner(badge, 12)
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = theme.Gold
	badgeStroke.Thickness = 1.5
	badgeStroke.Transparency = 0.3
	badgeStroke.Parent = badge

	-- "Rebirth available" button (top-right, under the badge), shown when eligible.
	local button = Instance.new("TextButton")
	button.Name = "RebirthButton"
	button.Size = UDim2.fromOffset(160, 40)
	button.Position = UDim2.new(1, -20, 0, 60)
	button.AnchorPoint = Vector2.new(1, 0)
	button.BackgroundColor3 = Color3.fromRGB(150, 92, 255)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 17
	button.Text = "\226\173\144 Rebirth!"
	button.Visible = false
	button.AutoButtonColor = true
	button.Parent = gui
	corner(button, 12)

	-- Confirm popup.
	local confirmGui = Instance.new("ScreenGui")
	confirmGui.Name = "PrestigeConfirmGui"
	confirmGui.ResetOnSpawn = false
	confirmGui.Enabled = false
	confirmGui.DisplayOrder = 25
	confirmGui.Parent = player.PlayerGui
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = confirmGui
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(380, 260)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = theme.Panel
	card.Parent = confirmGui
	corner(card, 18)
	local cstroke = Instance.new("UIStroke")
	cstroke.Color = Color3.fromRGB(150, 92, 255)
	cstroke.Thickness = 2.5
	cstroke.Transparency = 0.2
	cstroke.Parent = card
	local ctitle = Instance.new("TextLabel")
	ctitle.Size = UDim2.new(1, 0, 0, 40)
	ctitle.Position = UDim2.fromOffset(0, 18)
	ctitle.BackgroundTransparency = 1
	ctitle.Text = "\226\173\144 Rebirth?"
	ctitle.TextColor3 = theme.Gold
	ctitle.Font = Enum.Font.FredokaOne
	ctitle.TextSize = 30
	ctitle.Parent = card
	local cbody = Instance.new("TextLabel")
	cbody.Size = UDim2.new(1, -40, 0, 120)
	cbody.Position = UDim2.fromOffset(20, 62)
	cbody.BackgroundTransparency = 1
	cbody.TextWrapped = true
	cbody.TextYAlignment = Enum.TextYAlignment.Top
	cbody.TextColor3 = theme.Text
	cbody.Font = Enum.Font.GothamMedium
	cbody.TextSize = 15
	cbody.Text = ""
	cbody.Parent = card
	local yes = Instance.new("TextButton")
	yes.Size = UDim2.fromOffset(150, 44)
	yes.Position = UDim2.new(0, 30, 1, -20)
	yes.AnchorPoint = Vector2.new(0, 1)
	yes.BackgroundColor3 = Color3.fromRGB(150, 92, 255)
	yes.TextColor3 = Color3.fromRGB(255, 255, 255)
	yes.Font = Enum.Font.FredokaOne
	yes.TextSize = 18
	yes.Text = "Rebirth!"
	yes.Parent = card
	corner(yes, 10)
	local no = Instance.new("TextButton")
	no.Size = UDim2.fromOffset(150, 44)
	no.Position = UDim2.new(1, -30, 1, -20)
	no.AnchorPoint = Vector2.new(1, 1)
	no.BackgroundColor3 = theme.Neutral
	no.TextColor3 = theme.Text
	no.Font = Enum.Font.FredokaOne
	no.TextSize = 18
	no.Text = "Cancel"
	no.Parent = card
	corner(no, 10)

	-- ---- Middle-left "Rebirth" button + progress panel --------------------
	-- Always-visible nav button showing live progress toward the next rebirth;
	-- click to open a panel with a progress bar and the reward.
	local progressBtn = Instance.new("TextButton")
	progressBtn.Name = "RebirthProgressButton"
	progressBtn.Size = UDim2.fromOffset(178, 52)
	progressBtn.AnchorPoint = Vector2.new(0, 0.5)
	progressBtn.Position = UDim2.new(0, 16, 0.5, 0)
	progressBtn.BackgroundColor3 = Color3.fromRGB(150, 92, 255)
	progressBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	progressBtn.Font = Enum.Font.FredokaOne
	progressBtn.TextSize = 17
	progressBtn.Text = "\226\173\144 Rebirth"
	progressBtn.AutoButtonColor = true
	progressBtn.Parent = gui
	corner(progressBtn, 12)
	local pbStroke = Instance.new("UIStroke")
	pbStroke.Color = Color3.fromRGB(255, 255, 255)
	pbStroke.Thickness = 1
	pbStroke.Transparency = 0.6
	pbStroke.Parent = progressBtn

	local progGui = Instance.new("ScreenGui")
	progGui.Name = "RebirthProgressGui"
	progGui.ResetOnSpawn = false
	progGui.Enabled = false
	progGui.DisplayOrder = 26
	progGui.Parent = player.PlayerGui
	local pbackdrop = Instance.new("Frame")
	pbackdrop.Size = UDim2.fromScale(1, 1)
	pbackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	pbackdrop.BackgroundTransparency = 0.5
	pbackdrop.BorderSizePixel = 0
	pbackdrop.Parent = progGui
	local pcard = Instance.new("Frame")
	pcard.Size = UDim2.fromOffset(430, 300)
	pcard.Position = UDim2.fromScale(0.5, 0.5)
	pcard.AnchorPoint = Vector2.new(0.5, 0.5)
	pcard.BackgroundColor3 = theme.Panel
	pcard.Parent = progGui
	corner(pcard, 18)
	local pcs = Instance.new("UIStroke")
	pcs.Color = Color3.fromRGB(150, 92, 255)
	pcs.Thickness = 2.5
	pcs.Transparency = 0.2
	pcs.Parent = pcard

	local ptitle = Instance.new("TextLabel")
	ptitle.Size = UDim2.new(1, 0, 0, 44)
	ptitle.Position = UDim2.fromOffset(0, 16)
	ptitle.BackgroundTransparency = 1
	ptitle.Text = "\226\173\144 Rebirth Progress"
	ptitle.TextColor3 = theme.Gold
	ptitle.Font = Enum.Font.FredokaOne
	ptitle.TextSize = 26
	ptitle.Parent = pcard

	local plevel = Instance.new("TextLabel")
	plevel.Size = UDim2.new(1, -40, 0, 24)
	plevel.Position = UDim2.fromOffset(20, 66)
	plevel.BackgroundTransparency = 1
	plevel.TextColor3 = theme.TextMuted
	plevel.Font = Enum.Font.GothamMedium
	plevel.TextSize = 15
	plevel.Parent = pcard

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -40, 0, 28)
	barBg.Position = UDim2.fromOffset(20, 104)
	barBg.BackgroundColor3 = theme.Neutral
	barBg.Parent = pcard
	corner(barBg, 14)
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.BackgroundColor3 = Color3.fromRGB(150, 92, 255)
	barFill.Parent = barBg
	corner(barFill, 14)
	local barText = Instance.new("TextLabel")
	barText.Size = UDim2.fromScale(1, 1)
	barText.BackgroundTransparency = 1
	barText.TextColor3 = Color3.fromRGB(30, 33, 48)
	barText.Font = Enum.Font.GothamBold
	barText.TextSize = 14
	barText.Parent = barBg

	local pbonus = Instance.new("TextLabel")
	pbonus.Size = UDim2.new(1, -40, 0, 66)
	pbonus.Position = UDim2.fromOffset(20, 144)
	pbonus.BackgroundTransparency = 1
	pbonus.TextWrapped = true
	pbonus.TextYAlignment = Enum.TextYAlignment.Top
	pbonus.TextColor3 = theme.Text
	pbonus.Font = Enum.Font.GothamMedium
	pbonus.TextSize = 15
	pbonus.Parent = pcard

	local pAction = Instance.new("TextButton")
	pAction.Size = UDim2.fromOffset(190, 44)
	pAction.Position = UDim2.new(0.5, 0, 1, -20)
	pAction.AnchorPoint = Vector2.new(0.5, 1)
	pAction.BackgroundColor3 = Color3.fromRGB(150, 92, 255)
	pAction.TextColor3 = Color3.fromRGB(255, 255, 255)
	pAction.Font = Enum.Font.FredokaOne
	pAction.TextSize = 18
	pAction.Text = "Rebirth now!"
	pAction.Parent = pcard
	corner(pAction, 10)

	local pClose = Instance.new("TextButton")
	pClose.Size = UDim2.fromOffset(34, 34)
	pClose.Position = UDim2.new(1, -12, 0, 12)
	pClose.AnchorPoint = Vector2.new(1, 0)
	pClose.BackgroundTransparency = 1
	pClose.Text = "\195\151"
	pClose.TextColor3 = theme.TextMuted
	pClose.Font = Enum.Font.GothamBold
	pClose.TextSize = 24
	pClose.Parent = pcard

	local function openConfirm()
		local level = playerState.prestigeLevel or 0
		local nextBonus = math.floor(GameData.getPrestigeMultiplier(level + 1) * 100 - 100)
		cbody.Text = ("This RESETS your cash, studio, PC, workers, subscribers and money rooms.\n\nYou keep your outfit + decorations, and gain a PERMANENT +%d%% cash bonus (total).\n\nYou'll be Prestige %d."):format(nextBonus, level + 1)
		confirmGui.Enabled = true
	end

	-- Update the button label + progress panel from the live player state.
	local function updateProgress()
		local level = playerState.prestigeLevel or 0
		local subs = playerState.subscribers or 0
		local req = GameData.getPrestigeRequirement(level)
		local frac = math.clamp(req > 0 and subs / req or 0, 0, 1)
		local eligible = GameData.canPrestige(subs, level)
		local nextBonus = math.floor(GameData.getPrestigeMultiplier(level + 1) * 100 - 100)

		progressBtn.Text = eligible and "\226\173\144 Rebirth ready!" or ("\226\173\144 Rebirth  %d%%"):format(math.floor(frac * 100))
		plevel.Text = ("You are Prestige %d"):format(level)
		barFill.Size = UDim2.new(frac, 0, 1, 0)
		barText.Text = ("%s / %s subscribers"):format(withCommas(subs), withCommas(req))
		if eligible then
			pbonus.Text = ("You're ready! Rebirth now for a permanent +%d%% cash bonus (total, forever)."):format(nextBonus)
			pAction.Text = "Rebirth now!"
			pAction.BackgroundColor3 = Color3.fromRGB(150, 92, 255)
			pAction.TextColor3 = Color3.fromRGB(255, 255, 255)
			pAction.AutoButtonColor = true
			pAction.Active = true
		else
			pbonus.Text = ("Reach %s subscribers to rebirth. Reward: a permanent +%d%% cash bonus (total, forever)."):format(withCommas(req), nextBonus)
			pAction.Text = ("%d%% there"):format(math.floor(frac * 100))
			pAction.BackgroundColor3 = theme.Neutral
			pAction.TextColor3 = Color3.fromRGB(120, 126, 142)
			pAction.AutoButtonColor = false
			pAction.Active = false
		end
	end

	progressBtn.MouseButton1Click:Connect(function()
		updateProgress()
		progGui.Enabled = true
	end)
	pClose.MouseButton1Click:Connect(function()
		progGui.Enabled = false
	end)
	pAction.MouseButton1Click:Connect(function()
		local level = playerState.prestigeLevel or 0
		if GameData.canPrestige(playerState.subscribers or 0, level) then
			progGui.Enabled = false
			openConfirm()
		end
	end)

	local function refresh()
		local level = playerState.prestigeLevel or 0
		badge.Visible = level > 0
		badge.Text = ("\226\173\144 P%d"):format(level)
		local eligible = GameData.canPrestige(playerState.subscribers or 0, level)
		button.Visible = eligible
		updateProgress()
	end

	button.MouseButton1Click:Connect(openConfirm)
	no.MouseButton1Click:Connect(function()
		confirmGui.Enabled = false
	end)
	yes.MouseButton1Click:Connect(function()
		confirmGui.Enabled = false
		Remotes.RequestPrestige:FireServer()
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(refresh)

	Remotes.PrestigeResult.OnClientEvent:Connect(function(newLevel)
		playerState.prestigeLevel = newLevel
		refresh()
		Sound.play("Rebirth")
		Fx.celebrate(("\226\173\144 REBIRTH! Prestige %d"):format(newLevel), Color3.fromRGB(150, 92, 255))
		-- brief celebration banner
		local toast = Instance.new("TextLabel")
		toast.Size = UDim2.fromOffset(460, 60)
		toast.Position = UDim2.fromScale(0.5, 0.35)
		toast.AnchorPoint = Vector2.new(0.5, 0.5)
		toast.BackgroundColor3 = theme.Panel
		toast.TextColor3 = theme.Gold
		toast.Font = Enum.Font.FredokaOne
		toast.TextSize = 28
		toast.Text = ("\226\173\144 REBIRTH! You are now Prestige %d"):format(newLevel)
		toast.Parent = gui
		corner(toast, 16)
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(150, 92, 255)
		st.Thickness = 2
		st.Parent = toast
		task.delay(3, function()
			toast:Destroy()
		end)
	end)

	task.defer(refresh)
end

return PrestigePanel
