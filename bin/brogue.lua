require 'definitions'

levels = {}

function coords(cell)
    local cell = cell - 1
    -- y is inner, x is outer
    return cell // DROWS + 1, cell % DROWS + 1
end

function cell(x, y)
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

-- returns a truthy value if we can move diagonally between two adjacent cells, false otherwise
function diagonalblocked(cell1, cell2)
    local x1,y1 = coords(cell1)
    local x2,y2 = coords(cell2)
    return hastileflag(cell(x1,y2), T_OBSTRUCTS_DIAGONAL_MOVEMENT)
        or hastileflag(cell(x2,y1), T_OBSTRUCTS_DIAGONAL_MOVEMENT)
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
        if distmap[ncell] < sdist and not diagonalblocked(cell, ncell) then
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

function pushevents()

    local pack = getpack()
    rogue = getplayer()
    rogue.weapon = pack[rogue.weapon]
    rogue.armor = pack[rogue.armor]

    local seenworld = getworld()
    world = levels[rogue.depth] or {}
    world.lastseen = world.lastseen or {}

    for attr, t in pairs(seenworld) do
        world[attr] = world[attr] or {}
        for i, x in pairs(t) do
            world[attr][i] = x
            world.lastseen[i] = rogue.turn
        end
    end

    levels[rogue.depth] = world

    rogue.pack = pack
    creatures = getcreatures()
    items = getitems()
    act()

end
