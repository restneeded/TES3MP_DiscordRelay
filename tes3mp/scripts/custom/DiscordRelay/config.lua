local DiscordRelayConfig = {}

local json = require("dkjson")

local config = {}
local configFile = "custom/DiscordRelayConfig.json"
local legacyConfigFile = "discord_config.json"

local defaultConfig = {
    discordRelay = {
        configVersion = 1,
        debug = false,
        token = "",
        userModules = {
            chat = true
        }
    },
    localChat = {
        enabled = true,
        channel = ""
    },
    ooc = {
        enabled = false,
        channel = "",
        prefix = "[OOC]"
    },
    looc = {
        enabled = false,
        channel = "",
        prefix = "[LOOC]"
    },
    staffRanks = {
        enabled = false,
        moderatorPrefix = "[Mod]",
        adminPrefix = "[Admin]",
        ownerPrefix = "[Owner]"
    }
}

local keyOrder = {
    "discordRelay", "localChat", "ooc", "looc", "staffRanks",
    "token", "debug", "enabled", "channel", "prefix",
    "moderatorPrefix", "adminPrefix", "ownerPrefix", "userModules", "configVersion"
}

local function log(level, message)
    tes3mp.LogMessage(level, "[DiscordRelay:config] " .. message)
end

local function getDataFilePath(fileName)
    return tes3mp.GetDataPath() .. "/" .. fileName
end

local function fileExists(path)
    local file = io.open(path, "r")
    if file ~= nil then
        file:close()
        return true
    end
    return false
end

local function fillMissing(target, defaults)
    local changed = false
    for key, defaultValue in pairs(defaults) do
        if target[key] == nil then
            target[key] = type(defaultValue) == "table" and tableHelper.deepCopy(defaultValue) or defaultValue
            changed = true
        elseif type(defaultValue) == "table" and type(target[key]) == "table" then
            changed = fillMissing(target[key], defaultValue) or changed
        end
    end
    return changed
end

-- The old discord_config.json shipped with comments, which isn't valid JSON
local function stripJsonComments(text)
    local out = {}
    local i, len = 1, #text
    local inString = false

    while i <= len do
        local char = text:sub(i, i)
        local pair = text:sub(i, i + 1)

        if inString then
            table.insert(out, char)
            if char == "\\" then
                table.insert(out, text:sub(i + 1, i + 1))
                i = i + 1
            elseif char == '"' then
                inString = false
            end
            i = i + 1
        elseif char == '"' then
            inString = true
            table.insert(out, char)
            i = i + 1
        elseif pair == "//" then
            i = (text:find("\n", i, true) or len + 1)
        elseif pair == "/*" then
            local closing = text:find("*/", i + 2, true)
            i = closing and closing + 2 or len + 1
        else
            table.insert(out, char)
            i = i + 1
        end
    end

    return table.concat(out)
end

DiscordRelayConfig.GetConfig = function()
    if next(config) == nil then
        return DiscordRelayConfig.LoadConfig()
    end
    return config
end

DiscordRelayConfig.SaveConfig = function(newConfig)
    if newConfig ~= nil then
        jsonInterface.save(configFile, newConfig, keyOrder)
    end
end

DiscordRelayConfig.LoadConfig = function()
    local configPath = getDataFilePath(configFile)

    if not fileExists(configPath) then
        local newConfig = DiscordRelayConfig.MigrateFromLegacy()

        if newConfig == nil then
            newConfig = tableHelper.deepCopy(defaultConfig)
            log(enumerations.log.WARN, "Default configuration has been generated at: \"" .. configPath .. "\"")
        end

        DiscordRelayConfig.SaveConfig(newConfig)
        config = newConfig
        return config
    end

    local loadedConfig = jsonInterface.load(configFile)
    if type(loadedConfig) ~= "table" then
        -- Don't overwrite a broken config, the user might lose their token
        log(enumerations.log.ERROR, "\"" .. configPath .. "\" is not valid JSON, fix it or delete it to regenerate.")
        config = {}
        return nil
    end

    if fillMissing(loadedConfig, defaultConfig) then
        log(enumerations.log.INFO, "Added missing settings to \"" .. configPath .. "\" with their default values.")
        DiscordRelayConfig.SaveConfig(loadedConfig)
    end

    config = loadedConfig
    return config
