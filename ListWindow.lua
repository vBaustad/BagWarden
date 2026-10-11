-- BagWarden - one window for the four lists.
--
-- The settings page used to draw all four inline: the scrap list, what is protected in your bags
-- right now, your never-delete list (a frame per item) and the deletion log. Each grows with play,
-- so the page got longer the more you used the addon and the settings ended up in the middle of it.
-- Four buttons with a count on them say the same thing in four rows.
--
-- Nothing here is invented. Three things went wrong in the first version and all three were already
-- solved in the family:
--
--   * the window had a hand-rolled SetBackdrop and came out INVISIBLE - the settings page read
--     straight through it. Windows here wear "SettingsFrameTemplate" with the
--     "heavybronze-frame-background" atlas behind it, which is what Guildhall's U.Window and
--     Skillwright's window do, and the reason they come out in Forever's bronze: Forever swaps the
--     art behind Blizzard's atlas names.
--   * strata, dragging, the saved position and Escape are LIB.RegisterWindow's, not ours.
--   * most rows said "item 2067". C_Item.GetItemNameByID answers only for an item the client has
--     cached, and these lists are account-wide - half of them were put there by another character
--     in another session. C_Item.RequestLoadItemDataByID plus GET_ITEM_INFO_RECEIVED is how
--     Guildhall, Skillwright and AutoFeed all handle exactly this.
--
-- The scrolling list is Guildhall's U.ScrollList, down to the FauxScrollFrame and the fixed row
-- pool. The two newer scroll APIs are ones nothing in the family has tried.
local ADDON, BW = ...
local LIB = LibStub("LibForever-1.0", true)

-- The rows are the source of truth and the window is sized from them, rather than both being
-- typed and left to disagree. They did disagree: 16 rows of 22 need 352 pixels and the gap between
-- these two insets was 322, so the last two rows drew straight over the button at the foot. A frame
-- does not clip its children, so nothing complains - it just looks broken.
local ROW_H, NUM_ROWS = 22, 16
-- Just the title and the gap under it. There was a caption here too, and every list had one -
-- which meant every window opened by repeating its own title back at you. A list of items does
-- not need describing; it needs showing.
local HEADER_H = 64
local FOOTER_H = 50    -- the button at the foot, and the gap below the last row
local WIDTH = 500
local HEIGHT = HEADER_H + NUM_ROWS * ROW_H + FOOTER_H

local window

-- Item ids we have asked the server about and not heard back on. Kept so GET_ITEM_INFO_RECEIVED
-- only redraws when something we are actually waiting for arrives.
local pending = {}

--- An item's icon and its name in its quality colour, or nil while the client fetches it.
--- The link rather than the plain name, because a link carries the colour and the client builds it
--- for free - and a grey name beside a white one is most of what makes a list readable.
local function ItemFace(itemID)
    local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    local link = select(2, C_Item.GetItemInfo(itemID))
    if link and icon then
        pending[itemID] = nil
        return icon, link
    end
    -- Ask once and draw something honest in the meantime. The id is still shown, because an item
    -- you cannot name is one you may still want to take off the list.
    if not pending[itemID] then
        pending[itemID] = true
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    end
    return icon, "|cff808080item " .. itemID .. "|r"
end

