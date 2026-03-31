-- Sound module for Torchy's World
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

    -- ===============================================
    -- BACKGROUND MUSIC - WAV file with dynamic tempo
    -- ===============================================

    -- Load background music WAV via fileplayer
    self.bgmPlayer = snd.fileplayer.new("torchyworld")
    self.musicPlaying = false
    self.baseBPM = 80  -- Natural tempo of the WAV file
    self.currentRate = 1.0
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

function SoundManager:cleanup()
    self:stopMusic()
    if self.whooshPlaying then
        self.whooshSynth:stop()
        self.whooshPlaying = false
    end
end

function SoundManager:setMusicVolume(vol)
    self.bgmPlayer:setVolume(vol)
end
