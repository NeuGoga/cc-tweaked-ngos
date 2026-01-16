local w, h = term.getSize()
local nativeTerm = term.native() 

-- ==========================================
-- Global System Objects
-- ==========================================
_G.SystemMonitor = peripheral.find("monitor")
if _G.SystemMonitor then
    _G.SystemMonitor.setBackgroundColor(colors.black)
    _G.SystemMonitor.clear()
end

_G.ngos = {}
_G.ngos.version = "1.6.5"

local resources = { monitor = nil, speaker = nil }

function _G.ngos.claim(deviceType, processId)
    if resources[deviceType] == nil or resources[deviceType] == processId then
        resources[deviceType] = processId
        return peripheral.find(deviceType)
    end
    return nil
end

function _G.ngos.release(deviceType)
    resources[deviceType] = nil
end

-- ==========================================
-- Process Manager State
-- ==========================================
local desktopWindow = window.create(nativeTerm, 1, 1, w, h, true)
local desktopRoutine = nil

local processes = {} 
local pidCounter = 1
local activeProcess = nil 
local isTaskSwitcherOpen = false 

-- Toast
local toast = { text = nil, color = nil, expiry = 0 }
local wasToastActive = false

local function showToast(text, color)
    toast.text = text; toast.color = color; toast.expiry = os.clock() + 0.5 
end

local function getAppName(path)
    local parts = {}
    for part in string.gmatch(path, "[^/]+") do table.insert(parts, part) end
    if #parts >= 2 then return parts[#parts-1] end
    return fs.getName(path)
end

local function killProcess(proc)
    if resources.monitor == proc.pid then _G.ngos.release("monitor") end
    if resources.speaker == proc.pid then _G.ngos.release("speaker") end
    for i, p in ipairs(processes) do
        if p == proc then table.remove(processes, i); break end
    end
end

