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

    -- %s is the scrap modifier, which is a setting - see HelpNow below. A help block that names a
    -- key the settings above it can change is the one piece of prose guaranteed to go wrong.
    { "Using it",
        "Open your bags: the button sits next to Blizzard's sort button. Hold Ctrl to skip the "
        .. "question on things that would ask. Right-click it to protect what it was about to "
        .. "delete.\n\n"
        .. "%s-click any stack up to green and the next merchant buys that one. %s-click again "
        .. "to sell it every time." },

    { "Good to know",
        "The game only lets an addon delete inside a real click or keypress, so there is no \"clean "
        .. "my bags\" button and never will be. Selling is different: it can be undone from the "
        .. "merchant's buyback list until you walk away." },
}

--- HELP with the configurable key filled in, rebuilt on each Refresh rather than at load.
--- A copy, so the template keeps its %s and a second call does not format an already-formatted
--- string - which would silently drop the key and leave the sentence a word short.
local function HelpNow()
    local key = BW.ModifierLabel("scrap")
    local out = {}
    for i, section in ipairs(HELP) do
        out[i] = { section[1], section[2]:find("%%s") and section[2]:format(key, key) or section[2] }
    end
    return out
end

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
        -- `tip` may be a function, for a tooltip whose words depend on a setting. Built once and
        -- read at hover, a tooltip that names a configurable key is stale from the moment the key
        -- changes - and this page can change one of those keys itself, two rows further down.
        if tip then
            r:EnableMouse(true)
            r:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(text, 1, 1, 1)
                GameTooltip:AddLine(type(tip) == "function" and tip() or tip, 0.8, 0.8, 0.8, true)
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

    --- One checkbox with its label to the RIGHT of it, placed at an x inside a row.
    ---
    --- Not at CONTROL_X like a slider or a picker. A checkbox is 24 pixels wide, so a label on the
    --- left and the box out at 240 leaves a gap the size of the label and then the whole right half
    --- of the page empty - a full-width row spent on one tick. Beside its label it takes about half
    --- a row, which is what lets Checks below put two of them in one.
    local function InlineCheck(row, x, text, tip, onClick)
        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("LEFT", row, "LEFT", x - 4, 0)
        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetText(text)
        cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
        -- The tooltip hangs off the CHECKBOX, not the row: with two per row, a row-wide tooltip
        -- could only ever describe one of them.
        if tip then
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(text, 1, 1, 1)
                GameTooltip:AddLine(type(tip) == "function" and tip() or tip, 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        return { check = cb, label = label, control = cb }
    end

    --- One row, one or two checkboxes. Each spec is { text, tip, onClick }.
    --- Returns the handles in the order given, so Refresh reads them the same either way.
    local function Checks(a, b)
        local row = Row("", nil)
        -- Row() builds its own label for the single-control layout; with the checks carrying their
        -- own, that one is empty and must not take the mouse off them.
        row:EnableMouse(false)
        local left = InlineCheck(row, LEFT + 4, a[1], a[2], a[3])
        local right = b and InlineCheck(row, CONTROL_X + 4, b[1], b[2], b[3])
        return left, right
    end

    --- A checkbox on its own row, for the few whose label will not fit beside a neighbour.
    local function Toggle(text, tip, onClick)
        local left = Checks({ text, tip, onClick })
        return left
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

    --- A modifier picker: click it, then click again holding the keys you want.
    ---
    --- Not a list of choices, because there is no list - any combination of Ctrl, Shift and Alt is
    --- a valid gesture, and a button that steps through six of them makes the seventh impossible
    --- while taking up to six clicks to reach the one you wanted. Reading what is held means every
    --- combination is available by doing the thing you are about to do anyway, and "custom" stops
    --- being a feature.
    ---
    --- Two clicks rather than a keyboard capture: a modifier is held, not pressed, so there is no
    --- keypress to catch. OnKeyDown would also need the frame to take keyboard focus, which on a
    --- page inside somebody else's window is a good way to eat their Escape.
    local function KeyPick(text, tip, get, set)
        local row = Row(text, tip)
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(160, 22)
        Place(b, row)
        local listening = false

        row.Sync = function()
            if listening then
                b:SetText("hold keys, click")
            else
                local label = get()
                b:SetText((label ~= "" and label) or "none")
            end
        end

        b:SetScript("OnClick", function()
            if not listening then
                listening = true
                row.Sync()
                return
            end
            listening = false
            local value = BW.ModifierFrom(IsControlKeyDown(), IsShiftKeyDown(), IsAltKeyDown())
            -- No keys held is a cancel, not a setting: a gesture with no modifier would fire on
            -- every ordinary click in your bags, which is the one outcome nobody is asking for.
            if value then set(value) end
            row.Sync()
        end)
        -- Clicking elsewhere on the page should not leave the button waiting for ever.
        b:SetScript("OnHide", function() listening = false end)
        row.button = b
        return row
    end

    --- A button that opens one of the four lists, with its count on the face of it.
    --- The count is the part that matters: it answers "is there anything in there" without opening
    --- anything, which is what the inline lists were really being asked for. `spec()` is called at
    --- click time so the rows are built from the bags as they are then, not as they were when the
    --- page was drawn.
    local listButtons = {}
    local function ListButton(text, count, spec)
        local row = Row("", nil)
        row:EnableMouse(false)
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(260, 22)
        b:SetPoint("LEFT", row, "LEFT", LEFT + 4, 0)
        b:SetScript("OnClick", function() BW.OpenList(spec()) end)
        row.Sync = function()
            local n = count()
            b:SetText(n > 0 and ("%s  (%d)"):format(text, n) or text)
            -- Dim rather than hidden when empty: a button that comes and goes is harder to find
            -- than one that is simply unlit, and "nothing here" is still an answer worth opening.
            b:SetEnabled(true)
        end
        row.button = b
        listButtons[#listButtons + 1] = row
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

    -- Two settings that had a heading and a full-width row each, for one checkbox each: where
    -- BagWarden puts itself. They are the same question asked about two places, so they share a
    -- heading and a row. The minimap one is the library's rather than ours, which is why it is
    -- conditional - and why it has to look exactly like one of ours.
    Section("Where it shows up")
    local minimapRow, search
    local MINIMAP = { "Minimap row",
        "The YippYapp addons share one minimap button that opens a small row of icons. This is "
        .. "whether BagWarden is one of them. The addon works exactly the same either way - its "
        .. "icon only opens these settings - and you can always get here with /bagw.",
        function(on) LIB.SetMinimapButtonShown("BagWarden", on) end }
    local SEARCH = { "Shrink the bag search box",
        "In the combined bag window Blizzard's search box takes up most of the top row. This "
        .. "shrinks it and moves it to the right, next to the sort button, which leaves the title "
        .. "its space. The separate bags aren't crowded, so nothing changes there.",
        function(on) BW.db.smallSearch = on BW.Refresh() end }
    if LIB.SetMinimapButtonShown and LIB.IsMinimapButtonShown then
        minimapRow, search = Checks(MINIMAP, SEARCH)
    else
        -- No minimap support in this library: the search box moves over to the left on its own,
        -- rather than leaving a hole where the other checkbox was.
        search = Checks(SEARCH)
    end
    -- In this section because it is about what shows up, and this one is about what shows up on
    -- this page. Off by default: it is the longest thing here and the page is long enough.
    local helpOn = Checks({ "Explain how it works, at the foot of this page",
        "Three short sections at the bottom: what BagWarden does, how to use it, and what the game "
        .. "will not let it do. Off by default, because the page is long enough without them.",
        function(on)
            BW.db.showHelp = on
            if panel.OnRefresh then panel.OnRefresh() end
        end })

    Section("At a merchant")
    local sell = Toggle("Sell all grey items automatically",
        "When you open a vendor, BagWarden sells your grey items and says what they came to. Up to "
        .. "twelve stacks go per visit, greys and scrap together, so everything stays in the "
        .. "merchant's buyback list until you walk away. A grey on your never-delete list is left "
        .. "alone; one you put on the scrap list by hand is sold, because that list is about what "
        .. "gets destroyed, not what gets sold.",
        function(on) BW.db.sellGreys = on end)
    -- Named from the setting below, and re-set in Refresh, which runs on every OnShow and after
    -- the setting changes. A paragraph that says "Alt" to somebody who has chosen Ctrl-Alt is the
    -- page contradicting itself about its own setting two rows down.
    local scrapHow = Para("", -12)
    local function ScrapHowText()
        local key = BW.ModifierLabel("scrap")
        return ("%s-click any stack up to green in your bags: the next merchant buys that one, "
            .. "then forgets it. %s-click again to sell it every time, and once more to take it "
            .. "off."):format(key, key)
    end

    local scrapButton = ListButton("Scrap list", function()
        local n = 0
        for _ in pairs(BW.ScrapStore() or {}) do n = n + 1 end
        return n
    end, function()
        return {
            title = "Scrap list",
            empty = "Nothing on the scrap list yet. Alt-click a stack in your bags to add one.",
            rows = function()
                local out = {}
                for itemID, how in pairs(BW.ScrapStore() or {}) do
                    out[#out + 1] = {
                        itemID = itemID,
                        suffix = (how == "once") and "  |cff808080(once)|r" or "",
                        sort = (C_Item.GetItemNameByID(itemID) or ("item " .. itemID)),
                        action = function()
                            BW.SetScrap(itemID, false)
                            BW.Refresh()
                            if panel.OnRefresh then panel.OnRefresh() end
                        end,
                    }
                end
                table.sort(out, function(a, b) return a.sort < b.sort end)
                return out
            end,
            actionText = "Empty the list",
            action = function()
                wipe(BW.ScrapStore() or {})
                BW.Refresh()
                if panel.OnRefresh then panel.OnRefresh() end
            end,
        }
    end)

    -- "The bag button" was a heading over one checkbox about the search box, which is not the bag
    -- button at all. It is up under "Where it shows up" now, beside the minimap one.

    -- The on-screen row. Everything here is layout except the first toggle, which is also the only
    -- setting on this page that costs anything: with the row on, the bags are rescanned on every bag
    -- update instead of only while a bag window is open (see BW.Refresh).
    Section("The on-screen row")
    local barOn = Toggle("Show a row of icons on screen",
        -- The row's gesture is described HERE and nowhere else on the page: the paragraph that
        -- used to say it was dropped when the page was cut. A function, not a string, so it is
        -- built at hover and names whatever the key is by then.
        function()
            return ("The next few stacks BagWarden would delete, cheapest first, without opening "
                .. "your bags. %s-click an icon to act on it, right-click one to protect it, and "
                .. "drag the row to move it. An amber edge means it will ask before it goes, "
                .. "however you click it.\n\n"
                .. "This is the only setting here that costs anything: BagWarden then rescans your "
                .. "bags as they change even while they are shut, because something on screen "
                .. "depends on it."):format(BW.ModifierLabel("row"))
        end,
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
    -- Four toggles, two rows. Each pair is two settings about the same thing, so reading across is
    -- as natural as reading down.
    local barCombat, barLock = Checks(
        { "Hide it in combat",
          "Deleting is refused in combat anyway, so the icons can only be clutter over your "
          .. "action bars.",
          function(on) BW.db.barHideInCombat = on BW.ApplyBarSettings() end },
        { "Lock it in place",
          "Stops the row being dragged once it is where you want it.",
          function(on) BW.db.barLocked = on end })
    local barFreeLine, barPrice = Checks(
        { "Show free slots",
          "A line above the row: grey normally, amber when you are running low, red when the bags "
          .. "are full. \"Running low\" means the threshold above, or five slots when that is set "
          .. "to always show. It also keeps the row on screen when your bags are full and there is "
          .. "nothing BagWarden can free - which is exactly when you want telling.",
          function(on) BW.db.barShowFree = on BW.ApplyBarSettings() end },
        { "Show each price",
          "What that stack fetches at a vendor, under the icon as well as in its tooltip.",
          function(on) BW.db.barShowPrice = on BW.ApplyBarSettings() end })

    -- Both click gestures in one place, which is where somebody looking for them will look. They
    -- used to sit in the two sections they each belong to, which is defensible and useless: you do
    -- not go hunting for "the thing I click in my bags" under "At a merchant".
    Section("Clicks and keys")
    local scrapMod = KeyPick("Mark scrap in your bags", function()
            return "Hold these and click a stack in your bags to mark it as scrap. Alt by "
                .. "default.\n\nClick the button, then hold the keys you want and click it again.\n\n"
                .. "Ctrl and Shift on their own already do something to an item in a bag - try it "
                .. "on, split the stack - and BagWarden cannot suppress the client's own click, so "
                .. "both would happen. A combination collides with nothing."
        end,
        function() return BW.ModifierLabel("scrap") end,
        function(v)
            BW.db.scrapModifier = v
            if panel.OnRefresh then panel.OnRefresh() end
        end)
    local rowMod = KeyPick("Act on a row icon", function()
            return "Hold these and click one of the on-screen row's icons to act on it. Ctrl by "
                .. "default.\n\nA plain click never acts, whichever you pick: the row sits on the "
                .. "world, where a misclick costs an item."
        end,
        function() return BW.ModifierLabel("row") end,
        function(v)
            BW.db.rowModifier = v
            if panel.OnRefresh then panel.OnRefresh() end
        end)
    local skipMod = KeyPick("Delete without being asked", function()
            return "Hold these as you click the bag button to skip the confirm popup on anything "
                .. "that would ask. Ctrl by default.\n\n"
                .. "Its own setting rather than one of the two above, because it does a different "
                .. "job: these keys mean \"don't ask me\", not \"act\". It never skips a "
                .. "protection, only the question - and the two things that always ask whatever "
                .. "you hold still always ask."
        end,
        function() return BW.ModifierLabel("skip") end,
        function(v)
            BW.db.skipModifier = v
            if panel.OnRefresh then panel.OnRefresh() end
        end)


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

    -- The other three lists, as buttons. The never-delete one used to be a frame per item built
    -- into the page, and the log up to twenty lines of text, and Refresh had to re-anchor the
    -- heading below however many rows there happened to be. All of that is the window's job now.
    local protectedButton = ListButton("Protected in your bags right now",
        function() return #BW.Protected() end,
        function()
            return {
                title = "Protected right now",
                empty = "Nothing in your bags needs protecting right now.",
                rows = function() return BW.Protected() end,
            }
        end)

    local ignoreButton = ListButton("Never delete", function()
        local n = 0
        for _ in pairs(BW.db.ignore or {}) do n = n + 1 end
        return n
    end, function()
        return {
            title = "Never delete",
            empty = "Nothing on the list. Right-click BagWarden's bag button to add what it was "
                .. "about to delete.",
            rows = function()
                local out = {}
                -- The value is always `true` (see BW.SetIgnored), so the name comes from the
                -- item id. An item the client has not cached yet reads as "item 2589", which is
                -- honest and still removable.
                for itemID in pairs(BW.db.ignore or {}) do
                    out[#out + 1] = {
                        itemID = itemID,
                        sort = C_Item.GetItemNameByID(itemID) or ("item " .. itemID),
                        action = function()
                            BW.SetIgnored(itemID, false)
                            BW.Refresh()
                            if panel.OnRefresh then panel.OnRefresh() end
                        end,
                    }
                end
                table.sort(out, function(a, b) return a.sort < b.sort end)
                return out
            end,
            actionText = "Empty the list",
            action = function()
                wipe(BW.db.ignore)
                BW.Refresh()
                if panel.OnRefresh then panel.OnRefresh() end
            end,
        }
    end)

    local logButton = ListButton("Deleted items", function() return #(BW.db.log or {}) end,
        function()
            return {
                title = "Deleted items",
                empty = "Nothing deleted yet.",
                rows = function()
                    local out = {}
                    for _, entry in ipairs(BW.db.log or {}) do
                        out[#out + 1] = { text = ("%s x%d - %s  |cff808080%s%s|r"):format(
                            entry.link or entry.name or "?", entry.count or 1,
                            BW.Coin(entry.value or 0), date("%d.%m %H:%M", entry.when or 0),
                            (entry.ctrl and (" - " .. BW.ModifierLabel("skip") .. "-click") or "")
                            .. (entry.unlocked and (" - " .. entry.unlocked) or "")) }
                    end
                    return out
                end,
                actionText = "Clear the log",
                action = function()
                    wipe(BW.db.log)
                    if panel.OnRefresh then panel.OnRefresh() end
                end,
            }
        end)

    -- The launcher bar is gone, and LIB.LauncherOptions with it. What it used to offer that still
    -- means something is "should this addon have an icon at all", which is now the minimap toggle
    -- near the top of this page.

    local function Refresh()
        if not BW.db then return end
        -- The minimap button's state is the library's, not ours, so it is read rather than stored.
        if minimapRow then
            minimapRow.check:SetChecked(LIB.IsMinimapButtonShown("BagWarden") ~= false)
        end
        -- Every list button, in one loop. Four lists that each refreshed themselves in their
        -- own two lines here is how the old inline versions drifted apart.
        for _, row in ipairs(listButtons) do row.Sync() end
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
        rowMod.Sync()
        scrapMod.Sync()
        skipMod.Sync()
        helpOn.check:SetChecked(BW.db.showHelp)
        -- The one piece of prose on this page that names a key the page itself can change.
        scrapHow:SetText(ScrapHowText())
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
        -- rowMod is NOT here any more: it has moved to "Clicks and keys", and greying out a
        -- control in one section because of a toggle in another is a puzzle, not a hint.
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

        -- Nothing here re-anchors anything any more. Everything on this page is now a fixed number
        -- of rows: the four lists that used to grow downwards and push the log, the Clear buttons
        -- and the help text about with them are four buttons with a count on them.

        -- The help text goes below everything, and AddHelp wants a y in the page's own coordinates
        -- rather than an anchor, so it is placed from here - below the last row, which is now
        -- always the same row. Calling it again replaces the text rather than stacking a second
        -- copy, which is what makes that safe.
        if LIB.AddHelp then
            local top, bottom = f:GetTop(), logButton:GetBottom()
            if top and bottom then
                LIB.AddHelp(f, BW.db.showHelp and HelpNow() or {}, -(top - bottom) - 28)
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
