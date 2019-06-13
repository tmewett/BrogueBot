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
function isinworld(cell)
    return cell >= 1 and cell <= DROWS*DCOLS and cell
end

function discovered(cell)
    return world.lastseen[cell] and true
end

-- returns a truthy value if we know we are unobstructed when stepping in direction dir from cell
function canstepto(cell, dir)
    local step = cell + celldiffs[dir]
    if not discovered(step) or hastileflag(step, T_OBSTRUCTS_PASSABILITY) then return false end

    -- now we know step is discovered and unobstructed
    local x1,y1 = tocoords(cell)
    local x2,y2 = tocoords(step)
    if x1==x2 or y1==y2 then return true end

    local d1, d2 = tocell(x1,y2), tocell(x2,y1)
    return discovered(d1) and discovered(d2) and not
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

-- returns a table all 8 cells in the neighborhood of the cell, indexed by direction
function neighborhood(cell)
    local t = {}
    for dir, v in pairs(celldiffs) do
        t[dir] = isinworld(cell + v)
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

function drop(item)
    if not item.letter then error("cannot interact with an item not in the pack") end
    presskeys("d"..item.letter)
end

function throw(item, cell)
    if not item.letter then error("cannot interact with an item not in the pack") end
    presskeys("t"..item.letter)
    clickcell(cell)
end

function pushevents()

    rogue = getplayer()

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

        if not world.downstairs and fl & HAS_DOWN_STAIRS > 0 then
            world.downstairs = cell
        end
        if not world.upstairs and fl & HAS_UP_STAIRS > 0 then
            world.upstairs = cell
        end
    end

    levels[rogue.depth] = world

    rogue.pack = pack
    creatures = getcreatures()
    items = getitems()
    act()

end
