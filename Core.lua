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
    -- Which crafting reagents to keep: "mine" (the ones your professions use, which needs
    -- Skillwright to tell them apart), "all", or "none". See Protect.lua step 5b.
    reagentKeep = "mine",
    -- Ask before deleting anything of this quality or better: 0 grey, 1 white, 2 = don't ask on
    -- quality alone. Green is handled by allowGreen below and always asks. Reagents, consumables and
    -- anything a quest has wanted always ask, whatever this says.
    askFrom = 2,
    allowGreen = false,     -- let green items be deleted at all; they always ask first (Protect.lua)
    ignore = {},            -- [itemID] = true, never delete (right-click the button, or the popup)
    scrap = {},             -- [itemID] = true, sell this at the next merchant (Alt-click in your bags)
    log = {},               -- what we deleted, newest first: { link, name, count, value, when }
    learned = {},           -- ["item name in lower case"] = "quest title", account-wide, see Quests.lua
    minimap = {},         -- LibDBIcon's own store, filled by LIB.RegisterMinimapButton

    -- The on-screen row (Bar.lua). Flat keys rather than one nested table on purpose: PrepareDB
    -- merges shallowly, so a key added later reaches everyone who already has the row turned on -
    -- a nested table would only ever be filled in for a brand-new install.
    barEnabled = true,      -- on, but silent until the bags are nearly full (barFreeSlots below)
    barCount = 4,           -- how many icons, 1-10
    barSize = 36,           -- pixels per icon
    barDirection = "RIGHT", -- which way the row grows from its first icon: RIGHT/LEFT/DOWN/UP
    barHideInCombat = true, -- deleting is refused in combat anyway, so the icons can only be clutter
    barFreeSlots = 4,       -- show only at or below this many free slots; 0 means always show
    barLocked = false,      -- stop it being dragged once it is where you want it
    barShowPrice = false,   -- the price under each icon, as well as in the tooltip
    barShowFree = true,     -- the free-slot line above the row: amber when low, red when full
}

local migrations = {
    -- 2: "keep crafting reagents" became a three-way choice. Whoever had it off wanted reagents
    -- deletable, so they get "none"; everyone else gets the new default.
    [2] = function(db)
        if db.reagentKeep == nil then
            db.reagentKeep = (db.keepReagents == false) and "none" or "mine"
        end
        db.keepReagents = nil
    end,

    -- 3: the on-screen row went from off-by-default to on, showing itself only once four slots or
    -- fewer are left. A default change reaches a new install on its own; it does not reach anyone
    -- whose saved variables already hold the old value, which is everyone who has run the build
    -- where the row first appeared.
    --
    -- This cannot tell "never touched it" from "deliberately turned it off", so it only moves a
    -- setting still sitting on the exact old defaults - and it is only honest to do at all because
    -- the row has never been in a release. Nobody has had the chance to form a preference yet. Do
    -- NOT copy this for a setting that has shipped.
    [3] = function(db)
        if db.barEnabled == false and (db.barFreeSlots or 0) == 0 then
            db.barEnabled, db.barFreeSlots = true, 4
        end
    end,

    -- 4 is DELIBERATELY EMPTY, and must stay spent rather than be tidied back to 3.
    --
    -- It briefly cleared `notch`, `notchPrefs` and `notchHidden` - the launcher bar's position, its
    -- style, and which icons were tucked away. That was withdrawn on ownership, not on taste: the
    -- library WRITES all three into our table (Launcher.lua:54-80), the same way it writes
    -- `welcomeSeen` (Welcome.lua:33), so it clears all four once in its own final step. Six addons
    -- each deciding gave six slightly different saved files for one change - Guildhall had reached
    -- the opposite conclusion on the same three keys, and both arguments were sound.
    --
    -- The number stays at 4 because schema numbers may only ever go forward. A saved file that
    -- already reached 4 under the old migration would silently skip a future migration 4 if this
    -- went back to 3, and the files that reached it belong to whoever runs the dev build - the one
    -- person whose saved variables we most need to be right.
}

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
-- The scrap list: sell this, don't make me decide again
-- ---------------------------------------------------------------------------
-- Separate from the never-delete list because they are different verbs, not opposites. Scrap says
-- "sell it", never-delete says "don't destroy it", and an item can honestly be both: a trinket you
-- want turned into money but never binned. So neither list overrides the other - the only thing
-- scrap changes is what a merchant visit sells.
function BW.IsScrap(itemID)
    return itemID ~= nil and BW.db and BW.db.scrap and BW.db.scrap[itemID] == true
