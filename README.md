# BagWarden

Free one bag slot per click, without ever deleting something you need.

Early on, bags fill up faster than you can get back to a vendor. BagWarden puts one button on your
bag frame. Each click frees exactly one slot: first by merging two part-stacks of the same item, and
after that by deleting the least valuable junk stack you carry. The tooltip always says what the
next click will do ("Next: 5x Broken Fang - 25c") and why everything else is kept, so nothing
happens that you didn't read first.

## What it never deletes

- Anything a quest in your log asks for, including plain trade goods like Linen Cloth or Tough Wolf
  Meat that carry no "Quest Item" tag.
- Quest items, items that begin a quest, and anything bound to a quest.
- Anything green or better, and anything that can't be sold (hearthstone, keys).
- Items you put on the never-delete list (right-click the button).
- Items some quest has asked for before on this account: BagWarden remembers them as you play and
  always asks before one of those goes.

White items always ask first, in a popup that can also put the item on the never-delete list.
Nothing is ever deleted automatically, several at a time, or in combat.

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
