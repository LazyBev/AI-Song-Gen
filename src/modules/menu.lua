-- Menu Module
-- Handles the interactive menu and user interface

local menu = {}
local db = require("modules.database").create()
local analyzer = require("modules.analyzer")
local ideaGenerator = require("modules.ideaGenerator")
local mp3Analyzer = require("modules.mp3Analyzer")
local midiGenerator = require("modules.midiGenerator")

-- Displays the main menu
function menu.showMainMenu()
    print("\n" .. string.rep("=", 60))
    print("MAIN MENU")
    print(string.rep("=", 60))
    print("1. Generate Song Ideas")
    print("2. Analyze MP3 Files")
    print("3. Generate MIDI from Idea")
    print("4. View Database Stats")
    print("5. Exit")
    print(string.rep("-", 60))
    io.write("Enter your choice (1-5): ")
    
    local choice = tonumber(io.read())
    return choice
end

-- Handles the interactive menu
function menu.interactiveMenu()
    while true do
        local choice = menu.showMainMenu()
        
        if choice == 1 then
            menu.generateIdeas()
        elseif choice == 2 then
            menu.analyzeMP3s()
        elseif choice == 3 then
            menu.generateMIDI()
        elseif choice == 4 then
            menu.viewStats()
        elseif choice == 5 then
            print("\nGoodbye!")
            break
        else
            print("\nInvalid choice. Please try again.")
        end
    end
end

-- Generates song ideas
function menu.generateIdeas()
    print("\n" .. string.rep("=", 60))
    print("GENERATE SONG IDEAS")
    print(string.rep("=", 60))
    
    -- Get user input for genre (optional)
    print("\nEnter a genre (or press Enter for random):")
    local genre = io.read()
    if genre == "" then genre = nil end
    
    -- Get number of ideas to generate
    print("\nNumber of ideas to generate (1-10):")
    local count = tonumber(io.read()) or 3
    count = math.max(1, math.min(10, count))
    
    -- Generate and display ideas
    local ideas = ideaGenerator.generateMultipleIdeas(db, count, genre)
    
    print("\n" .. string.rep("-", 60))
    print(string.format("GENERATED %d SONG IDEAS:", #ideas))
    print(string.rep("-", 60))
    
    for i, idea in ipairs(ideas) do
        print(string.format("\nIDEA #%d:", i))
        print(string.format("  Genre: %s", idea.genre))
        print(string.format("  BPM: %d", idea.bpm))
        print("  Instruments: " .. table.concat(idea.instruments, ", "))
    end
end

-- Analyzes MP3 files
function menu.analyzeMP3s()
    print("\n" .. string.rep("=", 60))
    print("ANALYZE MP3 FILES")
    print(string.rep("=", 60))
    
    print("\nEnter directory containing MP3 files (or press Enter for current):")
    local dir = io.read()
    if dir == "" then dir = "." end
    
    print("\nAnalyzing MP3 files in: " .. dir)
    local results = mp3Analyzer.analyzeDirectory(dir)
    
    if #results > 0 then
        print("\nANALYSIS RESULTS:")
        print(string.rep("-", 60))
        
        for _, result in ipairs(results) do
            print(string.format("\nFile: %s", result.filename))
            print(string.format("  Duration: %.2f seconds", result.duration))
            print(string.format("  BPM: %d", result.bpm or 0))
            print("  Detected Genre: " .. (result.genre or "Unknown"))
        end
        
        -- Add to database
        for _, result in ipairs(results) do
            if result.genre and result.bpm then
                local entry = {
                    genre = result.genre,
                    instruments = result.instruments or {"guitar", "piano", "drums"},
                    bpm = result.bpm
                }
                db.addSong(db, entry)
            end
        end
        
        print("\nAnalysis complete! Added " .. #results .. " songs to database.")
    else
        print("\nNo MP3 files found or analysis failed.")
    end
end

-- Generates MIDI from an idea
function menu.generateMIDI()
    print("\n" .. string.rep("=", 60))
    print("GENERATE MIDI")
    print(string.rep("=", 60))
    
    print("\nEnter genre (or press Enter for random):")
    local genre = io.read()
    if genre == "" then genre = nil end
    
    print("\nEnter BPM (or press Enter for genre default):")
    local bpm = tonumber(io.read())
    
    print("\nEnter output filename (without extension):")
    local filename = io.read()
    if filename == "" then filename = "ai_song" end
    
    -- Generate song idea if no BPM provided
    if not bpm then
        local idea = ideaGenerator.generateAIGuidedIdea(db, genre)
        bpm = idea.bpm
        genre = idea.genre
        
        print("\nGenerated idea:")
        print("  Genre: " .. genre)
        print("  BPM: " .. bpm)
        print("  Instruments: " .. table.concat(idea.instruments, ", "))
    end
    
    -- Generate MIDI
    print("\nGenerating MIDI file...")
    local success = midiGenerator.generate({
        filename = filename,
        genre = genre,
        bpm = bpm,
        durationBars = 32
    })
    
    if success then
        print("\nMIDI file generated: " .. filename .. ".mid")
    else
        print("\nFailed to generate MIDI file.")
    end
end

-- Displays database statistics
function menu.viewStats()
    local stats = analyzer.getGenreStats(db)
    local dbStats = db.getStats(db)
    
    print("\n" .. string.rep("=", 60))
    print("DATABASE STATISTICS")
    print(string.rep("=", 60))
    
    print(string.format("\nTotal Songs: %d", dbStats.totalSongs))
    print(string.format("Total Genres: %d", dbStats.totalGenres))
    print(string.format("Unique Instruments: %d\n", dbStats.totalInstruments))
    
    print("GENRE BREAKDOWN:")
    print(string.rep("-", 60))
    
    for genre, stat in pairs(stats) do
        print(string.format("\n%s:", genre:upper()))
        print(string.format("  Songs: %d", stat.songCount))
        print(string.format("  Unique Instruments: %d", stat.uniqueInstruments))
        print(string.format("  Average BPM: %d", stat.avgBpm))
    end
    
    print("\nPress Enter to continue...")
    io.read()
end

return menu
