-- BagWarden - what a bag slot is worth, and what to do next.
-- A slot is worth what the stack in it fetches at a vendor: sell price times how many you hold.
-- One number, the one we show you, and the one we rank on.
--
-- It used to be two. A part-stack you were still filling was ranked at what the FULL stack would
-- fetch, from half a stack upwards, so a 15/20 of decent drops would not be binned to save a slot
-- you would refill in two minutes. That is gone, and the arguments against it were all the player's
-- own, made twice:
--
--   * it is a prediction. Eighteen more milk may not drop, and a queue that sorts on a guess is
--     sorting on something that has not happened.
--   * the threshold does not mean the same thing at different stack sizes. The markup is exactly 2x
--     at the half-way point whatever maxStack is, so ONE of a two-stack was counted as two, the same
--     treatment a 10-of-20 got. "Nearly done" and "a single item" are not the same claim.
--   * it ranked on a number we never showed. A 12c stack of bread sat behind a 15c grey, and the
--     only figure on screen said 12c. A rule that needs a line of tooltip to stop looking broken is
--     a rule arguing with its own interface.
--
-- What protects a stack you are farming was never the ordering anyway: it is that trade goods and
-- reagents ask before they go. The ordering only ever decided which question came first.
local ADDON, BW = ...

--- What this stack fetches at a vendor: the number shown, and the number ranked on.
function BW.StackValue(item)
    return (item.sellPrice or 0) * (item.count or 1)
end

-- A provider can say how much the player would miss an item, with Tier(itemID): "spare" for the
-- conjured bread they can make more of, "useful" for the food their macros use, "critical" for buff
-- food and, for a mana class, water. Only "critical" changes the order, and only as a last resort.
--
-- We tried sorting the things that ASK behind everything that doesn't, and it was wrong: it meant
-- destroying 93c of gyrostabilizers to avoid asking one question about 1c of cheese. Asking is a
-- question, not a ranking. So value decides, across the lot, and the only thing held back is the
-- item you'd actually mourn.
-- So the cheapest slot goes first, across everything, and exactly one thing is held back: what a
-- provider calls "critical", which today means your buff food. That is offered only when there is
-- nothing else left.
--
-- Two groups, where there were four. The two that went were not pulling their weight:
--
--   "spare" covers two things, and price handles both. A conjured item has no sell price at all, so
--   price alone already puts it first - and nothing else can reach this list at zero, because
--   anything unsellable is kept outright unless a provider lifted it (Protect.lua step 4). The
--   other kind is a surplus stack of ordinary food, which DOES have a price, and which the rank was
--   pushing in front of junk that costs less. That was the rank disagreeing with the only promise
--   this queue makes. Food you can rebuy is ordinary; let it be ordinary.
--
--   Reagents and trade goods had a rank because their vendor price says the least about them - a
--   Murloc Eye's 16c tells you nothing about what it is worth to someone levelling Alchemy. But
--   that argument was about not LOSING them, and ordering is a crude way to say so: what actually
--   protects a reagent is that it ASKS before it goes. The rank only decided which question came
--   first. So the protection stays where it belongs, and the queue gets to be one simple promise -
--   cheapest first - which is what the tooltip has always claimed it was.
--
-- What this exposes, and it is worth knowing: on the on-screen row a Ctrl-click deletes a white
-- reagent without asking (BW.AlwaysAsks), so a reagent reaching the front of the queue is now one
-- deliberate click from gone. The bag button is unaffected - a plain click there still asks.
local function Rank(entry)
    return entry.tier == "critical" and 1 or 0
end

--- Sort: the slot that costs least goes first, whatever colour the item is and whether or not it
--- asks. The one exception is buff food (see Rank). Ties go to the one we looted longest ago.
local function Cheaper(a, b)
    local ra, rb = Rank(a), Rank(b)
    if ra ~= rb then return ra < rb end
    if a.value ~= b.value then return a.value < b.value end
    local ta, tb = BW.lootSeen[a.item.itemID] or 0, BW.lootSeen[b.item.itemID] or 0
    if ta ~= tb then return ta < tb end
    return (a.item.name or "") < (b.item.name or "")
end

