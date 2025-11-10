-- CSV Generator Module
-- Converts metadata into CSV training format.

local csvGenerator = {}

-- Converts a single metadata object to a CSV line
function csvGenerator.metadataToCsvLine(metadata)
    if not metadata or not metadata.genre or not metadata.bpm or not metadata.instruments then
        return nil
    end
    
    if #metadata.instruments == 0 then
        return nil
    end
    
    local line = string.format("g<%s>", metadata.genre)
    
    for _, instrument in ipairs(metadata.instruments) do
        line = line .. string.format("i<%s>", instrument)
    end
    
    line = line .. string.format("b<%d>;", metadata.bpm)
    
    return line
end

-- Converts a list of metadata objects to CSV format
function csvGenerator.metadataListToCsv(metadataList)
    local lines = {}
    
    for _, metadata in ipairs(metadataList) do
        local line = csvGenerator.metadataToCsvLine(metadata)
        if line then
            table.insert(lines, line)
        end
    end
    
    return table.concat(lines, "\n")
end

-- Writes CSV content to a file
function csvGenerator.writeToFile(filePath, csvContent)
    local file = io.open(filePath, "w")
    if not file then
        return false
    end
    
    file:write(csvContent)
    file:close()
    return true
end

-- Generates CSV from a directory of MP3 files
function csvGenerator.generateFromDirectory(mp3Directory, outputCsvPath)
    local mp3Analyzer = require("modules.mp3Analyzer")
    
    local metadataList = mp3Analyzer.analyzeDirectory(mp3Directory)
    
    if #metadataList == 0 then
        print("Warning: No MP3 files found in " .. mp3Directory)
        return ""
    end
    
    print(string.format("Successfully analyzed %d MP3 files", #metadataList))
    
    local csvContent = csvGenerator.metadataListToCsv(metadataList)
    
    if outputCsvPath then
        local success = csvGenerator.writeToFile(outputCsvPath, csvContent)
        if success then
            print(string.format("CSV written to: %s", outputCsvPath))
        else
            print(string.format("Error: Could not write to %s", outputCsvPath))
        end
    end
    
    return csvContent
end

return csvGenerator