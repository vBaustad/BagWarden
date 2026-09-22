-- BagWarden - what must never be deleted.
-- Protection comes in two strengths:
--   "hard": BagWarden will not delete it, full stop, and says why in the tooltip.
--   "soft": BagWarden never picks it by itself; it can only go through the confirm popup.
-- When in doubt we keep the item. A wrong keep costs a bag slot; a wrong delete can cost a quest.
local ADDON, BW = ...

local POOR = Enum.ItemQuality and Enum.ItemQuality.Poor or 0
local COMMON = Enum.ItemQuality and Enum.ItemQuality.Common or 1
local UNCOMMON = Enum.ItemQuality and Enum.ItemQuality.Uncommon or 2

local CLASS_QUEST = 12          -- item class "Quest"
local BIND_QUEST = 4            -- bindType "Quest"

-- Other addons can add a keep rule: fn(item) -> reason text, or nil. Used by the YippYapp
-- synergies (Skillwright reagents, AutoFeed food, Guildhall listings).
BW.protectors = {}

--- The item's own tooltip, as a last check for "Quest Item" / "This Item Begins a Quest" on items
--- whose flags we couldn't read. Cheap enough for the handful of stacks we rank.
local function TooltipSaysQuest(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
    local data = C_TooltipInfo.GetBagItem(bag, slot)
    if not (data and data.lines) then return false end
    local questItem, startsQuest = ITEM_BIND_QUEST or "Quest Item", ITEM_STARTS_QUEST or "This Item Begins a Quest"
    for _, line in ipairs(data.lines) do
        local text = line and line.leftText
        if type(text) == "string" and (text == questItem or text == startsQuest) then return true end
    end
    return false
end

--- Why this stack is kept: "hard"/"soft", a short reason, or nil when it may be deleted.
--- Layers, strongest first.
function BW.KeepReason(item)
    if not item then return "hard", "unknown item" end

    -- 1. The live quest log. Exact, and it covers plain trade goods used as turn-ins.
    local quest = BW.QuestWanting(item.name)
    if quest then return "hard", "needed for " .. quest end

    -- 2. The item's own quest flags.
    if item.isQuestItem or item.questID then return "hard", "quest item" end
    if item.classID == CLASS_QUEST then return "hard", "quest item" end
    if item.bindType == BIND_QUEST then return "hard", "quest item" end
    if TooltipSaysQuest(item.bag, item.slot) then return "hard", "quest item" end

    -- 3. Your own never-delete list.
    if BW.IsIgnored(item.itemID) then return "hard", "on your never-delete list" end

    -- 4. Quality and value.
    if (item.quality or 0) >= UNCOMMON then return "hard", "green or better" end
    if item.hasNoValue or (item.sellPrice or 0) <= 0 then return "hard", "can't be sold" end
    if item.locked then return "hard", "in use" end

    -- 5. What the other YippYapp addons say.
    for _, fn in ipairs(BW.protectors) do
        local ok, reason = pcall(fn, item)
        if ok and reason then return "hard", reason end
    end

    -- 6. Soft: an item some quest has asked for before, on this account.
    local learned = BW.LearnedFor(item.name)
    if learned then
        return "soft", type(learned) == "string" and ("used by: " .. learned) or "some quests use this item"
    end

    -- 7. Soft: white items always ask first.
    if (item.quality or 0) >= COMMON then return "soft", "not junk" end

    -- Grey, sellable, no quest: this is what BagWarden is for.
    if (item.quality or 0) == POOR then return nil, nil end
    return "soft", "not junk"
end
