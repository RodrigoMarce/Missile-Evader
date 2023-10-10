-- Mainly setup and variable definition.
local VIRTUAL_WIDTH = 384
local VIRTUAL_HEIGHT = 216
local WINDOW_WIDTH = 1280
local WINDOW_HEIGHT = 720

local PLATFORM_HEIGHT = 6 
local PLATFORM_WIDTH = 50
local PLATFORM_SPEED = 140

local CHARACTER_HEIGHT = 43
local CHARACTER_WIDTH = 32
local CHARACTER_SPEED = 80
local MISSILE_SPEED = 100

local LARGE_FONT = love.graphics.newFont(32)
local SMALL_FONT = love.graphics.newFont(16)

push = require "push"
tick = require "tick"

local missileImage
local fallingImage
local standingImage
local falling = true

-- Defines platform and character objects.
local platform = {
    x = VIRTUAL_WIDTH / 2 - PLATFORM_WIDTH / 2,
    y = VIRTUAL_HEIGHT - 10 - PLATFORM_HEIGHT,
    width = PLATFORM_WIDTH,
    height = PLATFORM_HEIGHT
}

local character = {
    x = VIRTUAL_WIDTH / 2 - CHARACTER_WIDTH / 2,
    y = VIRTUAL_HEIGHT - 10 - PLATFORM_HEIGHT - CHARACTER_HEIGHT - 80,
    width = CHARACTER_WIDTH,
    height = CHARACTER_HEIGHT
}

local rightMissiles = {}
local leftMissiles = {}
local coins = {}
local frames = {}

local gameState = "title"
local delay = 2.5
local score = 0
local currentFrame = 1
local level = 1

function love.load()
    math.randomseed(os.time())
    love.graphics.setDefaultFilter("nearest", "nearest")
    push:setupScreen(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, WINDOW_WIDTH, WINDOW_HEIGHT)
    missileImage = love.graphics.newImage("images/missile.png")
    fallingImage = love.graphics.newImage("images/falling.png")
    standingImage = love.graphics.newImage("images/standing.png")
    for i=1, 2 do
        table.insert(frames, love.graphics.newImage("images/coin" .. i .. ".png"))
    end
    tick.recur(function() launch() end , delay)
    tick.recur(function() createCoin() end , 2 + math.random(4))
    song = love.audio.newSource("audio/song.wav", "stream")
    boom = love.audio.newSource("audio/boom.wav", "static")
    cling = love.audio.newSource("audio/cling.wav", "static")
    song:setLooping(true)
    song:setVolume(0.75)
    boom:setVolume(0.5)
end

