-- BagWarden - the settings page in Options -> AddOns -> YippYapp -> BagWarden.
--
-- Laid out as rows: a label on the left, its control at one fixed x, every row the same height,
-- every other row faintly banded so a long list can be scanned rather than read. What a setting
-- DOES is in the row's tooltip, not printed under it - a paragraph under each of a dozen toggles
-- turns a page you skim into a page you have to read, and pushes the twelfth setting off the screen.
--
-- Prose is one line per section at most. A settings page is a page you skim; the moment a section
-- carries a paragraph, the paragraph is what you see and the settings are what you hunt for. The
-- player said this page was "ekstremt bloated med alt for mye tekst", and it was: its help block
-- ran 470 words against 167-289 in the five sibling addons, with seven more paragraphs above it.
--
-- So the rule is: the row label says WHAT, its tooltip says the detail, and the help block at the
-- bottom is the only place allowed more than a sentence. Anything that was said twice is now said
-- once, and anything a reader only wants once ever - how BagWarden pairs with the other YippYapp
-- addons - lives on the CurseForge page, not here.
local ADDON, BW = ...
local LIB = LibStub("LibForever-1.0")

local category, panel

-- The in-game explanation, at the bottom of this page. BagWarden's welcome window never had a
-- body, so this is the only place in the game the addon explains itself - which is why it is three
-- short sections rather than none, and why it is not also four paragraphs higher up the page.
-- The library owns where it sits and how it wraps; the words are ours.
local HELP = {
    { "What it does",
        "One button in your bag window frees one bag slot per click, by deleting the least valuable "
        .. "junk stack you carry. The tooltip names the item first, and hovering lights that slot "
        .. "up in your bags.\n\n"
        .. "It never deletes quest items, anything a quest in your log wants, your professions' "
        .. "reagents, anything that cannot be sold, or anything better than green. When a check "
        .. "cannot be made, the item is kept." },

    { "Using it",
        "Open your bags: the button sits next to Blizzard's sort button. Hold Ctrl to skip the "
        .. "question on things that would ask. Right-click it to protect what it was about to "
        .. "delete. There is a keybind too, under BagWarden.\n\n"
        .. "Alt-click any stack up to green and the next merchant buys that one. Alt-click again "
        .. "to sell it every time." },

    { "Good to know",
        "The game only lets an addon delete inside a real click or keypress, so there is no \"clean "
        .. "my bags\" button and never will be. Selling is different: it can be undone from the "
        .. "merchant's buyback list until you walk away." },
}

-- The page is hosted in the YippYapp window, which decides how wide it is, so every block of text
-- is kept and re-widthed when the page is resized.
-- Nothing is ever anchored at a negative x, or it hangs off the page and is clipped.
--
-- The width comes from LIB.OptionsWidth / LIB.OnOptionsResize, never from a number written here.
-- A hardcoded width is not a harmless approximation: the library's own settings page assumed 600
-- inside a 544 scroll frame and pushed its per-addon buttons two-thirds off the right edge. A page
-- that declares a height - ours does - scrolls, so the real width is the frame minus the scrollbar,
-- and only the library knows that. FALLBACK_WIDTH survives for a client running an older library,
-- where it is the same guess as before and no worse.
local FALLBACK_WIDTH = 540      -- only used when the library cannot tell us
local LEFT, INDENT = 8, 30
local CONTROL_X = 240           -- where every row's control sits, measured from the row's left
local ROW_H = 26
local notes = {}

