package com.itsash.metal

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel

/**
 * Streams the magnetic field in µT as `[x, y, z, accuracy, uncalibrated]`.
 *
 * Prefers `TYPE_MAGNETIC_FIELD_UNCALIBRATED`: it has no hard-iron correction
 * applied, so the OS cannot "absorb" a nearby piece of iron into its
 * calibration. Falls back to the calibrated sensor (`uncalibrated` = 0).
 * Samples at 100 Hz (10 ms), the fastest rate allowed without the
 * HIGH_SAMPLING_RATE_SENSORS permission.
 */
class MagnetStreamHandler(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var sink: EventChannel.EventSink? = null
    private var uncalibrated = false
    // Android reports accuracy only when it changes, so assume high until told otherwise.
    private var accuracy = SensorManager.SENSOR_STATUS_ACCURACY_HIGH

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val raw = manager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED)
        val sensor = raw ?: manager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        if (sensor == null) {
            events.error("no_sensor", "This device has no magnetometer.", null)
            events.endOfStream()
            return
        }
        uncalibrated = raw != null
        accuracy = SensorManager.SENSOR_STATUS_ACCURACY_HIGH
        sink = events
        val ok = try {
            manager.registerListener(this, sensor, SAMPLING_US)
        } catch (e: SecurityException) {
            manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
        }
        if (!ok) {
            sink = null
            events.error("no_sensor", "The magnetometer could not be started.", null)
            events.endOfStream()
        }
    }

    override fun onCancel(arguments: Any?) {
        manager.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val v = event.values
        sink?.success(
            listOf(v[0].toDouble(), v[1].toDouble(), v[2].toDouble(), accuracy, if (uncalibrated) 1 else 0),
        )
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
        this.accuracy = accuracy
    }

    private companion object {
        const val SAMPLING_US = 10_000
    }
}
