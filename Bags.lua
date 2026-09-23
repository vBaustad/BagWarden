-- BagWarden - reading the bags.
-- One place that turns the four (or five) bags into a plain list of stacks, so the rest of the addon
-- never talks to C_Container directly.
local ADDON, BW = ...

local FIRST_BAG = Enum.BagIndex and Enum.BagIndex.Backpack or 0
local LAST_BAG = FIRST_BAG + (NUM_BAG_SLOTS or 4)

-- What GetItemInfo told us about an item, kept per itemID: the same query ran once per slot on
-- every scan before, and none of these fields change while we play.
BW.itemInfo = {}

--- Name, quality, stack size, sell price and class for an item, or nil while the client is still
--- fetching it. A nil answer is what makes an item "incomplete", and incomplete items are kept.
function BW.ItemInfo(link, itemID)
    local cached = BW.itemInfo[itemID]
    if cached then return cached end
    local name, _, quality, _, _, _, _, maxStack, _, _, sellPrice, classID, subclassID, bindType =
        C_Item.GetItemInfo(link or itemID)
    if not name then return nil end
    cached = {
        name = name, quality = quality, maxStack = maxStack or 1, sellPrice = sellPrice or 0,
        classID = classID, subclassID = subclassID, bindType = bindType,
    }
    BW.itemInfo[itemID] = cached
    return cached
end

--- Forget what we cached for an item the client has just finished loading.
function BW.ForgetItemInfo(itemID)
    if itemID then
        BW.itemInfo[itemID] = nil
        if BW.professionCache then BW.professionCache[itemID] = nil end
    else
        wipe(BW.itemInfo)
        if BW.professionCache then wipe(BW.professionCache) end
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
                    locked = info.isLocked,
                    hasNoValue = info.hasNoValue,
                    sellPrice = details and details.sellPrice or 0,
                    maxStack = details and details.maxStack or 1,
                    classID = details and details.classID,
                    subclassID = details and details.subclassID,
                    bindType = details and details.bindType,
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

--- Are two part-stacks of the same item lying around? BagWarden doesn't join them - Blizzard's sort
--- button does, and it sits right next to ours - but the tooltip mentions it when it's worth doing.
function BW.HasPartialStacks(items)
    local partial = {}
    for _, item in ipairs(items or {}) do
        if (item.maxStack or 1) > 1 and item.count < item.maxStack then
            if partial[item.itemID] then return true end
            partial[item.itemID] = true
        end
    end
    return false
end

--- Names are compared case- and space-insensitively, and always in full: "Wolf Meat" must never
--- match "Tough Wolf Meat".
function BW.NameKey(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    return name ~= "" and name or nil
end
