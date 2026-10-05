--[Find Frozen DNA Fragment B - Fixed ImGui Render Thread & Auto Suck]

local scriptRunning = false

-- [PENGATURAN POSISI TILE FIND]
local startX = 23 -- Tile awal
local endX = 14   -- Tile akhir
local posY = 190  -- Posisi Y tempat berdiri

-- [PENGATURAN MAGPLANT]
local magX = 23   -- Koordinat Tile X Magplant
local magY = 189  -- Koordinat Tile Y Magplant

local maxLimit = 6500
local delay = 200

local searchText = "frozen dna fragment b"
local targetID = "1348"

local currentX = startX
local currentCount = 0

-- Fungsi Wrench dan Klik "Suck all" di Magplant
function SuckMagplant()
    LogToConsole(">> Mengirim Wrench & Suck All ke Magplant (" .. magX .. ", " .. magY .. ")...")
    
    if SendPacketRaw then
        SendPacketRaw(false, {
            type = 3,
            value = 32, -- Wrench ID
            tile_x = magX,
            tile_y = magY,
            pos_x = magX * 32,
            pos_y = magY * 32
        })
    end
    
    Sleep(300)

    SendPacket(2, 
        "action|dialog_return\n" ..
        "dialog_name|magplant_edit\n" ..
        "x|" .. magX .. "|\n" ..
        "y|" .. magY .. "|\n" ..
        "buttonClicked|suck_all"
    )
    Sleep(500)
end

-- Hook dialog search
AddHook("onvariant", "dna_hook", function(var)
    if not scriptRunning then return false end

    if var[0] == "OnDialogRequest" and var[1]:find("item_finder") then
        return true
    end

    if var[0] == "OnDialogRequest" and var[1]:find("item_search") then
        local packetReturn = "action|dialog_return\ndialog_name|item_search\nsearched|" .. searchText .. "|\n"
        packetReturn = packetReturn .. targetID .. "|1\n"
        packetReturn = packetReturn .. "-" .. targetID .. "|1\n"
        packetReturn = packetReturn .. "buttonClicked|claim_items\nstay|0"
        
        SendPacket(2, packetReturn)
        return true
    end

    return false
end)

-- THREAD 1: KHUSUS RENDER IMGUI (Jalan cepat tanpa delay panjang agar menu tidak hilang)
RunThread(function()
    while true do
        if ImGui then
            if ImGui.Begin("DNA Finder & Magplant Controller") then
                ImGui.Text("Status Script: " .. (scriptRunning and "AKTIF" or "OFF"))
                ImGui.Text("Posisi Tile Aktif: X = " .. currentX .. ", Y = " .. posY)
                ImGui.Text("Progres Tile Ini: " .. currentCount .. " / " .. maxLimit)
                ImGui.Separator()

                if ImGui.Button(scriptRunning and "STOP SCRIPT" or "START SCRIPT") then
                    scriptRunning = not scriptRunning
                    if scriptRunning then
                        SendPacket(2, "action|input\n|text|/find " .. searchText)
                    end
                end

                ImGui.Separator()
                if ImGui.Button("Tes Suck Magplant Manual") then
                    SuckMagplant()
                end

                if ImGui.Button("Reset ke Posisi X 23") then
                    currentX = startX
                    currentCount = 0
                    if FindPath then FindPath(currentX, posY) end
                end

                ImGui.End()
            end
        end
        Sleep(16) -- Render stabil di 60 FPS
    end
end)

-- THREAD 2: KHUSUS LOGIKA KLAIM, PINDAH TILE, & AUTO SUCK MAGPLANT
RunThread(function()
    while true do
        if scriptRunning then
            SendPacket(2, 
                "action|dialog_return\n" ..
                "dialog_name|item_search\n" ..
                "searched|" .. searchText .. "|\n" ..
                targetID .. "|1\n" ..
                "-" .. targetID .. "|1\n" ..
                "buttonClicked|claim_items\n" ..
                "stay|0"
            )

            currentCount = currentCount + 200

            -- Jika tile saat ini penuh (6500)
            if currentCount >= maxLimit then
                currentCount = 0
                local oldX = currentX
                currentX = currentX - 1

                -- Jika semua tile X 23 sampai X 14 sudah selesai
                if currentX < endX then
                    LogToConsole(">> Semua tile (X 23 s/d 14) selesai! Eksekusi Suck All di Magplant...")
                    
                    SuckMagplant()

                    currentX = startX
                    LogToConsole(">> Memulai ulang siklus dari X 23...")
                else
                    LogToConsole(">> Tile X " .. oldX .. " Penuh! Berjalan ke X " .. currentX .. "...")
                end

                if FindPath then
                    FindPath(currentX, posY)
                end
                Sleep(600)

                SendPacket(2, "action|input\n|text|/find " .. searchText)
                Sleep(400)
            end
        end

        Sleep(delay)
    end
end)