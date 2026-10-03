# BagWarden

## Unreleased

- Fixed BagWarden possibly selling nothing at all at a merchant. It asked whether Blizzard's merchant
  window was on screen before selling, but that window is put up by the game in the same moment the
  merchant opens, and may not be up yet when BagWarden is told about it. The game telling us a
  merchant is open is the stronger fact, so that is what it goes on now.
- New: `/bagw sell` says what a merchant visit would do and, for anything it would hold back, exactly
  why - the protection that stopped it, a price of nothing, the twelve-per-visit limit. It sells
  nothing and works away from a merchant, which is the point: "it didn't sell my scrap" is always
  reported after the fact, and this answers it without a guess.

- **BagWarden now explains itself in the game.** At the bottom of its settings page there are four
  headed sections: what it does, how to get started, things worth knowing, and what it does with the
  other YippYapp addons. The switches stay at the top, because that is what you open settings for;
  the help is what you scroll to. This is new rather than moved - the old welcome window gave
  BagWarden a title and one line, and nowhere in the game said how the addon is actually used.
- The welcome window is gone, and BagWarden no longer registers a page in it.

- **"Show BagWarden in the minimap row" is now on BagWarden's own settings page**, near the top. The
  YippYapp addons share one minimap button, and whether BagWarden is one of the icons behind it was a
  setting on a shared page that is going away. The addon works the same either way - its icon only
  opens these settings - and `/bagw` always gets you here.
- The launcher bar is gone, so BagWarden no longer puts an icon on it. Your minimap choice is
  untouched: a hidden bar icon was never a statement about your minimap, and the two were never
  stored in the same place.
- Fixed the settings page assuming how wide it is. It now asks the window, which matters because a
  page this long scrolls, and a scrolling page is narrower than the frame by the width of the
  scrollbar. The same wrong assumption had pushed buttons off the right-hand edge of the shared page.

- **Alt-click a stack in your bags to call it scrap.** The next merchant you open buys it, and you
  never have to decide about that item again - no setting to find, no list to curate. Alt-click it a
  second time to take it back off. The scrap list is account-wide and shows on the settings page
  under "At a merchant".
- **A gold coin sits in the corner of every scrapped stack**, so the list is something you can see in
  your bags rather than something you have to remember. It appears on the click that put it there and
  follows the item through a bag sort.
- Every grey and white item's tooltip now mentions the Alt-click, and anything already on the list
  says so wherever you see it - in your bags, at a merchant, on a link in chat. A gesture nothing
  ever mentions is a gesture nobody finds.
- Greys and scrap share the same twelve-per-visit limit, so everything you sell stays in the
  merchant's buyback list until you walk away.
- Scrap only takes grey and white items. Buyback makes a mistake recoverable, but only until you
  leave, and an Alt-click that lands on the wrong slot should not be able to turn a blue into gold
  you can't undo - so better than white is refused out loud instead of sold quietly.
- A scrapped item is sold even when BagWarden would otherwise have kept it for being a reagent, or
  food, or something a quest once wanted: you named that exact item, which beats our guess. What no
  list overrides is a hard keep - a quest item in your log, something unsellable, something too good.
  Those are not guesses.

- **The settings page reads as a list instead of an essay.** Every setting is now one row - its name
  on the left, its control at the same place on the right, every other row faintly shaded so you can
  run your eye down it. What a setting does moved into the row's tooltip, so four paragraphs that used
  to sit under four toggles are there when you want them and out of the way when you don't. The three
  choices that genuinely need explaining - which reagents to keep, how much to ask, and the row below -
  keep their text on the page, because a bare label there would be a guess.

- **A row of icons on the screen, showing what goes next.** On by default, and silent until you are
  down to four free slots - so it is out of your way until the moment it is useful, and you don't
  have to know it exists to be helped by it. BagWarden draws the next few stacks it would delete,
  cheapest first, without you opening your bags.
  Ctrl-click an icon to act on that one - not just the first - and right-click one to put that item
  on your never-delete list. A plain click does nothing at all, on purpose: the bag button deletes on
  a plain click because you had to open your bags to reach it, and a row sitting on the world is far
  easier to hit by accident.