local function drawOverlay()
    local currentWindow = activeProcess and activeProcess.window or desktopWindow
    local _, _, bgLine = currentWindow.getLine(1)
    local bgAtMin = string.sub(bgLine, w-1, w-1)
    local bgAtClose = string.sub(bgLine, w, w)
    
    if not activeProcess and bgAtClose == "f" then bgAtClose = "8" end
    
    local lightColors = "012345689"
    local function getContrast(hex) return string.find(lightColors, hex) and "f" or "0" end
    
    local previous = term.redirect(nativeTerm)
    
    local isToastActive = (os.clock() < toast.expiry and toast.text)
    if wasToastActive and not isToastActive then
        currentWindow.redraw() 
    end
    wasToastActive = isToastActive
    
    if activeProcess then
        term.setCursorPos(w-1, 1); term.blit("_", getContrast(bgAtMin), bgAtMin)
        term.setCursorPos(w, 1); term.blit("X", getContrast(bgAtClose), bgAtClose)
    elseif #processes > 0 and not isTaskSwitcherOpen then
        term.setCursorPos(w, 1); term.blit("^", getContrast(bgAtClose), bgAtClose)
    end
    
    if isTaskSwitcherOpen and not activeProcess then
        local boxW = 22
        local boxH = #processes + 2
        local startX = math.floor((w - boxW) / 2)
        local startY = math.floor((h - boxH) / 2)
        
        paintutils.drawFilledBox(startX, startY, startX + boxW, startY + boxH, colors.black)
        
        term.setCursorPos(startX, startY)
        term.setBackgroundColor(colors.cyan)
        term.setTextColor(colors.black)
        local title = " Running Apps"
        term.write(title .. string.rep(" ", boxW - #title))
        
        term.setCursorPos(startX + boxW, startY)
        term.setBackgroundColor(colors.red)
        term.setTextColor(colors.white)
        term.write("X")
        
        for i, proc in ipairs(processes) do
            local lineY = startY + 1 + i
            term.setCursorPos(startX, lineY)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            
            term.write(string.rep(" ", boxW))
            
            term.setCursorPos(startX, lineY)
            term.write(" " .. getAppName(proc.path))
            
            term.setCursorPos(startX + boxW - 1, lineY)
            term.setTextColor(colors.orange)
            term.write("x")
        end
    end
    
    -- Draw Toast
    if isToastActive then
        local len = #toast.text + 2
        local x = math.floor((w - len) / 2)
        paintutils.drawFilledBox(x, h-2, x+len, h, toast.color)
        term.setTextColor(colors.white); term.setCursorPos(x+1, h-1); term.write(toast.text)
    end
    
    term.redirect(previous)
end

-- ==========================================
-- Process Loading Logic
-- ==========================================
local function loadDesktop()
    local path = "/ngos/bin/desktop.lua"
    if not fs.exists(path) then return nil end
    local fn, err = loadfile(path)
    if not fn then return nil end
    local env = setmetatable({ term = desktopWindow, shell = shell or _G.shell, os = os, _G = _G }, {__index = _G})
    setfenv(fn, env)
    return coroutine.create(fn)
end

local function launchApp(path)
    local appWin = window.create(nativeTerm, 1, 1, w, h, false)
    local fn, err = loadfile(path)
    if not fn then return nil, err end
    
    local myPid = pidCounter; pidCounter = pidCounter + 1
    local systemShell = shell or _G.shell

    local env = {
        term = appWin, shell = systemShell, multishell = multishell or _G.multishell,
        os = os, _G = _G, package = package, require = require,
        fs = fs, io = io, http = http, textutils = textutils, table = table,
        string = string, math = math, peripheral = peripheral, colors = colors,
        ngos = { version = _G.ngos.version, claim = function(dt) return _G.ngos.claim(dt, myPid) end, release = _G.ngos.release }
    }
    setmetatable(env, {__index = _G})
    setfenv(fn, env)
    
    local proc = { pid = myPid, routine = coroutine.create(fn), window = appWin, path = path }
    table.insert(processes, proc)
    return proc
end

desktopRoutine = loadDesktop()
if desktopRoutine then
    term.redirect(desktopWindow); coroutine.resume(desktopRoutine)
    desktopWindow.setVisible(true); desktopWindow.redraw()
end

-- ==========================================
-- MAIN MULTITASKING LOOP
-- ==========================================
while true do
    local eventData = { os.pullEventRaw() }
    local event = eventData[1]
    local isInput = (event:sub(1,5) == "mouse") or (event:sub(1,3) == "key") or (event == "char") or (event == "paste")
    local handled = false

    if event == "mouse_click" then
        local btn, x, y = eventData[2], eventData[3], eventData[4]
        
        if isTaskSwitcherOpen then
            local boxW = 22
            local boxH = #processes + 2
            local startX = math.floor((w - boxW) / 2)
            local startY = math.floor((h - boxH) / 2)
            
            if x >= startX and x <= startX + boxW and y >= startY and y <= startY + boxH then
                -- CLOSE MENU [X]
                if y == startY and x >= startX + boxW - 1 then
                    isTaskSwitcherOpen = false
                    desktopWindow.redraw()
                else
                    -- LIST ITEMS
                    local row = y - (startY + 1)
                    if row > 0 and row <= #processes then
                        local proc = processes[row]
                        -- KILL APP [x]
                        if x >= startX + boxW - 1 then
                            killProcess(proc)
                            if #processes == 0 then isTaskSwitcherOpen = false end
                            term.native().setBackgroundColor(colors.black); term.native().clear()
                            desktopWindow.setVisible(true); desktopWindow.redraw()
                            term.redirect(desktopWindow); coroutine.resume(desktopRoutine, "refresh")
                        else 
                            -- RESUME APP
                            isTaskSwitcherOpen = false
                            activeProcess = proc
                            desktopWindow.setVisible(false)
                            nativeTerm.setBackgroundColor(colors.black); nativeTerm.clear()
                            activeProcess.window.setVisible(true); activeProcess.window.redraw()
                        end
                    end
                end
            else isTaskSwitcherOpen = false; desktopWindow.redraw() end
            handled = true
            
        elseif y == 1 then
            if x == w and activeProcess then -- CLOSE
                showToast("Closing...", colors.red)
                os.queueEvent("terminate_app")
                local t = os.startTimer(0.2)
                while true do
                    local eData = { os.pullEventRaw() }
                    if eData[1] == "timer" and eData[2] == t then break end
                    local isInputE = (eData[1]:sub(1,5) == "mouse") or (eData[1]:sub(1,3) == "key")
                    for i = #processes, 1, -1 do
                        local proc = processes[i]
                        if not isInputE or proc == activeProcess then
                            term.redirect(proc.window)
                            coroutine.resume(proc.routine, table.unpack(eData))
                        end
                    end
                end
                killProcess(activeProcess)
                activeProcess = nil
                nativeTerm.setBackgroundColor(colors.black); nativeTerm.clear()
                desktopWindow.setVisible(true); desktopWindow.redraw()
                term.redirect(desktopWindow); coroutine.resume(desktopRoutine, "refresh")
                handled = true
                
            elseif x == w-1 and activeProcess then -- MINIMIZE
                showToast("Minimizing...", colors.blue)
                activeProcess.window.setVisible(false)
                activeProcess = nil
                nativeTerm.setBackgroundColor(colors.black); nativeTerm.clear()
                desktopWindow.setVisible(true); desktopWindow.redraw()
                term.redirect(desktopWindow); coroutine.resume(desktopRoutine, "refresh")
                handled = true
                
            elseif x == w and not activeProcess and #processes > 0 then -- RESUME
                isTaskSwitcherOpen = true
                handled = true
            end
        end
    elseif event == "ngos_launch" then
        isTaskSwitcherOpen = false
        local proc = launchApp(eventData[2])
        if proc then
            if activeProcess then activeProcess.window.setVisible(false) end
            desktopWindow.setVisible(false)
            activeProcess = proc
            nativeTerm.setBackgroundColor(colors.black); nativeTerm.clear()
            activeProcess.window.setVisible(true)
            term.redirect(activeProcess.window); coroutine.resume(activeProcess.routine); activeProcess.window.redraw()
        else
            showToast("Load Error", colors.red)
        end
        handled = true
    end

    if not handled then
        for i = #processes, 1, -1 do
            local proc = processes[i]
            local isActive = (proc == activeProcess)
            local blockInput = not isActive or isTaskSwitcherOpen
            if not isInput or not blockInput then
                term.redirect(proc.window)
                local ok, err = coroutine.resume(proc.routine, table.unpack(eventData))
                if not ok or coroutine.status(proc.routine) == "dead" then
                    if not ok then
                        term.redirect(nativeTerm)
                        term.setBackgroundColor(colors.blue); term.clear(); term.setCursorPos(1,1)
                        print("App Crashed: " .. tostring(err)); print("Press Enter."); read()
                    end
                    killProcess(proc)
                    if isActive then
                        activeProcess = nil
                        nativeTerm.setBackgroundColor(colors.black); nativeTerm.clear()
                        desktopWindow.setVisible(true); desktopWindow.redraw()
                        term.redirect(desktopWindow); coroutine.resume(desktopRoutine, "refresh")
                    end
                end
            end
        end
        if not activeProcess then
            term.redirect(desktopWindow)
            coroutine.resume(desktopRoutine, table.unpack(eventData))
        end
        drawOverlay()
    end
end