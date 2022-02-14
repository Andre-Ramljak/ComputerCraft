print("Re-Assemble (RAS)")

-- Get arguments
local function printUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " scan filename x y z")
    print("|--> Scans area and saves blueprint to filename WARNING DESTROYS BLOCKS")
    print(programName .. " print filename")
    print("|--> Prints saved blueprint")
    print(programName .. " blocks filename")
    print("|--> Lists resources required for blueprint")
end

tArgs = { ... }
if #tArgs < 1 then
    printUsage()
    return
end

--====== Configuration =====
worldX = 1
worldY = 1
worldZ = 1


-- Turtle state variables
xPos = 0
yPos = 1
zPos = 1
facing = 0 -- 0 to 3 clockwise
inventory = {}
revInv = {} -- Reverse inventory
revStartInv = {} -- Reverse inventory at start of build

-- World state variables
world = {}
-- Initialise world matrix
function initWorld()
    world = {}
    for x=1,worldX do
        world[x] = {}
        for y=1,worldY do
            world[x][y] = {}
        end
    end
end
initWorld()

--===== Utility functions =====
function normaliseFacing(direction)
    return math.fmod(direction, 4)
end

function normaliseVector(x, y, z)
    return math.clamp(x, 1, -1), math.clamp(y, 1, -1), math.clamp(z, 1, -1)
end

function facingToVector(direction)
    assert(direction >= 0 and direction <= 3, "Direction is out of range")
    
    if direction == 0 then return 1, 0
    elseif direction == 1 then return 0, 1
    elseif direction == 2 then return -1, 0
    elseif direction == 3 then return 0, -1
    end
    assert(false, "Invalid direction")
end

function vectorTofacing(x, z)
    if x == 1 then return 0
    elseif x == -1 then return 2
    elseif z == 1 then return 1
    elseif z == -1 then return 3
    end
    assert(false, "Invalid facing vector")
end

function printPosition()
    print(xPos, ", ", yPos, ", ", zPos)
end

function checkFuelLevel()
    local level = turtle.getFuelLevel()
    if level < 100 then
        print("Turtle low on fuel")
        print("Put fuel in active slot to continue")
        print("Press enter to continue")
        local junk = io.read()
        local ok, err = turtle.refuel()
        if ok then
            local new_level = turtle.getFuelLevel()
            print(("Refuelled %d, current level is %d"):format(new_level - level, new_level))
            print("Press enter to continue")
            junk = io.read()
        else
            print("Refueling failed: ", err ", try again")
            checkFuelLevel()
        end
    end
end


-- Loading and saving blueprint
function enumerateTypes() -- From 1 --> max (inclusive)
    print("Enumerating types...")
    -- Scan through world listing types
    local types = {}
    local revTypes = {}
    local nTypes = 0

    for z=1,worldZ do
        for y=1,worldY do
            for x=1,worldX do
                type = world[x][y][z]
                if types[type] == nil then
                    nTypes = nTypes + 1
                    types[type] = nTypes
                    revTypes[nTypes] = type
                    print("New type [", nTypes, "]: ", type)
                end
            end
        end
    end
    print(nTypes, " types found")

    return types, revTypes, nTypes
end

function saveBlueprint(path)
    print("Saving blueprint...")
    local file = fs.open(path, "w")

    -- Write Header
    file.writeLine(worldX)
    file.writeLine(worldY)
    file.writeLine(worldZ)

    -- Block type information
    local types, revTypes, nTypes = enumerateTypes()
    file.writeLine(nTypes)
    for i=1,nTypes do
        file.writeLine(revTypes[i])
    end

    -- Save blue print
    for z=1,worldZ do
        for y=1,worldY do
            for x=1,worldX do
                file.writeLine(types[world[x][y][z]])
            end
        end
    end

    -- Cleanup
    file.close()
    print("Blueprint saved")
end

function loadBluePrint(path)
    local sPath = shell.resolve(path)
    if not fs.exists(sPath) or fs.isDir(sPath) then
        print("No such file")
        return
    end

    print("Loading blueprint ", sPath, "...")

    lines = {}
    for line in io.lines(sPath) do
        print(line)
    end

    local file = fs.open(path, "r")
    print("File handle: ", file)

    -- Read Header
    worldX = tonumber(file.readLine())
    worldY = tonumber(file.readLine())
    worldZ = tonumber(file.readLine())
    initWorld()

    -- Block type information
    local nTypes = tonumber(file.readLine())
    local revTypes = {}
    print("Loading ", nTypes, " block types:")
    for i=1,nTypes do
        revTypes[i] = file.readLine()
        print("[", i, "] ", revTypes[i])
    end

    -- Load blue print
    print("Loading data size:", worldX, ", ", worldY, ", ", worldZ)
    for z=1,worldZ do
        for y=1,worldY do
            for x=1,worldX do
                local code = file.readLine()
                --print("Read code:", code)
                local type = revTypes[tonumber(code)]
                --print("Read type: ", type)
                world[x][y][z] = type
            end
        end
    end

    file.close()
    print("Blueprint loaded")
end


function listResources(path)
    loadBluePrint(path)
    local types, revTypes, nTypes = enumerateTypes()

    -- Count reasources
    local typeCount = {}
    for i=1,nTypes do
        typeCount[revTypes[i]] = 0
    end

    print("Counting numbers of types...")
    for z=1,worldZ do
        for y=1,worldY do
            for x=1,worldX do
                local type = world[x][y][z]
                typeCount[type]= typeCount[type] + 1
            end
        end
    end

    print("Resources required:")
    for i=1,nTypes do
        print(revTypes[i], " > ", typeCount[revTypes[i]])
    end
