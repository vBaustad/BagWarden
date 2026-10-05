-- BagWarden - working inside Baganator.
-- Baganator replaces Blizzard's bag windows entirely, so everything of ours that attaches to them
-- disappears: the bag button, the red slot glow, the Alt-click that marks scrap, and the coin on a
-- scrapped slot. What keeps working on its own is the part that never needed a bag frame - the
-- on-screen row, the keybind, and selling at a merchant - because those read the containers.
--
-- All of this uses Baganator's own published API, read out of its API/ folder rather than
-- remembered: RegisterJunkPlugin and RegisterRegion are documented there with their contracts, and
-- Baganator ships the same integration for the Scrap and SellJunk addons, which is the shape
-- followed here down to calling RequestItemButtonsRefresh when our list changes.
--
-- What is deliberately NOT done: hooking Alt-click on Baganator's item buttons. Alt-click already
-- means "highlight similar items" there (ItemViewCommon/ItemButton.lua). Firing on top of that
-- would be us talking over the bag addon the player chose, so inside Baganator the way to mark
-- scrap is the "Mark the item under your cursor as scrap" keybind, which works over any tooltip.
local ADDON, BW = ...

local ID = "bagwarden_scrap"

-- What happened when we tried, step by step, for `/bagw baganator`. Every entry is set exactly
-- where the thing it describes happens, so the report cannot drift from the attempt.
BW.baganatorSteps = {}
local function Step(name, ok, detail)
    BW.baganatorSteps[#BW.baganatorSteps + 1] = { name = name, ok = ok and true or false, detail = detail }
end

--- Tell Baganator to redraw its item buttons, so a coin appears or vanishes on the same click that
--- changed the list. Safe to call when Baganator isn't there.
function BW.RefreshBaganator()
    if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
        pcall(Baganator.API.RequestItemButtonsRefresh)
    end
end

--- A button built to Baganator's own shape rather than ours.
---
--- Our bag button is deliberately Blizzard's: a 28x26 brown square that matches the sort button it
--- sits beside. Inside Baganator that is exactly the wrong thing to be, so this is a second button,
--- and it INHERITS Baganator's own template rather than reproducing it.
---
--- Reproducing it is what I tried first - UIPanelButtonTemplate at 32x22 with a 17x17 icon, read
--- off ItemViewCommon/Components.xml - and in game it came out invisible: the frame was there and
--- the tooltip worked, but nothing was drawn. Whatever gives their buttons their face is not in
--- those three lines. Inheriting the template means it cannot be, because it is the same template,
--- and the same answer keeps working if they restyle it.
---
--- BaganatorTooltipIconButtonTemplate is a virtual template in ItemViewCommon/Components.xml, which
--- their TOC loads - so it exists by PLAYER_LOGIN, when this runs. If it ever does not, the fallback
--- is the plain Blizzard template, which at least draws something.
---
--- Then Baganator.Skins.AddFrame puts it in their skin system, which is public
--- (Skins/Initialize.lua: `Baganator.Skins = { AddFrame = ... }`). That applies the player's chosen
--- skin now and again whenever they change it - so this follows Dark, ElvUI, GW2 and the rest
--- without us knowing anything about them.
local hostedButton
local function BaganatorShapedButton()
    if hostedButton then return hostedButton end
    local template = "BaganatorTooltipIconButtonTemplate"
    local b = CreateFrame("Button", "BagWardenBaganatorButton", UIParent, template)
    if not b then
        template = "UIPanelButtonTemplate"
        b = CreateFrame("Button", "BagWardenBaganatorButton", UIParent, template)
    end
    BW.baganatorTemplate = template
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Their own buttons put a 17x17 icon in the middle and nothing else (the Cog, the sort broom).
    -- Same size, same anchor, our picture.
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetTexture("Interface\\AddOns\\BagWarden\\Media\\button")
    b.Icon:SetSize(17, 17)
    b.Icon:SetPoint("CENTER")

    -- SetScript, not HookScript: the inherited template has its own OnEnter that shows a tooltip
    -- from self.tooltipHeader, which we never set. Ours replaces it rather than arguing with it.
    b:SetScript("OnClick", BW.OnBagButtonClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        BW.FillTooltip(GameTooltip)
        GameTooltip:Show()
        BW.ShowHighlight()
    end)
    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
        BW.ClearHighlight()
    end)

    -- Re-assert the draw level every time the button is shown, and this is the whole reason the
    -- button was invisible for three rounds.
    --
    -- SetFrameLevel at registration is useless on its own: Baganator calls SetParent when it lays
    -- the region out, AFTER we have registered, and SetParent resets a frame's level relative to
    -- its new parent. So the level we set is thrown away, and the button ends up beneath
    -- Baganator's panel art - while still taking the mouse, because that panel is not mouse-enabled.
    -- Present, correctly placed, hoverable, tooltip and all, and drawn underneath. From outside it
    -- is indistinguishable from a button that was never placed.
    --
    -- OnShow is the right place because it fires on every path that can make it visible again:
    -- Baganator's layout, its "hold Alt to show buttons" parking and unparking, a skin change.
    -- 700 is the number Baganator uses for its own row (ItemViewCommon/ButtonVisibility.lua).
    b:SetScript("OnShow", function(self) self:SetFrameLevel(700) end)

    if Baganator.Skins and Baganator.Skins.AddFrame then
        pcall(Baganator.Skins.AddFrame, "IconButton", b, { "bagwarden" })
    end
    hostedButton = b
    return b
