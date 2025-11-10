-- Database Module
-- Manages the knowledge base: stores and indexes all training data.

local database = {}

-- Counts the number of keys in a table
local function countKeys(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Creates a new database instance
function database.create()
    return {
        songs = {},
        genreIndex = {},
        instrumentIndex = {},
        genreBpmRanges = {}
    }
end

-- Adds a song to the database
function database.addSong(db, songEntry)
    table.insert(db.songs, songEntry)
    
    local genre = songEntry.genre
    local bpm = songEntry.bpm
    
    -- Index by genre
    if not db.genreIndex[genre] then
        db.genreIndex[genre] = {}
    end
    table.insert(db.genreIndex[genre], songEntry)
    
    -- Track BPM range for genre
    if not db.genreBpmRanges[genre] then
        db.genreBpmRanges[genre] = { min = bpm, max = bpm }
    else
        db.genreBpmRanges[genre].min = math.min(db.genreBpmRanges[genre].min, bpm)
        db.genreBpmRanges[genre].max = math.max(db.genreBpmRanges[genre].max, bpm)
    end
    
    -- Index by instrument
    for _, instrument in ipairs(songEntry.instruments) do
        if not db.instrumentIndex[instrument] then
            db.instrumentIndex[instrument] = {}
        end
        table.insert(db.instrumentIndex[instrument], songEntry)
    end
end

-- Loads multiple songs into the database
function database.loadSongs(db, songEntries)
    for _, entry in ipairs(songEntries) do
        database.addSong(db, entry)
    end
end

-- Gets all songs of a specific genre
function database.getSongsByGenre(db, genre)
    return db.genreIndex[genre] or {}
end

-- Gets all unique genres in the database
function database.getAllGenres(db)
    local genres = {}
    for genre in pairs(db.genreIndex) do
        table.insert(genres, genre)
    end
    return genres
end

-- Gets database statistics
function database.getStats(db)
    return {
        totalSongs = #db.songs,
        totalGenres = countKeys(db.genreIndex),
        totalInstruments = countKeys(db.instrumentIndex)
    }
end

return database
