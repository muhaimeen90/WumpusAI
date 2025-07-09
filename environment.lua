-- environment.lua
-- Handles the Wumpus World grid, its contents, and initialization.
-- Team Member 1: Environment & Percepts

local Environment = {}

-- Constants for grid dimensions
Environment.GRID_SIZE = 10
Environment.START_X = 1
Environment.START_Y = 1

-- Internal representation of the world grid
-- Each cell will be a table with properties like:
-- { has_wumpus = false, is_wumpus_alive = false, has_pit = false, has_gold = false, is_visited = false }
local world_grid = {}
local wumpus_location = nil -- Stores {x, y} of the wumpus
local gold_location = nil   -- Stores {x, y} of the gold

-- Helper function to check if coordinates are within the grid
function Environment.is_valid_coord(x, y)
    return x >= 1 and x <= Environment.GRID_SIZE and y >= 1 and y <= Environment.GRID_SIZE
end

-- Helper function to get the content of a specific cell
function Environment.get_cell(x, y)
    if not Environment.is_valid_coord(x, y) then
        return nil -- Or throw an error, depending on desired error handling
    end
    return world_grid[y][x]
end

-- Helper function to set the content of a specific cell
-- function Environment.set_cell(x, y, data)
--     if not Environment.is_valid_coord(x, y) then
--         -- Handle invalid coordinates if necessary
--         return
--     end
--     -- Merge new data with existing cell data
--     for k, v in pairs(data) do
--         world_grid[y][x][k] = v
--     end
-- end
function Environment.set_cell(x, y, properties)
    if not world_grid[y] then
        world_grid[y] = {}
    end
    if not world_grid[y][x] then
        world_grid[y][x] = {}
    end
    
    -- Apply the provided properties
    for key, value in pairs(properties) do
        world_grid[y][x][key] = value
    end
end

-- --- Initialization Functions ---

-- Clears the grid and resets all cell properties
local function initialize_empty_grid()
    for y = 1, Environment.GRID_SIZE do
        world_grid[y] = {}
        for x = 1, Environment.GRID_SIZE do
            world_grid[y][x] = {
                has_wumpus = false,
                is_wumpus_alive = false, -- Only true if has_wumpus is also true
                has_pit = false,
                has_gold = false,
                is_visited = false       -- Agent's internal state, but useful for display/debug
            }
        end
    end
    wumpus_location = nil
    gold_location = nil
end

-- Places objects (Wumpus, Gold, Pits) randomly on the grid
function Environment.generate_random_environment()
    initialize_empty_grid()

    -- Place Wumpus (not in [1,1])
    repeat
        local wx = math.random(1, Environment.GRID_SIZE)
        local wy = math.random(1, Environment.GRID_SIZE)
        if not (wx == Environment.START_X and wy == Environment.START_Y) then
            Environment.set_cell(wx, wy, { has_wumpus = true, is_wumpus_alive = true })
            wumpus_location = {x = wx, y = wy}
            break
        end
    until false

    -- Place Gold (not in [1,1])
    repeat
        local gx = math.random(1, Environment.GRID_SIZE)
        local gy = math.random(1, Environment.GRID_SIZE)
        if not (gx == Environment.START_X and gy == Environment.START_Y) and not (gx == wumpus_location.x and gy == wumpus_location.y) then
            Environment.set_cell(gx, gy, { has_gold = true })
            gold_location = {x = gx, y = gy}
            break
        end
    until false

    -- Place Pits (probability 0.2, not in [1,1])
    for y = 1, Environment.GRID_SIZE do
        for x = 1, Environment.GRID_SIZE do
            if not (x == Environment.START_X and y == Environment.START_Y) then
                if math.random() < 0.2 then -- 20% chance
                    Environment.set_cell(x, y, { has_pit = true })
                end
            end
        end
    end

    -- Ensure [1,1] is safe
    Environment.set_cell(Environment.START_X, Environment.START_Y, { has_wumpus = false, is_wumpus_alive = false, has_pit = false, has_gold = false })

    print("Random environment generated.")
end

