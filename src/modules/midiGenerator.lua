-- MIDI Generator Module
-- Generates MIDI files from song ideas

local midiGenerator = {}

-- Generates a simple MIDI file based on song parameters
function midiGenerator.generate(params)
    local filename = params.filename or "ai_song"
    local bpm = params.bpm or 120
    local genre = params.genre or "pop"
    local durationBars = params.durationBars or 32
    
    -- Ensure filename has .mid extension
    if not filename:lower():match("%.mid$") then
        filename = filename .. ".mid"
    end
    
    -- Generate MIDI data based on genre
    local midiData = midiGenerator.generateMidiData(genre, bpm, durationBars)
    
    -- Write MIDI file
    local file = io.open(filename, "wb")
    if not file then
        return false, "Failed to create MIDI file"
    end
    
    file:write(midiData)
    file:close()
    
    return true, filename
end

-- Generates MIDI data based on genre and parameters
function midiGenerator.generateMidiData(genre, bpm, durationBars)
    -- This is a simplified MIDI file generator
    -- A real implementation would use a proper MIDI library
    
    local header = "MThd" .. string.char(
        0x00, 0x00, 0x00, 0x06,  -- header length
        0x00, 0x01,              -- format 1
        0x00, 0x02,              -- number of tracks
        0x01, 0xE0               -- division (480 ticks per quarter note)
    )
    
    -- Track 1: Tempo and time signature
    local tempoTrack = "MTrk" .. 
        string.char(0x00, 0x00, 0x00, 0x14) ..  -- track length
        string.char(0x00, 0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08) ..  -- time signature
        string.char(0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20) ..  -- tempo (500000 = 120 BPM)
        string.char(0x83, 0x00, 0xFF, 0x2F, 0x00)  -- end of track
    
    -- Track 2: Notes
    local noteTrack = midiGenerator.generateNoteTrack(genre, bpm, durationBars)
    
    -- Combine all chunks
    return header .. tempoTrack .. noteTrack
end

-- Generates note data based on genre
function midiGenerator.generateNoteTrack(genre, bpm, durationBars)
    -- This is a simplified note generator
    -- A real implementation would generate more musically interesting patterns
    
    local notes = {}
    local time = 0
    
    -- Generate different patterns based on genre
    if genre:lower() == "jazz" then
        -- Jazz pattern (swing feel)
        for i = 0, durationBars - 1 do
            -- Walking bass
            local bassNote = 36 + (i % 5)  -- Simple walking pattern
            table.insert(notes, {time = time, note = bassNote, velocity = 90, duration = 48})
            
            -- Piano chords on off-beats
            if i % 2 == 0 then
                table.insert(notes, {time = time + 24, note = 60, velocity = 70, duration = 12})
                table.insert(notes, {time = time + 24, note = 64, velocity = 70, duration = 12})
                table.insert(notes, {time = time + 24, note = 67, velocity = 70, duration = 12})
            end
            
            time = time + 96  -- Move to next bar (assuming 4/4 time)
        end
    else
        -- Default pop/rock pattern
        for i = 0, durationBars - 1 do
            -- Bass on 1 and 3
            table.insert(notes, {time = time, note = 36, velocity = 100, duration = 48})
            table.insert(notes, {time = time + 48, note = 36, velocity = 100, duration = 48})
            
            -- Snare on 2 and 4
            table.insert(notes, {time = time + 24, note = 38, velocity = 80, duration = 12})
            table.insert(notes, {time = time + 72, note = 38, velocity = 80, duration = 12})
            
            -- Hi-hats on 8th notes
            for j = 0, 7 do
                table.insert(notes, {time = time + j * 12, note = 42, velocity = 60, duration = 6})
            end
            
            time = time + 96  -- Move to next bar (assuming 4/4 time)
        end
    end
    
    -- Convert notes to MIDI events
    local events = {}
    local lastTime = 0
    
    for _, note in ipairs(notes) do
        -- Note on
        local deltaTime = note.time - lastTime
        table.insert(events, midiGenerator.encodeVarLen(deltaTime))
        table.insert(events, string.char(0x90))  -- Note on, channel 1
        table.insert(events, string.char(note.note))
        table.insert(events, string.char(note.velocity))
        
        -- Note off
        table.insert(events, midiGenerator.encodeVarLen(note.duration))
        table.insert(events, string.char(0x80))  -- Note off, channel 1
        table.insert(events, string.char(note.note))
        table.insert(events, string.char(0x00))
        
        lastTime = note.time + note.duration
    end
    
    -- Add end of track
    table.insert(events, string.char(0x00, 0xFF, 0x2F, 0x00))
    
    -- Combine all events
    local trackData = table.concat(events)
    
    -- Create track header
    local trackHeader = "MTrk" .. 
        string.pack(">I4", #trackData) ..  -- Track length
        trackData
    
    return trackHeader
end

-- Encodes a variable-length value for MIDI
function midiGenerator.encodeVarLen(value)
    local result = ""
    local buffer = value & 0x7F
    
    while (value > 0x7F) do
        value = value >> 7
        buffer = (buffer << 8) | 0x80 | (value & 0x7F)
    end
    
    while true do
        result = result .. string.char(buffer & 0xFF)
        if (buffer & 0x80) > 0 then
            buffer = buffer >> 8
        else
            break
        end
    end
    
    return result
end

return midiGenerator
