-- percepts.lua
-- Generates percepts for the agent based on its location in the environment.
-- Team Member 1: Environment & Percepts

local Percepts = {}

-- Requires the Environment module
local Environment = require("environment")

-- Helper function to get adjacent cells (non-diagonal)
local function get_adjacent_cells(x, y)
    local adjacent = {}
    -- North
    if Environment.is_valid_coord(x, y + 1) then table.insert(adjacent, {x = x, y = y + 1}) end
    -- South
    if Environment.is_valid_coord(x, y - 1) then table.insert(adjacent, {x = x, y = y - 1}) end
    -- East
    if Environment.is_valid_coord(x + 1, y) then table.insert(adjacent, {x = x + 1, y = y}) end
    -- West
    if Environment.is_valid_coord(x - 1, y) then table.insert(adjacent, {x = x - 1, y = y}) end
    return adjacent
end

-- Generates the percept list for the agent at a given location.
-- This function will be called by the 'agent.lua' module.
-- Parameters:
--   agent_x, agent_y: The agent's current coordinates.
--   has_bumped: Boolean, true if the last action resulted in a bump (against a wall).
--   has_screamed: Boolean, true if a wumpus was just killed (should reset after one turn).
-- Returns: A table of percept symbols, e.g., {"Stench", "Breeze", "Glitter", "None", "None"}
function Percepts.get_percepts(agent_x, agent_y, has_bumped, has_screamed)
    local percept_list = {"None", "None", "None", "None", "None"} -- [Stench, Breeze, Glitter, Bump, Scream]

    local current_cell = Environment.get_cell(agent_x, agent_y)
    if not current_cell then
        -- This should ideally not happen if agent movement is correctly constrained
        print("Error: Agent is at an invalid location for percepts!")
        return percept_list
    end

    -- 1. Check for Glitter
    if current_cell.has_gold then
        percept_list[3] = "Glitter"
    end

    -- 2. Check for Stench and Breeze in adjacent squares
    local adjacent_cells = get_adjacent_cells(agent_x, agent_y)
    local has_stench = false
    local has_breeze = false

    for _, coord in ipairs(adjacent_cells) do
        local cell = Environment.get_cell(coord.x, coord.y)
        if cell then -- Should always be true if get_adjacent_cells is correct
            if cell.has_wumpus and cell.is_wumpus_alive then
                has_stench = true
            end
            if cell.has_pit then
                has_breeze = true
            end
        end
        -- Optimization: Break early if both are found
        if has_stench and has_breeze then break end
    end

    if has_stench then
        percept_list[1] = "Stench"
    end
    if has_breeze then
        percept_list[2] = "Breeze"
    end

    -- 3. Check for Bump
    if has_bumped then
        percept_list[4] = "Bump"
    end

    -- 4. Check for Scream
    if has_screamed then
        percept_list[5] = "Scream"
    end

    return percept_list
end

return Percepts