-- BagWarden - marking something as scrap.
-- Alt-click any stack in your bags and it joins the scrap list: the next merchant you open buys it,
-- and you never have to decide about that item again.
--
-- How the click is caught, and why it is caught this way:
-- RXPGuides hooks the global ContainerFrameItemButton_OnModifiedClick for the same job, and guards
-- it with an existence check - because it is not certain to be there, and the rest of that addon's
-- inventory code still calls GetContainerItemID, a global Forever no longer has. So it is no proof
-- the hook works on this client. What IS proven here is Highlight.lua: the red slot glow has worked
-- in game since beta1, and it finds its button through frame:EnumerateValidItems() and
-- itemButton:GetBagID(). So the buttons are hooked one by one through that same enumeration, using
-- what we have already watched work rather than a global we would be guessing at.
--
-- HookScript, never SetScript: these are Blizzard's buttons, and replacing their handler would
-- break whatever the client does with them. A hook cannot suppress the default click either, which
-- is the honest trade - if Alt-click turns out to mean something to the client as well, both will
-- happen, and that is a thing to see in game rather than assume.
local ADDON, BW = ...

local POOR = Enum.ItemQuality and Enum.ItemQuality.Poor or 0
local COMMON = Enum.ItemQuality and Enum.ItemQuality.Common or 1

-- Same list Highlight.lua walks, for the same reason: these are the frames that draw bag slots.
local HOSTS = { "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2",
    "ContainerFrame3", "ContainerFrame4", "ContainerFrame5" }

--- Can this be scrapped at all? Grey and white only.
--- Selling is recoverable - the merchant holds twelve items in buyback - but only until you walk
--- away, and an Alt-click that landed on the wrong slot should not be able to turn a blue into
--- gold you can't undo. Green and better are refused out loud, so a misclick says something rather
--- than quietly doing the worst thing in the bag.
local function CanScrap(quality)
    quality = quality or 0
    return quality == POOR or quality == COMMON
end

--- Alt-click on one bag slot: add it to the scrap list, or take it off again.
local function Toggle(itemButton)
    if not IsAltKeyDown() then return end
    local bag, slot = itemButton:GetBagID(), itemButton:GetID()
    if not (bag and slot) then return end

    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not (info and info.itemID) then return end
    local itemID = info.itemID
    local name = info.itemName or info.hyperlink or ("item " .. itemID)

    if BW.IsScrap(itemID) then
        BW.SetScrap(itemID, false)
        BW.Print("%s is no longer scrap.", info.hyperlink or name)
        return
    end

    -- The quality on the container info can be nil while the client is still filling the item in;
    -- fall back to what we know, and refuse rather than guess when we know nothing.
    local details = BW.ItemInfo(info.hyperlink, itemID)
    local quality = info.quality or (details and details.quality)
    if quality == nil then
        BW.Print("can't tell what %s is yet - try again in a moment.", name)
        return
    end
    if not CanScrap(quality) then
        BW.Print("%s is better than white, so it won't be scrapped. Sell it yourself if you mean to.",
            info.hyperlink or name)
        return
    end

    BW.SetScrap(itemID, true)
    BW.Print("%s is scrap - the next merchant will buy it.", info.hyperlink or name)
end

-- One hook per button, ever. The flag lives on the button rather than in a table of our own so it
-- cannot go stale if the client replaces or re-pools its bag frames.
local function HookButton(itemButton)
    if itemButton.bagWardenScrapHooked then return end
    itemButton.bagWardenScrapHooked = true
    itemButton:HookScript("OnClick", function(self, mouse)
        if mouse ~= "LeftButton" then return end
        local ok, err = pcall(Toggle, self)
        if not ok then BW.Debug("scrap click failed: %s", tostring(err)) end
    end)
end

--- Hook whatever bag buttons are on screen now. Called every time a bag window opens, because the
--- client builds and re-pools those buttons as bags are opened and closed.
function BW.HookScrapClicks()
    for _, name in ipairs(HOSTS) do
        local frame = _G[name]
        if frame and frame:IsShown() and frame.EnumerateValidItems then
            local ok = pcall(function()
                for _, itemButton in frame:EnumerateValidItems() do HookButton(itemButton) end
            end)
            if not ok then BW.Debug("could not walk %s", name) end
        end
    end
    BW.MarkScrap()
end

-- ---------------------------------------------------------------------------
-- The coin on the slot
-- ---------------------------------------------------------------------------
-- A small gold coin in the corner of every scrapped stack, so the list is visible in the bags
-- rather than only on the settings page.
--
-- The texture is "Interface/Buttons/UI-GroupLoot-Coin-Up", and it is not a guess: RXPGuides marks
-- its own junk list with exactly that file, 16x16, offset one pixel into the corner, and it is
-- running on this client. (The same file also showed us something else - RXP resolves
-- GetCoinTextureString through C_CurrencyInfo with a fallback, which is independent confirmation of
-- the missing-global we hit in beta1.) Sizing and placement follow theirs, because a convention a
-- player already knows from another addon is worth more than one of ours.
local COIN = "Interface/Buttons/UI-GroupLoot-Coin-Up"

