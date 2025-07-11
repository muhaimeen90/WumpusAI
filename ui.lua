local UI = {}

-- Tables to hold loaded images and messages
local images = {}
local messages = {}

-- Load assets and set up UI
function UI.load()
    images.floor  = love.graphics.newImage("assets/wood.png")
    images.pit    = love.graphics.newImage("assets/hole.png")
    images.gold   = love.graphics.newImage("assets/gold.png")
    images.wumpus = love.graphics.newImage("assets/ogre.png")
    images.player = love.graphics.newImage("assets/player.png")
    -- Optional assets (not critical): arrow, blood, smoke, dirt
    images.arrow  = love.graphics.newImage("assets/arrow.png")
    images.blood  = love.graphics.newImage("assets/cobble_blood1.png")
    images.smoke  = love.graphics.newImage("assets/smoke.png")
    images.dirt   = love.graphics.newImage("assets/dirt_e.png")
    images.cave   = love.graphics.newImage("assets/cave.png")

    -- Font for messages
    UI.font = love.graphics.newFont(14)
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

-- Stub for sound playback (no sound assets provided)
function UI.playSound(name)
    -- sound functionality can be added if sound files are available
end

-- Update UI (animations or effects)
function UI.update(dt)
    -- placeholder for animations
end

-- Draw the game UI: grid, environment, agent, and messages
function UI.draw(gameState)
    local gridSize = #gameState.environment
    local winW, winH = love.graphics.getWidth(), love.graphics.getHeight()
    local tileSize = math.floor(math.min(winW, winH - 100) / gridSize)
    local offsetX = (winW - gridSize * tileSize) / 2
    local offsetY = (winH - gridSize * tileSize) / 2

    -- Draw cave background full-screen
    love.graphics.draw(images.cave, 0, 0,
        0,
        winW / images.cave:getWidth(),
        winH / images.cave:getHeight())

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
    love.graphics.setColor(1,1,1,0.2)
    for i = 0, gridSize do
        -- horizontal
        love.graphics.line(offsetX, offsetY + i*tileSize, offsetX + gridSize*tileSize, offsetY + i*tileSize)
        -- vertical
        love.graphics.line(offsetX + i*tileSize, offsetY, offsetX + i*tileSize, offsetY + gridSize*tileSize)
    end
    love.graphics.setColor(1,1,1,1)

    -- Draw environment elements only on visited cells
    for y = 1, gridSize do
        for x = 1, gridSize do
            local key = x .. "_" .. y
            if visited[key] then
                local cell = gameState.environment[y][x]
                if cell.has_pit then
                    love.graphics.draw(images.pit, offsetX + (x-1)*tileSize, offsetY + (y-1)*tileSize,
                        0, tileSize/images.pit:getWidth(), tileSize/images.pit:getHeight())
                end
                if cell.has_wumpus and cell.is_wumpus_alive then
                    love.graphics.draw(images.wumpus, offsetX + (x-1)*tileSize, offsetY + (y-1)*tileSize,
                        0, tileSize/images.wumpus:getWidth(), tileSize/images.wumpus:getHeight())
                end
                if cell.has_gold then
                    love.graphics.draw(images.gold, offsetX + (x-1)*tileSize, offsetY + (y-1)*tileSize,
                        0, tileSize/images.gold:getWidth(), tileSize/images.gold:getHeight())
                end
            end
        end
    end

    -- Show smoke effect on breeze or stench at agent tile
    local ax, ay = gameState.agent.x, gameState.agent.y
    local percepts = gameState.percepts or {}
    if percepts[1] == "Stench" or percepts[2] == "Breeze" then
        love.graphics.draw(images.smoke,
            offsetX + (ax-1)*tileSize,
            offsetY + (ay-1)*tileSize,
            0,
            tileSize/images.smoke:getWidth(),
            tileSize/images.smoke:getHeight())
    end

    -- Draw agent with rotation
    local ax, ay = gameState.agent.x, gameState.agent.y
    local dir = gameState.agent.direction
    local rot = 0
    if dir == "up" then rot = -math.pi/2 elseif dir == "left" then rot = math.pi elseif dir == "down" then rot = math.pi/2 end
    love.graphics.draw(images.player,
        offsetX + (ax-1)*tileSize + tileSize/2,
        offsetY + (ay-1)*tileSize + tileSize/2,
        rot,
        tileSize/images.player:getWidth(),
        tileSize/images.player:getHeight(),
        images.player:getWidth()/2,
        images.player:getHeight()/2)

    -- Draw messages and stats
    love.graphics.setColor(1,1,1,1)
    local msgX, msgY = 10, 10
    for i, m in ipairs(messages) do
        love.graphics.print(m, msgX, msgY + (i-1)*20)
    end

    -- Draw score and arrow info
    love.graphics.print("Score: " .. gameState.agent.score, 10, winH - 50)
    local arrowCount = gameState.kb.hasArrow and 1 or 0
    love.graphics.print("Arrows: " .. arrowCount, 10, winH - 30)

    -- Define minimap size for both minimap and KB panel
    local miniSize = 150
    -- Draw arrow icon (disabled if used)
    local iconScale = (tileSize * 0.5) / images.arrow:getWidth()
    local arrowX = 10
    local arrowY = winH - 90
    if gameState.kb.hasArrow then
        love.graphics.setColor(1,1,1,1)
    else
        love.graphics.setColor(0.5,0.5,0.5,1)
    end
    love.graphics.draw(images.arrow, arrowX, arrowY, 0, iconScale, iconScale)
    love.graphics.setColor(1,1,1,1)

    -- Draw snapshot of agent's Knowledge Base (first 10 facts)
    local kbFacts = gameState.kb.facts or {}
    local kbX = 10 -- shift KB panel to left margin
    local kbY = miniSize + 20
    love.graphics.print("Knowledge Base:", kbX, kbY)
    for i, fact in ipairs(kbFacts) do
        if i > 10 then break end
        love.graphics.print(fact, kbX, kbY + i * 15)
    end

    -- Draw minimap revealing full environment
    local mOffX = winW - miniSize - 10
    local mOffY = 10
    local miniTile = miniSize / gridSize
    -- Background for minimap
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", mOffX-5, mOffY-5, miniSize+10, miniSize+10)
    love.graphics.setColor(1,1,1,1)
    for y = 1, gridSize do
        for x = 1, gridSize do
            local cell = gameState.environment[y][x]
            local dx = mOffX + (x-1)*miniTile
            local dy = mOffY + (y-1)*miniTile
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
        end
    end
    love.graphics.setColor(1,1,1,1)
end

return UI