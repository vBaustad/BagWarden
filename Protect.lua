-- BagWarden - what must never be deleted.
-- Protection comes in two strengths:
--   "hard": BagWarden will not delete it, full stop, and says why in the tooltip.
--   "soft": BagWarden never picks it by itself; it can only go through the confirm popup.
-- When in doubt we keep the item. A wrong keep costs a bag slot; a wrong delete can cost a quest.
local ADDON, BW = ...

local UNCOMMON = Enum.ItemQuality and Enum.ItemQuality.Uncommon or 2

local CLASS_QUEST = 12          -- item class "Quest"
local CLASS_CONSUMABLE = 0      -- item class "Consumable": food, drink, potions, bandages, scrolls
local BIND_QUEST = 4            -- bindType "Quest"

-- Other addons can add a keep rule: fn(item) -> reason text, or nil. Used by the YippYapp
-- synergies (Skillwright reagents, AutoFeed food, Guildhall listings).
BW.protectors = {}

--- The item's own tooltip, as a last check for "Quest Item" / "This Item Begins a Quest" on items
--- whose flags we couldn't read. Returns true, false, or NIL when the tooltip couldn't be read -
--- and nil means keep, because a tooltip we can't read may be the one that says "Quest Item".
local function TooltipSaysQuest(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or not (data and data.lines) then return nil end
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

    -- 0. Everything below reads something. Where a read can fail, the failure keeps the item:
    -- details the client hasn't sent, or a quest log we couldn't walk, mean we know too little.
    if item.incomplete or not item.name then return "hard", "still loading" end
    if not BW.questScanOk then return "hard", "quest check unavailable" end

    -- 1. The live quest log. Exact, and it covers plain trade goods used as turn-ins.
    local quest = BW.QuestWanting(item.name)
    if quest then return "hard", "needed for " .. quest end

    -- 2. The item's own quest flags.
    if item.isQuestItem or item.questID then return "hard", "quest item" end
    if item.classID == CLASS_QUEST then return "hard", "quest item" end
    if item.bindType == BIND_QUEST then return "hard", "quest item" end
    local tooltipQuest = TooltipSaysQuest(item.bag, item.slot)
    if tooltipQuest == nil then return "hard", "can't read its tooltip" end
    if tooltipQuest then return "hard", "quest item" end

    -- 3. Your own never-delete list.
    if BW.IsIgnored(item.itemID) then return "hard", "on your never-delete list" end

    -- 4. Quality and value. Green is the highest BagWarden will ever touch, and only when the player
    -- has said so; blue and better are never deletable, whatever the settings say.
    local quality = item.quality or 0
    if quality > UNCOMMON then return "hard", "too good to delete" end
    if quality == UNCOMMON and not (BW.db and BW.db.allowGreen) then return "hard", "green or better" end
    if item.hasNoValue or (item.sellPrice or 0) <= 0 then return "hard", "can't be sold" end
    if item.locked then return "hard", "in use" end

    -- 5. Profession gear, and what the other YippYapp addons say. A rule that errors keeps the item:
    -- we asked it a question and got no answer. These come BEFORE our own reagent rule on purpose:
    -- a provider knows why it wants the item ("needed for your route") and we only know that it's a
    -- reagent, so the better reason wins when both would answer.
    for _, fn in ipairs(BW.protectors) do
        local ok, reason = pcall(fn, item)
        if not ok then return "hard", "a keep rule failed" end
        if reason then return "hard", reason end
    end

    -- 5b. Crafting reagents, three ways (BW.db.reagentKeep):
    --   "all"  - every reagent is kept.
    --   "mine" - only the ones your own professions use. Skillwright's provider claims those in
    --            step 5 above, so anything reaching here is NOT one of yours and falls through to
    --            the ask tier. But without Skillwright published we cannot tell whose a reagent is,
    --            and guessing "someone else's" would delete your ore. So with no provider, keep all.
    --   "none" - no special treatment.
    if item.craftingReagent then
        local mode = (BW.db and BW.db.reagentKeep) or "mine"
        if mode == "all" then
            return "hard", "crafting reagent"
        elseif mode == "mine" and not (BW.ProviderPresent and BW.ProviderPresent("SkillwrightReagents")) then
            return "hard", "crafting reagent"
        end
    end

    -- 6. Soft: an item some quest has asked for before, on this account, or one of the trade goods
    -- classic quests are known to want (by item ID, so it holds in every language).
    local learned = BW.LearnedFor(item.name)
    if learned then
        return "soft", type(learned) == "string" and ("used by: " .. learned) or "some quests use this item"
    end
    if BW.IsSeededQuestItem(item.itemID) then return "soft", "some quests use this item" end

    -- 7. Soft: things a white item can be that you'd miss. Being white is not itself a reason to
    -- ask - a worn-out white belt worth a copper is junk, and the tooltip already names what the
    -- click deletes - but these two are worth a question:
    --   * crafting reagents (the green "Crafting Reagent" line; isCraftingReagent from GetItemInfo,
    --     so it needs no tooltip and works in every language);
    --   * consumables: food, water, potions, bandages, scrolls. They sell for almost nothing, so
    --     they sort to the front of the queue, and they're exactly what you miss out in the field.
    if item.craftingReagent then return "soft", "crafting reagent" end
    if item.classID == CLASS_CONSUMABLE then return "soft", "something you use" end
    -- Green only gets here at all when the player allowed it, and then it always asks.
    if quality >= UNCOMMON then return "soft", "green - you allowed these" end

    -- 8. Soft: whatever the player asked to be asked about. "askFrom" is a quality: POOR means ask
    -- about everything, COMMON means ask about white items too, and UNCOMMON (the default) means
    -- don't ask on quality alone. Green is handled above, because it always asks.
    local askFrom = BW.db and BW.db.askFrom or UNCOMMON
    if (item.quality or 0) >= askFrom then return "soft", "you asked to be asked first" end

    -- Sellable, no quest, not a reagent: this is what BagWarden is for.
    return nil, nil
end
