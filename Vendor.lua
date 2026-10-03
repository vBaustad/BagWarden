-- BagWarden - selling junk at a merchant.
-- Selling is not deleting: the money comes back and the items sit in the merchant's buyback list.
-- It still follows the same rules, because a sold quest item is just as annoying as a deleted one:
--   * grey items, and anything the player Alt-clicked onto the scrap list;
--   * a grey must pass the whole protection chain; a scrapped item must pass the hard half of it;
--   * each stack is read again immediately before it is sold;
--   * a fixed number per visit, so a bug can never chew through a bag;
--   * any error stops the run, and nothing is ever sold without a merchant open.
local ADDON, BW = ...

-- The merchant's buyback list holds 12 items. Selling more than that per visit would put the
-- earliest ones beyond recovery, so this cap is a safety limit, not a performance one.
local MAX_PER_VISIT = 12
local POOR = Enum.ItemQuality and Enum.ItemQuality.Poor or 0

--- Why this stack is not for sale, or nil when it is. One function, because `/bagw sell` reports
--- from it and BW.SellGreys acts on it - a report that described the rule in its own words would be
--- free to describe a rule that is not the one running.
local function NotSelling(item, scrapped, grey)
    if not (grey or scrapped) then return "not grey, and not on the scrap list" end
    if item.locked then return "it is in use right now" end
    if item.incomplete then return "the client has not sent its details yet" end
    if (item.sellPrice or 0) <= 0 or item.hasNoValue then return "the merchant pays nothing for it" end

    local strength, reason = BW.KeepReason(item)
    if strength == "hard" then
        return "protected: " .. (reason or "?")
    end
    if strength and not scrapped then
        -- A grey is left alone on any doubt at all, because WE chose it. A scrapped item is the
        -- player's own choice and only a hard keep overrules that.
        return "protected: " .. (reason or "?") .. " - a grey is left alone on any doubt"
    end
    return nil
end

--- Everything in the bags that bears on a merchant visit: what would sell, what would not and why.
--- Reads only; sells nothing.
function BW.SellPlan()
    local plan = { sell = {}, held = {}, scrapSeen = 0 }
    if not BW.db then plan.blocked = "no saved settings yet" return plan end
    if BW.testing then plan.blocked = "a self test is running" return plan end
    if not BW.db.sellGreys and not next(BW.db.scrap or {}) then
        plan.blocked = "\"sell all grey items\" is off and the scrap list is empty"
        return plan
    end

    for _, item in ipairs(BW.ScanBags()) do
        local scrapped = BW.IsScrap and BW.IsScrap(item.itemID) or false
        local grey = (item.quality or 0) == POOR and BW.db.sellGreys and true or false
        if scrapped then plan.scrapSeen = plan.scrapSeen + 1 end
        if scrapped or grey then
            local why = NotSelling(item, scrapped, grey)
            if why then
                plan.held[#plan.held + 1] = { item = item, why = why, scrapped = scrapped }
            elseif #plan.sell < MAX_PER_VISIT then
                plan.sell[#plan.sell + 1] = { item = item, scrapped = scrapped }
            else
                plan.held[#plan.held + 1] = { item = item, scrapped = scrapped,
                    why = "over the twelve-per-visit limit, so it stays recoverable in buyback" }
            end
        end
    end
    return plan
end

--- Sell what the plan says, once. Returns how many stacks went and what they made.
--- `merchantIsOpen` is the caller saying so: MERCHANT_SHOW firing IS the game telling us a merchant
--- is open, and that is a stronger fact than MerchantFrame:IsShown(), which is Blizzard's UI
--- catching up and may not have happened yet in the same frame. Any other caller has to prove it
--- with the frame.
function BW.SellGreys(merchantIsOpen)
    if not merchantIsOpen and not (MerchantFrame and MerchantFrame:IsShown()) then return 0, 0 end
    local plan = BW.SellPlan()
    if plan.blocked then return 0, 0 end

    local sold, total = 0, 0
    for _, entry in ipairs(plan.sell) do
        local item = entry.item
        -- Read the slot again: the scan is already a moment old.
        local fresh = C_Container.GetContainerItemInfo(item.bag, item.slot)
        if fresh and fresh.itemID == item.itemID and fresh.stackCount == item.count then
            local ok = pcall(C_Container.UseContainerItem, item.bag, item.slot)
            if not ok then
                BW.Print("stopped selling: the merchant refused an item.")
                break
            end
            sold = sold + 1
            total = total + (item.sellPrice or 0) * (item.count or 1)
        end
    end

    if sold > 0 then
        BW.Print("sold %d junk %s for %s.", sold, sold == 1 and "stack" or "stacks", BW.Coin(total))
    end
    return sold, total
end

--- `/bagw sell` - what a merchant visit would do, and for anything held back, why.
--- Sells nothing. This exists because "scrap isn't being sold" has half a dozen possible causes and
--- guessing between them from outside the game wastes a round each time.
function BW.SellReport()
    local plan = BW.SellPlan()
    BW.Print("merchant open: %s", (MerchantFrame and MerchantFrame:IsShown()) and "yes" or "no")
    BW.Print("sell greys: %s | scrap list: %d %s | in your bags now: %d",
        (BW.db and BW.db.sellGreys) and "on" or "off",
        BW.db and BW.db.scrap and (function() local n = 0 for _ in pairs(BW.db.scrap) do n = n + 1 end return n end)() or 0,
        "item(s)", plan.scrapSeen)

    if plan.blocked then
        BW.Print("nothing would be sold: %s", plan.blocked)
        return
    end
    if #plan.sell == 0 and #plan.held == 0 then
        BW.Print("no stack in your bags is grey or on the scrap list.")
        return
    end
    for _, entry in ipairs(plan.sell) do
        BW.Print("  would sell: %dx %s%s", entry.item.count, entry.item.link or entry.item.name or "?",
            entry.scrapped and " |cffc9a227(scrap)|r" or "")
    end
    for _, entry in ipairs(plan.held) do
        BW.Print("  kept: %dx %s%s - %s", entry.item.count, entry.item.link or entry.item.name or "?",
            entry.scrapped and " |cffc9a227(scrap)|r" or "", entry.why)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function()
    -- Once per merchant window, and never on a timer. The event itself is the proof a merchant is
    -- open, so it is passed through rather than re-tested against a frame that may not be up yet.
    local ok, err = pcall(BW.SellGreys, true)
    if not ok then BW.Debug("sell failed: %s", tostring(err)) end
end)
