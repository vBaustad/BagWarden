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

-- Within the things that ASK, some are far more precious than others. A provider can say so with
-- Tier(itemID): the conjured bread you can make more of is "spare", the food and drink your macros
-- use is "useful", buff food (and water, for a mana class) is "critical". Items nobody has an
-- opinion on sit between useful and critical: we know less about them than the provider does about
-- its own, but a stranger's food is still not someone's +5% XP meal.
local TIER_ORDER = { spare = 1, useful = 2, critical = 4 }
local NO_OPINION = 3

local function Precious(entry)
    return TIER_ORDER[entry.tier] or NO_OPINION
end

--- Sort, in two tiers.
--- Tier one is everything BagWarden can delete without asking: plain stuff whose only use is the
--- money it sells for. Tier two is everything that asks - reagents, food, drink, things quests have
--- wanted. A 2c Rough Stone is cheaper than a 97c hammer, but price is not the same as usefulness,
--- and offering the stone first is technically right and practically wrong. So nothing you might
--- want is offered while plain junk is still there.
--- Inside each tier: cheapest slot first, whatever colour it is - a 97c grey must not go before a
--- 1c white just because grey means junk. Ties go to the one we looted longest ago.
local function Cheaper(a, b)
    if (a.confirm or false) ~= (b.confirm or false) then return not a.confirm end
    -- Only inside the ask tier, where the provider opinions live.
    if a.confirm and b.confirm then
        local pa, pb = Precious(a), Precious(b)
        if pa ~= pb then return pa < pb end
    end
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
        local strength, reason = BW.KeepReason(item)
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
