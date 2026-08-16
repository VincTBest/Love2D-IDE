-- Love2D GUI Library

-- Settings
local debugMode = false
local version = "0.0.1"

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

-- UUID
local random = math.random
local function gen_uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Helper
local function getDummyRoot()
    return create_widget(
        0, 0, 0, 0, true, function(widget)
            widget.doInGlobal.draw = false
            widget.visible = false
            widget.remove = function () end -- Make this widget unremovable

            widget.update = function ()
                local w, h = love.window.getMode()
                widget.size.x = w
                widget.size.y = h
                widget.children = {}
            end
            return widget
        end,
        function (widget)
            widget.extra.root = false
            return widget
        end
    )
end

-- Widgets
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
            update = true -- If false, then widget.do_update will not be called in update_widgets.
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
    function widget.draw() end

    -- Regular functions.
    function widget.add(c_x, c_y, c_xSize, c_ySize, c_init)
        local child = create_widget(c_x, c_y, c_xSize, c_ySize, false, c_init)
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

    -- Do not call.
    function widget.do_draw()
        if widget.visible then
            widget.draw()
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
            widget.update()
            for i=1,#widget.children do
                local child = widget.children[i]
                if child.doInGlobal.update then
                    child.do_update()
                end
            end
        end
        widget.do_anchorAdjust()
    end

    function widget.do_anchorAdjust()
        -- Fallback to window dimensions if the widget somehow has no parent
        local minX, minY = 0, 0
        local maxX, maxY = love.window.getMode()
        
        if widget.parent then
            minX, minY = widget.parent.pos.x, widget.parent.pos.y
            maxX, maxY = minX + widget.parent.size.x, minY + widget.parent.size.y
        end

        -- Anchor
        local anchor = widget.pos.anchor
        if anchor then
            -- X
            if anchor.x == -1 then
                widget.pos.x = minX
            elseif anchor.x == 0 then
                widget.pos.x = minX + (maxX - minX) / 2 - widget.size.x / 2
            elseif anchor.x == 1 then
                widget.pos.x = maxX - widget.size.x
            end

            -- Y
            if anchor.y == -1 then
                widget.pos.y = minY
            elseif anchor.y == 0 then
                widget.pos.y = minY + (maxY - minY) / 2 - widget.size.y / 2
            elseif anchor.y == 1 then
                widget.pos.y = maxY - widget.size.y
            end
        end

        -- Expand
        local expansions = widget.size.expand
        if expansions and #expansions > 0 then
            local left, right, top, bottom = nil, nil, nil, nil

            -- Identify which edges the widget needs to stretch to
            for i = 1, #expansions do
                local n = expansions[i]
                if #n == 2 then
                    local expX, expY = n[1], n[2]
                    if expX == -1 then left = minX end
                    if expX == 1 then right = maxX end
                    if expY == -1 then top = minY end
                    if expY == 1 then bottom = maxY end
                else
                    error("The number of positions on the expand of a widget are not 2!")
                end
            end

            -- Recalculate dimensions and positions based on pinned edges
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
end

function love.keypressed( key, scancode, isrepeat )
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
    elseif key == "f12" then
        debugMode = not debugMode
    end
end

loadFont("default", "gui/fonts/default/BricolageGrotesque.ttf")

-- Panel

function create_panel(x, y, w, h)
    return create_widget(x, y, w, h, true, function(widget)
        widget.margin = 14
        widget.radius = 6

        local c = .9
        widget.color = {c, c, c, 1}

        function widget.draw()
            love.graphics.setColor(widget.color[1], widget.color[2], widget.color[3], widget.color[4])
            local x1, y1 = widget.pos.x + widget.margin, widget.pos.y + widget.margin
            local x2, y2 = widget.size.x - widget.margin * 2, widget.size.y - widget.margin * 2
            love.graphics.rectangle("fill", x1, y1, x2, y2, widget.radius)
            love.graphics.rectangle("line", x1, y1, x2, y2, widget.radius)
        end

        return widget
    end)
end