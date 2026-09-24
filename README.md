# BagWarden

Free one bag slot per click, without ever deleting something you need.

Early on, bags fill up faster than you can get back to a vendor. BagWarden puts one button on your
bag frame. Each click frees exactly one slot, by deleting the least valuable junk stack you carry.
The tooltip always says which item that is ("Delete [Broken Fang] - 25c") before you click, and
hovering the button lights up that slot in your bags, so nothing happens that you didn't read first.
Joining part-stacks is left to Blizzard's sort button, which sits right next to ours and already
does it.

## What it never deletes

- Anything a quest in your log asks for, including plain trade goods like Linen Cloth or Tough Wolf
  Meat that carry no "Quest Item" tag.
- Quest items, items that begin a quest, and anything bound to a quest.
- Anything better than green, and anything that can't be sold (hearthstone, keys). Green items are
  kept too unless you tick "Let it delete green items too", and even then they always ask first.
- Items you put on the never-delete list (right-click the button).
- Items some quest has asked for before on this account: BagWarden remembers them as you play and
  always asks before one of those goes.

Everything deletable is ranked by what the slot is really worth, whether the item is grey or
white - freeing a slot should cost you as little as possible, and a grey item is not
automatically the cheapest thing you carry.

Before it deletes a crafting reagent, food, drink, a potion, a bandage or anything a quest has ever
asked you for, it asks, in a popup that can also put the item on the never-delete list. A setting
decides whether it also asks by quality: not at all, for white items, or for everything down to
grey. Hold Ctrl while you click, or while you press the keybind, and it skips the question - that
skips the asking, never a protection.

## Only when you ask for it

BagWarden deletes only inside your own click on its button, or your own press of its keybind (set it
under BagWarden in the keybindings). Never on a timer, never several items at once, never in combat,
and never from the minimap button or a chat command - `/bagw free` will tell you to use the button
instead. That is partly because the game only allows an addon to delete from a real click, and
partly because it is the right way round: one deliberate click, one item.

Before anything goes, BagWarden reads the slot again and checks that it still holds the same item,
the same number of them, and that every protection still passes. If anything changed while you were
deciding, it deletes nothing and tells you why.

## How it picks

A stack is judged by what the slot is worth: sell price times how many you hold. A stack that is
already at least half full, and that you are still picking up, counts as what it will be worth full
instead, so a nearly finished stack of good drops isn't binned to save a slot you would refill in a
minute. Below half a stack it counts for what it is actually worth today - two of something is two
of something, however big the stack could get.

## Part of YippYapp

BagWarden is part of YippYapp, addons for WoW: Forever that work even better together. With
Skillwright installed it keeps the reagents for recipes you know; with AutoFeed it keeps the food,
water and bandages your macros use, and offers your buff food only as a last resort; with
BuffWarden it keeps the sharpening stones and oils you use; with Guildhall it keeps what you have
listed or guildies want. Each addon works fully on its own.

`/bagw` opens the settings, as does BagWarden's minimap button, and `/bagw test` reports what it
sees in your bags. The settings live in the YippYapp window, under BagWarden.
