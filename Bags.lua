-- BagWarden - reading the bags.
-- One place that turns every bag you carry into a plain list of stacks, so the rest of the addon
-- never talks to C_Container directly.
local ADDON, BW = ...

local FIRST_BAG = Enum.BagIndex and Enum.BagIndex.Backpack or 0
-- NUM_TOTAL_EQUIPPED_BAG_SLOTS counts the reagent bag; NUM_BAG_SLOTS does not. Preferring the
-- first means a reagent bag is walked where one exists and nothing changes where the global is
-- missing - which matters, because whether Forever has a reagent bag at all is unconfirmed. The
-- same fallback chain ForeverDungeonJournal uses on this client.
--
-- An index with no bag in it simply answers 0 slots, so an extra turn of the loop costs one call.
local LAST_BAG = FIRST_BAG + (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)

--- Does this container only take one kind of thing - a quiver, an ammo pouch, a reagent bag?
--- Its free slots are not room for the stack you are holding, so they are not room at all as far
--- as "how full are my bags" is concerned. The family comes from GetContainerNumFreeSlots's second
--- return, which costs nothing extra: it is the call we were making anyway.
local function Specialised(bag)
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    return (family or 0) ~= 0
end

-- What GetItemInfo told us about an item, kept per itemID: the same query ran once per slot on
-- every scan before, and none of these fields change while we play.
BW.itemInfo = {}

--- Name, quality, stack size, sell price and class for an item, or nil while the client is still
--- fetching it. A nil answer is what makes an item "incomplete", and incomplete items are kept.
function BW.ItemInfo(link, itemID)
    local cached = BW.itemInfo[itemID]
    if cached then return cached end
    -- isCraftingReagent is the same flag that puts the green "Crafting Reagent" line on the
    -- tooltip, so we never have to read the tooltip text for it.
    local name, _, quality, _, _, _, _, maxStack, _, _, sellPrice, classID, subclassID, bindType,
        _, _, isCraftingReagent = C_Item.GetItemInfo(link or itemID)
    if not name then return nil end
    cached = {
        name = name, quality = quality, maxStack = maxStack or 1, sellPrice = sellPrice or 0,
        classID = classID, subclassID = subclassID, bindType = bindType,
        craftingReagent = isCraftingReagent and true or false,
    }
    BW.itemInfo[itemID] = cached
    return cached
end

--- Forget what we cached for an item the client has just finished loading.
function BW.ForgetItemInfo(itemID)
    if itemID then
        BW.itemInfo[itemID] = nil
        if BW.professionCache then BW.professionCache[itemID] = nil end
        if BW.questTooltipCache then BW.questTooltipCache[itemID] = nil end
    else
        wipe(BW.itemInfo)
        if BW.professionCache then wipe(BW.professionCache) end
        if BW.questTooltipCache then wipe(BW.questTooltipCache) end
    end
end

--- Every stack we carry: bag, slot, itemID, count, quality, name, link, sellPrice, maxStack,
--- classID, subclassID, bindType, hasNoValue, isQuestItem, questID (the item's own quest flags),
--- and `incomplete` when the client hadn't loaded the item's details yet.
function BW.ScanBags()
    local items = {}
    for bag = FIRST_BAG, LAST_BAG do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local details = BW.ItemInfo(info.hyperlink, info.itemID)
                local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
                items[#items + 1] = {
                    bag = bag,
                    slot = slot,
                    itemID = info.itemID,
                    count = info.stackCount or 1,
                    quality = info.quality or (details and details.quality) or 0,
                    name = (details and details.name) or info.itemName,
                    link = info.hyperlink,
                    icon = info.iconFileID,
                    locked = info.isLocked,
                    hasNoValue = info.hasNoValue,
                    sellPrice = details and details.sellPrice or 0,
                    maxStack = details and details.maxStack or 1,
                    classID = details and details.classID,
                    subclassID = details and details.subclassID,
                    bindType = details and details.bindType,
                    craftingReagent = details and details.craftingReagent or false,
                    -- The client hasn't sent this item's details yet: we know too little to judge it.
                    incomplete = details == nil,
                    isQuestItem = quest and quest.isQuestItem or false,
                    questID = quest and quest.questID or nil,
                }
            end
        end
    end
    return items
end

--- How many empty slots we have, counting only normal bags. A quiver only takes arrows and a
--- reagent bag only takes reagents, so neither is room for the thing in your hand.
---
--- Note what this does NOT do: it does not stop BagWarden deleting or selling what is INSIDE one.
--- An item in a reagent bag is still an item you own and can lose - it just is not free space.
function BW.FreeSlots()
    local free = 0
    for bag = FIRST_BAG, LAST_BAG do
        if not Specialised(bag) then
            free = free + (select(1, C_Container.GetContainerNumFreeSlots(bag)) or 0)
        end
    end
    return free
end

--- Total slots across those same bags - and "those same bags" has to mean the same thing it
--- means in FreeSlots, or the two numbers describe different sets.
---
--- They did not. FreeSlots has skipped specialised bags since it was written; this counted every
--- bag. Carry a 20-slot quiver and the tooltip said "4 free of 36", where 16 was the only number
--- that meant anything - a bug that needed no reagent bag to happen, and has been there all along.
function BW.TotalSlots()
    local total = 0
    for bag = FIRST_BAG, LAST_BAG do
        if not Specialised(bag) then
            total = total + (C_Container.GetContainerNumSlots(bag) or 0)
        end
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
