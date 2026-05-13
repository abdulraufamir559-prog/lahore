--[[
  @name: Google Gemini text to audio generator
  @author: Abdul Rauf Amir
  @version: 2.0
  @description: Final Advanced TTS with Auto-Close & Crash Fix
]]

require "import"
import "com.androlua.Http"
import "cjson"
import "com.androlua.LuaDialog"
import "android.widget.*"
import "android.view.*"
import "android.content.Context"
import "android.content.Intent"
import "android.net.Uri"
import "android.media.MediaPlayer"
import "android.util.Base64"
import "android.os.*"
import "android.graphics.Typeface"
import "java.io.*"
import "android.text.InputFilter"

local context = activity or service
local mainHandler = Handler(Looper.getMainLooper())
local CHAR_LIMIT = 10000

local VOICE_LIST = {"Puck", "Kore", "Charon", "Zephyr", "Fenrir", "Leda", "Orus", "Aoede", "Callirrhoe", "Autonoe", "Enceladus", "Iapetus", "Umbriel", "Algieba", "Despina", "Erinome", "Algenib", "Rasalgethi", "Laomedeia", "Achernar", "Alnilam", "Schedar", "Gacrux", "Pulcherrima"}
local EMOTIONS = {"Natural/Neutral", "Very Happy & Energetic", "Sad & Emotional", "Angry & Loud", "Serious & Professional", "Whispering/Secretive", "Excited/Cheer", "Surprised/Shocked", "Tired/Sleepy", "Shy/Romantic", "Heroic/Epic", "Sarcastic/Funny", "Mysterious/Dark"}

local googleApiKey = ""
local generatedAudioPath = nil
local mediaPlayer = nil
local mainDlg = nil

local PREFS_NAME = "Gemini_TTS_Abdul_Rauf"
local prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

-- [Helper Functions]
function fixSymbols(text)
    if not text then return "" end
    local fixedText = text
    fixedText = fixedText:gsub("⭐", " star verified ")
    fixedText = fixedText:gsub("💎", " jam stone ")
    fixedText = fixedText:gsub("vs", " versus ")
    fixedText = fixedText:gsub("/", " out of ")
    return fixedText
end

function loadSettings() googleApiKey = prefs.getString("apikey", "") end
function saveSettings() local editor = prefs.edit(); editor.putString("apikey", googleApiKey); editor.apply() end

-- [Audio Generation Logic]
function generateAudio(text, voice, apikey, emotion, generateBtn, playBtn, pauseBtn, resultLayout)
    local cleanText = fixSymbols(text)
    local prompts = { ["Very Happy & Energetic"] = "Joyful energy: ", ["Sad & Emotional"] = "Deeply sad: ", ["Angry & Loud"] = "Intense anger: ", ["Serious & Professional"] = "Professional: ", ["Whispering/Secretive"] = "Whisper: ", ["Excited/Cheer"] = "Excited: ", ["Surprised/Shocked"] = "Shocked: ", ["Tired/Sleepy"] = "Tired: ", ["Shy/Romantic"] = "Romantic: ", ["Heroic/Epic"] = "Heroic: ", ["Sarcastic/Funny"] = "Sarcastic: ", ["Mysterious/Dark"] = "Mysterious: " }
    local finalPrompt = (prompts[emotion] or "Natural: ") .. cleanText
    
    local apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=" .. apikey
    local body = { contents = {{ parts = {{ text = finalPrompt }} }}, generationConfig = { responseModalities = {"AUDIO"}, speechConfig = { voiceConfig = { prebuiltVoiceConfig = { voiceName = voice } } } } }
    
    Http.post(apiUrl, cjson.encode(body), {["Content-Type"]="application/json"}, function(code, content)
        if code == 200 then
            local ok, data = pcall(cjson.decode, content)
            if ok and data and data.candidates and data.candidates[1] and data.candidates[1].content and data.candidates[1].content.parts and data.candidates[1].content.parts[1].inlineData then
                local b64 = data.candidates[1].content.parts[1].inlineData.data
                local bytes = Base64.decode(b64, Base64.NO_WRAP)
                local tempPath = context.getCacheDir().getPath() .. "/tts_temp.wav"
                local fos = FileOutputStream(File(tempPath))
                
                local sampleRate, channels, bitsPerSample = 24000, 1, 16
                local byteRate = sampleRate * channels * (bitsPerSample / 8)
                local blockAlign = channels * (bitsPerSample / 8)
                local totalDataLen = #bytes
                local totalSize = totalDataLen + 36
                local function getBytes(val) return {val & 0xff, (val >> 8) & 0xff, (val >> 16) & 0xff, (val >> 24) & 0xff} end
                local tsB, srB, brB, dlB = getBytes(totalSize), getBytes(sampleRate), getBytes(byteRate), getBytes(totalDataLen)
                local h = {0x52, 0x49, 0x46, 0x46, tsB[1], tsB[2], tsB[3], tsB[4], 0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, channels & 0xff, (channels >> 8) & 0xff, srB[1], srB[2], srB[3], srB[4], brB[1], brB[2], brB[3], brB[4], blockAlign & 0xff, (blockAlign >> 8) & 0xff, bitsPerSample & 0xff, (bitsPerSample >> 8) & 0xff, 0x64, 0x61, 0x74, 0x61, dlB[1], dlB[2], dlB[3], dlB[4]}
                for i = 1, #h do fos.write(h[i]) end
                fos.write(bytes)
                fos.close()
                
                generatedAudioPath = tempPath
                mainHandler.post(Runnable({run=function()
                    resultLayout.setVisibility(View.VISIBLE)
                    playBtn.setEnabled(true)
                    generateBtn.setText("REGENERATE")
                    generateBtn.setEnabled(true)
                    Toast.makeText(context, "Audio Successfully Generated!", 0).show()
                end}))
            else
                mainHandler.post(Runnable({run=function()
                    generateBtn.setEnabled(true); generateBtn.setText("GENERATE")
                    Toast.makeText(context, "API did not return audio. Check Key.", 1).show()
                end}))
            end
        else
            mainHandler.post(Runnable({run=function()
                generateBtn.setEnabled(true); generateBtn.setText("GENERATE")
                Toast.makeText(context, "Error: " .. tostring(code), 0).show()
            end}))
        end
    end)
