local w, h = term.getSize()

local UPDATE_URL = "https://raw.githubusercontent.com/NeuGoga/ngos-repo/main/os_manifest.json"

local C_BG = colors.black
local C_TITLE = colors.cyan
local C_TEXT = colors.white
local C_BTN_TEXT = colors.lime
local C_BTN_ACCENT = colors.gray
local C_WARN = colors.orange

local function drawMenu()
    term.setBackgroundColor(C_BG)
    term.clear()
    
    term.setCursorPos(1,1)
    term.setTextColor(C_TITLE)
    term.write("System Settings")
    term.setCursorPos(1,2)
    term.setTextColor(C_BTN_ACCENT)
    term.write(string.rep("-", w))

    term.setCursorPos(w - 1, 1)
    term.setTextColor(C_TEXT)
    term.write("_X")

    local startY = 4
    
    term.setCursorPos(2, startY)
    term.setTextColor(C_BTN_ACCENT)
    term.write("[ ")
    term.setTextColor(C_BTN_TEXT)
    term.write("Check for Updates")
    term.setTextColor(C_BTN_ACCENT)
    term.write(" ]")
    
    term.setCursorPos(2, startY + 2)
    term.setTextColor(C_BTN_ACCENT)
    term.write("[ ")
    term.setTextColor(C_WARN)
    term.write("Reboot System")
    term.setTextColor(C_BTN_ACCENT)
    term.write(" ]")

    term.setCursorPos(2, h-1)
    term.setTextColor(colors.gray)
    term.write("NgOS v" .. ngos.version)
end

local function runUpdate()
    dofile("/ngos/bin/updater.lua")
    drawMenu()
end

while true do
    drawMenu()
    local event, btn, x, y = os.pullEvent("mouse_click")
    
    if y == 4 and x <= 25 then
        runUpdate()
        
    elseif y == 6 and x <= 20 then
        os.reboot()
    end
end