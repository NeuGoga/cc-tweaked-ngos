local w, h = term.getSize()
local DATABASE_FILE = "/etc/installed.json"
local CATALOG_URL = "https://raw.githubusercontent.com/NeuGoga/cc-tweaked-ngos-apps/main/apps.json"

-- Colors
local C_BG = colors.black
local C_TAB_OFF = colors.gray
local C_TAB_ON = colors.cyan
local C_TEXT = colors.white
local C_ACCENT = colors.lime
local C_ERROR = colors.red

-- State
local currentTab = "install" 
local localData = {}  
local remoteData = {} 
local selectedApp = nil
local showModal = nil 

local sha256 = require("ngos.lib.sha256")

-- ==========================================
-- Data Management
-- ==========================================

local function loadLocalDB()
    if fs.exists(DATABASE_FILE) then
        local f = fs.open(DATABASE_FILE, "r")
        local data = f.readAll()
        f.close()
        localData = textutils.unserializeJSON(data) or {}
    else
        localData = {}
    end
end

local function saveLocalDB()
    local f = fs.open(DATABASE_FILE, "w")
    f.write(textutils.serializeJSON(localData))
    f.close()
end

local function fetchCatalog()
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.blue)
    term.clearLine()
    term.write(" Connecting to repository...")
    
    local response = http.get(CATALOG_URL)
    if response then
        local content = response.readAll()
        response.close()
        remoteData = textutils.unserializeJSON(content) or {}
    else
        remoteData = {}
    end
end

-- ==========================================
-- Installation / Removal Logic
-- ==========================================

local function performInstall(appEntry)
    term.setBackgroundColor(C_BG)
    term.clear()
    term.setCursorPos(1,1)
    print("Fetching manifest for " .. appEntry.name .. "...")
    
    local resp = http.get(appEntry.manifest)
    if not resp then 
        print("Error: Could not get manifest.")
        sleep(2)
        return 
    end
    
    local manifest = textutils.unserializeJSON(resp.readAll())
    resp.close()
    
    if not manifest or not manifest.files then
        print("Error: Invalid manifest format.")
        sleep(2)
        return
    end
    
    local installDir = "/apps/" .. appEntry.id
    if not fs.exists(installDir) then fs.makeDir(installDir) end
    
    print("Downloading files...")
    local hasErrors = false

    for localName, remoteData in pairs(manifest.files) do
        term.setTextColor(C_TEXT)
        term.write(" - " .. localName .. " ")
        
        local url = ""
        local expectedHash = nil
        
        if type(remoteData) == "table" then
            url = remoteData.url
            expectedHash = remoteData.sha256
        else
            url = remoteData -- Old format (just a string URL)
        end
        
        local fileResp = http.get(url)
        if fileResp then
            local content = fileResp.readAll()
            fileResp.close()
            
            local verified = true
            
            if expectedHash then
                -- Normalize newlines before hashing to match online tools
                local cleanContent = content:gsub("\r", "")
                local actualHash = sha256.hex(cleanContent)
                
                if actualHash ~= expectedHash then
                    verified = false
                    hasErrors = true
                    term.setTextColor(colors.red)
                    print("[HASH FAIL]")
                    print("   Exp: " .. expectedHash:sub(1,8))
                    print("   Got: " .. actualHash:sub(1,8))
                    sleep(1)
                end
            else
                -- Warn but allow
                term.setTextColor(colors.gray)
                write("[UNSIGNED] ")
            end
            
            if verified then
                local targetPath = fs.combine(installDir, localName)
                local parentDir = fs.getDir(targetPath)
                if not fs.exists(parentDir) then fs.makeDir(parentDir) end
                
                local f = fs.open(targetPath, "w")
                f.write(content)
                f.close()
                
                if expectedHash then
                    term.setTextColor(colors.lime)
                    print("[OK]")
                else
                    term.setTextColor(colors.white)
                    print("Saved")
                end
            else
                term.setTextColor(colors.red)
                print("Skipped (Security)")
            end
        else
            term.setTextColor(colors.red)
            print("[DOWNLOAD FAIL]")
            hasErrors = true
        end
    end
    
    if not hasErrors then
        localData[appEntry.id] = {
            name = appEntry.name,
            version = manifest.version,
            manifestUrl = appEntry.manifest
        }
        saveLocalDB()
        term.setTextColor(colors.lime)
        print("\nSuccess! App installed.")
    else
        term.setTextColor(colors.orange)
        print("\nFinished with errors.")
    end
    
    sleep(1)
end

local function performVerify(appId, appEntry)
    if not appEntry then return end

    term.setBackgroundColor(C_BG)
    term.clear()
    term.setCursorPos(1,1)
    
    local displayName = appEntry.name or appId
    print("Verifying " .. displayName .. "...")
    
    if not appEntry.manifestUrl then
        print("Error: Corrupt install data (no URL).")
        sleep(2)
        return
    end
    
    local resp = http.get(appEntry.manifestUrl)
    if not resp then print("Error: Offline."); sleep(2); return end
    
    local manifest = textutils.unserializeJSON(resp.readAll())
    resp.close()
    
    if not manifest or not manifest.files then print("Error: Bad manifest."); sleep(2); return end
    
    local installDir = "/apps/" .. appId
    local issues = 0
    
    print("Checking Integrity...")
    
    for localName, remoteData in pairs(manifest.files) do
        term.setTextColor(C_TEXT)
        term.write(" " .. localName .. " ")
        
        local fullPath = fs.combine(installDir, localName)
        
        local expectedHash = nil
        if type(remoteData) == "table" then
            expectedHash = remoteData.sha256
        end
        
        if not fs.exists(fullPath) then
            term.setTextColor(colors.red)
            print("[MISSING]")
            issues = issues + 1
        elseif expectedHash then
            local f = fs.open(fullPath, "r")
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
                issues = issues + 1
            end
        else
            term.setTextColor(colors.gray)
            print("[NO HASH]")
        end
    end
    
    term.setTextColor(C_TEXT)
    print(string.rep("-", 20))
    if issues == 0 then
        term.setTextColor(colors.lime)
        print("Integrity Verified.")
    else
        term.setTextColor(colors.red)
        print("Found " .. issues .. " issues.")
        print("Recommendation: Reinstall.")
    end
    
    print("\nPress Enter to return.")
    read()