end

function BW.SetScrap(itemID, on)
    if not (itemID and BW.db) then return end
    BW.db.scrap = BW.db.scrap or {}
    BW.db.scrap[itemID] = on and true or nil
    -- The coin on the slot has to appear on the same click that put it there, and Refresh is
    -- debounced - and skipped outright when nothing on screen needs a plan.
    if BW.MarkScrap then BW.MarkScrap() end
    BW.Refresh()
end

-- ---------------------------------------------------------------------------
-- The log of what was deleted
-- ---------------------------------------------------------------------------
BW.LOG_MAX = 200

--- Remember a deletion, newest first. Account-wide, so the log survives a character switch.
function BW.LogDeletion(item, value, skippedAsk, unlockedBy)
    if not (BW.db and item) then return end
    table.insert(BW.db.log, 1, {
        link = item.link,
        name = item.name,
        count = item.count,
        value = value or 0,
        when = time(),
        -- Ctrl was held, so no popup was shown. Recorded so "I never confirmed that" has an answer.
        ctrl = skippedAsk and true or nil,
        -- Set when another addon overruled our own "keep this" - it says which, and why.
        unlocked = unlockedBy or nil,
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
--- skipped entirely while nothing on screen depends on the plan: with the bags shut and the row
--- not showing, whoever needs a plan (a tooltip, a click) asks for one with BW.PlanNow.
---
--- The test asks BarShouldShow, not BarWanted, and the difference is the whole cost of the row
--- being on by default. The row is hidden until four slots are left, and a hidden row needs no
--- plan - but it does need to know when to appear, and that is BW.FreeSlots: five calls against
--- the hundred-odd a full scan costs. So with room to spare we pay the five and stop.
--- It also means no scanning at all during combat while "hide it in combat" is on, which is exactly
--- when loot is arriving fastest.
function BW.Refresh()
    LIB.Debounce("BagWarden.refresh", 0.2, function()
        if not ((BW.BagsOpen and BW.BagsOpen()) or (BW.BarShouldShow and BW.BarShouldShow())) then
            BW.planStale = true
            if BW.UpdateButton then BW.UpdateButton() end
            if BW.UpdateBar then BW.UpdateBar() end
            return
        end
        BW.PlanNow()
    end)
end

--- A stack we have just deleted. The client clears the slot when it gets round to it, so a scan
--- taken in the same click still sees it; until the bags update, we leave it out ourselves.
--- Cleared on BAG_UPDATE_DELAYED, which is the client confirming.
function BW.Forget(item)
    BW.goneAlready = item and { bag = item.bag, slot = item.slot, itemID = item.itemID } or nil
end

local function WithoutTheDeleted(items)
    local gone = BW.goneAlready
    if not gone then return items end
    for index, item in ipairs(items) do
        if item.bag == gone.bag and item.slot == gone.slot and item.itemID == gone.itemID then
            table.remove(items, index)
            break
        end
    end
    return items
end

--- Scan and plan right now, whatever is on screen. Every reader of BW.plan that must be current
--- calls this: the click paths and the tooltips.
function BW.PlanNow()
    BW.items = WithoutTheDeleted(BW.ScanBags())
    BW.UpdateLootClock(BW.items)
    BW.plan = BW.Plan(BW.items)
    BW.planStale = false
    if BW.UpdateButton then BW.UpdateButton() end
    if BW.UpdateBar then BW.UpdateBar() end
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
        BW.db = LIB.PrepareDB(BagWardenDB, defaults, migrations, 4)
    elseif event == "PLAYER_LOGIN" then
        BW.RegisterOptions()
        BW.RegisterMinimap()
        -- /yippyapp test runs every addon's checks in one go; ours is the same set as /bagw test.
        if LIB.RegisterSelfTest then LIB.RegisterSelfTest("BagWarden", BW.SelfTest) end
        BW.Refresh()
    elseif event == "BAG_UPDATE_DELAYED" then
        -- The client has caught up, so whatever we were pretending had gone really has.
        BW.goneAlready = nil
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
        if BW.WhereIsBar then BW.Print(BW.WhereIsBar()) end
    elseif msg == "debug" then
        BW.db.debug = not BW.db.debug
        BW.Print("debug %s", BW.db.debug and "on" or "off")
    elseif msg == "settings" or msg == "options" then
        BW.OpenOptions()
    elseif msg == "sell" then
        -- What a merchant visit would do, and why anything is held back. Sells nothing, and works
        -- away from a merchant too - which is the point, since "it did not sell" is reported after
        -- the fact.
        BW.SellReport()
    elseif msg == "bags" then
        -- The bags are the player's own window; this is just a convenience for a macro.
        if type(ToggleAllBags) == "function" then ToggleAllBags() end
    elseif msg == "free" then
        -- Merging works from chat, deleting does not: the client only allows that inside a real
        -- click or keypress. DeleteStack says so rather than failing silently.
        BW.ReportPlan(false)
    else
        BW.OnIconClick()
    end
end

-- The keybinding (Bindings.xml). A keypress is a hardware event, so this one CAN delete, unlike
-- /bagw free typed in chat.
BINDING_HEADER_BAGWARDEN = "BagWarden"
BINDING_NAME_BAGWARDEN_FREE_SLOT = "Free a bag slot"

function BagWardenFreeSlot()
    -- Ctrl held at the moment of the press skips the question, exactly like a Ctrl-click.
    BW.ReportPlan(true, IsControlKeyDown())
end

--- Every icon we own - the minimap button and the addon compartment - opens the settings, whichever
--- mouse button was used. BagWarden has no window of its own: its UI is the button inside Blizzard's
--- bag window, which the player opens themselves. Nothing out here ever deletes.
--- (Named for the launcher bar until it was removed; the two icons it also served are still here.)
function BW.OnIconClick()
    BW.OpenOptions()
end

--- What the minimap button and the compartment say. The bag button has its own tooltip with the
--- next deletion; these only open the settings, so they say so and nothing more.
function BW.FillIconTooltip(tooltip)
    tooltip:AddLine("BagWarden")
    -- Counting free slots is cheap, so this never needs a scan of its own.
    tooltip:AddLine(string.format("Bags: %d free of %d", BW.FreeSlots(), BW.TotalSlots()), 0.8, 0.8, 0.8)
    tooltip:AddLine("Click: settings", 0.6, 0.6, 0.6)
end

function BagWarden_OnAddonCompartmentClick()
    BW.OnIconClick()
end

function BagWarden_OnAddonCompartmentEnter(_, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    BW.FillIconTooltip(GameTooltip)
    GameTooltip:Show()
end

function BagWarden_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

-- The welcome window is gone, so there is no page to register. BagWarden's page had no body of its
-- own anyway - a title, a one-line subtitle and an Open button - so nothing was lost in the move;
-- what the addon explains about itself now lives at the bottom of its settings page, where someone
-- looking for help actually goes. See HELP in Options.lua.

function BW.RegisterMinimap()
    if LIB.RegisterMinimapButton then
        LIB.RegisterMinimapButton("BagWarden", {
            icon = "Interface\\AddOns\\BagWarden\\Media\\minimap",
            label = "BagWarden",
            OnClick = function() BW.OnIconClick() end,
            OnTooltipShow = function(tooltip) BW.FillIconTooltip(tooltip) end,
        }, BW.db)
    end
end
