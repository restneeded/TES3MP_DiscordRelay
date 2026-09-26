local DiscordRelayChat = {}
local DiscordRelayModules = DiscordRelay.GetModules()
local DiscordRelayConfig = require("custom.DiscordRelay.config")

customEventHooks.registerValidator(
    "OnServerPostInit",
    function()
        tes3mp.LogMessage(enumerations.log.INFO, "[DiscordRelay:chat] Loaded")
    end
)

-- "// message" is OOC, "/// message" is LOOC, anything else starting with / is a command
DiscordRelayChat.parseMessage = function(message)
    if message:sub(1, 1) ~= "/" then
        return "localChat", message
    end

    local command = message:sub(2):match("^([^ ]+)")
    if command == "/" then
        return "ooc", message:sub(3)
    elseif command == "//" then
        return "looc", message:sub(4)
    end
    return nil, message
end

DiscordRelayChat.getStaffRank = function(pid, staffRanks)
    local player = Players[pid]
    if player:IsServerOwner() then
        return staffRanks.ownerPrefix
    elseif player:IsAdmin() then
        return staffRanks.adminPrefix
    elseif player:IsModerator() then
        return staffRanks.moderatorPrefix
    end
    return nil
end

DiscordRelayChat.formatMessage = function(pid, chatType, body, config)
    local playerName = tes3mp.GetName(pid)

    if chatType == "localChat" then
        return "[" .. playerName .. "] " .. body
    end

    local formatted = config[chatType].prefix .. "[" .. playerName .. "]" .. body

    if config.staffRanks.enabled == true then
        local staffRank = DiscordRelayChat.getStaffRank(pid, config.staffRanks)
        DiscordRelayModules.utils.debug("staffRank = " .. tostring(staffRank))
        if staffRank ~= nil then
            formatted = staffRank .. formatted
        end
    end

    return formatted
end

-- Handler instead of a validator so the message shows up in game before we wait on Discord
customEventHooks.registerHandler(
    "OnPlayerSendMessage",
    function(eventStatus, pid, message)
        if not DiscordRelay.IsEnabled() or Players[pid] == nil then
            return
        end

        local chatType, body = DiscordRelayChat.parseMessage(message)
        if chatType == nil or body:match("^%s*$") then
            return
        end

        local config = DiscordRelayConfig.GetConfig()
        local chatConfig = config[chatType]
        if chatConfig.enabled ~= true then
            return
        end

        DiscordRelayModules.utils.sendDiscordMessage(
            chatConfig.channel,
            DiscordRelayChat.formatMessage(pid, chatType, body, config)
        )
    end
)

return DiscordRelayChat
