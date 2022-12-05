require 'brogue'
std = require 'std'
fn = require 'std.functional'
tb = require 'std.table'
require 'debugger'

function appendto(seq, el)
	seq[#seq+1] = el
end

-- ~ EXPLOREFLAGS = T_IS_DEEP_WATER | T_CAUSES_POISON | T_IS_FIRE | T_LAVA_INSTA_DEATH | T_AUTO_DESCENT
EXPLOREFLAGS = T_PATHING_BLOCKER

foodturns = {
	[RATION] = 1800,
	[FRUIT] = 1550
}

function isfrontier(cell)
	if not cellknown(cell)
		or hastileflag(cell, T_OBSTRUCTS_PASSABILITY)
	then return false end
	
	for d, c in pairs(neighborhood(cell)) do
		if not cellknown(c) and not canstepto(cell, d) then return true end
	end
	return false
end

function ischokepoint(cell)
	if hastileflag(cell, T_OBSTRUCTS_PASSABILITY) then return false end
	
	local dirs = 0
	for d, c in pairs(neighborhood(cell)) do
		if cellknown(c) and not hastileflag(c, T_PATHING_BLOCKER) and canstepto(cell, d)
		then dirs = dirs+1 end
	end
	
	return dirs <= 2
end

function valuecosts(c)
	local carriedturns = 0
	for it in std.elems(rogue.pack) do 
		if it.category == FOOD then carriedturns = carriedturns + foodturns[it.kind] end
	end
	return c.turns + 1800 * c.food + (rogue.statuses[STATUS_NUTRITION] + carriedturns) / rogue.hp * c.hp
end

plans = {}

function plans.explore()
	local target = fn.foldl(closer(pathdmap), explorables)
	if not target then return end
	return {
		costs = {food = -1/3},
		children = {plans.moveto(target)}
	}
end

function plans.descend()
	if not world.downstairs then return end
	return {
		costs = {},
		children = {plans.moveto(world.downstairs)}
	}
end

function plans.fightmonsters()
	local hunting = fn.filter(function (cr) return cr.state == MONSTER_HUNTING end,
		std.elems, creatures)
	local children = fn.map(plans.defeat, std.elems, hunting)
	
	-- ~ if #hunting > 1 then 
		-- ~ local chk = fn.foldl(closer(chokedmap), chokepoints)
		-- ~ if chk then appendto(children, plans.moveto(chk)) end
	-- ~ end
	
	return {
		costs = {},
		children = children
	}
end

function plans.defeat(monst)
	return {
		costs = {turns=-1000},
		children = {plans.moveto(monst.cell)}
	}
end

function plans.moveto(cell)
	local d = pathdmap[cell]
	local dmap = distancemap({cell}, EXPLOREFLAGS)
	return {
		costs = {turns = d},
		children = {function () return stepto(nextstep(rogue.cell, dmap)) end}
	}
end


function act()

	pathdmap = distancemap({rogue.cell}, EXPLOREFLAGS)
	allcells = tb.keys(world.lastseen)
	explorables = fn.filter(isfrontier, std.elems, allcells)
	
	chokepoints = fn.filter(ischokepoint, std.elems, allcells)
	chokedmap = distancemap(chokepoints, EXPLOREFLAGS)

	local masterplan = {
		costs = {},
		children = {
			plans.explore(),
			plans.descend(),
			plans.fightmonsters(),
		}
	}
	
	local actions = planactions(masterplan)
	return bestaction(actions)()
end

function addmerge(t1, t2)
	for k,v in pairs(t1) do 
		t1[k] = t1[k] + (t2[k] or 0)
	end
end

-- Given a plan, returns a table of all possible actions that could be taken to perform
-- said plan. The table is of [fun]=cost pairs, where fun is a function that when executed
-- emits the relevant events, and cost is a number representing how many resources are
-- required to complete that branch of the plan.
function planactions(plan, acts, costs)
	acts = acts or {}
	costs = costs or {
		turns=0,
		food=0,
		hp=0
	}
	
	if type(plan) == 'function' then
		acts[plan] = valuecosts(costs)
		return
	end

	addmerge(costs, plan.costs)
	for c in std.elems(plan.children) do
		planactions(c, acts, tb.clone(costs))
	end
	
	return acts
end

function bestaction(acts)
	local f, min
	for fun, val in pairs(acts) do 
		if not min or val < min then 
			f = fun
			min = val
		end
	end
	return f
end
