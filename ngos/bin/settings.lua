local w, h = term.getSize()
local security = require("ngos.system.security")

sleep(0.1)

local themeNames = { "standard", "hacker", "ocean", "retro", "dark" }
local themeIndex = 1

local currentBg = ngos.theme.bg
local currentAccent = ngos.theme.accent

for i, name in ipairs(themeNames) do
    local preset = ngos.themeLib.getPreset(name)
    if preset.bg == currentBg and preset.accent == currentAccent then
        themeIndex = i
        break
    end
end

local function drawMenu()
    local T = ngos.theme
    
    term.setBackgroundColor(colors.black)
    term.clear()
    
    term.setCursorPos(1,1); term.setTextColor(T.accent); term.write("System Settings")
    term.setCursorPos(1,2); term.setTextColor(colors.gray); term.write(string.rep("-", w))

    local startY = 4
    
    term.setCursorPos(2, startY)
    term.setTextColor(colors.gray); term.write("[ ")
    term.setTextColor(colors.white); term.write("Check for Updates")
    term.setTextColor(colors.gray); term.write(" ]")
    
    local isSecured = security.isEnabled()
    term.setCursorPos(2, startY + 2)
    term.setTextColor(colors.gray); term.write("[ ")
    term.setTextColor(colors.white); term.write("Protected Boot: ")
    term.setTextColor(isSecured and T.accent or T.err); term.write(isSecured and "ON " or "OFF")
    term.setTextColor(colors.gray); term.write(" ]")
    
    term.setCursorPos(2, startY + 4)
    term.setTextColor(colors.gray); term.write("[ ")
    term.setTextColor(colors.white); term.write("Theme: ")
    term.setTextColor(T.accent); term.write(themeNames[themeIndex]:upper())
    term.setTextColor(colors.gray); term.write(" ]")
    
    term.setCursorPos(2, startY + 6)
    term.setTextColor(colors.gray); term.write("[ ")
    term.setTextColor(T.warn); term.write("Reboot System")
    term.setTextColor(colors.gray); term.write(" ]")

    term.setCursorPos(2, h-1); term.setTextColor(colors.gray); term.write("NgOS v" .. ngos.version)
end

local function toggleTheme()
    themeIndex = themeIndex + 1
    if themeIndex > #themeNames then themeIndex = 1 end
    
    local newName = themeNames[themeIndex]
    local newColors = ngos.themeLib.getPreset(newName)
    
    ngos.themeLib.save(newColors)
    
    drawMenu()
end

while true do
    drawMenu()
    local event, btn, x, y = os.pullEvent("mouse_click")
    
    if y == 4 then
        dofile("/ngos/bin/updater.lua")
    elseif y == 6 then
        if security.isEnabled() then security.disableProtection() else security.enableProtection() end
    elseif y == 8 then
        toggleTheme()
        sleep(0.25)
        os.queueEvent("clear_queue")
        os.pullEvent("clear_queue")
        
    elseif y == 10 then
        os.reboot()
    end
end