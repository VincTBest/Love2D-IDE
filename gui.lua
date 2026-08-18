-- loveYourGUI - Love2D GUI Library

-- Settings
local debugMode = false
local version = "0.0.2"

-- Fonts
fonts = {}

function loadFont(name, path, sizes)
    sizes = sizes or {4, 8, 12, 14, 16, 18, 20, 24, 28, 32, 36, 40, 44, 50, 54, 64}
    fonts[name] = {}
    for i=1,#sizes do
        local size = sizes[i]
        local font = love.graphics.newFont(path, size)
        fonts[name][tostring(size)] = font
    end
end

function getText(font, size, text)
    local font = fonts[font][tostring(size)]
    local drawable = love.graphics.newText(font, text)
    return drawable
end

function drawText(font, size, text, x, y)
    local drawable
    if font and not x and not y then -- drawText(drawable, x, y)
        drawable = font
        x = size
        y = text
    else
        drawable = getText(font, size, text)
    end
    love.graphics.draw(drawable, x, y)
end

-- UUID
local random = math.random
local function gen_uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Helpers
local dummyRoot

local function getDummyRoot()
    if not dummyRoot then
        dummyRoot = create_widget(0, 0, 0, 0, false, function(widget)
            widget.extra.root = false
            widget.doInGlobal.draw = false
            widget.visible = false
            widget.remove = function() end
            widget.radius = nil
            widget.margin = nil

            function widget.update()
                local w, h = love.window.getMode()
                widget.size.x = w
                widget.size.y = h
            end
        end,
        function (widget)
            widget.extra.root = false
            return widget
        end)
    end

    return dummyRoot
end

function setColFT(table)
    love.graphics.setColor(table[1], table[2], table[3], table[4] or 1)
end

function findCenter(x, y, w1, h1, w2, h2)
    local nX = math.floor(x + (w1 - w2) / 2)
    local nY = math.floor(y + (h1 - h2) / 2)
    
    return nX, nY
end

local tick = 0

function clamp(x, min, max)
    return math.min(math.max(x, min), max)
end

function pointInRect(px, py, rx, ry, width, height)
    return px >= rx and px <= rx + width and py >= ry and py <= ry + height
end

function cToHover(n, m)
    local m = m or 60
    m = m/50

    local str = string.format("%.3f", n)
    local decimals = str:match("%.(%d+)")
    
    local d1 = tonumber(decimals:sub(1,1))
    local d2 = tonumber(decimals:sub(2,2))
    local d3 = tonumber(decimals:sub(3,3))
    
    local digitSum = d1 + d2 + d3
    
    local addedValue = (2 * digitSum * m) - 6
    
    local baseInt = tonumber(decimals)
    local resultInt = baseInt + addedValue
    
    return resultInt / 1000
end

function cFTtoHover(t, m)
    local n1 = cToHover(t[1], m)
    local n2 = cToHover(t[2], m)
    local n3 = cToHover(t[3], m)

    return {n1, n2, n3, t[4]}
end

function nilFunc() end

-- Widgets
local selected = nil
local widgets = {}

