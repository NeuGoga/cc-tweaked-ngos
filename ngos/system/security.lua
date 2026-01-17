local sha256 = require("ngos.lib.sha256")
local DIGEST_FILE = "/etc/system.digest"
local CONFIG_FILE = "/etc/security.cfg"

local security = {}

-- Load Config
local function loadConfig()
    if fs.exists(CONFIG_FILE) then
        local f = fs.open(CONFIG_FILE, "r")
        local data = textutils.unserializeJSON(f.readAll())
        f.close()
        return data
    end
    return { enabled = false, hash = nil }
end

local function saveConfig(data)
    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serializeJSON(data))
    f.close()
end

-- ==========================================
-- UI HELPER (Shared between Boot and Settings)
-- ==========================================

local function drawBox(title, message, isError)
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    
    local bx, by = math.floor(w/4), math.floor(h/3)
    local bw, bh = math.floor(w/2), 6
    
    paintutils.drawBox(bx, by, bx+bw, by+bh, isError and colors.red or colors.cyan)
    
    term.setCursorPos(bx+2, by)
    term.setTextColor(isError and colors.red or colors.cyan)
    term.write(" " .. title .. " ")
    
    term.setCursorPos(bx+2, by+2)
    term.setTextColor(colors.white)
    term.write(message)
    
    return bx+2, by+4
end

-- ==========================================
-- PUBLIC API
-- ==========================================

function security.isEnabled()
    local cfg = loadConfig()
    return cfg.enabled
end

-- ==========================================
-- INTEGRITY CHECKER
-- ==========================================
function security.checkIntegrity()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)
    print("NgOS Boot Guard")
    print("Verifying System Integrity...")
    
    if not fs.exists(DIGEST_FILE) then
        term.setTextColor(colors.orange)
        print("System Digest missing.")
        print("Initializing security...")
        
        if fs.exists("/ngos/bin/gen_digest.lua") then
            dofile("/ngos/bin/gen_digest.lua")
            sleep(1)
            term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
            print("NgOS Boot Guard")
        else
            print("Error: Generator not found.")
            sleep(2)
            return true
        end
    end
    
    local f = fs.open(DIGEST_FILE, "r")
    local knownHashes = textutils.unserializeJSON(f.readAll())
    f.close()
    
    local errors = 0
    
    for path, expectedHash in pairs(knownHashes) do
        term.write(" " .. fs.getName(path) .. " ")
        
        if not fs.exists(path) then
            term.setTextColor(colors.red)
            print("[MISSING]")
            errors = errors + 1
        else
            local f = fs.open(path, "rb")
            local content = f.readAll()
            f.close()
            
            local cleanContent = content:gsub("\r", "")
            local actualHash = sha256.hex(cleanContent)
            
            if actualHash == expectedHash then
                term.setTextColor(colors.lime)
                print("[OK]")
            else
                term.setTextColor(colors.red)
                print("[MODIFIED]")
                errors = errors + 1
            end
        end
        term.setTextColor(colors.white)
    end
    
    if errors > 0 then
        print("\n" .. errors .. " integrity violations found.")
        print("System may be compromised.")
        write("Press Enter to continue anyway... ")
        read()
        return false
    end
    
    sleep(0.5)
    return true
end

function security.bootLogin()
    local cfg = loadConfig()
    if not cfg.enabled or not cfg.hash then return end
    
    while true do
        local ix, iy = drawBox("Protected Boot", "Enter Password:", false)
        term.setCursorPos(ix, iy)
        local input = read("*")
        
        if sha256.hex(input) == cfg.hash then
            return true
        else
            drawBox("Access Denied", "Incorrect Password.", true)
            sleep(1)
        end
    end
end

function security.enableProtection()
    local cfg = loadConfig()
    
    while true do
        local ix, iy = drawBox("Security Setup", "Create Password:", false)
        term.setCursorPos(ix, iy)
        local p1 = read("*")
        
        local ix2, iy2 = drawBox("Security Setup", "Confirm Password:", false)
        term.setCursorPos(ix2, iy2)
        local p2 = read("*")
        
        if p1 == p2 and #p1 > 0 then
            cfg.hash = sha256.hex(p1)
            cfg.enabled = true
            saveConfig(cfg)
            drawBox("Success", "Protection Enabled.", false)
            sleep(1)
            return true
        else
            drawBox("Error", "Passwords did not match.", true)
            sleep(1)
        end
    end
end

function security.disableProtection()
    local cfg = loadConfig()
    if not cfg.enabled then return true end
    
    local attempts = 0
    while attempts < 3 do
        local ix, iy = drawBox("Security Check", "Enter current password:", false)
        term.setCursorPos(ix, iy)
        local input = read("*")
        
        if sha256.hex(input) == cfg.hash then
            cfg.enabled = false
            saveConfig(cfg)
            drawBox("Success", "Protection Disabled.", false)
            sleep(1)
            return true
        else
            drawBox("Error", "Incorrect Password.", true)
            sleep(1)
            attempts = attempts + 1
        end
    end
    return false
end

return security