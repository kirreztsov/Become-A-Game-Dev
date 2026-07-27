-- Puts a gold "💎 VIP" tag in front of chat messages from players who own the
-- VIP game pass. VIP status is a replicated player attribute (IsVIP) set by the
-- server's MonetizationService, so every client can tag every VIP's messages.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local VIPChat = {}

function VIPChat.setup()
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local plr = Players:GetPlayerByUserId(source.UserId)
			if plr and plr:GetAttribute("IsVIP") then
				props.PrefixText = "<font color=\"#F0C85A\">\240\159\146\142 VIP</font> " .. message.PrefixText
			end
		end
		return props
	end
end

return VIPChat