- **Ctrl-clicking an icon gets on with it.** Picking one icon out of the row and holding Ctrl is a
  long way from a slip, and the tooltip under your cursor has already named the item - so a reagent
  or an old quest leftover goes without a second question. Two things still stop and ask, however you
  click and wherever you click them: anything green, and anything another YippYapp addon unlocked for
  us. Both were promises made elsewhere, and a held key is not a reason to break one.
- Fixed: holding Ctrl on the bag button deleted green items without asking, although the setting that
  allows greens at all says they always ask "however the other settings are set". Both the button and
  the row now ask the same single rule about what Ctrl may skip, so they cannot drift apart again.
- Each icon's edge now says which of the three it is: grey for plain junk, amber for something that
  isn't junk but will go on a Ctrl-click, blue for the ones that will stop and ask you first.
- **The row says how much room you have left**, above the icons: grey normally, amber when you are
  running low, and red saying "Bags full" when you are out. Running low means whatever you set under
  "only when free slots are under", or five slots if you never set one - your own threshold is
  already you telling us what low means to you.
- And when your bags are full with nothing BagWarden can free, the row stays on screen to say exactly
  that, instead of hiding because it has no icons to show. That is the moment you most want telling,
  and going quiet then would look like the addon had given up without a word.
- The row is yours to place: drag it anywhere, choose how many icons (1-10), how big they are, which
  way it grows, and whether it hides in combat. It can also stay out of sight until you are actually
  running out of room - set "only when free slots are under" and it appears when you need it.
- A hidden row costs almost nothing. While it is waiting for your bags to fill, BagWarden only reads
  how many slots are free - five numbers - instead of reading every slot. The full scan happens once
  the row actually has something to show, which is also when you were about to open your bags anyway.
  With "hide it in combat" on it reads nothing at all during a fight, which is when loot arrives
  fastest. Set the row to "always show" and you are opting into the full scan on every bag update.

## 0.1.0-beta4

- On the settings page, the paragraph explaining the three reagent choices now sits with them
  instead of reading as part of the profession-gear description above it.

- Anything another YippYapp addon calls spare - a surplus stack someone can replace for nothing -
  is now offered before ordinary junk, however little it sells for. With AutoFeed installed that
  covers spare conjured food and water, which BagWarden would otherwise keep for having no sell
  price. The conjured stack your AutoFeed macro actually eats is still kept, because AutoFeed also
  says the macro uses it - so this is about the surplus beside it. Anything unlocked this way always
  asks before it goes, even with Ctrl held, and the question says which addon vouched for it.

- The tooltip now names the next item the instant you delete one, without moving the mouse, and the
  red slot in your bags moves with it. Before, a second click could take something the tooltip
  wasn't describing. Same for a Ctrl-click and for the keybind.

- Reagents and trade goods are offered after everything ordinary, whatever they sell for. A grey
  item's vendor price is exactly what it is worth, because vendoring is all a grey is for - but a
  Murloc Eye's 16c says almost nothing about what it is worth to someone levelling Alchemy. So a
  2s40 grey knife now goes before a 16c reagent, while a 1c belt still goes before a 97c grey
  hammer. Your buff food still comes after all of it.

## 0.1.0-beta3

- Updated shared YippYapp library.

## 0.1.0-beta2

- BagWarden's own checks now run from `/yippyapp test` as well as `/bagw test`, so one command can
  confirm nothing in the addon is broken. The shared run can never delete or sell anything.

- The bag button's tooltip is down to what the click does: how full your bags are, the item that
  goes, and what each mouse button does. The sort-button tip and the "kept until last" line are
  gone.
- Cheapest slot first, across everything: whether an item asks before it goes no longer changes
  where it sits in the queue. Asking is a question, not a ranking, so 1c of cheese is offered before
  93c of engineering parts. The one exception: with AutoFeed installed, your buff food is offered
  only when there is nothing else left.

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
