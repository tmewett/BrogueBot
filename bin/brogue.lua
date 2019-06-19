require 'definitions'

levels = {}

function tocoords(cell)
    local cell = cell - 1
    -- y is inner, x is outer
    return cell // DROWS + 1, cell % DROWS + 1
end

function tocell(x, y)
    return (x-1) * DROWS + y
end

-- returns a layer of the cell which has flag tf, or false if none do
function hastileflag(cell, tf)
    return tileflags(world.dungeon[cell]) & tf > 0 and "dungeon"
        or tileflags(world.surface[cell]) & tf > 0 and "surface"
        or tileflags(world.liquid[cell]) & tf > 0 and "liquid"
        or tileflags(world.gas[cell]) & tf > 0 and "gas"
end

-- returns cell if cell is a valid index, false otherwise
function iscell(cell)
    return cell >= 1 and cell <= DROWS*DCOLS and cell
end

function cellknown(cell)
    return world.lastseen[cell] and true
end

-- returns a truthy value if we know we are unobstructed when stepping in direction dir from cell
function canstepto(cell, dir)
    local step = cell + celldiffs[dir]
    if not cellknown(step) or hastileflag(step, T_OBSTRUCTS_PASSABILITY) then return false end

    -- now we know step is discovered and unobstructed
    local x1,y1 = tocoords(cell)
    local x2,y2 = tocoords(step)
    if x1==x2 or y1==y2 then return true end

    local d1, d2 = tocell(x1,y2), tocell(x2,y1)
    return cellknown(d1) and cellknown(d2) and not
        (hastileflag(d1, T_OBSTRUCTS_DIAGONAL_MOVEMENT) or hastileflag(d2, T_OBSTRUCTS_DIAGONAL_MOVEMENT))
end

celldiffs = {
    [UP]          = -1,
    [DOWN]        = 1,
    [LEFT]        = -DROWS,
    [RIGHT]       = DROWS,
    [UPLEFT]      = -DROWS - 1,
    [DOWNLEFT]    = -DROWS + 1,
    [UPRIGHT]     = DROWS - 1,
    [DOWNRIGHT]   = DROWS + 1
}

local function wraps(c1, c2)
    if c2 < c1 then c1, c2 = c2, c1 end
    return c1 % DROWS == 0 and c2 == c1 + 1
end

-- returns a table all 8 cells in the neighborhood of the cell, indexed by direction
function neighborhood(cell)
    local t = {}
    for dir, v in pairs(celldiffs) do
        t[dir] = not wraps(cell, cell+v) and iscell(cell+v) or nil
    end
    return t
end

-- returns the direction from the cell of a path of shortest distance, according to distmap
function nextstep(cell, distmap)
    if distmap[cell] == UNREACHABLE or distmap[cell] == 0 then return nil end

    local sdist, sdir = UNREACHABLE, nil
    for dir, ncell in pairs(neighborhood(cell)) do
        if distmap[ncell] < sdist and canstepto(cell, dir) then
            sdir = dir
            sdist = distmap[ncell]
        end
    end

    return sdir
end

function hitprobability(defender, attacker)
    attacker = attacker or rogue
    local deffactor = 0.987
    local prob = attacker.accuracy * math.pow(deffactor, defender.defense) / 100
    return math.max(0.0, math.min(1.0, prob))
end

function averagedamage(cr)
    return (cr.maxdamage + cr.mindamage) / 2
end

function expecteddamages(target, attacker)
    attacker = attacker or rogue

    local avgout = hitprobability(target, attacker) * averagedamage(attacker)
    local avgin = hitprobability(attacker, target) * averagedamage(target)

    local tickstokill = target.hp / avgout * attacker.attackticks
    return tickstokill / target.attackticks * avgin
end

function drop(item)
    if not item.letter then error("cannot interact with an item not in the pack") end
    presskeys("d"..item.letter)
end

function throw(item, cell)
    if not item.letter then error("cannot interact with an item not in the pack") end
    presskeys("t"..item.letter)
    clickcell(cell)
end

function apply(item, choice)
    if not item.letter then error("cannot interact with an item not in the pack") end
    presskeys("a"..item.letter)
    lastapply = {item, choice, debug.getinfo(2, "Sl")}
end

local scrollsel = {
    [1] = "onenchant",
    [2] = "onidentify"
}
local choicechecks = {
    [1] = function (it) return it.category & CAN_BE_ENCHANTED > 0 end,
    [2] = function (it) return it.flags & ITEM_CAN_BE_IDENTIFIED > 0 end
}

function pushevents()

    local newrogue = getplayer()

    -- if action is non-zero, we need to make a decision
    if newrogue.action > 0 then
        local applied, choice, info = table.unpack(lastapply)
        local applyloc = info.short_src .. ":" .. info.currentline

        if newrogue.action == 3 then
            assert(choice and iscell(choice), "cell choice required for apply at "..applyloc)
            clickcell(choice)
        else
            -- choice omitted or scroll not identified? then fetch from global variable
            local name
            if not (choice and applied.kind) then
                name = scrollsel[newrogue.action]
                choice = _ENV[name]
            end
            assert(choice, (name or "item choice") .. " required but not defined at "..applyloc)

            if type(choice) == "function" then choice = choice() end

            assert(choice.letter and choicechecks[newrogue.action](choice),
                (name or "argument") .. " gave invalid item for apply at "..applyloc)

            presskeys(choice.letter)
        end

        -- This code is run with the state of the previous invocation, which is fine as no turns passed.
        -- Now we've made a decision we need to get new state, so return.
        return
    end

    rogue = newrogue
    local pack = getpack()
    rogue.weapon = pack[rogue.weapon]
    rogue.armor = pack[rogue.armor]

    local rings = {pack[rogue.leftring], pack[rogue.rightring]}
    rogue.rings = {}
    if rings[1] then rogue.rings[rings[1]] = true end
    if rings[2] then rogue.rings[rings[2]] = true end
    rogue.leftring = nil
    rogue.rightring = nil

    local seenworld = getworld()
    world = levels[rogue.depth] or {}
    world.lastseen = world.lastseen or {}

    for attr, t in pairs(seenworld) do
        world[attr] = world[attr] or {}
        for i, x in pairs(t) do
            world[attr][i] = x
        end
    end

    for cell, fl in pairs(seenworld.flags) do
        -- set lastseen value for magic-mapped cells to -1
        if fl & DISCOVERED == 0 and fl & MAGIC_MAPPED > 0 then
            world.lastseen[cell] = -1
            -- we only get info about dungeon and liquid layers
            world.surface[cell] = 0
            world.gas[cell] = 0
            -- hide unknown information
            world.flags[cell] = fl & ~(HAS_MONSTER | HAS_DORMANT_MONSTER | HAS_ITEM | IS_IN_SHADOW)
        else
            world.lastseen[cell] = rogue.turn
        end

        if not world.downstairs and world.dungeon[cell] == 12 then
            world.downstairs = cell
        end
        if not world.upstairs and world.dungeon[cell] == 13 then
            world.upstairs = cell
        end
    end

    levels[rogue.depth] = world

    rogue.pack = pack
    creatures = getcreatures()
    items = getitems()
    act()

end
