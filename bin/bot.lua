require 'brogue'

function act()

    local pcell = rogue.cell

    for let, item in pairs(rogue.pack) do
        if item.quantity > 1 then return drop(item) end
    end

    if #creatures > 0 then
        local cell = creatures[1].cell
        local dmap = distancemap(cell, 0)
        local dir = nextstep(pcell, dmap)
        stepto(dir)
        return
    end

    --message(string.format("I am at (%d, %d)", px, py))
    stepto(math.random(1, 8))
end

