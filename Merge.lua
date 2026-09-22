-- BagWarden - merging partial stacks.
-- Free a slot for nothing: two half stacks of the same item become one. This is always tried before
-- anything is deleted. Moving items is not restricted for addons, so this part needs no confirming.
local ADDON, BW = ...

--- The best merge available: the two smallest partial stacks of the same item, so one slot empties.
--- Returns { from = item, to = item, name = ... } or nil.
function BW.FindMerge(items)
    local byItem = {}
    for _, item in ipairs(items or {}) do
        if (item.maxStack or 1) > 1 and item.count < item.maxStack and not item.locked then
            local list = byItem[item.itemID]
            if not list then list = {}; byItem[item.itemID] = list end
            list[#list + 1] = item
        end
    end
    local best
    for _, list in pairs(byItem) do
        if #list >= 2 then
            table.sort(list, function(a, b) return a.count < b.count end)
            local from, to = list[1], list[2]
            -- Prefer the merge that frees a slot with the fewest items moved.
            if not best or from.count < best.from.count then
                best = { from = from, to = to, name = from.name }
            end
        end
    end
    return best
end

--- Move one partial stack onto another. Picking an item up and dropping it needs no hardware event,
--- but it does need an empty cursor, so we bail out if something is already on it.
function BW.DoMerge(merge)
    if not merge then return false end
    if CursorHasItem() then
        BW.Print("your cursor is holding something - drop it first.")
        return false
    end
    if InCombatLockdown() then
        BW.Print("not in combat.")
        return false
    end
    C_Container.PickupContainerItem(merge.from.bag, merge.from.slot)
    if not CursorHasItem() then
        BW.Debug("merge: nothing picked up from %d/%d", merge.from.bag, merge.from.slot)
        return false
    end
    C_Container.PickupContainerItem(merge.to.bag, merge.to.slot)
    if CursorHasItem() then ClearCursor() end
    return true
end
