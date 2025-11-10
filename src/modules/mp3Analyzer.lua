-- MP3 Analyzer Module
-- Analyzes MP3 files to extract musical information

local mp3Analyzer = {}
local lfs = require("lfs")  -- Lua File System

-- Analyzes a single MP3 file
function mp3Analyzer.analyzeFile(filepath)
    local result = {
        filename = filepath:match("([^/]+)$"),
        duration = 0,
        bpm = 0,
        genre = nil,
        success = false
    }
    
    -- Use ffmpeg to get file info
    local cmd = string.format(
        "ffmpeg -i \"%s\" -f ffmetadata - 2>&1 | grep -i -E \"duration|bpm|genre\"",
        filepath
    )
    
    local handle = io.popen(cmd)
    if not handle then
        return result
    end
    
    local output = handle:read("*a")
    handle:close()
    
    -- Extract duration (in seconds)
    local durationStr = output:match("Duration: (.-),")
    if durationStr then
        local h, m, s = durationStr:match("(%%d+):(%%d+):([%d.]+)")
        if h and m and s then
            result.duration = h * 3600 + m * 60 + s
        end
    end
    
    -- Extract BPM if available in metadata
    local bpmStr = output:lower():match("bpm:?%s*([%d.]+)")
    if bpmStr then
        result.bpm = math.floor(tonumber(bpmStr) + 0.5)
    end
    
    -- Extract genre if available in metadata
    local genre = output:lower():match("genre:?%s*([^\r\n]+)")
    if genre then
        -- Clean up genre string
        genre = genre:gsub("^%s+", ""):gsub("%s+$", "")
        if genre ~= "" then
            result.genre = genre
        end
    end
    
    -- If BPM not in metadata, estimate it (simplified)
    if result.bpm == 0 then
        -- This is a placeholder - real BPM detection would be more complex
        result.bpm = math.random(80, 160)
    end
    
    -- If genre not detected, make an educated guess based on BPM
    if not result.genre then
        if result.bpm < 90 then
            result.genre = "ballad"
        elseif result.bpm < 110 then
            result.genre = "pop"
        elseif result.bpm < 130 then
            result.genre = "rock"
        else
            result.genre = "dance"
        end
    end
    
    result.success = true
    return result
end

-- Analyzes all MP3 files in a directory
function mp3Analyzer.analyzeDirectory(directory)
    local results = {}
    
    -- Ensure directory ends with a slash
    if directory:sub(-1) ~= "/" then
        directory = directory .. "/"
    end
    
    -- Scan directory for MP3 files
    for file in lfs.dir(directory) do
        if file:lower():match("%.mp3$") then
            local filepath = directory .. file
            print("Analyzing: " .. file)
            
            local status, result = pcall(function()
                return mp3Analyzer.analyzeFile(filepath)
            end)
            
            if status and result then
                table.insert(results, result)
            end
        end
    end
    
    return results
end

-- Estimates BPM from audio file (simplified version)
function mp3Analyzer.estimateBPM(filepath)
    -- This is a placeholder - real BPM detection would use audio analysis
    -- For now, return a random BPM between 80 and 160
    return math.random(80, 160)
end

return mp3Analyzer
