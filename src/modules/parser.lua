-- Parser Module
-- Handles parsing of CSV-style input format: g<genre>i<instrument>...b<bpm>;

local parser = {}

-- Extracts a field value from a line
local function extractFieldValue(line, startPos)
    local openBracket = line:find("<", startPos)
    if not openBracket then
        return nil, startPos
    end
    
    local closeBracket = line:find(">", openBracket)
    if not closeBracket then
        return nil, startPos
    end
    
    local value = line:sub(openBracket + 1, closeBracket - 1)
    return value, closeBracket + 1
end

-- Parses a single line of input
function parser.parseLine(line)
    if not line or line:len() == 0 or line:sub(-1) ~= ";" then
        return nil
    end
    
    line = line:sub(1, -2)
    
    local result = {
        genre = nil,
        instruments = {},
        bpm = nil
    }
    
    local pos = 1
    
    while pos <= line:len() do
        local fieldType = line:sub(pos, pos)
        
        if fieldType == "g" then
            result.genre, pos = extractFieldValue(line, pos)
            if not result.genre then return nil end
            pos = pos + 1
        elseif fieldType == "i" then
            local instrument
            instrument, pos = extractFieldValue(line, pos)
            if not instrument then return nil end
            table.insert(result.instruments, instrument)
            pos = pos + 1
        elseif fieldType == "b" then
            local bpmStr
            bpmStr, pos = extractFieldValue(line, pos)
            if not bpmStr then return nil end
            result.bpm = tonumber(bpmStr)
            if not result.bpm then return nil end
            pos = pos + 1
        else
            pos = pos + 1
        end
    end
    
    if result.genre and #result.instruments > 0 and result.bpm then
        return result
    end
    
    return nil
end

-- Parses a file containing multiple lines
function parser.parseFile(fileContent)
    local entries = {}
    
    for line in fileContent:gmatch("[^\n]+") do
        local entry = parser.parseLine(line)
        if entry then
            table.insert(entries, entry)
        end
    end
    
    return entries
end

return parser
