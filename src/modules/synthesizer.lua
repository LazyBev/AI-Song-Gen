-- Audio Synthesizer Module
-- Generates raw audio waveforms from song ideas directly to MP3.

local synthesizer = {}

-- Generates a sine wave at a given frequency and sample rate
local function generateSineWave(frequency, duration, sampleRate, amplitude)
    local samples = {}
    local numSamples = math.floor(duration * sampleRate)
    local twoPi = 2 * math.pi
    
    for i = 0, numSamples - 1 do
        local t = i / sampleRate
        local sample = amplitude * math.sin(twoPi * frequency * t)
        table.insert(samples, sample)
    end
    
    return samples
end

-- Converts frequency in Hz to MIDI note number
local function frequencyToMidi(frequency)
    return 12 * math.log(frequency / 440) / math.log(2) + 69
end

-- Converts MIDI note number to frequency in Hz
local function midiToFrequency(midiNote)
    return 440 * math.pow(2, (midiNote - 69) / 12)
end

-- Generates audio samples for a complete song
local function generateAudioSamples(songIdea, durationBars)
    local sampleRate = 44100
    local beatsPerBar = 4
    local beatDuration = 60 / songIdea.bpm
    local barDuration = beatDuration * beatsPerBar
    local totalDuration = barDuration * durationBars
    
    local totalSamples = math.floor(totalDuration * sampleRate)
    local audioData = {}
    for i = 1, totalSamples do
        audioData[i] = 0
    end
    
    local notes = { 60, 62, 64, 65, 67, 69, 71 }  -- C, D, E, F, G, A, B
    local notesPerBeat = 4
    local samplesPerNote = math.floor(sampleRate * beatDuration / notesPerBeat)
    
    -- Generate melody
    for noteIdx = 1, math.floor(totalDuration * sampleRate / samplesPerNote) do
        if math.random() > 0.3 then
            local midiNote = notes[math.random(1, #notes)] + (math.random(0, 2) * 12)
            local frequency = midiToFrequency(midiNote)
            local startSample = (noteIdx - 1) * samplesPerNote + 1
            
            -- Generate note with envelope (attack, decay, sustain, release)
            for sampleIdx = 1, samplesPerNote do
                if startSample + sampleIdx <= totalSamples then
                    local t = sampleIdx / sampleRate
                    local noteDuration = samplesPerNote / sampleRate
                    
                    -- Simple ADSR envelope
                    local envelope = 1.0
                    if t < noteDuration * 0.1 then
                        envelope = t / (noteDuration * 0.1)
                    elseif t > noteDuration * 0.8 then
                        envelope = (noteDuration - t) / (noteDuration * 0.2)
                    end
                    
                    local sample = 0.1 * envelope * math.sin(2 * math.pi * frequency * t)
                    audioData[startSample + sampleIdx] = audioData[startSample + sampleIdx] + sample
                end
            end
        end
    end
    
    -- Generate drums (kick, snare, hihat)
    local beatDurationSamples = math.floor(sampleRate * beatDuration)
    
    for bar = 1, durationBars do
        for beat = 1, beatsPerBar do
            local beatStartSample = (bar - 1) * beatsPerBar * beatDurationSamples + (beat - 1) * beatDurationSamples + 1
            
            -- Kick drum on beats 1 and 3
            if beat == 1 or beat == 3 then
                for i = 0, math.floor(beatDurationSamples * 0.5) - 1 do
                    if beatStartSample + i <= totalSamples then
                        local t = i / sampleRate
                        local envelope = math.exp(-10 * t)
                        local kickFreq = 150 * envelope
                        audioData[beatStartSample + i] = audioData[beatStartSample + i] + 0.3 * envelope * math.sin(2 * math.pi * kickFreq * t)
                    end
                end
            end
            
            -- Snare on beats 2 and 4
            if beat == 2 or beat == 4 then
                for i = 0, math.floor(beatDurationSamples * 0.3) - 1 do
                    if beatStartSample + i <= totalSamples then
                        local t = i / sampleRate
                        local envelope = math.exp(-15 * t)
                        audioData[beatStartSample + i] = audioData[beatStartSample + i] + 0.2 * envelope * (2 * math.random() - 1)
                    end
                end
            end
            
            -- Hi-hat on eighth notes
            for eighth = 1, 2 do
                local hatStartSample = beatStartSample + math.floor((eighth - 1) * beatDurationSamples * 0.5)
                for i = 0, math.floor(beatDurationSamples * 0.1) - 1 do
                    if hatStartSample + i <= totalSamples then
                        local t = i / sampleRate
                        local envelope = math.exp(-20 * t)
                        audioData[hatStartSample + i] = audioData[hatStartSample + i] + 0.15 * envelope * (2 * math.random() - 1)
                    end
                end
            end
        end
    end
    
    -- Normalize to prevent clipping
    local maxSample = 0
    for _, sample in ipairs(audioData) do
        maxSample = math.max(maxSample, math.abs(sample))
    end
    
    if maxSample > 0 then
        for i, sample in ipairs(audioData) do
            audioData[i] = sample / maxSample * 0.95
        end
    end
    
    return audioData, sampleRate
end

-- Converts audio samples to WAV format
local function samplesToWav(audioData, sampleRate)
    local numChannels = 1
    local bitsPerSample = 16
    local byteRate = sampleRate * numChannels * bitsPerSample / 8
    local blockAlign = numChannels * bitsPerSample / 8
    local numSamples = #audioData
    local dataSize = numSamples * blockAlign
    
    local wav = ""
    
    -- RIFF header
    wav = wav .. "RIFF"
    wav = wav .. string.char(
        (36 + dataSize) % 256,
        math.floor((36 + dataSize) / 256) % 256,
        math.floor((36 + dataSize) / 65536) % 256,
        math.floor((36 + dataSize) / 16777216) % 256
    )
    wav = wav .. "WAVE"
    
    -- fmt subchunk
    wav = wav .. "fmt "
    wav = wav .. string.char(16, 0, 0, 0)
    wav = wav .. string.char(1, 0)
    wav = wav .. string.char(numChannels, 0)
    wav = wav .. string.char(
        sampleRate % 256,
        math.floor(sampleRate / 256) % 256,
        math.floor(sampleRate / 65536) % 256,
        math.floor(sampleRate / 16777216) % 256
    )
    wav = wav .. string.char(
        byteRate % 256,
        math.floor(byteRate / 256) % 256,
        math.floor(byteRate / 65536) % 256,
        math.floor(byteRate / 16777216) % 256
    )
    wav = wav .. string.char(blockAlign % 256, math.floor(blockAlign / 256) % 256)
    wav = wav .. string.char(bitsPerSample % 256, math.floor(bitsPerSample / 256) % 256)
    
    -- data subchunk
    wav = wav .. "data"
    wav = wav .. string.char(
        dataSize % 256,
        math.floor(dataSize / 256) % 256,
        math.floor(dataSize / 65536) % 256,
        math.floor(dataSize / 16777216) % 256
    )
    
    -- Audio data (16-bit PCM)
    for _, sample in ipairs(audioData) do
        local intSample = math.floor(sample * 32767)
        if intSample > 32767 then intSample = 32767 end
        if intSample < -32768 then intSample = -32768 end
        
        wav = wav .. string.char(intSample % 256, math.floor(intSample / 256) % 256)
    end
    
    return wav
end

-- Main function to generate a complete song
function synthesizer.generateSong(songIdea, outputPath, durationBars)
    durationBars = durationBars or 8
    
    print(string.format("Synthesizing: %s @ %d BPM", songIdea.genre, songIdea.bpm))
    print(string.format("  Instruments: %s", table.concat(songIdea.instruments, ", ")))
    
    -- Generate audio samples
    local audioData, sampleRate = generateAudioSamples(songIdea, durationBars)
    
    -- Convert to WAV
    local wavData = samplesToWav(audioData, sampleRate)
    
    -- Write WAV to temporary file
    local wavPath = outputPath:gsub("%.mp3$", ".wav")
    local wavFile = io.open(wavPath, "wb")
    if not wavFile then
        print(string.format("Error: Could not write to %s", wavPath))
        return false
    end
    wavFile:write(wavData)
    wavFile:close()
    print(string.format("Generated WAV: %s", wavPath))
    
    -- Convert WAV to MP3 using ffmpeg
    local mp3Path = outputPath
    local cmd = string.format('ffmpeg -i "%s" -acodec libmp3lame -ab 192k "%s" -y 2>/dev/null', wavPath, mp3Path)
    
    print(string.format("Converting to MP3..."))
    local result = os.execute(cmd)
    
    if result == 0 or result == true then
        print(string.format("MP3 file written: %s", mp3Path))
        os.remove(wavPath)
        return true
    else
        print(string.format("Error: Could not convert WAV to MP3"))
        print(string.format("Keeping WAV file: %s", wavPath))
        return false
    end
end

return synthesizer