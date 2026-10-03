-- BagWarden - the on-screen row.
-- The same plan the bag button uses, drawn where you can see it without opening your bags: the next
-- few stacks BagWarden would delete, cheapest first, one icon each.
--
-- Nothing here is a new way to delete. An icon is a plain Button, and a Ctrl-click on one is the
-- player's own click - which is all DeleteCursorItem needs, and the reason these icons need none of
-- the secure-button machinery BuffWarden's spell buttons do. Every click ends in BW.DeleteStack, so
-- the whole keep chain, the re-read of the slot and the confirm popup all still apply. If you ever
-- find yourself writing a shortcut past DeleteStack here, that is the bug.
local ADDON, BW = ...
local LIB = LibStub("LibForever-1.0")

local GAP = 4
local bar, icons = nil, {}

local function DB() return BW.db or {} end
local function Size() return math.max(16, math.min(64, DB().barSize or 36)) end
local function Count() return math.max(1, math.min(10, DB().barCount or 4)) end

-- ---------------------------------------------------------------------------
-- Where it sits
-- ---------------------------------------------------------------------------
-- The bar frame is exactly one icon big and is always pinned by its top-left corner, whatever the
-- row is doing. The icons hang off it at offsets that may be negative, so the FIRST icon is at the
-- saved point in all four directions and never moves - not when the count setting changes, not when
-- the row runs short of junk, not when the direction changes. BuffWarden had to learn this the hard
-- way: StopMovingOrSizing re-anchors to whatever corner is nearest, and a frame anchored by its
-- centre or right edge walks across the screen every time its contents change size.
local function SavePosition(byUser)
    if not bar then return end
    local l, t = bar:GetLeft(), bar:GetTop()
    if not (l and t) then return end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    if byUser then DB().barPoint = { l, t } end
end

--- Offset of icon `index` from the bar's top-left, in the player's chosen direction.
local function IconOffset(index)
    local step = Size() + GAP
    local n = index - 1
    local dir = DB().barDirection or "RIGHT"
    if dir == "LEFT" then return -n * step, 0 end
    if dir == "DOWN" then return 0, -n * step end
    if dir == "UP" then return 0, n * step end
    return n * step, 0
end

-- ---------------------------------------------------------------------------
-- One icon
-- ---------------------------------------------------------------------------
--- What a Ctrl-click on this icon would do, as the tooltip says it and as OnClick acts on it. One
--- function so the two can never drift apart and promise different things.
---
--- Reaching an icon takes a held Ctrl and a chosen target, which is a long way from a slip. So a
--- reagent or a leftover quest item goes without a second question here - the tooltip under the
--- cursor has already named it. Only what BW.AlwaysAsks covers still stops us: an item another
--- addon unlocked, and anything green.
local function ActionFor(entry)
    if not entry then return nil end
    if entry.confirm and BW.AlwaysAsks(entry) then return "ask" end
    return "delete"
end

local function IconTooltip(self)
    local entry = self.entry
    if not entry then return end
    local item = entry.item
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    -- The item's own tooltip first: whatever the player already knows how to read.
    local shown = false
    if item.bag and item.slot then
        local ok = pcall(GameTooltip.SetBagItem, GameTooltip, item.bag, item.slot)
        shown = ok and GameTooltip:NumLines() > 0
    end
    if not shown then
        GameTooltip:SetText(item.link or item.name or "?", 1, 1, 1)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(("%dx - %s"):format(item.count or 1, BW.Coin(entry.real or entry.value or 0)),
        1, 0.82, 0.3)
    if entry.reason then
        GameTooltip:AddLine(entry.reason, 0.8, 0.8, 0.8, true)
    end
    if ActionFor(entry) == "ask" then
        GameTooltip:AddLine("Ctrl-click: asks first", 0.6, 0.85, 1)
    else
        GameTooltip:AddLine("Ctrl-click: delete", 1, 0.4, 0.4)
    end
    GameTooltip:AddLine("Right-click: never delete this", 0.6, 0.85, 1)
    GameTooltip:Show()
end

local function IconClick(self, mouse)
    local entry = self.entry
    if not (entry and entry.item) then return end

    if mouse == "RightButton" then
        BW.SetIgnored(entry.item.itemID, true)
        BW.Print("%s will never be deleted.", entry.item.name or "?")
        BW.PlanNow()
        return
    end

    -- A plain click does nothing, on purpose. The bag button deletes on a plain click because you
    -- had to open your bags to reach it; these icons sit on the world, where a misclick costs an
    -- item. Ctrl is how you act here.
    if not IsControlKeyDown() then return end

    -- And Ctrl here means "act", NOT "skip the question" - that is what it means on the bag button,
    -- where a plain click already acts. Reading it the other way would make the row the one place
    -- where a reagent goes without being asked about, which is exactly backwards for the surface
    -- that is easiest to click by accident.
    if ActionFor(entry) == "ask" then
        BW.AskThenDelete(entry)
        return
    end
    BW.DeleteStack(entry, true)
