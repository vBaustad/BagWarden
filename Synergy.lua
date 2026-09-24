-- BagWarden - what the other YippYapp addons ask us to keep.
-- Nothing here reaches into another addon. Each one publishes a small table through the library
-- (LIB.ProvideData) with a Keep(itemID) function that returns a reason or nil, and we ask whoever
-- happens to be there. No addon is assumed to exist, no call is trusted not to error, and a
-- provider that misbehaves keeps the item rather than getting it deleted.
local ADDON, BW = ...
local LIB = LibStub("LibForever-1.0")

-- The providers we know about. An entry that nobody publishes is simply skipped, so this list can
-- name addons the player hasn't got (or that don't exist yet) without any harm.
local PROVIDERS = {
    "BuffWardenWeaponEnhancers",    -- stones, oils and poisons for the weapon you're carrying
    "SkillwrightReagents",          -- reagents for recipes you know
    "AutoFeedConsumables",          -- the food, water and bandages your macros use
    "GuildhallWanted",              -- what you've listed, or guildies are after
}

--- The table a provider published, or nil. LIB.GetData is an index into the library's own table,
--- so it needs no pcall; the provider's FUNCTIONS are the part we don't trust.
local function Provider(name)
    local data = LIB.GetData and LIB.GetData(name)
    return type(data) == "table" and data or nil
end

--- Ask every provider that is present. Returns the first reason given, or nil.
--- Answers are NOT cached: they follow the player's equipped weapon, known recipes and settings,
--- so a stale answer would be worse than the lookup it saves.
function BW.SynergyReason(item)
    if not (item and item.itemID and LIB.GetData) then return nil end
    for _, name in ipairs(PROVIDERS) do
        local data = Provider(name)
        if data and type(data.Keep) == "function" then
            local called, reason = pcall(data.Keep, item.itemID)
            if not called then
                BW.Debug("%s.Keep errored: %s", name, tostring(reason))
                -- A provider that throws is a provider we can't clear the item with.
                return "another YippYapp addon uses this"
            end
            if type(reason) == "string" and reason ~= "" then return reason end
            if reason == true then return "another YippYapp addon uses this" end
        end
    end
    return nil
end

-- Protect.lua asks every registered rule, in pcall, and a rule that errors keeps the item.
table.insert(BW.protectors, BW.SynergyReason)

--- Is a provider actually publishing rules right now? Used where the ANSWER MATTERS EVEN WHEN IT IS
--- "no": without Skillwright we cannot tell one profession's reagents from another's, so we must
--- know whether anybody is able to tell us rather than assuming the worst.
function BW.ProviderPresent(name)
    local data = Provider(name)
    return data ~= nil and type(data.Keep) == "function"
end

-- ---------------------------------------------------------------------------
-- How precious is it? (ordering, not protection)
-- ---------------------------------------------------------------------------
-- A provider may also offer Tier(itemID) -> "critical" | "useful" | "spare" | nil, which says how
-- much the player would miss the item rather than whether to keep it at all. AutoFeed publishes it
-- for food and drink (buff food is critical, conjured bread is spare); any provider may.
-- It only changes the ORDER things are offered in. It can never make something deletable, and an
-- absent or erroring Tier simply means "no opinion".
function BW.SynergyTier(itemID)
    if not (itemID and LIB.GetData) then return nil end
    for _, name in ipairs(PROVIDERS) do
        local data = Provider(name)
        if data and type(data.Tier) == "function" then
            local called, tier = pcall(data.Tier, itemID)
            if called and (tier == "critical" or tier == "useful" or tier == "spare") then
                return tier
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- /bagw test - which providers are actually there
-- ---------------------------------------------------------------------------
function BW.TestSynergies()
    local found = 0
    for _, name in ipairs(PROVIDERS) do
        local data = Provider(name)
        local usable = data ~= nil and type(data.Keep) == "function"
        if usable then
            found = found + 1
            BW.Print("synergy: %s is providing keep rules%s", name,
                type(data.Tier) == "function" and " and an ordering" or "")
        end
    end
    if found == 0 then BW.Print("synergy: no other YippYapp addon is providing keep rules") end
end