-- Loads environment from a coordinate-based file
-- Expected file format (one entity per line):
-- W x y
-- G x y
-- P x y
function Environment.load_environment_from_file(filename)
    initialize_empty_grid()

    local file = io.open("env_samples/" .. filename, "r")
    if not file then
        error("Could not open environment file: " .. filename)
    end

    for line in file:lines() do
        local type_char, x_str, y_str = line:match("^(%S+)%s+(%d+)%s+(%d+)$")
        local x = tonumber(x_str)
        local y = tonumber(y_str)

        if not Environment.is_valid_coord(x, y) then
            print(string.format("Warning: Invalid coordinates %d,%d in file for %s. Skipping.", x, y, type_char))
            goto continue -- Skip to next line
        end

        if type_char == "W" then
            Environment.set_cell(x, y, { has_wumpus = true, is_wumpus_alive = true })
            wumpus_location = {x = x, y = y}
        elseif type_char == "G" then
            Environment.set_cell(x, y, { has_gold = true })
            gold_location = {x = x, y = y}
        elseif type_char == "P" then
            Environment.set_cell(x, y, { has_pit = true })
        else
            print("Warning: Unknown entity type '" .. type_char .. "' in environment file. Skipping.")
        end
        ::continue::
    end
    file:close()

    -- Ensure [1,1] is safe, as per Wumpus World rules. This overrides file content if any.
    Environment.set_cell(Environment.START_X, Environment.START_Y, { has_wumpus = false, is_wumpus_alive = false, has_pit = false, has_gold = false })

    print("Environment loaded from file: " .. filename)
end

-- Loads environment from a grid-based file (as per project description)
-- Expected format: 10 lines, each with 10 characters (W, G, P, or -)
function Environment.load_grid_environment_from_file(filename)
    initialize_empty_grid()

    local file = io.open("env_samples/" .. filename, "r")
    if not file then
        error("Could not open environment file: " .. filename)
    end

    local grid = {}
    local line_count = 0
    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$") -- Trim whitespace
        if #line ~= Environment.GRID_SIZE then
            print("Warning: Line " .. (line_count + 1) .. " has incorrect length. Expected 10 characters.")
            file:close()
            return
        end
        table.insert(grid, line) -- Insert in order (no y-flip)
        line_count = line_count + 1
    end
    file:close()

    if line_count ~= Environment.GRID_SIZE then
        print("Warning: File does not contain exactly 10 lines.")
        return
    end

    for y = 1, Environment.GRID_SIZE do
        for x = 1, Environment.GRID_SIZE do
            local char = grid[y]:sub(x, x)
            if char == "W" then
                Environment.set_cell(x, y, { has_wumpus = true, is_wumpus_alive = true })
                wumpus_location = {x = x, y = y} -- Last Wumpus found is stored
            elseif char == "G" then
                Environment.set_cell(x, y, { has_gold = true })
                gold_location = {x = x, y = y}
            elseif char == "P" then
                Environment.set_cell(x, y, { has_pit = true })
            elseif char ~= "-" then
                print("Warning: Unknown character '" .. char .. "' at [" .. x .. "," .. y .. "]. Treating as empty.")
            end
        end
    end

    -- Ensure [1,1] is safe
    Environment.set_cell(Environment.START_X, Environment.START_Y, { has_wumpus = false, is_wumpus_alive = false, has_pit = false, has_gold = false })

    print("Grid environment loaded from file: " .. filename)
end

-- --- Environment State Modification Functions (called by agent actions) ---

-- Kills the wumpus if it's at the given location and alive
function Environment.kill_wumpus_at(x, y)
    local cell = Environment.get_cell(x, y)
    if cell and cell.has_wumpus and cell.is_wumpus_alive then
        cell.is_wumpus_alive = false
        print(string.format("Wumpus at [%d,%d] has been killed!", x, y))
        return true -- Wumpus was killed
    end
    return false -- No wumpus or already dead
end

-- Removes gold from the current cell if present
function Environment.remove_gold_at(x, y)
    local cell = Environment.get_cell(x, y)
    if cell and cell.has_gold then
        cell.has_gold = false
        gold_location = nil -- Gold is now gone from the world
        print(string.format("Gold removed from [%d,%d].", x, y))
        return true -- Gold was picked up
    end
    return false -- No gold to pick up
end

-- --- Query Functions for Percepts ---
-- These are used by percepts.lua and potentially the UI.

-- Returns the full grid for UI or debugging purposes
function Environment.get_grid()
    return world_grid
end

-- Returns the Wumpus's current alive status (true/false)
function Environment.is_wumpus_alive()
    if wumpus_location then
        local cell = Environment.get_cell(wumpus_location.x, wumpus_location.y)
        return cell and cell.is_wumpus_alive
    end
    return false -- No wumpus in the world
end

-- Returns the Wumpus's location
function Environment.get_wumpus_location()
    return wumpus_location
end

-- Returns the Gold's location
function Environment.get_gold_location()
    return gold_location
end

return Environment