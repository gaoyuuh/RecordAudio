# SpeakHere


SpeakHere给出了关于AudioQueue Services, Audio File Services, 以及 AudioSession Services在录音和播放过程中的具体用法.

具体使用是使用场景:

* The code in SpeakHere uses Audio File Services to create, record into, and read from a CAF (Core Audio Format) audio file containing uncompressed (PCM) audio data. 
*  The application uses Audio Queue Services to manage recording and playback.
*  The application also uses Audio Session Services to manage interruptions and audio hardware route changes (as described in Core Audio Overview).

简而言之,Audio File Services读写CAF文件(内部是PCM data),Audio Queue Services用来录音和播放,Audio Session Services监听打断录音或播放的事件.

### 关于测试
在AQRecorder.mm代码中的SetupAudioFormat参数用来修改录音的格式.

如果需要测试AudioSession Service相关功能:

* To test the application's interruption behavior, place a phone call to the device during recording or playback; then choose to ignore the phone call.
* To test the application's audio hardware route change behavior, plug in or unplug a headset while playing back or recording.

### 具体实现的功能

* Set up a linear PCM audio format.设置成LPCM音频格式数据
* Set up a compressed audio format.设置成系统中支持的压缩的音频数据
* Create a Core Audio Format (CAF) audio file and save it to an application's Documents directory.创建和保存CAF文件
* Reuse an existing CAF file by overwriting it.
* Read from a CAF file for playback.从CAF文件中读取音频数据然后播放
* Create and use recording (input) and playback (output) audio queue objects.创建audioQueue(录音和播放)
* Define and use audio data and property data callbacks with audio queue objects.通过audioQueue 的callback获取录音或播放的音频数据
* Set playback gain for an audio queue object.播放增强
* Stop recording in a way ensures that all audio data gets written to disk. 停止录音时候,确保所有的audio data已经写入文件系统
* Stop playback when a sound file has finished playing.
* Stop playback immediately when a user invokes a Stop method.
* Enable audio level metering in an audio queue object.
* Get average and peak audio levels from a running audio queue object. 获取平均和峰值音量
* Use audio format magic cookies with an audio queue object.获取audioQueue对象的幻数
* Use OpenGL to indicate average and peak recording and playback level.使用OpenGL绘制平均和峰值音量
* Use Audio Session Services to register an interruption callback. 
* Use Audio Session Services to register property listener callback.
* Use Audio Session Services to set appropriate audio session categories for recording and playback.
* Use Audio Session Services to pause playback upon receiving an interruption, and to then resume playback if the interruption ends.
* Use UIBarButtonItem objects as toggle buttons.

### 注意iOS默认支持的audio Formats

* linear PCM
* ALAC (Apple Lossless)
* IMA4 (IMA/ADPCM)
* iLBC
* µLaw
* aLaw

因此如果需要保存成其他的音频格式,需要自己使用LPCM,然后封装成其他的音频格式,例如使用Speex压缩,Ogg封装,进行语音传递.
