-- BagWarden - the settings page in Options -> AddOns -> YippYapp -> BagWarden.
local ADDON, BW = ...
local LIB = LibStub("LibForever-1.0")

local category, panel

local function Heading(parent, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetAtlas("Options_HorizontalDivider")
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    return fs
end

-- The page is hosted in the YippYapp window (LibForever 1.0.3), which decides how wide it is, so
-- every block of text is kept here and re-widthed whenever the page is resized.
-- Two x positions only: LEFT for headings and checkboxes, LEFT + INDENT for the text under a
-- checkbox. Nothing is ever anchored at a negative offset, or it hangs off the page and is clipped.
local FALLBACK_WIDTH = 540      -- only used until the window sizes us
local LEFT, INDENT = 8, 30
local notes = {}

local function Note(parent, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetWidth(FALLBACK_WIDTH - LEFT - INDENT)
    notes[#notes + 1] = fs
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(2)
    fs:SetText(text)
    return fs
end

function BW.RegisterOptions()
    if category or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    panel = CreateFrame("Frame")
    panel:SetWidth(FALLBACK_WIDTH)
    panel:SetScript("OnSizeChanged", function(self, width)
        width = width or self:GetWidth()
        if not width or width <= 0 then return end
        -- Room for the indent on the left and the same margin again on the right.
        local textWidth = math.max(120, width - LEFT - INDENT - LEFT)
        for _, fs in ipairs(notes) do fs:SetWidth(textWidth) end
    end)
    local f = panel

    local head = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", LEFT, -6)
    head:SetText("BagWarden")
    local version = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", head, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. BW.version)
    local sub = Note(f, "Free one bag slot per click. BagWarden picks the least valuable junk stack, tells you "
        .. "what it will do before you click, and never touches quest items or anything better than green.")
    sub:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)

    local function Check(anchor, x, y, text, onClick)
        local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        cb:SetSize(26, 26)
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y)
        local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        label:SetText(text)
        cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
        return cb
    end

    local h1 = Heading(f, "At a merchant")
    h1:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -20)
    local sell = Check(h1, 0, -6, "Sell all grey items automatically", function(on) BW.db.sellGreys = on end)
    local sellNote = Note(f, "When you open a vendor, BagWarden sells your grey items and says what they came to. "
        .. "Items on your never-delete list are never sold.")
    sellNote:SetPoint("TOPLEFT", sell, "BOTTOMLEFT", INDENT, -2)

    local h2 = Heading(f, "The bag button")
    h2:SetPoint("TOPLEFT", sellNote, "BOTTOMLEFT", -INDENT, -20)
    local search = Check(h2, 0, -6, "Make the bag search box smaller", function(on)
        BW.db.smallSearch = on
        BW.Refresh()
    end)
    local searchNote = Note(f, "In the combined bag window Blizzard's search box takes up most of the top "
        .. "row. Tick this to shrink it and move it to the right, next to the sort button, which leaves the "
        .. "title its space. The separate bags aren't crowded, so nothing changes there.")
    searchNote:SetPoint("TOPLEFT", search, "BOTTOMLEFT", INDENT, -2)

    -- How chatty the confirm popup is. Green and better can never be deleted, so the choice only
    -- covers grey and white.
    local hAsk = Heading(f, "Asking first")
    hAsk:SetPoint("TOPLEFT", searchNote, "BOTTOMLEFT", -INDENT, -20)
    local askNote = Note(f, "BagWarden always asks before deleting a crafting reagent, anything you use "
        .. "(food, drink, potions, bandages) and anything a quest has ever wanted. On top of that you can "
        .. "have it ask by quality.")
    askNote:SetPoint("TOPLEFT", hAsk, "BOTTOMLEFT", 0, -8)

    local askChoices, askButtons = {
        { value = 2, label = "Only reagents and things you use", note = "the least clicking" },
        { value = 1, label = "Also ask about white items" },
        { value = 0, label = "Ask about everything, grey items too" },
    }, {}
    local anchor = askNote
    for index, choice in ipairs(askChoices) do
        local cb = CreateFrame("CheckButton", nil, f, "UIRadioButtonTemplate")
        cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, index == 1 and -6 or -2)
        local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        label:SetText(choice.note and (choice.label .. " |cff808080(" .. choice.note .. ")|r") or choice.label)
        cb:SetScript("OnClick", function()
            BW.db.askFrom = choice.value
            BW.Refresh()
            if panel.OnRefresh then panel.OnRefresh() end
        end)
        askButtons[index] = cb
        anchor = cb
    end

    local green = Check(anchor, 0, -8, "Let it delete green items too", function(on)
        BW.db.allowGreen = on
        BW.Refresh()
        if panel.OnRefresh then panel.OnRefresh() end
    end)
    local greenNote = Note(f, "Off by default. Green items are normally kept whatever else you choose. "
        .. "Tick this and vendor greens can go as well - they always ask first, however you set the "
        .. "choices above. Blue and better are never deleted.")
    greenNote:SetPoint("TOPLEFT", green, "BOTTOMLEFT", INDENT, -2)
    anchor = greenNote

    -- Everything BagWarden is keeping right now, grouped by why. This is what used to crowd the
    -- button's tooltip.
    local h3 = Heading(f, "Protected items")
    h3:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -INDENT, -20)
    local protectedNote = Note(f, "What's in your bags right now that BagWarden will not delete. Quest items, "
        .. "items you can't sell and anything better than green are always kept, with no setting needed.")
    protectedNote:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -8)
    local profession = Check(protectedNote, 0, -8, "Keep profession gear", function(on)
        BW.db.protectProfession = on
        wipe(BW.professionCache)
        BW.Refresh()
        if panel.OnRefresh then panel.OnRefresh() end
    end)
    local professionNote = Note(f, "On by default. Keeps mining picks, skinning knives, fishing poles, "
        .. "enchanting rods and the like, anything that gives profession skill (+5 Mining gloves), anything "
        .. "that needs a profession, and every recipe, pattern and plan.")
    professionNote:SetPoint("TOPLEFT", profession, "BOTTOMLEFT", INDENT, -2)

    local reagentNote = Note(f, "Ore, stone, cloth, leather and herbs - anything the game marks "
        .. "\"Crafting Reagent\". Reagents that aren't kept still ask before they go, like anything else "
        .. "you might want.")
    reagentNote:SetPoint("TOPLEFT", professionNote, "BOTTOMLEFT", 0, -10)

    local reagentChoices, reagentButtons = {
        { value = "mine", label = "Keep reagents my professions use" },
        { value = "all", label = "Keep every crafting reagent" },
        { value = "none", label = "Keep none" },
    }, {}
    local reagentAnchor = reagentNote
    for index, choice in ipairs(reagentChoices) do
        local cb = CreateFrame("CheckButton", nil, f, "UIRadioButtonTemplate")
        cb:SetPoint("TOPLEFT", reagentAnchor, "BOTTOMLEFT", index == 1 and -INDENT or 0, index == 1 and -6 or -2)
        local label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        label:SetText(choice.label)
        cb:SetScript("OnClick", function()
            BW.db.reagentKeep = choice.value
            BW.Refresh()
            if panel.OnRefresh then panel.OnRefresh() end
        end)
        reagentButtons[index] = cb
        reagentAnchor = cb
    end

    -- Said plainly, because the honest answer depends on another addon being there.
    local reagentMineNote = Note(f, "")
    reagentMineNote:SetPoint("TOPLEFT", reagentAnchor, "BOTTOMLEFT", INDENT, -4)

    local protectedList = Note(f, "")
    protectedList:SetPoint("TOPLEFT", reagentMineNote, "BOTTOMLEFT", -INDENT, -12)

    -- Your own never-delete list: one row per item, each removable.
    local ignoreTitle = Note(f, "")
    ignoreTitle:SetPoint("TOPLEFT", protectedList, "BOTTOMLEFT", 0, -12)
    local rows, rowPool = {}, CreateFrame("Frame", nil, f)
    rowPool:SetSize(1, 1)
    rowPool:SetPoint("TOPLEFT", ignoreTitle, "BOTTOMLEFT", 0, -4)

    local function Row(index)
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
    local h4 = Heading(f, "Deleted items")
    local logNote = Note(f, "Everything BagWarden has deleted on this account, newest first. The last "
        .. BW.LOG_MAX .. " are kept.")
    local logList = Note(f, "")
    local clearLog = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearLog:SetSize(160, 22)
    clearLog:SetText("Clear log")
    clearLog:SetScript("OnClick", function()
        wipe(BW.db.log)
        if panel.OnRefresh then panel.OnRefresh() end
    end)

    local launcher = LIB.LauncherOptions and LIB.LauncherOptions(f, "BagWarden")

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
                entry.ctrl and " - Ctrl-click" or "")
        end
        if #log > 20 then lines[#lines + 1] = string.format("|cff808080...and %d more|r", #log - 20) end
        return table.concat(lines, "\n")
    end

    local function Refresh()
        if not BW.db then return end
        sell:SetChecked(BW.db.sellGreys)
        search:SetChecked(BW.db.smallSearch)
        profession:SetChecked(BW.db.protectProfession)
        for index, choice in ipairs(reagentChoices) do
            reagentButtons[index]:SetChecked((BW.db.reagentKeep or "mine") == choice.value)
        end
        local canTell = BW.ProviderPresent and BW.ProviderPresent("SkillwrightReagents")
        reagentMineNote:SetText(canTell
            and "Skillwright is telling BagWarden which reagents your professions use."
            or "Telling your professions' reagents apart needs Skillwright. Without it, the first choice "
                .. "keeps every reagent rather than guessing that one is someone else's.")
        for index, choice in ipairs(askChoices) do
            askButtons[index]:SetChecked((BW.db.askFrom or 2) == choice.value)
        end
        green:SetChecked(BW.db.allowGreen)
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
            local row = Row(index)
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
        if launcher then
            launcher:ClearAllPoints()
            launcher:SetPoint("TOPLEFT", clearLog, "BOTTOMLEFT", 0, -24)
        end
    end
    panel.OnRefresh = Refresh
    f:HookScript("OnShow", Refresh)
    Refresh()

    if LIB.RegisterOptionsPage then
        -- Tall enough for the protected list and the log; the lib scrolls whatever doesn't fit.
        category = LIB.RegisterOptionsPage("BagWarden", panel, "BagWarden", 900)
    else
        category = Settings.RegisterCanvasLayoutCategory(panel, "BagWarden")
        Settings.RegisterAddOnCategory(category)
    end
    BW.category = category
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
