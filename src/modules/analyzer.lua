-- Analyzer Module
-- Analyzes patterns in the database to learn musical relationships.

local analyzer = {}

-- Counts unique instruments in a list of songs
local function countUniqueInstruments(songs)
    local unique = {}
    for _, song in ipairs(songs) do
        for _, inst in ipairs(song.instruments) do
            unique[inst] = true
        end
    end
    local count = 0
    for _ in pairs(unique) do
        count = count + 1
    end
    return count
end

-- Gets instrument frequency for a specific genre
function analyzer.getInstrumentFrequencyForGenre(db, genre)
    local songs = db.genreIndex[genre] or {}
    local frequency = {}
    
    for _, song in ipairs(songs) do
        for _, instrument in ipairs(song.instruments) do
            if not frequency[instrument] then
                frequency[instrument] = 0
            end
            frequency[instrument] = frequency[instrument] + 1
        end
    end
    
    local result = {}
    for instrument, count in pairs(frequency) do
        table.insert(result, { instrument = instrument, count = count })
    end
    
    table.sort(result, function(a, b) 
        return a.count > b.count 
    end)
    
    return result
end

-- Calculates the average BPM for a genre
function analyzer.getAverageBpmForGenre(db, genre)
    local songs = db.genreIndex[genre] or {}
    
    if #songs == 0 then
        return 120  -- Default BPM if no songs found
    end
    
    local sum = 0
    for _, song in ipairs(songs) do
        sum = sum + song.bpm
    end
    
    return math.floor(sum / #songs)
end

-- Gets statistics for all genres
function analyzer.getGenreStats(db)
    local stats = {}
    
    for genre, songs in pairs(db.genreIndex) do
        stats[genre] = {
            songCount = #songs,
            uniqueInstruments = countUniqueInstruments(songs),
            avgBpm = analyzer.getAverageBpmForGenre(db, genre)
        }
    end
    
    return stats
end

return analyzer
