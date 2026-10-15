-- BagWarden inside GudaBags.
--
-- GudaBags publishes exactly the hook this needs:
--
--   GudaBags.API.OnItemButtonUpdate(function(button, bagID, slot) end)
--
-- It fires after every real-item update on one of their buttons, which is the thing that was
-- missing everywhere else. The scrap gesture was reported broken in Baganator because we hooked
-- buttons when a bag WINDOW opened, and a bag addon builds its buttons after that moment - so we
-- walked an empty list and never looked again. A per-button callback removes the guess entirely:
-- we are told, every time, including when a button is re-pooled onto a different slot.
--
-- Their button is CreateFrame("ItemButton", name, wrapper, "ContainerFrameItemButtonTemplate")
-- with RegisterForClicks("AnyUp"), so HookScript("OnClick") works exactly as it does on Blizzard's
-- own bags. HookScript and never SetScript: these are their buttons.
--
-- The callback hands us bagID and slot directly, so nothing here reads GetBagID. That matters
-- because a pooled button's identity changes under it - what the button IS is only true until the
-- next update, which is why the pair is stored on the button every time rather than once.
--
-- Their own documented limits, repeated here so nobody reads silence as a bug: it does not fire
-- for empty or pseudo slots, for read-only or cached-character views, or for guild bank items.
-- None of those are things BagWarden would act on anyway.
local ADDON, BW = ...

local function OnButtonUpdate(button, bag, slot)
    if not (button and bag and slot) then return end

    -- The slot this button is drawing RIGHT NOW. Rewritten on every update, because the pool
    -- moves buttons between slots and a value captured at hook time would be a lie by the second
    -- time the window laid out.
    button.bagWardenBag, button.bagWardenSlot = bag, slot
    if BW.RegisterHostedButton then BW.RegisterHostedButton(bag, slot, button) end

    if not button.bagWardenScrapHooked then
        button.bagWardenScrapHooked = true
        button:HookScript("OnClick", function(self, mouse)
            if mouse ~= "LeftButton" then return end
            if not BW.ModifierHeld("scrap") then return end
            -- Read the slot off the button, not off the closure: this handler outlives the update
            -- that installed it.
            local b, s = self.bagWardenBag, self.bagWardenSlot
            if not (b and s) then return end
            local info = C_Container.GetContainerItemInfo(b, s)
            if not (info and info.itemID) then return end
            BW.ToggleScrap(info.itemID, info.hyperlink, info.quality)
        end)
    end

    -- The coin, drawn here rather than by a sweep: this fires on exactly the occasions a sweep
    -- was trying to catch up with.
    if BW.ScrapCoin then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        BW.ScrapCoin(button, info and info.itemID and BW.IsScrap(info.itemID))
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if not (GudaBags and GudaBags.API and GudaBags.API.OnItemButtonUpdate) then return end
    -- Registering cannot be allowed to take BagWarden down with it, and a GudaBags that changes
    -- this API is the likeliest way that happens.
    local ok, err = pcall(GudaBags.API.OnItemButtonUpdate, OnButtonUpdate)
    if ok then
        BW.gudaHooked = true
    else
        BW.Debug("GudaBags hookup failed: %s", tostring(err))
    end
end)
