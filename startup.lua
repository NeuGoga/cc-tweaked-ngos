-- NgOS Bootloader

local sysLib = "/ngos/lib/?.lua;/ngos/lib/?/init.lua"
package.path = sysLib .. ";" .. package.path

_G.shell = shell
_G.multishell = multishell
_G.package = package
_G.require = require

local securityPath = "/ngos/system/security.lua"

if fs.exists(securityPath) then
    local security = require("ngos.system.security")
    
    security.checkIntegrity()
    
    if security.isEnabled() then
        security.bootLogin()
    end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
print("Booting NgOS Kernel...")
sleep(0.5)

local kernelPath = "/ngos/system/kernel.lua"

if not fs.exists(kernelPath) then
    term.setTextColor(colors.red)
    print("FATAL: Kernel not found at " .. kernelPath)
    return
end

local ok, err = pcall(function()
    dofile(kernelPath)
end)

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