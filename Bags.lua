-- BagWarden - reading the bags.
-- One place that turns the four (or five) bags into a plain list of stacks, so the rest of the addon
-- never talks to C_Container directly.
local ADDON, BW = ...

local FIRST_BAG = Enum.BagIndex and Enum.BagIndex.Backpack or 0
local LAST_BAG = FIRST_BAG + (NUM_BAG_SLOTS or 4)

--- Every stack we carry: bag, slot, itemID, count, quality, name, link, sellPrice, maxStack,
--- classID, bindType, hasNoValue, isQuestItem and questID (the item's own quest flags).
function BW.ScanBags()
    local items = {}
    for bag = FIRST_BAG, LAST_BAG do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local name, _, quality, _, _, _, _, maxStack, _, _, sellPrice, classID, subclassID, bindType =
                    C_Item.GetItemInfo(info.hyperlink or info.itemID)
                local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
                items[#items + 1] = {
                    bag = bag,
                    slot = slot,
                    itemID = info.itemID,
                    count = info.stackCount or 1,
                    quality = info.quality or quality or 0,
                    name = name or info.itemName,
                    link = info.hyperlink,
                    locked = info.isLocked,
                    hasNoValue = info.hasNoValue,
                    sellPrice = sellPrice or 0,
                    maxStack = maxStack or 1,
                    classID = classID,
                    subclassID = subclassID,
                    bindType = bindType,
                    isQuestItem = quest and quest.isQuestItem or false,
                    questID = quest and quest.questID or nil,
                }
            end
        end
    end
    return items
end

--- How many empty slots we have, counting only normal bags (a quiver only takes arrows).
function BW.FreeSlots()
    local free = 0
    for bag = FIRST_BAG, LAST_BAG do
        local n, family = C_Container.GetContainerNumFreeSlots(bag)
        if (family or 0) == 0 then free = free + (n or 0) end
    end
    return free
end

--- Total slots across those same bags.
function BW.TotalSlots()
    local total = 0
    for bag = FIRST_BAG, LAST_BAG do
        total = total + (C_Container.GetContainerNumSlots(bag) or 0)
    end
    return total
end

--- Names are compared case- and space-insensitively, and always in full: "Wolf Meat" must never
--- match "Tough Wolf Meat".
function BW.NameKey(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    return name ~= "" and name or nil
end
