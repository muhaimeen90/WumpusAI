-- -- inference_engine.lua
-- -- Implements logical inference for Wumpus World using forward chaining

-- local Environment = require("environment")
-- local InferenceEngine = {}
-- InferenceEngine.__index = InferenceEngine

-- -- Create a new Inference Engine
-- function InferenceEngine.new(kb)
--     local self = setmetatable({}, InferenceEngine)
--     self.kb = kb -- Reference to Knowledge Base
--     self.visited = {} -- Track visited squares to avoid loops
--     self.gridSize = 10 -- 10x10 grid
--     return self
-- end

-- -- Mark a square as visited
-- function InferenceEngine:markVisited(x, y)
--     self.visited[x .. "_" .. y] = true
--     Environment.set_cell(x, y, { is_visited = true })
-- end

-- -- Check if a square has been visited (for loop detection)
-- function InferenceEngine:isVisited(x, y)
--     return self.visited[x .. "_" .. y] == true
-- end

-- -- Check if a square is safe
-- function InferenceEngine:isSafe(x, y)
--     -- Out-of-bounds squares are not safe
--     if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize then
--         return false
--     end
--     -- Known safe from KB
--     if self.kb:query("Safe_" .. x .. "_" .. y) then
--         return true
--     end
--     -- Check for Bump (indicates wall)
--     if self.kb:query("Bump_" .. x .. "_" .. y) then
--         return false
--     end
--     -- If the agent has visited a square with no Breeze or Stench, adjacent squares are safe
--     local adjacents = self:getAdjacents(x, y)
--     for _, adj in ipairs(adjacents) do
--         local ax, ay = adj[1], adj[2]
--         if self:isVisited(ax, ay) and
--            not self.kb:query("Breeze_" .. ax .. "_" .. ay) and
--            not (self.kb:query("Stench_" .. ax .. "_" .. ay) and self.kb:isWumpusAlive()) then
--             self.kb:addFact("Safe_" .. x .. "_" .. y)
--             return true
--         end
--     end
--     return false -- Default to unsafe if unknown
-- end

-- -- Infer if a square has a pit
-- function InferenceEngine:hasPit(x, y)
--     -- Out-of-bounds or known no-pit
--     if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize or
--        self.kb:query("NoPit_" .. x .. "_" .. y) then
--         return false
--     end
--     -- Check adjacent squares: Breeze implies possible pit
--     local adjacents = self:getAdjacents(x, y)
--     for _, adj in ipairs(adjacents) do
--         local ax, ay = adj[1], adj[2]
--         if self.kb:query("Breeze_" .. ax .. "_" .. ay) then
--             return true
--         end
--     end
--     return false
-- end

-- -- Infer if a square has a Wumpus
-- -- function InferenceEngine:hasWumpus(x, y)
-- --     -- Out-of-bounds, known no-Wumpus, or Wumpus is dead
-- --     if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize or
-- --        self.kb:query("NoWumpus_" .. x .. "_" .. y) or
-- --        not self.kb:isWumpusAlive() then
-- --         return false
-- --     end
-- --     -- Check adjacent squares: Stench implies possible Wumpus
-- --     local adjacents = self:getAdjacents(x, y)
-- --     for _, adj in ipairs(adjacents) do
-- --         local ax, ay = adj[1], adj[2]
-- --         if self.kb:query("Stench_" .. ax .. "_" .. ay) then
-- --             return true
-- --         end
-- --     end
-- --     return false
-- -- end
-- function InferenceEngine:hasWumpus(x, y)
--     -- Out-of-bounds, known no-Wumpus, or Wumpus is dead
--     if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize or
--        self.kb:query("NoWumpus_" .. x .. "_" .. y) or
--        not self.kb:isWumpusAlive() then
--         return false
--     end
    
--     -- Check if KB explicitly states there's a Wumpus here
--     if self.kb:query("Wumpus_" .. x .. "_" .. y) then
--         return true
--     end
    