end

function showAboutMenu()
    local v = {}
    local layout = {LinearLayout, orientation="vertical", padding="20dp", 
        {TextView, text="Abdul Rauf Amir", textSize=22, textColor="#2E7D32", gravity="center", typeface=Typeface.DEFAULT_BOLD},
        {TextView, text="About & Support", textSize=16, textColor="#607D8B", gravity="center", layout_marginBottom="20dp"},
        {Button, id="apiBtn", text="API SETTINGS", layout_width="fill", layout_marginTop="5dp"}, 
        {Button, id="waBtn", text="JOIN MY WHATSAPP GROUP", layout_width="fill", backgroundColor="#25D366", textColor="#FFFFFF", layout_marginTop="15dp"},
        {Button, id="fbBtn", text="SEND FEEDBACK TO DEVELOPER", layout_width="fill", backgroundColor="#2196F3", textColor="#FFFFFF", layout_marginTop="15dp"}
    }
    local aboutDlg = LuaDialog(context).setView(loadlayout(layout, v))
    
    v.apiBtn.onClick = function()
        local sv = {}
        local sl = {LinearLayout, orientation="vertical", padding="20dp", 
            {TextView, text="API Settings", textSize=16, layout_marginBottom="10dp"},
            {EditText, id="apiInput", hint="Paste Google API Key here", layout_width="fill"}, 
            {Button, id="saveBtn", text="SAVE KEY", layout_width="fill", layout_marginTop="10dp"}}
        local sd = LuaDialog(context).setView(loadlayout(sl, sv))
        sv.apiInput.setText(googleApiKey)
        sv.saveBtn.onClick = function() 
            googleApiKey = sv.apiInput.getText().toString()
            saveSettings()
            Toast.makeText(context, "API Key Saved!", 0).show()
            sd.dismiss() 
        end
        sd.show()
    end
    
    v.waBtn.onClick = function()
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://chat.whatsapp.com/B4ptEIk0G5oDpajoujjlZs")))
        aboutDlg.dismiss()
        if mainDlg then mainDlg.dismiss() end
    end
    
    v.fbBtn.onClick = function()
        local feedbackMsg = "Hello Abdul Rauf Amir, I am absolutely impressed with this Google Gemini TTS Generator!"
        local url = "https://api.whatsapp.com/send?phone=923234391100&text=" .. Uri.encode(feedbackMsg)
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        aboutDlg.dismiss()
        if mainDlg then mainDlg.dismiss() end
    end
    
    aboutDlg.show()
end

