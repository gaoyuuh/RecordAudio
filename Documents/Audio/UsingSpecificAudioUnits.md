每个iOS音频单元都有某些共同之处，也有一些独特之处。本文档的前几章描述了常见的方面，其中包括需要在运行时找到音频单元，实例化它，并确保其流格式被适当地设置。本章解释了音频单元之间的差异，并提供了如何使用它们的细节。

在后面的章节中，[Identifier Keys for Audio Units](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide_iOS/UsingSpecificAudioUnits/UsingSpecificAudioUnits.html#//apple_ref/doc/uid/TP40009492-CH17-SW14) 列出了你需要在运行时为每个音频单元找到动态链接库的代码。



## Using I/O Units

iOS提供了三个 I/O (输入/输出) 单元。绝大多数音频单元应用程序使用 `Remote I/O unit`，它连接到输入和输出音频硬件，并提供对单个传入和传出音频样本值的低延迟访问。对于VoIP应用程序，`Voice-Processing I/O unit` 通过添加回声消除和其他功能来扩展 Remote I/O单元。要将音频发送回应用程序而不是输出音频硬件，请使用 `Generic Output unit`

### Remote I/O Unit

Remote I/O 单元 (子类型 [kAudioUnitSubType_RemoteIO](https://developer.apple.com/documentation/audiotoolbox/1619485-anonymous/kaudiounitsubtype_remoteio)) 连接到设备硬件进行输入、输出或同时输入和输出。使用它回放，录音，或低延迟的同步输入和输出不需要回声消除。

设备的音频硬件将其音频流格式强加到 Reteme I/O 单元的外部，如[Understanding Where and How to Set Stream Formats](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide_iOS/AudioUnitHostingFundamentals/AudioUnitHostingFundamentals.html#//apple_ref/doc/uid/TP40009492-CH3-SW34)中所述。音频单元提供硬件音频格式和应用程序音频格式之间的格式转换，通过包含的格式转换器音频单元来实现。

有关演示如何使用此音频单元的示例代码，请参见示例代码项目 *[aurioTouch](https://developer.apple.com/library/archive/samplecode/aurioTouch/Introduction/Intro.html#//apple_ref/doc/uid/DTS40007770)*

本音频单元的使用说明如表3-1所示。

Table 3-1  Using the Remote I/O unit

| Audio unit feature                   | Details                                                      |
| :----------------------------------- | :----------------------------------------------------------- |
| Elements                             | 一个 input element: element 1. 一个 output element: element 0.<br>默认情况下，input element 是禁用的，output element 是启用的。如果需要更改此属性，请参考[kAudioOutputUnitProperty_EnableIO](https://developer.apple.com/documentation/audiotoolbox/1534116-i_o_audio_unit_properties/kaudiooutputunitproperty_enableio)属性的描述。 |
| Recommended stream format attributes | [kAudioFormatLinearPCM](https://developer.apple.com/documentation/coreaudiotypes/1572096-audio_data_format_identifiers/kaudioformatlinearpcm)<br/>[AudioUnitSampleType](https://developer.apple.com/documentation/coreaudiotypes/audiounitsampletype)<br/>[kAudioFormatFlagsAudioUnitCanonical](https://developer.apple.com/documentation/coreaudiotypes/1572098-audiostreambasicdescription_flag/kaudioformatflagsaudiounitcanonical?language=objc) |
| Stream format notes                  | Remote I/O单元的外部从音频硬件获取其格式如下:<br>1. input element (element 1) 的 input scope 从当前活动的音频输入硬件获得流格式。 <br>2. output element (element 0) 的 output scope 从当前激活的输出音频硬件获得流格式。<br>在 input element 的 output scope 上设置应用程序格式。input element 根据需要在其输入和输出范围之间执行格式转换。对应用程序流格式使用硬件采样率。<br>如果 output element 的输入范围是由音频单元连接提供的，则它从该连接获取其流格式。但是，如果它是由渲染回调函数提供的，那么就在它上面设置应用程序格式。 |
| Parameters                           | None in iOS.                                                 |
| Properties                           | 参考 `I/O Audio Unit Properties`.                            |
| Property notes                       | 你永远不需要在这个音频单元上设置 [kAudioUnitProperty_MaximumFramesPerSlice](https://developer.apple.com/documentation/audiotoolbox/1534199-generic_audio_unit_properties/kaudiounitproperty_maximumframesperslice) 属性 |



### Voice-Processing I/O Unit

Voice-Processing I/O unit (子类型 [kAudioUnitSubType_VoiceProcessingIO](https://developer.apple.com/documentation/audiotoolbox/1584139-input_output_audio_unit_subtypes/kaudiounitsubtype_voiceprocessingio)) 具有 Remote I/O单元的特性，并为双向双工通信增加了回波抑制。它还增加了自动增益校正、语音处理质量调整和静音功能。这是用于VoIP (Voice over Internet Protocol)应用程序的正确I/O单元。

表3-1中列出的所有考虑事项也适用于 Voice-Processing I/O unit。此外，在 `Voice-Processing I/O Audio Unit Properties` 中描述了该音频单元可用的特定属性



### Generic Output Unit

当将audio processing graph的输出发送到应用程序而不是输出音频硬件时，使用子类型[kAudioUnitSubType_GenericOutput](https://developer.apple.com/documentation/audiotoolbox/1584139-input_output_audio_unit_subtypes/kaudiounitsubtype_genericoutput) 的音频单元。您通常会使用Generic Output单元进行脱机音频处理。就像其他I/O单元一样，通用输出单元集成了格式转换器单元。这允许Generic Output单元在 audio processing graph 中使用的流格式和您想要的格式之间执行格式转换。



## Using Mixer Units

iOS提供了两个 mixer 单元。在大多数情况下，您应该使用 Multichannel Mixer单元，它为任何数量的单声道或立体声流提供混合。如果你需要3D Mixer单元的功能，你很可能会使用OpenAL来代替。OpenAL是建立在3D Mixer单元之上的，通过一个非常适合游戏应用开发的更简单的API提供同等的性能。

### Multichannel Mixer Unit (多通道混合单元)

Multichannel Mixer unit (子类型 [kAudioUnitSubType_MultiChannelMixer](https://developer.apple.com/documentation/audiotoolbox/kaudiounitsubtype_multichannelmixer) ) 接受任意数量的单声道或立体声流，并将它们合并成一个单一的立体声输出。它控制音频增益为每个输入和输出，并让您打开或关闭每个输入单独。从iOS 4.0开始，Multichannel Mixer支持立体声平移每个输入。

有关演示如何使用此音频单元的示例代码，请参见示例代码项目audio Mixer (MixerHost)。

本音频单元的使用说明如表3-2所示。

Table 3-2  Using the Multichannel Mixer unit

| Audio unit feature                   | Details                                                      |
| :----------------------------------- | :----------------------------------------------------------- |
| Elements                             | 一个或多个 input element ，每一个都可以是单声道的或立体声的。一个立体声 output element |
| Recommended stream format attributes | [kAudioFormatLinearPCM](https://developer.apple.com/documentation/coreaudiotypes/1572096-audio_data_format_identifiers/kaudioformatlinearpcm)<br/>[AudioUnitSampleType](https://developer.apple.com/documentation/coreaudiotypes/audiounitsampletype)<br/>[kAudioFormatFlagsAudioUnitCanonical](https://developer.apple.com/documentation/coreaudiotypes/1572098-audiostreambasicdescription_flag/kaudioformatflagsaudiounitcanonical?language=objc) |
| Stream format notes                  | 在 inout scope 上，按如下方式管理流格式:<br>1. 如果 input bus 是由音频单元连接提供的，它就从该连接获得流格式。<br>2. 如果 input bus 是由回调函数提供的，请在bus上设置完整的应用程序流格式。使用与回调提供的数据相同的流格式。<br>在 output scope 中，只设置应用程序采样率 |
| Parameters                           | 参考 `Multichannel Mixer Unit Parameters`.                   |
| Properties                           | [kAudioUnitProperty_MeteringMode](https://developer.apple.com/documentation/audiotoolbox/1534041-mixer_audio_unit_properties/kaudiounitproperty_meteringmode) |
| Property notes                       | 默认情况下，[kAudioUnitProperty_MaximumFramesPerSlice](https://developer.apple.com/documentation/audiotoolbox/1534199-generic_audio_unit_properties/kaudiounitproperty_maximumframesperslice) 属性被设置为1024，当屏幕锁定和显示休眠时，这个值是不够的。如果你的应用程序在屏幕锁定的情况下播放音频，你必须增加这个属性的值，除非音频输入是激活的。执行如下操作:<br>1. 如果音频输入是活动的，你不需要为 kAudioUnitProperty_MaximumFramesPerSlice 属性设置一个值。<br>如果音频输入未激活，将此属性设置为4096。 |



## Using Effect Units

iPodEQ单元 (子类型 [kAudioUnitSubType_AUiPodEQ](https://developer.apple.com/documentation/audiotoolbox/kaudiounitsubtype_auipodeq)) 是iOS 4中唯一提供的效果单元。这是相同的均衡器使用内置的iPod应用程序。要查看iPod应用程序的用户界面为这个音频单元，去设置> iPod > EQ。这个音频单元提供了一套预设均衡曲线，如Bass Booster, Pop，和Spoken Word。

你必须提供自己的用户界面iPod EQ单元，因为你必须为任何音频单元。 *[Mixer iPodEQ AUGraph Test](https://developer.apple.com/library/archive/samplecode/iPhoneMixerEQGraphTest/Introduction/Intro.html#//apple_ref/doc/uid/DTS40009555)* 示例代码项目演示了如何使用iPodEQ单元，并展示了一种为它提供用户界面的方法。

本音频单元的使用说明如表3-4所示。

Table 3-4  Using the iPod EQ unit

| Audio unit feature                   | Details                                                      |
| :----------------------------------- | :----------------------------------------------------------- |
| Elements                             | 一个单声道或立体声 input element。一个单声道或立体声  output element |
| Recommended stream format attributes | 1. [kAudioFormatLinearPCM](https://developer.apple.com/documentation/coreaudio/1572096-audio_data_format_identifiers/kaudioformatlinearpcm)<br>2. [AudioUnitSampleType](https://developer.apple.com/documentation/coreaudio/audiounitsampletype)<br>3. [kAudioFormatFlagsAudioUnitCanonical](https://developer.apple.com/documentation/coreaudio/kaudioformatflagsaudiounitcanonical) |
| Stream format notes                  | 在 input scope 上，按照以下方式管理流格式:<br>1. 如果输入是由音频单元连接提供的，它从该连接获取流格式。<br>2. 如果输入是由回调函数提供的，请在总线上设置完整的应用程序流格式。使用与回调提供的数据相同的流格式。<br>在 output scope 上，设置与输入相同的完整流格式 |
| Parameters                           | None.                                                        |
| Properties                           | [kAudioUnitProperty_FactoryPresets](https://developer.apple.com/documentation/audiotoolbox/1534199-generic_audio_unit_properties/kaudiounitproperty_factorypresets) 和 [kAudioUnitProperty_PresentPreset](https://developer.apple.com/documentation/audiotoolbox/kaudiounitproperty_presentpreset) |
| Property notes                       | iPod EQ单元提供了一套预先设定的音调均衡曲线作为工厂预设。通过访问音频单元的' kAudioUnitProperty_FactoryPresets '属性获得可用的EQ设置数组。然后你可以通过将它作为' kAudioUnitProperty_PresentPreset '属性的值来应用一个设置。默认情况下，' kAudioUnitProperty_MaximumFramesPerSlice '属性被设置为1024，当屏幕锁定和显示休眠时，这个值是不够的。如果你的应用程序在屏幕锁定的情况下播放音频，你必须增加这个属性的值，除非音频输入是激活的。执行如下操作:如果音频输入是活动的，你不需要为' kAudioUnitProperty_MaximumFramesPerSlice '属性设置一个值。如果音频输入未激活，将此属性设置为4096。 |



## Identifier Keys for Audio Units

这个表提供了您需要访问每个iOS音频单元的动态链接库的标识符键，以及音频单元的简要描述。

Table 3-5  Identifier keys for accessing the dynamically-linkable libraries for each iOS audio unit

| Name and description                                         | Identifier keys                                              | Corresponding four-char codes |
| :----------------------------------------------------------- | :----------------------------------------------------------- | :---------------------------- |
| *Converter unit*Supports audio format conversions to or from linear PCM. | `kAudioUnitType_FormatConverter`<br>`kAudioUnitSubType_AUConverter`<br>`kAudioUnitManufacturer_Apple` | `aufc`<br>`conv`<br>`appl`    |
| *iPod Equalizer unit*Provides the features of the iPod equalizer. | `kAudioUnitType_Effect`<br>`kAudioUnitSubType_AUiPodEQ`<br>`kAudioUnitManufacturer_Apple` | `aufx`<br>`ipeq`<br>`appl`    |
| *3D Mixer unit*Supports mixing multiple audio streams, output panning, sample rate conversion, and more. | `kAudioUnitType_Mixer`<br>`kAudioUnitSubType_AU3DMixerEmbedded`<br>`kAudioUnitManufacturer_Apple` | `aumx`<br>`3dem`<br>`appl`    |
| *Multichannel Mixer unit*Supports mixing multiple audio streams to a single stream. | `kAudioUnitType_Mixer`<br>`kAudioUnitSubType_MultiChannelMixer`<br>`kAudioUnitManufacturer_Apple` | `aumx`<br>`mcmx`<br>`appl`    |
| *Generic Output unit*Supports converting to and from linear PCM format; can be used to start and stop a graph. | `kAudioUnitType_Output`<br>`kAudioUnitSubType_GenericOutput`<br>`kAudioUnitManufacturer_Apple` | `auou`<br/>`genr`<br/>`appl`  |
| *Remote I/O unit*Connects to device hardware for input, output, or simultaneous input and output. | `kAudioUnitType_Output`<br>`kAudioUnitSubType_RemoteIO`<br>`kAudioUnitManufacturer_Apple` | `auou`<br/>`rioc`<br/>`appl`  |
| *Voice Processing I/O unit*Has the characteristics of the I/O unit and adds echo suppression for two-way communication. | `kAudioUnitType_Output`<br>`kAudioUnitSubType_VoiceProcessingIO`<br>`kAudioUnitManufacturer_Apple` | `auou`<br/>`vpio`<br/>`appl`  |



[Using Specific Audio Units](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitHostingGuide_iOS/UsingSpecificAudioUnits/UsingSpecificAudioUnits.html#//apple_ref/doc/uid/TP40009492-CH17-SW14)