--     -- For more sophisticated inference:
--     -- If we have stench in ALL adjacent squares that are visited,
--     -- AND we have visited at least 2 adjacent squares,
--     -- AND all other possible Wumpus locations for those stenches are ruled out,
--     -- then this MUST be the Wumpus location
    
--     local adjacents = self:getAdjacents(x, y)
--     local visited_adjacents = 0
--     local all_have_stench = true
    
--     for _, adj in ipairs(adjacents) do
--         local ax, ay = adj[1], adj[2]
--         if self:isVisited(ax, ay) then
--             visited_adjacents = visited_adjacents + 1
--             if not self.kb:query("Stench_" .. ax .. "_" .. ay) then
--                 all_have_stench = false
--                 break
--             end
--         end
--     end
    
--     -- If we've visited at least 2 adjacent cells and they all have stench,
--     -- this is very likely the Wumpus location
--     if visited_adjacents >= 2 and all_have_stench then
--         self.kb:addFact("Wumpus_" .. x .. "_" .. y)
--         return true
--     end
    
--     -- Not enough information to be certain
--     return false
-- end

-- -- Get adjacent squares (up, down, left, right; not diagonal)
-- function InferenceEngine:getAdjacents(x, y)
--     local adjacents = {}
--     if x > 1 then table.insert(adjacents, {x-1, y}) end -- Left
--     if x < self.gridSize then table.insert(adjacents, {x+1, y}) end -- Right
--     if y > 1 then table.insert(adjacents, {x, y-1}) end -- Down
--     if y < self.gridSize then table.insert(adjacents, {x, y+1}) end -- Up
--     return adjacents
-- end

-- -- Update KB with new percepts and run inference
-- function InferenceEngine:update(x, y, percepts)
--     self.kb:updateFromPercepts(x, y, percepts)
--     self:markVisited(x, y)
--     -- Forward chaining: Infer safety, pits, and Wumpus for adjacent squares
--     local adjacents = self:getAdjacents(x, y)
--     for _, adj in ipairs(adjacents) do
--         local ax, ay = adj[1], adj[2]
--         if not self:isVisited(ax, ay) then
--             if self:isSafe(ax, ay) then
--                 self.kb:addFact("Safe_" .. ax .. "_" .. ay)
--             end
--             if self:hasPit(ax, ay) then
--                 self.kb:addFact("Pit_" .. ax .. "_" .. ay)
--             end
--             if self:hasWumpus(ax, ay) then
--                 self.kb:addFact("Wumpus_" .. ax .. "_" .. ay)
--             end
--         end
--     end
-- end

-- -- Notify inference engine of a Shoot action
-- function InferenceEngine:shoot()
--     self.kb:useArrow()
-- end

-- return InferenceEngine

-- inference_engine.lua
-- Implements logical inference for Wumpus World using forward chaining

local InferenceEngine = {}
InferenceEngine.__index = InferenceEngine

-- Create a new Inference Engine - backward compatible constructor
function InferenceEngine.new(kb_or_gridSize, kb)
    local self = setmetatable({}, InferenceEngine)
    
    -- Handle both old and new calling conventions
    if kb == nil then
        -- Old calling convention: InferenceEngine.new(kb)
        self.kb = kb_or_gridSize
        self.gridSize = 10 -- Default grid size
    else
        -- New calling convention: InferenceEngine.new(gridSize, kb)
        self.gridSize = kb_or_gridSize
        self.kb = kb
    end
    
    self.visited = {} -- Track visited squares
    return self
end

-- Mark a square as visited
function InferenceEngine:markVisited(x, y)
    if not self.visited[x] then
        self.visited[x] = {}
    end
    self.visited[x][y] = true
end

-- Check if a square has been visited
function InferenceEngine:isVisited(x, y)
    return self.visited[x] and self.visited[x][y]
end

