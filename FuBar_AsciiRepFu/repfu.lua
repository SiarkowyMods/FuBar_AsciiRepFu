--------------------------------------------------------------------------------
-- AsciiRepFu (c) 2011-2013 by Siarkowy
-- Released under the terms of BSD-2.0 license.
--------------------------------------------------------------------------------

-- Ace2 and FuBar stuff -t

AsciiRepFu = AceLibrary("AceAddon-2.0"):new(
    "AceDB-2.0",
    "AceEvent-2.0",
    "FuBarPlugin-2.0"
)

local Rep = AsciiRepFu
Rep.hasNoColor = true
Rep.defaultMinimapPosition = 180
Rep.hasIcon = UnitFactionGroup("player") == "Horde"
    and [[Interface\Icons\INV_BannerPVP_01]]
    or  [[Interface\Icons\INV_BannerPVP_02]]

-- Upvalues

local floor = floor
local format = format
local getglobal = getglobal
local tablet = AceLibrary("Tablet-2.0")
local GetWatchedFactionInfo = GetWatchedFactionInfo

-- Locals

local repcolors = {
    "cc2222", -- Hated
    "ff0000", -- Hostile
    "ee6622", -- Unfriendly
    "ffff00", -- Neutral
    "00ff00", -- Friendly
    "00ff88", -- Honored
    "00ffcc", -- Revered
    "00ffff", -- Exalted
}

local standings -- holds login-time faction standings

-- Core

function Rep:OnInitialize()
    self:ExpandFactionHeaders() -- this will expand all headers besides Inactive

    self:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE", "Update")
    self:RegisterEvent("UPDATE_FACTION", "Update")

    self:RegisterDB("AsciiRepFuDB")
    self:RegisterDefaults("profile", {
        barLength = 40,
        char = "||",
        format = "%n: %s %b %c / %M (%p)",
        long = false,
    })
end

function Rep:ExpandFactionHeaders()
    for i = 1, GetNumFactions() do
        local isHeader, isCollapsed = select(9, GetFactionInfo(i))
        if isHeader and isCollapsed then
            ExpandFactionHeader(i)
            return self:ExpandFactionHeaders()
        end
    end
end

function Rep:GetRepBar(val, max, length)
    local _, standing = GetWatchedFactionInfo()
    local len = length or self.db.profile.barLength
    local k = floor(val / max * len)
    local l = len - k
    local char = self.db.profile.char
    return format("|cff%s%s|r|cff%s%s|r", repcolors[standing], char:rep(k), '888888', char:rep(l))
end

function Rep:SaveStandings()
    if not GetWatchedFactionInfo() then
        return
    end

    standings = { }

    for i = 1, GetNumFactions() do
        local name, _, _, _, _, value, _, _, isHeader = GetFactionInfo(i)

        if not isHeader then
            standings[name] = value
        end
    end

    self.standings = standings
end

-- FuBar functions

function Rep:OnClick()
    ToggleCharacter("ReputationFrame")
end

function Rep:OnDataUpdate()
    if standings then return end
    self:SaveStandings()
end

do
    local data = { }

    function Rep:OnTextUpdate()
        local name, standing, min, max, value = GetWatchedFactionInfo()

        if not name then
            self:SetText(self.title)
            return
        end

        local relval = value - min
        local relmax = max - min
        local percent = relval / relmax * 100

        data.ac = value -- current value (absolute)
        data.am = min -- minimum value (absolute)
        data.aM = max -- maximum value (absolute)
        data.b = self:GetRepBar(relval, relmax) -- bar string
        data.c = relval -- current value (relative)
        data.i = standing -- standing identifier
        data.M = relmax -- maximum value (relative)
        data.n = name -- faction name
        data.p = format("%.2f%%", percent) -- percent with % sign
        data.s = getglobal("FACTION_STANDING_LABEL" .. standing) -- standing text
        data.S = format("|cff%s%s|r", repcolors[standing], getglobal("FACTION_STANDING_LABEL" .. standing)) -- standing text (colored)

        self:SetText(self.db.profile.format:gsub("%%(%w+)", data))
    end