local function Build()
    if window then return window end

    -- Blizzard's own panel frame, as every other YippYapp window uses. Forever swaps the art behind
    -- these atlas names, so this comes out bronze without us naming a colour.
    local f = CreateFrame("Frame", "BagWardenListWindow", UIParent, "SettingsFrameTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    if f.NineSlice and f.NineSlice.Text then f.NineSlice.Text:SetText("BagWarden") end

    -- The template's own background is a flat translucent grey - which is what made the first
    -- version look like it had none at all once it sat over a busy page.
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 7, -18)
    bg:SetPoint("BOTTOMRIGHT", -3, 3)
    bg:SetAtlas("heavybronze-frame-background")
    if f.Bg then f.Bg:Hide() end

    -- The template's X calls HideUIPanel, which does nothing from addon code in combat.
    local close = f.ClosePanelButton or f.CloseButton
    if close then close:SetScript("OnClick", function() f:Hide() end) end

    -- Strata, front-to-back order against our other windows, dragging, the saved position and
    -- Escape - all the library's. Doing any of it by hand is how a window ends up under the page
    -- it was opened from.
    if LIB and LIB.RegisterWindow then
        LIB.RegisterWindow(f, BW.db or {}, "listPos")
    else
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        table.insert(UISpecialFrames, "BagWardenListWindow")
    end

    f.heading = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.heading:SetPoint("TOPLEFT", 20, -34)

    f.empty = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.empty:SetPoint("TOPLEFT", 24, -(HEADER_H + 4))
    f.empty:SetPoint("RIGHT", f, "RIGHT", -24, 0)
    f.empty:SetJustifyH("LEFT")

    f.action = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.action:SetSize(170, 22)
    f.action:SetPoint("BOTTOMLEFT", 20, 18)

    -- ----------------------------------------------------------------- rows
    local list = CreateFrame("Frame", nil, f)
    list:SetPoint("TOPLEFT", 20, -HEADER_H)
    list:SetPoint("BOTTOMRIGHT", -20, FOOTER_H)

    local scroll = CreateFrame("ScrollFrame", nil, list, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -26, 0)

    list.rows = {}
    for i = 1, NUM_ROWS do
        local row = CreateFrame("Frame", nil, list)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)

        -- Every other row faintly shaded, so the eye can follow one across to its button. This is
        -- the whole difference between a list and a column of text with buttons beside it.
        if i % 2 == 0 then
            row.stripe = row:CreateTexture(nil, "BACKGROUND")
            row.stripe:SetAllPoints()
            row.stripe:SetColorTexture(1, 1, 1, 0.03)
        end

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 2, 0)

        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWordWrap(false)

        row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.button:SetSize(64, 18)
        row.button:SetPoint("RIGHT", -2, 0)
        -- The label stops where the button starts, so a long name is cut rather than drawn under it.
        row.label:SetPoint("RIGHT", row.button, "LEFT", -8, 0)

        list.rows[i] = row
    end
    list.data = {}

    function list:Refresh()
        local offset = FauxScrollFrame_GetOffset(scroll)
        FauxScrollFrame_Update(scroll, #self.data, NUM_ROWS, ROW_H)
        for i, row in ipairs(self.rows) do
            local entry = self.data[i + offset]
            if entry then
                -- An entry naming an item id gets its icon and its colour from the client; one
                -- carrying its own text (the log) is drawn as given.
                if entry.itemID then
                    local icon, face = ItemFace(entry.itemID)
                    row.icon:SetTexture(icon)
                    row.icon:SetShown(icon and true or false)
                    row.label:SetText(face .. (entry.suffix or ""))
                else
                    row.icon:SetShown(false)
                    row.label:SetText(entry.text or "?")
                end

                if entry.action then
                    row.button:SetText(entry.actionLabel or "Remove")
                    row.button:SetScript("OnClick", function()
                        entry.action()
                        -- Re-ask the caller for its rows: removing one changes the list, and
                        -- redrawing the old array would show the item still sitting there.
                        if window.spec then BW.OpenList(window.spec) end
                    end)
                    row.button:Show()
                else
                    row.button:Hide()
                end
                row:Show()
            else
                row:Hide()
            end
        end
    end

    scroll:SetScript("OnVerticalScroll", function(self, value)
        FauxScrollFrame_OnVerticalScroll(self, value, ROW_H, function() list:Refresh() end)
    end)

    f.list = list
    window = f
    return f
end

--- Show one list. `spec` is kept, so a row's own button can ask for the list again after changing
--- something - which is why the rows are a function rather than an array.
---   title       heading
---   rows()      -> { { itemID = , suffix = , action = , actionLabel = } | { text = }, ... }
---   actionText  label for the button at the foot, or nil for none
---   action()    what that button does
function BW.OpenList(spec)
    if not spec then return end
    local f = Build()
    f.spec = spec

    f.heading:SetText(spec.title or "")

    local rows = (spec.rows and spec.rows()) or {}
    f.list.data = rows
    f.list:Refresh()

    -- Empty is the one state worth saying out loud: an empty window and a broken one look the same
    -- otherwise.
    f.empty:SetText(#rows == 0 and (spec.empty or "Nothing here yet.") or "")
    f.list:SetShown(#rows > 0)

    if spec.actionText and spec.action then
        f.action:SetText(spec.actionText)
        f.action:SetScript("OnClick", function()
            spec.action()
            BW.OpenList(spec)
        end)
        f.action:SetEnabled(#rows > 0)
        f.action:Show()
    else
        f.action:Hide()
    end

    f:Show()
    if LIB and LIB.RaiseWindow then LIB.RaiseWindow(f) else f:Raise() end
end

--- Redraw if the window is open and showing something we were waiting on a name for.
--- Called from Core.lua's GET_ITEM_INFO_RECEIVED, which BagWarden already listens to.
function BW.RefreshListWindow()
    if window and window:IsShown() and window.spec and next(pending) then
        BW.OpenList(window.spec)
    end
end

function BW.CloseList()
    if window then window:Hide() end
end