-- Conservative safety check - only returns true if we're CERTAIN it's safe
function InferenceEngine:isSafe(x, y)
    -- Out-of-bounds
    if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize then
        return false
    end
    
    -- Explicitly known to be safe
    if self.kb:query("Safe_" .. x .. "_" .. y) then
        return true
    end
    
    -- Explicitly known to have pit or Wumpus - definitely not safe
    if self.kb:query("Pit_" .. x .. "_" .. y) or self.kb:query("Wumpus_" .. x .. "_" .. y) then
        return false
    end
    
    -- If we KNOW there's no pit and no Wumpus, it's safe
    local has_no_pit = self.kb:query("NoPit_" .. x .. "_" .. y)
    local has_no_wumpus = self.kb:query("NoWumpus_" .. x .. "_" .. y) or not self.kb:isWumpusAlive()
    
    if has_no_pit and has_no_wumpus then
        self.kb:addFact("Safe_" .. x .. "_" .. y)
        return true
    end
    
    -- Conservative approach: if we're not certain, return false
    return false
end

-- Simple but correct pit inference
function InferenceEngine:hasPit(x, y)
    -- Out-of-bounds or known no-pit
    if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize or
       self.kb:query("NoPit_" .. x .. "_" .. y) then
        return false
    end
    
    -- Explicitly known to have pit
    if self.kb:query("Pit_" .. x .. "_" .. y) then
        return true
    end
    
    -- Conservative approach: only infer pit if we have strong evidence
    -- For now, let the update() method handle pit inference through constraint propagation
    return false
end

-- Simple but correct Wumpus inference
function InferenceEngine:hasWumpus(x, y)
    -- Out-of-bounds, known no-Wumpus, or Wumpus is dead
    if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize or
       self.kb:query("NoWumpus_" .. x .. "_" .. y) or
       not self.kb:isWumpusAlive() then
        return false
    end
    
    -- Check if KB explicitly states there's a Wumpus here
    if self.kb:query("Wumpus_" .. x .. "_" .. y) then
        return true
    end
    
    -- Conservative approach: only infer Wumpus if we have strong evidence
    return false
end

-- Get adjacent squares (up, down, left, right; not diagonal)
function InferenceEngine:getAdjacents(x, y)
    local adjacents = {}
    if x > 1 then table.insert(adjacents, {x-1, y}) end -- Left
    if x < self.gridSize then table.insert(adjacents, {x+1, y}) end -- Right
    if y > 1 then table.insert(adjacents, {x, y-1}) end -- Down
    if y < self.gridSize then table.insert(adjacents, {x, y+1}) end -- Up
    return adjacents
end

-- Core constraint propagation logic
function InferenceEngine:propagateConstraintsFrom(x, y)
    local adjacents = self:getAdjacents(x, y)
    
    -- Rule 1: If no breeze here, all adjacent cells have no pit
    if not self.kb:query("Breeze_" .. x .. "_" .. y) then
        for _, adj in ipairs(adjacents) do
            local ax, ay = adj[1], adj[2]
            if not self.kb:query("NoPit_" .. ax .. "_" .. ay) then
                self.kb:addFact("NoPit_" .. ax .. "_" .. ay)
                print("INFERENCE: [" .. ax .. "," .. ay .. "] has no pit (no breeze at [" .. x .. "," .. y .. "])")
            end
        end
    end
    
    -- Rule 2: If no stench here, all adjacent cells have no Wumpus
    if not self.kb:query("Stench_" .. x .. "_" .. y) then
        for _, adj in ipairs(adjacents) do
            local ax, ay = adj[1], adj[2]
            if not self.kb:query("NoWumpus_" .. ax .. "_" .. ay) then
                self.kb:addFact("NoWumpus_" .. ax .. "_" .. ay)
                print("INFERENCE: [" .. ax .. "," .. ay .. "] has no Wumpus (no stench at [" .. x .. "," .. y .. "])")
            end
        end
    end
    
    -- Rule 3: Advanced pit inference using constraint satisfaction
    if self.kb:query("Breeze_" .. x .. "_" .. y) then
        local possible_pit_locations = {}
        
        -- Find all unvisited adjacent cells that could have pits
        for _, adj in ipairs(adjacents) do
            local ax, ay = adj[1], adj[2]
            if not self:isVisited(ax, ay) and not self.kb:query("NoPit_" .. ax .. "_" .. ay) then
                table.insert(possible_pit_locations, {ax, ay})
            end
        end
        
        -- If only one possible location for the pit, it must be there
        if #possible_pit_locations == 1 then
            local px, py = possible_pit_locations[1][1], possible_pit_locations[1][2]
            self.kb:addFact("Pit_" .. px .. "_" .. py)
            print("INFERENCE: [" .. px .. "," .. py .. "] has pit (only possible location for breeze at [" .. x .. "," .. y .. "])")
        end
    end
    
    -- Rule 4: Advanced Wumpus inference
    if self.kb:query("Stench_" .. x .. "_" .. y) and self.kb:isWumpusAlive() then
        local possible_wumpus_locations = {}
        
        -- Find all unvisited adjacent cells that could have the Wumpus
        for _, adj in ipairs(adjacents) do
            local ax, ay = adj[1], adj[2]
            if not self:isVisited(ax, ay) and not self.kb:query("NoWumpus_" .. ax .. "_" .. ay) then
                table.insert(possible_wumpus_locations, {ax, ay})
            end
        end
        
        -- If only one possible location for the Wumpus, it must be there
        if #possible_wumpus_locations == 1 then
            local wx, wy = possible_wumpus_locations[1][1], possible_wumpus_locations[1][2]
            self.kb:addFact("Wumpus_" .. wx .. "_" .. wy)
            print("INFERENCE: [" .. wx .. "," .. wy .. "] has Wumpus (only possible location for stench at [" .. x .. "," .. y .. "])")
        end
    end