end

local function BuildIcon(index)
    local b = CreateFrame("Button", "BagWardenBarIcon" .. index, bar)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)

    -- The price sits on the world, not on a panel, so it has to be readable over grass, stone and a
    -- lit spell effect alike - which means an outline. Not by naming an outlined font object: only
    -- the plain ones are proven on this client, and a CreateFontString that names a template the
    -- client hasn't got throws, here, the first time the row is ever drawn. So take the family's
    -- font and add the outline by hand, the way BuffWarden's row does. SetFont needs BOTH the font
    -- and the size; passing a nil size is an error in the client.
    b.price = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.price:SetPoint("TOP", b, "BOTTOM", 0, -1)
    local font, fontSize = b.price:GetFont()
    if font and fontSize then b.price:SetFont(font, fontSize, "OUTLINE") end
    b.price:SetShadowColor(0, 0, 0, 1)
    b.price:SetShadowOffset(1, -1)

    b:SetScript("OnEnter", IconTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", IconClick)

    -- Unlocked, the whole row drags: you grab whichever icon is under the cursor.
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function()
        if DB().barLocked then return end
        bar:StartMoving()
    end)
    b:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        SavePosition(true)
    end)
    return b
end

--- A thin coloured frame drawn on the icon's edge, by four textures rather than a backdrop, so it
--- costs nothing and scales with the icon.
local function SetEdge(b, r, g, bl)
    if not b.edgeParts then
        b.edgeParts = {}
        local function Part(p1, p2, w, h)
            local t = b:CreateTexture(nil, "OVERLAY")
            t:SetPoint(p1)
            t:SetPoint(p2)
            if w then t:SetWidth(w) else t:SetHeight(h) end
            b.edgeParts[#b.edgeParts + 1] = t
        end
        Part("TOPLEFT", "TOPRIGHT", nil, 2)
        Part("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
        Part("TOPLEFT", "BOTTOMLEFT", 2)
        Part("TOPRIGHT", "BOTTOMRIGHT", 2)
    end
    for _, t in ipairs(b.edgeParts) do t:SetColorTexture(r, g, bl, 0.9) end
end

-- ---------------------------------------------------------------------------
-- How much room is left
-- ---------------------------------------------------------------------------
--- The free-slot line above the row: what it says, what colour, and whether it is urgent enough to
--- put the row on screen by itself.
---
--- "Almost full" is not a fixed number. A player who has set "only when free slots are under 8" has
--- already told us what running low means to them, so that is the line; without one, five. Absolute
--- slots rather than a percentage, because slots is the number a player actually watches - 20% of a
--- starter pack is eight slots, which is not low at all.
local function Status(candidates)
    local free = BW.FreeSlots and BW.FreeSlots() or 0
    local low = DB().barFreeSlots or 0
    if low <= 0 then low = 5 end

    if free <= 0 then
        -- Full, and the row may have nothing to offer: say which, because "bags full" over an empty
        -- row would look like BagWarden had given up without saying so.
        local text = candidates > 0 and "Bags full" or "Bags full - nothing I can free"
        return text, 1, 0.3, 0.3, true
    end
    if free <= low then
        return free .. " free", 1, 0.75, 0.2, true
    end
    return free .. " free", 0.7, 0.7, 0.7, false
end

-- ---------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------
--- Should the row be on screen at all? Separate from whether the plan is worth keeping current:
--- BW.BarWanted below decides that, and stays true while the row is merely hidden by a threshold,
--- because we need a plan to know whether the threshold has been crossed.
function BW.BarWanted()
    return DB().barEnabled and true or false
end

function BW.BarShouldShow()
    if not BW.BarWanted() then return false end
    if DB().barHideInCombat and InCombatLockdown() then return false end
    -- "Only when I am running out of room": 0 means always. Free slots, not a percentage, because
    -- free slots is the number the player is actually watching.
    --
    -- The test is INCLUSIVE - at most this many, not fewer than - so the setting reads the way a
    -- player says it: four means "show it when I am down to four slots", and four free is already
    -- down to four. Zero keeps its meaning of "always", so the slider's first stop is still always.
    local atMost = DB().barFreeSlots or 0
    if atMost > 0 and (BW.FreeSlots() or 0) > atMost then return false end
    return true
end

local function EnsureBar()
    if bar then return end
    bar = CreateFrame("Frame", "BagWardenBar", UIParent)
    bar:SetMovable(true)
    bar:SetClampedToScreen(true)
    bar:SetSize(Size(), Size())
    local p = DB().barPoint
    if p and p[1] and p[2] then
        bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    end
    -- Same treatment as the price: this sits on the world, so it needs an outline added by hand
    -- rather than an outlined font object, which may not exist on this client.
    bar.status = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local font, fontSize = bar.status:GetFont()
    if font and fontSize then bar.status:SetFont(font, fontSize, "OUTLINE") end
    bar.status:SetShadowColor(0, 0, 0, 1)
    bar.status:SetShadowOffset(1, -1)

    SavePosition()
    bar:Hide()
end

--- Draw the row from the current plan. Cheap enough to call on every plan change: it reuses the
--- icon frames and only ever changes textures and text.
function BW.UpdateBar()
    if not BW.BarWanted() then
        if bar then bar:Hide() end
        return
    end
    EnsureBar()
    if not BW.BarShouldShow() then bar:Hide() return end

    local plan = BW.plan
    local candidates = (plan and plan.candidates) or {}
    local wanted = Count()
    local size = Size()
    bar:SetSize(size, size)

    local shown = 0
    for index = 1, wanted do
        local entry = candidates[index]
        if not entry then break end
        local b = icons[index] or BuildIcon(index)
        icons[index] = b
        b.entry = entry
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", IconOffset(index))
        b.icon:SetTexture(entry.item.icon or (C_Item and C_Item.GetItemIconByID
            and C_Item.GetItemIconByID(entry.item.itemID)) or 134400)
        b.count:SetText((entry.item.count or 1) > 1 and entry.item.count or "")
        b.price:SetText(DB().barShowPrice and BW.Money(entry.real or entry.value or 0) or "")
        -- Three edges, because there are now three answers, and an edge that lumped the last two
        -- together would be telling the player something the click no longer does.
        if ActionFor(entry) == "ask" then
            SetEdge(b, 0.4, 0.8, 1)         -- blue: this one stops and asks, Ctrl or not
        elseif entry.confirm then
            SetEdge(b, 1, 0.75, 0.2)        -- amber: not plain junk - read the tooltip first
        else
            SetEdge(b, 0.55, 0.55, 0.55)    -- plain junk
        end
        b:Show()
        shown = index
    end
    for index = shown + 1, #icons do icons[index]:Hide() end

    -- The free-slot line. It hangs off the bar, which is always the first icon's corner, so it does
    -- not move as the row fills or empties. Above, except when the row grows upwards.
    local text, red, green, blue, urgent = Status(shown)
    local status = bar.status
    status:ClearAllPoints()
    if (DB().barDirection or "RIGHT") == "UP" then
        -- Below the icons, and clear of the price line when that is on.
        status:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, DB().barShowPrice and -16 or -3)
    else
        status:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 3)
    end
    status:SetText(text)
    status:SetTextColor(red, green, blue)
    status:SetShown(DB().barShowFree ~= false)

    -- Nothing to offer is not an error, and an empty row is a row that has stopped meaning anything,
    -- so it normally goes away until there is something in it again. The exception is the moment the
    -- player most needs telling: bags full or nearly, with nothing BagWarden can free. Going quiet
    -- then would be hiding exactly when we have something worth saying.
    if shown > 0 or (urgent and DB().barShowFree ~= false) then bar:Show() else bar:Hide() end
