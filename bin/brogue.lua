require 'definitions'

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

-- returns a table all 8 cells in the neighborhood of the cell, indexed by direction
function neighborhood(cell)
    return {
        [UP]          = isinworld(cell - 1        ) or nil,
        [DOWN]        = isinworld(cell + 1        ) or nil,
        [LEFT]        = isinworld(cell - DROWS    ) or nil,
        [RIGHT]       = isinworld(cell + DROWS    ) or nil,
        [UPLEFT]      = isinworld(cell - DROWS - 1) or nil,
        [DOWNLEFT]    = isinworld(cell - DROWS + 1) or nil,
        [UPRIGHT]     = isinworld(cell + DROWS - 1) or nil,
        [DOWNRIGHT]   = isinworld(cell + DROWS + 1) or nil
    }
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
    world, rogue = getworld(), getplayer()
    rogue.pack = getpack()
    creatures = getcreatures()
    act()
end
