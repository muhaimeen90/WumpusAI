-- knowledge_base.lua
-- Manages the Knowledge Base for the Wumpus World using Propositional Logic

local KnowledgeBase = {}
KnowledgeBase.__index = KnowledgeBase

-- Create a new Knowledge Base
function KnowledgeBase.new()
    local self = setmetatable({}, KnowledgeBase)
    self.facts = {} -- Stores facts as a set (e.g., "Safe_1_1", "Stench_2_3")
    self.wumpusAlive = true -- Track if Wumpus is alive
    self._hasArrow = true -- Track if agent has arrow (renamed to avoid shadowing method)
    return self
end

-- Add a fact to the KB (e.g., "Safe_1_1", "Breeze_2_3")
function KnowledgeBase:addFact(fact)
    self.facts[fact] = true
end

-- Check if a fact is in the KB
function KnowledgeBase:query(fact)
    return self.facts[fact] == true
end

-- Update KB based on percepts at position (x, y)
function KnowledgeBase:updateFromPercepts(x, y, percepts)
    -- Percepts are a list: [Stench, Breeze, Glitter, Bump, Scream]
    if percepts[1] == "Stench" then
        self:addFact("Stench_" .. x .. "_" .. y)
    else
        self:addFact("NoStench_" .. x .. "_" .. y)
    end
    if percepts[2] == "Breeze" then
        self:addFact("Breeze_" .. x .. "_" .. y)
    else
        self:addFact("NoBreeze_" .. x .. "_" .. y)
    end
    if percepts[3] == "Glitter" then
        self:addFact("Glitter_" .. x .. "_" .. y)
    else
        self:addFact("NoGlitter_" .. x .. "_" .. y)
    end
    if percepts[4] == "Bump" then
        self:addFact("Bump_" .. x .. "_" .. y)
    else
        self:addFact("NoBump_" .. x .. "_" .. y)
    end
    if percepts[5] == "Scream" then
        self.wumpusAlive = false
        self:addFact("Scream")
    end
    -- Mark current square as safe (agent is alive)
    self:addFact("Safe_" .. x .. "_" .. y)
    self:addFact("NoPit_" .. x .. "_" .. y)
    self:addFact("NoWumpus_" .. x .. "_" .. y)
end

-- Update arrow status after shooting
function KnowledgeBase:useArrow()
    self._hasArrow = false
    self:addFact("NoArrow")
end

-- Get Wumpus alive status
function KnowledgeBase:isWumpusAlive()
    return self.wumpusAlive
end

-- Get arrow availability
function KnowledgeBase:hasArrow()
    return self._hasArrow
end

-- Get all facts for debugging or UI
function KnowledgeBase:getAllFacts()
    local factsList = {}
    for fact, _ in pairs(self.facts) do
        table.insert(factsList, fact)
    end
    table.insert(factsList, "WumpusAlive_" .. tostring(self.wumpusAlive))
    table.insert(factsList, "HasArrow_" .. tostring(self._hasArrow))
    return factsList
end

return KnowledgeBase