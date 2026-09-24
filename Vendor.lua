-- BagWarden - selling junk at a merchant.
-- Selling is not deleting: the money comes back and the items sit in the merchant's buyback list.
-- It still follows the same rules, because a sold quest item is just as annoying as a deleted one:
--   * only grey items, and only ones that pass the whole protection chain;
--   * each stack is read again immediately before it is sold;
--   * a fixed number per visit, so a bug can never chew through a bag;
--   * any error stops the run, and nothing is ever sold without a merchant window open.
local ADDON, BW = ...

-- The merchant's buyback list holds 12 items. Selling more than that per visit would put the
-- earliest ones beyond recovery, so this cap is a safety limit, not a performance one.
local MAX_PER_VISIT = 12
local POOR = Enum.ItemQuality and Enum.ItemQuality.Poor or 0

--- Sell the greys, once, when a merchant opens. Returns how many stacks went and what they made.
function BW.SellGreys()
    -- Same rule as deleting: a self test sells nothing, whatever it calls.
    if BW.testing then return 0, 0 end
    if not (BW.db and BW.db.sellGreys) then return 0, 0 end
    if not MerchantFrame or not MerchantFrame:IsShown() then return 0, 0 end

    local sold, total = 0, 0
    for _, item in ipairs(BW.ScanBags()) do
        if sold >= MAX_PER_VISIT then break end
        if (item.quality or 0) == POOR and not item.locked and not item.incomplete
            and (item.sellPrice or 0) > 0 and not item.hasNoValue then
            -- The same chain the delete path uses: anything kept is never sold either.
            local strength = BW.KeepReason(item)
            if not strength then
                -- Read the slot again: the scan above is already a moment old.
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
        end
    end

    if sold > 0 then
        BW.Print("sold %d junk %s for %s.", sold, sold == 1 and "stack" or "stacks", BW.Coin(total))
    end
    return sold, total
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", function()
    -- Once per merchant window, and never on a timer.
    local ok, err = pcall(BW.SellGreys)
    if not ok then BW.Debug("sell failed: %s", tostring(err)) end
end)
