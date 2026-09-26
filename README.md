# Discord Relay for TES3MP

Sends your TES3MP server chat into Discord channels through a bot.

The original [TES3MP_DiscordRelay](https://github.com/HotaruBlaze/TES3MP_DiscordRelay) by HotaruBlaze got deprecated when [goTES3MP](https://github.com/HotaruBlaze/goTES3MP) came out. It still ran on Script Loader, which is dead now, so I rebuilt it on the hooks TES3MP has had since 0.7 and laid it out the same way goTES3MP does. It does the same job as before, it just works on current servers.

If you want Discord messages showing up in game, slash commands, or VPN blocking, go use goTES3MP. This one is for when you just want chat going to Discord and don't feel like running an IRC server and a Go binary next to TES3MP.

## What it does

Local chat, OOC (`// message`) and LOOC (`/// message`) each go to their own Discord channel. You can put staff ranks in front of OOC and LOOC so it reads like `[Admin][OOC][Name] message`.

The config makes itself the first time you start the server. If you're coming from the old version your `discord_config.json` gets pulled in automatically, comments and all.

Players can't ping @everyone, @here or roles through the relay.

## Install

Copy the `custom` and `lib` folders from `tes3mp/` into your `server` folder.

Add this line to `server/scripts/customScripts.lua`:

```lua
DiscordRelay = require("custom/DiscordRelay/main")
```

Start the server once. It'll write `server/data/custom/DiscordRelayConfig.json` and tell you the token is missing. Fill the config in, then restart or type `/reloadDiscordRelay` in game as an admin.

### Coming from the old version

Take `discordRelay` out of `data/scripts.json` and delete `scripts/addons/discordRelay.lua`. Then just install like above. Once it says the migration is done you can delete the old `data/discord_config.json`.

## Config

Everything lives in `data/custom/DiscordRelayConfig.json`.

```json
{
    "discordRelay": {
        "token": "your bot token",
        "debug": false,
        "userModules": { "chat": true }
    },
    "localChat": { "enabled": true, "channel": "123456789012345678" },
    "ooc": { "enabled": false, "channel": "", "prefix": "[OOC]" },
    "looc": { "enabled": false, "channel": "", "prefix": "[LOOC]" },
    "staffRanks": {
        "enabled": false,
        "moderatorPrefix": "[Mod]",
        "adminPrefix": "[Admin]",
        "ownerPrefix": "[Owner]"
    }
}
```

Keep channel IDs in quotes. They're too big for JSON numbers and Lua will mangle them if you don't.

`debug` logs every message that goes through. `userModules` is which files in `userModules/` get loaded, so if you write your own you just drop it in there and add it to the list.

If something in the config is wrong the relay turns itself off and logs what's broken instead of spamming Discord with bad requests.

## Commands

`/reloadDiscordRelay` reloads the config without a restart. Admins only.

## Getting a channel ID

In Discord go to User Settings, then Advanced, and turn on Developer Mode. Right click any channel and hit Copy Channel ID.

## Making the bot

1. Make a new application over at the [Discord developer portal](https://discord.com/developers/applications).
2. Go to Bot, hit Reset Token, and copy it somewhere.
3. Go to OAuth2, then URL Generator. Tick `bot`, then View Channels and Send Messages.
4. Open the link it gives you, pick your server, and authorize it.
5. Paste the token into `discordRelay.token`.

## Stuff to know

It only goes one way, TES3MP to Discord.

The `ssl.dll` in `lib` only works on Windows. On Linux you'll need to install LuaSec 0.6 or newer for whatever Lua your server runs.

That bundled LuaSec doesn't check Discord's certificate, so your token isn't as locked down as it should be on a network you don't trust.

Every message is a blocking HTTPS call. It fires after the message already shows in game, but if Discord is slow the server will hitch for a second.

## Credits

Original script by [HotaruBlaze](https://github.com/HotaruBlaze). Layout follows [goTES3MP](https://github.com/HotaruBlaze/goTES3MP).