function love.update(dt)
    if gameState == "play" then
        song:play()
        tick.update(dt)
        -- Manages frame changes for coins.
        currentFrame = currentFrame + dt * 4
        if currentFrame >= 3 then
            currentFrame = 1
        end
        -- Allows user to move the platform with up, down, right and left arrows.
        if love.keyboard.isDown("right") then
            platform.x = platform.x + PLATFORM_SPEED * dt
        elseif love.keyboard.isDown("left") then
            platform.x = platform.x - PLATFORM_SPEED * dt
        elseif love.keyboard.isDown("up") then
            platform.y = platform.y - PLATFORM_SPEED * dt
        elseif love.keyboard.isDown("down") then
            platform.y = platform.y + PLATFORM_SPEED * dt
        end   
        
        -- Avoids platform from going off screen.
        if platform.x < 0 then
            platform.x = 0
        elseif platform.x > VIRTUAL_WIDTH - PLATFORM_WIDTH then
            platform.x = VIRTUAL_WIDTH - PLATFORM_WIDTH
        elseif platform.y > VIRTUAL_HEIGHT - PLATFORM_HEIGHT then
            platform.y = VIRTUAL_HEIGHT - PLATFORM_HEIGHT
        elseif platform.y < CHARACTER_HEIGHT then
            platform.y = CHARACTER_HEIGHT
        end

        -- Makes the character fall unless it is in contact with the platform. Falling variable is used for the change of sprites.
        if collision (platform, character) then
            character.y = platform.y - CHARACTER_HEIGHT
            character.x = platform.x + PLATFORM_WIDTH / 2 - CHARACTER_WIDTH / 2
            falling = false
        else
            character.y = character.y + CHARACTER_SPEED * dt
            falling = true
        end 

        -- Game is over if character falls below the screen or if he is taken above the screen.
        if character.y > VIRTUAL_HEIGHT then
            gameState = "gameover"
        end
        
        -- Check for collisions between the character and missiles. If true, game over.
        for i,missile in ipairs(rightMissiles) do
            missile.x = missile.x - missile.speed * dt
            if collision(missile, character) then
                song:stop()
                boom:play()
                gameState = "gameover"
            end
        end
        for i, missile in ipairs(leftMissiles) do
            missile.x = missile.x + missile.speed * dt
            if collision(missile, character) then
                song:stop()
                boom:play()
                gameState = "gameover"
            end
        end

        -- Check for collisions between the character and coins. If true, hide that coin and add 1 to user's score.
        for i, coin in ipairs(coins) do
            if collision(coin, character) then
                love.audio.play(cling)
                table.remove(coins, i)
                score = score + 1
            end
        end

        -- User levels up when score is 5. Wins after 5 levels.
        if score == 5 then
            level = level + 1
            gameState = "nextLevel"
            reset()
            delay = delay * 0.5
            MISSILE_SPEED = MISSILE_SPEED * 1.3
        elseif level == 6 then
            gameState = "win"
        end
    end
end

function love.keypressed(key)
    -- Closes game when escape key is pressed.
    if key == "escape" then
        love.event.quit()
    end
    
    -- Manages the change of game states.
    if key == "return" or key == "enter" then
        if gameState == "title" then
            gameState = "instructions"
        elseif gameState == "instructions" then
            gameState = "play"
        elseif gameState == "nextLevel" then
            gameState = "play"
        elseif gameState == "gameover" or gameState == "win" then
            gameState = "title"
            level = 1
            MISSILE_SPEED = 100
            delay = 2.5
            reset()
        end
    end
end    