end

--- The button Baganator is showing, for whoever needs to keep it current.
function BW.BaganatorButton() return hostedButton end

--- The item button Baganator is drawing a given bag slot with, so hovering our button lights that
--- slot up the way it does in Blizzard's bags.
---
--- Highlight.lua needs no change to match: their item buttons answer GetBagID() and GetID() exactly
--- like Blizzard's, because they inherit the same item-button mixin - ItemViewCommon/ItemButton.lua
--- calls `self:GetBagID()` on its own buttons. Only ENUMERATING them differs, and that is the part
--- that belongs in this file rather than in a generic one.
---
--- Skins.GetAllFrames is the public list of everything Baganator has handed to its skin system,
--- which includes every item button it has built. It also holds bank and dialog buttons, and
--- buttons belonging to windows that are shut, so the match is on bag, slot AND being on screen -
--- a hidden button from another view would otherwise take the glow and nothing would light up.
function BW.FindHostedItemButton(bag, slot)
    if not (Baganator and Baganator.API and Baganator.API.Skins
        and Baganator.API.Skins.GetAllFrames) then return nil end
    local ok, frames = pcall(Baganator.API.Skins.GetAllFrames)
    if not ok or type(frames) ~= "table" then return nil end
    for _, entry in ipairs(frames) do
        local b = entry and entry.regionType == "ItemButton" and entry.region
        if b and b.GetBagID and b.IsShown and b:IsShown() then
            local okIDs, bagID, slotID = pcall(function() return b:GetBagID(), b:GetID() end)
            if okIDs and bagID == bag and slotID == slot then return b end
        end
    end
    return nil
end

