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

    local strength, reason, _, overridable = BW.KeepReason(item)
    if strength == "hard" then
        -- An item the player put on the scrap list by hand beats two kinds of keep: a GUESS about
        -- what it is for, and a keep that is only about DELETING - the never-delete list, or the
        -- delete-greens setting. It does not beat a fact: a quest in your log wants this, it
        -- cannot be sold, it is too good, it is in use. Nor does it beat not knowing, which is
        -- what an unreadable tooltip or a provider that threw amounts to. See Protect.lua.
        if not (scrapped and overridable) then
            return "protected: " .. (reason or "?")
        end
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
function BW.SellPlan(budget)
    budget = budget or MAX_PER_VISIT
    local plan = { sell = {}, held = {}, scrapSeen = 0 }
    if not BW.db then plan.blocked = "no saved settings yet" return plan end
    if BW.testing then plan.blocked = "a self test is running" return plan end
    if not BW.db.sellGreys and not next(BW.db.scrap or {}) then
        plan.blocked = "\"sell all grey items\" is off and the scrap list is empty"
        return plan
    end

    -- Everything eligible first, with no budget applied, because WHICH twelve we sell has to be a
    -- decision rather than an accident of where things sit in the bags.
    local eligible = {}
    for _, item in ipairs(BW.ScanBags()) do
        local scrapped = BW.IsScrap and BW.IsScrap(item.itemID) or false
        local grey = (item.quality or 0) == POOR and BW.db.sellGreys and true or false
        if scrapped then plan.scrapSeen = plan.scrapSeen + 1 end
        if scrapped or grey then
            local why = NotSelling(item, scrapped, grey)
            if why then
                plan.held[#plan.held + 1] = { item = item, why = why, scrapped = scrapped }
            else
                eligible[#eligible + 1] = { item = item, scrapped = scrapped }
            end
        end
    end

    -- Scrap before greys, and that is the whole fix for "it doesn't ALWAYS sell my scrap".
    -- The loop above walks the bags in slot order, so twelve greys in earlier slots used to spend
    -- the entire visit's budget before the scrap was reached - and whether that happened depended on
    -- where a stack happened to sit, which changes every time you loot. Hence "sometimes".
    -- Scrap is a standing instruction the player gave item by item; selling greys is BagWarden's own
    -- initiative. When only twelve can go, theirs goes first. A stable sort is not needed because
    -- within each group bag order is as good an order as any, and table.sort is not stable - so the
    -- comparison only ever looks at the group.
    table.sort(eligible, function(a, b)
        if a.scrapped ~= b.scrapped then return a.scrapped end
        return false
    end)

    for _, entry in ipairs(eligible) do
        if #plan.sell < budget then
            plan.sell[#plan.sell + 1] = entry
        else
            entry.why = "over the twelve-per-visit limit, so it stays recoverable in buyback"
            plan.held[#plan.held + 1] = entry
        end
    end
    return plan
end

--- Sell what the plan says, once. Returns how many stacks went and what they made.
--- `merchantIsOpen` is the caller saying so: MERCHANT_SHOW firing IS the game telling us a merchant
--- is open, and that is a stronger fact than MerchantFrame:IsShown(), which is Blizzard's UI
--- catching up and may not have happened yet in the same frame. Any other caller has to prove it
--- with the frame.
-- How many times we are willing to re-plan inside one merchant visit.
--
-- NOT because selling renumbers the bags - it does not. A bag slot is a fixed address, and selling
-- out of slot 5 empties slot 5 and leaves slot 6 alone. I built this on the opposite assumption and
-- the simulation refused to reproduce it, which is how the assumption got caught.
--
-- What it is actually for: another addon selling at the same merchant can take a stack we had
-- planned to sell, between our plan and our reaching it. We correctly refuse that stack, and then
-- we are under the twelve for no reason while other stacks were eligible. A second look picks those
-- up. Narrow, real, and cheap. Bounded by passes AND by the twelve-per-visit cap, shared across
-- them, so it can still never chew through a bag.
local MAX_PASSES = 3

--- Take the one-shot marks off the list, for every item we sold that has none left in the bags.
--- Reading the bags again rather than trusting the count we sold: another addon may have sold or
--- moved a stack at the same merchant, and the question that decides this is simply "is any of it
--- still here", which the bags answer directly.
local function ForgetSoldOnce(soldOnce)
    if not next(soldOnce) then return end
    local left = {}
    for _, item in ipairs(BW.ScanBags()) do
        if soldOnce[item.itemID] then left[item.itemID] = true end
    end
    for itemID in pairs(soldOnce) do
        if not left[itemID] then BW.SetScrap(itemID, false) end
    end
end

function BW.SellGreys(merchantIsOpen)
    if not merchantIsOpen and not (MerchantFrame and MerchantFrame:IsShown()) then return 0, 0 end

    local sold, total, moved = 0, 0, 0
    -- Item ids whose mark was a one-shot and which we actually sold a stack of. Cleared after the
    -- whole visit rather than on each sale, because two stacks of the same green is a real hand of
    -- cards: marking it meant "sell these", and dropping the mark on the first sale would leave
    -- the second sitting there.
    local soldOnce = {}
    local plan
    for pass = 1, MAX_PASSES do
        plan = BW.SellPlan(MAX_PER_VISIT - sold)
        if plan.blocked then return 0, 0 end
        if #plan.sell == 0 then break end

        local soldThisPass, stop = 0, false
        for _, entry in ipairs(plan.sell) do
            local item = entry.item
            -- Read the slot again: the plan is already a moment old, and may be describing bags
            -- that another addon has been selling out of.
            local fresh = C_Container.GetContainerItemInfo(item.bag, item.slot)
            if fresh and fresh.itemID == item.itemID and fresh.stackCount == item.count then
                local ok = pcall(C_Container.UseContainerItem, item.bag, item.slot)
                if not ok then
                    BW.Print("stopped selling: the merchant refused an item.")
                    stop = true
                    break
                end
                sold, soldThisPass = sold + 1, soldThisPass + 1
                total = total + (item.sellPrice or 0) * (item.count or 1)
                if BW.ScrapOnce and BW.ScrapOnce(item.itemID) then
                    soldOnce[item.itemID] = true
                end
            else
                moved = moved + 1
            end
        end
        -- Nothing left to find, nothing moved under us, or the cap is spent: no point looking again.
        if stop or soldThisPass == #plan.sell or sold >= MAX_PER_VISIT then break end
    end

    ForgetSoldOnce(soldOnce)

    if sold > 0 then
        BW.Print("sold %d junk %s for %s.", sold, sold == 1 and "stack" or "stacks", BW.Coin(total))
        return sold, total
    end

    -- Selling nothing used to be silent, and silence is the one answer that cannot be acted on: it
    -- reads the same whether BagWarden refused every stack or never ran at all. So when the player
    -- has put something on the scrap list and it is still in their bags unsold, say which stack and
    -- why - once, at the merchant, where they can do something about it.
    -- Only for SCRAP. A grey held back is BagWarden being careful on its own initiative and the
    -- player never asked about it; a scrapped item is a standing instruction we are not carrying
    -- out, and not saying so is the addon quietly disagreeing with them.
    -- `plan` here is the LAST pass's, which is the one that describes the bags as they now are.
    for _, entry in ipairs(plan and plan.held or {}) do
        if entry.scrapped then
            BW.Print("didn't sell %s: %s.", entry.item.link or entry.item.name or "?", entry.why)
            BW.Print("'/bagw sell' lists the rest.")
            break
        end
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
