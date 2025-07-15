-- main.lua
-- LÖVE 2D main controller for Wumpus World AI
-- Orchestrates game logic, UI, and user interaction

-- Clear module cache for development
package.loaded["environment"] = nil
package.loaded["percepts"] = nil
package.loaded["knowledge_base"] = nil
package.loaded["inference_engine"] = nil
package.loaded["agent"] = nil
package.loaded["ui"] = nil

-- Load all required modules
local Environment = require("environment")
local KnowledgeBase = require("knowledge_base")
local InferenceEngine = require("inference_engine")
local Agent = require("agent")
local Percepts = require("percepts")
local UI = require("ui")

-- Game state variables
local gameState = {}
local kb, ie, agent
local aiTimer = 0
local AI_TURN_DELAY = 0.5 -- Seconds between AI turns (faster)
local isGameRunning = false
local isGameOver = false
local winMessage = ""
local lastPercepts = {}
local stepCount = 0
local maxSteps = 200

-- Menu state
local gameMode = "menu" -- "menu", "predefined", "random"
local menuSelection = 1 -- 1 = predefined, 2 = random

-- Console output for debugging
local function debugPrint(...)
    print(...)
end

-- Initialize game logic
local function initializeGame(useRandom)
    -- Create game logic objects
    kb = KnowledgeBase.new()
    ie = InferenceEngine.new(kb)
    agent = Agent.new(kb, ie)
    
    -- Load environment based on selection
    if useRandom then
        Environment.generate_random_environment()
        UI.addMessage("Random environment generated!")
        debugPrint("Wumpus World initialized with random environment")
    else
        Environment.load_grid_environment_from_file("sample1.txt")
        UI.addMessage("Predefined environment loaded!")
        debugPrint("Wumpus World initialized with sample1.txt")
    end
    
    -- Reset game state
    isGameRunning = true
    isGameOver = false
    winMessage = ""
    stepCount = 0
    aiTimer = 0
    lastPercepts = {"None", "None", "None", "None", "None"}
    
    -- Initialize UI messages
    UI.addMessage("Game started! Agent begins at [1,1]")
end

-- Build game state for UI
local function buildGameState()
    local agent_x, agent_y = agent:getPosition()
    
    gameState = {
        agent = {
            x = agent_x,
            y = agent_y,
            direction = agent.direction,
            score = agent:getScore(),
            hasGold = agent.has_gold
        },
        kb = {
            hasArrow = kb:hasArrow(),
            facts = kb:getAllFacts()
        },
        percepts = lastPercepts,
        environment = Environment.get_grid(),
        visited = agent.visited_cells,
        isGameOver = isGameOver,
        winMessage = winMessage
    }
end

-- Execute one AI step
local function executeAIStep()
    if not isGameRunning or isGameOver then return end
    
    stepCount = stepCount + 1
    local agent_x, agent_y = agent:getPosition()
    
    -- Get current percepts
    lastPercepts = Percepts.get_percepts(agent_x, agent_y, agent.has_bumped, agent.has_screamed)
    
    -- Log step info
    debugPrint("Step " .. stepCount .. ": Agent at [" .. agent_x .. "," .. agent_y .. "]")
    debugPrint("Percepts: [" .. table.concat(lastPercepts, ", ") .. "]")
    
    -- Check for specific percepts and play sounds
    for _, percept in ipairs(lastPercepts) do
        if percept == "Scream" then
            UI.playSound("scream")
        elseif percept == "Glitter" then
            UI.playSound("grab")
        elseif percept == "Bump" then
            UI.playSound("bump")
        end
    end
    
    -- Execute agent step
    local previousScore = agent:getScore()
    isGameRunning = agent:step()
    local newScore = agent:getScore()
    
    -- Determine what action was taken based on score change and agent state
    if newScore < previousScore then
        local scoreDiff = previousScore - newScore
        if scoreDiff == 11 then -- Shot arrow (-10) + action (-1)
            UI.playSound("shoot")
            UI.addMessage("Agent shot an arrow!")
        elseif scoreDiff == 1 then -- Regular move
            UI.playSound("move")
        elseif scoreDiff == 1000 then -- Death
            UI.addMessage("Agent died!")
            isGameOver = true
            winMessage = "AGENT DIED - GAME OVER"
        end
    elseif newScore > previousScore then
        local scoreDiff = newScore - previousScore
        if scoreDiff == 999 then -- Won with gold (+1000 - 1)
            UI.playSound("climb")
            UI.addMessage("Agent escaped with gold!")
            UI.addMessage("Congratulations! You found the gold and escaped!")
            isGameOver = true
            winMessage = "VICTORY! Agent escaped with the gold!"
        end
    end
    
    -- Check for maximum steps
    if stepCount >= maxSteps then
        UI.addMessage("Maximum steps reached!")
        isGameOver = true
        winMessage = "GAME OVER - Maximum steps reached"
        isGameRunning = false
    end
    
    -- Check if game should end
    if not isGameRunning and not isGameOver then
        isGameOver = true
        winMessage = "GAME OVER"
    end
    
    debugPrint("Score: " .. agent:getScore())
