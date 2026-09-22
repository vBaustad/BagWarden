-- BagWarden - showing which stack the next click touches.
-- Hovering the bag button glows the slot it would act on: red for a delete, gold for the two stacks
-- a merge would join. The glow is Blizzard's own "bags-glow-white" atlas, the one new items use,
-- tinted; it sits on top of the item button and is removed the moment the mouse leaves.
local ADDON, BW = ...

local RED = { 1, 0.15, 0.15 }
local GOLD = { 1, 0.82, 0.1 }

local glows = {}            -- our textures, one per slot we light up right now

local function Glow(itemButton, color)
    local glow = glows[itemButton]
    if not glow then
        glow = itemButton:CreateTexture(nil, "OVERLAY")
        glow:SetAtlas("bags-glow-white")
        glow:SetBlendMode("ADD")
        glow:SetAllPoints(itemButton)
        glows[itemButton] = glow
    end
    glow:SetVertexColor(color[1], color[2], color[3])
    glow:Show()
end

--- The item button drawing a given bag slot, in whichever bag window is open.
local function FindItemButton(bag, slot)
    for _, name in ipairs({ "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2",
        "ContainerFrame3", "ContainerFrame4", "ContainerFrame5" }) do
        local frame = _G[name]
        if frame and frame:IsShown() and frame.EnumerateValidItems then
            for _, itemButton in frame:EnumerateValidItems() do
                if itemButton:GetBagID() == bag and itemButton:GetID() == slot then return itemButton end
            end
        end
    end
    return nil
end

--- Clear every glow we put up.
function BW.ClearHighlight()
    for itemButton, glow in pairs(glows) do
        glow:Hide()
        glows[itemButton] = nil
    end
end

--- Light up whatever the next click would touch. Safe to call again while hovering: the plan can
--- change under the mouse (a bag update, or the click itself), and this follows it.
function BW.ShowHighlight()
    BW.ClearHighlight()
    local plan = BW.plan
    if not plan then return end

    if plan.action == "merge" and plan.merge then
        -- A merge takes nothing away, so it never gets the red treatment.
        for _, item in ipairs({ plan.merge.from, plan.merge.to }) do
            local itemButton = FindItemButton(item.bag, item.slot)
            if itemButton then Glow(itemButton, GOLD) end
        end
        return
    end

    local target = plan.target
    if not target then return end
    local itemButton = FindItemButton(target.item.bag, target.item.slot)
    if itemButton then Glow(itemButton, RED) end
end
