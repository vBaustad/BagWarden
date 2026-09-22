-- BagWarden - profession gear is never junk.
-- Two different things are protected here: the TOOLS a profession needs (mining pick, fishing pole,
-- enchanting rod, spanner) and anything that GIVES profession skill or teaches a recipe. Both are
-- worked out from the item's class and subclass first, which is language-independent, and only then
-- from the tooltip text, which is cached per item so the scan happens once.
local ADDON, BW = ...

-- Item classes and subclasses, read out of the Forever item data (build 69893):
--   2/14  Weapon > Miscellaneous: mining pick, blacksmith hammer, skinning knife, arclight spanner
--   2/20  Weapon > Fishing Pole
--   7/12  Trade Goods > Enchanting rods (Runed Copper Rod ... Arcanite Rod)
--   9/*   Recipe: every recipe, pattern, plan, schematic, formula and blueprint
local CLASS_WEAPON, CLASS_TRADE_GOODS, CLASS_RECIPE = 2, 7, 9
local SUB_WEAPON_MISC, SUB_FISHING_POLE, SUB_ENCHANTING_ROD = 14, 20, 12

-- Tools the item classes don't catch: they sit in classes shared with ordinary goods, so they're
-- listed by ID. Philosopher's Stone is armour (a trinket), the Micro-Adjustor is a trade good part.
local TOOL_IDS = {
    [9149] = true,      -- Philosopher's Stone
    [13503] = true,     -- Alchemist's Stone
    [10498] = true,     -- Gyromatic Micro-Adjustor
    [5956] = true,      -- Blacksmith Hammer
    [2901] = true,      -- Mining Pick
    [7005] = true,      -- Skinning Knife
    [6219] = true,      -- Arclight Spanner
    [6218] = true,      -- Runed Copper Rod
}

-- Backup by name, for anything the data classes oddly.
local TOOL_NAMES = {
    ["mining pick"] = true, ["skinning knife"] = true, ["blacksmith hammer"] = true,
    ["arclight spanner"] = true, ["gyromatic micro-adjustor"] = true, ["jeweler's kit"] = true,
    ["philosopher's stone"] = true, ["alchemist's stone"] = true, ["flint and tinder"] = true,
    ["simple fishing pole"] = true, ["fishing pole"] = true, ["blacksmithing hammer"] = true,
}

local PROFESSIONS = {
    "Mining", "Herbalism", "Skinning", "Fishing", "Cooking", "First Aid", "Blacksmithing",
    "Leatherworking", "Tailoring", "Engineering", "Alchemy", "Enchanting", "Jewelcrafting",
    "Inscription", "Lockpicking", "Poisons", "Riding",
}

BW.professionCache = {}     -- [itemID] = reason string, or false for "nothing to do with professions"

--- The profession reason from the item's own class, or nil.
local function ByClass(item)
    if TOOL_IDS[item.itemID] then return "profession tool" end
    if item.name and TOOL_NAMES[BW.NameKey(item.name)] then return "profession tool" end
    if item.classID == CLASS_RECIPE then return "recipe" end
    if item.classID == CLASS_WEAPON then
        if item.subclassID == SUB_FISHING_POLE then return "fishing pole" end
        if item.subclassID == SUB_WEAPON_MISC then return "profession tool" end
    end
    if item.classID == CLASS_TRADE_GOODS and item.subclassID == SUB_ENCHANTING_ROD then
        return "enchanting rod"
    end
    return nil
end

--- The profession reason from the tooltip text: "+5 Mining", "Requires Engineering", "Teaches you...".
--- `lines` can be passed in for the smoke test; normally they're read from the item in the bag.
function BW.ProfessionTooltipReason(bag, slot, lines)
    if not lines then
        if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return nil end
        local data = C_TooltipInfo.GetBagItem(bag, slot)
        if not (data and data.lines) then return nil end
        lines = {}
        for _, line in ipairs(data.lines) do
            if type(line.leftText) == "string" then lines[#lines + 1] = line.leftText end
        end
    end
    for _, text in ipairs(lines) do
        if text:find("^Teaches you") then return "recipe" end
        for _, profession in ipairs(PROFESSIONS) do
            -- "+5 Mining", "Equip: +3 Fishing"
            if text:find("%+%s*%d+%s+" .. profession) then return "gives profession skill" end
            if text:find("Requires%s+" .. profession) then return "needs " .. profession end
        end
    end
    return nil
end

--- Why this item counts as profession gear, or nil. Cached per item, since neither the class nor
--- the tooltip text changes while we play.
function BW.ProfessionReason(item)
    if not (BW.db and BW.db.protectProfession) then return nil end
    if not item or not item.itemID then return nil end
    local cached = BW.professionCache[item.itemID]
    if cached ~= nil then return cached or nil end

    local reason = ByClass(item) or BW.ProfessionTooltipReason(item.bag, item.slot)
    BW.professionCache[item.itemID] = reason or false
    return reason
end

-- Protect.lua asks every registered rule; this is one of them.
table.insert(BW.protectors, BW.ProfessionReason)

-- ---------------------------------------------------------------------------
-- /bagw test - the profession layer
-- ---------------------------------------------------------------------------
function BW.TestProfessions()
    local cases = {
        { name = "Mining Pick", item = { itemID = 2901, name = "Mining Pick", classID = 2, subclassID = 14 } },
        { name = "Fishing Pole", item = { itemID = 6256, name = "Fishing Pole", classID = 2, subclassID = 20 } },
        { name = "Runed Copper Rod", item = { itemID = 6218, name = "Runed Copper Rod", classID = 7, subclassID = 12 } },
        { name = "Recipe (any)", item = { itemID = 4607, name = "Recipe: Goretusk Liver Pie", classID = 9, subclassID = 0 } },
        { name = "Plain grey", item = { itemID = 1372, name = "Ragged Cloak", classID = 4, subclassID = 1 } },
    }
    for _, case in ipairs(cases) do
        -- Work from the class alone here: these test items aren't in the bags, so there's no tooltip.
        BW.professionCache[case.item.itemID] = nil
        local reason = BW.db.protectProfession and ByClass(case.item) or nil
        BW.Print("profession: %s -> %s", case.name, reason or "not protected")
    end
    -- The tooltip route, with mocked lines instead of a real item.
    local mocks = {
        { "+5 Mining", { "Mithril Spurs", "Equip: +5 Mining" } },
        { "+3 Fishing", { "Lucky Fishing Hat", "Equip: +3 Fishing" } },
        { "Requires Engineering", { "Gyro-Balanced Khorium Destroyer", "Requires Engineering (350)" } },
        { "Teaches you", { "Pattern: Linen Bag", "Teaches you how to sew a Linen Bag." } },
        { "nothing", { "Ragged Cloak", "Cloth", "Sell Price: 2c" } },
    }
    for _, mock in ipairs(mocks) do
        BW.Print("profession tooltip: %s -> %s", mock[1],
            BW.ProfessionTooltipReason(nil, nil, mock[2]) or "not protected")
    end
end
