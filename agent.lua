-- agent.lua
-- Enhanced version with better exploration patterns and revisit prevention

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
    self.step_counter = 0                  -- Count steps taken
    
    -- Enhanced exploration
    self.move_history = {}                 -- Stores last 20 positions
    self.loop_detected = false             -- Flag for loop detection
    self.blocked_moves = {}                -- Temporarily blocked moves to break loops
    self.cell_visits = {}                  -- Count how many times we've visited each cell
    self.frontier_cells = {}               -- Cells adjacent to visited but not yet explored
    self.risk_tolerance = 0                -- Increases over time to break out of stuck states
    self.exploration_zones = {}            -- Track which zones have been explored
    self.last_productive_step = 0          -- Last step where we visited a new cell
    
    -- Mark starting position as safe and visited
    self:markCurrentCell()
    
    return self
end

-- Mark current cell as safe and visited
function Agent:markCurrentCell()
    local key = self.x .. "_" .. self.y
    self.safe_cells[key] = true
    
    -- Track if this is a new cell visit
    local is_new_visit = not self.visited_cells[key]
    self.visited_cells[key] = true
    self.ie:markVisited(self.x, self.y)
    
    -- Increment visit counter for this cell
    self.cell_visits[key] = (self.cell_visits[key] or 0) + 1
    
    -- Update last productive step if this was a new cell
    if is_new_visit then
        self.last_productive_step = self.step_counter
        print("New cell discovered! Last productive step: " .. self.last_productive_step)
    end
    
    -- Add current position to move history
    table.insert(self.move_history, {x = self.x, y = self.y})
    -- Keep only last 20 moves (increased for better pattern detection)
    if #self.move_history > 20 then
        table.remove(self.move_history, 1)
    end
    
    -- Update exploration zones
    self:updateExplorationZones()
    
    -- Update frontier cells
    self:updateFrontierCells()
    
    -- Check for loops (repeated positions)
    self:detectLoop()
end

-- Track exploration zones to encourage systematic exploration
function Agent:updateExplorationZones()
    -- Divide the grid into 2x2 zones and track which ones we've visited
    local zone_x = math.floor((self.x - 1) / 2) + 1
    local zone_y = math.floor((self.y - 1) / 2) + 1
    local zone_key = zone_x .. "_" .. zone_y
    
    if not self.exploration_zones[zone_key] then
        self.exploration_zones[zone_key] = {
            x = zone_x,
            y = zone_y,
            first_visit = self.step_counter,
            cells_visited = 0
        }
    end
    
    self.exploration_zones[zone_key].cells_visited = self.exploration_zones[zone_key].cells_visited + 1
end

function Agent:updateFrontierCells()
    local directions = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}} -- up, right, down, left
    
    for dir_idx, dir in ipairs(directions) do
        local nx, ny = self.x + dir[1], self.y + dir[2]
        if Environment.is_valid_coord(nx, ny) then
            local key = nx .. "_" .. ny
            -- If it's not visited, add to frontier
            if not self.visited_cells[key] and not self.frontier_cells[key] then
                -- IMPORTANT: Only add to frontier if we don't think it has a pit or wumpus
                if self.ie:isSafe(nx, ny) and 
                   not self.kb:query("Pit_" .. nx .. "_" .. ny) and 
                   not self.kb:query("Wumpus_" .. nx .. "_" .. ny) then
                    -- Calculate a priority score for this frontier cell
                    -- Higher values = more promising to explore
                    local priority = 10 -- Base priority
                    
                    -- Bonus for cells farther from start (likely closer to gold)
                    local dist_from_start = math.abs(nx - Environment.START_X) + math.abs(ny - Environment.START_Y)
                    priority = priority + (dist_from_start * 4) -- Increased multiplier
                    
                    -- Bonus for cells in deeper parts of the grid
                    if nx > 4 and ny > 4 then
                        priority = priority + 20 -- Increased bonus for deeper cells
                    end
                    
                    -- Check if this cell is in an unexplored zone
                    local zone_x = math.floor((nx - 1) / 2) + 1
                    local zone_y = math.floor((ny - 1) / 2) + 1
                    local zone_key = zone_x .. "_" .. zone_y
                    
                    if not self.exploration_zones[zone_key] then
                        priority = priority + 30 -- Big bonus for new zones
                    elseif self.exploration_zones[zone_key].cells_visited < 2 then
                        priority = priority + 15 -- Bonus for partially explored zones
                    end
                    
                    -- Bonus based on how long it's been since we found a new cell
                    local steps_since_productive = self.step_counter - self.last_productive_step
                    if steps_since_productive > 10 then
                        priority = priority + (steps_since_productive * 2) -- Desperation bonus
                    end
                    
                    self.frontier_cells[key] = {
                        x = nx,
                        y = ny,
                        priority = priority,
                        discovered_at = self.step_counter
                    }
                    
                    print("Added frontier cell at [" .. nx .. "," .. ny .. "] with priority " .. priority)
                end
            end
        end
    end
    
    -- Remove current cell from frontier
    local current_key = self.x .. "_" .. self.y
    self.frontier_cells[current_key] = nil
    
    -- Age frontier cells - increase priority of older frontier cells
    for k, frontier in pairs(self.frontier_cells) do
        local age = self.step_counter - frontier.discovered_at
        if age > 3 then -- Reduced threshold for faster priority increase
            frontier.priority = frontier.priority + (age * 3) -- Increased multiplier
            -- Cap at reasonable value
            if frontier.priority > 150 then
                frontier.priority = 150
            end
        end
    end
