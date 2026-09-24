-- BagWarden - the only place an item is ever destroyed.
-- The rules here are deliberately strict, because a wrong delete can't be undone:
--   * the plan is never trusted: the slot is read again and re-judged the moment before deleting;
--   * one click deletes at most one stack, with no loop and no retry;
--   * anything unexpected aborts and rescans instead of deleting something else;
--   * only the player's own click gets here (the bag button, or /bagw free). No timer, no event.
local ADDON, BW = ...
local LIB = LibStub("LibForever-1.0")

--- Read one slot afresh and build the same record ScanBags would.
local function ReadSlot(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not (info and info.itemID) then return nil end
    local details = BW.ItemInfo(info.hyperlink, info.itemID)
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    return {
        bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1,
        quality = info.quality or (details and details.quality) or 0,
        name = (details and details.name) or info.itemName, link = info.hyperlink,
        locked = info.isLocked, hasNoValue = info.hasNoValue,
        sellPrice = details and details.sellPrice or 0,
        maxStack = details and details.maxStack or 1,
        classID = details and details.classID, subclassID = details and details.subclassID,
        bindType = details and details.bindType, incomplete = details == nil,
        craftingReagent = details and details.craftingReagent or false,
        isQuestItem = quest and quest.isQuestItem or false,
        questID = quest and quest.questID or nil,
    }
end

--- Is this exactly the stack we decided on, and is it still deletable? Returns the fresh item, or
--- nil plus why not. Everything unknown counts as "no".
function BW.VerifyTarget(entry)
    if not (entry and entry.item) then return nil, "nothing chosen" end
    local planned = entry.item
    local fresh = ReadSlot(planned.bag, planned.slot)
    if not fresh then return nil, "that slot is empty now" end
    if fresh.itemID ~= planned.itemID then return nil, "that slot holds something else now" end
    if fresh.count ~= planned.count then return nil, "the stack changed size" end
    if fresh.link ~= planned.link then return nil, "that item changed" end
    if fresh.locked then return nil, "that item is in use" end
    -- Re-run the whole protection chain against the item as it is right now.
    local strength, reason = BW.KeepReason(fresh)
    if strength == "hard" then return nil, reason or "it's protected now" end
    if strength == "soft" and not entry.confirm then return nil, reason or "it needs confirming" end
    return fresh
end

-- White items are never deleted on a plain click: they ask first. The popup's own button click is
-- the player's click, which is what the client needs for a delete.
StaticPopupDialogs["BAGWARDEN_CONFIRM_DELETE"] = {
    text = "Delete %s?\n\n%s",
    button1 = DELETE or "Delete",
    button2 = CANCEL or "Skip",
    button3 = "Never delete",
    hasThreeButtons = true,
    OnAccept = function(_, entry) BW.DeleteStack(entry) end,
    OnAlt = function(_, entry)
        if entry and entry.item then
            BW.SetIgnored(entry.item.itemID, true)
            BW.Print("%s will never be deleted.", entry.item.name or "?")
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    showAlert = 1,
    exclusive = 1,
};

--- Ask before deleting something that isn't plain junk.
function BW.AskThenDelete(entry)
    if not (entry and entry.item) then return end
    local dialog = StaticPopup_Show("BAGWARDEN_CONFIRM_DELETE",
        string.format("%dx %s (%s)", entry.item.count, entry.item.link or entry.item.name or "?",
            BW.Coin(entry.real or entry.value or 0)),
        entry.reason or "", entry)
    if dialog and LIB and LIB.RegisterPopup then LIB.RegisterPopup(dialog) end
end

--- Delete one stack. Returns true when the item was handed to the client for deletion.
--- `fromHardware` says the caller is running inside the player's own click or keypress, which is
--- what DeleteCursorItem needs: it silently does nothing when called from a slash command or a
--- timer. The one place we can't ask the client, so the callers have to be honest.
--- `skippedAsk` means the player held Ctrl to skip the question. It changes nothing below: every
--- check still runs, and it is only recorded in the log so the deletion can be accounted for.
function BW.DeleteStack(entry, fromHardware, skippedAsk)
    -- A self test must never destroy anything. This is the assertion, not a convention: whatever a
    -- future test step calls, it cannot get past here while BW.testing is set.
    if BW.testing then
        BW.Print("refused: nothing is deleted while the self test runs.")
        return false
    end
    if fromHardware == false then
        BW.Print("the game only lets an addon delete inside a real click or keypress.")
        BW.Print("use the button in your bag window, or bind a key to BagWarden in the keybindings.")
        return false
    end
    if not BW.deleteEnabled then
        BW.Print("deleting is off in this build.")
        return false
    end
    if InCombatLockdown() then
        BW.Print("not in combat.")
        return false
    end
    if CursorHasItem() then
        BW.Print("your cursor is holding something - drop it first.")
        return false
    end

    local item, why = BW.VerifyTarget(entry)
    if not item then
        BW.Print("nothing deleted: %s.", why or "the bags changed")
        BW.Refresh()            -- rescan, then let the player click again if they still want to
        return false
    end

    C_Container.PickupContainerItem(item.bag, item.slot)
    if not CursorHasItem() then
        BW.Print("nothing deleted: the item wouldn't pick up.")
        BW.Refresh()
        return false
    end
    -- Last chance to notice a swap. The slot itself is empty now (the stack is on the cursor), so
    -- this is the final re-verification: what we are holding must be the itemID and the link that
    -- VerifyTarget just approved, a few lines above and in this same click.
    local kind, cursorItemID, link = GetCursorInfo()
    if kind ~= "item"
        or (cursorItemID and cursorItemID ~= item.itemID)
        or (link and item.link and link ~= item.link) then
        ClearCursor()
        BW.Print("nothing deleted: the cursor picked up something else.")
        BW.Refresh()
        return false
    end

    -- Write the log BEFORE the delete: if anything after this errors, the record still exists.
    BW.LogDeletion(item, entry.real or entry.value or 0, skippedAsk)
    DeleteCursorItem()

    -- DeleteCursorItem fails silently when it isn't allowed, and the item simply stays on the
    -- cursor. That's not a deletion, so put the cursor back and take the log line away again.
    if CursorHasItem() then
        ClearCursor()
        BW.UnlogLastDeletion()
        BW.Print("nothing deleted: the game refused it. Deleting only works from a click or a keypress.")
        BW.Refresh()
        return false
    end

    BW.Print("deleted %dx %s (%s)%s.", item.count, item.name or "?",
        BW.Coin(entry.real or entry.value or 0), skippedAsk and " - Ctrl-click, no question asked" or "")
    BW.Refresh()
    return true
end