function BW.RegisterOptions()
    if category or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    panel = CreateFrame("Frame")
    local f = panel

    --- Re-wrap every block of text to the width the page actually has. One function, so the library
    --- hook and the old-library fallback cannot wrap to two different numbers.
    local function Relayout(width)
        width = width or f:GetWidth()
        if not width or width <= 0 then return end
        -- Room for the indent on the left and the same margin again on the right.
        local textWidth = math.max(120, width - LEFT - INDENT - LEFT)
        for _, fs in ipairs(notes) do fs:SetWidth(textWidth) end
    end

    -- The width to BUILD at. The real one arrives from LIB.OnOptionsResize once the page is
    -- registered and shown, which is before the player sees it; this only has to be close enough
    -- that nothing is laid out at a silly size in between.
    local buildWidth = (LIB.OptionsWidth and LIB.OptionsWidth(panel)) or FALLBACK_WIDTH
    panel:SetWidth(buildWidth)
    if not LIB.OnOptionsResize then
        -- An older library: keep watching the frame ourselves, exactly as before.
        panel:SetScript("OnSizeChanged", function(_, width) Relayout(width) end)
    end

    -- Everything below chains off `anchor`, so a row can be moved or removed without re-pointing
    -- its neighbours. `band` alternates the row backgrounds.
    local anchor, band

    local function Note(text)
        local fs = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:SetWidth(math.max(120, buildWidth - LEFT - INDENT - LEFT))
        notes[#notes + 1] = fs
        fs:SetJustifyH("LEFT")
        fs:SetSpacing(2)
        fs:SetText(text)
        return fs
    end

    --- A paragraph in the flow, for the three choices that need one. Indented under its heading.
    local function Para(text, gap)
        local fs = Note(text)
        fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -8)
        anchor = fs
        return fs
    end

    local function Section(text)
        local fs = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fs:SetText(text)
        fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)
        local line = f:CreateTexture(nil, "ARTWORK")
        line:SetAtlas("Options_HorizontalDivider")
        line:SetHeight(1)
        line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", f, "RIGHT", -LEFT, 0)
        anchor, band = fs, false
        return fs
    end

    --- One row: label left, control at CONTROL_X, tooltip on hover. `indent` shifts the label only,
    --- for the radio groups, so their controls still line up with everything else.
    local function Row(text, tip, indent)
        local r = CreateFrame("Frame", nil, f)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        r:SetPoint("RIGHT", f, "RIGHT", -LEFT, 0)
        band = not band
        if band then
            local bg = r:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.035)
        end
        local label = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", r, "LEFT", (indent or 0), 0)
        label:SetText(text)
        label:SetJustifyH("LEFT")
        -- No width is set on purpose: a width plus SetWordWrap(false) ellipsises, and a setting whose
        -- name is cut off is worse than one that runs a little wide. The labels are written short
        -- enough to stop before CONTROL_X.
        if tip then
            r:EnableMouse(true)
            r:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(text, 1, 1, 1)
                GameTooltip:AddLine(tip, 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        r.label = label
        anchor = r
        return r
    end

    --- The row's own control sits at CONTROL_X, vertically centred, whatever kind it is.
    local function Place(control, row, yOffset)
        control:SetPoint("LEFT", row, "LEFT", CONTROL_X, yOffset or 0)
        row.control = control
        return control
    end

    local function Toggle(text, tip, onClick)
        local row = Row(text, tip)
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        Place(cb, row)
        cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
        row.check = cb
        return row
    end

    --- A slider with its number beside it. Built by hand because OptionsSliderTemplate is deprecated
    --- on this client - the same reason Guildhall's settings build theirs the same way.
    local function Slider(text, tip, lo, hi, get, set, describe)
        local row = Row(text, tip)
        local s = CreateFrame("Slider", nil, row, "BackdropTemplate")
        s:SetSize(140, 16)
        Place(s, row)
        s:SetOrientation("HORIZONTAL")
        s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 } })
        s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        s:SetMinMaxValues(lo, hi)
        s:SetValueStep(1)
        s:SetObeyStepOnDrag(true)
        local value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        value:SetPoint("LEFT", s, "RIGHT", 10, 0)
        local function SyncText(v) value:SetText(describe and describe(v) or tostring(v)) end
        s:SetScript("OnValueChanged", function(_, v, byUser)
            v = math.floor(v + 0.5)
            SyncText(v)
            -- Only a drag or a click writes a setting. SetValue from Refresh must not save anything,
            -- or merely opening the page would count as the player changing their mind.
            if byUser then set(v) end
        end)
        row.Sync = function()
            local v = get()
            s:SetValue(v)
            SyncText(v)
        end
        row.slider = s
        return row
    end

    --- One button that steps through a short list of choices. A real dropdown would mean picking
    --- between the client's deprecated menu API and its new one; with four choices, a button that
    --- says what it is set to costs the player nothing and us no client-version risk.
    local function Cycle(text, tip, choices, get, set)
        local row = Row(text, tip)
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(140, 22)
        Place(b, row)
        row.Sync = function()
            local current = get()
            for _, choice in ipairs(choices) do
                if choice.value == current then b:SetText(choice.label) return end
            end
            b:SetText(choices[1].label)
        end
        b:SetScript("OnClick", function()
            local current, index = get(), 1
            for i, choice in ipairs(choices) do
                if choice.value == current then index = i break end
            end
            set(choices[(index % #choices) + 1].value)
            row.Sync()
        end)
        row.button = b
        return row
    end

    --- A radio group, one row each. The label carries the choice, so these rows have the radio on
    --- the LEFT of their text, not out at CONTROL_X: a list of alternatives reads as a list.
    local function Radios(choices, get, set)
        local buttons = {}
        for index, choice in ipairs(choices) do
            local row = Row("", nil, INDENT + 22)
            local cb = CreateFrame("CheckButton", nil, row, "UIRadioButtonTemplate")
            cb:SetPoint("LEFT", row, "LEFT", INDENT, 0)
            row.label:SetText(choice.note
                and (choice.label .. " |cff808080(" .. choice.note .. ")|r") or choice.label)
            cb:SetScript("OnClick", function()
                set(choice.value)
                BW.Refresh()
                if panel.OnRefresh then panel.OnRefresh() end
            end)
            buttons[index] = cb
        end
        return buttons
    end

    -- ---------------------------------------------------------------- the page
    local head = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", LEFT, -6)
    head:SetText("BagWarden")
    local version = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", head, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. BW.version)
    anchor = head
    Para("Free one bag slot per click - the least valuable junk stack you carry, named in the "
        .. "tooltip before you click it.")

    -- Whether BagWarden has an icon at all. This used to live on the shared YippYapp page, next to
    -- a "group the buttons" toggle; grouping is fixed on now, so the only question left is this one,
    -- and it belongs to the addon it is about. Near the top because someone hunting for it is
    -- looking for a way to hide an icon, not reading the page through.
    local minimapRow
    if LIB.SetMinimapButtonShown and LIB.IsMinimapButtonShown then
        Section("BagWarden's icon")
        minimapRow = Toggle("Show BagWarden in the minimap row",
            "The YippYapp addons share one minimap button that opens a small row of icons. This is "
            .. "whether BagWarden is one of them. The addon works exactly the same either way - its "
            .. "icon only opens these settings - and you can always get here with /bagw.",
            function(on) LIB.SetMinimapButtonShown("BagWarden", on) end)
    end

    Section("At a merchant")
    local sell = Toggle("Sell all grey items automatically",
        "When you open a vendor, BagWarden sells your grey items and says what they came to. Up to "
        .. "twelve stacks go per visit, greys and scrap together, so everything stays in the "
        .. "merchant's buyback list until you walk away. A grey on your never-delete list is left "
        .. "alone; one you put on the scrap list by hand is sold, because that list is about what "
        .. "gets destroyed, not what gets sold.",
        function(on) BW.db.sellGreys = on end)
    Para("Alt-click any stack up to green in your bags: the next merchant buys that one, then "
        .. "forgets it. Alt-click again to sell it every time, and once more to take it off.", -12)
    local scrapList = Para("", -10)
    local clearScrap = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearScrap:SetSize(160, 22)
    clearScrap:SetText("Empty the scrap list")
    clearScrap:SetPoint("TOPLEFT", scrapList, "BOTTOMLEFT", 0, -8)
    clearScrap:SetScript("OnClick", function()
        wipe(BW.db.scrap or {})
        BW.Refresh()
        if panel.OnRefresh then panel.OnRefresh() end
    end)
    anchor = clearScrap

    Section("The bag button")
    local search = Toggle("Make the bag search box smaller",
        "In the combined bag window Blizzard's search box takes up most of the top row. This shrinks it "
        .. "and moves it to the right, next to the sort button, which leaves the title its space. The "
        .. "separate bags aren't crowded, so nothing changes there.",
        function(on) BW.db.smallSearch = on BW.Refresh() end)

    -- The on-screen row. Everything here is layout except the first toggle, which is also the only
    -- setting on this page that costs anything: with the row on, the bags are rescanned on every bag
    -- update instead of only while a bag window is open (see BW.Refresh).
    Section("The on-screen row")
    local barOn = Toggle("Show a row of icons on screen",
        "The next few stacks BagWarden would delete, cheapest first, without opening your bags. "
        .. "Ctrl-click an icon to act on it, right-click one to protect it, and drag the row to move "
        .. "it. An amber edge means it will ask before it goes, however you click it.\n\n"
        .. "This is the only setting here that costs anything: BagWarden then rescans your bags as "
        .. "they change even while they are shut, because something on screen depends on it.",
        function(on)
            BW.db.barEnabled = on
            BW.ApplyBarSettings()
            if panel.OnRefresh then panel.OnRefresh() end
        end)
    local barCount = Slider("How many icons", "How many stacks the row shows at once.", 1, 10,
        function() return BW.db.barCount or 4 end,
        function(v) BW.db.barCount = v BW.ApplyBarSettings() end)
    local barSize = Slider("Icon size", "How big each icon is, in pixels.", 16, 64,
        function() return BW.db.barSize or 36 end,
        function(v) BW.db.barSize = v BW.ApplyBarSettings() end,
        function(v) return v .. " px" end)
    local barFree = Slider("Only when free slots are down to",
        "Keeps the row out of sight until you are actually running out of room. Four by default, so it "
        .. "appears when you have four slots left and stays out of your way until then. At zero it is "
        .. "always shown.",
        0, 20,
        function() return BW.db.barFreeSlots or 0 end,
        function(v) BW.db.barFreeSlots = v BW.ApplyBarSettings() end,
        function(v) return v == 0 and "always show" or (v .. " or fewer") end)
    local barDir = Cycle("The row grows",
        "Which way the row extends from its first icon. The first icon never moves, whichever you pick.", {
        { value = "RIGHT", label = "Right" }, { value = "DOWN", label = "Down" },
        { value = "LEFT", label = "Left" }, { value = "UP", label = "Up" },
    }, function() return BW.db.barDirection or "RIGHT" end,
       function(v) BW.db.barDirection = v BW.ApplyBarSettings() end)
    local barCombat = Toggle("Hide it in combat",
        "Deleting is refused in combat anyway, so the icons can only be clutter over your action bars.",
        function(on) BW.db.barHideInCombat = on BW.ApplyBarSettings() end)
    local barLock = Toggle("Lock it where it is",
        "Stops the row being dragged once it is where you want it.",
        function(on) BW.db.barLocked = on end)
    local barFreeLine = Toggle("Show how many slots are free",
        "A line above the row: grey normally, amber when you are running low, red when the bags are "
        .. "full. \"Running low\" means the threshold above, or five slots when that is set to always "
        .. "show. It also keeps the row on screen when your bags are full and there is nothing "
        .. "BagWarden can free - which is exactly when you want telling.",
        function(on) BW.db.barShowFree = on BW.ApplyBarSettings() end)
    local barPrice = Toggle("Show the price under each icon",
        "What that stack fetches at a vendor, under the icon as well as in its tooltip.",
        function(on) BW.db.barShowPrice = on BW.ApplyBarSettings() end)

    -- How chatty the confirm popup is. Green and better can never be deleted, so the choice only
    -- covers grey and white.
    Section("Asking first")
    Para("Reagents, food, drink, potions, bandages and anything a quest has ever wanted always ask "
        .. "first. On top of that you can ask by quality.")
    local askChoices = {
        { value = 2, label = "Only reagents and things you use", note = "the least clicking" },
        { value = 1, label = "Also ask about white items" },
        { value = 0, label = "Ask about everything, grey items too" },
    }
    local askButtons = Radios(askChoices, function() return BW.db.askFrom or 2 end,
        function(v) BW.db.askFrom = v end)
    local green = Toggle("Let it delete green items too",
        "Off by default. Green items are normally kept whatever else you choose. Turn this on and vendor "
        .. "greens can go as well - they always ask first, however the choices above are set. Blue and "
        .. "better are never deleted.",
        function(on)
            BW.db.allowGreen = on
            BW.Refresh()
            if panel.OnRefresh then panel.OnRefresh() end
        end)

    -- Everything BagWarden is keeping right now, grouped by why.
    Section("Protected items")
    Para("What BagWarden is keeping in your bags right now, and why.")
    local profession = Toggle("Keep profession gear",
        "On by default. Keeps mining picks, skinning knives, fishing poles, enchanting rods and the like, "
        .. "anything that gives profession skill (+5 Mining gloves), anything that needs a profession, and "
        .. "every recipe, pattern and plan.",
        function(on)
            BW.db.protectProfession = on
            wipe(BW.professionCache)
            BW.Refresh()
            if panel.OnRefresh then panel.OnRefresh() end
        end)
    local reagentChoices = {
        { value = "mine", label = "Keep reagents my professions use" },
        { value = "all", label = "Keep every crafting reagent" },
        { value = "none", label = "Keep none" },
    }
    local reagentButtons = Radios(reagentChoices, function() return BW.db.reagentKeep or "mine" end,
        function(v) BW.db.reagentKeep = v end)
    -- Said plainly, because the honest answer depends on another addon being there.
    local reagentMineNote = Para("", -6)

    local protectedList = Para("", -12)
    local ignoreTitle = Para("", -12)

    -- Your own never-delete list: one row per item, each removable.
    local rows, rowPool = {}, CreateFrame("Frame", nil, f)
    rowPool:SetSize(1, 1)
    rowPool:SetPoint("TOPLEFT", ignoreTitle, "BOTTOMLEFT", 0, -4)

    local function IgnoreRow(index)
        local row = rows[index]
        if row then return row end
        row = CreateFrame("Frame", nil, f)
        row:SetSize(560, 20)
        row:SetPoint("TOPLEFT", rowPool, "TOPLEFT", INDENT, -(index - 1) * 22)
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT")
        row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.remove:SetSize(80, 20)
        row.remove:SetPoint("LEFT", 240, 0)
        row.remove:SetText("Remove")
        rows[index] = row
        return row
    end

    local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clear:SetSize(160, 22)
    clear:SetText("Empty the list")
    clear:SetScript("OnClick", function()
        wipe(BW.db.ignore)
        BW.Refresh()
        if panel.OnRefresh then panel.OnRefresh() end
    end)

    -- The audit log: what BagWarden has actually deleted.
    local h4 = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h4:SetText("Deleted items")
    -- Section() would anchor this into the chain, and Refresh has to move it below however many
    -- never-delete rows there are. So it gets the divider by hand; the line follows the heading.
    local h4Line = f:CreateTexture(nil, "ARTWORK")
    h4Line:SetAtlas("Options_HorizontalDivider")
    h4Line:SetHeight(1)
    h4Line:SetPoint("LEFT", h4, "RIGHT", 8, 0)
    h4Line:SetPoint("RIGHT", f, "RIGHT", -LEFT, 0)
    local logNote = Note("Deleted on this account, newest first. The last "
        .. BW.LOG_MAX .. " are kept, with whether Ctrl was held.")
    local logList = Note("")
    local clearLog = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearLog:SetSize(160, 22)
    clearLog:SetText("Clear log")
    clearLog:SetScript("OnClick", function()
        wipe(BW.db.log)
        if panel.OnRefresh then panel.OnRefresh() end
    end)

    -- The launcher bar is gone, and LIB.LauncherOptions with it. What it used to offer that still
    -- means something is "should this addon have an icon at all", which is now the minimap toggle
    -- near the top of this page.

    --- Group everything in the bags that is kept, by reason.
    local function ProtectedText()
        local items = BW.ScanBags()
        local groups, order = {}, {}
        -- One line per ITEM, not per stack: two stacks of Rough Weightstone are one entry.
        local listed = {}
        for _, item in ipairs(items) do
            local strength, reason = BW.KeepReason(item)
            if strength and not listed[item.itemID] then
                listed[item.itemID] = true
                reason = reason or "kept"
                if not groups[reason] then groups[reason] = {}; order[#order + 1] = reason end
                local names = groups[reason]
                names[#names + 1] = item.link or item.name or "?"
            end
        end
        if #order == 0 then return "Nothing in your bags needs protecting right now." end
        table.sort(order)
        local lines = {}
        for _, reason in ipairs(order) do
            table.sort(groups[reason])
            lines[#lines + 1] = "|cffffd100" .. reason .. ":|r " .. table.concat(groups[reason], ", ")
        end
        return table.concat(lines, "\n")
    end

    local function LogText()
        local log = BW.db.log or {}
        if #log == 0 then return "Nothing deleted yet." end
        local lines = {}
        for i = 1, math.min(20, #log) do
            local entry = log[i]
            lines[#lines + 1] = string.format("%s x%d - %s  |cff808080%s%s|r",
                entry.link or entry.name or "?", entry.count or 1,
                BW.Coin(entry.value or 0), date("%d.%m %H:%M", entry.when or 0),
                (entry.ctrl and " - Ctrl-click" or "") .. (entry.unlocked and (" - " .. entry.unlocked) or ""))
        end
        if #log > 20 then lines[#lines + 1] = string.format("|cff808080...and %d more|r", #log - 20) end
        return table.concat(lines, "\n")
    end

    --- The scrap list, said as a sentence rather than a table: it is usually a handful of items, and
    --- the only thing you do to one is Alt-click it again in your bags.
    local function ScrapText()
        local names = {}
        for itemID in pairs(BW.db.scrap or {}) do
            local name = C_Item.GetItemNameByID(itemID) or ("item " .. itemID)
            -- A one-shot is a different promise from a standing rule, and the list is the one place
            -- you can see the whole thing at once - so it has to say which each one is. Sorting the
            -- finished strings keeps the suffix with its name.
            names[#names + 1] = BW.ScrapOnce(itemID) and (name .. " |cff808080(once)|r") or name
        end
        if #names == 0 then
            return "Nothing on the scrap list yet."
        end
        table.sort(names)
        return "|cffffd100Scrap:|r " .. table.concat(names, ", ")
    end

    local function Refresh()
        if not BW.db then return end
        -- The minimap button's state is the library's, not ours, so it is read rather than stored.
        if minimapRow then
            minimapRow.check:SetChecked(LIB.IsMinimapButtonShown("BagWarden") ~= false)
        end
        scrapList:SetText(ScrapText())
        clearScrap:SetShown(next(BW.db.scrap or {}) ~= nil)
        sell.check:SetChecked(BW.db.sellGreys)
        search.check:SetChecked(BW.db.smallSearch)
        barOn.check:SetChecked(BW.db.barEnabled)
        barCombat.check:SetChecked(BW.db.barHideInCombat)
        barLock.check:SetChecked(BW.db.barLocked)
        barPrice.check:SetChecked(BW.db.barShowPrice)
        -- Defaults to on, so read a missing value as on rather than as off.
        barFreeLine.check:SetChecked(BW.db.barShowFree ~= false)
        barCount.Sync()
        barSize.Sync()
        barFree.Sync()
        barDir.Sync()
        -- The row's own controls mean nothing while the row is off, and a page full of live-looking
        -- sliders that change nothing is worse than a page that says so.
        --
        -- Greying them out is a nicety; this function running is not. Refresh builds the page and
        -- runs again on every OnShow, so one missing method here takes the ENTIRE settings page
        -- down - every section, not just this one - and BagWarden then looks like it never loaded.
        -- SetEnabled is the modern spelling, and every other use of it in the family is on a Button;
        -- on a Slider it is unverified on this client. So ask for it, fall back to the older
        -- Enable/Disable pair, and let a widget that has neither simply stay lit.
        local rowOn = BW.db.barEnabled and true or false
        local function SetLit(control, on)
            if not control then return end
            if type(control.SetEnabled) == "function" then
                control:SetEnabled(on)
            elseif on and type(control.Enable) == "function" then
                control:Enable()
            elseif not on and type(control.Disable) == "function" then
                control:Disable()
            end
        end
        for _, row in ipairs({ barCount, barSize, barFree, barDir, barCombat, barLock,
                               barFreeLine, barPrice }) do
            SetLit(row.control, rowOn)
            row.label:SetFontObject(rowOn and "GameFontHighlight" or "GameFontDisable")
        end

        profession.check:SetChecked(BW.db.protectProfession)
        for index, choice in ipairs(reagentChoices) do
            reagentButtons[index]:SetChecked((BW.db.reagentKeep or "mine") == choice.value)
        end
        local canTell = BW.ProviderPresent and BW.ProviderPresent("SkillwrightReagents")
        reagentMineNote:SetText(canTell
            and "Skillwright is naming your professions' reagents."
            or "Without Skillwright, BagWarden cannot tell whose reagent is whose, so the first "
                .. "choice keeps them all.")
        for index, choice in ipairs(askChoices) do
            askButtons[index]:SetChecked((BW.db.askFrom or 2) == choice.value)
        end
        green.check:SetChecked(BW.db.allowGreen)
        protectedList:SetText(ProtectedText())

        -- The never-delete rows.
        local ids = {}
        for itemID in pairs(BW.db.ignore) do ids[#ids + 1] = itemID end
        table.sort(ids, function(a, b)
            return (C_Item.GetItemNameByID(a) or tostring(a)) < (C_Item.GetItemNameByID(b) or tostring(b))
        end)
        ignoreTitle:SetText(#ids > 0 and "Your never-delete list:" or
            "Your never-delete list is empty. Right-click the bag button to add what it was about to delete.")
        for _, row in ipairs(rows) do row:Hide() end
        for index, itemID in ipairs(ids) do
            local row = IgnoreRow(index)
            row.label:SetText(C_Item.GetItemNameByID(itemID) or ("item " .. itemID))
            row.remove:SetScript("OnClick", function()
                BW.SetIgnored(itemID, false)
                if panel.OnRefresh then panel.OnRefresh() end
            end)
            row:Show()
        end

        -- Everything below the rows moves with them.
        local listHeight = #ids * 22
        clear:ClearAllPoints()
        clear:SetPoint("TOPLEFT", rowPool, "TOPLEFT", INDENT, -listHeight - 6)
        clear:SetShown(#ids > 0)
        h4:ClearAllPoints()
        h4:SetPoint("TOPLEFT", rowPool, "TOPLEFT", 0, -listHeight - (#ids > 0 and 40 or 12))
        logNote:ClearAllPoints()
        logNote:SetPoint("TOPLEFT", h4, "BOTTOMLEFT", 0, -8)
        logList:ClearAllPoints()
        logList:SetPoint("TOPLEFT", logNote, "BOTTOMLEFT", 0, -8)
        logList:SetText(LogText())
        clearLog:ClearAllPoints()
        clearLog:SetPoint("TOPLEFT", logList, "BOTTOMLEFT", 0, -10)
        clearLog:SetShown(#(BW.db.log or {}) > 0)

        -- The help text goes below everything, and AddHelp wants a y in the page's own coordinates
        -- rather than an anchor - so it is placed from here, where the frames above have just been
        -- laid out and the never-delete list and the log have their real heights. Calling it again
        -- replaces the text rather than stacking a second copy, which is what makes that safe.
        if LIB.AddHelp then
            local top, bottom = f:GetTop(), clearLog:GetBottom()
            if top and bottom then
                LIB.AddHelp(f, HELP, -(top - bottom) - 28)
                -- The page is a scroll child, so its height is what decides whether the help can be
                -- scrolled to at all. Grow to fit it; never shrink below the height we registered.
                local reach = -(LIB.HelpBottom and LIB.HelpBottom(f) or 0) + 24
                if reach > f:GetHeight() then f:SetHeight(reach) end
            end
        end
    end
    panel.OnRefresh = Refresh
    f:HookScript("OnShow", Refresh)
    Refresh()

    if LIB.RegisterOptionsPage then
        -- Tall enough for the protected list and the log; the lib scrolls whatever doesn't fit.
        category = LIB.RegisterOptionsPage("BagWarden", panel, "BagWarden", 1220)
    else
        category = Settings.RegisterCanvasLayoutCategory(panel, "BagWarden")
        Settings.RegisterAddOnCategory(category)
    end
    BW.category = category

    -- AFTER registering, not before: declaring a height is what makes the page scroll, and a
    -- scrolling page is narrower than the frame by the width of the scrollbar. Ask any earlier and
    -- the library can only answer for a page it has not been told about yet.
    if LIB.OnOptionsResize then LIB.OnOptionsResize(panel, Relayout) end
end

--- Returns true when the settings opened; says why in chat when they can't.
--- Since LibForever 1.0.3 our pages live in the YippYapp window, not in Blizzard's Options, so the
--- lib opens them; Settings.OpenToCategory is only for a client running an older lib.
function BW.OpenOptions()
    if LIB.OpenAddonSettings then
        LIB.OpenAddonSettings("BagWarden")
        return true
    end
    if not category then BW.Print("the settings page isn't available.") return false end
    if InCombatLockdown() then BW.Print("settings can't open in combat.") return false end
    local id = category.GetID and category:GetID()
    if not id then BW.Print("the settings page isn't available.") return false end
    Settings.OpenToCategory(id)
    return true
end
