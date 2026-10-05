-- BagWarden - the button on the bag frame, its tooltip, and the chat report.
-- One click does exactly one thing, and the tooltip always says what that thing is before you click.
local ADDON, BW = ...
local LIB = LibStub("LibForever-1.0")

-- Deleting works ONLY inside a real click or keypress. DeleteCursorItem is a hardware-event
-- function: from a slash command, a timer or any other code of ours it silently does nothing, and
-- C_Item.DeleteItem is protected outright (ADDON_ACTION_BLOCKED). Verified in game 2026-09-23: the
-- bag button's own OnClick deletes; /run in chat does not.
-- So never move a delete into a timer, a C_Timer.After, an event handler or a "do the rest of them"
-- loop. It would quietly stop working, which is also exactly the behaviour we want anyway: one
-- deliberate click, one item.
BW.deleteEnabled = true

local button

-- ---------------------------------------------------------------------------
-- Tooltip
-- ---------------------------------------------------------------------------
--- Shrink the lines we just added to the tooltip's small font. Only works on GameTooltip's named
--- font strings, which is where our tooltip actually shows.
local function SmallFrom(tooltip, first)
    if tooltip ~= GameTooltip then return end
    for i = first, tooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        if line then line:SetFontObject(GameTooltipTextSmall) end
    end
end

--- A few short lines, and nothing else: what BagWarden is, how full the bags are, what this click
--- does. The tooltip is read mid-play, so every line that isn't about the click costs attention.
--- Anything explanatory (what's protected and why, what has been deleted) lives on the settings page.
function BW.FillTooltip(tooltip)
    if BW.planStale then BW.PlanNow() end
    local plan = BW.plan
    tooltip:AddLine("BagWarden")
    if not plan then
        tooltip:AddLine("Bags not read yet.", 0.8, 0.8, 0.8)
        SmallFrom(tooltip, 2)
        return
    end
    tooltip:AddLine(string.format("Bags: %d free of %d", plan.free, plan.total), 0.8, 0.8, 0.8)

    local click
    if plan.target then
        local target = plan.target
        local link = target.item.link or target.item.name or "?"
        tooltip:AddLine(string.format("Delete %s - %s", link, BW.Coin(target.real or target.value or 0)), 1, 0.82, 0)
        click = "Left-click: delete this item"
    else
        tooltip:AddLine("Nothing to free.", 0.8, 0.8, 0.8)
    end

    if not BW.deleteEnabled then
        tooltip:AddLine("Test build: deletes nothing yet.", 1, 0.4, 0.4)
    end
    if click then
        tooltip:AddLine(click, 0.6, 0.6, 0.6)
        -- Only worth saying when the next click would actually stop and ask.
        if plan.action == "confirm" then
            tooltip:AddLine("Ctrl-click: delete without asking", 0.6, 0.6, 0.6)
        end
        tooltip:AddLine("Right-click: never delete this item", 0.6, 0.6, 0.6)
    end
    SmallFrom(tooltip, 2)
end

-- ---------------------------------------------------------------------------
-- The click
-- ---------------------------------------------------------------------------
--- What one click does. `fromHardware` is true when we're inside the player's own click or
--- keypress, which is the only context the client lets an addon delete in. `skipAsk` is a held
--- Ctrl: it skips the QUESTION, never a protection - anything BagWarden keeps is still kept.
function BW.ReportPlan(fromHardware, skipAsk)
    -- Always work from a scan taken now, never from whatever the last bag update left behind.
    local plan = BW.PlanNow()

    if not plan.target then
        BW.Print("nothing to free: everything in your bags is worth keeping.")
        return
    end
    if not BW.deleteEnabled then
        BW.Print("would delete: %s%s", BW.Describe(plan.target) or "?",
            plan.action == "confirm" and " (would ask first: " .. (plan.target.reason or "not junk") .. ")" or "")
        BW.Print("deleting is off in this test build. Nothing was touched.")
        return
    end
    -- Ctrl skips the question for ordinary soft keeps. What it can never skip is BW.AlwaysAsks,
    -- which the row's icons ask as well, so the two surfaces cannot drift apart.
    if plan.action == "confirm" and (not skipAsk or BW.AlwaysAsks(plan.target)) then
        -- The popup's own Delete button is the player's click, so the deletion happens there.
        BW.AskThenDelete(plan.target)
        return
    end
    -- One click, one stack. DeleteStack verifies the slot again and refuses if anything moved.
    BW.DeleteStack(plan.target, fromHardware, plan.action == "confirm" and skipAsk or nil)
end

--- What a click on BagWarden's button does, wherever that button happens to live. Shared, because
--- the button inside Baganator is a different frame built to Baganator's shape - but it has to do
--- exactly the same thing, and two copies of this would eventually stop agreeing.
function BW.OnBagButtonClick(_, mouse)
    if mouse == "RightButton" then
        if BW.planStale then BW.PlanNow() end
        local target = BW.plan and BW.plan.target
        if target then
            BW.SetIgnored(target.item.itemID, true)
            BW.Print("%s will never be deleted.", target.item.name or "?")
        else
            BW.OpenOptions()
        end
        return
    end
    -- Inside the button's OnClick: a real hardware event, which is what deleting needs.
    -- Ctrl held means "don't ask me", read at the moment of the click.
    BW.ReportPlan(true, IsControlKeyDown())
end
local OnClick = BW.OnBagButtonClick

-- ---------------------------------------------------------------------------
-- Placing the button on whichever bag frame is open
-- ---------------------------------------------------------------------------
-- The bag frames we can sit on, best first. Blizzard's combined bag window and the backpack are the
-- real cases; the rest are the bag addons people replace them with.
local HOSTS = {
    "ContainerFrameCombinedBags",
    "ContainerFrame1",
    "Baganator_SingleViewBackpackViewFrame",
    "Baganator_CategoryViewBackpackViewFrame",
    "BagnonFrameinventory",
    "BagnonInventory1",
}

--- The open bag window, whichever UI is drawing it.
local function Host()
    for _, name in ipairs(HOSTS) do
        local frame = _G[name]
        if frame and frame.IsShown and frame:IsShown() then return frame end
    end
    return nil
end

--- Is any bag window open? While none is, BagWarden doesn't scan at all.
function BW.BagsOpen()
    return Host() ~= nil
end

--- We sit just left of the bag's search box, in the same row. When there is no search box (another
--- bag addon, or Blizzard hiding it), we fall back to the sort button's side, then to the top right.
local function Anchor(host)
    button:ClearAllPoints()
    local box = BagItemSearchBox
    if box and box:IsShown() and box:GetParent() == host then
        -- The same gap Blizzard leaves around the sort button, and vertically centred on the box.
        button:SetPoint("RIGHT", box, "LEFT", -7, 0)
        return
    end
    local sort = BagItemAutoSortButton
    if sort and sort:IsShown() and sort:GetParent() == host then
        button:SetPoint("RIGHT", sort, "LEFT", -2, 0)
    else
        button:SetPoint("TOPRIGHT", host, "TOPRIGHT", -9, -32)
    end