--- What BagWarden would do next, and why everything else stays.
--- Returns { action = "delete"|"confirm"|nil, ... , kept = { {item, reason}, ... } }.
--- Merging part-stacks isn't ours to do: Blizzard's sort button, right next to ours, already does it.
function BW.Plan(items)
    items = items or BW.items or {}
    local plan = { free = BW.FreeSlots(), total = BW.TotalSlots(), candidates = {} }

    -- Two stacks of the same item free exactly one slot each, so the smaller one always costs less.
    -- Only the smallest stack of an item is ever a candidate; the rest can't be better answers, and
    -- leaving them out also keeps the sort a plain comparison of different items.
    local smallest = {}
    for _, item in ipairs(items) do
        local strength, reason, mustAsk = BW.KeepReason(item)
        -- A hard keep is simply not a candidate. What's kept and why is shown on the settings page,
        -- which asks KeepReason itself when the page is opened.
        if strength ~= "hard" then
            local best = smallest[item.itemID]
            if not best or item.count < best.item.count then
                -- Colour decides whether we ASK, not what comes first: a soft keep (a reagent,
                -- something you use, or one some quest has wanted) goes through the confirm popup.
                -- `value` and `real` are the same number now and both are kept: every reader of an
                -- entry outside this file uses one or the other, and one name for it is a rename
                -- across five files for no gain.
                local value = BW.StackValue(item)
                smallest[item.itemID] = {
                    item = item, value = value, reason = reason,
                    real = value, confirm = strength == "soft" or nil,
                    tier = BW.SynergyTier and BW.SynergyTier(item.itemID) or nil,
                    -- Set only for an item another addon unlocked: Ctrl can't skip its question.
                    mustAsk = mustAsk or nil,
                }
            end
        end
    end
    for _, entry in pairs(smallest) do plan.candidates[#plan.candidates + 1] = entry end
    table.sort(plan.candidates, Cheaper)

    local next_ = plan.candidates[1]
    if next_ then
        plan.action = next_.confirm and "confirm" or "delete"
        plan.target = next_
    end
    return plan
end

--- One line describing a candidate, for the tooltip and chat.
--- Always the REAL value: what the stack fetches at a vendor today. A number the player can't
--- reconcile with the merchant window is a number that costs us their trust.
function BW.Describe(entry)
    if not entry then return nil end
    local text = string.format("%dx %s - %s", entry.item.count, entry.item.name or "?",
        BW.Money(entry.real or entry.value))
    return text
end

--- `/bagw order` - the queue, in order, and why each stack sits where it does. Then everything in
--- the bags that is NOT in the queue, with the protection that kept it out.
---
--- This exists because "that cheap thing wasn't offered first" is answered by seeing the queue: the
--- stack is either further down it than you expected, or not in it at all because something is
--- keeping it. The second half of this report is the only place that says which protection.
function BW.OrderReport()
    local items = BW.ScanBags()
    local plan = BW.Plan(items)
    local queue = plan.candidates or {}

    BW.Print("the queue, cheapest first (%d of %d stacks):", #queue, #items)
    for index = 1, math.min(12, #queue) do
        local entry = queue[index]
        local real = entry.real or 0
        local note = ""
        if entry.tier == "critical" then note = " |cffc9a227(buff food - always last)|r" end
        BW.Print("  %d. %dx %s - %s%s%s", index, entry.item.count,
            entry.item.link or entry.item.name or "?", BW.Coin(real), note,
            entry.confirm and (" |cff808080asks: " .. (entry.reason or "?") .. "|r") or "")
    end
    if #queue > 12 then BW.Print("  ...and %d more", #queue - 12) end

    -- What is being kept, grouped by reason, so a long list stays one line per reason.
    local groups, order, seen = {}, {}, {}
    for _, item in ipairs(items) do
        local strength, reason = BW.KeepReason(item)
        if strength == "hard" and not seen[item.itemID] then
            seen[item.itemID] = true
            reason = reason or "kept"
            if not groups[reason] then groups[reason] = {} order[#order + 1] = reason end
            local names = groups[reason]
            names[#names + 1] = item.name or ("item " .. item.itemID)
        end
    end
    if #order == 0 then
        BW.Print("nothing in your bags is being held back.")
        return
    end
    table.sort(order)
    BW.Print("not in the queue at all:")
    for _, reason in ipairs(order) do
        table.sort(groups[reason])
        BW.Print("  |cffffd100%s:|r %s", reason, table.concat(groups[reason], ", "))
    end
end
