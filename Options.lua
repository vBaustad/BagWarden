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

local function Note(parent, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetWidth(560)
    fs:SetJustifyH("LEFT")
    fs:SetSpacing(2)
    fs:SetText(text)
    return fs
end

function BW.RegisterOptions()
    if category or not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    panel = CreateFrame("Frame")
    local f = panel

    local head = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", 8, -6)
    head:SetText("BagWarden")
    local version = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", head, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. BW.version)
    local sub = Note(f, "Free one bag slot per click. BagWarden picks the least valuable junk stack, tells you "
        .. "what it will do before you click, and never touches quest items or anything green and above.")
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
    local sell = Check(h1, -4, -6, "Sell all grey items automatically", function(on) BW.db.sellGreys = on end)
    local sellNote = Note(f, "When you open a vendor, BagWarden sells your grey items and says what they came to. "
        .. "Items on your never-delete list are never sold.")
    sellNote:SetPoint("TOPLEFT", sell, "BOTTOMLEFT", 30, -2)

    local h2 = Heading(f, "The bag button")
    h2:SetPoint("TOPLEFT", sellNote, "BOTTOMLEFT", -30, -20)
    local search = Check(h2, -4, -6, "Make the bag search box smaller", function(on)
        BW.db.smallSearch = on
        BW.Refresh()
    end)
    local searchNote = Note(f, "Blizzard's search box takes up most of the bag window's top row. Tick this to "
        .. "shrink it, which leaves room for BagWarden's button next to the sort button.")
    searchNote:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 30, -2)

    -- Everything BagWarden is keeping right now, grouped by why. This is what used to crowd the
    -- button's tooltip.
    local h3 = Heading(f, "Protected items")
    h3:SetPoint("TOPLEFT", searchNote, "BOTTOMLEFT", -30, -20)
    local protectedNote = Note(f, "What's in your bags right now that BagWarden will not delete. Quest items, "
        .. "items you can't sell and anything green or better are always kept, with no setting needed.")
    protectedNote:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -8)
    local profession = Check(protectedNote, -4, -8, "Keep profession gear", function(on)
        BW.db.protectProfession = on
        wipe(BW.professionCache)
        BW.Refresh()
        if panel.OnRefresh then panel.OnRefresh() end
    end)
    local professionNote = Note(f, "On by default. Keeps mining picks, skinning knives, fishing poles, "
        .. "enchanting rods and the like, anything that gives profession skill (+5 Mining gloves), anything "
        .. "that needs a profession, and every recipe, pattern and plan.")
    professionNote:SetPoint("TOPLEFT", profession, "BOTTOMLEFT", 30, -2)

    local protectedList = Note(f, "")
    protectedList:SetPoint("TOPLEFT", professionNote, "BOTTOMLEFT", -30, -12)

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
        row:SetPoint("TOPLEFT", rowPool, "TOPLEFT", 8, -(index - 1) * 22)
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
        for _, item in ipairs(items) do
            local strength, reason = BW.KeepReason(item)
            if strength then
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
            lines[#lines + 1] = string.format("%s x%d - %s  |cff808080%s|r",
                entry.link or entry.name or "?", entry.count or 1,
                BW.Coin(entry.value or 0), date("%d.%m %H:%M", entry.when or 0))
        end
        if #log > 20 then lines[#lines + 1] = string.format("|cff808080...and %d more|r", #log - 20) end
        return table.concat(lines, "\n")
    end

    local function Refresh()
        if not BW.db then return end
        sell:SetChecked(BW.db.sellGreys)
        search:SetChecked(BW.db.smallSearch)
        profession:SetChecked(BW.db.protectProfession)
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
        clear:SetPoint("TOPLEFT", rowPool, "TOPLEFT", 8, -listHeight - 6)
        clear:SetShown(#ids > 0)
        h4:ClearAllPoints()
        h4:SetPoint("TOPLEFT", rowPool, "TOPLEFT", -8, -listHeight - (#ids > 0 and 40 or 12))
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
function BW.OpenOptions()
    if not category then BW.Print("the settings page isn't available.") return false end
    if InCombatLockdown() then BW.Print("settings can't open in combat.") return false end
    Settings.OpenToCategory(category:GetID())
    return true
end