function create_widget(x, y, xSize, ySize, addToGlobal, init, eInit)
    local widget = {
        pos = {
            x = x or 0, y = y or 0, -- X/Y Position
            anchor = nil -- Anchor
        },
        size = {
            x = xSize or 1, y = ySize or 1, -- X/Y Size
            expand = {} -- Expand dimensions.
        },
        children = {}, -- Children
        parent = nil,  -- The parent (Window if this is a root widget)
        uuid = gen_uuid(), -- Unique Identifier
        doInGlobal = {
            draw = true, -- If false, then widget.do_draw will not be called in draw_widgets.
            update = true, -- If false, then widget.do_update will not be called in update_widgets.
            perfectCornerRadius = true, -- If true, then the widget will update it's corner radius (widget.radius) to widget.parent.radius - widget.margin on every 10th frame.
            mousePress = true, -- Will not run widget.mousePressed if false.
            mouseRelease = true, -- Will not run widget.mouseReleased if false.
        },
        extra = {
            root = true -- When true, widget.parent will be set to getDummyRoot().
        },
        visible = true, -- If false, then widget.draw will not be called in widget.do_draw.
        enabled = true -- If false, then widget.update will not be called in widget.do_update.
    }

    if eInit then
        widget = eInit(widget) -- Early init. Used in getDummyRoot().
    end

    if widget.extra.root then
        widget.parent = getDummyRoot()
    end

    -- For the programmer to override.
    function widget.cleanup() end
    function widget.update() end
    function widget.update30() end -- 30fps update ( tick % 30 == 0 or tick == 0 )
    function widget.update10() end -- 10fps update ( tick % 10 == 0 or tick == 0 )
    function widget.mousePressed(_x, _y, _button) end
    function widget.mouseReleased(_x, _y, _button) end
    function widget.draw() end

    -- Regular functions.
    function widget.add(c_x, c_y, c_xSize, c_ySize, c_init)
        local child

        if c_x and not c_y then
            child = c_x
            widgets[child.uuid] = nil
        else
            child = create_widget(
                c_x, c_y,
                c_xSize, c_ySize,
                false,
                c_init
            )
        end

        child.extra.root = false
        child.parent = widget

        table.insert(widget.children, child)

        return child
    end

    function widget.remove(skipChildren)
        widget.cleanup()

        if not skipChildren then
            for i = #widget.children, 1, -1 do
                widget.children[i].remove()
            end
        end

        if widget.parent then
            for i = #widget.parent.children, 1, -1 do
                if widget.parent.children[i] == widget then
                    table.remove(widget.parent.children, i)
                    break
                end
            end
        else
            widgets[widget.uuid] = nil
        end
    end

    function widget.setAnchor(a_x, a_y)
        -- X and Y are both integers from -1 to 1. (-1/0/1)
        -- For X -1 is left, 0 is center and 1 is right.
        -- For Y -1 is top, 0 is middle and 1 is bottom.

        widget.pos.anchor = {
            x = a_x,
            y = a_y
        }

        if a_x == nil and a_y == nil then
            widget.pos.anchor = nil -- Set to nil when anchor is not set.
        end
    end

    function widget.setExpand(expansions)
        -- Expansions is a table of tables that are 2 numbers.
        -- For example: { {-1, -1}, {-1, 0}, {-1, 1} }.
        -- The numbers are the exact same as the numbers that are given to anchors.
        -- The example above would make the widget stick to the top-left, middle-left and bottom-left.
        -- That means that every frame, it will be resized so that the anchor points meet with the edges of the window.

        widget.size.expand = expansions
    end

    function widget.getPos()
        if widget.parent then
            local px, py = widget.parent.getPos()
            return px + widget.pos.x, py + widget.pos.y
        end

        return widget.pos.x, widget.pos.y
    end

    function widget.getContentPos()
        local x, y = widget.getPos()

        local current = widget

        while current do
            local margin = current.margin or 0

            x = x + margin
            y = y + margin

            current = current.parent
        end

        return x, y
    end

    function widget.getSize()
        local w, h = widget.size.x, widget.size.y
        return w, h
    end

    function widget.getContentSize()
        local w, h = widget.getSize()
        local margin = ((widget.margin or 0) * 2)
        return w - margin, h - margin
    end

    function widget.configure(table)
        local newWidget = table
        for k, v in pairs(widget) do
            if not newWidget[k] then
                newWidget[k] = v -- Keeps old unchanged values
            end
        end
        widget = newWidget
    end

    function widget.selectMe()
        selected = widget.uuid
    end

    function widget.unselectMe()
        selected = nil
    end

    function widget.isSelected()
        if not selected then return false end
        return selected == widget.uuid
    end

    -- Do not call.
    function widget.do_draw()
        if widget.visible then
            if type(widget.draw) == "function" then
                widget.draw()
            end
            for i=1,#widget.children do
                local child = widget.children[i]
                if child.doInGlobal.draw then
                    child.do_draw()
                end
            end
        end
    end

    function widget.do_update()
        if widget.enabled then
            if type(widget.update) == "function" then
                widget.update()
            end
            
            if tick % 30 == 0 or tick == 0 and type(widget.update30) == "function" then
                widget.update30()
            end
            if tick % 10 == 0 or tick == 0 and type(widget.update10) == "function" then
                widget.update10()
                if widget.doInGlobal.perfectCornerRadius then
                    widget.do_perfectCornerRadius()
                end
            end

            widget.do_anchorAdjust()
            for i=1,#widget.children do
                local child = widget.children[i]
                if child.doInGlobal.update then
                    child.do_update()
                end
            end
        end
    end

    function widget.do_anchorAdjust()
        local minX, minY = 0, 0
        local maxX, maxY = love.window.getMode()

        if widget.parent then
            minX, minY = widget.parent.getContentPos()
            local parentW, parentH = widget.parent.getContentSize()

            maxX = minX + parentW
            maxY = minY + parentH
        end

        -- Anchor
        local anchor = widget.pos.anchor

        if anchor then
            if anchor.x == -1 then
                widget.pos.x = 0
            elseif anchor.x == 0 then
                widget.pos.x = (maxX - minX) / 2 - widget.size.x / 2
            elseif anchor.x == 1 then
                widget.pos.x = (maxX - minX) - widget.size.x
            end

            if anchor.y == -1 then
                widget.pos.y = 0
            elseif anchor.y == 0 then
                widget.pos.y = (maxY - minY) / 2 - widget.size.y / 2
            elseif anchor.y == 1 then
                widget.pos.y = (maxY - minY) - widget.size.y
            end
        end

        -- Expand
        local expansions = widget.size.expand

        if expansions and #expansions > 0 then
            local left, right, top, bottom = nil, nil, nil, nil

            for i = 1, #expansions do
                local n = expansions[i]

                if #n == 2 then
                    local expX, expY = n[1], n[2]

                    if expX == -1 then left = 0 end
                    if expX == 1 then right = maxX - minX end
                    if expY == -1 then top = 0 end
                    if expY == 1 then bottom = maxY - minY end
                else
                    error("The number of positions on the expand of a widget are not 2!")
                end
            end

            if left and right then
                widget.pos.x = left
                widget.size.x = right - left
            elseif left then
                widget.pos.x = left
            elseif right then
                widget.pos.x = right - widget.size.x
            end

            if top and bottom then
                widget.pos.y = top
                widget.size.y = bottom - top
            elseif top then
                widget.pos.y = top
            elseif bottom then
                widget.pos.y = bottom - widget.size.y
            end
        end
    end

    function widget.do_perfectCornerRadius()
        local w, h = widget.getContentSize()
        if widget.parent and widget.parent.radius and widget.parent.margin then
            local newRad = clamp(widget.parent.radius - widget.margin, 0, math.min(h/2, w/2)) -- Perfect corner radius
            if newRad == widget.radius then
                widget.parent.radius = newRad + widget.margin
            end
            widget.radius = newRad
        end
    end

    function widget.do_mousePressed(x, y, button)
        if not widget.enabled or not widget.visible then
            return false
        end

        -- Check children first so they get priority over their parent.
        for i = #widget.children, 1, -1 do
            local child = widget.children[i]

            if child.doInGlobal.mousePress then
                if child.do_mousePressed(x, y, button) then
                    return true
                end
            end
        end

        local wx, wy = widget.getContentPos()
        local ww, wh = widget.getContentSize()

        if pointInRect(x, y, wx, wy, ww, wh) then
            widget.mousePressed(x, y, button)
            return true
        end

        return false
    end

    function widget.do_mouseReleased(x, y, button)
        if not widget.enabled or not widget.visible then
            return false
        end

        -- Children first.
        for i = #widget.children, 1, -1 do
            local child = widget.children[i]

            if child.doInGlobal.mouseRelease then
                if child.do_mouseReleased(x, y, button) then
                    return true
                end
            end
        end

        local wx, wy = widget.getContentPos()
        local ww, wh = widget.getContentSize()

        if pointInRect(x, y, wx, wy, ww, wh) then
            widget.mouseReleased(x, y, button)
            return true
        end

        return false
    end

    if addToGlobal == nil then
        addToGlobal = true
    end
    if addToGlobal then
        widgets[widget.uuid] = widget
    end

    -- Do initialization last.
    if init then
        widget = init(widget)
    end
    return widget
