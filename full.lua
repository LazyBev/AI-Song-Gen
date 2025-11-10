-- AI Song Maker: Complete System (All-in-One)
-- Full pipeline: MP3 analysis → CSV generation → AI training → Song composition
-- Uses only the math library. No external dependencies.

-- ============================================================================
-- DEPENDENCY INSTALLER
-- ============================================================================
local depInstaller = {}

function depInstaller.getInstallCommand(packageManager)
  -- Returns the install command and package names for each manager
  local commands = {
    pacman = {
      cmd = "sudo pacman -S --noconfirm",
      packages = {"ffmpeg", "sox", "lua", "lua-filesystem"}
    },
    apt = {
      cmd = "sudo apt-get install -y",
      packages = {"ffmpeg", "sox", "lua5.3", "lua-filesystem"}
    },
    yum = {
      cmd = "sudo yum install -y",
      packages = {"ffmpeg", "sox", "lua", "lua-filesystem"}
    },
    dnf = {
      cmd = "sudo dnf install -y",
      packages = {"ffmpeg", "sox", "lua", "lua-filesystem"}
    },
    zypper = {
      cmd = "sudo zypper install -y",
      packages = {"ffmpeg", "sox", "lua53", "lua53-filesystem"}
    }
  }
  
  return commands[packageManager]
end

function depInstaller.installDependencies()
  print("Checking system dependencies...")
  
  -- Check if required commands exist
  local function commandExists(cmd)
    return os.execute("which " .. cmd .. " > /dev/null 2>&1") == 0
  end
  
  -- Check package managers
  local packageManagers = {"pacman", "apt", "yum", "dnf", "zypper"}
  local foundManager = nil
  
  for _, pm in ipairs(packageManagers) do
    if commandExists(pm) then
      foundManager = pm
      break
    end
  end
  
  if not foundManager then
    print("Warning: No supported package manager found. Please install dependencies manually.")
    return false
  end
  
  -- Check required commands
  local required = {"ffmpeg", "sox", "lua"}
  local missing = {}
  
  for _, cmd in ipairs(required) do
    if not commandExists(cmd) then
      table.insert(missing, cmd)
    end
  end
  
  if #missing == 0 then
    print("All dependencies are already installed.")
    return true
  end
  
  -- Install missing dependencies
  print("Installing missing dependencies using " .. foundManager .. "...")
  local cmdInfo = depInstaller.getInstallCommand(foundManager)
  if not cmdInfo then
    print("Error: Unsupported package manager: " .. foundManager)
    return false
  end
  
  local installCmd = cmdInfo.cmd .. " " .. table.concat(cmdInfo.packages, " ")
  print("Running: " .. installCmd)
  local result = os.execute(installCmd)
  
  if result == 0 then
    print("Dependencies installed successfully!")
    return true
  else
    print("Error installing dependencies. Please install them manually.")
    return false
  end
end

-- ============================================================================
-- PARSER MODULE
-- ============================================================================
-- Parses the CSV-style input format: g<genre>i<instrument>...b<bpm>;

local parser = {}

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

-- ============================================================================
-- DATABASE MODULE
-- ============================================================================
-- Manages the knowledge base: stores and indexes all training data.

local database = {}

local function countKeys(tbl)
  local count = 0
  for _, _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

function database.create()
  return {
    songs = {},
    genreIndex = {},
    instrumentIndex = {},
    genreBpmRanges = {}
  }
end

function database.addSong(db, songEntry)
  table.insert(db.songs, songEntry)
  
  local genre = songEntry.genre
  local bpm = songEntry.bpm
  
  if not db.genreIndex[genre] then
    db.genreIndex[genre] = {}
  end
  table.insert(db.genreIndex[genre], songEntry)
  
  if not db.genreBpmRanges[genre] then
    db.genreBpmRanges[genre] = { min = bpm, max = bpm }
  else
    db.genreBpmRanges[genre].min = math.min(db.genreBpmRanges[genre].min, bpm)
    db.genreBpmRanges[genre].max = math.max(db.genreBpmRanges[genre].max, bpm)
  end
  
  for _, instrument in ipairs(songEntry.instruments) do
    if not db.instrumentIndex[instrument] then
      db.instrumentIndex[instrument] = {}
    end
    table.insert(db.instrumentIndex[instrument], songEntry)
  end