end

-- Update KB with new percepts and run inference
function InferenceEngine:update(x, y, percepts)
    print("INFERENCE: Updating from position [" .. x .. "," .. y .. "] with percepts: [" .. table.concat(percepts, ", ") .. "]")
    
    self.kb:updateFromPercepts(x, y, percepts)
    self:markVisited(x, y)
    
    -- First, propagate constraints from this cell
    self:propagateConstraintsFrom(x, y)
    
    -- Then run a few iterations of global constraint propagation
    local iterations = 0
    local changed = true
    
    while changed and iterations < 5 do
        changed = false
        iterations = iterations + 1
        
        -- Check all visited cells for new constraint propagation opportunities
        for vx = 1, self.gridSize do
            if self.visited[vx] then
                for vy = 1, self.gridSize do
                    if self.visited[vx][vy] then
                        local old_fact_count = #self.kb:getAllFacts()
                        self:propagateConstraintsFrom(vx, vy)
                        local new_fact_count = #self.kb:getAllFacts()
                        if new_fact_count > old_fact_count then
                            changed = true
                        end
                    end
                end
            end
        end
    end
    
    print("INFERENCE: Completed " .. iterations .. " inference iterations")
    
    -- Debug: Print key facts about adjacent cells
    local adjacents = self:getAdjacents(x, y)
    for _, adj in ipairs(adjacents) do
        local ax, ay = adj[1], adj[2]
        if not self:isVisited(ax, ay) then
            local has_pit = self.kb:query("Pit_" .. ax .. "_" .. ay)
            local no_pit = self.kb:query("NoPit_" .. ax .. "_" .. ay)
            local has_wumpus = self.kb:query("Wumpus_" .. ax .. "_" .. ay)
            local no_wumpus = self.kb:query("NoWumpus_" .. ax .. "_" .. ay)
            local is_safe = self:isSafe(ax, ay)
            
            print("INFERENCE: [" .. ax .. "," .. ay .. "] - Pit:" .. tostring(has_pit) .. " NoPit:" .. tostring(no_pit) .. 
                  " Wumpus:" .. tostring(has_wumpus) .. " NoWumpus:" .. tostring(no_wumpus) .. " Safe:" .. tostring(is_safe))
        end
    end
end

-- Notify inference engine of a Shoot action
function InferenceEngine:shoot()
    self.kb:useArrow()
end

return InferenceEngine