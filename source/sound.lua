-- Sound module for Torchy's World
-- Generates all game sounds using Playdate's synthesizer API
-- No external audio files needed

local snd <const> = playdate.sound

class('SoundManager').extends()

function SoundManager:init()
    SoundManager.super.init(self)

    -- === BLASTER SYNTH (laser zap sound) ===
    self.blasterSynth = snd.synth.new(snd.kWaveSquare)
    self.blasterSynth:setADSR(0.0, 0.05, 0.0, 0.05)
    self.blasterSynth:setVolume(0.3)

    -- === HIT/DESTROY SYNTH (satisfying crunch) ===
    self.hitSynth = snd.synth.new(snd.kWaveNoise)
    self.hitSynth:setADSR(0.0, 0.08, 0.0, 0.1)
    self.hitSynth:setVolume(0.3)

    self.hitToneSynth = snd.synth.new(snd.kWaveSine)
    self.hitToneSynth:setADSR(0.0, 0.1, 0.0, 0.05)
    self.hitToneSynth:setVolume(0.2)

    -- === JUMP SYNTH (ascending boing) ===
    self.jumpSynth = snd.synth.new(snd.kWaveSine)
    self.jumpSynth:setADSR(0.0, 0.1, 0.3, 0.1)
    self.jumpSynth:setVolume(0.25)

    -- === STAR COLLECT SYNTH (bright chime) ===
    self.starSynth = snd.synth.new(snd.kWaveTriangle)
    self.starSynth:setADSR(0.0, 0.05, 0.2, 0.15)
    self.starSynth:setVolume(0.3)

    -- === CRANK WHOOSH SYNTH (noise tied to crank speed) ===
    self.whooshSynth = snd.synth.new(snd.kWaveNoise)
    self.whooshSynth:setADSR(0.02, 0.05, 0.8, 0.1)
    self.whooshSynth:setVolume(0.0)
    self.whooshPlaying = false
    self.whooshTargetVol = 0

    -- === GAME OVER SYNTH ===
    self.gameOverSynth = snd.synth.new(snd.kWaveSawtooth)
    self.gameOverSynth:setADSR(0.0, 0.3, 0.0, 0.3)
    self.gameOverSynth:setVolume(0.3)

    -- === MUSIC SYNTHS ===
    self.melodySynth = snd.synth.new(snd.kWaveSquare)
    self.melodySynth:setADSR(0.01, 0.1, 0.4, 0.1)
    self.melodySynth:setVolume(0.12)

    self.bassSynth = snd.synth.new(snd.kWaveSawtooth)
    self.bassSynth:setADSR(0.01, 0.15, 0.3, 0.1)
    self.bassSynth:setVolume(0.1)

    self.percSynth = snd.synth.new(snd.kWaveNoise)
    self.percSynth:setADSR(0.0, 0.02, 0.0, 0.02)
    self.percSynth:setVolume(0.08)

    -- Music state
    self.musicPlaying = false
    self.musicBeat = 0
    self.musicTimer = 0
    self.bpm = 140
    self.beatDuration = 60 / self.bpm * 30 -- frames per beat at 30fps

    -- Driving melody pattern (MIDI note numbers)
    -- Energetic, forward-motion feel inspired by Smash Hit
    self.melodyPattern = {
        -- Bar 1
        {note = 72, dur = 0.15},  -- C5
        {note = 0,  dur = 0.1},   -- rest
        {note = 75, dur = 0.15},  -- Eb5
        {note = 0,  dur = 0.1},   -- rest
        -- Bar 2
        {note = 79, dur = 0.15},  -- G5
        {note = 77, dur = 0.1},   -- F5
        {note = 75, dur = 0.15},  -- Eb5
        {note = 0,  dur = 0.1},   -- rest
        -- Bar 3
        {note = 72, dur = 0.15},  -- C5
        {note = 70, dur = 0.1},   -- Bb4
        {note = 67, dur = 0.2},   -- G4
        {note = 0,  dur = 0.1},   -- rest
        -- Bar 4
        {note = 70, dur = 0.15},  -- Bb4
        {note = 72, dur = 0.1},   -- C5
        {note = 75, dur = 0.2},   -- Eb5
        {note = 0,  dur = 0.1},   -- rest
    }

    -- Bass pattern (lower octave, root notes)
    self.bassPattern = {
        {note = 48, dur = 0.3},   -- C3
        {note = 0,  dur = 0.1},
        {note = 48, dur = 0.15},  -- C3
        {note = 0,  dur = 0.1},
        {note = 51, dur = 0.3},   -- Eb3
        {note = 0,  dur = 0.1},
        {note = 51, dur = 0.15},  -- Eb3
        {note = 0,  dur = 0.1},
        {note = 55, dur = 0.3},   -- G3
        {note = 0,  dur = 0.1},
        {note = 55, dur = 0.15},  -- G3
        {note = 0,  dur = 0.1},
        {note = 53, dur = 0.3},   -- F3
        {note = 0,  dur = 0.1},
        {note = 51, dur = 0.15},  -- Eb3
        {note = 0,  dur = 0.1},
    }

    self.melodyIndex = 1
    self.bassIndex = 1
    self.melodyWait = 0
    self.bassWait = 0
