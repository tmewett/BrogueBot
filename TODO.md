# To-do

- "You defeated something", "you hear combat in the distance", "your ally defeated X/something", events in general ...?
- We also have no robust way of identifying which scroll/potion was just used (merge with events system? ^)
- Carried items, are they properly magic-detected?

- Generalise/refactor shortest path calculations in Dijkstra.c
	- A short int distance value is definitely not big enough for arbitrary cost maps
	- costmap(cmap) gives (configurable) default cost map, setupKnownCosts
	- calcdistances(dmap, cmap, diagonals) - basically dijkstraScan
	- distancemap(goals, bf, mb) == calcdistances(<table mapping goal cells to 0>, costmap(bf, mb), true)

# Done/for reference

- Attack and defense values for player and creatures in general - what processing needs to be done on them? And for weapon/armor values?
	- Need to give base weapon/armor stats when the item isn't identified
	- player.info attack and defense take equipment and their enchants, and str modifiers into account via recalculateEquipmentBonuses
		- However, they are "true values"
	- Weapon/armor stats themselves are base; assuming +0 and at the strength level of the player
	- Empowerment alters the creatureType struct creature.info
	- Temp status affects alter the attributes in the creature struct itself (applies to player too)
	- defense = armor + 10 * net enchant
	- Armor values are divided by 10 when shown to the player

- Item identification
	- kinds can be known without knowing item (staves) - how does "kind-based" IDing work?
		No change, just name given by itemName if the kind is marked as identified in the item table
	- what can we actually see from an item on the ground? everything

- When a non-magic item is detected, does it reveal it is +0? Yes
- HALLUCINATION!
	- When hallucinating, you get no monster or floor item descriptions. Monster and item names are randomised.

- When reading a scroll we don't know whether we will end up having to select an item
	- when reading a scroll, pass callbacks to determine the action to take if the scroll targets an item? (stashed)
	- need a bot state parameter - playing, enchanting, identifying, targetting cell
	- but ignore during reporting mode? (no need, act is not run)
- Stairs not given after magic mapping

All the player really knows about a cell is:

- The text description of the highest-priority tile
- The cell's appearance, which may contain info about several layers
- A union of tile flags from all layers
- If not visible, all of these are substituted by their stored "remembered" values

We give

- The tile types (after some censoring) on all layers of all visible cells
- Dungeon and liquid layers on all magic-mapped cells, but only on the turn of use

Is this ok?

Seeds
2 - ench scroll
5 - obstr staff
12 - magic map, halluc

