-- BagWarden - what a bag slot is worth, and what to do next.
-- The slot value is normally the whole stack's sell value (5 x 5s = 25s). The stack you are WELL ON
-- THE WAY to filling is judged by what it will be worth full instead, so a 15/20 stack of decent
-- drops isn't binned to save a slot you'd refill in two minutes.
-- That only applies from half a stack upwards. Below that the rest is guesswork: 2 milk out of a
-- possible 20 is worth 12c, not 120c, and shouldn't outrank a grey that really does sell for 65c.
-- It also applies to at most ONE stack of an item, the one loot actually goes into.
local ADDON, BW = ...

-- How full a stack must already be before we count it as full.
local NEARLY = 0.5

--- What this stack would really fetch at a vendor. This is the number we show the player.
function BW.StackValue(item)
    return (item.sellPrice or 0) * (item.count or 1)
end

--- Value used for RANKING the slot, and whether that value is the potential one. `filling` says
--- this is the stack loot is going into; only that one can be judged by what it will be worth.
function BW.SlotValue(item, filling)
    local price = item.sellPrice or 0
    local count = item.count or 1
    local maxStack = item.maxStack or 1
    if filling and maxStack > 1 and count < maxStack and count >= maxStack * NEARLY
        and BW.RecentlyLooted(item.itemID) then
        return price * maxStack, true
    end
    return price * count, false
end

-- A provider can say how much the player would miss an item, with Tier(itemID): "spare" for the
-- conjured bread they can make more of, "useful" for the food their macros use, "critical" for buff
-- food and, for a mana class, water. Only "critical" changes the order, and only as a last resort.
--
-- We tried sorting the things that ASK behind everything that doesn't, and it was wrong: it meant
-- destroying 93c of gyrostabilizers to avoid asking one question about 1c of cheese. Asking is a
-- question, not a ranking. So value decides, across the lot, and the only thing held back is the
-- item you'd actually mourn.
-- Item class 7 is Trade Goods: ore, stone, cloth, leather, herbs, parts, the things people buy from
-- each other. Their vendor price is the number that means LEAST about them, while a grey item's
-- vendor price is exactly what it is worth, because vendoring is all a grey is for. So we rank in
-- three groups, and only inside a group does price decide:
--   1. everything ordinary - greys, worn-out whites, food you can rebuy;
--   2. crafting reagents and trade goods, whose worth isn't on the price tag;
--   3. whatever a provider calls "critical", which is only ever offered when nothing else is left.
-- This is what makes a 2s40 grey knife go before a 16c Murloc Eye while a 1c belt still goes before
-- a 97c grey hammer: the belt is ordinary, the eye is not.
-- And ahead of all of it: anything a provider calls "spare", which is its way of saying somebody
-- can replace this for nothing - a mage's conjured bread, or a surplus stack. Losing one of those
-- costs less than losing any amount of money, so they go first.
-- All of this needs a provider to speak up. With no AutoFeed installed nothing is ever "spare" or
-- "critical", and the order is simply ordinary items, then trade goods, by price.
local CLASS_TRADE_GOODS = 7

local function Rank(entry)
    if entry.tier == "spare" then return 0 end
    if entry.tier == "critical" then return 3 end
    local item = entry.item
    if item.craftingReagent or item.classID == CLASS_TRADE_GOODS then return 2 end
    return 1
end

--- Sort: by group first (see Rank), then the slot that costs least, whatever colour the item is and
--- whether or not it asks. Ties go to the one we looted longest ago.
local function Cheaper(a, b)
    local ra, rb = Rank(a), Rank(b)
    if ra ~= rb then return ra < rb end
    if a.value ~= b.value then return a.value < b.value end
    local ta, tb = BW.lootSeen[a.item.itemID] or 0, BW.lootSeen[b.item.itemID] or 0
    if ta ~= tb then return ta < tb end
    return (a.item.name or "") < (b.item.name or "")
end

--- What BagWarden would do next, and why everything else stays.
--- Returns { action = "delete"|"confirm"|nil, ... , kept = { {item, reason}, ... } }.
--- Merging part-stacks isn't ours to do: Blizzard's sort button, right next to ours, already does it.
function BW.Plan(items)
    items = items or BW.items or {}
    local plan = { free = BW.FreeSlots(), total = BW.TotalSlots(), candidates = {} }

    -- Loot only ever goes into one stack of an item: the fullest one that isn't full yet. That is
    -- the only stack the potential-value rule may apply to.
    local filling = {}
    for _, item in ipairs(items) do
        local maxStack = item.maxStack or 1
        if maxStack > 1 and item.count < maxStack then
            local best = filling[item.itemID]
            if not best or item.count > best.count then filling[item.itemID] = item end
        end
    end

    -- Two stacks of the same item free exactly one slot each, so the smaller one always costs less.
    -- Only the smallest stack of an item is ever a candidate; the rest can't be better answers, and
    -- leaving them out also keeps the sort a plain comparison of different items.
    local smallest = {}
    for _, item in ipairs(items) do
        local strength, reason, mustAsk = BW.KeepReason(item)
        -- A hard keep is simply not a candidate. What's kept and why is shown on the settings page,
        -- which asks KeepReason itself when the page is opened.
        if strength ~= "hard" then
            local best = smallest[item.itemID]
            if not best or item.count < best.item.count then
                local value, potential = BW.SlotValue(item, filling[item.itemID] == item)
                -- Colour decides whether we ASK, not what comes first: a soft keep (a reagent,
                -- something you use, or one some quest has wanted) goes through the confirm popup.
                smallest[item.itemID] = {
                    item = item, value = value, potential = potential, reason = reason,
                    real = BW.StackValue(item), confirm = strength == "soft" or nil,
                    tier = BW.SynergyTier and BW.SynergyTier(item.itemID) or nil,
                    -- Set only for an item another addon unlocked: Ctrl can't skip its question.
                    mustAsk = mustAsk or nil,
                }
            end
        end
    end
    for _, entry in pairs(smallest) do plan.candidates[#plan.candidates + 1] = entry end
    table.sort(plan.candidates, Cheaper)

    local next_ = plan.candidates[1]
    if next_ then
        plan.action = next_.confirm and "confirm" or "delete"
        plan.target = next_
    end
    return plan
end

--- One line describing a candidate, for the tooltip and chat.
--- Always the REAL value: what the stack fetches at a vendor today. A number the player can't
--- reconcile with the merchant window is a number that costs us their trust.
function BW.Describe(entry)
    if not entry then return nil end
    local text = string.format("%dx %s - %s", entry.item.count, entry.item.name or "?",
        BW.Money(entry.real or entry.value))
    if entry.potential then text = text .. " (nearly a full stack)" end
    return text
end
