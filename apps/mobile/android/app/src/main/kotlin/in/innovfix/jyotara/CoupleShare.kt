package `in`.innovfix.jyotara

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Exports only the rendered card, using a temporary, read-only content URI. */
class CoupleShare(private val activity: Activity, messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private var busy = false
    init {
        MethodChannel(messenger, "jyotara/couple-share").setMethodCallHandler { call, result ->
            if (call.method != "share") { result.notImplemented(); return@setMethodCallHandler }
            val frames = call.argument<List<ByteArray>>("frames")
            val animated = call.argument<Boolean>("animated") == true
            val target = call.argument<String>("target")
            if (busy || frames == null || frames.size !in 1..48 || frames.any { it.size > 4_000_000 }) {
                result.error("invalid_export", "Please retry your share.", null); return@setMethodCallHandler
            }
            busy = true
            worker.execute {
                var file: File? = null
                try {
                    val folder = File(activity.cacheDir, "couple").apply { mkdirs() }
                    folder.listFiles()?.filter { it.lastModified() < System.currentTimeMillis() - 86400000 }?.forEach { it.delete() }
                    file = File(folder, "Jyotara-${UUID.randomUUID()}.${if (animated) "mp4" else "png"}")
                    if (animated) encode(frames, file) else file.writeBytes(frames.first())
                    val completed = file
                    activity.runOnUiThread {
                        busy = false
                        try {
                            if (activity.isFinishing || activity.isDestroyed) { result.error("closed", "Screen closed.", null); return@runOnUiThread }
                            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.couple-files", completed)
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = if (animated) "video/mp4" else "image/png"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                clipData = ClipData.newRawUri("Jyotara card", uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            if (target in listOf("com.whatsapp", "com.instagram.android")) {
                                intent.setPackage(target)
                                if (intent.resolveActivity(activity.packageManager) == null) intent.setPackage(null)
                            }
                            activity.startActivity(Intent.createChooser(intent, "Share your Jyotara card"))
                            result.success(null)
                        } catch (_: Exception) { result.error("share_failed", "Could not open sharing.", null) }
                    }
                } catch (_: Exception) {
                    file?.delete()
                    activity.runOnUiThread { busy = false; result.error("export_failed", "Could not prepare this card.", null) }
                }
            }
        }
    }

    private fun encode(frames: List<ByteArray>, file: File) {
        val width = 720
        val first = BitmapFactory.decodeByteArray(frames.first(), 0, frames.first().size) ?: error("Invalid image")
        val height = ((width * first.height / first.width + 15) / 16 * 16).coerceIn(480, 1600)
        first.recycle()
        val mime = "video/avc"
        val candidates = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.filter { it.isEncoder && it.supportedTypes.contains(mime) }
        val choice = candidates.sortedBy { if (it.name.contains("android") || it.name.contains("google")) 0 else 1 }.firstOrNull {
            val caps = it.getCapabilitiesForType(mime)
            caps.videoCapabilities.isSizeSupported(width, height) && caps.colorFormats.any { c -> c == 19 || c == 21 }
        } ?: error("Encoder unavailable")
        val color = if (choice.getCapabilitiesForType(mime).colorFormats.contains(19)) 19 else 21
        val codec = MediaCodec.createByCodecName(choice.name)
        val muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var started = false
        var track = -1
        try {
            val format = MediaFormat.createVideoFormat(mime, width, height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, color)
                setInteger(MediaFormat.KEY_BIT_RATE, 3_500_000)
                setInteger(MediaFormat.KEY_FRAME_RATE, 8)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            }
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            val info = MediaCodec.BufferInfo()
            var index = 0
            var eosInput = false
            var done = false
            val deadline = System.currentTimeMillis() + 60000
            while (!done && System.currentTimeMillis() < deadline) {
                if (!eosInput) {
                    val slot = codec.dequeueInputBuffer(10000)
                    if (slot >= 0) {
                        if (index < frames.size) {
                            val bytes = frames[index]
                            val original = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: error("Invalid frame")
                            val bitmap = Bitmap.createScaledBitmap(original, width, height, true)
                            val data = yuv(bitmap, width, height, color == 21)
                            if (bitmap !== original) bitmap.recycle()
                            original.recycle()
                            codec.getInputBuffer(slot)!!.apply { clear(); put(data) }
                            codec.queueInputBuffer(slot, 0, data.size, index * 125000L, 0)
                            index++
                        } else {
                            codec.queueInputBuffer(slot, 0, 0, index * 125000L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            eosInput = true
                        }
                    }
                }
                var output = codec.dequeueOutputBuffer(info, 10000)
                while (output != MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (output == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        check(!started)
                        track = muxer.addTrack(codec.outputFormat); muxer.start(); started = true
                    } else if (output >= 0) {
                        if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                            check(started)
                            val buffer = codec.getOutputBuffer(output)!!
                            buffer.position(info.offset); buffer.limit(info.offset + info.size)
                            muxer.writeSampleData(track, buffer, info)
                        }
                        done = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        codec.releaseOutputBuffer(output, false)
                        if (done) break
                    }
                    output = codec.dequeueOutputBuffer(info, 0)
                }
            }
            check(done && started)
        } finally {
            try { codec.stop() } catch (_: Exception) {}
            codec.release()
            try { if (started) muxer.stop() } finally { muxer.release() }
        }
    }

    private fun yuv(bitmap: Bitmap, width: Int, height: Int, semi: Boolean): ByteArray {
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        val count = width * height
        val out = ByteArray(count * 3 / 2)
        var uv = count
        var u = count
        var v = count + count / 4
        for (y in 0 until height) for (x in 0 until width) {
            val c = pixels[y * width + x]
            val r = c shr 16 and 255; val g = c shr 8 and 255; val b = c and 255
            out[y * width + x] = (((66*r + 129*g + 25*b + 128) shr 8) + 16).coerceIn(0,255).toByte()
            if (y % 2 == 0 && x % 2 == 0) {
                val cb = (((-38*r - 74*g + 112*b + 128) shr 8) + 128).coerceIn(0,255).toByte()
                val cr = (((112*r - 94*g - 18*b + 128) shr 8) + 128).coerceIn(0,255).toByte()
                if (semi) { out[uv++] = cb; out[uv++] = cr } else { out[u++] = cb; out[v++] = cr }
            }
        }
        return out
    }
}
