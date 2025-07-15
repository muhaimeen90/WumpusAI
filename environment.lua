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

-- Places objects (Wumpus, Gold, Pits) randomly on the grid with controlled distribution
function Environment.generate_random_environment()
    initialize_empty_grid()
    
    -- Create a list of valid positions (excluding [1,1] and adjacent cells for safety)
    local valid_positions = {}
    local safe_zone = {
        {1, 1}, {1, 2}, {2, 1}, {2, 2}  -- Keep starting area safe
    }
    
    for y = 1, Environment.GRID_SIZE do
        for x = 1, Environment.GRID_SIZE do
            local is_safe_zone = false
            for _, safe_pos in ipairs(safe_zone) do
                if x == safe_pos[1] and y == safe_pos[2] then
                    is_safe_zone = true
                    break
                end
            end
            if not is_safe_zone then
                table.insert(valid_positions, {x = x, y = y})
            end
        end
    end

    -- Place exactly 3 Wumpuses
    local num_wumpuses = 3
    local placed_wumpuses = 0
    local wumpus_locations = {}
    
    for i = 1, num_wumpuses do
        if #valid_positions > 0 then
            local wumpus_index = math.random(1, #valid_positions)
            local wumpus_pos = valid_positions[wumpus_index]
            Environment.set_cell(wumpus_pos.x, wumpus_pos.y, { has_wumpus = true, is_wumpus_alive = true })
            table.insert(wumpus_locations, {x = wumpus_pos.x, y = wumpus_pos.y})
            table.remove(valid_positions, wumpus_index)
            placed_wumpuses = placed_wumpuses + 1
        end
    end
    
    -- Set the first wumpus as the primary one for legacy compatibility
    if #wumpus_locations > 0 then
        wumpus_location = wumpus_locations[1]
    end

    -- Place Gold (not in same cell as any Wumpus)
    local gold_index = math.random(1, #valid_positions)
    local gold_pos = valid_positions[gold_index]
    Environment.set_cell(gold_pos.x, gold_pos.y, { has_gold = true })
    gold_location = {x = gold_pos.x, y = gold_pos.y}
    table.remove(valid_positions, gold_index)

    -- Place exactly 3 Pits strategically distributed
    local num_pits = 3
    local placed_pits = 0
    
    -- Divide grid into quadrants for better distribution
    local quadrants = {
        {min_x = 1, max_x = 5, min_y = 1, max_y = 5},      -- Top-left
        {min_x = 6, max_x = 10, min_y = 1, max_y = 5},     -- Top-right
        {min_x = 1, max_x = 5, min_y = 6, max_y = 10},     -- Bottom-left
        {min_x = 6, max_x = 10, min_y = 6, max_y = 10}     -- Bottom-right
    }
    
    -- Try to place at least one pit in different quadrants
    for _, quadrant in ipairs(quadrants) do
        if placed_pits >= num_pits then break end
        
        -- Find valid positions in this quadrant
        local quadrant_positions = {}
        for _, pos in ipairs(valid_positions) do
            if pos.x >= quadrant.min_x and pos.x <= quadrant.max_x and
               pos.y >= quadrant.min_y and pos.y <= quadrant.max_y then
                table.insert(quadrant_positions, pos)
            end
        end
        
        -- Place a pit in this quadrant if possible
        if #quadrant_positions > 0 and math.random() < 0.7 then -- 70% chance per quadrant
            local pit_index = math.random(1, #quadrant_positions)
            local pit_pos = quadrant_positions[pit_index]
            
            -- Find and remove from main valid_positions list
            for i, pos in ipairs(valid_positions) do
                if pos.x == pit_pos.x and pos.y == pit_pos.y then
                    Environment.set_cell(pit_pos.x, pit_pos.y, { has_pit = true })
                    table.remove(valid_positions, i)
                    placed_pits = placed_pits + 1
                    break
                end
            end
        end
    end
    
    -- Fill remaining pit slots randomly if needed
    while placed_pits < num_pits and #valid_positions > 0 do
        local pit_index = math.random(1, #valid_positions)
        local pit_pos = valid_positions[pit_index]
        Environment.set_cell(pit_pos.x, pit_pos.y, { has_pit = true })
        table.remove(valid_positions, pit_index)
        placed_pits = placed_pits + 1
    end

    -- Ensure starting area is completely safe
    for _, safe_pos in ipairs(safe_zone) do
        Environment.set_cell(safe_pos[1], safe_pos[2], { 
            has_wumpus = false, 
            is_wumpus_alive = false, 
            has_pit = false, 
            has_gold = false 
        })
    end

    print("Random environment generated with " .. placed_pits .. " pits, " .. placed_wumpuses .. " Wumpuses, and 1 Gold.")
end

-- Loads environment from a coordinate-based file
-- Expected file format (one entity per line):
-- W x y
-- G x y
-- P x y
-- function Environment.load_environment_from_file(filename)
--     initialize_empty_grid()

--     local file = io.open("env_samples/" .. filename, "r")
--     if not file then
--         error("Could not open environment file: " .. filename)
--     end

--     for line in file:lines() do
--         local type_char, x_str, y_str = line:match("^(%S+)%s+(%d+)%s+(%d+)$")
--         local x = tonumber(x_str)
--         local y = tonumber(y_str)

--         if not Environment.is_valid_coord(x, y) then
--             print(string.format("Warning: Invalid coordinates %d,%d in file for %s. Skipping.", x, y, type_char))
--             goto continue -- Skip to next line
--         end

--         if type_char == "W" then
--             Environment.set_cell(x, y, { has_wumpus = true, is_wumpus_alive = true })
--             wumpus_location = {x = x, y = y}
--         elseif type_char == "G" then
--             Environment.set_cell(x, y, { has_gold = true })
--             gold_location = {x = x, y = y}
--         elseif type_char == "P" then
--             Environment.set_cell(x, y, { has_pit = true })
--         else
--             print("Warning: Unknown entity type '" .. type_char .. "' in environment file. Skipping.")
--         end
--         ::continue::
--     end
--     file:close()

--     -- Ensure [1,1] is safe, as per Wumpus World rules. This overrides file content if any.
--     Environment.set_cell(Environment.START_X, Environment.START_Y, { has_wumpus = false, is_wumpus_alive = false, has_pit = false, has_gold = false })

--     print("Environment loaded from file: " .. filename)
-- end

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


-- Returns the full grid for UI or debugging purposes
function Environment.get_grid()
    return world_grid
end

-- Returns true if any Wumpus is alive in the world
function Environment.is_wumpus_alive()
    for y = 1, Environment.GRID_SIZE do
        for x = 1, Environment.GRID_SIZE do
            local cell = Environment.get_cell(x, y)
            if cell and cell.has_wumpus and cell.is_wumpus_alive then
                return true
            end
        end
    end
    return false -- No living wumpus in the world
end

-- Returns the primary Wumpus's location (for legacy compatibility)
function Environment.get_wumpus_location()
    return wumpus_location
end

-- Returns all Wumpus locations in the world
function Environment.get_all_wumpus_locations()
    local wumpus_locations = {}
    for y = 1, Environment.GRID_SIZE do
        for x = 1, Environment.GRID_SIZE do
            local cell = Environment.get_cell(x, y)
            if cell and cell.has_wumpus then
                table.insert(wumpus_locations, {x = x, y = y, alive = cell.is_wumpus_alive})
            end
        end
    end
    return wumpus_locations
end

-- Returns the Gold's location
function Environment.get_gold_location()
    return gold_location
end

return Environment