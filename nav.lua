-- ===INERTIAL NAVIGATION PROGRAM===

local nav = {}

-- ==CONFIGURATION==
local cachePath = "pos.nav"

-- State Variables
nav.posX = 1
nav.posY = 1
nav.posZ = 1
nav.facing = 0
nav.homeX = 1
nav.homeY = 1
nav.homeZ = 1

-- ===== Utility =====

function normaliseFacing(direction)
    return math.fmod(direction, 4)
end

function normaliseVector(x, y, z)
    return math.clamp(x, 1, -1), math.clamp(y, 1, -1), math.clamp(z, 1, -1)
end

function facingToVector(direction)
    assert(direction >= 0 and direction <= 3, "NAV: Direction is out of range")
    
    if direction == 0 then return 1, 0
    elseif direction == 1 then return 0, 1
    elseif direction == 2 then return -1, 0
    elseif direction == 3 then return 0, -1
    end
    assert(false, "NAV: Invalid direction")
end

function vectorToFacing(x, z)
    if x == 1 then return 0
    elseif x == -1 then return 2
    elseif z == 1 then return 1
    elseif z == -1 then return 3
    end
    assert(false, "NAV: Invalid facing vector")
end

function printPosition()
    print("NAV: Pos:", posX, ", ", posY, ", ", posZ)
end


-- ===== Persistant Data =====

local function savePos()
    -- Save state variables to file
    local file = fs.open(cachePath, "w")
    file.writeLine(nav.posX)
    file.writeLine(nav.posY)
    file.writeLine(nav.posZ)
    file.writeLine(nav.facing)
    file.close()
end

local function loadPos()
    -- Check for existance of file
    if not fs.exists(cachePath) then
        -- Cache file does not exist, ignore
        print("NAV: Cache file does not exist")
        return false
    else
        -- Read state variables from file
        local file = fs.open(cachePath, "r")
        nav.posX = file.readLine()
        nav.posY = file.readLine()
        nav.posZ = file.readLine()
        nav.facing = file.readLine()
        file.close()
        return true
    end
end


-- ===== Movement util =====

local function tryForward()
    if not turtle.forward() then
        print("NAV: F Obstructed! Breaking block")
        turtle.dig()
        tryForward()
    end
end

local function tryBack()
    if not turtle.back() then
        print("NAV: B Obstructed; Breaking block")
        turtle.turnRight()
        turtle.turnRight()
        turtle.dig()
        turtle.turnRight()
        turtle.turnRight()
        tryBack()
    end
end

local function tryUp()
    if not turtle.up() then
        -- Could not move up
        print("Top Obstructed; Breaking block")
        turtle.digUp()
        tryUp()
    end
end

local function tryDown()
    if not turtle.down() then
        -- Turtle could not move down
        print("Bottom Obstructed; Breaking block")
        turtle.digDown()
        tryDown()
    end
end

-- ================================================
-- PUBLIC API
-- ================================================

-- ===== Initialisation =====

function nav.init()
    return loadPos()
end

function nav.setPosition(x, y, z, facing)
    nav.posX = x
    nav.posY = y
    nav.posZ = z
    nav.facing = 0
    savePos()
end


-- ===== Base Movement =====
function nav.turn(direction) -- (0 <= direciton <= 3)
    -- Find optimum rotation direction
    local rotDir -- true = clockwise, false = anti-clockwise
    local delta = direction - nav.facing

    -- Handle rotation encoding disjoint
    if delta == -3 then
        delta = 1
    elseif delta == 3 then
        delta = -1
    end

    -- Perform rotations
    if delta == 1 then
        turtle.turnRight()
    elseif delta == -1 then
        turtle.turnLeft()
    elseif delta == 2 then
        turtle.turnRight()
        turtle.turnRight()
    end

    -- Set end direction
    nav.facing = normalisenav.facing(direction)
end

function nav.forward(steps)
    -- Calculate delta
    local xVec, zVec = facingToVector(nav.facing)
    xVec = xVec * steps
    zVec = zVec * steps
    
    -- Perform movement
    while steps ~= 0 do
        if steps > 0 then -- Forward
            tryForward()
            steps = steps - 1
        else -- Backward
            tryBack()
            steps = steps + 1
        end
    end

    -- Set end position
    nav.posX = nav.posX + xVec
    nav.posZ = nav.posZ + zVec
end

function nav.up(steps)
    while steps ~= 0 do
        if steps > 0 then -- Up
            tryUp()
            steps = steps - 1
        else -- Down
            tryDown()
            steps = steps + 1
        end
    end

    -- Set end position
    nav.posY = nav.posY + steps
end


-- ===== Compound Movement =====

function nav.go(x, y, z, facing)
    nav.facing = facing or 0 -- Default parameter

    -- Calculate delta vector
    local dx = x - nav.posX
    local dy = y - nav.posY
    local dz = z - nav.posZ

    -- Perform x delta
    if dx ~= 0 then
        turn(0)
        forward(dx)
    end
    -- Perform z difference
    if dz ~= 0 then
        turn(1)
        forward(dz)
    end
    -- Perform y difference
    if dy ~= 0 then
        up(dy)
    end
    -- Perfrom rotation
    turn(nav.facing)
end

return nav