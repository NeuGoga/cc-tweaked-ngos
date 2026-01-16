-- NgOS Bootloader

local sysLib = "/ngos/lib/?.lua;/ngos/lib/?/init.lua"
package.path = sysLib .. ";" .. package.path

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Booting NgOS...")
sleep(0.1)

_G.shell = shell
_G.multishell = multishell
_G.package = package
_G.require = require

local kernelPath = "/ngos/system/kernel.lua"

if not fs.exists(kernelPath) then
    term.setTextColor(colors.red)
    print("FATAL: Kernel not found at " .. kernelPath)
    print("Please reinstall NgOS.")
    return
end

local ok, err = pcall(function()
    dofile(kernelPath)
end)

-- Crash Handler (BSOD)
if not ok then
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 2)
    print(" :(  NgOS Crashed")
    print("------------------")
    print(err)
    print("------------------")
    print("Press R to reboot or T to terminate.")
    
    while true do
        local _, key = os.pullEvent("key")
        if key == keys.r then os.reboot() end
        if key == keys.t then term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1); return end
    end
end