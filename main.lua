package.loaded["environment"] = nil
package.loaded["percepts"] = nil
package.loaded["knowledge_base"] = nil
package.loaded["inference_engine"] = nil
package.loaded["agent"] = nil

-- Set up output file
local output_file = io.open("wumpus_output2.txt", "w")
if not output_file then
    error("Could not open output file")
end
io.output(output_file) -- Redirect all print output to this file

-- Keep a reference to the original print function
local original_print = print
print = function(...)
    original_print(...) -- Still print to console
    io.write(table.concat({...}, " ") .. "\n") -- Write to file
end

-- Load all required modules
local Environment = require("environment")
local KnowledgeBase = require("knowledge_base")
local InferenceEngine = require("inference_engine")
local Agent = require("agent")

-- -- Verify module loading
-- if type(KnowledgeBase) ~= "table" then
--     error("Failed to load knowledge_base module: expected a table, got " .. type(KnowledgeBase))
-- end
-- if type(InferenceEngine) ~= "table" then
--     error("Failed to load inference_engine module: expected a table, got " .. type(InferenceEngine))
-- end
-- if type(Agent) ~= "table" then
--     error("Failed to load agent module: expected a table, got " .. type(Agent))
-- end

-- Helper function to print the environment
local function print_environment(agent_x, agent_y)
    print("Environment (W=Wumpus, G=Gold, P=Pit, A=Agent):")
    local grid = Environment.get_grid()
    for y = Environment.GRID_SIZE, 1, -1 do
        local row = ""
        for x = 1, Environment.GRID_SIZE do
            local cell = grid[y][x]
            if x == agent_x and y == agent_y then
                row = row .. "A "
            elseif cell.has_wumpus and cell.is_wumpus_alive then
                row = row .. "W "
            elseif cell.has_gold then
                row = row .. "G "
            elseif cell.has_pit then
                row = row .. "P "
            else
                row = row .. ". "
            end
        end
        print(row)
    end
end

-- Initialize game
local kb = KnowledgeBase.new()
local ie = InferenceEngine.new(kb)
local agent = Agent.new(kb, ie)

-- Load environment
Environment.load_grid_environment_from_file("sample1.txt") -- Use the test file
print("Starting Wumpus World Test")
local agent_x, agent_y = agent:getPosition()
print_environment(agent_x, agent_y)

-- Main game loop
local max_steps = 100
local step = 0
local running = true

while running and step < max_steps do
    step = step + 1
    running = agent:step()
    agent_x, agent_y = agent:getPosition()
    print_environment(agent_x, agent_y)
end

if step >= max_steps then
    print("Maximum steps reached. Game Over.")
    print("Final Score: " .. agent:getScore())
end

-- Close the output file
io.output():close()