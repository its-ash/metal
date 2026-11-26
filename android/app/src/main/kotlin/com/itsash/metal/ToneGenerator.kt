package com.itsash.metal

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlin.math.PI
import kotlin.math.sin

/**
 * Plays a generated sine tone. Dart decides what to play (see
 * `lib/core/tone_mapping.dart`); this class only synthesises it.
 *
 * `set(freqHz, periodMs)`: pitch, and the beep period (0 = continuous). A beep
 * is on for about 45% of its period, with a short fade to avoid clicks.
 */
class ToneGenerator {
    @Volatile private var freq = 0.0
    @Volatile private var periodMs = 0
    @Volatile private var generation = 0
    private val lock = Any()

    fun set(freqHz: Double, period: Int) {
        freq = freqHz
        periodMs = period
        synchronized(lock) {
            if (!running()) start()
        }
    }

    fun stop() {
        synchronized(lock) { generation++ }
    }

    private var activeGen = -1

    private fun running() = activeGen == generation

    private fun start() {
        generation++
        val gen = generation
        activeGen = gen
        Thread {
            val minBuf = AudioTrack.getMinBufferSize(
                SAMPLE_RATE, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
            )
            val chunk = SAMPLE_RATE / 50 // 20 ms
            val track = try {
                AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(SAMPLE_RATE)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build(),
                    )
                    .setBufferSizeInBytes(maxOf(minBuf, chunk * 2 * 2))
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            } catch (e: Exception) {
                synchronized(lock) { if (activeGen == gen) activeGen = -1 }
                return@Thread
            }
            val buffer = ShortArray(chunk)
            var phase = 0.0
            var gain = 0.0
            var sampleClock = 0L
            try {
                track.play()
                while (generation == gen) {
                    val f = freq
                    val period = periodMs
                    val periodSamples = period * SAMPLE_RATE / 1000
                    val onSamples = (periodSamples * 0.45).toLong()
                    val step = 2 * PI * f / SAMPLE_RATE
                    for (i in buffer.indices) {
                        val on = if (period <= 0) true else (sampleClock % periodSamples) < onSamples
                        val target = if (on && f > 0) 1.0 else 0.0
                        // ~4 ms fade
                        gain += (target - gain) * 0.01
                        phase += step
                        if (phase > 2 * PI) phase -= 2 * PI
                        buffer[i] = (sin(phase) * gain * 0.6 * Short.MAX_VALUE).toInt().toShort()
                        sampleClock++
                    }
                    track.write(buffer, 0, buffer.size)
                }
            } finally {
                runCatching { track.stop() }
                track.release()
                synchronized(lock) { if (activeGen == gen) activeGen = -1 }
            }
        }.also { it.name = "metal-tone"; it.start() }
    }

    private companion object {
        const val SAMPLE_RATE = 22050
    }
}