end

-- Global update/draw

function draw_widgets()
    for _, widget in pairs(widgets) do
        if widget.doInGlobal.draw then
            widget.do_draw()
        end
    end
end

function update_widgets()
    for _, widget in pairs(widgets) do
        if widget.doInGlobal.update then
            widget.do_update()
        end
    end
end

function draw_gui()
    draw_widgets()
    if debugMode then
        local c = 0.7
        love.graphics.setColor(c, c, c, .85)

        local debugTitle = love.graphics.newText(fonts.default["18"], "loveYourGUI")
        love.graphics.draw(debugTitle, 8, 8)

        local debugText = love.graphics.newText(fonts.default["14"], "Version "..version.."\nBy VincTBest")
        love.graphics.draw(debugText, 8, 8+22)
    end
end

function update_gui()
    update_widgets()
    tick = tick + 1
end

function keypressed_gui( key, scancode, isrepeat )
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
    elseif key == "f12" then
        debugMode = not debugMode
    end
end

function resize_gui(w, h)
    windowW = w
    windowH = h

    if dummyRoot then
        dummyRoot.size.x = w
        dummyRoot.size.y = h
    end

    update_gui()
end

function mousepressed_gui( x, y, button, istouch, presses )
    for _, widget in pairs(widgets) do
        if widget.enabled and widget.doInGlobal.mousePress then
            local wx, wy = widget.getContentPos()
            local ww, wh = widget.getContentSize()
            if pointInRect(x, y, wx, wy, ww, wh) then
                widget.do_mousePressed(x, y, button)
            end
        end
    end
end

