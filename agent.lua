-- agent.lua
-- Handles the Wumpus World agent's behavior, decision-making, and state

local Environment = require("environment")
local Percepts = require("percepts")

local Agent = {}
Agent.__index = Agent

-- Create a new Agent instance
function Agent.new(kb, ie)
    local self = setmetatable({}, Agent)
    
    -- Internal state
    self.kb = kb                           -- Knowledge base reference
    self.ie = ie                           -- Inference engine reference
    self.x = Environment.START_X           -- Current x position
    self.y = Environment.START_Y           -- Current y position
    self.direction = "right"               -- Current facing direction
    self.has_gold = false                  -- Whether agent has gold
    self.score = 0                         -- Current score
    self.has_bumped = false                -- Whether last action caused a bump
    self.has_screamed = false              -- Whether a wumpus was just killed
    self.safe_cells = {}                   -- Track known safe cells
    self.visited_cells = {}                -- Track visited cells
    self.step_counter = 0  
    -- Mark starting position as safe and visited
    self:markCurrentCell()
    
    return self
end

-- Mark current cell as safe and visited
function Agent:markCurrentCell()
    local key = self.x .. "_" .. self.y
    self.safe_cells[key] = true
    self.visited_cells[key] = true
    self.ie:markVisited(self.x, self.y)
end

-- Get possible moves from current position
function Agent:getPossibleMoves()
    local moves = {}
    if Environment.is_valid_coord(self.x + 1, self.y) then table.insert(moves, {x = self.x + 1, y = self.y, dir = "right"}) end
    if Environment.is_valid_coord(self.x - 1, self.y) then table.insert(moves, {x = self.x - 1, y = self.y, dir = "left"}) end
    if Environment.is_valid_coord(self.x, self.y + 1) then table.insert(moves, {x = self.x, y = self.y + 1, dir = "up"}) end
    if Environment.is_valid_coord(self.x, self.y - 1) then table.insert(moves, {x = self.x, y = self.y - 1, dir = "down"}) end
    return moves
end

-- Check if agent dies at current position
function Agent:checkDeath()
    local cell = Environment.get_cell(self.x, self.y)
    if cell.has_pit then
        print("Agent fell into a pit at [" .. self.x .. "," .. self.y .. "]! Game Over.")
        self.score = self.score - 1000
        return true
    elseif cell.has_wumpus and cell.is_wumpus_alive then
        print("Agent was eaten by the Wumpus at [" .. self.x .. "," .. self.y .. "]! Game Over.")
        self.score = self.score - 1000
        return true
    end
    return false
end

-- Find best move for returning home to [1,1]
function Agent:getBestMoveHome()
    local moves = self:getPossibleMoves()
    local best_move = nil
    local best_dist = 99999
    
    for _, move in ipairs(moves) do
        if self.ie:isSafe(move.x, move.y) then
            -- Manhattan distance to home
            local dist = math.abs(move.x - 1) + math.abs(move.y - 1)
            if dist < best_dist then
                best_dist = dist
                best_move = move
            end
        end
    end
    
    return best_move
end

-- Find safe, unvisited move for exploration
function Agent:getExplorationMove()
    local moves = self:getPossibleMoves()
    local safe_move = nil
    
    -- First try to find a safe, unvisited square
    for _, move in ipairs(moves) do
        if self.ie:isSafe(move.x, move.y) and not self.ie:isVisited(move.x, move.y) then
            safe_move = move
            break
        end
    end
    
    -- If no unvisited safe square, just pick any safe square
    if not safe_move then
        for _, move in ipairs(moves) do
            if self.ie:isSafe(move.x, move.y) then
                safe_move = move
                break
            end
        end
    end
    
    return safe_move
end

-- Turn the agent to a new direction
function Agent:turn()
    local directions = {"right", "up", "left", "down"}
    local current_dir_idx = 1
    for i, dir in ipairs(directions) do
        if dir == self.direction then
            current_dir_idx = i
            break
        end
    end
    local new_dir_idx = current_dir_idx % 4 + 1
    self.direction = directions[new_dir_idx]
    print("Action: Turn to " .. self.direction)
    self.score = self.score - 1 -- Action cost
    self.has_bumped = false
end

-- Execute the next step of the agent
function Agent:step()
    self.step_counter = self.step_counter + 1
    print("\nStep " .. self.step_counter .. ": Agent at [" .. self.x .. "," .. self.y .. "], Direction: " .. self.direction)
    
    -- Get percepts
    local percepts = Percepts.get_percepts(self.x, self.y, self.has_bumped, self.has_screamed)
    self.has_screamed = false -- Reset scream after one turn
    print("Percepts: [" .. table.concat(percepts, ", ") .. "]")
    
    -- Update knowledge base and run inference
    self.ie:update(self.x, self.y, percepts)
    print("Knowledge Base Facts:")
    local facts = self.kb:getAllFacts()
    for _, fact in ipairs(facts) do
        print("  " .. fact)
    end
    print("Score: " .. self.score)
    
    -- Check for death
    if self:checkDeath() then
        return false -- Game over
    end
    
    -- Handle Glitter (Grab gold)
    if percepts[3] == "Glitter" then
        print("Action: Grab")
        Environment.remove_gold_at(self.x, self.y)
        self.has_gold = true
        self.score = self.score - 1 -- Action cost
    end
    
    -- Handle Climb (only at [1,1] with gold)
    if self.has_gold then
        print("Action: Returning home to climb out")
        self.score = self.score + 1000 - 1 -- +1000 for climbing with gold, -1 for action
        print("Agent climbed out with gold! Game Over.")
        print("Final Score: " .. self.score)
        return false -- Game over
    end
    
    -- Handle Shoot (if Wumpus inferred nearby and has arrow)
    if self.kb:hasArrow() then
        local moves = self:getPossibleMoves()
        for _, move in ipairs(moves) do
            if self.ie:hasWumpus(move.x, move.y) and move.dir == self.direction then
                print("Action: Shoot")
                if Environment.kill_wumpus_at(move.x, move.y) then
                    self.has_screamed = true
                end
                self.ie:shoot()
                self.score = self.score - 10 - 1 -- -10 for arrow, -1 for action
                break
            end
        end
    end
    
    -- MOVEMENT LOGIC
    if self.has_gold then
        -- RETURNING HOME MODE - prioritize getting back to [1,1]
        local home_move = self:getBestMoveHome()
        
        if home_move then
            -- Move toward home if possible
            print("Action: Move to [" .. home_move.x .. "," .. home_move.y .. "] (returning home)")
            self.x, self.y = home_move.x, home_move.y
            self.direction = home_move.dir
            self.has_bumped = false
            self.score = self.score - 1 -- Action cost
            self:markCurrentCell()
        else
            -- If no direct move is possible, turn to try another direction
            self:turn()
        end
    else
        -- EXPLORATION MODE - look for gold
        local safe_move = self:getExplorationMove()
        
        if safe_move then
            -- Move to the selected safe square
            print("Action: Move to [" .. safe_move.x .. "," .. safe_move.y .. "]")
            self.x, self.y = safe_move.x, safe_move.y
            self.direction = safe_move.dir
            self.has_bumped = false
            self.score = self.score - 1 -- Action cost
            self:markCurrentCell()
        else
            -- If no safe move, just turn
            self:turn()
        end
    end
    
    return true -- Continue game
end

-- Get the final score
function Agent:getScore()
    return self.score
end

-- Get the current position
function Agent:getPosition()
    return self.x, self.y
end

return Agent