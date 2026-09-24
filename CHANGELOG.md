# BagWarden

## 0.1.0-beta2

- BagWarden's own checks now run from `/yippyapp test` as well as `/bagw test`, so one command can
  confirm nothing in the addon is broken. The shared run can never delete or sell anything.

- The bag button's tooltip is down to what the click does: how full your bags are, the item that
  goes, and what each mouse button does. The sort-button tip and the "kept until last" line are
  gone.
- Among the things BagWarden asks about, it now offers the least precious first when another
  YippYapp addon can tell it which those are. With AutoFeed installed that means conjured bread
  long before your ordinary food, and your buff food last of all.

- Fixed the settings page being cut off down the left-hand side, which also hid which "Asking first"
  choice was selected.
- The protected-items list shows each item once, instead of once per stack.

- "Make the bag search box smaller" is tidier: the box is twice as wide as it was, so you can read
  what you typed, and it sits at the right-hand end of the row beside the sort button instead of
  adrift in the middle. It only applies to the combined bag window now; the separate bags aren't
  crowded, so they are left alone.

- BagWarden's minimap button, launcher icon and addon-compartment entry now open its settings on any
  click. They no longer open your bags, which you open yourself anyway.

- Crafting reagents are kept, not queried. The ore, stone, cloth and leather you are levelling a
  profession with is not junk, and being asked about it on every click is worse than being asked
  nothing. Under Protected items you choose which reagents to keep: the ones your own professions
  use (the default), every reagent, or none. Telling your professions' reagents apart needs
  Skillwright; without it the first choice keeps them all rather than guessing.
- Anything that asks now waits until the plain junk is gone. A 2c Rough Stone used to be offered
  before a 97c hammer because it was cheaper, which was arithmetically right and practically wrong.
  Cheapest first still decides within each group.

- Hold Ctrl while clicking the bag button (or pressing its keybind) to delete without being asked.
  It skips the question only: everything BagWarden keeps is still kept, every check still runs, and
  the deleted-items log records that Ctrl was held.

- Fixed: with two stacks of the same item, BagWarden could offer the bigger one - a full 20 of
  Roasted Boar Meat while 13 of it sat two slots away. Both free one slot, so the smaller stack
  always costs less and is now always the one offered.
- The price in the tooltip is now always what that stack really fetches at a vendor, never the
  "if it were full" number used for ranking.
- New setting: let BagWarden delete green items as well. Off by default, and green always asks
  before it goes, however the other settings are set. Blue and better are never deleted.
- It no longer asks about every white item. Being white isn't a reason on its own: the tooltip
  already names the item the click will delete. It still always asks before a crafting reagent, food,
  drink, potions, bandages and anything a quest has ever wanted.
- New setting for how much it asks: only reagents and things you use (the default), white items as
  well, or everything including grey.
- Cheapest first, whatever colour it is. BagWarden used to work through your grey items before
  looking at white ones, so it would offer to destroy a 97c grey while a 1c white sat in the next
  slot. It now ranks everything deletable by what the slot is actually worth. White items still ask
  before they go.

- A part-stack now has to be at least half full before BagWarden values it at what it would be worth
  full. Two milk out of a possible twenty is worth twelve copper, not the six silver the full stack
  would fetch, and shouldn't outrank a grey item that really does sell for more.
- The bag button is red now. It deletes things, so it shouldn't look like the quiet bronze buttons
  next to it.
- Fixed the "Unrecognized XML" warnings at login. BagWarden's keybinding file was listed among the
  addon's files, which sent it through the wrong parser; the game loads that file on its own. The
  keybinding now appears as "Free a bag slot" under BagWarden in the keybindings.

## 0.1.0-beta1

The first build of BagWarden for WoW: Forever.

- **One click frees one bag slot.** A button in your bag window deletes the least valuable junk
  stack you carry. The tooltip says which item that is before you click, and hovering the button
  lights up its slot in red.
- **It deletes only when you click the button or press your BagWarden keybind.** Never on a timer,
  never several at once, never in combat, and never from the minimap button or a chat command. The
  game only permits deletion from a real click, and it is the right behaviour in any case.
- **It never deletes anything you need.** Items a quest in your log asks for (including plain trade
  goods like Linen Cloth that carry no quest tag), quest items, profession tools, gear that gives
  profession skill, recipes, anything green or better, anything that can't be sold, and anything on
  your never-delete list. White items always ask first. If anything can't be checked, the item is
  kept.
- **It remembers quest turn-ins as you play**, for your whole account, so an item some quest asked
  for once is never picked automatically again.
- **Sells your grey items at a merchant**, up to twelve per visit so everything stays in the
  merchant's buyback list, and tells you what they came to.
- The settings page lists everything currently protected and why, plus a log of what has been
  deleted. Settings are under Options -> AddOns -> YippYapp -> BagWarden.