function mousereleased_gui( x, y, button, istouch, presses )
    for _, widget in pairs(widgets) do
        if widget.enabled and widget.doInGlobal.mouseRelease then
            local wx, wy = widget.getContentPos()
            local ww, wh = widget.getContentSize()
            if pointInRect(x, y, wx, wy, ww, wh) then
                widget.do_mouseReleased(x, y, button)
            end
        end
    end
end

loadFont("default", "gui/fonts/default/BricolageGrotesque.ttf")

-- Panel

function create_panel(x, y, w, h, init)
    return create_widget(x, y, w, h, true, function(widget)
        widget.margin = 12
        widget.radius = 8

        local c = .9
        widget.color = {c, c, c, 1}

        function widget.draw()
            local x, y = widget.getContentPos()
            local w, h = widget.getContentSize()

            setColFT(widget.color)
            love.graphics.rectangle("fill", x, y, w, h, widget.radius)

            love.graphics.rectangle("line", x, y, w, h, widget.radius)
        end
        
        function widget.mousePressed(_x, _y, _button)
            widget.selectMe()
        end

        if init then
            widget = init(widget)
        end
        return widget
    end)
end

function create_button(x, y, w, h, text, onPressed, onReleased, init)
    return create_widget(x, y, w, h, true, function(widget)
        widget.margin = 4
        widget.radius = 8

        widget.custom_onPressed = onPressed or function () end
        widget.custom_onReleased = onReleased or function () end

        widget.label = {
            color = {.96, .96, .96, 1},
            text = text or "Hello, world!",
        }

        widget.mouseDown = false

        widget.colorIndex = 1

        local cPrimaryDefault = {0.235, 0.416, 0.78, 1}
        local cPrimaryHover = cFTtoHover(cPrimaryDefault)

        widget.colors = {
            cPrimaryDefault,
            cPrimaryHover
        }

        local cBorderDefault = {0.161, 0.329, 0.761, 1}
        local cBorderHover = cFTtoHover(cBorderDefault)

        widget.border = true
        widget.bColors = {
            cBorderDefault,
            cBorderHover
        }

        function widget.draw()
            local x, y = widget.getContentPos()
            local w, h = widget.getContentSize()

            setColFT(widget.colors[widget.colorIndex])
            love.graphics.rectangle("fill", x, y, w, h, widget.radius)
            
            if widget.border then
                setColFT(widget.bColors[widget.colorIndex])
            end
            love.graphics.rectangle("line", x, y, w, h, widget.radius) -- Smooth edges

            setColFT(widget.label.color)
            local text = getText("default", 20, widget.label.text)
            local tW, tH = text:getDimensions()
            local textX, textY = findCenter(x, y, w, h, tW, tH)
            drawText(text, textX, textY)
        end

        function widget.update()
            widget.mouseDown = love.mouse.isDown(1)

            local mx, my = love.mouse.getPosition()
            local x, y = widget.getContentPos()
            local w, h = widget.getContentSize()
            widget.mouseHover = pointInRect(mx, my, x, y, w, h)

            if widget.mouseHover then
                widget.colorIndex = 2
            else
                widget.colorIndex = 1
            end
        end

        function widget.mousePressed(_x, _y, _button)
            widget.selectMe()
        end

        function widget.mouseReleased(_x, _y, _button)
        end

        if init then
            widget = init(widget)
        end

        return widget
    end)
end

function create_textarea(x, y, w, h)
    return create_panel(x, y, w, h, function (widget)
        widget.margin = 4
        widget.padding = 4
        widget.color = {0.31, 0.31, 0.36, 1}

        widget.label = {
            color = {.96, .96, .96, 1},
            text = {
                "This is line 1!",
                "This is line 2!",
                "This is line 3!",
                "This is line 4!",
                "This is line 5!",
                "This is line 6!",
                "This is line 7!",
                "This is line 8!",
                "This is line 9!",
                "This is line 10!"
            }, -- Lines
            textWhole = nil
        }

        function widget.mergeLines()
            local whole = ""
            for i=1,#widget.label.text do
                whole = whole..widget.label.text[i].."\n"
            end

            widget.label.textWhole = whole
        end
        
        function widget.draw()
            local x, y = widget.getContentPos()
            local w, h = widget.getContentSize()

            setColFT(widget.color)
            love.graphics.rectangle("fill", x, y, w, h, widget.radius)

            love.graphics.rectangle("line", x, y, w, h, widget.radius)

            setColFT(widget.label.color)
            local text = getText("default", 18, widget.label.textWhole)

            drawText(text, x+widget.padding, y+widget.padding)
        end

        function widget.update()
            widget.mergeLines()
        end

        function widget.mousePressed(_x, _y, _button)
            widget.selectMe()
        end

        return widget
    end)
end