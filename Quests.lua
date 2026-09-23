-- BagWarden - knowing which items a quest wants.
-- Many quest turn-ins are ordinary white trade goods with no "Quest Item" tag (Linen Cloth, Tough
-- Wolf Meat), so the item's own flags are never enough. Two sources feed this file:
--   * the LIVE quest log, which is exact and protects hard;
--   * an account-wide LEARNED list of every item we have ever seen a quest ask for, which protects
--     softly (BagWarden won't pick it by itself; you can still confirm it).
-- Quest objectives carry no item ID, only text like "Tough Wolf Meat: 3/8", so both work by name.
local ADDON, BW = ...

BW.questWanted = {}     -- [name key] = quest title, from the quest log right now
-- False until a quest-log scan has actually run. Nothing is ever deleted before it has: without the
-- quest log we can't tell a turn-in trade good from junk (see BW.KeepReason).
BW.questScanOk = false

-- Items classic quests ask for that look like plain trade goods. Small on purpose: the learned list
-- does the real work, and this only covers a new character's first hours.
local SEED = {
    "linen cloth", "wool cloth", "silk cloth", "mageweave cloth", "runecloth",
    "tough wolf meat", "stringy wolf meat", "chunk of boar meat", "boar meat", "lean wolf flank",
    "small egg", "bear meat", "crag boar rib", "coyote meat", "crawler meat", "murloc eye",
    "light leather", "medium leather", "ruined pelt", "light hide", "small spider leg",
    "copper bar", "rough stone", "coarse stone", "kodo horn", "bloodscalp ear",
}

--- "Tough Wolf Meat: 3/8" -> "tough wolf meat". Objective text always ends in the counter, in every
--- locale, so only that tail is cut; nothing else is guessed from the text.
local function ObjectiveName(text)
    if type(text) ~= "string" then return nil end
    local name = text:gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")
    return BW.NameKey(name)
end

-- ---------------------------------------------------------------------------
-- The learned list (account-wide, saved)
-- ---------------------------------------------------------------------------
--- Remember that some quest wants this item. Learning is one-way: we never unlearn, because a quest
--- we did once can come back on another character.
function BW.Learn(name, questTitle)
    local key = BW.NameKey(name)
    if not key or not BW.db then return end
    if BW.db.learned[key] == nil then BW.Debug("learned %s (%s)", key, questTitle or "?") end
    BW.db.learned[key] = questTitle or BW.db.learned[key] or true
end

--- The quest that taught us this item, or nil.
function BW.LearnedFor(name)
    local key = BW.NameKey(name)
    if not key or not BW.db then return nil end
    local learned = BW.db.learned[key]
    if learned == nil then return nil end
    return type(learned) == "string" and learned or true
end

-- ---------------------------------------------------------------------------
-- The live quest log
-- ---------------------------------------------------------------------------
--- Walk the quest log and note every item objective. Runs on QUEST_LOG_UPDATE / ACCEPTED / REMOVED.
--- Finished objectives count too: the items stay needed until the quest is handed in.
function BW.ScanQuestLog()
    local wanted = {}
    -- Every call here is resolved before use: a client without one of them must fall back to the
    -- item's own flags and the learned list, never error out (see BW.Coin for why).
    local count, getInfo, getObjectives = C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetInfo,
        C_QuestLog.GetQuestObjectives
    if not (count and getInfo and getObjectives) then
        BW.questWanted, BW.questScanOk = wanted, false
        return
    end
    -- A scan that breaks half way through has seen only some of the quests, so it must not count as
    -- a scan: questScanOk stays false and everything is kept until a whole one succeeds.
    local ok, err = pcall(function()
        local entries = count() or 0
        for i = 1, entries do
            local info = getInfo(i)
            if info and not info.isHeader and info.questID then
                local title = info.title or ""
                local objectives = getObjectives(info.questID)
                if type(objectives) == "table" then
                    for _, objective in ipairs(objectives) do
                        if objective and (objective.type == "item" or objective.objectiveType == "item") then
                            local key = ObjectiveName(objective.text)
                            if key then
                                wanted[key] = title
                                BW.Learn(key, title)
                            end
                        end
                    end
                end
            end
        end
    end)
    BW.questWanted = wanted
    BW.questScanOk = ok
    if not ok then BW.Debug("quest scan failed: %s", tostring(err)) end
end

--- The quest in our log that wants this item, or nil.
function BW.QuestWanting(name)
    local key = BW.NameKey(name)
    return key and BW.questWanted[key] or nil
end

-- ---------------------------------------------------------------------------
-- Learning from an open quest giver
-- ---------------------------------------------------------------------------
--- QUEST_DETAIL (a quest we are only reading), QUEST_PROGRESS (what it wants from us) and
--- QUEST_COMPLETE (the rewards). Everything seen here goes into the learned list.
function BW.LearnFromQuestFrame(event)
    local title = GetTitleText and GetTitleText() or nil
    if event == "QUEST_PROGRESS" then
        -- The required items, which is where plain trade goods show up.
        for i = 1, (GetNumQuestItems and GetNumQuestItems() or 0) do
            local name = GetQuestItemInfo and GetQuestItemInfo("required", i)
            if name then BW.Learn(name, title) end
        end
    elseif event == "QUEST_DETAIL" then
        -- The objective text of a quest we haven't accepted: "Bring 8 Tough Wolf Meat to ...".
        -- Only the items it lists as required are read; free text is never parsed for names.
        for i = 1, (GetNumQuestItems and GetNumQuestItems() or 0) do
            local name = GetQuestItemInfo and GetQuestItemInfo("required", i)
            if name then BW.Learn(name, title) end
        end
    elseif event == "QUEST_COMPLETE" then
        for i = 1, (GetNumQuestChoices and GetNumQuestChoices() or 0) do
            local name = GetQuestItemInfo and GetQuestItemInfo("choice", i)
            if name then BW.Learn(name, title) end
        end
        for i = 1, (GetNumQuestRewards and GetNumQuestRewards() or 0) do
            local name = GetQuestItemInfo and GetQuestItemInfo("reward", i)
            if name then BW.Learn(name, title) end
        end
    end
end

--- Fill the seed list into a fresh database, once.
function BW.SeedLearned()
    if not BW.db or BW.db.seeded then return end
    for _, name in ipairs(SEED) do
        if BW.db.learned[name] == nil then BW.db.learned[name] = true end
    end
    BW.db.seeded = true
end
