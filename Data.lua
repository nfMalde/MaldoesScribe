local _, ns = ...

--[[
Maldö's links, the same as in GT Toolz and the Inc Caller. The game cannot open a browser,
so a click shows the link in the copy window.
]]
ns.Links = {
    { id = "paypal", name = "PayPal", donate = true, url = "https://www.paypal.com/donate/?hosted_button_id=SVZHLRTQ6H4VL" },
    { id = "discord", name = "Discord", short = "DC", url = "https://discord.gg/GbvU9sns5z" },
    { id = "twitch", name = "Twitch", short = "TW", url = "https://www.twitch.tv/maldoe" },
    { id = "youtube", name = "YouTube", short = "YT", url = "https://www.youtube.com/@dermaldoe" },
    { id = "facebook", name = "Facebook", short = "FB", url = "https://www.facebook.com/RealMaldoe" },
    { id = "x", name = "X", short = "X", url = "https://x.com/DerMaldoe" },
    { id = "instagram", name = "Instagram", short = "IG", url = "https://www.instagram.com/maldoe_gaming/" },
}

-- Hyperlink types the game uses and the Wowhead page type they belong to.
ns.WowheadKinds = {
    item = "item",
    quest = "quest",
    spell = "spell",
    enchant = "spell",
    achievement = "achievement",
    currency = "currency",
    npc = "npc",
    object = "object",
    faction = "faction",
}

-- Link types whose "kind:id" is useful on its own (macros, /use item:1234, databases).
ns.IdKinds = { item = true, spell = true, quest = true, enchant = true, achievement = true, currency = true }

-- Web addresses in chat: a word is a link when it has a scheme, starts with www. or ends in
-- one of these domains (a bare "example.com" or "example.de/path").
ns.Domains = {}
for domain in ("com net org de at ch eu gg tv io me info co uk dev app link be ly to us fr nl es it pl ru se no dk fi cz br xyz gl wtf stream live"):gmatch("%a+") do
    ns.Domains[domain] = true
end

-- Chat events whose message text is scanned for web addresses.
ns.UrlEvents = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM",
}