end

--- The tooltip is the promise: it says what the next click does. So when the plan changes under a
--- resting cursor - which is exactly what a click, a Ctrl-click or the keybind does - it has to be
--- rebuilt where it stands rather than waiting for the mouse to leave and come back.
local function RedrawTooltip()
    if not (button and GameTooltip and GameTooltip.IsOwned) then return end
    if not GameTooltip:IsOwned(button) then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    BW.FillTooltip(GameTooltip)
    GameTooltip:Show()
end

--- The bag button itself, for a bag addon that wants to place it in its own window.
function BW.BagButton()
    if not button then BW.BuildButton() end
    return button
end

function BW.UpdateButton()
    if not button then return end
    local plan = BW.plan
    -- 0.6 means "nothing in here is worth freeing". Before the first scan there is no plan at all,
    -- which is a different thing and must not be drawn the same - otherwise the button fades in
    -- every time you open your bags, because Refresh is debounced and the plan lands a fraction of
    -- a second later. No plan yet draws at full strength, and the scan dims it if it was wrong.
    local dim = (plan and not plan.action) and 0.6 or 1

    -- The button inside Baganator is a SECOND frame, built to Baganator's shape rather than
    -- Blizzard's (see Baganator.lua). It lives in their window and they decide where it sits; all
    -- that is left for us is to keep it as bright or as dim as the plan deserves.
    local hosted = BW.BaganatorButton and BW.BaganatorButton()
    if hosted then
        hosted:SetAlpha(dim)
        -- Belt and braces with the OnShow in Baganator.lua: a SetParent we did not see still leaves
        -- the level wrong, and a button drawn under the panel looks exactly like one that is absent.
        hosted:SetFrameLevel(700)
    end

    local host = Host()
    -- Our own button belongs beside Blizzard's sort button and nowhere else. With no Blizzard bag
    -- frame on screen it has no place to be - and that stays true when Baganator is installed,
    -- because what Baganator is showing is the other button, not this one. Showing this one here
    -- would leave a loose button floating on the screen with nothing holding it.
    if not host then button:Hide() return end
    button:SetParent(host)
    button:SetFrameLevel((host:GetFrameLevel() or 1) + 10)
    -- Room first, then the anchor: making room moves the search box we anchor to.
    BW.ApplySearchBox(host)
    Anchor(host)
    -- The free-slot count lives in the tooltip; a number on the round emblem only clutters it.
    -- Always clickable (a click then just says there's nothing to free); dimmed when idle.
    button:SetAlpha(dim)
    button:Show()
    -- The plan can change while the mouse sits on the button (a bag update, or the click itself),
    -- and the keybind changes it without the mouse being anywhere near. Both the tooltip and the
    -- red slot in the bags follow it at once.
    if button:IsMouseOver() or (GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button)) then
        BW.ShowHighlight()
        RedrawTooltip()
    end
