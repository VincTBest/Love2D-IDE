-- Love2D IDE
require("gui")

local windowW = 800
local windowH = 600

local testPanel = create_panel(0, 0, windowW, windowH)
testPanel.setAnchor(0, 0)
testPanel.setExpand({ {-1, -1}, {1, 1} })

function love.load()
    love.window.setTitle("LoveIDE")
    love.window.setMode(windowW, windowH, {
        resizable = true
    })
end

function love.draw()
    draw_gui()
end

function love.update()
    update_gui()
end
