local _, ns = ...

--[[
Turning what the game shows into plain text that can be pasted anywhere.

The game marks up its strings with escape codes: |cffRRGGBB colours, |H...|h[name]|h hyperlinks,
|T...|t textures, |K...|k protected Battle.net names, |4one:many; plurals. Players see none of
that, so the copy must not contain it either.
]]

local Text = {}
ns.Text = Text

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end
ns.IsSecret = IsSecret

--- A value as a string, or nil when it is not one or the game keeps it secret.
function ns.Str(value)
    if IsSecret(value) then return nil end
    local kind = type(value)
    if kind == "string" then return value end
    if kind == "number" then return tostring(value) end
    return nil
end

--- A boolean, or nil when the game keeps it secret.
function ns.Bool(value)
    if IsSecret(value) then return nil end
    return value and true or false
end

function ns.Trim(text)
    return (tostring(text):gsub("^%s+", ""):gsub("%s+$", ""))
end

--- "3 |4day:days;" is "3 days", "1 |4day:days;" is "1 day".
local function Plural(count, one, many)
    if tonumber(count) == 1 then return count .. " " .. one end
    return count .. " " .. many
end

--- Turns a string with UI escape codes into the plain text the player reads.
function Text.Clean(raw)
    if type(raw) ~= "string" then return "" end
    local s = raw
    s = s:gsub("|H.-|h(.-)|h", "%1")                        -- hyperlinks: keep the shown text
    s = s:gsub("|T.-|t", "")                                -- textures
    s = s:gsub("|A.-|a", "")                                -- atlas icons
    s = s:gsub("|K.-|k", "[" .. ns.L.BNET_FRIEND .. "]")    -- protected Battle.net names
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")                    -- colours
    s = s:gsub("|cn[^:|]-:", "")                            -- named colours
    s = s:gsub("|r", "")
    s = s:gsub("|n", "\n")
    s = s:gsub("(%d+)%s*|4([^:;|]-):([^;|]-);", Plural)
    s = s:gsub("|4([^:;|]-):([^;|]-);", "%2")
    s = s:gsub("||", "|")                                   -- an escaped pipe, last
    return s
end

-- "[12:34] ", "12:34 ", "12:34:56 " and "3:45 PM ": every timestamp format the chat offers.
local TIMESTAMP = "^%[?%d%d?:%d%d:?%d?%d?%s*[AaPp]?[Mm]?%.?%]?%s+"

--- Removes the timestamp at the start of a chat line.
function Text.StripTimestamp(line)
    local rest = line:gsub(TIMESTAMP, "", 1)
    return rest
end

--- Book pages can be HTML: keep the words, drop the tags.
function Text.StripHtml(s)
    if not s:find("<", 1, true) then return s end
    s = s:gsub("<[Bb][Rr]%s*/?>", "\n")
    s = s:gsub("</[Pp]>", "\n\n")
    s = s:gsub("</[Hh]%d>", "\n\n")
    s = s:gsub("<[^>]->", "")
    s = s:gsub("&nbsp;", " ")
    s = s:gsub("&lt;", "<")
    s = s:gsub("&gt;", ">")
    s = s:gsub("&quot;", "\"")
    s = s:gsub("&amp;", "&")
    s = s:gsub("\n\n\n+", "\n\n")
    return ns.Trim(s)
end

--- Joins the non-empty parts with a blank line between them.
function Text.Sections(parts)
    local out = {}
    for _, part in ipairs(parts) do
        if type(part) == "string" and part ~= "" then out[#out + 1] = part end
    end
    return table.concat(out, "\n\n")
end

--- A heading over a body, or nil when the body is empty.
function Text.Heading(title, body)
    body = ns.Str(body)
    if not body then return nil end
    body = ns.Trim(Text.Clean(body))
    if body == "" then return nil end
    return title .. "\n" .. body
end

--[[
Parses a hyperlink: its kind ("item"), the first number in its data (the id) and the shown
name without brackets. Accepts "item:1234:0:..." as well as "|cff..|Hitem:1234|h[Name]|h|r".
]]
function Text.ParseLink(link, shown)
    if type(link) ~= "string" then return nil end
    local kind, data = link:match("|H(%a+):([^|]*)")
    if not kind then kind, data = link:match("^(%a+):([^|]*)") end
    if not kind then return nil end
    local id = tonumber(data:match("^(%d+)"))
    local name
    if type(shown) == "string" then
        name = ns.Trim(Text.Clean(shown))
        name = name:match("^%[(.*)%]$") or name
        if name == "" then name = nil end
    end
    if not name then
        name = Text.Clean(link)
        name = name:match("^%[(.*)%]$") or name
        if name == "" or name == link then name = nil end
    end
    return kind, id, name, data
end

--- The Wowhead page of a thing, or nil when the kind is unknown or the address is turned off.
function Text.Wowhead(kind, id)
    local page = kind and ns.WowheadKinds[kind]
    id = tonumber(id)
    if not page or not id or id <= 0 then return nil end
    local base = ns.Trim((ns.db and ns.db.wowhead) or ns.defaults.wowhead or "")
    if base == "" then return nil end
    if base:sub(-1) ~= "/" then base = base .. "/" end
    return base .. page .. "=" .. id
end

--- The creature id inside a unit GUID ("Creature-0-4234-0-3-14645-00001E2F5A" is 14645).
function Text.NpcID(guid)
    guid = ns.Str(guid)
    if not guid then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if (kind == "Creature" or kind == "Vehicle") and id then return tonumber(id) end
    return nil
end

--[[
Web addresses in chat. A word is one when it has a scheme (https://...), starts with www. or
is a bare domain from ns.Domains with an optional path. Brackets and punctuation around the
word stay outside the link. Returns the address or nil.
]]
function Text.FindUrl(word)
    if word:find("|", 1, true) then return nil end -- already a link, coloured or an icon
    local lead, core = word:match("^([%(%[<\"']*)(.-)$")
    local url, trail = core:match("^(.-)([%.,;:!%?%)%]>\"']*)$")
    if not url or url == "" then return nil end
    if url:match("^%a[%w%+%.%-]*://[^%s/$.?#].*$") then return url, lead, trail end
    if url:match("^[Ww][Ww][Ww]%.[%w%-]+%.%a%a+") then return url, lead, trail end
    local host, domain = url:match("^([%w%-%.]+)%.(%a+)$")
    if not host then host, domain = url:match("^([%w%-%.]+)%.(%a+)[/:?#]") end
    if host and domain and ns.Domains[domain:lower()]
            and not host:find("^%.") and not host:find("%.$") and not host:find("%.%.") then
        return url, lead, trail
    end
    return nil
end
