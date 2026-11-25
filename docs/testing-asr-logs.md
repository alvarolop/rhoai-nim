# Testing ASR Logs

## Deploy


```bash
❯ ./auto-install.sh 

====================
FEATURE TOGGLES & CONFIG:
 * INSTALL_NIM_PLATFORM: true
 * INSTALL_NIM_MODELS: true
 * NIM_NAMESPACE: rhoai-nim-models
====================

✅ Check. You are correctly logged in. Continue...

🟩 ======================
🟩 =   NIM platform     =
🟩 ======================

🚀 Trigger the ArgoCD application of the NIM platform (Account and NGC secrets, namespace rhoai-nim-models)
application.argoproj.io/nim-platform configured
⏳ Waiting until the application nim-platform is Synced and Healthy

🧠 ======================
🧠 =      NIM models     =
🧠 ======================

🚀 Trigger the ArgoCD application of the model nemotron-asr-streaming
application.argoproj.io/nim-nemotron-asr-streaming created
🎊 That's all!! NIM should be ready to serve models!! :)
```

## Autotesting

```bash
❯ ./test-asr.sh 

🩺 === Check 1: is the NIM ready? ===
✅ GET /v1/health/ready returned 200

🎤 === Preparing the client and the audio ===
Audio: /tmp/test-asr/en-US_sample.wav

📋 === Check 2: which models does the server offer? (gRPC) ===
Available ASR models
{'bg-BG,cs-CZ,da-DK,de-DE,el-GR,et-EE,fi-FI,fr-FR,hu-HU,hr-HR,it-IT,lt-LT,lv-LV,mt-MT,nl-NL,pl-PL,pt-BR,ro-RO,ru-RU,sk-SK,sl-SI,sv-SE,uk-UA,ar-AR,en-GB,en-US,es-ES,es-US,fr-CA,he-IL,hi-IN,ja-JP,ko-KR,nb-NO,nn-NO,pt-PT,th-TH,tr-TR,zh-CN,vi-VN,auto': [{'model': ['cache-aware-parakeet-rnnt-multi-asr-streaming-sortformer']}]}

📝 === Check 3: transcribe the audio, streamed in chunks (gRPC) ===
## What is natural language processing?

🎉 Done. If you saw a sentence above, the ASR NIM works.
```

## Live testing

```bash
❯ ./test-asr-live.sh 
🎤 === Preparing the client ===

🗣️  === Speak now. The text appears while you talk. Stop with Ctrl+C ===

ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.rear
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.center_lfe
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.side
ALSA lib confmisc.c:1377:(snd_func_refer) [error.core] Unable to find definition 'cards.0.pcm.hdmi.0:CARD=0,AES0=4,AES1=130,AES2=0,AES3=2'
ALSA lib conf.c:5211:(_snd_config_evaluate) [error.core] function snd_func_refer returned error: No such file or directory
ALSA lib conf.c:5734:(snd_config_expand) [error.core] Evaluate error: No such file or directory
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM hdmi
ALSA lib confmisc.c:1377:(snd_func_refer) [error.core] Unable to find definition 'cards.0.pcm.hdmi.0:CARD=0,AES0=4,AES1=130,AES2=0,AES3=2'
ALSA lib conf.c:5211:(_snd_config_evaluate) [error.core] function snd_func_refer returned error: No such file or directory
ALSA lib conf.c:5734:(snd_config_expand) [error.core] Evaluate error: No such file or directory
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM hdmi
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.modem
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.modem
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.phoneline
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.phoneline
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.rear
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.center_lfe
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.side
ALSA lib confmisc.c:1377:(snd_func_refer) [error.core] Unable to find definition 'cards.0.pcm.hdmi.0:CARD=0,AES0=4,AES1=130,AES2=0,AES3=2'
ALSA lib conf.c:5211:(_snd_config_evaluate) [error.core] function snd_func_refer returned error: No such file or directory
ALSA lib conf.c:5734:(snd_config_expand) [error.core] Evaluate error: No such file or directory
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM hdmi
ALSA lib confmisc.c:1377:(snd_func_refer) [error.core] Unable to find definition 'cards.0.pcm.hdmi.0:CARD=0,AES0=4,AES1=130,AES2=0,AES3=2'
ALSA lib conf.c:5211:(_snd_config_evaluate) [error.core] function snd_func_refer returned error: No such file or directory
ALSA lib conf.c:5734:(snd_config_expand) [error.core] Evaluate error: No such file or directory
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM hdmi
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.modem
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.modem
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.phoneline
ALSA lib pcm.c:2722:(snd_pcm_open_noupdate) [error.pcm] Unknown PCM cards.pcm.phoneline
## Cuántos años tienes? Que जस्ता की, mira, y entonces estoy aquí hablando   
##  y mira cómo aparecen las palabritas.   
##  Mira,  
##  todo lo que digo se transcribe y esto es se está ejecutando en un modelo   
##  de. transcripción de no sé qué, no sé dónde. pero mira, si pego un golpe.   
##  no lo transcribe.  
##  sin online altra trabajo, vuelvo a cuando estaba   
##  चलिए।    
## Just took.  
##  paragar esto porque si no.   
## s tapadías puestas.   
##  Voil   
## à.   
Error: Stream removed (Socket closed)
```