local function Coin(itemButton)
    local coin = itemButton.bagWardenCoin
    if not coin then
        coin = itemButton:CreateTexture(nil, "OVERLAY")
        coin:SetTexture(COIN)
        coin:SetSize(15, 15)
        -- Top left: the slot's own count sits bottom right, and the delete highlight fills the
        -- whole slot, so this corner is the one nothing else is using.
        coin:SetPoint("TOPLEFT", itemButton, "TOPLEFT", 1, -1)
        itemButton.bagWardenCoin = coin
    end
    return coin
end

--- Put a coin on every scrapped stack on screen, and take it off the rest. Cheap: it reads the
--- slot's item id and shows or hides one texture, with no scan and no tooltip.
function BW.MarkScrap()
    for _, name in ipairs(HOSTS) do
        local frame = _G[name]
        if frame and frame:IsShown() and frame.EnumerateValidItems then
            pcall(function()
                for _, itemButton in frame:EnumerateValidItems() do
                    local bag, slot = itemButton:GetBagID(), itemButton:GetID()
                    local info = bag and slot and C_Container.GetContainerItemInfo(bag, slot)
                    local scrap = info and info.itemID and BW.IsScrap(info.itemID)
                    -- Only build the texture for a slot that needs one: most slots never will.
                    if scrap then
                        Coin(itemButton):Show()
                    elseif itemButton.bagWardenCoin then
                        itemButton.bagWardenCoin:Hide()
                    end
                end
            end)
        end
    end
end

--- How many items are on the list, and what they are worth to sell - for the settings page.
function BW.ScrapInBags()
    local found, seen = {}, {}
    for _, item in ipairs(BW.ScanBags()) do
        if BW.IsScrap(item.itemID) and not seen[item.itemID] then
            seen[item.itemID] = true
            found[#found + 1] = item
        end
    end
    return found
end

-- ---------------------------------------------------------------------------
-- Saying so on the item itself
-- ---------------------------------------------------------------------------
-- Alt-click is not discoverable if nothing ever mentions it, and a chat line after the fact is not
-- the same as knowing beforehand. So the item's own tooltip carries it.
--
-- The hook is Skillwright's, down to the guard and the two-tooltip filter: that is shipped code we
-- have watched work on this client, and OnTooltipSetItem - the way everyone wrote this before - was
-- removed from the client years ago. Guessing between the two is exactly how the last two rounds
-- went wrong.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
        if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
        local itemID = data and data.id
        if not itemID or not BW.db then return end

        if BW.IsScrap(itemID) then
            -- True wherever you see the item - in a bag, at a merchant, in a chat link - so it is
            -- not limited to the bags the way the hint below is.
            -- Gold, the colour of the coin on the slot and of BagWarden's own name, not grey.
            -- A grey line reads as something the game has switched off.
            tt:AddLine("|cffc9a227BagWarden|r  |cffffd100scrap - the next merchant buys this|r")
            tt:AddLine("|cffc9a227Alt-click in your bags to take it off the list|r")
            return
        end

        -- Alt-click only does anything over a bag slot, so the line has to say WHERE - it shows on
        -- a merchant's wares and on chat links too, and "Alt-click to sell this" would be a lie
        -- there. Saying "in your bags" makes one sentence that is true everywhere it appears, which
        -- beats the two ways of limiting it to the bags: GameTooltip:GetOwner() is a call nothing
        -- else in the family makes, and tracking the hovered button cannot work - the tooltip is
        -- built inside the button's own OnEnter, so a HookScript on it runs AFTER this has already
        -- decided, and the hint would always be one hover behind.
        -- The quality comes from C_Item.GetItemInfo, not from the tooltip's own data table: `data.id`
        -- is the only field of it anything in the family reads, so a `data.quality` would be me
        -- assuming a field exists. ItemInfo is cached per item, so this costs nothing per hover.
        local details = BW.ItemInfo(nil, itemID)
        local quality = details and details.quality
        if quality ~= nil and CanScrap(quality) then
            tt:AddLine("|cffc9a227Alt-click in your bags: sell at the next merchant|r")
        end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:SetScript("OnEvent", function(_, event)
    if event == "BAG_UPDATE_DELAYED" then
        -- Items move: a sort, a stack merging, a slot emptying. The coins belong to slots, not to
        -- items, so they have to be redrawn whenever what is in a slot changes.
        BW.MarkScrap()
        return
    end
    -- The same four entry points the bag button uses, so a button is hooked the first time its
    -- window appears rather than one click later.
    for _, hook in ipairs({ "ToggleAllBags", "OpenAllBags", "OpenBackpack", "ContainerFrame_OnShow" }) do
        if type(_G[hook]) == "function" then
            hooksecurefunc(hook, function() BW.HookScrapClicks() end)
        end
    end
    BW.HookScrapClicks()
end)