function showMain()
    loadSettings()
    local views = {}
    local layout = { ScrollView, layout_width="fill", { LinearLayout, orientation="vertical", padding="20dp", 
        {TextView, text="Google Gemini TTS", textSize=20, textColor="#2E7D32", gravity="center", typeface=Typeface.DEFAULT_BOLD, layout_marginTop="10dp"}, 
        {TextView, text="Developed by Abdul Rauf Amir", gravity="center", paddingBottom="15dp"}, 
        {EditText, id="textInput", hint="Enter text or scorecard...", layout_height="120dp", layout_width="fill", gravity=Gravity.TOP, backgroundColor="#F5F5F5", padding="10dp"}, 
        {TextView, text="Emotion:", layout_marginTop="10dp"}, {Spinner, id="emotionSpin", layout_width="fill"}, 
        {TextView, text="Voice:", layout_marginTop="5dp"}, {Spinner, id="voiceSpin", layout_width="fill"}, 
        {Button, id="generateBtn", text="GENERATE AUDIO", layout_width="fill", layout_marginTop="15dp", backgroundColor="#2196F3", textColor="#FFFFFF"}, 
        {LinearLayout, id="resultLayout", visibility=View.GONE, layout_marginTop="10dp", 
            {Button, id="playBtn", text="PLAY", layout_weight=1, backgroundColor="#4CAF50", textColor="#FFFFFF"}, 
            {Button, id="pauseBtn", text="PAUSE", layout_weight=1, backgroundColor="#9E9E9E", textColor="#FFFFFF"}, 
            {Button, id="downloadBtn", text="DOWNLOAD", layout_weight=1.5, backgroundColor="#FF9800", textColor="#FFFFFF"}}, 
        {Button, id="aboutBtn", text="ABOUT & SUPPORT", layout_width="fill", layout_marginTop="20dp", backgroundColor="#607D8B", textColor="#FFFFFF"},
        {Button, id="exitBtn", text="EXIT", layout_width="fill", backgroundColor="#D32F2F", textColor="#FFFFFF", layout_marginTop="10dp"} } }
    
    mainDlg = LuaDialog(context).setView(loadlayout(layout, views))
    
    views.textInput.setFilters({InputFilter.LengthFilter(CHAR_LIMIT)})
    views.emotionSpin.setAdapter(ArrayAdapter(context, android.R.layout.simple_spinner_item, EMOTIONS))
    views.voiceSpin.setAdapter(ArrayAdapter(context, android.R.layout.simple_spinner_item, VOICE_LIST))
    
    views.generateBtn.onClick = function()
        local txt = views.textInput.getText().toString()
        if txt == "" or googleApiKey == "" then Toast.makeText(context, "Missing API Key or Text!", 0).show() return end
        views.generateBtn.setText("Processing..."); views.generateBtn.setEnabled(false)
        generateAudio(txt, VOICE_LIST[views.voiceSpin.getSelectedItemPosition()+1], googleApiKey, EMOTIONS[views.emotionSpin.getSelectedItemPosition()+1], views.generateBtn, views.playBtn, views.pauseBtn, views.resultLayout)
    end
    
    views.playBtn.onClick = function()
        if mediaPlayer then mediaPlayer.release() end
        mediaPlayer = MediaPlayer(); mediaPlayer.setDataSource(generatedAudioPath); mediaPlayer.prepare(); mediaPlayer.start()
        views.playBtn.setEnabled(false); views.pauseBtn.setEnabled(true)
    end
    
    views.pauseBtn.onClick = function()
        if mediaPlayer and mediaPlayer.isPlaying() then mediaPlayer.pause(); views.playBtn.setEnabled(true); views.pauseBtn.setEnabled(false) end
    end
    
    views.downloadBtn.onClick = function()
        if not generatedAudioPath then return end
        local downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        local fileName = "Gemini_TTS_" .. os.date("%Y%m%d_%H%M%S") .. ".wav"
        local destFile = File(downloadDir, fileName)
        local source = File(generatedAudioPath)
        local input = FileInputStream(source); local output = FileOutputStream(destFile)
        local buffer = byte[4096]; local len = input.read(buffer)
        while len > 0 do output.write(buffer, 0, len); len = input.read(buffer) end
        input.close(); output.close()
        Toast.makeText(context, "Saved to Downloads", 1).show()
    end
    
    views.aboutBtn.onClick = function() showAboutMenu() end
    views.exitBtn.onClick = function() if mediaPlayer then mediaPlayer.release() end; mainDlg.dismiss() end
    
    mainDlg.show()
end

showMain()