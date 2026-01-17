local w, h = term.getSize()
local selectedAppIndex = 0

-- Scan for Apps
local function getApps()
    local apps = {}
    if not fs.exists("/apps") then fs.makeDir("/apps") end
    local files = fs.list("/apps")
    for _, file in ipairs(files) do
        if fs.isDir(fs.combine("/apps", file)) then
            table.insert(apps, {
                name = file,
                path = "/apps/" .. file .. "/app.lua"
            })
        end
    end
    return apps
end

local function drawIcon(x, y, label, isSelected)
    local T = ngos.theme
    
    if isSelected then
        paintutils.drawFilledBox(x, y, x+6, y+3, T.header)
    else
        paintutils.drawFilledBox(x, y, x+6, y+3, T.accent)
    end
    
    -- Draw Initial
    term.setTextColor(T.headerText)
    term.setCursorPos(x+3, y+1)
    term.write(string.sub(label, 1, 1):upper())
    
    -- Draw Label below
    term.setBackgroundColor(T.bg)
    term.setTextColor(T.text)
    term.setCursorPos(x, y+4)
    local shortName = string.sub(label, 1, 7)
    term.write(shortName)
end

local function drawDesktop(appList)
    local T = ngos.theme
    local BG_COLOR = T.bg
    local BAR_COLOR = T.header
    local TEXT_COLOR = T.headerText

    term.setBackgroundColor(BG_COLOR)
    term.clear()
    
    term.setBackgroundColor(BAR_COLOR)
    term.setCursorPos(1,1)
    term.clearLine()
    
    term.setTextColor(TEXT_COLOR)
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
local clockTimer = os.startTimer(2)

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
        clockTimer = os.startTimer(2)
    end
end