end

-- Helper function to get adjacent cells
function Agent:getAdjacentCells(x, y)
    local adjacents = {}
    if Environment.is_valid_coord(x+1, y) then table.insert(adjacents, {x = x+1, y = y}) end
    if Environment.is_valid_coord(x-1, y) then table.insert(adjacents, {x = x-1, y = y}) end
    if Environment.is_valid_coord(x, y+1) then table.insert(adjacents, {x = x, y = y+1}) end
    if Environment.is_valid_coord(x, y-1) then table.insert(adjacents, {x = x, y = y-1}) end
    return adjacents
end

-- Enhanced loop detection with better pattern recognition
function Agent:detectLoop()
    self.loop_detected = false
    
    -- Check for lack of progress (no new cells discovered recently)
    local steps_since_productive = self.step_counter - self.last_productive_step
    if steps_since_productive > 15 then
        print("WARNING: No new cells discovered in " .. steps_since_productive .. " steps!")
        self.loop_detected = true
        self.risk_tolerance = math.min(100, self.risk_tolerance + 25)
        print("Increasing risk tolerance to " .. self.risk_tolerance .. " due to lack of progress")
    end
    
    -- Need at least 4 moves to detect movement loops
    if #self.move_history < 4 then return end
    
    -- Check for 2-move loop (going back and forth)
    if #self.move_history >= 4 then
        local pos1 = self.move_history[#self.move_history]
        local pos2 = self.move_history[#self.move_history - 1]
        local pos3 = self.move_history[#self.move_history - 2]
        local pos4 = self.move_history[#self.move_history - 3]
        
        -- Simple loop detection (A->B->A->B pattern)
        if pos1.x == pos3.x and pos1.y == pos3.y and
           pos2.x == pos4.x and pos2.y == pos4.y then
            self.loop_detected = true
            
            -- Block both positions in the loop
            local key1 = pos1.x .. "_" .. pos1.y
            local key2 = pos2.x .. "_" .. pos2.y
            self.blocked_moves[key1] = 8  -- Block for longer
            self.blocked_moves[key2] = 8
            print("Loop detected! Blocking moves to [" .. pos1.x .. "," .. pos1.y .. "] and [" .. pos2.x .. "," .. pos2.y .. "]")
            
            -- Increase risk tolerance when loops are detected
            self.risk_tolerance = math.min(100, self.risk_tolerance + 20)
            print("Increasing risk tolerance to " .. self.risk_tolerance)
        end
    end
    
    -- Check for longer patterns (like A->B->C->A->B->C)
    if #self.move_history >= 8 then
        local pattern_length = 4 -- Look for 4-step patterns
        local is_pattern = true
        
        for i = 1, pattern_length do
            local pos1 = self.move_history[#self.move_history - (i - 1)]
            local pos2 = self.move_history[#self.move_history - (i - 1) - pattern_length]
            
            if pos1.x ~= pos2.x or pos1.y ~= pos2.y then
                is_pattern = false
                break
            end
        end
        
        if is_pattern then
            self.loop_detected = true
            print("Detected " .. pattern_length .. "-step loop pattern! Will try to break out")
            
            -- Block all cells in the loop
            for i = 1, pattern_length do
                local pos = self.move_history[#self.move_history - (i - 1)]
                local key = pos.x .. "_" .. pos.y
                self.blocked_moves[key] = 10  -- Block for longer
            end
            
            -- Increase risk tolerance more for complex loops
            self.risk_tolerance = math.min(100, self.risk_tolerance + 30)
            print("Increasing risk tolerance to " .. self.risk_tolerance)
        end
    end
    
    -- Check for repeated visits to the same cell with enhanced penalties
    local current_key = self.x .. "_" .. self.y
    if self.cell_visits[current_key] and self.cell_visits[current_key] >= 2 then -- Lowered threshold
        print("Visited cell [" .. self.x .. "," .. self.y .. "] " .. 
              self.cell_visits[current_key] .. " times - will heavily penalize")
        
        -- Scale blocking time based on visit count
        local block_time = 5 + (self.cell_visits[current_key] * 3)
        self.blocked_moves[current_key] = block_time
        self.loop_detected = true
        
        -- Increase risk tolerance based on revisit count
        self.risk_tolerance = math.min(100, self.risk_tolerance + (self.cell_visits[current_key] * 8))
        print("Increasing risk tolerance to " .. self.risk_tolerance)
    end
    
    -- Check if we've been turning in the same place
    if #self.move_history >= 5 then
        local last_pos = self.move_history[#self.move_history]
        local stuck = true
        
        -- Check if we've been in the same position for the last 3+ moves
        for i = #self.move_history-1, math.max(1, #self.move_history-3), -1 do
            if self.move_history[i].x ~= last_pos.x or self.move_history[i].y ~= last_pos.y then
                stuck = false
                break
            end
        end
        
        if stuck then
            print("Agent appears to be stuck turning in place")
            self.risk_tolerance = math.min(100, self.risk_tolerance + 25)
            print("Increasing risk tolerance to " .. self.risk_tolerance)
        end
    end
end

-- Reduce counters for blocked moves
function Agent:updateBlockedMoves()
    local to_remove = {}
    for key, count in pairs(self.blocked_moves) do
        self.blocked_moves[key] = count - 1
        if self.blocked_moves[key] <= 0 then
            table.insert(to_remove, key)
        end
    end
    
    for _, key in ipairs(to_remove) do
        self.blocked_moves[key] = nil
        print("Unblocking move to " .. key)
    end
    
    -- Gradually reduce risk tolerance over time if no new loops and we're making progress
    local steps_since_productive = self.step_counter - self.last_productive_step
    if self.risk_tolerance > 0 and not self.loop_detected and steps_since_productive < 5 then
        self.risk_tolerance = math.max(0, self.risk_tolerance - 2) -- Faster reduction when making progress
    end
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

-- Enhanced risk calculation with much stronger revisit penalties
function Agent:calculateRiskScore(move)
    local key = move.x .. "_" .. move.y
    
    -- CRITICAL SAFETY CHECK: Never move to known pits or wumpuses
    if self.kb:query("Pit_" .. move.x .. "_" .. move.y) then
        print("DANGER: Cell [" .. move.x .. "," .. move.y .. "] has inferred pit")
        return 9999  -- Extremely high risk - never choose this move
    end
    
    if self.kb:query("Wumpus_" .. move.x .. "_" .. move.y) then
        print("DANGER: Cell [" .. move.x .. "," .. move.y .. "] has inferred wumpus")
        return 9999  -- Extremely high risk - never choose this move
    end
    
    local risk_score = 0
    
    -- ENHANCED REVISIT PENALTIES - Much stronger now
    if self.visited_cells[key] then
        local visit_count = self.cell_visits[key] or 0
        
        -- Exponentially increasing penalties for multiple visits
        if visit_count == 1 then
            risk_score = risk_score + 40 -- Moderate penalty for first revisit
        elseif visit_count == 2 then
            risk_score = risk_score + 120 -- High penalty for second revisit
        elseif visit_count >= 3 then
            risk_score = risk_score + (visit_count * 80) -- Severe penalty for multiple revisits
        end
        
        -- Additional penalty based on how recently this cell was visited
        local recency_penalty = 0
        for i = #self.move_history, math.max(1, #self.move_history - 8), -1 do
            if self.move_history[i].x == move.x and self.move_history[i].y == move.y then
                recency_penalty = recency_penalty + (10 - (i - (#self.move_history - 8))) * 15
            end
        end
        risk_score = risk_score + recency_penalty
        
        print("Cell [" .. move.x .. "," .. move.y .. "] revisit penalty: " .. (risk_score - 0) .. " (visits: " .. visit_count .. ")")
    else
        -- MASSIVE bonus for completely unvisited cells
        risk_score = risk_score - 150
        print("Cell [" .. move.x .. "," .. move.y .. "] gets new cell bonus: -150")
    end
    
    -- Check if this cell is a high-priority frontier cell
    if self.frontier_cells[key] then
        -- Apply a significant bonus based on the frontier priority
        local frontier_bonus = self.frontier_cells[key].priority
        risk_score = risk_score - frontier_bonus
        print("Cell [" .. move.x .. "," .. move.y .. "] gets frontier bonus: -" .. frontier_bonus)
    end
    
    -- Enhanced exploration zone bonuses
    local zone_x = math.floor((move.x - 1) / 2) + 1
    local zone_y = math.floor((move.y - 1) / 2) + 1
    local zone_key = zone_x .. "_" .. zone_y
    
    if not self.exploration_zones[zone_key] then
        risk_score = risk_score - 60 -- Big bonus for new exploration zones
        print("Cell [" .. move.x .. "," .. move.y .. "] in new zone, bonus: -60")
    elseif self.exploration_zones[zone_key].cells_visited < 3 then
        risk_score = risk_score - 30 -- Moderate bonus for partially explored zones
        print("Cell [" .. move.x .. "," .. move.y .. "] in partially explored zone, bonus: -30")
    end
    
    -- Check if move leads toward highest priority frontier
    local best_frontier_priority = 0
    local best_frontier = nil
    for frontier_key, frontier_cell in pairs(self.frontier_cells) do
        if frontier_cell.priority > best_frontier_priority then
            best_frontier_priority = frontier_cell.priority
            best_frontier = frontier_cell
        end
    end
    
    if best_frontier then
        local dist_to_frontier = math.abs(move.x - best_frontier.x) + math.abs(move.y - best_frontier.y)
        local current_dist = math.abs(self.x - best_frontier.x) + math.abs(self.y - best_frontier.y)
        
        -- If this move brings us closer to the highest priority frontier
        if dist_to_frontier < current_dist then
            local direction_bonus = (current_dist - dist_to_frontier) * 25
            risk_score = risk_score - direction_bonus
            print("Cell [" .. move.x .. "," .. move.y .. "] moves toward high-priority frontier, bonus: -" .. direction_bonus)
        end
    end
    
    -- DANGER CHECKS - Keep these the same as they're safety critical
    -- Check if unsafe due to stench (may contain Wumpus)
    if self.kb:query("Stench_" .. self.x .. "_" .. self.y) and 
       not self.kb:query("NoWumpus_" .. move.x .. "_" .. move.y) then
        risk_score = risk_score + 100  -- High risk for possible Wumpus
    end
    
    -- Check if unsafe due to breeze (may contain pit)
    if self.kb:query("Breeze_" .. self.x .. "_" .. self.y) and
       not self.kb:query("NoPit_" .. move.x .. "_" .. move.y) then
        risk_score = risk_score + 50  -- Medium risk for possible pit
    end
    
    -- Bonus for known safe cells
    if self.kb:query("NoWumpus_" .. move.x .. "_" .. move.y) and 
       self.kb:query("NoPit_" .. move.x .. "_" .. move.y) then
        risk_score = risk_score - 25
    end
    
    -- Penalize blocked moves heavily
    if self.blocked_moves[key] then
        risk_score = risk_score + (self.blocked_moves[key] * 50) -- Increased penalty
    end
    
    -- EFFICIENT MOVEMENT - Give slight preference to staying on course
    -- Prefer moves in direction we're already facing to minimize turning
    if move.dir == self.direction then
        risk_score = risk_score - 15 -- Increased bonus
    end
    
    -- After certain steps, encourage exploration of cells further from start
    if self.step_counter > 30 then
        local dist_from_start = math.abs(move.x - Environment.START_X) + math.abs(move.y - Environment.START_Y)
        risk_score = risk_score - (dist_from_start * 8) -- Increased bonus for distant cells
    end
    
    return risk_score
end

-- Find best move for returning home to [1,1]
function Agent:getBestMoveHome()
    local moves = self:getPossibleMoves()
    local best_move = nil
    local best_dist = 99999
    
    for _, move in ipairs(moves) do
        if self.ie:isSafe(move.x, move.y) and
           not self.ie:hasWumpus(move.x, move.y) and 
           not self.ie:hasPit(move.x, move.y) and
           not self.kb:query("Pit_" .. move.x .. "_" .. move.y) and 
           not self.kb:query("Wumpus_" .. move.x .. "_" .. move.y) then
            -- Manhattan distance to home
            local dist = math.abs(move.x - Environment.START_X) + math.abs(move.y - Environment.START_Y)
            if dist < best_dist then
                best_dist = dist
                best_move = move
            end
        end
    end
    
    return best_move
end

-- Modified to detect being stuck after just 1 step
function Agent:isStuckInPlace()
    -- Need at least 2 moves in history
    if #self.move_history < 2 then return false end
    
    -- If current position is same as previous position, we're stuck
    local curr_pos = {x = self.x, y = self.y}
    local prev_pos = self.move_history[#self.move_history]
    
    -- Consider agent stuck if it's in the same place as last turn
    if curr_pos.x == prev_pos.x and curr_pos.y == prev_pos.y then
        print("WARNING: Agent still in same position [" .. curr_pos.x .. "," .. curr_pos.y .. "] - must move!")
        return true
    end
    
    return false
end

-- Enhanced exploration move selection with better prioritization
function Agent:getExplorationMove()
    local moves = self:getPossibleMoves()
    local safe_move = nil
    local safe_moves = {} -- Only truly safe moves
    local risky_moves = {} -- Moves that have some risk but aren't known dangers
    
    -- Check if we were in the same place last turn
    local was_here_last_turn = self:isStuckInPlace()
    if was_here_last_turn then
        print("MOVEMENT REQUIRED: Must leave position [" .. self.x .. "," .. self.y .. "] this turn!")
        self.risk_tolerance = math.min(100, self.risk_tolerance + 50)
    end
    
    -- Update blocked moves counters
    self:updateBlockedMoves()
    
    -- Check for high-priority frontier cells
    local best_frontier = nil
    local best_frontier_priority = 0
    
    for k, frontier in pairs(self.frontier_cells) do
        if frontier.priority > best_frontier_priority then
            best_frontier_priority = frontier.priority
            best_frontier = frontier
        end
    end
    
    if best_frontier and best_frontier_priority > 40 then
        print("High priority frontier detected at [" .. best_frontier.x .. "," .. best_frontier.y .. 
              "] with priority " .. best_frontier_priority)
    end
    
    -- Evaluate all possible moves
    for _, move in ipairs(moves) do
        local move_key = move.x .. "_" .. move.y
        
        -- CRITICAL SAFETY CHECK: Never move to known pits or wumpuses
        if self.kb:query("Pit_" .. move.x .. "_" .. move.y) or 
           self.kb:query("Wumpus_" .. move.x .. "_" .. move.y) then
            print("DANGER: Avoiding known danger at [" .. move.x .. "," .. move.y .. "]")
            goto continue
        end
        
        -- Skip temporarily blocked moves unless we're stuck and risk tolerance is high
        if self.blocked_moves[move_key] and not (was_here_last_turn and self.risk_tolerance > 70) then
            goto continue
        end
        
        -- Calculate risk score
        move.risk_score = self:calculateRiskScore(move)
        
        -- Skip moves with extreme risk scores (they contain pits or wumpuses)
        if move.risk_score >= 9000 then
            goto continue
        end
        
        -- Determine safety level for this move
        local wumpus_risk = self.kb:query("Stench_" .. self.x .. "_" .. self.y) and 
                            not self.kb:query("NoWumpus_" .. move.x .. "_" .. move.y)
        
        local pit_risk = self.kb:query("Breeze_" .. self.x .. "_" .. self.y) and
                        not self.kb:query("NoPit_" .. move.x .. "_" .. move.y)
        
        -- Mark safety level in the move object
        if not wumpus_risk and not pit_risk and self.ie:isSafe(move.x, move.y) then
            move.safety = "safe"
            table.insert(safe_moves, move)
        else
            move.safety = "risky"
            table.insert(risky_moves, move)
        end
        
        ::continue::
    end
    
    -- Sort moves by risk score (lower is better)
    table.sort(safe_moves, function(a, b) return (a.risk_score or 0) < (b.risk_score or 0) end)
    table.sort(risky_moves, function(a, b) return (a.risk_score or 0) < (b.risk_score or 0) end)
    
    -- Enhanced debugging output
    print("=== MOVE EVALUATION ===")
    print("Steps since last new cell: " .. (self.step_counter - self.last_productive_step))
    print("Risk tolerance: " .. self.risk_tolerance)
    
    if #safe_moves > 0 then
        print("Safe moves available:")
        for i = 1, math.min(3, #safe_moves) do
            local move = safe_moves[i]
            local visits = self.cell_visits[move.x .. "_" .. move.y] or 0
            print("  " .. i .. ". [" .. move.x .. "," .. move.y .. "] - Risk: " .. move.risk_score .. " (visits: " .. visits .. ")")
        end
    end
    
    if #risky_moves > 0 then
        print("Risky moves available:")
        for i = 1, math.min(2, #risky_moves) do
            local move = risky_moves[i]
            local visits = self.cell_visits[move.x .. "_" .. move.y] or 0
            print("  " .. i .. ". [" .. move.x .. "," .. move.y .. "] - Risk: " .. move.risk_score .. " (visits: " .. visits .. ")")
        end
    end
    
    -- Choose best move based on situation with enhanced logic
    if #safe_moves > 0 then
        -- Prefer the lowest risk safe move
        safe_move = safe_moves[1]
        print("Selected safe move to [" .. safe_move.x .. "," .. safe_move.y .. "] with risk score " .. safe_move.risk_score)
    elseif was_here_last_turn and #risky_moves > 0 and self.risk_tolerance > 50 then
        -- We're stuck and need to take a risk
        safe_move = risky_moves[1]
        print("FORCED MOVE: Taking calculated risk to [" .. safe_move.x .. "," .. safe_move.y .. 
              "] with risk score " .. safe_move.risk_score)
    elseif #risky_moves > 0 and self.step_counter > 60 and self.risk_tolerance > 70 then
        -- Late game, high risk tolerance
        safe_move = risky_moves[1]
        print("LATE GAME RISK: Moving to [" .. safe_move.x .. "," .. safe_move.y .. 
              "] with risk score " .. safe_move.risk_score)
    end
    
    return safe_move
end

-- Add a function to plan paths to distant frontier cells
function Agent:planPathToFrontier()
    -- Only use path planning after we've explored a bit
    if self.step_counter < 15 then return nil end
    
    -- Find the highest priority frontier cell
    local best_frontier = nil
    local best_priority = 0
    
    for k, frontier in pairs(self.frontier_cells) do
        if frontier.priority > best_priority then
            best_priority = frontier.priority
            best_frontier = frontier
        end
    end
    
    -- If we found a good frontier and it's not adjacent
    if best_frontier and best_priority > 60 then
        local dist = math.abs(self.x - best_frontier.x) + math.abs(self.y - best_frontier.y)
        
        -- If it's more than 1 step away, try to plan a path
        if dist > 1 then
            print("Planning path to high-value frontier at [" .. best_frontier.x .. "," .. best_frontier.y .. 
                  "] with priority " .. best_priority)
            return best_frontier
        end
    end
    
    return nil
end

-- Turn the agent to a new direction
function Agent:turn()
    -- Check which directions would lead to useful cells
    local best_dir = nil
    local best_score = 999 -- Lower is better for risk scores
    local directions = {"right", "up", "left", "down"}
    
    -- Try to find a direction that leads to unexplored territory
    for _, dir in ipairs(directions) do
        local nx, ny = self.x, self.y
        if dir == "right" then nx = nx + 1
        elseif dir == "left" then nx = nx - 1
        elseif dir == "up" then ny = ny + 1
        elseif dir == "down" then ny = ny - 1 end
        
        if Environment.is_valid_coord(nx, ny) then
            -- Skip directions that lead to known dangers
            if self.kb:query("Pit_" .. nx .. "_" .. ny) or self.kb:query("Wumpus_" .. nx .. "_" .. ny) then
                goto continue
            end
            
            local move = {x = nx, y = ny, dir = dir}
            local risk_score = self:calculateRiskScore(move)
            
            -- If better than current best (lower is better), update
            if risk_score < best_score then
                best_score = risk_score
                best_dir = dir
            end
        end
        ::continue::
    end
    
    -- If we found a good direction, use it
    if best_dir then
        self.direction = best_dir
        print("Action: Turn to " .. self.direction .. " (strategic, score: " .. best_score .. ")")
    else
        -- Fall back to default turning behavior
        local current_dir_idx = 1
        for i, dir in ipairs(directions) do
            if dir == self.direction then
                current_dir_idx = i
                break
            end
        end
        local new_dir_idx = current_dir_idx % 4 + 1
        self.direction = directions[new_dir_idx]
        print("Action: Turn to " .. self.direction .. " (fallback)")
    end
    
    self.score = self.score - 1 -- Action cost
    self.has_bumped = false
end

-- Execute the next step of the agent
function Agent:step()
    self.step_counter = self.step_counter + 1
    print("\n=== STEP " .. self.step_counter .. " ===")
    print("Agent at [" .. self.x .. "," .. self.y .. "], Direction: " .. self.direction)
    
    -- Get percepts
    local percepts = Percepts.get_percepts(self.x, self.y, self.has_bumped, self.has_screamed)
    self.has_screamed = false -- Reset scream after one turn
    print("Percepts: [" .. table.concat(percepts, ", ") .. "]")
    
    -- Update knowledge base and run inference
    self.ie:update(self.x, self.y, percepts)
    
    -- Print only key KB facts to reduce clutter
    local facts = self.kb:getAllFacts()
    local important_facts = {}
    for _, fact in ipairs(facts) do
        if string.match(fact, "Pit_") or string.match(fact, "Wumpus_") or string.match(fact, "Stench_") or string.match(fact, "Breeze_") then
            table.insert(important_facts, fact)
        end
    end
    
    if #important_facts > 0 then
        print("Key Knowledge Base Facts:")
        for _, fact in ipairs(important_facts) do
            print("  " .. fact)
        end
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
        print("Gold found! Game Over")
        self.score = self.score + 1000 -- +1000 for finding gold
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
                self.kb:useArrow()
                self.score = self.score - 10 - 1 -- -10 for arrow, -1 for action
                break
            end
        end
    end
    
    -- EXPLORATION MODE with improved safety
    local safe_move = self:getExplorationMove()
    local must_move = self:isStuckInPlace()
    
    if safe_move then
        -- Final safety check before moving
        if self.kb:query("Pit_" .. safe_move.x .. "_" .. safe_move.y) or 
           self.kb:query("Wumpus_" .. safe_move.x .. "_" .. safe_move.y) then
            print("CRITICAL SAFETY CHECK: Not moving to [" .. safe_move.x .. "," .. safe_move.y .. "] - contains danger")
            self:turn() -- Just turn instead of moving to danger
        else
            -- Safe to move
            print("Action: Move to [" .. safe_move.x .. "," .. safe_move.y .. "]")
            self.x, self.y = safe_move.x, safe_move.y
            self.direction = safe_move.dir
            self.has_bumped = false
            self.score = self.score - 1
            self:markCurrentCell()
        end
    else
        -- No safe move found, turn instead
        if must_move then
            print("No safe move found despite needing to move - turning instead (safer than death)")
            self.risk_tolerance = math.min(100, self.risk_tolerance + 30) -- Increase risk tolerance for next turn
        end
        self:turn()
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

