local w, h = term.getSize()
local selectedAppIndex = 0

-- Colors
local BG_COLOR = colors.gray
local BAR_COLOR = colors.lightGray
local ICON_COLOR = colors.blue
local TEXT_COLOR = colors.white

-- Scan for Apps
local function getApps()
    local apps = {}
    
    -- Check if /apps exists
    if not fs.exists("/apps") then fs.makeDir("/apps") end
    
    local files = fs.list("/apps")
    for _, file in ipairs(files) do
        if fs.isDir(fs.combine("/apps", file)) then
            table.insert(apps, {
                name = file,
                path = "/apps/" .. file .. "/app.lua" -- Standard entry point
            })
        end
    end
    return apps
end

-- Draw the Interface
local function drawIcon(x, y, label, isSelected)
    if isSelected then
        paintutils.drawFilledBox(x, y, x+6, y+3, colors.cyan)
    else
        paintutils.drawFilledBox(x, y, x+6, y+3, ICON_COLOR)
    end
    
    -- Draw Initial
    term.setTextColor(colors.white)
    term.setCursorPos(x+3, y+1)
    term.write(string.sub(label, 1, 1):upper())
    
    -- Draw Label below
    term.setBackgroundColor(BG_COLOR)
    term.setCursorPos(x, y+4)
    local shortName = string.sub(label, 1, 7)
    term.write(shortName)
end

local function drawDesktop(appList)
    term.setBackgroundColor(BG_COLOR)
    term.clear()
    
    term.setBackgroundColor(BAR_COLOR)
    term.setCursorPos(1,1)
    term.clearLine()
    
    term.setBackgroundColor(BAR_COLOR)
    term.setTextColor(colors.black)
    term.setCursorPos(1, 1) 
    term.write("NgOS")
    
    local timeStr = textutils.formatTime(os.time("local"), true)
    term.setCursorPos(w - #timeStr, 1)
    term.write(timeStr)
    
    -- Draw Apps Grid
    local startX, startY = 3, 4
    local paddingX, paddingY = 10, 6
    
    for i, app in ipairs(appList) do
        local col = (i - 1) % 3 
        local row = math.floor((i - 1) / 3)
        local x = startX + (col * paddingX)
        local y = startY + (row * paddingY)
        
        app.x, app.y = x, y
        drawIcon(x, y, app.name, (i == selectedAppIndex))
    end
end

-- Main Loop
local appList = getApps()
local clockTimer = os.startTimer(10)

while true do
    drawDesktop(appList)
    
    local event, p1, p2, p3 = os.pullEvent()
    
    if event == "mouse_click" then
        local btn, clickX, clickY = p1, p2, p3
        
        for i, app in ipairs(appList) do
            if clickX >= app.x and clickX <= app.x + 6 and
               clickY >= app.y and clickY <= app.y + 4 then
               
               selectedAppIndex = i
               drawDesktop(appList)
               sleep(0.1)
               selectedAppIndex = 0
               
               if fs.exists(app.path) then
                   os.queueEvent("ngos_launch", app.path)
               else
                   term.setCursorPos(2, h)
                   term.setBackgroundColor(colors.red)
                   term.write("Missing app.lua!")
                   sleep(1)
               end
            end
        end
        
    elseif event == "timer" and p1 == clockTimer then
        clockTimer = os.startTimer(10)
    end
end