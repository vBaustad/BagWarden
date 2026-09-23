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
- Anything green or better, and anything that can't be sold (hearthstone, keys).
- Items you put on the never-delete list (right-click the button).
- Items some quest has asked for before on this account: BagWarden remembers them as you play and
  always asks before one of those goes.

White items always ask first, in a popup that can also put the item on the never-delete list.

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

A stack is judged by what the slot is worth: sell price times how many you hold. A stack you are
still filling counts as what it will be worth when full, so a half-done stack of good drops isn't
thrown away to save a slot you would refill in a minute.

## Part of YippYapp

BagWarden is part of YippYapp, addons for WoW: Forever that work even better together. With
Skillwright installed it keeps the reagents for recipes you know; with AutoFeed it keeps the food,
water and bandages your macros use; with Guildhall it keeps what you have listed or guildies want.
Each addon works fully on its own.

`/bagw` does the next thing, `/bagw test` reports what BagWarden sees, and the settings are under
Options -> AddOns -> YippYapp -> BagWarden.
