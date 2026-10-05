-- BagWarden - the checks that run in game, from /bagw test or the shared /yippyapp test.
-- Split out of Button.lua, where they had grown to a third of the file while testing none of it:
-- nothing here touches the bag button's internals, so nothing here belongs next to them.
--
-- Every step is read-only. BW.testing is set for the duration and BW.DeleteStack refuses outright
-- while it is, so a step that reaches the delete path by mistake stops rather than destroying
-- something - see the first lines of BW.DeleteStack.
local ADDON, BW = ...
-- ---------------------------------------------------------------------------
-- /bagw test - one line per protection layer, so a change can be checked in game
-- ---------------------------------------------------------------------------
function BW.SmokeTest()
    BW.ScanQuestLog()
    BW.PlanNow()

    BW.Print("bags: %d stacks, %d of %d slots free", #BW.items, BW.FreeSlots(), BW.TotalSlots())

    local wanted = 0
    for _ in pairs(BW.questWanted) do wanted = wanted + 1 end
    BW.Print("quest log: %d item objectives", wanted)
    for name, title in pairs(BW.questWanted) do BW.Print("  %s -> %s", name, tostring(title)) end

    local learned = 0
    for _ in pairs(BW.db.learned) do learned = learned + 1 end
    BW.Print("learned list: %d items", learned)

    local hard, soft, free = 0, 0, 0
    for _, item in ipairs(BW.items) do
        local strength = BW.KeepReason(item)
        if strength == "hard" then hard = hard + 1
        elseif strength == "soft" then soft = soft + 1
        else free = free + 1 end
    end
    BW.Print("protection: %d kept, %d ask first, %d deletable", hard, soft, free)

    if BW.plan.target then
        BW.Print("next: %s [%s]", BW.Describe(BW.plan.target), BW.plan.action)
    else
        BW.Print("next: nothing")
    end

    BW.TestStacks()
    BW.TestOrdering()
    BW.TestProfessions()
    BW.TestSynergies()
    BW.TestTooltip()
    BW.TestBar()
end

--- The same checks as /bagw test, for LibForever's /yippyapp test: quiet, and guaranteed harmless.
--- Returns ok, message. Three things make "harmless" true rather than hoped for:
---   * BW.testing is set for the duration, and DeleteStack and SellGreys refuse outright while it is;
---   * the deletion log's length is compared before and after, so a delete that somehow happened
---     would fail the test rather than pass quietly;
---   * the flag is cleared whether the checks pass, fail or error.
function BW.SelfTest()
    local logBefore = (BW.db and BW.db.log) and #BW.db.log or 0
    local slotsBefore = BW.FreeSlots()

    -- Collect the lines instead of printing them: /yippyapp test runs six addons.
    local lines, realPrint = {}, BW.Print
    BW.Print = function(fmt, ...)
        lines[#lines + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
    end
    BW.testing = true
    local ok, err = pcall(BW.SmokeTest)
    BW.testing = nil
    BW.Print = realPrint

    if not ok then return false, tostring(err) end
    local logAfter = (BW.db and BW.db.log) and #BW.db.log or 0
    if logAfter ~= logBefore then return false, "the self test deleted something - that must never happen" end
    if BW.FreeSlots() ~= slotsBefore then return false, "the bags changed during the self test" end
    for _, line in ipairs(lines) do
        if line:find("FAILED") then return false, line end
    end
    return true, string.format("%d checks, nothing deleted", #lines)
end

--- The six cases the ordering rules were written for, each one a real screenshot. Run them against
--- the live comparator so a future "improvement" has to face them.
function BW.TestOrdering()
    -- Stand in for a provider: the test items carry the verdict a live AutoFeed would give.
    local realTier = BW.SynergyTier
    BW.SynergyTier = function(itemID)
        for _, item in ipairs(BW.testItems or {}) do
            if item.itemID == itemID then return item.tier end
        end
        return nil
    end
    local function pick(label, items)
        BW.testItems = items
        local plan = BW.Plan(items)
        local target = plan.target
        BW.Print("order (%s): %s", label,
            target and string.format("%dx %s, %s", target.item.count, target.item.name,
                BW.Coin(target.real)) or "nothing")
    end
    local function stack(id, name, count, price, quality, extra)
        local it = { bag = 0, slot = id, itemID = id, name = name, count = count, sellPrice = price,
                     quality = quality, maxStack = 20 }
        for key, value in pairs(extra or {}) do it[key] = value end
        return it
    end
    pick("1c belt before 97c grey", {
        stack(1, "Rustic Belt", 1, 1, 1, { maxStack = 1 }),
        stack(2, "Cracked Sledge", 1, 97, 0, { maxStack = 1 }) })
    pick("2 milk before 65c grey", {
        stack(3, "Milk", 2, 6, 1, { classID = 0 }),
        stack(2, "Ragged Cloak", 1, 65, 0, { maxStack = 1 }) })
    pick("13 before 20 of one item", {
        stack(4, "Boar Meat", 20, 6, 1, { classID = 0 }),
        { bag = 0, slot = 9, itemID = 4, name = "Boar Meat", count = 13, sellPrice = 6, quality = 1,
          maxStack = 20, classID = 0 } })
    pick("1c cheese before 93c parts", {
        stack(5, "Darnassian Bleu", 1, 1, 1, { classID = 0 }),
        stack(6, "Gyrostabilizer", 3, 31, 1, { classID = 7 }) })
    -- Cheapest wins even when the cheap one is a reagent: what keeps a reagent is that it asks
    -- before it goes, not where it sits in the queue.
    pick("16c eye before a 2s40 grey knife", {
        stack(7, "Murloc Eye", 1, 16, 1, { classID = 7, craftingReagent = true }),
        stack(8, "Fisherman Knife", 1, 240, 0, { maxStack = 1 }) })
    -- Conjured food has no sell price, so it leads on price alone with no rank of its own.
    pick("conjured bread (no price) before 1c junk", {
        stack(10, "Conjured Bread", 5, 0, 1, { classID = 0, tier = "spare" }),
        stack(11, "Chipped Bowl", 1, 1, 0, { maxStack = 1 }) })
    -- A SURPLUS stack is spare too, but it has a price - and now sorts on it like anything else.
    pick("1c junk before a 10c surplus stack", {
        stack(12, "Surplus Bread", 5, 2, 1, { classID = 0, tier = "spare" }),
        stack(11, "Chipped Bowl", 1, 1, 0, { maxStack = 1 }) })
    pick("buff food only when nothing else", {
        stack(9, "Sagefish (+XP)", 4, 1, 1, { classID = 0, tier = "critical" }),
        stack(6, "Gyrostabilizer", 3, 31, 1, { classID = 7 }) })
    BW.SynergyTier, BW.testItems = realTier, nil

    -- The three cases for the one path that can overrule BagWarden's own "keep this". The last one
    -- is the important one: it tests the class gate, not our good intentions.
    local realSpare = BW.SpareProvider
    local function spareSays(itemID)
        BW.SpareProvider = function(id) return id == itemID and "AutoFeed" or nil end
    end
    local function verdict(label, item)
        local strength, reason, mustAsk = BW.KeepReason(item)
        BW.Print("unlock (%s): %s%s - %s", label, strength or "deletable",
            mustAsk and ", always asks" or "", reason or "-")
    end
    local bread = { bag = 0, slot = 1, itemID = 1113, name = "Conjured Bread", count = 8,
                    sellPrice = 0, quality = 1, maxStack = 20, classID = 0 }
    local hearth = { bag = 0, slot = 2, itemID = 6948, name = "Hearthstone", count = 1,
                     sellPrice = 0, quality = 1, maxStack = 1, classID = 15 }
    spareSays(1113)
    verdict("conjured bread, AutoFeed calls it spare", bread)
    BW.SpareProvider = function() return nil end
    verdict("hearthstone, nobody tiers it", hearth)
    spareSays(6948)
    verdict("hearthstone WRONGLY called spare", hearth)

    -- An unlocked item that ALSO matches something learned from a quest: the soft keeps below the
    -- lift return without mustAsk, so this proves the guarantee survives meeting one of them.
    spareSays(1113)
    local realLearned = BW.LearnedFor
    BW.LearnedFor = function(name) return name == "Conjured Bread" and "Some Old Quest" or nil end
    verdict("unlocked AND learned from a quest", bread)
    BW.LearnedFor = realLearned
    BW.SpareProvider = realSpare
end

--- Two stacks of the same item: the smaller one must always be the one offered, because both free
--- exactly one slot. The case this was written for: a full 20 of Roasted Boar Meat was offered while
--- 13 of it sat two slots away, because the 13 was being valued as if it were already full.
function BW.TestStacks()
    local function case(label, stacks)
        local items = {}
        for i, stack in ipairs(stacks) do
            items[i] = {
                bag = 0, slot = i, itemID = stack[1], count = stack[2], maxStack = stack[3] or 20,
                sellPrice = stack[4] or 6, name = stack[5] or "Test Item", quality = 1,
            }
        end
        local plan = BW.Plan(items)
        local target = plan.target
        BW.Print("stacks (%s): offers %s", label,
            target and string.format("%dx %s worth %s", target.item.count, target.item.name,
                BW.Coin(target.real)) or "nothing")
    end
    case("20 and 13 of one item", { { 1, 20, 20, 6, "Boar Meat" }, { 1, 13, 20, 6, "Boar Meat" } })
    case("13 and 5 of one item", { { 1, 13, 20, 6, "Boar Meat" }, { 1, 5, 20, 6, "Boar Meat" } })
    case("two full stacks", { { 1, 20, 20, 6, "Boar Meat" }, { 1, 20, 20, 6, "Boar Meat" } })
end

--- Build the tooltip for real, once normally and once with the coin API taken away, so a missing
--- client function can never take the tooltip down again (it did: Forever has no global
--- GetCoinTextureString, only C_CurrencyInfo.GetCoinTextureString).
function BW.TestTooltip()
    local scratch = BagWardenScratchTooltip
        or CreateFrame("GameTooltip", "BagWardenScratchTooltip", UIParent, "GameTooltipTemplate")
    local function build(label)
        scratch:SetOwner(UIParent, "ANCHOR_NONE")
        scratch:ClearLines()
        local ok, err = pcall(BW.FillTooltip, scratch)
        BW.Print("tooltip (%s): %s", label, ok and (scratch:NumLines() .. " lines") or ("FAILED - " .. tostring(err)))
        scratch:Hide()
    end
    build("normal")

    local savedNamespace, savedGlobal = C_CurrencyInfo, GetCoinTextureString
    C_CurrencyInfo, GetCoinTextureString = nil, nil
    local ok, err = pcall(build, "no coin API")
    C_CurrencyInfo, GetCoinTextureString = savedNamespace, savedGlobal
    if not ok then BW.Print("tooltip (no coin API): FAILED - %s", tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- The on-screen row
-- ---------------------------------------------------------------------------
--- What the row would draw right now, and the one thing about it that must never change: an icon
--- for something that asks before it goes must still ask, whatever the player clicks.
--- Nothing here draws or clicks anything - it reads the plan the row reads.
function BW.TestBar()
    if not BW.db then return end
    if not BW.db.barEnabled then
        BW.Print("row: off.")
        return
    end
    BW.Print("row: %s", BW.WhereIsBar and BW.WhereIsBar() or "?")

    local plan = BW.plan or BW.PlanNow()
    local candidates = (plan and plan.candidates) or {}
    local wanted = math.max(1, math.min(10, BW.db.barCount or 4))
    local asks = 0
    for index = 1, math.min(wanted, #candidates) do
        local entry = candidates[index]
        -- entry.confirm is what both the amber edge and the Ctrl-click path read. If they ever come
        -- from different places, this is where it shows up first.
        if entry.confirm then asks = asks + 1 end
        BW.Print("  %d. %s%s", index, BW.Describe(entry) or "?",
            entry.confirm and (" - asks: " .. (entry.reason or "?")) or "")
    end
    if #candidates == 0 then
        BW.Print("  nothing to offer - the row hides itself rather than sit there empty.")
    else
        BW.Print("  %d of %d shown would ask first (amber edge).", asks, math.min(wanted, #candidates))
    end
end
