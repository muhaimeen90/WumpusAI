local UI = {}

-- Tables to hold loaded images and messages
local images = {}
local messages = {}
-- Track persistent percept cells
local stench_cells = {}
local breeze_cells = {}

-- Load assets and set up UI
function UI.load()
    images.floor  = love.graphics.newImage("assets/parquet.png")
    images.pit    = love.graphics.newImage("assets/volcano.png")
    images.gold   = love.graphics.newImage("assets/gold.png")
    images.wumpus = love.graphics.newImage("assets/orc.png")
    images.player = love.graphics.newImage("assets/warrior.png")
    images.arrow  = love.graphics.newImage("assets/arrow.png")
    images.dead  = love.graphics.newImage("assets/zombie.png")
    images.smoke  = love.graphics.newImage("assets/poop.png")
    images.breeze   = love.graphics.newImage("assets/wind.png")
    images.cave   = love.graphics.newImage("assets/cave.png")

    -- Load sounds
    images.background_music = love.audio.newSource("assets/background_music.mp3", "stream")
    images.gold_found = love.audio.newSource("assets/gold_found.mp3", "static")
    images.kill_wumpus = love.audio.newSource("assets/kill_wumpus.mp3", "static")
    images.victory_sound = love.audio.newSource("assets/victory_sound.mp3", "static")
    
    -- Start background music
    images.background_music:setLooping(true)
    love.audio.play(images.background_music)

    -- Fonts for better UI
    UI.font = love.graphics.newFont(14)
    UI.titleFont = love.graphics.newFont(16)
    UI.smallFont = love.graphics.newFont(12)
    love.graphics.setFont(UI.font)
    -- Set a fitting background color
    love.graphics.setBackgroundColor(0.2, 0.2, 0.25, 1)
end

-- Add a message to display (max 5 retained)
function UI.addMessage(msg)
    table.insert(messages, msg)
    if #messages > 5 then
        table.remove(messages, 1)
    end
end

-- Stub for sound playback
function UI.playSound(name)
    if name == "grab" and images.gold_found then
        love.audio.play(images.gold_found)
    elseif name == "shoot" and images.kill_wumpus then
        love.audio.play(images.kill_wumpus)
    elseif name == "climb" and images.victory_sound then
        love.audio.play(images.victory_sound)
    end
end

-- Update UI (animations or effects)
function UI.update(dt)
    -- Simple animation timer for smooth effects
    if not UI.animTimer then UI.animTimer = 0 end
    UI.animTimer = UI.animTimer + dt
end