end

DiscordRelayConfig.MigrateFromLegacy = function()
    local legacyPath = getDataFilePath(legacyConfigFile)
    local file = io.open(legacyPath, "r")
    if file == nil then
        return nil
    end

    local content = file:read("*a")
    file:close()

    local ok, legacy = pcall(json.decode, stripJsonComments(content))
    if not ok or type(legacy) ~= "table" then
        log(enumerations.log.WARN, "Found \"" .. legacyPath .. "\" but couldn't parse it, skipping migration.")
        return nil
    end

    log(enumerations.log.INFO, "Migrating settings from \"" .. legacyPath .. "\"")

    local newConfig = tableHelper.deepCopy(defaultConfig)
    local function migrate(section, key, legacyKey)
        if legacy[legacyKey] ~= nil then
            newConfig[section][key] = legacy[legacyKey]
        end
    end

    migrate("discordRelay", "debug", "debug")
    migrate("discordRelay", "token", "token")
    migrate("localChat", "enabled", "enableLocal")
    migrate("localChat", "channel", "local_Channel")
    migrate("ooc", "enabled", "enableOOC")
    migrate("ooc", "channel", "ooc_Channel")
    migrate("ooc", "prefix", "oocPrefix")
    migrate("looc", "enabled", "enableLOOC")
    migrate("looc", "channel", "looc_Channel")
    migrate("looc", "prefix", "loocPrefix")
    migrate("staffRanks", "enabled", "showStaffRanks")
    migrate("staffRanks", "moderatorPrefix", "ModeratorPrefix")
    migrate("staffRanks", "adminPrefix", "AdminPrefix")
    migrate("staffRanks", "ownerPrefix", "OwnerPrefix")

    log(enumerations.log.INFO, "Migration done, you can delete \"" .. legacyPath .. "\" now.")
    return newConfig
end

-- Returns a list of errors that stop the relay and a list of warnings for disabled features
DiscordRelayConfig.Validate = function(cfg)
    local errors = {}
    local warnings = {}

    if type(cfg) ~= "table" or next(cfg) == nil then
        table.insert(errors, "Configuration is missing or couldn't be loaded")
        return errors, warnings
    end

    local function requireBoolean(value, name)
        if type(value) ~= "boolean" then
            table.insert(errors, name .. " must be set to true or false")
            return false
        end
        return true
    end

    local function requireString(value, name)
        if type(value) ~= "string" or value == "" then
            table.insert(errors, name .. " cannot be blank")
        end
    end

    -- Discord IDs are too big for JSON numbers so they have to be strings
    local function requireChannel(value, name)
        if type(value) ~= "string" or not value:match("^%d+$") then
            table.insert(errors, name .. " must be a Discord channel ID in quotes, like \"123456789012345678\"")
        end
    end

    local relay = type(cfg.discordRelay) == "table" and cfg.discordRelay or {}
    requireBoolean(relay.debug, "discordRelay.debug")
    requireString(relay.token, "discordRelay.token")

    local chatTypes = {
        { key = "localChat", label = "Local Chat", hasPrefix = false },
        { key = "ooc", label = "OOC Chat", hasPrefix = true },
        { key = "looc", label = "Local OOC Chat", hasPrefix = true }
    }

    for _, chatType in ipairs(chatTypes) do
        local section = type(cfg[chatType.key]) == "table" and cfg[chatType.key] or {}
        if requireBoolean(section.enabled, chatType.key .. ".enabled") then
            if section.enabled then
                requireChannel(section.channel, chatType.key .. ".channel")
                if chatType.hasPrefix then
                    requireString(section.prefix, chatType.key .. ".prefix")
                end
            else
                table.insert(warnings, chatType.label .. " is disabled via config file")
            end
        end
    end

    local staffRanks = type(cfg.staffRanks) == "table" and cfg.staffRanks or {}
    if requireBoolean(staffRanks.enabled, "staffRanks.enabled") and staffRanks.enabled then
        requireString(staffRanks.moderatorPrefix, "staffRanks.moderatorPrefix")
        requireString(staffRanks.adminPrefix, "staffRanks.adminPrefix")
        requireString(staffRanks.ownerPrefix, "staffRanks.ownerPrefix")
    end

    return errors, warnings
end

return DiscordRelayConfig