end

-- === SOUND EFFECTS ===

function SoundManager:playBlaster()
    -- Descending frequency sweep for laser/blaster feel
    self.blasterSynth:playMIDINote(80, 0.3, 0.08)
    -- Schedule a lower note shortly after for the sweep effect
    playdate.timer.performAfterDelay(30, function()
        self.blasterSynth:playMIDINote(60, 0.2, 0.06)
    end)
end

function SoundManager:playHit()
    -- Noise burst + low tone for satisfying destruction
    self.hitSynth:playMIDINote(40, 0.35, 0.12)
    self.hitToneSynth:playMIDINote(55, 0.25, 0.15)
end

function SoundManager:playJump()
    -- Quick ascending tone
    self.jumpSynth:playMIDINote(65, 0.25, 0.08)
    playdate.timer.performAfterDelay(40, function()
        self.jumpSynth:playMIDINote(72, 0.2, 0.08)
    end)
end

function SoundManager:playStar()
    -- Bright ascending chime
    self.starSynth:playMIDINote(76, 0.3, 0.1)
    playdate.timer.performAfterDelay(60, function()
        self.starSynth:playMIDINote(83, 0.25, 0.15)
    end)
end

function SoundManager:playGameOver()
    -- Descending sad tone
    self.gameOverSynth:playMIDINote(60, 0.3, 0.2)
    playdate.timer.performAfterDelay(200, function()
        self.gameOverSynth:playMIDINote(55, 0.25, 0.2)
    end)
    playdate.timer.performAfterDelay(400, function()
        self.gameOverSynth:playMIDINote(48, 0.3, 0.4)
    end)
end

-- === CRANK WHOOSH ===

function SoundManager:updateWhoosh(crankChange)
    local absChange = math.abs(crankChange)

    if absChange > 1 then
        self.whooshTargetVol = math.min(0.15, absChange / 40)

        if not self.whooshPlaying then
            self.whooshSynth:playNote(200, 0.0, 0)  -- indefinite, start silent
            self.whooshPlaying = true
        end

        -- Set frequency based on crank speed (faster = higher pitch)
        local freq = 150 + absChange * 8
        self.whooshSynth:setFrequency(math.min(freq, 600))
    else
        self.whooshTargetVol = 0
    end

    -- Smooth volume transition
    local currentVol = self.whooshSynth:getVolume()
    local newVol = currentVol + (self.whooshTargetVol - currentVol) * 0.3
    self.whooshSynth:setVolume(newVol)

    -- Stop synth if volume is near zero
    if newVol < 0.005 and self.whooshPlaying and self.whooshTargetVol == 0 then
        self.whooshSynth:stop()
        self.whooshPlaying = false
    end
end

-- === MUSIC ===

function SoundManager:startMusic()
    self.musicPlaying = true
    self.melodyIndex = 1
    self.bassIndex = 1
    self.melodyWait = 0
    self.bassWait = 0
    self.musicTimer = 0
end

function SoundManager:stopMusic()
    self.musicPlaying = false
    self.melodySynth:stop()
    self.bassSynth:stop()
end

function SoundManager:updateMusic(gameSpeed)
    if not self.musicPlaying then return end

    -- Tempo scales slightly with game speed
    local tempoMult = 0.8 + gameSpeed * 0.2
    self.musicTimer = self.musicTimer + tempoMult

    -- Update melody
    self.melodyWait = self.melodyWait - tempoMult
    if self.melodyWait <= 0 then
        local note = self.melodyPattern[self.melodyIndex]
        if note.note > 0 then
            self.melodySynth:playMIDINote(note.note, 0.12, note.dur)
        end
        self.melodyWait = self.beatDuration * (note.dur / 0.15)
        self.melodyIndex = self.melodyIndex + 1
        if self.melodyIndex > #self.melodyPattern then
            self.melodyIndex = 1
        end
    end

    -- Update bass
    self.bassWait = self.bassWait - tempoMult
    if self.bassWait <= 0 then
        local note = self.bassPattern[self.bassIndex]
        if note.note > 0 then
            self.bassSynth:playMIDINote(note.note, 0.10, note.dur)
        end
        self.bassWait = self.beatDuration * (note.dur / 0.15)
        self.bassIndex = self.bassIndex + 1
        if self.bassIndex > #self.bassPattern then
            self.bassIndex = 1
        end
    end

    -- Percussion hits on beat
    self.musicBeat = self.musicBeat + tempoMult
    if self.musicBeat >= self.beatDuration then
        self.musicBeat = self.musicBeat - self.beatDuration
        self.percSynth:playMIDINote(40, 0.08, 0.02)
    end
end

function SoundManager:cleanup()
    self:stopMusic()
    if self.whooshPlaying then
        self.whooshSynth:stop()
        self.whooshPlaying = false
    end
end