end

-- LÖVE 2D callback: Initialize
function love.load()
    -- Set up window
    love.window.setTitle("Wumpus World AI")
    love.window.setMode(800, 600, {resizable = false})
    
    -- Initialize UI
    UI.load()
    
    -- Start in menu mode
    gameMode = "menu"
    
    debugPrint("LÖVE 2D Wumpus World loaded successfully!")
end

-- LÖVE 2D callback: Update
function love.update(dt)
    -- Update UI animations
    UI.update(dt)
    
    -- Only update game logic if not in menu
    if gameMode ~= "menu" then
        -- Update AI timer
        if isGameRunning and not isGameOver then
            aiTimer = aiTimer + dt
            if aiTimer >= AI_TURN_DELAY then
                aiTimer = 0
                executeAIStep()
            end
        end
        
        -- Build current game state for rendering
        buildGameState()
    end
end

-- LÖVE 2D callback: Draw
function love.draw()
    if gameMode == "menu" then
        UI.drawMenu()
    else
        UI.draw(gameState)
        
        -- Draw debug info in top-left corner
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print("Step: " .. stepCount .. "/" .. maxSteps, 10, 10)
        if isGameRunning and not isGameOver then
            local timeToNext = AI_TURN_DELAY - aiTimer
            love.graphics.print("Next AI turn in: " .. string.format("%.1f", timeToNext) .. "s", 10, 30)
        end
        love.graphics.print("Press SPACE for manual step", 10, 50)
        love.graphics.print("Press R to restart", 10, 70)
        love.graphics.print("Press ESC for menu", 10, 90)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- LÖVE 2D callback: Key pressed
function love.keypressed(key)
    if gameMode == "menu" then
        if key == "1" then
            menuSelection = "predefined"
            gameMode = "game"
            initializeGame(false) -- Use predefined environment
        elseif key == "2" then
            menuSelection = "random"
            gameMode = "game"
            initializeGame(true) -- Use random environment
        elseif key == "escape" then
            love.event.quit()
        end
    else
        if key == "space" then
            -- Manual AI step trigger
            if isGameRunning and not isGameOver then
                executeAIStep()
                aiTimer = 0 -- Reset timer
            end
        elseif key == "r" then
            -- Restart game with same mode
            local useRandom = (menuSelection == "random")
            initializeGame(useRandom)
            debugPrint("Game restarted!")
        elseif key == "escape" then
            -- Return to menu
            gameMode = "menu"
            isGameRunning = false
            isGameOver = false
        elseif key == "1" then
            -- Load sample1.txt
            Environment.load_grid_environment_from_file("sample1.txt")
            initializeGame(false)
            debugPrint("Loaded sample1.txt")
        elseif key == "2" then
            -- Load sample2.txt
            Environment.load_grid_environment_from_file("sample2.txt")
            initializeGame(false)
            debugPrint("Loaded sample2.txt")
        elseif key == "d" then
            -- Toggle debug info
            local facts = kb:getAllFacts()
            debugPrint("=== KNOWLEDGE BASE FACTS ===")
            for _, fact in ipairs(facts) do
                debugPrint("  " .. fact)
            end
            debugPrint("=============================")
        end
    end
end

-- LÖVE 2D callback: Quit
function love.quit()
    debugPrint("Wumpus World shutting down...")
end