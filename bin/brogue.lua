require 'definitions'

function coords(cell)
    cell = cell - 1
    -- y is inner, x is outer
    return cell // DROWS, cell % DROWS
end

function pushevents()
    world = getworld()
    for i=1, DCOLS*DROWS do
        if world.flags[i] & HAS_PLAYER > 0 then
            px, py = coords(i)
            break
        end
    end
    message(string.format("I am at (%d, %d)", px, py))
    stepto(math.random(0, 7))
end
