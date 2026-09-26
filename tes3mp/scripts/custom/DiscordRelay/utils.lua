local DiscordRelayUtils = {}

local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson")
local DiscordRelayConfig = require("custom.DiscordRelay.config")

local discordApiUrl = "https://discord.com/api/v10"
local userAgent = "DiscordBot (https://github.com/restneeded/TES3MP_DiscordRelay, v2.0.0)"
local maxMessageLength = 2000

-- Discord counts characters, not bytes
local function utf8Length(str)
    local _, count = str:gsub("[^\128-\191]", "")
    return count
end

DiscordRelayUtils.log = function(level, message)
    tes3mp.LogMessage(level, "[DiscordRelay] " .. message)
end

DiscordRelayUtils.debug = function(message)
    local config = DiscordRelayConfig.GetConfig()
    if config ~= nil and config.discordRelay.debug == true then
        DiscordRelayUtils.log(enumerations.log.INFO, message)
    end
end

DiscordRelayUtils.isJsonValidEncode = function(value)
    local success, result = pcall(json.encode, value)
    if success and type(result) == "string" then
        return result
    end
    return nil
end

DiscordRelayUtils.sendDiscordMessage = function(channel, message)
    local config = DiscordRelayConfig.GetConfig()
    if config == nil then
        return false
    end

    if utf8Length(message) > maxMessageLength then
        DiscordRelayUtils.log(enumerations.log.WARN, "Message is over Discord's " .. maxMessageLength .. " character limit. Skipping")
        return false
    end

    local encodedMessage = DiscordRelayUtils.isJsonValidEncode(message)
    if encodedMessage == nil then
        DiscordRelayUtils.log(enumerations.log.WARN, "Failed to encode message for Discord.")
        return false
    end

    -- Built by hand so parse is always an empty array, this stops players pinging @everyone and roles
    local body = '{"content":' .. encodedMessage .. ',"allowed_mentions":{"parse":[]}}'
    local responseBody = {}

    local result, code = https.request{
        url = discordApiUrl .. "/channels/" .. channel .. "/messages",
        method = "POST",
        protocol = "tlsv1_2",
        headers = {
            ["Authorization"] = "Bot " .. config.discordRelay.token,
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#body),
            ["User-Agent"] = userAgent
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(responseBody)
    }

    if result == nil then
        DiscordRelayUtils.log(enumerations.log.WARN, "Failed to send message, " .. tostring(code))
        return false
    end

    if type(code) ~= "number" or code < 200 or code >= 300 then
        DiscordRelayUtils.log(enumerations.log.WARN, "Failed to send message, Response was " .. tostring(code) ..
            ": " .. table.concat(responseBody))
        return false
    end

    DiscordRelayUtils.debug("Message Sent")
    return true
end

return DiscordRelayUtils
