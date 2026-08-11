package es.uva.gsic.momoest

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

/**
 * Guarda ficheros en la carpeta de Descargas del dispositivo.
 *
 * Se usa MediaStore en lugar de la galeria: escribir en el carrete obliga a
 * pedir un permiso de fotografias que el alumnado percibe como invasivo y que
 * la aplicacion no necesita para nada mas. A partir de Android 10 (API 29)
 * MediaStore.Downloads no requiere ningun permiso.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CANAL = "es.uva.gsic.momoest/descargas"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "guardarEnDescargas" -> guardarEnDescargas(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun guardarEnDescargas(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Antes de Android 10 no hay MediaStore.Downloads y escribir en la
            // carpeta publica exigiria WRITE_EXTERNAL_STORAGE. Se devuelve null
            // para que el cliente ofrezca la hoja de compartir.
            result.success(null)
            return
        }
        val bytes = call.argument<ByteArray>("bytes")
        val nombre = call.argument<String>("nombre")
        val mime = call.argument<String>("mime") ?: "application/octet-stream"
        if (bytes == null || nombre.isNullOrBlank()) {
            result.error("argumentos", "Faltan los bytes o el nombre del fichero", null)
            return
        }
        try {
            result.success(escribirEnDescargas(bytes, nombre, mime))
        } catch (error: Exception) {
            result.error("guardado", error.message, null)
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun escribirEnDescargas(bytes: ByteArray, nombre: String, mime: String): String {
        val valores = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, nombre)
            put(MediaStore.Downloads.MIME_TYPE, mime)
            // Mientras esta pendiente el fichero no es visible para el resto
            // del sistema, de modo que nadie lo lee a medio escribir.
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val resolver = applicationContext.contentResolver
        // MediaStore resuelve por si mismo las colisiones de nombre anadiendo
        // un sufijo, asi que no hace falta comprobarlas aqui.
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, valores)
            ?: throw IOException("MediaStore no ha devuelto ninguna URI")
        try {
            val salida = resolver.openOutputStream(uri)
                ?: throw IOException("No se ha podido abrir $uri para escritura")
            salida.use { it.write(bytes) }
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
        valores.clear()
        valores.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, valores, null, null)
        return uri.toString()
    }
}