end

-- ---------------------------------------------------------------------------
-- The bag search box
-- ---------------------------------------------------------------------------
-- Blizzard sets the search box's width in SetSearchBoxPoint every time a bag frame updates (96 on a
-- single bag, 150 or 330 on the combined window), so setting it once never sticks. We hook that
-- method on each bag frame we meet and narrow it afterwards, which survives reopening and the
-- combined/separate toggle. It's a plain EditBox, so nothing here is protected.
-- Wide enough to read a few characters of what you typed - the first try at 60 showed "Se...".
BW.SEARCH_WIDTH = 120
local BUTTON_ROOM = 35      -- the button (28) plus the gap to the search box (7)
-- Where the right-aligned box ends: clear of the sort button, which Blizzard puts at TOPRIGHT -9
-- and is 28 wide, plus a gap.
local RIGHT_INSET = -(9 + 28 + 6)
local SEARCH_Y = -37        -- the row Blizzard puts the box on, on both layouts
local hookedSearch = {}

--- Only the combined bag window is crowded enough to be worth rearranging. The separate bags have
--- room to spare, so Blizzard's box is left exactly as it is there.
local function IsCombined(host)
    if host.IsCombinedBagContainer then
        local ok, combined = pcall(host.IsCombinedBagContainer, host)
        if ok then return combined end
    end
    return host == ContainerFrameCombinedBags
end

--- Should we be rearranging this window's search box at all?
local function Rearranging(host)
    return BW.db and BW.db.smallSearch and IsCombined(host)
end

--- Blizzard anchors the search box to the host's TOPLEFT (x = 42 on a single bag, 62 on the combined
--- window), which leaves no room for a button to its left. Slide it right by just enough, so our
--- button never lands on the bag's portrait or title. Only used when we aren't right-aligning it.
local function MakeRoom(box, host)
    local point, relativeTo, relativePoint, x, y = box:GetPoint(1)
    if not point or relativeTo ~= host then return end
    local need = BUTTON_ROOM + 8        -- 8 = the frame's own left inset
    if x and x < need then
        box:ClearAllPoints()
        box:SetPoint(point, relativeTo, relativePoint, need, y)
    end
end

--- Narrow the box and move it to the right end of the row, so the box, our button and the sort
--- button read as one group and the title keeps the space it needs.
local function ShrinkRight(box, host)
    box:SetWidth(BW.SEARCH_WIDTH)
    box:ClearAllPoints()
    box:SetPoint("TOPRIGHT", host, "TOPRIGHT", RIGHT_INSET, SEARCH_Y)
end

--- Put the search box where BagWarden needs it. Blizzard re-runs SetSearchBoxPoint on every bag
--- update, so the same work is hooked onto that call and survives reopening and the layout toggle.
function BW.ApplySearchBox(host)
    local box = BagItemSearchBox
    if not (box and host) then return end
    if not hookedSearch[host] and host.SetSearchBoxPoint then
        hookedSearch[host] = true
        hooksecurefunc(host, "SetSearchBoxPoint", function(self, searchBox)
            if not searchBox then return end
            if Rearranging(self) then ShrinkRight(searchBox, self) else MakeRoom(searchBox, self) end
            -- The box just moved or resized, so follow it. This also runs during the bag frame's own
            -- OnShow, which is what puts the button in its final place in that very first frame.
            if button and button:GetParent() == self then Anchor(self) end
        end)
    end
    if Rearranging(host) then
        ShrinkRight(box, host)
        return
    end
    -- Not ours to rearrange: give Blizzard's own width and place back, then just make room beside it.
    if host.SetSearchBoxPoint and box.anchorBag == host then
        box:ClearAllPoints()
        host:SetSearchBoxPoint(box)
    end
    MakeRoom(box, host)
end

--- Put the button up. The first pass runs in the same frame the bags open, so it's there at once;
--- the next-frame pass only corrects the anchor once Blizzard has finished laying the window out,
--- and the scan (debounced) just decides later whether the button is dimmed.
local function Attach()
    BW.UpdateButton()
    C_Timer.After(0, BW.UpdateButton)
    BW.Refresh()
end

local Build
--- Build the button now, for a caller that needs it before our own wiring gets round to it.
function BW.BuildButton()
    if not button then Build() end
end

