-- Idea Generator Module
-- Generates creative song ideas from learned patterns.

local ideaGenerator = {}
local analyzer = require("modules.analyzer")

-- Generates a song idea guided by AI analysis
function ideaGenerator.generateAIGuidedIdea(db, specifiedGenre)
    local genres = {}
    
    -- If genre is specified, use it; otherwise get all genres
    if specifiedGenre and db.genreIndex[specifiedGenre] then
        genres = {specifiedGenre}
    else
        for genre in pairs(db.genreIndex) do
            table.insert(genres, genre)
        end
        
        if #genres == 0 then
            -- Default genres if database is empty
            return {
                genre = "pop",
                instruments = {"piano", "drums", "bass"},
                bpm = 120,
                guidedBy = "default"
            }
        end
    end
    
    -- Select a random genre
    local genre = genres[math.random(1, #genres)]
    
    -- Get instrument frequencies for this genre
    local instrumentFreq = analyzer.getInstrumentFrequencyForGenre(db, genre)
    
    -- Select instruments (up to 3 most common)
    local selectedInstruments = {}
    local instrumentCount = math.min(3, #instrumentFreq)
    
    for i = 1, instrumentCount do
        if instrumentFreq[i] then
            table.insert(selectedInstruments, instrumentFreq[i].instrument)
        end
    end
    
    -- If no instruments found, use defaults
    if #selectedInstruments == 0 then
        selectedInstruments = {"piano", "drums", "bass"}
    end
    
    -- Get BPM range for genre or use defaults
    local bpmRange = db.genreBpmRanges[genre] or { min = 80, max = 160 }
    local randomBpm = math.random(bpmRange.min, bpmRange.max)
    
    return {
        genre = genre,
        instruments = selectedInstruments,
        bpm = randomBpm,
        guidedBy = "AI"
    }
end

-- Generates multiple song ideas
function ideaGenerator.generateMultipleIdeas(db, count, specifiedGenre)
    count = math.max(1, math.min(10, count or 3)) -- Limit to 1-10 ideas
    local ideas = {}
    
    for i = 1, count do
        local idea = ideaGenerator.generateAIGuidedIdea(db, specifiedGenre)
        table.insert(ideas, idea)
    end
    
    return ideas
end

-- Generates a human-guided song idea
function ideaGenerator.generateHumanGuidedIdea(db, specifiedGenre)
    if not db.genreIndex[specifiedGenre] then
        return nil
    end
    
    local instrumentFreq = analyzer.getInstrumentFrequencyForGenre(db, specifiedGenre)
    
    if #instrumentFreq == 0 then
        return nil
    end
    
    local selectedInstruments = {}
    local instrumentCount = math.min(3, #instrumentFreq)
    
    for i = 1, instrumentCount do
        if instrumentFreq[i] then
            table.insert(selectedInstruments, instrumentFreq[i].instrument)
        end
    end
    
    local avgBpm = analyzer.getAverageBpmForGenre(db, specifiedGenre)
    
    return {
        genre = specifiedGenre,
        instruments = selectedInstruments,
        bpm = avgBpm,
        guidedBy = "Human"
    }
end

return ideaGenerator