local function Hook()
    Step("Baganator loaded", Baganator ~= nil)
    Step("Baganator.API", Baganator and Baganator.API ~= nil)
    if not (Baganator and Baganator.API) then return end
    Step("API.RegisterJunkPlugin", type(Baganator.API.RegisterJunkPlugin) == "function")
    Step("API.RegisterRegion", type(Baganator.API.RegisterRegion) == "function")
    Step("BW.BagButton", type(BW.BagButton) == "function")

    -- 1. The scrap list as one of Baganator's junk sources. Its own junk coin then marks exactly
    -- what BagWarden would sell, drawn by Baganator in the player's chosen corner and style - which
    -- is better than painting our own coin on top of somebody else's bag UI.
    -- The player picks one junk source in Baganator's settings; it selects ours automatically only
    -- when they have not chosen one, which is Baganator's rule and a polite one.
    if Baganator.API.RegisterJunkPlugin then
        local ok, err = pcall(Baganator.API.RegisterJunkPlugin, "BagWarden scrap", ID,
            function(_, _, itemID) return BW.IsScrap and BW.IsScrap(itemID) or false end)
        Step("junk plugin registered", ok, not ok and tostring(err) or nil)
    end

    -- 2. The bag button, inside Baganator's own backpack window. This is the request as it was
    -- actually made: "show the button on baganators UI for the bags".
    -- Only "backpack" is a valid view and only the two left corners are valid positions, both
    -- asserted on their side, so a wrong value here is an error rather than a silent no-op.
    if Baganator.API.RegisterRegion then
        local button = BaganatorShapedButton()
        if button then
            -- Shown BEFORE it is handed over, and that is not a detail. Baganator lays a region out
            -- with `if button:IsShown() then button:SetParent(parent) ... end` - a hidden frame is
            -- skipped, never parented, never placed, and never shown later either, because nothing
            -- looks at it again until the next layout. Our own Build() ends with button:Hide(),
            -- since without a bag addon the button has nowhere to be until a bag window opens.
            button:Show()
            button:SetFrameLevel(700)   -- and again on every OnShow; see the note where that is set
            BW.baganatorHosted = true
            Step("button built and shown", button:IsShown())
            Step("skinned by Baganator", Baganator.Skins ~= nil and Baganator.Skins.AddFrame ~= nil)
            Step("built from " .. tostring(BW.baganatorTemplate),
                BW.baganatorTemplate == "BaganatorTooltipIconButtonTemplate")
            local ok, err = pcall(Baganator.API.RegisterRegion, "BagWarden", "bagwarden",
                "backpack", "top_left", button)
            Step("region registered", ok, not ok and tostring(err) or nil)
            -- Baganator may already have laid its window out by now; this is the call its own API
            -- documents for a region whose width has changed, and it is what makes it look again.
            if Baganator.API.RequestLayoutUpdate then
                Step("layout update requested", pcall(Baganator.API.RequestLayoutUpdate))
            end
        end
    else
        Step("region registered", false, "no RegisterRegion, or no button to give it")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    -- Baganator may load after us or not at all; either is fine, and neither is an error.
    local ok, err = pcall(Hook)
    if not ok then
        -- Loud, not whispered. A silent failure here is indistinguishable from Baganator not being
        -- installed, and that cost two rounds of guessing at what the player could not see.
        Step("hookup", false, tostring(err))
        BW.Print("couldn't attach to Baganator: %s", tostring(err))
        BW.Print("'/bagw baganator' has the detail.")
    end
end)

--- `/bagw baganator` - every link in the chain, and which one is broken.
function BW.BaganatorReport()
    if #BW.baganatorSteps == 0 then
        BW.Print("the Baganator hookup never ran - no PLAYER_LOGIN yet, or the file didn't load.")
        return
    end
    for _, step in ipairs(BW.baganatorSteps) do
        BW.Print("  %s %s%s", step.ok and "|cff40ff40yes|r" or "|cffff4040NO |r", step.name,
            step.detail and (" - " .. step.detail) or "")
    end

    -- State now, rather than at login: a button that was placed and later hidden looks the same in
    -- the window as one that was never placed at all.
    local button = hostedButton or (BW.BagButton and BW.BagButton())
    if button then
        local parent = button:GetParent()
        BW.Print("button now: %s, parent %s", button:IsShown() and "shown" or "|cffff4040HIDDEN|r",
            (parent and parent.GetName and parent:GetName()) or "unnamed")
        -- Shown and parented is not the same as visible. A button can be behind the panel, or
        -- anchored past its edge - and those look identical from the outside, so say which.
        BW.Print("  level %s, parent level %s",
            tostring(button:GetFrameLevel()), tostring(parent and parent:GetFrameLevel()))
        local left, bottom, width, height = button:GetRect()
        if left and parent and parent.GetRect then
            local pLeft, pBottom, pWidth, pHeight = parent:GetRect()
            local inside = pLeft and left >= pLeft - 1 and bottom >= pBottom - 1
                and (left + width) <= (pLeft + pWidth) + 1
                and (bottom + height) <= (pBottom + pHeight) + 1
            BW.Print("  at %d,%d size %dx%d - %s the window",
                math.floor(left), math.floor(bottom), math.floor(width), math.floor(height),
                inside and "|cff40ff40inside|r" or "|cffff4040OUTSIDE|r")
        else
            BW.Print("  |cffff4040no position yet|r - nothing has laid it out.")
        end
    end
    if Baganator and Baganator.API and Baganator.API.IsJunkPluginActive then
        BW.Print("scrap is Baganator's chosen junk source: %s",
            Baganator.API.IsJunkPluginActive(ID) and "yes" or "no (pick \"BagWarden scrap\" in its settings)")
    end
end