-- Draw the game UI: grid, environment, agent, and messages
function UI.draw(gameState)
    local gridSize = #gameState.environment
    local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
    
    -- Draw cave background full-screen
    love.graphics.draw(images.cave, 0, 0,
        0,
        winW / images.cave:getWidth(),
        winH / images.cave:getHeight())

    -- UI Layout: Left main game area, Right info panel
    local rightPanelWidth = 300
    local mainAreaWidth = winW - rightPanelWidth - 20
    local mainAreaHeight = winH - 40
    local tileSize = math.floor(math.min(mainAreaWidth, mainAreaHeight) / gridSize)
    local gridWidth = gridSize * tileSize
    local gridHeight = gridSize * tileSize
    local offsetX = 20 + (mainAreaWidth - gridWidth) / 2
    local offsetY = 20 + (mainAreaHeight - gridHeight) / 2


    -- Determine visited cells for fog of war
    local visited = gameState.visited or {}
    
    -- Draw wood floor everywhere
    for y = 1, gridSize do
        for x = 1, gridSize do
            local drawX = offsetX + (x-1)*tileSize
            local drawY = offsetY + (y-1)*tileSize
            love.graphics.draw(images.floor, drawX, drawY,
                0, tileSize/images.floor:getWidth(), tileSize/images.floor:getHeight())
        end
    end
    
    -- Overlay fog on unvisited cells
    love.graphics.setColor(0, 0, 0, 0.75)
    for y = 1, gridSize do
        for x = 1, gridSize do
            local key = x .. "_" .. y
            if not visited[key] then
                local drawX = offsetX + (x-1)*tileSize
                local drawY = offsetY + (y-1)*tileSize
                love.graphics.rectangle("fill", drawX, drawY, tileSize, tileSize)
            end
        end
    end
    love.graphics.setColor(1,1,1,1)

    -- Draw grid lines
    love.graphics.setColor(1,1,1,0.3)
    for i = 0, gridSize do
        -- horizontal
        love.graphics.line(offsetX, offsetY + i*tileSize, offsetX + gridWidth, offsetY + i*tileSize)
        -- vertical
        love.graphics.line(offsetX + i*tileSize, offsetY, offsetX + i*tileSize, offsetY + gridHeight)
    end
    love.graphics.setColor(1,1,1,1)

    -- Draw environment elements and percept indicators
    local ax, ay = gameState.agent.x, gameState.agent.y
    local percepts = gameState.percepts or {}
    
    -- Show stench and breeze on adjacent tiles of Wumpus and Pits after discovery
    local stenchCells, breezeCells = {}, {}
    -- Compute adjacency based on environment
    for y = 1, gridSize do
        for x = 1, gridSize do
            local cell = gameState.environment[y][x]
            if cell.has_wumpus and cell.is_wumpus_alive then
                for _,d in ipairs({{x+1,y},{x-1,y},{x,y+1},{x,y-1}}) do
                    local nx, ny = d[1], d[2]
                    if nx>=1 and nx<=gridSize and ny>=1 and ny<=gridSize then
                        stenchCells[nx.."_"..ny] = true
                    end
                end
            end
            if cell.has_pit then
                for _,d in ipairs({{x+1,y},{x-1,y},{x,y+1},{x,y-1}}) do
                    local nx, ny = d[1], d[2]
                    if nx>=1 and nx<=gridSize and ny>=1 and ny<=gridSize then
                        breezeCells[nx.."_"..ny] = true
                    end
                end
            end
        end
    end
    -- Draw indicators only on visited squares
    for key, _ in pairs(stenchCells) do
        if visited[key] then
            local sx, sy = key:match("(%d+)_(%d+)")
            sx, sy = tonumber(sx), tonumber(sy)
            local dx = offsetX + (sx-1)*tileSize
            local dy = offsetY + (sy-1)*tileSize
            love.graphics.draw(images.smoke, dx, dy, 0,
                tileSize/images.smoke:getWidth(), tileSize/images.smoke:getHeight())
        end
    end
    for key, _ in pairs(breezeCells) do
        if visited[key] then
            local sx, sy = key:match("(%d+)_(%d+)")
            sx, sy = tonumber(sx), tonumber(sy)
            local dx = offsetX + (sx-1)*tileSize
            local dy = offsetY + (sy-1)*tileSize
            love.graphics.draw(images.breeze, dx, dy, 0,
                tileSize/images.breeze:getWidth(), tileSize/images.breeze:getHeight())
        end
    end

    -- Draw player on top
    local agentX = offsetX + (ax-1)*tileSize + tileSize/2
    local agentY = offsetY + (ay-1)*tileSize + tileSize/2
    local bounce = math.sin((UI.animTimer or 0) * 4) * 2
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(images.player,
        agentX, agentY + bounce,
        0,
        tileSize/images.player:getWidth(),
        tileSize/images.player:getHeight(),
        images.player:getWidth()/2,
        images.player:getHeight()/2)
    love.graphics.setColor(1,1,1,1)

    -- RIGHT PANEL - Information Area
    local panelX = winW - rightPanelWidth - 10
    local panelY = 10
    -- No background panel fill for cleaner UI
    love.graphics.setColor(1,1,1,1)
    
    -- Messages section
    love.graphics.setFont(UI.titleFont)
    love.graphics.print("Game Status", panelX, panelY)
    love.graphics.setFont(UI.smallFont)
    local msgY = panelY + 25
    for i, m in ipairs(messages) do
        love.graphics.print(m, panelX, msgY + (i-1)*18)
    end
    
    -- Stats section
    love.graphics.setFont(UI.titleFont)
    love.graphics.print("Statistics", panelX, msgY + 120)
    love.graphics.setFont(UI.font)
    love.graphics.print("Score: " .. gameState.agent.score, panelX, msgY + 145)
    local arrowCount = gameState.kb.hasArrow and 1 or 0
    love.graphics.print("Arrows: " .. arrowCount, panelX, msgY + 165)
    
    -- Arrow icon
    local iconScale = 32 / images.arrow:getWidth()
    if gameState.kb.hasArrow then
        love.graphics.setColor(1,1,1,1)
    else
        love.graphics.setColor(0.5,0.5,0.5,1)
    end
    love.graphics.draw(images.arrow, panelX + 80, msgY + 160, 0, iconScale, iconScale)
    love.graphics.setColor(1,1,1,1)
    -- Large congratulations message on victory
    if gameState.isGameOver and gameState.winMessage and gameState.winMessage:find("VICTORY") then
        love.graphics.setFont(UI.titleFont)
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf("Congratulations!", 0, winH/2 - 30, winW, "center")
        love.graphics.printf("You won the Wumpus World!", 0, winH/2 + 10, winW, "center")
        love.graphics.setColor(1,1,1,1)
    end
    
    -- Knowledge Base section
    love.graphics.setFont(UI.titleFont)
    love.graphics.print("Knowledge Base", panelX, msgY + 200)
    love.graphics.setFont(UI.smallFont)
    local kbFacts = gameState.kb.facts or {}
    for i, fact in ipairs(kbFacts) do
        if i > 8 then break end
        love.graphics.print(fact, panelX, msgY + 220 + i * 16)
    end

    -- Enhanced Minimap
    local miniSize = 200
    local miniX = panelX + 10
    local miniY = msgY + 370
    local miniTile = miniSize / gridSize
    
    -- Minimap title and background
    love.graphics.setFont(UI.titleFont)
    love.graphics.print("Full Map", miniX, miniY - 25)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", miniX-5, miniY-5, miniSize+10, miniSize+10)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("line", miniX-5, miniY-5, miniSize+10, miniSize+10)
    love.graphics.setColor(1,1,1,1)
    
    -- Draw minimap content
    for y = 1, gridSize do
        for x = 1, gridSize do
            local cell = gameState.environment[y][x]
            local dx = miniX + (x-1)*miniTile
            local dy = miniY + (y-1)*miniTile
            
            -- draw floor
            love.graphics.draw(images.floor, dx, dy, 0, miniTile/images.floor:getWidth(), miniTile/images.floor:getHeight())
            
            -- draw elements
            if cell.has_pit then
                love.graphics.draw(images.pit, dx, dy, 0, miniTile/images.pit:getWidth(), miniTile/images.pit:getHeight())
            end
            if cell.has_wumpus and cell.is_wumpus_alive then
                love.graphics.draw(images.wumpus, dx, dy, 0, miniTile/images.wumpus:getWidth(), miniTile/images.wumpus:getHeight())
            end
            if cell.has_gold then
                love.graphics.draw(images.gold, dx, dy, 0, miniTile/images.gold:getWidth(), miniTile/images.gold:getHeight())
            end
            
            -- Highlight agent position
            if x == ax and y == ay then
                love.graphics.setColor(1, 1, 0, 0.5)
                love.graphics.rectangle("fill", dx, dy, miniTile, miniTile)
                love.graphics.setColor(1,1,1,1)
            end
        end
    end
    
    love.graphics.setColor(1,1,1,1)
