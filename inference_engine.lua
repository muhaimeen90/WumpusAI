-- inference_engine.lua
-- Implements logical inference for Wumpus World using forward chaining

local Environment = require("environment")
local InferenceEngine = {}
InferenceEngine.__index = InferenceEngine

-- Create a new Inference Engine
function InferenceEngine.new(kb)
    local self = setmetatable({}, InferenceEngine)
    self.kb = kb -- Reference to Knowledge Base
    self.visited = {} -- Track visited squares to avoid loops
    self.gridSize = 10 -- 10x10 grid
    return self
end

-- Mark a square as visited
function InferenceEngine:markVisited(x, y)
    self.visited[x .. "_" .. y] = true
    Environment.set_cell(x, y, { is_visited = true })
end

-- Check if a square has been visited (for loop detection)
function InferenceEngine:isVisited(x, y)
    return self.visited[x .. "_" .. y] == true
end

-- Check if a square is safe
function InferenceEngine:isSafe(x, y)
    -- Out-of-bounds squares are not safe
    if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize then
        return false
    end
    -- Known safe from KB
    if self.kb:query("Safe_" .. x .. "_" .. y) then
        return true
    end
    -- Check for Bump (indicates wall)
    if self.kb:query("Bump_" .. x .. "_" .. y) then
        return false
    end
    -- If the agent has visited a square with no Breeze or Stench, adjacent squares are safe
    local adjacents = self:getAdjacents(x, y)
    for _, adj in ipairs(adjacents) do
        local ax, ay = adj[1], adj[2]
        if self:isVisited(ax, ay) and
           not self.kb:query("Breeze_" .. ax .. "_" .. ay) and
           not (self.kb:query("Stench_" .. ax .. "_" .. ay) and self.kb:isWumpusAlive()) then
            self.kb:addFact("Safe_" .. x .. "_" .. y)
            return true
        end
    end
    return false -- Default to unsafe if unknown
end

-- Infer if a square has a pit
function InferenceEngine:hasPit(x, y)
    -- Out-of-bounds or known no-pit
    if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize or
       self.kb:query("NoPit_" .. x .. "_" .. y) then
        return false
    end
    -- Check adjacent squares: Breeze implies possible pit
    local adjacents = self:getAdjacents(x, y)
    for _, adj in ipairs(adjacents) do
        local ax, ay = adj[1], adj[2]
        if self.kb:query("Breeze_" .. ax .. "_" .. ay) then
            return true
        end
    end
    return false
end

-- Infer if a square has a Wumpus
function InferenceEngine:hasWumpus(x, y)
    -- Out-of-bounds, known no-Wumpus, or Wumpus is dead
    if x < 1 or x > self.gridSize or y < 1 or y > self.gridSize or
       self.kb:query("NoWumpus_" .. x .. "_" .. y) or
       not self.kb:isWumpusAlive() then
        return false
    end
    -- Check adjacent squares: Stench implies possible Wumpus
    local adjacents = self:getAdjacents(x, y)
    for _, adj in ipairs(adjacents) do
        local ax, ay = adj[1], adj[2]
        if self.kb:query("Stench_" .. ax .. "_" .. ay) then
            return true
        end
    end
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

-- Update KB with new percepts and run inference
function InferenceEngine:update(x, y, percepts)
    self.kb:updateFromPercepts(x, y, percepts)
    self:markVisited(x, y)
    -- Forward chaining: Infer safety, pits, and Wumpus for adjacent squares
    local adjacents = self:getAdjacents(x, y)
    for _, adj in ipairs(adjacents) do
        local ax, ay = adj[1], adj[2]
        if not self:isVisited(ax, ay) then
            if self:isSafe(ax, ay) then
                self.kb:addFact("Safe_" .. ax .. "_" .. ay)
            end
            if self:hasPit(ax, ay) then
                self.kb:addFact("Pit_" .. ax .. "_" .. ay)
            end
            if self:hasWumpus(ax, ay) then
                self.kb:addFact("Wumpus_" .. ax .. "_" .. ay)
            end
        end
    end
end

-- Notify inference engine of a Shoot action
function InferenceEngine:shoot()
    self.kb:useArrow()
end

return InferenceEngine