end


-- Base movement functions
function turn(direction)
    if direction == 3 then
        turtle.turnLeft()
    else
        local difference = direction - facing
        while difference ~= 0 do
            if difference > 0 then
                turtle.turnRight()
                difference = difference - 1
            else
                turtle.turnLeft()
                difference = difference + 1
            end
        end
    end
    facing = normaliseFacing(direction)
end

function forward(steps)
    -- Calculate new position
    local xVec, zVec = facingToVector(facing)
    xVec = xVec * steps
    zVec = zVec * steps
    xPos = xPos + xVec
    zPos = zPos + zVec

    -- Perform movement
    while steps ~= 0 do
        if steps > 0 then
            if turtle.forward() then
                -- No errors raised
            else
                -- Could not prefrom movement
                print("Front Obstructed; Breaking block")
                turtle.dig()
                turtle.forward()
            end
            steps = steps - 1
        else
            if not turtle.back() then
                -- Could not move backwards
                -- Clear a way
                print("Back Obstructed; Breaking block")
                turtle.turnRight()
                turtle.turnRight()
                turtle.dig()
                turtle.turnRight()
                turtle.turnRight()
                turtle.back()
            end
            steps = steps + 1
        end
    end
end

function up(steps)
    -- Calculate new position
    yPos = yPos + steps

    -- Perform movement
    while steps ~= 0 do
        if steps > 0 then
            if not turtle.up() then
                -- Could not move up
                print("Top Obstructed; Breaking block")
                turtle.digUp()
                turtle.up()
            end
            steps = steps - 1
        else
            if not turtle.down() then
                -- Turtle could not move down
                print("Bottom Obstructed; Breaking block")
                turtle.digDown()
                turtle.down()
            end
            steps = steps + 1
        end
    end
end


-- Compound movement functions
function moveTo(x, y, z)
    --print("Moving: ", xPos, ", ", yPos, ", ", zPos, "->", x, ", ", y, ", ", z)
    local dx = x - xPos
    local dy = y - yPos
    local dz = z - zPos
    --print("|--> Delta: ", dx, ", ", dy, ", ", dz)

    -- Perform x difference
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

    turn(0)
end

function toHome()
    print("Going home...")
    moveTo(0, 1, 1)
    turn(0)
end

-- Inspect block
function inspect(x, y, z)
    -- Go to inspection location
    moveTo(x - 1, y, z)
    turn(0)
    return turtle.inspect()
end


-- Read block values from world (Destructive)
function scan()
    print("Scanning world...")
    local has_block
    local data

    for y=1,worldY do
        for z=1,worldZ do
            for x=1,worldX do
                has_block, data = inspect(x, y, z)
                turtle.dig()
                if has_block == false then
                    data = {}
                    data["name"] = "minecraft:air"
                end
                --print("Read block: ", x, ", ", y ,", ", z, " as: ", data["name"])
                world[x][y][z] = data["name"]
            end
            checkFuelLevel()
        end
    end
    -- Return home
    toHome()
end


-- Scan Inventory
function scanInventory()
    print("Scanning Inventory...")
    inventory = {}
    revInv = {}
    for i=1,16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        inventory[i] = item
        if item ~= nil then
            print("+", i, "> ", item["name"])
            revInv[item["name"]] = i
        end
    end
end


-- Place blocks into world
function fillInventory()
    toHome()
    turn(2)
end

function getBlock(name)
    scanInventory()
    slot = revInv[name]
    if slot == nil then
        print("Ran out of block: ", name)
        print("Please put in inventory then press enter")
        local junk = io.read()
        slot = getBlock(name)
    end
    return slot
end

function placeBlock(name)
    local slot = revStartInv[name]
    if slot == nil then -- Item was not in starting inventory
        if name ~= "minecraft:air" then
            print("Missing block: ", name)
        end
        --[[
        scanInventory()
        slot = revInv[name]
        if slot == nil then
            print("ERROR: Block not in inv: ", name)
        else
            turtle.select(slot)
            turtle.placeDown()
        end
        ]]--
    else
        slot = revInv[name] -- Get updated inventry location
        --local count = turtle.getItemCount(slot)
        if slot == nil or turtle.getItemCount(slot) == 0 then -- Is no longer in inventory
            print("Stack empty for: ", name)
            slot = getBlock(name)
        end
        turtle.select(slot)
        turtle.placeDown()
    end
end

function build()
    toHome()
    print("Building...")
    scanInventory()
    revStartInv = revInv

    for y=1,worldY do
        moveTo(0, y + 1, 1)
        for z=worldZ,1,-1 do
            moveTo(0, y + 1, z)
            for x=worldX,1,-1 do
                local name = world[x][y][z]
                --print("Place block: ", x, ", ", y ,", ", z, " as: ", name)
                moveTo(x, y + 1, z)
                turn(0)
                placeBlock(name)
            end
            checkFuelLevel()
        end
    end
end

-- Main function
local sCommand = tArgs[1]
if sCommand == "scan" then
    print("Scanning...")
    worldX = tonumber(tArgs[3])
    worldY = tonumber(tArgs[4])
    worldZ = tonumber(tArgs[5])
    print("Scan Size:", worldX, ", ", worldY, ", ", worldZ)
    initWorld()
    scan()
    saveBlueprint(tArgs[2])
elseif sCommand == "print" then
    print("Printing...")
    loadBluePrint(tArgs[2])
    build()
elseif sCommand == "blocks" then
    print("Displaying required resources")
    listResources(tArgs[2])
else
    print("Invalid command")
    printUsage()
end


-- Return home at end
toHome()