local w, h = term.getSize()

local MANIFEST_URL = "https://raw.githubusercontent.com/NeuGoga/cc-tweaked-ngos/main/os_manifest.json"
local VERSION_FILE = "/etc/os.info"

-- COLORS
local C_TITLE = colors.cyan
local C_TEXT  = colors.white
local C_DIM   = colors.gray
local C_OK    = colors.lime
local C_ERR   = colors.red
local C_WARN  = colors.orange

local function header()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(C_TITLE)
    print("NgOS System Updater")
    term.setTextColor(C_DIM)
    print(string.rep("-", w))
end

local function printStatus(text, color)
    term.setTextColor(color)
    print(text)
end

header()

local currentVer = "Unknown"
if _G.ngos and _G.ngos.version then
    currentVer = _G.ngos.version
end

printStatus(" Current Version: " .. currentVer, C_TEXT)
printStatus(" Checking remote server...", C_DIM)

-- Fetch Manifest
local resp = http.get(MANIFEST_URL)
if not resp then
    printStatus(" Error: Could not connect to GitHub.", C_ERR)
    printStatus("\n Press any key to exit.", C_DIM)
    os.pullEvent("key")
    return
end

local manifest = textutils.unserializeJSON(resp.readAll())
resp.close()

if not manifest or not manifest.version then
    printStatus(" Error: Invalid manifest data.", C_ERR)
    sleep(2)
    return
end

-- Compare Versions
if manifest.version == currentVer then
    printStatus("\n System is up to date!", C_OK)
    printStatus(" Remote: " .. manifest.version, C_DIM)
    
    term.setTextColor(C_TEXT)
    write("\n Force update anyway? (y/n): ")
    term.setCursorBlink(true)
    sleep(0.1)
    local input = read()
    term.setCursorBlink(false)
    
    if string.lower(input) ~= "y" then 
        print("\nCancelled.")
        sleep(1)
        return 
    end
else
    printStatus("\n New version found: " .. manifest.version, C_OK)
    printStatus(" Press [Enter] to install...", C_TEXT)
    read()
end

-- Start Update
header()
printStatus(" Updating to v" .. manifest.version .. "...", C_TITLE)

for localPath, remoteUrl in pairs(manifest.files) do
    term.setTextColor(C_DIM)
    write(" > " .. fs.getName(localPath) .. " ")
    
    -- Download
    local d = http.get(remoteUrl)
    if d then
        local content = d.readAll()
        d.close()
        
        -- Ensure directory exists
        local dir = fs.getDir(localPath)
        if not fs.exists(dir) then fs.makeDir(dir) end
        
        -- Write file
        local f = fs.open(localPath, "w")
        f.write(content)
        f.close()
        
        term.setTextColor(C_OK)
        print("[OK]")
    else
        term.setTextColor(C_ERR)
        print("[ERR]")
        printStatus("   Failed to download file.", C_ERR)
        sleep(1)
    end
end

-- Update Local Version File
local infoData = {
    name = "NgOS",
    version = manifest.version,
    channel = "Stable",
    updated = os.time("utc")
}

local f = fs.open(VERSION_FILE, "w")
f.write(textutils.serializeJSON(infoData))
f.close()

printStatus("\n Update Complete!", C_OK)

if fs.exists("/ngos/bin/gen_digest.lua") then
    printStatus(" Updating Security Digest...", C_DIM)
    dofile("/ngos/bin/gen_digest.lua")
end

printStatus(" System will reboot in 3 seconds.", C_TEXT)
sleep(3)
os.reboot()