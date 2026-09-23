# BagWarden

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
