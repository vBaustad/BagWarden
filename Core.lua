-- BagWarden - free one bag slot per click, without ever deleting anything you need.
-- Core.lua holds the saved variables, the event plumbing, the slash command and the loot clock
-- (which items we are still picking up, used by Value.lua's "potential value" rule).
local ADDON, BW = ...
local LIB = LibStub("LibForever-1.0")

BW.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
BW.TAG = "|cffc9a227BagWarden|r"
local TAG = BW.TAG

-- An item counts as "still being looted" for this long after the last one dropped.
BW.LOOT_WINDOW = 30 * 60

local defaults = {
    sellGreys = true,       -- sell all greys when a merchant window opens
    smallSearch = false,    -- shrink Blizzard's bag search box to free room in the bag's top row
    protectProfession = true, -- keep profession tools, skill gear and recipes (Professions.lua)
    confirmWhite = true,    -- white items always ask first (kept as a setting so it can't be lost)
    ignore = {},            -- [itemID] = true, never delete (right-click the button, or the popup)
    log = {},               -- what we deleted, newest first: { link, name, count, value, when }
    learned = {},           -- ["item name in lower case"] = "quest title", account-wide, see Quests.lua
    minimap = {},
}

local migrations = {}

BW.lootSeen = {}            -- [itemID] = time() when we last gained one
BW.counts = {}              -- [itemID] = how many we held at the last scan, to spot gains

function BW.Print(fmt, ...)
    print(TAG .. ": " .. (select("#", ...) > 0 and fmt:format(...) or fmt))
end

function BW.Debug(fmt, ...)
    if BW.db and BW.db.debug then BW.Print("|cff888888" .. fmt .. "|r", ...) end
end

--- Money with the gold/silver/copper icons. Forever only has the C_CurrencyInfo version (the old
--- global is gone), so resolve it when asked and fall back to plain text if it isn't there.
function BW.Coin(copper)
    copper = math.floor(tonumber(copper) or 0)
    local coin = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    if coin then
        local ok, text = pcall(coin, copper)
        if ok and text then return text end
    end
    return BW.Money(copper)
end

--- Money as "12g 30s 5c", short and without the zero parts.
function BW.Money(copper)
    copper = math.floor(tonumber(copper) or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    if g > 0 then return string.format("%dg %ds", g, s) end
    if s > 0 then return string.format("%ds %dc", s, c) end
    return string.format("%dc", c)
end

-- ---------------------------------------------------------------------------
-- The loot clock
-- ---------------------------------------------------------------------------
--- Note every item we gained since the last scan. Anything that went up is being looted now, which
--- is what lets Value.lua judge a half-full stack by what it will be worth, not what it is worth.
function BW.UpdateLootClock(items)
    local now = time()
    local seen = {}
    for _, it in ipairs(items) do
        seen[it.itemID] = (seen[it.itemID] or 0) + it.count
    end
    for itemID, count in pairs(seen) do
        if count > (BW.counts[itemID] or 0) then BW.lootSeen[itemID] = now end
    end
    BW.counts = seen
end

--- True while we are still picking this item up.
function BW.RecentlyLooted(itemID)
    local at = BW.lootSeen[itemID]
    return at ~= nil and (time() - at) < BW.LOOT_WINDOW
end

-- ---------------------------------------------------------------------------
-- The never-delete list
-- ---------------------------------------------------------------------------
function BW.IsIgnored(itemID)
    return itemID ~= nil and BW.db and BW.db.ignore[itemID] == true
end

function BW.SetIgnored(itemID, on)
    if not (itemID and BW.db) then return end
    BW.db.ignore[itemID] = on and true or nil
    BW.Refresh()
end

-- ---------------------------------------------------------------------------
-- The log of what was deleted
-- ---------------------------------------------------------------------------
BW.LOG_MAX = 200

--- Remember a deletion, newest first. Account-wide, so the log survives a character switch.
function BW.LogDeletion(item, value)
    if not (BW.db and item) then return end
    table.insert(BW.db.log, 1, {
        link = item.link,
        name = item.name,
        count = item.count,
        value = value or 0,
        when = time(),
    })
    for i = #BW.db.log, BW.LOG_MAX + 1, -1 do table.remove(BW.db.log, i) end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
--- Rescan the bags and redraw the button. Debounced: bag updates arrive in bursts.
function BW.Refresh()
    LIB.Debounce("BagWarden.refresh", 0.2, function()
        BW.items = BW.ScanBags()
        BW.UpdateLootClock(BW.items)
        BW.plan = BW.Plan(BW.items)
        if BW.UpdateButton then BW.UpdateButton() end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_REMOVED")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_PROGRESS")
f:RegisterEvent("QUEST_COMPLETE")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        BagWardenDB = BagWardenDB or {}
        BW.db = LIB.PrepareDB(BagWardenDB, defaults, migrations, 1)
    elseif event == "PLAYER_LOGIN" then
        BW.RegisterOptions()
        BW.RegisterMinimap()
        BW.Refresh()
    elseif event == "BAG_UPDATE_DELAYED" then
        BW.Refresh()
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
        BW.ScanQuestLog()
        BW.Refresh()
    elseif event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        -- A quest giver is open: learn what this quest wants, even if we never accept it.
        BW.LearnFromQuestFrame(event)
    end
end)

-- ---------------------------------------------------------------------------
-- Slash command
-- ---------------------------------------------------------------------------
SLASH_BAGWARDEN1 = "/bagw"
SLASH_BAGWARDEN2 = "/bagwarden"
SlashCmdList.BAGWARDEN = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "test" then
        BW.SmokeTest()
    elseif msg == "where" then
        BW.WhereIsButton()
    elseif msg == "debug" then
        BW.db.debug = not BW.db.debug
        BW.Print("debug %s", BW.db.debug and "on" or "off")
    elseif msg == "settings" or msg == "options" then
        BW.OpenOptions()
    else
        BW.ReportPlan()
    end
end

--- The one click BagWarden has: left = do the next thing, right = settings.
function BW.OnLauncherClick(mouse)
    if mouse == "RightButton" then BW.OpenOptions() else BW.ReportPlan() end
end

function BagWarden_OnAddonCompartmentClick(_, button)
    BW.OnLauncherClick(button)
end

function BagWarden_OnAddonCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    BW.FillTooltip(GameTooltip)
    GameTooltip:Show()
end

function BagWarden_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

function BW.RegisterMinimap()
    if LIB.RegisterMinimapButton then
        LIB.RegisterMinimapButton("BagWarden", {
            icon = "Interface\\AddOns\\BagWarden\\Media\\minimap",
            label = "BagWarden",
            OnClick = function(_, button) BW.OnLauncherClick(button) end,
            OnTooltipShow = function(tooltip) BW.FillTooltip(tooltip) end,
        }, BW.db)
    end
    if LIB.RegisterLauncher then
        LIB.RegisterLauncher({
            id = "BagWarden", label = "BagWarden", order = 40,
            icon = "Interface\\AddOns\\BagWarden\\Media\\notch",
            onClick = function(_, button) BW.OnLauncherClick(button) end,
            status = function() return BW.FreeSlots() .. " free" end,
            tooltip = { "Left-click: free a bag slot", "Right-click: settings" },
        }, BW.db)
    end
end
