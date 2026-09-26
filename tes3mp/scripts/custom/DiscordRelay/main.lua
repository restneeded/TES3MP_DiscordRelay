local DiscordRelay = {}

DiscordRelay.Name = "DiscordRelay"
DiscordRelay.Version = "v2.0.0"
DiscordRelay.Desc = "Connect TES3MP to Discord!"

local DiscordRelayConfig = require("custom.DiscordRelay.config")
local DiscordRelayUtils = require("custom.DiscordRelay.utils")

local DiscordRelayModules = nil
local RelayEnabled = false

DiscordRelay.LoadConfig = function()
    DiscordRelayUtils.log(enumerations.log.INFO, "Initializing Discord Relay " .. DiscordRelay.Version .. "...")

    local config = DiscordRelayConfig.LoadConfig()
    local errors, warnings = DiscordRelayConfig.Validate(config)

    for _, message in ipairs(errors) do
        DiscordRelayUtils.log(enumerations.log.ERROR, message)
    end
    for _, message in ipairs(warnings) do
        DiscordRelayUtils.log(enumerations.log.WARN, "[ " .. message .. " ]")
    end

    RelayEnabled = #errors == 0

    if RelayEnabled then
        DiscordRelayUtils.log(enumerations.log.INFO, "DiscordRelay Started with 0 Errors and " .. #warnings .. " warnings.")
    else
        DiscordRelayUtils.log(enumerations.log.ERROR, #errors .. " errors occurred while initializing DiscordRelay. " ..
            "Relay is off until they're fixed, run /reloadDiscordRelay after editing the config.")
    end

    return RelayEnabled
end

DiscordRelay.LoadModules = function()
    if DiscordRelayModules ~= nil then
        return DiscordRelayModules
    end

    DiscordRelayModules = {}

    local requiredModules = {
        "utils"
    }

    DiscordRelayUtils.log(enumerations.log.INFO, "[Module] Loading Modules...")
    for _, moduleName in ipairs(requiredModules) do
        DiscordRelayUtils.log(enumerations.log.INFO, "[Module] Loading Required Module: \"" .. moduleName .. "\"")
        DiscordRelayModules[moduleName] = require("custom.DiscordRelay." .. moduleName)
    end

    local config = DiscordRelayConfig.GetConfig()
    if config == nil or type(config.discordRelay.userModules) ~= "table" then
        DiscordRelayUtils.log(enumerations.log.ERROR, "[Module] discordRelay.userModules is missing, no userModules loaded.")
        return DiscordRelayModules
    end

    DiscordRelayUtils.log(enumerations.log.INFO, "[Module] Loading user Modules...")
    for moduleName, enabled in pairs(config.discordRelay.userModules) do
        if enabled == true then
            if type(moduleName) ~= "string" or not moduleName:match("^[%w_]+$") then
                DiscordRelayUtils.log(enumerations.log.ERROR, "[Module] Invalid userModule name: \"" .. tostring(moduleName) .. "\"")
            else
                DiscordRelayUtils.log(enumerations.log.INFO, "[Module] Loading userModule: \"" .. moduleName .. "\"")
                local success, module = pcall(require, "custom.DiscordRelay.userModules." .. moduleName)
                if success then
                    DiscordRelayModules[moduleName] = module
                else
                    DiscordRelayUtils.log(enumerations.log.ERROR, "[Module] Failed to load userModule \"" ..
                        moduleName .. "\": " .. tostring(module))
                end
            end
        end
    end

    return DiscordRelayModules
end

DiscordRelay.GetModules = function()
    if DiscordRelayModules ~= nil then
        return DiscordRelayModules
    end
    return DiscordRelay.LoadModules()
end

DiscordRelay.IsEnabled = function()
    return RelayEnabled
end

customEventHooks.registerValidator(
    "OnServerInit",
    function()
        DiscordRelay.LoadConfig()
        DiscordRelay.LoadModules()
        DiscordRelayUtils.log(enumerations.log.INFO, "Loaded")
    end
)

-- Modules read the config on every message so they don't need reloading
customCommandHooks.registerCommand("reloadDiscordRelay", function(pid, cmd)
    local enabled = DiscordRelay.LoadConfig()
    if enabled then
        tes3mp.SendMessage(pid, color.Green .. "[DiscordRelay] " .. color.Default .. "Config reloaded.\n", false)
    else
        tes3mp.SendMessage(pid, color.Red .. "[DiscordRelay] " .. color.Default ..
            "Config has errors, check the server log. Relay is off.\n", false)
    end
end)
customCommandHooks.setRankRequirement("reloadDiscordRelay", 2)

return DiscordRelay
