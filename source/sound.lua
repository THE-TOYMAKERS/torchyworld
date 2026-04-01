-- Sound module for Chrono Break
-- SFX generated via Playdate's synthesizer API
-- Background music: torchyworld.wav with dynamic tempo scaling

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

    -- === DEATH SYNTH (Pokemon-style descending faint) ===
    self.deathSynth = snd.synth.new(snd.kWaveSquare)
    self.deathSynth:setADSR(0.005, 0.15, 0.3, 0.1)
    self.deathSynth:setVolume(0.3)

    -- === BOOT-UP / JINGLE SYNTHS ===
    self.jingleSynth = snd.synth.new(snd.kWaveTriangle)
    self.jingleSynth:setADSR(0.01, 0.1, 0.4, 0.2)
    self.jingleSynth:setVolume(0.3)

    self.jingleBassSynth = snd.synth.new(snd.kWaveSine)
    self.jingleBassSynth:setADSR(0.01, 0.15, 0.3, 0.2)
    self.jingleBassSynth:setVolume(0.2)

    -- ===============================================
    -- BACKGROUND MUSIC - WAV file with dynamic tempo
    -- ===============================================

    -- Load background music WAV via fileplayer
    self.bgmPlayer = snd.fileplayer.new("torchyworld")
    self.musicPlaying = false
    self.baseBPM = 80  -- Natural tempo of the WAV file
    self.currentRate = 1.0

    -- Load intro music WAV for menu screen
    self.introPlayer = snd.fileplayer.new("intromusic")
    self.introPlaying = false
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

-- === INTRO MUSIC (menu screen) ===

function SoundManager:startIntroMusic()
    if self.introPlaying then return end
    self.introPlayer:setVolume(0)
    self.introPlayer:play(0)  -- 0 = loop forever
    self.introPlaying = true
    -- Fade in over ~1 second
    self.introFadeTarget = 1.0
    self.introFadeVol = 0
end

function SoundManager:stopIntroMusic()
    if not self.introPlaying then return end
    self.introPlayer:stop()
    self.introPlaying = false
end

function SoundManager:updateIntroMusic()
    if not self.introPlaying then return end
    if self.introFadeVol < self.introFadeTarget then
        self.introFadeVol = math.min(self.introFadeTarget, self.introFadeVol + 0.03)
        self.introPlayer:setVolume(self.introFadeVol)
    end
end

-- === GAMEPLAY MUSIC ===

function SoundManager:startMusic()
    self.musicPlaying = true
    self.currentRate = 1.0
    self.bgmPlayer:setRate(self.currentRate)
    self.bgmPlayer:play(0)  -- 0 = loop forever
end

function SoundManager:stopMusic()
    self.musicPlaying = false
    self.bgmPlayer:stop()
end

function SoundManager:updateMusic(gameSpeed)
    if not self.musicPlaying then return end

    -- Scale playback rate with game speed
    -- At gameSpeed 1.0: rate 1.0 (80 BPM)
    -- At gameSpeed 4.0: rate 1.75 (140 BPM)
    local targetRate = 0.75 + gameSpeed * 0.25
    -- Smooth transition to avoid jarring speed changes
    self.currentRate = self.currentRate + (targetRate - self.currentRate) * 0.1
    self.bgmPlayer:setRate(self.currentRate)
end

-- === DEATH SOUND (Pokemon-style descending notes) ===

function SoundManager:playDeath()
    -- Descending whole-tone run: B4 -> A4 -> G4 -> E4 -> D4 -> low C4
    self.deathSynth:playMIDINote(71, 0.35, 0.15)  -- B4
    playdate.timer.performAfterDelay(120, function()
        self.deathSynth:playMIDINote(69, 0.32, 0.15) -- A4
    end)
    playdate.timer.performAfterDelay(240, function()
        self.deathSynth:playMIDINote(67, 0.30, 0.15) -- G4
    end)
    playdate.timer.performAfterDelay(360, function()
        self.deathSynth:playMIDINote(64, 0.28, 0.18) -- E4
    end)
    playdate.timer.performAfterDelay(500, function()
        self.deathSynth:playMIDINote(62, 0.25, 0.2)  -- D4
    end)
    playdate.timer.performAfterDelay(660, function()
        self.deathSynth:playMIDINote(60, 0.30, 0.4)  -- C4 (long final)
    end)
end

-- === BOOT-UP JINGLE (plays on splash/menu load) ===

function SoundManager:playBootJingle()
    -- Bright ascending chime: C5 -> E5 -> G5 -> C6 with bass
    self.jingleBassSynth:playMIDINote(48, 0.25, 0.4) -- C3 bass
    self.jingleSynth:playMIDINote(72, 0.30, 0.12) -- C5
    playdate.timer.performAfterDelay(100, function()
        self.jingleSynth:playMIDINote(76, 0.30, 0.12) -- E5
    end)
    playdate.timer.performAfterDelay(200, function()
        self.jingleSynth:playMIDINote(79, 0.30, 0.12) -- G5
    end)
    playdate.timer.performAfterDelay(350, function()
        self.jingleSynth:playMIDINote(84, 0.35, 0.3) -- C6 (bright finish)
        self.jingleBassSynth:playMIDINote(60, 0.20, 0.3) -- C4 bass resolve
    end)
end

-- === MENU ARRIVAL SOUND (when transitioning to main menu) ===

function SoundManager:playMenuArrive()
    -- Quick two-note confirm: G5 -> C6
    self.jingleSynth:playMIDINote(79, 0.25, 0.1) -- G5
    playdate.timer.performAfterDelay(80, function()
        self.jingleSynth:playMIDINote(84, 0.30, 0.2) -- C6
    end)
end

function SoundManager:cleanup()
    self:stopMusic()
    self:stopIntroMusic()
    if self.whooshPlaying then
        self.whooshSynth:stop()
        self.whooshPlaying = false
    end
end

function SoundManager:setMusicVolume(vol)
    self.bgmPlayer:setVolume(vol)
end
