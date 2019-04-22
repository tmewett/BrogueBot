require 'definitions'

function coords(cell)
    cell = cell - 1
    -- y is inner, x is outer
    return cell // DROWS, cell % DROWS
end

-- sample, override to customize
function act(world, rogue)

    for i=1, DCOLS*DROWS do
        if world.flags[i] & HAS_PLAYER > 0 then
            local px, py = coords(i)
            break
        end
    end

    for let, item in pairs(rogue.pack) do
        -- drop stacked items as a test
        if item.quantity > 1 then presskeys("d"..let) end
    end

    --message(string.format("I am at (%d, %d)", px, py))
    stepto(math.random(1, 8))
end

function pushevents()
    local world, rogue = getworld(), {}
    rogue.pack = getpack()
    act(world, rogue)
end
