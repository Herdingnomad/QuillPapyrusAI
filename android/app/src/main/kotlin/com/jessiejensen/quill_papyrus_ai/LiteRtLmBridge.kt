package com.jessiejensen.quill_papyrus_ai

import android.content.Context
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.SamplerConfig
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Native Android LiteRT-LM bridge supporting explicit maxNumTokens (4K/8K/16K KV cache),
 * visionBackend, and audioBackend directly on Google's litertlm-android SDK.
 */
class LiteRtLmBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.jessiejensen.quill_papyrus_ai/litert_lm"
        const val EVENT_CHANNEL = "com.jessiejensen.quill_papyrus_ai/litert_lm_stream"
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val engines = ConcurrentHashMap<String, Engine>()
    private val conversations = ConcurrentHashMap<String, Conversation>()
    private val conversationEngineMap = ConcurrentHashMap<String, String>()
    private var eventSink: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createEngine" -> handleCreateEngine(call, result)
            "disposeEngine" -> handleDisposeEngine(call, result)
            "createConversation" -> handleCreateConversation(call, result)
            "disposeConversation" -> handleDisposeConversation(call, result)
            "sendMessage" -> handleSendMessage(call, result)
            "startMessageStream" -> handleStartMessageStream(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleCreateEngine(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val modelPath = call.argument<String>("modelPath")!!
                val backendName = call.argument<String>("backend") ?: "gpu"
                val visionBackendName = call.argument<String>("visionBackend")
                val audioBackendName = call.argument<String>("audioBackend")
                val maxNumTokens = call.argument<Number>("maxNumTokens")?.toInt()
                val cacheDir = call.argument<String>("cacheDir")

                val engineConfig = EngineConfig(
                    modelPath = modelPath,
                    backend = parseBackend(backendName),
                    visionBackend = visionBackendName?.let { parseBackend(it) },
                    audioBackend = audioBackendName?.let { parseBackend(it) },
                    maxNumTokens = maxNumTokens,
                    cacheDir = cacheDir ?: context.cacheDir.absolutePath,
                )

                val engine = Engine(engineConfig)
                engine.initialize()

                val engineId = UUID.randomUUID().toString()
                engines[engineId] = engine

                withContext(Dispatchers.Main) {
                    result.success(engineId)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("ENGINE_ERROR", e.message ?: e.toString(), e.stackTraceToString())
                }
            }
        }
    }

    private fun handleDisposeEngine(call: MethodCall, result: MethodChannel.Result) {
        val engineId = call.argument<String>("engineId") ?: ""
        conversationEngineMap.entries
            .filter { it.value == engineId }
            .forEach { (convId, _) ->
                try {
                    conversations.remove(convId)?.close()
                } catch (_: Exception) {}
                conversationEngineMap.remove(convId)
            }
        try {
            engines.remove(engineId)?.close()
        } catch (_: Exception) {}
        result.success(null)
    }

    private fun handleCreateConversation(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val engineId = call.argument<String>("engineId")!!
                val engine = engines[engineId]
                    ?: throw IllegalStateException("Engine not found: $engineId")
                @Suppress("UNCHECKED_CAST")
                val configMap = call.argument<Map<String, Any>>("config")

                val conversation = if (configMap != null) {
                    engine.createConversation(parseConversationConfig(configMap))
                } else {
                    engine.createConversation()
                }

                val convId = UUID.randomUUID().toString()
                conversations[convId] = conversation
                conversationEngineMap[convId] = engineId

                withContext(Dispatchers.Main) {
                    result.success(convId)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("CONVERSATION_ERROR", e.message ?: e.toString(), e.stackTraceToString())
                }
            }
        }
    }

    private fun handleDisposeConversation(call: MethodCall, result: MethodChannel.Result) {
        val convId = call.argument<String>("conversationId") ?: ""
        try {
            conversations.remove(convId)?.close()
        } catch (_: Exception) {}
        conversationEngineMap.remove(convId)
        result.success(null)
    }

    private fun handleSendMessage(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val convId = call.argument<String>("conversationId")!!
                @Suppress("UNCHECKED_CAST")
                val contentsList = call.argument<List<Map<String, Any>>>("contents")!!
                val conversation = conversations[convId]
                    ?: throw IllegalStateException("Conversation not found: $convId")

                val contents = parseContents(contentsList)
                val response = conversation.sendMessage(contents)
                val text = extractText(response)

                withContext(Dispatchers.Main) {
                    result.success(mapOf("text" to text))
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("MESSAGE_ERROR", e.message ?: e.toString(), e.stackTraceToString())
                }
            }
        }
    }

    private fun handleStartMessageStream(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val convId = call.argument<String>("conversationId")!!
                @Suppress("UNCHECKED_CAST")
                val contentsList = call.argument<List<Map<String, Any>>>("contents")!!
                val conversation = conversations[convId]
                    ?: throw IllegalStateException("Conversation not found: $convId")

                val contents = parseContents(contentsList)
                val flow = conversation.sendMessageAsync(contents)

                withContext(Dispatchers.Main) {
                    result.success(null)
                }

                flow.collect { message: Message ->
                    val text = extractText(message)
                    withContext(Dispatchers.Main) {
                        eventSink?.success(
                            mapOf(
                                "conversationId" to convId,
                                "text" to text,
                                "done" to false,
                            )
                        )
                    }
                }

                withContext(Dispatchers.Main) {
                    eventSink?.success(
                        mapOf(
                            "conversationId" to convId,
                            "text" to "",
                            "done" to true,
                        )
                    )
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    eventSink?.error("STREAM_ERROR", e.message ?: e.toString(), null)
                }
            }
        }
    }

    private fun parseBackend(name: String): Backend = when (name.lowercase()) {
        "gpu" -> Backend.GPU()
        "npu" -> Backend.NPU(context.applicationInfo.nativeLibraryDir)
        else -> Backend.CPU()
    }

    @Suppress("UNCHECKED_CAST")
    private fun parseConversationConfig(map: Map<String, Any>): ConversationConfig {
        val systemInstruction = map["systemInstruction"] as? String
        val samplerMap = map["samplerConfig"] as? Map<String, Any>
        val initialMsgsList = map["initialMessages"] as? List<Map<String, Any>>

        var config = ConversationConfig()
        if (!systemInstruction.isNullOrEmpty()) {
            config = config.copy(systemInstruction = Contents.of(systemInstruction))
        }
        if (!initialMsgsList.isNullOrEmpty()) {
            val msgs = initialMsgsList.map { msgMap ->
                val role = msgMap["role"] as? String ?: "user"
                val text = msgMap["text"] as? String ?: ""
                if (role == "model") Message.model(text) else Message.user(text)
            }
            config = config.copy(initialMessages = msgs)
        }
        if (samplerMap != null) {
            config = config.copy(
                samplerConfig = SamplerConfig(
                    topK = (samplerMap["topK"] as? Number)?.toInt() ?: 40,
                    topP = (samplerMap["topP"] as? Number)?.toDouble() ?: 0.95,
                    temperature = (samplerMap["temperature"] as? Number)?.toDouble() ?: 0.7,
                )
            )
        }
        return config
    }

    private fun parseContents(contentsList: List<Map<String, Any>>): Contents {
        val parts = mutableListOf<Content>()
        for (content in contentsList) {
            when (content["type"]) {
                "text" -> parts.add(Content.Text(content["text"] as String))
                "imageFile" -> parts.add(Content.ImageFile(content["path"] as String))
                "audioFile" -> parts.add(Content.AudioFile(content["path"] as String))
            }
        }
        return Contents.of(parts)
    }

    private fun extractText(message: Message): String {
        return message.contents.contents
            .filterIsInstance<Content.Text>()
            .joinToString("") { it.text }
    }

    fun dispose() {
        conversations.values.forEach { try { it.close() } catch (_: Exception) {} }
        conversations.clear()
        engines.values.forEach { try { it.close() } catch (_: Exception) {} }
        engines.clear()
        scope.cancel()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
