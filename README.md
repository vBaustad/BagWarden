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

Everything ordinary is ranked by what the slot is really worth, whether the item is grey or
white - freeing a slot should cost you as little as possible, and a grey item is not
automatically the cheapest thing you carry. Crafting reagents, trade goods, and anything another
YippYapp addon has an opinion about are ordered separately; "How it picks" below says how.

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

## The scrap list

**Alt-click** any grey or white stack in your bags and it becomes scrap: a gold coin appears in the
corner of the slot, the next merchant you open buys it, and you never have to decide about that item
again. Alt-click it again to take it off. The list is account-wide and also shows under "At a
merchant" in the settings.

Greys and scrap share one limit of twelve stacks per visit, so everything you sell stays in the
merchant's buyback list until you walk away. Better than white is refused - buyback only saves you
until you leave the vendor, and a misplaced Alt-click should not be able to sell a blue.

A scrapped item is sold even when BagWarden would otherwise keep it for being a reagent, or food, or
something a quest once wanted: you named that item, which beats our guess. What no list overrides is
a hard keep - a quest item in your log, something unsellable, something too good.

## The on-screen row

On by default, and silent until you are down to four free slots. When it appears, BagWarden draws the
next few stacks it would delete as a row of icons you can put anywhere, so you can clear a slot
without opening your bags.

- **Ctrl-click** an icon to act on that stack - any of them, not just the first.
- **Right-click** one to put that item on your never-delete list.
- **A plain click does nothing.** The bag button deletes on a plain click because you had to open
  your bags to reach it. A row on the world is easy to hit by accident, so acting there takes Ctrl.
- The edge says what the click will do. **Grey** is plain junk. **Amber** is something that isn't
  junk - a reagent, food, an old quest leftover - which a Ctrl-click still deletes, because choosing
  one icon and holding Ctrl is a decision, not an accident. **Blue** is the two that always stop and
  ask whatever you hold: anything green, and anything another YippYapp addon unlocked for us.

Above the icons is how much room you have left: grey normally, amber when you are running low, red
saying "Bags full" when you are out. Running low is whatever you set under "only when free slots are
under", or five slots if you never set one. When your bags are full and there is nothing BagWarden
can free, the row stays up to say so rather than hiding for having no icons - that is the moment you
most want telling.

How many icons, how big, which way the row grows, whether it hides in combat, and whether it stays
out of sight until you are low on slots are all settings. Drag the row to move it; lock it when it
is where you want it.

A hidden row costs almost nothing. While it waits for your bags to fill, BagWarden reads only how
many slots are free - five numbers - rather than reading every slot; the full scan waits until the
row has something to show, which is when you were about to open your bags anyway. With "hide it in
combat" on it reads nothing at all during a fight. Setting the row to "always show" opts into the
full scan on every bag update.

Nothing in BagWarden uses the game's secure or protected frame machinery, so none of it can taint
your action bars or unit frames. The icons are ordinary buttons; deleting works because the game
accepts a real click, not because anything is hooked into a protected path.

## How it picks

Everything ordinary is offered first, cheapest slot first - a grey item's vendor price is exactly
what it is worth, since vendoring is all a grey is for. Crafting reagents and trade goods come after
that whatever they cost, because their price tag says the least about them, and anything another
YippYapp addon calls critical (your buff food) is offered only when nothing else is left. Ahead of
all of it goes anything one of them calls spare - a surplus stack someone can replace for nothing,
like the spare conjured bread beside the stack your AutoFeed macro eats, which stays.

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
