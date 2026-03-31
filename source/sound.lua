-- Sound module for Cronobreak
-- Generates all game sounds using Playdate's synthesizer API
-- No external audio files needed
-- Music: High-energy Geometry Dash-inspired chiptune

local snd <const> = playdate.sound

class('SoundManager').extends()

function SoundManager:init()
    SoundManager.super.init(self)

    -- === BLASTER SYNTH (laser zap sound) ===
    self.blasterSynth = snd.synth.new(snd.kWaveSquare)
    self.blasterSynth:setADSR(0.0, 0.05, 0.0, 0.05)
    self.blasterSynth:setVolume(0.35)

    -- === HIT/DESTROY SYNTH (satisfying crunch) ===
    self.hitSynth = snd.synth.new(snd.kWaveNoise)
    self.hitSynth:setADSR(0.0, 0.08, 0.0, 0.1)
    self.hitSynth:setVolume(0.35)

    self.hitToneSynth = snd.synth.new(snd.kWaveSine)
    self.hitToneSynth:setADSR(0.0, 0.1, 0.0, 0.05)
    self.hitToneSynth:setVolume(0.25)

    -- === JUMP SYNTH (ascending boing) ===
    self.jumpSynth = snd.synth.new(snd.kWaveSine)
    self.jumpSynth:setADSR(0.0, 0.1, 0.3, 0.1)
    self.jumpSynth:setVolume(0.3)

    -- === STAR COLLECT SYNTH (bright chime) ===
    self.starSynth = snd.synth.new(snd.kWaveTriangle)
    self.starSynth:setADSR(0.0, 0.05, 0.2, 0.15)
    self.starSynth:setVolume(0.35)

    -- === CRANK WHOOSH SYNTH (noise tied to crank speed) ===
    self.whooshSynth = snd.synth.new(snd.kWaveNoise)
    self.whooshSynth:setADSR(0.02, 0.05, 0.8, 0.1)
    self.whooshSynth:setVolume(0.0)
    self.whooshPlaying = false
    self.whooshTargetVol = 0
    self.whooshCurrentVol = 0

    -- === GAME OVER SYNTH ===
    self.gameOverSynth = snd.synth.new(snd.kWaveSawtooth)
    self.gameOverSynth:setADSR(0.0, 0.3, 0.0, 0.3)
    self.gameOverSynth:setVolume(0.35)

    -- ===============================================
    -- MUSIC SYNTHS - High energy Geometry Dash style
    -- ===============================================

    -- Lead melody: bright square wave, punchy
    self.melodySynth = snd.synth.new(snd.kWaveSquare)
    self.melodySynth:setADSR(0.005, 0.08, 0.5, 0.05)
    self.melodySynth:setVolume(0.18)

    -- Arpeggio layer: fast triangle arpeggios
    self.arpSynth = snd.synth.new(snd.kWaveTriangle)
    self.arpSynth:setADSR(0.005, 0.04, 0.3, 0.03)
    self.arpSynth:setVolume(0.12)

    -- Bass: heavy sawtooth, driving 8th notes
    self.bassSynth = snd.synth.new(snd.kWaveSawtooth)
    self.bassSynth:setADSR(0.005, 0.1, 0.4, 0.05)
    self.bassSynth:setVolume(0.16)

    -- Sub bass: sine wave for low-end punch
    self.subBassSynth = snd.synth.new(snd.kWaveSine)
    self.subBassSynth:setADSR(0.005, 0.08, 0.3, 0.05)
    self.subBassSynth:setVolume(0.14)

    -- Kick drum: low sine burst
    self.kickSynth = snd.synth.new(snd.kWaveSine)
    self.kickSynth:setADSR(0.0, 0.06, 0.0, 0.04)
    self.kickSynth:setVolume(0.25)

    -- Snare: noise burst
    self.snareSynth = snd.synth.new(snd.kWaveNoise)
    self.snareSynth:setADSR(0.0, 0.03, 0.0, 0.03)
    self.snareSynth:setVolume(0.16)

    -- Hi-hat: high noise, very short
    self.hihatSynth = snd.synth.new(snd.kWaveNoise)
    self.hihatSynth:setADSR(0.0, 0.015, 0.0, 0.01)
    self.hihatSynth:setVolume(0.10)

    -- Music state
    self.musicPlaying = false
    self.musicBeat = 0
    self.musicTimer = 0
    self.bpm = 174  -- High energy tempo
    self.beatDuration = 60 / self.bpm * 30 -- frames per beat at 30fps

    -- Beat tracking for drum pattern
    self.beatCount = 0      -- counts quarter notes
    self.subBeatCount = 0   -- counts 8th notes within a beat

    -- Driving melody - energetic, Geometry Dash-inspired minor key riffs
    -- Fast 16th note patterns with octave jumps
    self.melodyPattern = {
        -- Phrase 1: Rising energy (E minor feel)
        {note = 76, dur = 0.08},  -- E5 (staccato)
        {note = 0,  dur = 0.04},
        {note = 76, dur = 0.08},  -- E5
        {note = 0,  dur = 0.04},
        {note = 79, dur = 0.08},  -- G5
        {note = 83, dur = 0.12},  -- B5
        {note = 0,  dur = 0.04},
        {note = 81, dur = 0.08},  -- A5
        {note = 79, dur = 0.08},  -- G5
        {note = 76, dur = 0.12},  -- E5
        {note = 0,  dur = 0.04},
        -- Phrase 2: Descending tension
        {note = 83, dur = 0.08},  -- B5
        {note = 81, dur = 0.08},  -- A5
        {note = 79, dur = 0.08},  -- G5
        {note = 76, dur = 0.08},  -- E5
        {note = 0,  dur = 0.04},
        {note = 74, dur = 0.08},  -- D5
        {note = 76, dur = 0.16},  -- E5 (hold)
        {note = 0,  dur = 0.04},
        -- Phrase 3: Aggressive push
        {note = 79, dur = 0.06},  -- G5
        {note = 79, dur = 0.06},  -- G5
        {note = 81, dur = 0.06},  -- A5
        {note = 83, dur = 0.12},  -- B5
        {note = 0,  dur = 0.04},
        {note = 88, dur = 0.08},  -- E6 (octave jump!)
        {note = 86, dur = 0.08},  -- D6
        {note = 83, dur = 0.12},  -- B5
        {note = 0,  dur = 0.04},
        -- Phrase 4: Resolution with flair
        {note = 81, dur = 0.08},  -- A5
        {note = 79, dur = 0.08},  -- G5
        {note = 0,  dur = 0.04},
        {note = 76, dur = 0.06},  -- E5
        {note = 79, dur = 0.06},  -- G5
        {note = 83, dur = 0.06},  -- B5
        {note = 88, dur = 0.16},  -- E6 (big finish)
        {note = 0,  dur = 0.06},
    }

    -- Fast arpeggio pattern - 16th note arpeggios cycling through chords
    self.arpPattern = {
        -- Em arpeggio
        {note = 64, dur = 0.06},  -- E4
        {note = 67, dur = 0.06},  -- G4
        {note = 71, dur = 0.06},  -- B4
        {note = 76, dur = 0.06},  -- E5
        {note = 71, dur = 0.06},  -- B4
        {note = 67, dur = 0.06},  -- G4
        -- C major arpeggio
        {note = 60, dur = 0.06},  -- C4
        {note = 64, dur = 0.06},  -- E4
        {note = 67, dur = 0.06},  -- G4
        {note = 72, dur = 0.06},  -- C5
        {note = 67, dur = 0.06},  -- G4
        {note = 64, dur = 0.06},  -- E4
        -- D major arpeggio
        {note = 62, dur = 0.06},  -- D4
        {note = 66, dur = 0.06},  -- F#4
        {note = 69, dur = 0.06},  -- A4
        {note = 74, dur = 0.06},  -- D5
        {note = 69, dur = 0.06},  -- A4
        {note = 66, dur = 0.06},  -- F#4
        -- B minor -> Em resolution
        {note = 59, dur = 0.06},  -- B3
        {note = 62, dur = 0.06},  -- D4
        {note = 66, dur = 0.06},  -- F#4
        {note = 71, dur = 0.06},  -- B4
        {note = 67, dur = 0.06},  -- G4
        {note = 64, dur = 0.06},  -- E4
    }

    -- Driving bass - 8th note pattern, heavy and relentless
    self.bassPattern = {
        -- Em
        {note = 40, dur = 0.10},  -- E2
        {note = 40, dur = 0.08},  -- E2
        {note = 0,  dur = 0.04},
        {note = 40, dur = 0.10},  -- E2
        {note = 52, dur = 0.08},  -- E3 (octave pop)
        {note = 0,  dur = 0.04},
        -- C
        {note = 36, dur = 0.10},  -- C2
        {note = 36, dur = 0.08},  -- C2
        {note = 0,  dur = 0.04},
        {note = 36, dur = 0.10},  -- C2
        {note = 48, dur = 0.08},  -- C3 (octave pop)
        {note = 0,  dur = 0.04},
        -- D
        {note = 38, dur = 0.10},  -- D2
        {note = 38, dur = 0.08},  -- D2
        {note = 0,  dur = 0.04},
        {note = 38, dur = 0.10},  -- D2
        {note = 50, dur = 0.08},  -- D3 (octave pop)
        {note = 0,  dur = 0.04},
        -- Bm -> Em
        {note = 35, dur = 0.10},  -- B1
        {note = 35, dur = 0.08},  -- B1
        {note = 0,  dur = 0.04},
        {note = 40, dur = 0.10},  -- E2
        {note = 52, dur = 0.08},  -- E3
        {note = 0,  dur = 0.04},
    }

    self.melodyIndex = 1
    self.bassIndex = 1
    self.arpIndex = 1
    self.melodyWait = 0
    self.bassWait = 0
    self.arpWait = 0
