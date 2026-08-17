-- Love2D IDE
require("gui")

local windowW = 800
local windowH = 600

local testPanel = create_panel(0, 0, windowW, windowH)
testPanel.setAnchor(0, 0)
testPanel.setExpand({ {-1, -1}, {1, 1} })

local testButton = testPanel.add(create_button(16, 16, 196, 48, "Press the arrows"))
testButton.setAnchor(-1, -1)

function love.load()
    love.window.setTitle("LoveIDE")
    love.window.setMode(windowW, windowH, {
        resizable = true
    })
end

function love.keypressed(key, scancode, isrepeat)
    if key == "left" then
        testPanel.radius = testPanel.radius - 1
    end
    if key == "right" then
        testPanel.radius = testPanel.radius + 1
    end
    testButton.label.text = "Radius: "..testPanel.radius
end

function love.draw()
    draw_gui()
end

function love.update()
    update_gui()
end
