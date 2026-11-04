package com.couple.couple_locator

import android.opengl.EGL14
import android.opengl.EGLConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "couple/gl")
            .setMethodCallHandler { call, result ->
                if (call.method == "eglOk") result.success(checkEgl()) else result.notImplemented()
            }
    }

    /**
     * 地图渲染预检：用和 GLSurfaceView 默认一致的配置（RGB888 + 16 位深度 + OpenGL ES 2.0）
     * 试着创建一次 EGL 上下文。部分模拟器选不到配置（createContext failed: 12288），
     * 此时高德地图 SDK 会在原生层崩溃，所以提前探测并让 Dart 端降级。
     */
    private fun checkEgl(): Boolean {
        return try {
            val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (display == EGL14.EGL_NO_DISPLAY) return false
            val ver = IntArray(2)
            if (!EGL14.eglInitialize(display, ver, 0, ver, 1)) return false
            val attrs = intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_DEPTH_SIZE, 16,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_NONE
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val num = IntArray(1)
            val ok = EGL14.eglChooseConfig(display, attrs, 0, configs, 0, 1, num, 0)
            if (!ok || num[0] < 1 || configs[0] == null) {
                EGL14.eglTerminate(display)
                return false
            }
            val ctx = EGL14.eglCreateContext(
                display, configs[0], EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0
            )
            val good = ctx != EGL14.EGL_NO_CONTEXT
            if (good) EGL14.eglDestroyContext(display, ctx)
            EGL14.eglTerminate(display)
            good
        } catch (e: Throwable) {
            false
        }
    }
}