end

function Rep:OnTooltipUpdate()
    local name, standing, min, max, value = GetWatchedFactionInfo()
    if not name then
        tablet:SetHint("Left click to open the reputation frame and select watched faction from the list.")
        return
    end

    local relval = value - min
    local relmax = max - min
    local missing = relmax - relval
    local percent = relval / relmax * 100
    local change = value - (standings[name] or 0)

    local cat = tablet:AddCategory(
        'columns', 2,
        'child_text2R', 1,
        'child_text2G', 1,
        'child_text2B', 1
    )

    cat:AddLine('text', "Faction", 'text2', format("%s", name))
    cat:AddLine('text', "Standing", 'text2', format("|cff%s%s|r", repcolors[standing], getglobal("FACTION_STANDING_LABEL" .. standing)))

    cat:AddLine()

    cat:AddLine('text', "Current", 'text2', format("%d (%.2f%%)", relval, percent))
    cat:AddLine('text', "Missing", 'text2', format("%d (%.2f%%)", missing, 100 - percent))
    cat:AddLine('text', "Maximum", 'text2', format("%d (100.0%%)", relmax))

    cat:AddLine()

    cat:AddLine('text', "Change", 'text2', format("|cff%s%+d|r", change < 0 and "ff3333" or change > 0 and "33ff33" or "ffffff", change))

    if change > 0 then
        local q = missing/change

        cat:AddLine('text', "Quotient", 'text2', q > 1000 and "1000+" or format("%.1f", q))
    end

    if not self.db.profile.long and not IsControlKeyDown() then
        return
    end

    for i = 1, GetNumFactions() do
        local name, _, standing, _, _, value, _, _, isHeader = GetFactionInfo(i)

        if isHeader then
            cat = tablet:AddCategory('columns', 2, 'text', name)
        else
            cat:AddLine(
                'text', name,
                'text2', format("|cff%s%s|r", repcolors[standing], getglobal("FACTION_STANDING_LABEL" .. standing)),
                'func', SetWatchedFactionIndex,
                'arg1', i
            )
        end
    end
end

-- Dropdown menu stuff

Rep.OnMenuRequest = {
    type = "group",
    args = {
        char = {
            name = "Character",
            desc = "Character from which to compose reputation indicator bar",
            usage = "<character>",
            type = "text",
            get = function()
                return Rep.db.profile.char
            end,
            set = function(v)
                Rep.db.profile.char = v
                Rep:Update()
            end,
            order = 1
        },
        length = {
            name = "Bar length",
            desc = "Sets reputation indicator bar length",
            usage = "<number>",
            type = "range",
            min = 1,
            max = 100,
            step = 1,
            get = function()
                return Rep.db.profile.barLength
            end,
            set = function(v)
                Rep.db.profile.barLength = v
                Rep:Update()
            end,
            order = 2
        },
        format = {
            name = "Format",
            desc = "Title bar reputation information format",
            usage = [[Allowed tags:
  %ac - current value (absolute)
  %am - minimum value (absolute)
  %aM - maximum value (absolute)
  %b - bar string
  %c - current value (relative)
  %i - standing identifier
  %M - maximum value (relative)
  %n - faction name
  %p - percent with % sign
  %s - standing text
  %S - standing text (colored)]],
            type = "text",
            get = function()
                return Rep.db.profile.format
            end,
            set = function(v)
                Rep.db.profile.format = v
                Rep:Update()
            end,
            order = 3
        },
        long = {
            name = "Extended view",
            desc = "Display faction list with standings",
            type = "toggle",
            get = function()
                return Rep.db.profile.long
            end,
            set = function(v)
                Rep.db.profile.long = v
                Rep:Update()
            end,
            order = 4
        },
    }
}