end

local function performUninstall(appId)
    local dir = "/apps/" .. appId
    if fs.exists(dir) then
        fs.delete(dir)
    end
    localData[appId] = nil
    saveLocalDB()
end

-- ==========================================
-- UI Rendering
-- ==========================================

local function drawHeader()
    local leftBg = (currentTab == "install") and C_TAB_ON or C_TAB_OFF
    paintutils.drawFilledBox(1, 1, w/2, 3, leftBg)
    
    local rightBg = (currentTab == "installed") and C_TAB_ON or C_TAB_OFF
    paintutils.drawFilledBox((w/2)+1, 1, w, 3, rightBg)
    
    term.setCursorPos(math.floor(w/4)-4, 2)
    term.setBackgroundColor(leftBg)
    term.setTextColor(C_BG)
    term.write("Available")
    
    term.setCursorPos(math.floor(w*0.75)-4, 2)
    term.setBackgroundColor(rightBg)
    term.setTextColor(C_BG)
    term.write("Installed")
end

local function drawList()
    term.setBackgroundColor(C_BG)
    paintutils.drawFilledBox(1, 4, w, h, C_BG)
    
    local y = 5
    local listToDraw = {}
    
    if currentTab == "install" then
        for _, app in ipairs(remoteData) do
            if not localData[app.id] then table.insert(listToDraw, app) end
        end
    else
        for id, info in pairs(localData) do
            table.insert(listToDraw, {id=id, name=info.name, desc="v"..(info.version or "?")})
        end
    end
    
    if #listToDraw == 0 then
        term.setCursorPos(3, 6)
        term.setTextColor(colors.gray)
        term.write(currentTab == "install" and "No new apps." or "No apps installed.")
    end

    for i, app in ipairs(listToDraw) do
        term.setCursorPos(2, y)
        term.setBackgroundColor(C_BG)
        
        if selectedApp and selectedApp.id == app.id then
            term.setTextColor(C_ACCENT)
            term.write("> " .. app.name)
        else
            term.setTextColor(C_TEXT)
            term.write("  " .. app.name)
        end
        
        if currentTab == "install" then
            local btnText = "[ Install ]"
            app.btnX = w - #btnText - 1
            
            term.setCursorPos(app.btnX, y)
            term.setTextColor(colors.blue)
            term.write(btnText)
        else
            local txtRem = "[ Remove ]"
            local txtVer = "[ Verify ]"
            
            app.remX = w - #txtRem - 1
            app.verX = app.remX - #txtVer - 1
            
            term.setCursorPos(app.verX, y)
            term.setTextColor(colors.cyan)
            term.write(txtVer)
            
            term.setCursorPos(app.remX, y)
            term.setTextColor(colors.red)
            term.write(txtRem)
        end
        
        app.y = y
        y = y + 2
    end
    return listToDraw
end

local function drawModal()
    if not showModal then return end
    
    local bw, bh = 26, 8
    local bx, by = math.floor((w-bw)/2), math.floor((h-bh)/2)
    
    paintutils.drawFilledBox(bx, by, bx+bw, by+bh, colors.lightGray)
    
    term.setCursorPos(bx+2, by+2)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.write(showModal.text)
    
    term.setCursorPos(bx+3, by+6)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.white)
    term.write(" YES ")
    
    term.setCursorPos(bx+bw-8, by+6)
    term.setBackgroundColor(colors.red)
    term.write(" NO ")
end

-- ==========================================
-- Main Loop
-- ==========================================

loadLocalDB()
fetchCatalog()

while true do
    drawHeader()
    local visibleList = drawList()
    drawModal()
    
    local event, p1, p2, p3 = os.pullEvent()
    
    if event == "mouse_click" then
        local btn, x, y = p1, p2, p3
        
        if showModal then
            local bw, bh = 26, 8
            local bx, by = math.floor((w-bw)/2), math.floor((h-bh)/2)
            
            if y == by+6 then
                if x >= bx+3 and x <= bx+7 then
                    showModal.onYes()
                    showModal = nil
                    loadLocalDB()
                    selectedApp = nil
                elseif x >= bx+bw-8 and x <= bx+bw-4 then
                    showModal = nil
                end
            end
            
        elseif y <= 3 then
            if x < w/2 then currentTab = "install" 
            else currentTab = "installed" end
            selectedApp = nil
            
        else
            for _, app in ipairs(visibleList) do
                if y == app.y then
                    selectedApp = app
                    
                    if currentTab == "install" then
                        if x >= app.btnX then
                            showModal = {
                                text = "Install " .. app.name .. "?",
                                onYes = function() performInstall(app) end
                            }
                        end
                    else
                        if x >= app.remX then
                            showModal = {
                                text = "Delete " .. app.name .. "?",
                                onYes = function() performUninstall(app.id) end
                            }
                        elseif x >= app.verX and x < app.remX then
                            performVerify(app.id, localData[app.id])
                        end
                    end
                end
            end
        end
    end
end