function Build()
    if button then return end
    -- Built like Blizzard's sort button next to it (ContainerFrame.xml: 28x26, a square ADD
    -- highlight, a pushed state that sinks by a pixel), with our gold emblem as the icon.
    button = CreateFrame("Button", "BagWardenButton", UIParent)
    button:SetSize(28, 26)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- The button body is Blizzard's own raised square button, so ours and the sort button read as a
    -- pair; only the picture differs. bags-button-autosort has the broom baked into the art, so it
    -- can't be reused - ui-squarebuttonbrown is the same look without a picture.
    local body = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("ui-squarebuttonbrown-up")
    if body then
        button:SetNormalAtlas("ui-squarebuttonbrown-up")
        button:SetPushedAtlas("ui-squarebuttonbrown-down")
    else
        button:SetNormalTexture("Interface\\Buttons\\UI-SquareButton-Up")
        button:SetPushedTexture("Interface\\Buttons\\UI-SquareButton-Down")
    end
    button:GetNormalTexture():SetAllPoints(button)
    button:GetPushedTexture():SetAllPoints(button)

    -- Our picture sits on top of that body, about the size of the broom inside the sort button.
    button.icon = button:CreateTexture(nil, "OVERLAY")
    button.icon:SetTexture("Interface\\AddOns\\BagWarden\\Media\\button")
    button.icon:SetSize(18, 18)
    button.icon:SetPoint("CENTER")
    -- Pressed buttons sink a pixel, so the picture goes with it.
    local function IconAt(x, y)
        button.icon:ClearAllPoints()
        button.icon:SetPoint("CENTER", x, y)
    end
    button:SetScript("OnMouseDown", function() IconAt(1, -1) end)
    button:SetScript("OnMouseUp", function() IconAt(0, 0) end)

    -- This button destroys things, so it must not read as just another bronze button beside the
    -- sort button. That used to mean tinting the body red as well - but the warning was carrying
    -- weight it no longer has to: the icon was a dull medallion then, and is a bright gold pack now,
    -- which nobody mistakes for a quiet button. A red square under it only made this button look
    -- like a different addon from the one in Baganator's window, where the same icon sits clean.
    -- So the body keeps the bronze it shares with the sort button, and the warning moves entirely
    -- into the hover glow below - which is the moment it actually matters, just before the click.

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local highlight = button:GetHighlightTexture()
    highlight:ClearAllPoints()
    highlight:SetSize(24, 23)
    highlight:SetPoint("CENTER")
    highlight:SetVertexColor(1, 0.3, 0.25)
    button:SetScript("OnClick", OnClick)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        BW.FillTooltip(GameTooltip)
        GameTooltip:Show()
        BW.ShowHighlight()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        BW.ClearHighlight()
    end)
    button:Hide()

    -- Hook the frames that exist now...
    for _, name in ipairs(HOSTS) do
        local frame = _G[name]
        if frame and frame.HookScript then
            frame:HookScript("OnShow", Attach)
            frame:HookScript("OnHide", function() BW.UpdateButton() end)
        end
    end
    -- ...and catch every container frame, including ones built later and the combined/separate
    -- toggle, through Blizzard's own show handler.
    if type(ContainerFrame_OnShow) == "function" then
        hooksecurefunc("ContainerFrame_OnShow", Attach)
    end
    if type(ToggleAllBags) == "function" then hooksecurefunc("ToggleAllBags", Attach) end
    if type(OpenAllBags) == "function" then hooksecurefunc("OpenAllBags", Attach) end
    if type(OpenBackpack) == "function" then hooksecurefunc("OpenBackpack", Attach) end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    Build()
    BW.ScanQuestLog()
    BW.Refresh()
end)

--- /bagw where - what our button is and where it sits, for when a screenshot and the code disagree.
function BW.WhereIsButton()
    if not button then BW.Print("the bag button hasn't been built yet.") return end
    local host = Host()
    BW.Print("button: %s, shown=%s, parent=%s, host=%s", button:GetName() or "?",
        tostring(button:IsShown()), tostring(button:GetParent() and button:GetParent():GetName()),
        tostring(host and host:GetName()))
    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
    BW.Print("  anchor: %s to %s %s at %.0f,%.0f", tostring(point),
        tostring(relativeTo and relativeTo.GetName and relativeTo:GetName()), tostring(relativePoint),
        x or 0, y or 0)
    local normal = button:GetNormalTexture()
    BW.Print("  size %.0fx%.0f, alpha %.1f, level %d, texture %s", button:GetWidth(), button:GetHeight(),
        button:GetAlpha(), button:GetFrameLevel(), tostring(normal and normal:GetTexture()))
    local box = BagItemSearchBox
    if box then
        BW.Print("  search box: shown=%s, parent=%s, width %.0f", tostring(box:IsShown()),
            tostring(box:GetParent() and box:GetParent():GetName()), box:GetWidth())
    end
end