end

--- Called when a setting changes: the row may need to appear, disappear, or be laid out again.
--- Goes through PlanNow rather than UpdateBar alone, because turning the row ON is exactly the case
--- where there is no current plan to draw.
function BW.ApplyBarSettings()
    if BW.BarWanted() then
        BW.PlanNow()
    else
        if bar then bar:Hide() end
    end
end

-- Entering combat only hides the row, which needs no plan. LEAVING it does: with "hide it in
-- combat" on we deliberately stopped scanning while hidden, so the plan is as of the pull and
-- whatever was looted during the fight is missing from it. Rescan rather than redraw.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
    if not BW.BarWanted() then return end
    if event == "PLAYER_REGEN_ENABLED" then BW.Refresh() else BW.UpdateBar() end
end)

--- Where the row is, for `/bagw where`. Useful when someone has dragged it off the edge.
function BW.WhereIsBar()
    if not DB().barEnabled then return "the on-screen row is off." end
    if not bar then return "the on-screen row is on, but hasn't been built yet." end
    local l, t = bar:GetLeft(), bar:GetTop()
    return ("row: %s, %d icons, %s at %d,%d"):format(
        bar:IsShown() and "shown" or "hidden",
        Count(), DB().barDirection or "RIGHT", math.floor(l or 0), math.floor(t or 0))
end