end

-- === SOUND EFFECTS ===

function SoundManager:playBlaster()
    self.blasterSynth:playMIDINote(80, 0.35, 0.08)
    playdate.timer.performAfterDelay(30, function()
        self.blasterSynth:playMIDINote(60, 0.25, 0.06)
    end)
end

function SoundManager:playHit()
    self.hitSynth:playMIDINote(40, 0.4, 0.12)
    self.hitToneSynth:playMIDINote(55, 0.3, 0.15)
end

function SoundManager:playJump()
    self.jumpSynth:playMIDINote(65, 0.3, 0.08)
    playdate.timer.performAfterDelay(40, function()
        self.jumpSynth:playMIDINote(72, 0.25, 0.08)
    end)
end

function SoundManager:playStar()
    self.starSynth:playMIDINote(76, 0.35, 0.1)
    playdate.timer.performAfterDelay(60, function()
        self.starSynth:playMIDINote(83, 0.3, 0.15)
    end)
end

function SoundManager:playGameOver()
    self.gameOverSynth:playMIDINote(60, 0.35, 0.2)
    playdate.timer.performAfterDelay(200, function()
        self.gameOverSynth:playMIDINote(55, 0.3, 0.2)
    end)
    playdate.timer.performAfterDelay(400, function()
        self.gameOverSynth:playMIDINote(48, 0.35, 0.4)
    end)