function love.draw()
    push:start()
    love.graphics.clear(40/255, 45/255, 52/255, 255/255)

    -- Draws title.
    if gameState == "title" then
        love.graphics.setFont(LARGE_FONT)
        love.graphics.printf("Missile Evader", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
        love.graphics.setFont(SMALL_FONT)
        love.graphics.printf("Press Enter", 0, VIRTUAL_HEIGHT - 32, VIRTUAL_WIDTH, "center")
    end

    -- Draws How to Play screen.
    if gameState == "instructions" then
        love.graphics.setFont(LARGE_FONT)
        love.graphics.printf("How To Play", 0, 10, VIRTUAL_WIDTH, "center")
        love.graphics.setFont(SMALL_FONT)
        love.graphics.printf("Evade the missiles and collect the coins to win.", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
        love.graphics.printf("Use arrows to move the platform.", 0, VIRTUAL_HEIGHT / 2 + 20, VIRTUAL_WIDTH, "center")
        love.graphics.printf("Press Enter", 0, VIRTUAL_HEIGHT - 32, VIRTUAL_WIDTH, "center")
    end

    if gameState == "play" then
        -- Draws platform.
        love.graphics.rectangle("fill", platform.x, platform.y, platform.width, platform.height)

        -- Changes between sprites depending on whether the character is falling or not.
        if falling then
            love.graphics.draw(fallingImage, character.x, character.y, 0)
        else
            love.graphics.draw(standingImage, character.x, character.y, 0)        
        end

        -- Draws missiles.
        for i, missile in ipairs(rightMissiles) do
            love.graphics.draw(missileImage, missile.x, missile.y, math.pi, 0.25, 0.25, missileImage:getWidth(), 0)
        end

        for i, missile in ipairs(leftMissiles) do
            love.graphics.draw(missileImage, missile.x, missile.y, 0, 0.25, 0.25)
        end

        -- Draws coins.
        for i, coin in ipairs(coins) do
            love.graphics.draw(frames[math.floor(currentFrame)], coin.x, coin.y)
        end

        -- Displays user's score and level.
        love.graphics.setFont(SMALL_FONT)
        love.graphics.print("Score: " ..score, VIRTUAL_WIDTH - 80, 10)
        love.graphics.print("Level: " ..level, 10, 10)
    end

    -- Draws Game Over screen.
    if gameState == "gameover" then
        love.graphics.setFont(LARGE_FONT)
        love.graphics.printf("Game Over", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
        love.graphics.setFont(SMALL_FONT)
        love.graphics.printf("Press Enter to Retry", 0, VIRTUAL_HEIGHT - 32, VIRTUAL_WIDTH, "center")
    end

    -- Draws You Win! screen.
    if gameState == "win" then
        love.graphics.setFont(LARGE_FONT)
        love.graphics.printf("You Win!", 0, VIRTUAL_HEIGHT / 2 - 20, VIRTUAL_WIDTH, "center")
        love.graphics.setFont(SMALL_FONT)
        love.graphics.printf("Press Enter to Play Again", 0, VIRTUAL_HEIGHT - 32, VIRTUAL_WIDTH, "center")
    end

    -- Shows state between levels.
    if gameState == "nextLevel" then
        love.graphics.setFont(LARGE_FONT)
        love.graphics.printf("Level Up!", 0, 20, VIRTUAL_WIDTH, "center")
        love.graphics.setFont(SMALL_FONT)
        love.graphics.printf("Press Enter to Continue", 0, VIRTUAL_HEIGHT - 32, VIRTUAL_WIDTH, "center")
    end

    push:finish()
end

-- Defines collision.
function collision(p, b)
    return not (p.x > b.x + b.width or p.y > b.y + b.height or b.x > p.x + p.width or b.y > p.y + p.height)
end

-- Creates a missile incoming from the left side of the screen.
function createLeftMissile()
    local missile = {
        x = 0,
        y = 30 + math.random(VIRTUAL_HEIGHT - 50),
        speed = MISSILE_SPEED,
        height = missileImage:getHeight() * 0.25,
        width = missileImage:getWidth() * 0.25
    }
    table.insert(leftMissiles, missile)
end

-- Creates a missile incoming from the right side of the screen.
function createRightMissile()
    local missile = {
        x = VIRTUAL_WIDTH,
        y = 30 + math.random(VIRTUAL_HEIGHT - 50),
        speed = MISSILE_SPEED,
        height = missileImage:getHeight() * 0.25,
        width = missileImage:getWidth() * 0.25
    }
    table.insert(rightMissiles, missile)
end

-- Randomly decides to create a missile either from the right or left.
function launch()
    if math.random(2) == 1 then
        createLeftMissile()
    else
        createRightMissile()
    end
end

-- Creates a coin in a random place.
function createCoin()
    local coin = {
        y = 30 + math.random(VIRTUAL_HEIGHT - 50),
        x = 20 + math.random(VIRTUAL_WIDTH - 40),
        height = frames[1]:getHeight(),
        width = frames[1]:getWidth()
    }
    table.insert(coins, coin)
end

-- Resets main variables (puts everything back in place, erases coins and missiles form screen and resets the score). Used between levels.
function reset()
    character.x = VIRTUAL_WIDTH / 2 - CHARACTER_WIDTH / 2
    character.y = VIRTUAL_HEIGHT - 10 - PLATFORM_HEIGHT - CHARACTER_HEIGHT - 80

    platform.x = VIRTUAL_WIDTH / 2 - PLATFORM_WIDTH / 2
    platform.y = VIRTUAL_HEIGHT - 10 - PLATFORM_HEIGHT

    leftMissiles = {}
    rightMissiles = {}
    coins = {}
    score = 0
end