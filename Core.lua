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

--- Take the newest line back off the log, for a delete that turned out not to happen.
function BW.UnlogLastDeletion()
    if BW.db and BW.db.log then table.remove(BW.db.log, 1) end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
--- Rescan the bags and redraw the button. Debounced, because bag updates arrive in bursts, and
--- skipped entirely while no bag window is open: nothing on screen depends on the plan then, and
--- whoever needs one (a tooltip, a click) asks for it with BW.PlanNow.
function BW.Refresh()
    LIB.Debounce("BagWarden.refresh", 0.2, function()
        if not (BW.BagsOpen and BW.BagsOpen()) then
            BW.planStale = true
            if BW.UpdateButton then BW.UpdateButton() end
            return
        end
        BW.PlanNow()
    end)
end

--- Scan and plan right now, whatever is on screen. Every reader of BW.plan that must be current
--- calls this: the click paths and the tooltips.
function BW.PlanNow()
    BW.items = BW.ScanBags()
    BW.UpdateLootClock(BW.items)
    BW.plan = BW.Plan(BW.items)
    BW.planStale = false
    if BW.UpdateButton then BW.UpdateButton() end
    return BW.plan
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
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
        BW.RegisterWelcome()
        BW.Refresh()
    elseif event == "BAG_UPDATE_DELAYED" then
        BW.Refresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- The client has just filled in an item we couldn't judge: drop what we cached for it and
        -- look again, so "still loading" doesn't stick.
        BW.ForgetItemInfo(arg1)
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
    elseif msg == "free" then
        -- Merging works from chat, deleting does not: the client only allows that inside a real
        -- click or keypress. DeleteStack says so rather than failing silently.
        BW.ReportPlan(false)
    else
        BW.OnLauncherClick("LeftButton")
    end
end

-- The keybinding (Bindings.xml). A keypress is a hardware event, so this one CAN delete, unlike
-- /bagw free typed in chat.
BINDING_HEADER_BAGWARDEN = "BagWarden"
BINDING_NAME_BAGWARDEN_FREE_SLOT = "Free a bag slot"

function BagWardenFreeSlot()
    BW.ReportPlan(true)
end

--- Away from the bags, nothing is ever deleted: the minimap button, the launcher notch and the
--- addon compartment only open things. Deleting lives on the bag frame's own button, where you can
--- see what's in your bags. Left opens the bags (the addon's "window"), right opens the settings.
function BW.OnLauncherClick(mouse)
    if mouse == "RightButton" then BW.OpenOptions() else BW.OpenBags(true) end
end

--- Show the bags. `toggle` closes them again on a second click, which is what a minimap button
--- should do; the welcome card only ever opens them.
function BW.OpenBags(toggle)
    if toggle and type(ToggleAllBags) == "function" then
        ToggleAllBags()
    elseif type(OpenAllBags) == "function" then
        OpenAllBags()
    elseif type(ToggleAllBags) == "function" then
        ToggleAllBags()
    else
        BW.OpenOptions()
    end
end

--- What the minimap button, the notch and the compartment say. The bag button has its own tooltip
--- with the next action; these only open things, so they say so.
function BW.FillLauncherTooltip(tooltip)
    tooltip:AddLine("BagWarden")
    -- Counting free slots is cheap, so this never needs a scan of its own.
    tooltip:AddLine(string.format("Bags: %d free of %d", BW.FreeSlots(), BW.TotalSlots()), 0.8, 0.8, 0.8)
    tooltip:AddLine("Left-click: open your bags", 0.6, 0.6, 0.6)
    tooltip:AddLine("Right-click: settings", 0.6, 0.6, 0.6)
end

function BagWarden_OnAddonCompartmentClick(_, button)
    BW.OnLauncherClick(button)
end

function BagWarden_OnAddonCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    BW.FillLauncherTooltip(GameTooltip)
    GameTooltip:Show()
end

function BagWarden_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

--- Our page in the shared YippYapp welcome window. BagWarden needs no setup, so it never opens the
--- window by itself; the page waits for /yippyapp or the "Welcome" button.
function BW.RegisterWelcome()
    if not LIB.RegisterWelcome then return end
    LIB.RegisterWelcome({
        id = "BagWarden", title = "BagWarden", version = 1, order = 40,
        icon = "Interface\\AddOns\\BagWarden\\Media\\icon",
        subtitle = "One click, one free bag slot.",
        blurb = "A button in your bag window frees one slot per click, by deleting the least valuable junk "
            .. "stack you carry. It tells you which item that is before you click, "
            .. "and never touches quest items, profession gear, recipes or anything green and above.",
        onOpen = function() BW.OpenBags(false) end,
    }, BW.db)
end

function BW.RegisterMinimap()
    if LIB.RegisterMinimapButton then
        LIB.RegisterMinimapButton("BagWarden", {
            icon = "Interface\\AddOns\\BagWarden\\Media\\minimap",
            label = "BagWarden",
            OnClick = function(_, button) BW.OnLauncherClick(button) end,
            OnTooltipShow = function(tooltip) BW.FillLauncherTooltip(tooltip) end,
        }, BW.db)
    end
    if LIB.RegisterLauncher then
        LIB.RegisterLauncher({
            id = "BagWarden", label = "BagWarden", order = 40,
            icon = "Interface\\AddOns\\BagWarden\\Media\\notch",
            onClick = function(_, button) BW.OnLauncherClick(button) end,
            status = function() return BW.FreeSlots() .. " free" end,
            tooltip = { "Left-click: open your bags", "Right-click: settings" },
        }, BW.db)
    end
end