end

-- === CRANK WHOOSH ===

function SoundManager:updateWhoosh(crankChange)
    local absChange = math.abs(crankChange)

    if absChange > 1 then
        self.whooshTargetVol = math.min(0.15, absChange / 40)
        local freq = math.min(600, 150 + absChange * 8)
        self.whooshSynth:playNote(freq, self.whooshTargetVol, 0.05)
        self.whooshPlaying = true
    else
        self.whooshTargetVol = 0
    end

    self.whooshCurrentVol = self.whooshCurrentVol + (self.whooshTargetVol - self.whooshCurrentVol) * 0.3

    if self.whooshCurrentVol < 0.005 and self.whooshPlaying and self.whooshTargetVol == 0 then
        self.whooshSynth:stop()
        self.whooshPlaying = false
    end
end

-- === MUSIC ===

function SoundManager:startMusic()
    self.musicPlaying = true
    self.melodyIndex = 1
    self.bassIndex = 1
    self.arpIndex = 1
    self.melodyWait = 0
    self.bassWait = 0
    self.arpWait = 0
    self.musicTimer = 0
    self.beatCount = 0
    self.subBeatCount = 0
    self.musicBeat = 0
end

function SoundManager:stopMusic()
    self.musicPlaying = false
    self.melodySynth:stop()
    self.bassSynth:stop()
    self.arpSynth:stop()
    self.subBassSynth:stop()