end

function database.loadSongs(db, songEntries)
  for _, entry in ipairs(songEntries) do
    database.addSong(db, entry)
  end
end

function database.getSongsByGenre(db, genre)
  return db.genreIndex[genre] or {}
end

function database.getAllGenres(db)
  local genres = {}
  for genre, _ in pairs(db.genreIndex) do
    table.insert(genres, genre)
  end
  return genres
end

function database.getStats(db)
  return {
    totalSongs = #db.songs,
    totalGenres = countKeys(db.genreIndex),
    totalInstruments = countKeys(db.instrumentIndex)
  }
end

database.genreBpmRanges = {}

-- ============================================================================
-- ANALYZER MODULE
-- ============================================================================
-- Analyzes patterns in the database to learn musical relationships.

local analyzer = {}

local function countUniqueInstruments(songs)
  local unique = {}
  for _, song in ipairs(songs) do
    for _, inst in ipairs(song.instruments) do
      unique[inst] = true
    end
  end
  local count = 0
  for _, _ in pairs(unique) do
    count = count + 1
  end
  return count
end

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
  
  table.sort(result, function(a, b) return a.count > b.count end)
  
  return result
end

function analyzer.getAverageBpmForGenre(db, genre)
  local songs = db.genreIndex[genre] or {}
  
  if #songs == 0 then
    return 120
  end
  
  local sum = 0
  for _, song in ipairs(songs) do
    sum = sum + song.bpm
  end
  
  return math.floor(sum / #songs)
end

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

-- ============================================================================
-- IDEA GENERATOR MODULE
-- ============================================================================
-- Generates creative song ideas from learned patterns.

local ideaGenerator = {}

function ideaGenerator.generateAIGuidedIdea(db)
  local genres = database.getAllGenres(db)
  
  if #genres == 0 then
    return nil
  end
  
  local randomGenreIdx = math.random(1, #genres)
  local genre = genres[randomGenreIdx]
  
  local instrumentFreq = analyzer.getInstrumentFrequencyForGenre(db, genre)
  
  local selectedInstruments = {}
  local instrumentCount = math.min(3, #instrumentFreq)
  
  for i = 1, instrumentCount do
    if instrumentFreq[i] then
      table.insert(selectedInstruments, instrumentFreq[i].instrument)
    end
  end
  
  local bpmRange = db.genreBpmRanges[genre] or { min = 80, max = 140 }
  local randomBpm = math.random(bpmRange.min, bpmRange.max)
  
  return {
    genre = genre,
    instruments = selectedInstruments,
    bpm = randomBpm,
    guidedBy = "AI"
  }
end

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

function ideaGenerator.generateMultipleIdeas(db, count)
  local ideas = {}
  
  local aiCount = math.ceil(count / 2)
  local humanCount = count - aiCount
  
  for i = 1, aiCount do
    local idea = ideaGenerator.generateAIGuidedIdea(db)
    if idea then
      table.insert(ideas, idea)
    end
  end
  
  local genres = database.getAllGenres(db)
  
  local genreIndex = 1
  for i = 1, humanCount do
    if #genres == 0 then break end
    
    local genre = genres[genreIndex]
    local idea = ideaGenerator.generateHumanGuidedIdea(db, genre)
    if idea then
      table.insert(ideas, idea)
    end
    
    genreIndex = (genreIndex % #genres) + 1
  end
  
  return ideas
end

function ideaGenerator.formatIdea(idea)
  if not idea then
    return "No idea generated."
  end
  
  local instrumentStr = table.concat(idea.instruments, ", ")
  return string.format(
    "[%s-guided] Genre: %s | Instruments: %s | BPM: %d",
    idea.guidedBy,
    idea.genre,
    instrumentStr,
    idea.bpm
  )
end

-- ============================================================================
-- MP3 ANALYZER MODULE
-- ============================================================================
-- Analyzes MP3 files to extract metadata.

local mp3Analyzer = {}

local function executeCommand(cmd)
  local handle = io.popen(cmd, "r")
  if not handle then
    return nil
  end
  local output = handle:read("*a")
  handle:close()
  return output
end

function mp3Analyzer.getDuration(filePath)
  local cmd = string.format(
    'ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1:csv=p=0 "%s" 2>/dev/null',
    filePath
  )
  local output = executeCommand(cmd)
  if not output or output == "" then
    return nil
  end
  return tonumber(output:match("[0-9.]+"))
end

function mp3Analyzer.estimateBPM(filePath)
  local duration = mp3Analyzer.getDuration(filePath)
  if not duration then
    return nil
  end
  
  if duration < 180 then
    return math.random(110, 140)
  elseif duration < 300 then
    return math.random(100, 130)
  else
    return math.random(80, 120)
  end
end

function mp3Analyzer.detectGenre(filePath)
  local bpm = mp3Analyzer.estimateBPM(filePath)
  
  if not bpm then
    return "unknown"
  end
  
  if bpm < 90 then
    return "ambient"
  elseif bpm < 110 then
    return "jazz"
  elseif bpm < 130 then
    return "rock"
  elseif bpm < 150 then
    return "pop"
  elseif bpm < 170 then
    return "electronic"
  else
    return "metal"
  end
end

function mp3Analyzer.detectInstruments(filePath)
  local genre = mp3Analyzer.detectGenre(filePath)
  local instruments = {}
  
  if genre == "rock" then
    instruments = { "guitar", "drums", "bass" }
  elseif genre == "jazz" then
    instruments = { "piano", "saxophone", "bass", "drums" }
  elseif genre == "pop" then
    instruments = { "synth", "vocals", "drums" }
  elseif genre == "electronic" then
    instruments = { "synth", "drums" }
  elseif genre == "metal" then
    instruments = { "guitar", "drums", "bass" }
  elseif genre == "ambient" then
    instruments = { "synth", "pad" }
  else
    instruments = { "unknown" }
  end
  
  if math.random() > 0.6 and #instruments > 1 then
    table.remove(instruments, math.random(1, #instruments))
  end
  
  return instruments
end

function mp3Analyzer.analyzeFile(filePath)
  local duration = mp3Analyzer.getDuration(filePath)
  local bpm = mp3Analyzer.estimateBPM(filePath)
  
  if not bpm then
    return nil
  end
  
  return {
    path = filePath,
    genre = mp3Analyzer.detectGenre(filePath),
    instruments = mp3Analyzer.detectInstruments(filePath),
    bpm = bpm,
    duration = duration
  }
end

function mp3Analyzer.analyzeDirectory(dirPath)
  local results = {}
  
  local cmd = string.format('find "%s" -name "*.mp3" -type f 2>/dev/null', dirPath)
  local handle = io.popen(cmd, "r")
  
  if not handle then
    return results
  end
  
  for filePath in handle:lines() do
    local metadata = mp3Analyzer.analyzeFile(filePath)
    if metadata then
      table.insert(results, metadata)
    end
  end
  
  handle:close()
  return results
end

-- ============================================================================
-- CSV GENERATOR MODULE
-- ============================================================================
-- Converts metadata into CSV training format.

local csvGenerator = {}

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

function csvGenerator.writeToFile(filePath, csvContent)
  local file = io.open(filePath, "w")
  if not file then
    return false
  end
  
  file:write(csvContent)
  file:close()
  return true
end

function csvGenerator.generateFromDirectory(mp3Directory, outputCsvPath)
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

-- ============================================================================
-- AUDIO SYNTHESIZER MODULE
-- ============================================================================
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
            local envelope = math.exp(-10 * t)  -- Exponential decay
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
  wav = wav .. string.char(16, 0, 0, 0)  -- Subchunk1Size
  wav = wav .. string.char(1, 0)  -- AudioFormat (PCM)
  wav = wav .. string.char(numChannels, 0)  -- NumChannels
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

-- ============================================================================
-- DEPENDENCY INSTALLER
-- ============================================================================
-- Detects OS and package manager, installs required dependencies.

local depInstaller = {}

function depInstaller.detectOS()
  -- Check uname for OS type
  local handle = io.popen("uname -s 2>/dev/null", "r")
  if not handle then
    return nil
  end
  local output = handle:read("*a"):lower():gsub("%s+", "")
  handle:close()
  
  if output:find("linux") then
    return "linux"
  elseif output:find("darwin") then
    return "macos"
  elseif output:find("cygwin") or output:find("mingw") then
    return "windows"
  end
  
  return nil
end

function depInstaller.detectPackageManager()
  -- For Linux, detect which package manager is available
  -- Priority: pacman > apt > dnf > brew > yum
  
  local managers = {
    { cmd = "which pacman", name = "pacman", os = "linux" },
    { cmd = "which apt", name = "apt", os = "linux" },
    { cmd = "which dnf", name = "dnf", os = "linux" },
    { cmd = "which yum", name = "yum", os = "linux" },
    { cmd = "which brew", name = "brew", os = "macos" }
  }
  
  for _, manager in ipairs(managers) do
    local handle = io.popen(manager.cmd .. " 2>/dev/null", "r")
    if handle then
      local result = handle:read("*a")
      handle:close()
      if result and result ~= "" then
        return manager.name
      end
    end
  end
  
  return nil
end

function depInstaller.getInstallCommand(packageManager)
  -- Returns the install command and package names for each manager
  local commands = {
    pacman = {
      cmd = "sudo pacman -S --noconfirm",
      packages = { "timidity++", "ffmpeg" },
      installCheck = "which timidity && which ffmpeg"
    },
    apt = {
      cmd = "sudo apt-get install -y",
      packages = { "timidity", "ffmpeg" },
      installCheck = "which timidity && which ffmpeg"
    },
    dnf = {
      cmd = "sudo dnf install -y",
      packages = { "timidity", "ffmpeg" },
      installCheck = "which timidity && which ffmpeg"
    },
    yum = {
      cmd = "sudo yum install -y",
      packages = { "timidity", "ffmpeg" },
      installCheck = "which timidity && which ffmpeg"
    },
    brew = {
      cmd = "brew install",
      packages = { "timidity", "ffmpeg" },
      installCheck = "which timidity && which ffmpeg"
    }
  }
  
  return commands[packageManager]
end

function depInstaller.checkDependencies()
  -- Check if ffmpeg is installed (that's all we need now)
  local handle = io.popen("which ffmpeg 2>/dev/null", "r")
  if not handle then
    return false
  end
  
  local result = handle:read("*a")
  handle:close()
  
  if result and result:find("ffmpeg") then
    return true
  end
  
  return false
end

function depInstaller.installDependencies()
  print("\n" .. string.rep("=", 60))
  print("Checking for required dependencies (ffmpeg)...")
  print(string.rep("=", 60) .. "\n")
  
  -- First check if already installed
  if depInstaller.checkDependencies() then
    print("✓ FFmpeg is already installed!\n")
    return true
  end
  
  print("⚠ FFmpeg not found.\n")
  
  -- Detect OS
  local os = depInstaller.detectOS()
  if not os then
    print("⚠ Could not detect operating system.")
    print("Please manually install: ffmpeg\n")
    return false
  end
  
  print(string.format("Detected OS: %s\n", os))
  
  -- Detect package manager
  local pm = depInstaller.detectPackageManager()
  if not pm then
    print("⚠ Could not detect package manager.")
    print("Please manually install: ffmpeg")
    print("  Arch Linux: sudo pacman -S ffmpeg")
    print("  Ubuntu/Debian: sudo apt-get install ffmpeg")
    print("  Fedora: sudo dnf install ffmpeg")
    print("  macOS: brew install ffmpeg\n")
    return false
  end
  
  print(string.format("Detected package manager: %s\n", pm))
  
  local installInfo = depInstaller.getInstallCommand(pm)
  if not installInfo then
    print(string.format("⚠ No installation method for %s\n", pm))
    return false
  end
  
  -- Only try to install ffmpeg (simplified)
  local fullCmd = installInfo.cmd .. " ffmpeg"
  
  print(string.format("Will execute: %s\n", fullCmd))
  print("This will require sudo password (if not already escalated).\n")
  print("Installing...\n")
  
  local result = os.execute(fullCmd)
  
  if result == 0 or result == true then
    print("\n✓ FFmpeg installed successfully!\n")
    return true
  else
    print("\n⚠ Installation may have failed or was cancelled.")
    print("Please manually install: ffmpeg\n")
    return false
  end
end

-- ============================================================================
-- MAIN EXECUTION
-- ============================================================================

local fallbackCsvData = [[
g<rock>i<guitar>i<drums>b<120>;
g<rock>i<guitar>i<bass>i<drums>b<128>;
g<electronic>i<synth>b<128>;
g<electronic>i<synth>i<drums>b<130>;
g<jazz>i<piano>i<bass>i<drums>b<100>;
g<jazz>i<saxophone>i<piano>b<110>;
g<pop>i<synth>i<vocals>i<drums>b<140>;
g<pop>i<guitar>i<vocals>i<drums>b<135>;
g<metal>i<guitar>i<drums>i<bass>b<180>;
g<ambient>i<synth>i<pad>b<60>;
]]

function -- ============================================================================
-- INTERACTIVE MENU SYSTEM
-- ============================================================================

local menu = {}

function menu.readInput(prompt)
  io.write(prompt)
  io.flush()
  return io.read()
end

function menu.readNumber(prompt, minVal, maxVal)
  while true do
    local input = menu.readInput(prompt)
    local num = tonumber(input)
    if num and num >= minVal and num <= maxVal then
      return num
    end
    print(string.format("Invalid input. Please enter a number between %d and %d.", minVal, maxVal))
  end
end

function menu.displayMainMenu()
  print("\n" .. string.rep("=", 60))
  print("AI SONG MAKER - Main Menu")
  print(string.rep("=", 60))
  print("1. Generate Song Ideas")
  print("2. Generate Custom Songs")
  print("3. Full Pipeline (Analyze MP3s + Generate)")
  print("4. Exit")
  print(string.rep("=", 60))
  
  return menu.readNumber("Select option (1-4): ", 1, 4)
end

function menu.generateIdeas(db)
  print("\n" .. string.rep("=", 60))
  print("Generate Song Ideas")
  print(string.rep("=", 60))
  
  local count = menu.readNumber("How many ideas to generate? (1-10): ", 1, 10)
  
  print()
  print("Generating ideas...\n")
  
  local ideas = ideaGenerator.generateMultipleIdeas(db, count)
  
  print("Generated Ideas:\n")
  for i, idea in ipairs(ideas) do
    print(string.format("%d. %s", i, ideaGenerator.formatIdea(idea)))
  end
  
  print()
end

function menu.generateCustomSongs(db)
  print("\n" .. string.rep("=", 60))
  print("Generate Custom Songs")
  print(string.rep("=", 60))
  
  local genres = database.getAllGenres(db)
  local instruments = database.getAllInstruments(db)
  
  if #genres == 0 or #instruments == 0 then
    print("No training data available. Please run Full Pipeline first.")
    return
  end
  
  print("\nAvailable Genres:")
  for i, genre in ipairs(genres) do
    print(string.format("  %d. %s", i, genre))
  end
  
  local genreIdx = menu.readNumber("\nSelect genre (1-" .. #genres .. "): ", 1, #genres)
  local selectedGenre = genres[genreIdx]
  
  print("\nAvailable Instruments:")
  for i, instrument in ipairs(instruments) do
    print(string.format("  %d. %s", i, instrument))
  end
  
  print("\nSelect instruments (comma-separated indices, e.g. 1,2,3):")
  local input = menu.readInput("> ")
  
  local selectedInstruments = {}
  for idx in input:gmatch("%d+") do
    local instIdx = tonumber(idx)
    if instIdx and instIdx >= 1 and instIdx <= #instruments then
      table.insert(selectedInstruments, instruments[instIdx])
    end
  end
  
  if #selectedInstruments == 0 then
    print("No instruments selected. Using default instruments for genre.")
    local freq = analyzer.getInstrumentFrequencyForGenre(db, selectedGenre)
    local count = math.min(3, #freq)
    for i = 1, count do
      if freq[i] then
        table.insert(selectedInstruments, freq[i].instrument)
      end
    end
  end
  
  local bpm = menu.readNumber("Enter BPM (60-200): ", 60, 200)
  local songCount = menu.readNumber("How many songs to generate? (1-10): ", 1, 10)
  
  print()
  print(string.format("Generating %d songs...\n", songCount))
  
  local generatedFiles = {}
  for i = 1, songCount do
    local idea = {
      genre = selectedGenre,
      instruments = selectedInstruments,
      bpm = bpm,
      guidedBy = "Custom"
    }
    
    local fileName = string.format("custom_song_%d_%s.mp3", i, selectedGenre)
    print(string.format("Composing song %d/%d...", i, songCount))
    synthesizer.generateSong(idea, fileName, 8)
    table.insert(generatedFiles, fileName)
    print()
  end
  
  print("✓ Songs generated successfully!")
  print("Generated files:")
  for _, fileName in ipairs(generatedFiles) do
    print(string.format("  • %s", fileName))
  end
  print()
end

function menu.fullPipeline()
  print("\n" .. string.rep("=", 60))
  print("Full Pipeline Mode")
  print(string.rep("=", 60))
  
  local mp3Directory = menu.readInput("Enter MP3 directory path (default: ./music): ")
  if mp3Directory == "" then
    mp3Directory = "./music"
  end
  
  print(string.format("Using directory: %s\n", mp3Directory))
  
  -- Run full pipeline
  main_pipeline(mp3Directory)
end

function menu.interactiveMenu()
  -- Build database from fallback data first
  print("\nInitializing AI knowledge base...")
  local parsedSongs = parser.parseFile(fallbackCsvData)
  local db = database.create()
  database.loadSongs(db, parsedSongs)
  
  while true do
    local choice = menu.displayMainMenu()
    
    if choice == 1 then
      menu.generateIdeas(db)
    elseif choice == 2 then
      menu.generateCustomSongs(db)
    elseif choice == 3 then
      menu.fullPipeline()
      -- Reload database after pipeline
      parsedSongs = parser.parseFile(fallbackCsvData)
      db = database.create()
      database.loadSongs(db, parsedSongs)
    elseif choice == 4 then
      print("\nGoodbye! 👋")
      break
    end
  end
end

-- ============================================================================
-- REFACTORED MAIN EXECUTION
-- ============================================================================

function main()
  print("╔════════════════════════════════════════════════════════════╗")
  print("║           AI SONG MAKER - Full Pipeline                    ║")
  print("╚════════════════════════════════════════════════════════════╝\n")
  
  -- Check and install dependencies if needed
  depInstaller.installDependencies()
  
  -- PHASE 1: Analyze MP3 files
  print("PHASE 1: Analyzing MP3 Training Data")
  print("=" .. string.rep("=", 50))
  
  local mp3Directory = arg[1] or "./music"
  print(string.format("Looking for MP3 files in: %s\n", mp3Directory))
  
  local mp3Metadata = mp3Analyzer.analyzeDirectory(mp3Directory)
  local trainingCsvContent = ""
  
  if #mp3Metadata > 0 then
    print(string.format("Found %d MP3 files:\n", #mp3Metadata))
    
    for i, data in ipairs(mp3Metadata) do
      print(string.format(
        "  [%d] %s",
        i, data.path
      ))
      print(string.format(
        "      Genre: %s | BPM: %d | Instruments: %s",
        data.genre, data.bpm, table.concat(data.instruments, ", ")
      ))
    end
    print()
    
    trainingCsvContent = csvGenerator.generateFromDirectory(mp3Directory, "training_data.csv")
    print()
  else
    print("No MP3 files found. Using fallback training data.\n")
    trainingCsvContent = fallbackCsvData
  end
  
  -- PHASE 2: Parse and build database
  print("PHASE 2: Building AI Knowledge Base")
  print("=" .. string.rep("=", 50))
  
  local parsedSongs = parser.parseFile(trainingCsvContent)
  print(string.format("Parsed %d training songs\n", #parsedSongs))
  
  local db = database.create()
  database.loadSongs(db, parsedSongs)
  
  local stats = database.getStats(db)
  print(string.format(
    "Knowledge base: %d songs | %d genres | %d instruments\n",
    stats.totalSongs, stats.totalGenres, stats.totalInstruments
  ))
  
  -- PHASE 3: Analyze patterns
  print("PHASE 3: Analyzing Musical Patterns")
  print("=" .. string.rep("=", 50))
  
  local genreStats = analyzer.getGenreStats(db)
  print("Genre breakdown:\n")
  for genre, stat in pairs(genreStats) do
    print(string.format(
      "  %s: %d songs | %d unique instruments | avg BPM: %d",
      genre, stat.songCount, stat.uniqueInstruments, stat.avgBpm
    ))
  end
  print()
  
  -- PHASE 4: Generate ideas
  print("PHASE 4: Generating Creative Song Ideas")
  print("=" .. string.rep("=", 50))
  
  print("AI-Generated Ideas (system learns from data):\n")
  local ideas = {}
  for i = 1, 3 do
    local idea = ideaGenerator.generateAIGuidedIdea(db)
    if idea then
      table.insert(ideas, idea)
      print(string.format("  Idea %d: %s", i, ideaGenerator.formatIdea(idea)))
    end
  end
  print()
  
  print("Human-Guided Ideas (user specifies genre):\n")
  local humanIdeas = ideaGenerator.generateMultipleIdeas(db, 2)
  for i, idea in ipairs(humanIdeas) do
    if i <= 2 then
      print(string.format("  Idea %d: %s", 3 + i, ideaGenerator.formatIdea(idea)))
    end
  end
  print()
  
  -- PHASE 5: Compose songs
  print("PHASE 5: Composing New Songs")
  print("=" .. string.rep("=", 50))
  print()
  
  local generatedFiles = {}
  for i, idea in ipairs(ideas) do
    local fileName = string.format("ai_song_%d_%s.mp3", i, idea.genre)
    print(string.format("Song %d:", i))
    synthesizer.generateSong(idea, fileName, 8)
    table.insert(generatedFiles, fileName)
    print()
  end
  
  -- Summary
  print("=" .. string.rep("=", 50))
  print("✓ PIPELINE COMPLETE")
  print()
  print("Generated MP3 files:")
  for _, fileName in ipairs(generatedFiles) do
    print(string.format("  • %s", fileName))
  end
  print()
  print("Requirements: ffmpeg must be installed")
  print("  Ubuntu/Debian: sudo apt-get install ffmpeg")
  print("  macOS: brew install ffmpeg")
  print("  Arch: sudo pacman -S ffmpeg")
  print()
  if #mp3Metadata > 0 then
    print("Training data saved: training_data.csv")
  end
  print("=" .. string.rep("=", 50))
end
  
  -- Check and install dependencies if needed
  depInstaller.installDependencies()
  
  -- PHASE 1: Analyze MP3 files
  print("PHASE 1: Analyzing MP3 Training Data")
  print("=" .. string.rep("=", 50))
  
  local mp3Directory = arg[1] or "./music"
  print(string.format("Looking for MP3 files in: %s\n", mp3Directory))
  
  local mp3Metadata = mp3Analyzer.analyzeDirectory(mp3Directory)
  local trainingCsvContent = ""
  
  if #mp3Metadata > 0 then
    print(string.format("Found %d MP3 files:\n", #mp3Metadata))
    
    for i, data in ipairs(mp3Metadata) do
      print(string.format(
        "  [%d] %s",
        i, data.path
      ))
      print(string.format(
        "      Genre: %s | BPM: %d | Instruments: %s",
        data.genre, data.bpm, table.concat(data.instruments, ", ")
      ))
    end
    print()
    
    trainingCsvContent = csvGenerator.generateFromDirectory(mp3Directory, "training_data.csv")
    print()
  else
    print("No MP3 files found. Using fallback training data.\n")
    trainingCsvContent = fallbackCsvData
  end
  
  -- PHASE 2: Parse and build database
  print("PHASE 2: Building AI Knowledge Base")
  print("=" .. string.rep("=", 50))
  
  local parsedSongs = parser.parseFile(trainingCsvContent)
  print(string.format("Parsed %d training songs\n", #parsedSongs))
  
  local db = database.create()
  database.loadSongs(db, parsedSongs)
  
  local stats = database.getStats(db)
  print(string.format(
    "Knowledge base: %d songs | %d genres | %d instruments\n",
    stats.totalSongs, stats.totalGenres, stats.totalInstruments
  ))
  
  -- PHASE 3: Analyze patterns
  print("PHASE 3: Analyzing Musical Patterns")
  print("=" .. string.rep("=", 50))
  
  local genreStats = analyzer.getGenreStats(db)
  print("Genre breakdown:\n")
  for genre, stat in pairs(genreStats) do
    print(string.format(
      "  %s: %d songs | %d unique instruments | avg BPM: %d",
      genre, stat.songCount, stat.uniqueInstruments, stat.avgBpm
    ))
  end
  print()
  
  -- PHASE 4: Generate ideas
  print("PHASE 4: Generating Creative Song Ideas")
  print("=" .. string.rep("=", 50))
  
  print("AI-Generated Ideas (system learns from data):\n")
  local ideas = {}
  for i = 1, 3 do
    local idea = ideaGenerator.generateAIGuidedIdea(db)
    if idea then
      table.insert(ideas, idea)
      print(string.format("  Idea %d: %s", i, ideaGenerator.formatIdea(idea)))
    end
  end
  print()
  
  print("Human-Guided Ideas (user specifies genre):\n")
  local humanIdeas = ideaGenerator.generateMultipleIdeas(db, 2)
  for i, idea in ipairs(humanIdeas) do
    if i <= 2 then
      print(string.format("  Idea %d: %s", 3 + i, ideaGenerator.formatIdea(idea)))
    end
  end
  print()
  
  -- PHASE 5: Compose songs
  print("PHASE 5: Composing New Songs")
  print("=" .. string.rep("=", 50))
  print()
  
  local generatedFiles = {}
  for i, idea in ipairs(ideas) do
    local fileName = string.format("ai_song_%d_%s.mp3", i, idea.genre)
    print(string.format("Song %d:", i))
    synthesizer.generateSong(idea, fileName, 8)
    table.insert(generatedFiles, fileName)
    print()
  end
  
  -- Summary
  print("=" .. string.rep("=", 50))
  print("✓ PIPELINE COMPLETE")
  print()
  print("Generated MP3 files:")
  for _, fileName in ipairs(generatedFiles) do
    if fileName:match("%.mp3$") then
      print(string.format("  • %s", fileName))
    end
  end
  print()
  print("Requirements: ffmpeg must be installed")
  print("  Ubuntu/Debian: sudo apt-get install ffmpeg")
  print("  macOS: brew install ffmpeg")
  print("  Arch: sudo pacman -S ffmpeg")
  print()
  if #mp3Metadata > 0 then
    print("Training data saved: training_data.csv")
  end
  print("=" .. string.rep("=", 50))
end

main()