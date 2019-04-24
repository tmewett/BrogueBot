require 'definitions'

function coords(cell)
    cell = cell - 1
    -- y is inner, x is outer
    return cell // DROWS, cell % DROWS
end

function drop(item)
    if not item.letter then error("cannot interact with an item not in the pack") end
    presskeys("d"..item.letter)
end

-- sample, override to customize
function act()

    for i=1, DCOLS*DROWS do
        if world.flags[i] & HAS_PLAYER > 0 then
            local px, py = coords(i)
            break
        end
    end

    for let, item in pairs(rogue.pack) do
        -- drop stacked items as a test
        if item.quantity > 1 then drop(item) end
    end

    --message(string.format("I am at (%d, %d)", px, py))
    stepto(math.random(1, 8))
end

function pushevents()
    world, rogue = getworld(), {}
    rogue.pack = getpack()
    act()
end