end

function SoundManager:updateMusic(gameSpeed)
    if not self.musicPlaying then return end

    -- Tempo ramps up with speed (starts energetic, gets frantic)
    local tempoMult = 0.9 + gameSpeed * 0.25
    self.musicTimer = self.musicTimer + tempoMult

    -- === MELODY ===
    self.melodyWait = self.melodyWait - tempoMult
    if self.melodyWait <= 0 then
        local note = self.melodyPattern[self.melodyIndex]
        if note.note > 0 then
            -- Volume increases slightly with speed for intensity
            local vol = math.min(0.22, 0.16 + gameSpeed * 0.015)
            self.melodySynth:playMIDINote(note.note, vol, note.dur)
        end
        self.melodyWait = self.beatDuration * (note.dur / 0.12)
        self.melodyIndex = self.melodyIndex + 1
        if self.melodyIndex > #self.melodyPattern then
            self.melodyIndex = 1
        end
    end

    -- === ARPEGGIO ===
    self.arpWait = self.arpWait - tempoMult
    if self.arpWait <= 0 then
        local note = self.arpPattern[self.arpIndex]
        if note.note > 0 then
            local vol = math.min(0.14, 0.10 + gameSpeed * 0.01)
            self.arpSynth:playMIDINote(note.note, vol, note.dur)
        end
        self.arpWait = self.beatDuration * (note.dur / 0.12)
        self.arpIndex = self.arpIndex + 1
        if self.arpIndex > #self.arpPattern then
            self.arpIndex = 1
        end
    end

    -- === BASS ===
    self.bassWait = self.bassWait - tempoMult
    if self.bassWait <= 0 then
        local note = self.bassPattern[self.bassIndex]
        if note.note > 0 then
            local vol = math.min(0.20, 0.14 + gameSpeed * 0.015)
            self.bassSynth:playMIDINote(note.note, vol, note.dur)
            -- Sub bass layer on root notes for extra punch
            if note.note < 45 then
                self.subBassSynth:playMIDINote(note.note, vol * 0.7, note.dur)
            end
        end
        self.bassWait = self.beatDuration * (note.dur / 0.12)
        self.bassIndex = self.bassIndex + 1
        if self.bassIndex > #self.bassPattern then
            self.bassIndex = 1
        end
    end

    -- === DRUMS: Kick-Snare-HiHat pattern ===
    self.musicBeat = self.musicBeat + tempoMult

    -- 8th note grid
    local eighthNoteDur = self.beatDuration / 2

    if self.musicBeat >= eighthNoteDur then
        self.musicBeat = self.musicBeat - eighthNoteDur
        self.subBeatCount = self.subBeatCount + 1

        -- Pattern over 8 eighth notes (one bar of 4/4)
        local pos = self.subBeatCount % 8

        -- Kick: beats 1, 3, and the "and" of 4 for drive
        -- pos: 0=1, 1=1+, 2=2, 3=2+, 4=3, 5=3+, 6=4, 7=4+
        if pos == 0 or pos == 4 or pos == 7 then
            local kickVol = math.min(0.30, 0.22 + gameSpeed * 0.02)
            self.kickSynth:playMIDINote(36, kickVol, 0.06)
        end

        -- Snare: beats 2 and 4
        if pos == 2 or pos == 6 then
            local snareVol = math.min(0.20, 0.14 + gameSpeed * 0.015)
            self.snareSynth:playMIDINote(60, snareVol, 0.04)
        end

        -- Hi-hat: every 8th note for driving feel, accented on beats
        local hhVol = 0.08
        if pos % 2 == 0 then hhVol = 0.12 end  -- accent on beats
        hhVol = math.min(hhVol + gameSpeed * 0.01, 0.16)
        self.hihatSynth:playMIDINote(80, hhVol, 0.015)

        -- Extra: every other bar, add a snare fill on beat 4+
        if self.subBeatCount % 16 >= 14 then
            self.snareSynth:playMIDINote(64, 0.12, 0.025)
        end
    end
end

function SoundManager:cleanup()
    self:stopMusic()
    if self.whooshPlaying then
        self.whooshSynth:stop()
        self.whooshPlaying = false
    end
end
