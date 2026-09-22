-- BagWarden - what a bag slot is worth, and what to do next.
-- The slot value is normally the whole stack's sell value (5 x 5s = 25s). A stack you are still
-- filling is judged by what it will be worth when full, so a half-done stack of good drops isn't
-- thrown away to save a slot you'd refill anyway.
local ADDON, BW = ...

--- Value of the slot this stack sits in, and whether that value is the potential one.
function BW.SlotValue(item)
    local price = item.sellPrice or 0
    local stackValue = price * (item.count or 1)
    local stackable = (item.maxStack or 1) > 1
    local full = (item.count or 1) >= (item.maxStack or 1)
    if stackable and not full and BW.RecentlyLooted(item.itemID) then
        return price * item.maxStack, true
    end
    return stackValue, false
end

--- Sort: cheapest slot first, and on a tie the one we looted longest ago.
local function Cheaper(a, b)
    if a.value ~= b.value then return a.value < b.value end
    local ta, tb = BW.lootSeen[a.item.itemID] or 0, BW.lootSeen[b.item.itemID] or 0
    if ta ~= tb then return ta < tb end
    return (a.item.name or "") < (b.item.name or "")
end

--- What BagWarden would do next, and why everything else stays.
--- Returns { action = "merge"|"delete"|"confirm"|nil, ... , kept = { {item, reason}, ... } }.
function BW.Plan(items)
    items = items or BW.items or {}
    local plan = { free = BW.FreeSlots(), total = BW.TotalSlots(), kept = {}, candidates = {} }

    -- 0. Merging partial stacks frees a slot at no cost, so it always comes first.
    local merge = BW.FindMerge(items)
    if merge then
        plan.action = "merge"
        plan.merge = merge
        plan.label = string.format("merge %s (%d + %d)", merge.name or "?", merge.from.count, merge.to.count)
    end

    local greys, whites = {}, {}
    for _, item in ipairs(items) do
        local strength, reason = BW.KeepReason(item)
        if strength == "hard" then
            plan.kept[#plan.kept + 1] = { item = item, reason = reason }
        else
            local value, potential = BW.SlotValue(item)
            local entry = { item = item, value = value, potential = potential, reason = reason }
            if strength == "soft" then
                entry.confirm = true
                whites[#whites + 1] = entry
            else
                greys[#greys + 1] = entry
            end
        end
    end
    table.sort(greys, Cheaper)
    table.sort(whites, Cheaper)

    -- 1. Greys first, then anything that needs confirming.
    for _, entry in ipairs(greys) do plan.candidates[#plan.candidates + 1] = entry end
    for _, entry in ipairs(whites) do plan.candidates[#plan.candidates + 1] = entry end

    local next_ = plan.candidates[1]
    if next_ and not plan.action then
        plan.action = next_.confirm and "confirm" or "delete"
        plan.target = next_
        plan.label = string.format("%dx %s - %s", next_.item.count, next_.item.name or "?", BW.Money(next_.value))
    elseif next_ then
        plan.target = next_        -- shown in the tooltip as what comes after the merge
    end
    return plan
end

--- One line describing a candidate, for the tooltip and chat.
function BW.Describe(entry)
    if not entry then return nil end
    local text = string.format("%dx %s - %s", entry.item.count, entry.item.name or "?", BW.Money(entry.value))
    if entry.potential then text = text .. " (still looting)" end
    return text
end