end

-- Draw menu screen
function UI.drawMenu()
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    
    -- Background gradient
    love.graphics.setColor(0.1, 0.1, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)
    
    -- Title
    love.graphics.setFont(UI.titleFont)
    love.graphics.setColor(0.9, 0.8, 0.6, 1)
    local title = "WUMPUS WORLD AI"
    local titleWidth = UI.titleFont:getWidth(title)
    love.graphics.print(title, (windowWidth - titleWidth) / 2, 100)
    
    -- Subtitle
    love.graphics.setFont(UI.font)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local subtitle = "Choose your adventure"
    local subtitleWidth = UI.font:getWidth(subtitle)
    love.graphics.print(subtitle, (windowWidth - subtitleWidth) / 2, 140)
    
    -- Menu options
    love.graphics.setFont(UI.font)
    local centerX = windowWidth / 2
    local startY = 200
    local spacing = 80
    
    -- Option 1: Predefined Grid
    love.graphics.setColor(0.8, 0.9, 0.6, 1)
    local option1 = "1 - PREDEFINED GRID"
    local opt1Width = UI.font:getWidth(option1)
    love.graphics.print(option1, centerX - opt1Width / 2, startY)
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    local desc1 = "Play with carefully crafted environments"
    local desc1Width = UI.font:getWidth(desc1)
    love.graphics.print(desc1, centerX - desc1Width / 2, startY + 20)
    
    -- Option 2: Random Grid
    love.graphics.setColor(0.9, 0.7, 0.5, 1)
    local option2 = "2 - RANDOM GRID"
    local opt2Width = UI.font:getWidth(option2)
    love.graphics.print(option2, centerX - opt2Width / 2, startY + spacing)
    
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    local desc2 = "Generate a random Wumpus World"
    local desc2Width = UI.font:getWidth(desc2)
    love.graphics.print(desc2, centerX - desc2Width / 2, startY + spacing + 20)
    
    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setFont(UI.smallFont)
    local instructions = "Press 1 or 2 to select • ESC to quit"
    local instWidth = UI.smallFont:getWidth(instructions)
    love.graphics.print(instructions, centerX - instWidth / 2, windowHeight - 50)
    
    -- Reset color and font
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(UI.font)
end

return UI