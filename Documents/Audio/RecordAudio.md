当使用 Audio Queue Services 进行录音时，目标可以是任何东西—磁盘上的文件、网络连接、内存中的对象等等。本章描述了最常见的场景：基础录音到磁盘文件

要想在程序中实现录音功能，通常需要执行以下步骤：

1. 定义一个自定义结构体来管理状态、格式和路径信息
2. 写一个音频队列回调函数来执行实际的录制
3. 可以选择编写代码来确定音频队列缓冲区的合适大小。如果您要以使用cookie的格式进行记录，那么请编写使用magic cookie的代码
4. 填充自定义结构体的字段。包括了指定音频队列发送到它要录制的文件的数据流，以及该文件的路径
5. 创建一个录音音频队列，并要求它创建一组音频队列缓冲区。还要创建一个要录音的文件
6. 告诉音频队列开始录音
7. 完成后，告诉音频队列停止，然后释放它。音频队列会释放它的缓冲区



## Define a Custom Structure to Manage State

想要使用Audio Queue Services实现录音功能，首先需要定义一个自定义结构体，使用这个结构体来管理音频格式和音频队列状态信息

```c
static const int kNumberBuffers = 3;                            // 1
struct AQRecorderState {
    AudioStreamBasicDescription  mDataFormat;                   // 2
    AudioQueueRef                mQueue;                        // 3
    AudioQueueBufferRef          mBuffers[kNumberBuffers];      // 4
    AudioFileID                  mAudioFile;                    // 5
    UInt32                       bufferByteSize;                // 6
    SInt64                       mCurrentPacket;                // 7
    bool                         mIsRunning;                    // 8
};
```

1. 设置音频队列缓冲区的数量

2. AudioStreamBasicDescription 结构体 （CoreAudioBaseTypes.h），表示要写入磁盘的音频数据格式。该格式由mQueue字段中指定的音频队列使用。
   mDataFormat 字段最初由程序中的代码设置，参见[Set Up an Audio Format for Recording](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW4)。通过查询音频队列的 kAudioQueueProperty_StreamDescription 属性来更新这个字段的值是一个很好的实践，参见 [Getting the Full Audio Format from an Audio Queue](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW23)

   关于 AudioStreamBasicDescription 结构体的详细信息，参见*[Core Audio Data Types Reference](https://developer.apple.com/documentation/coreaudio/core_audio_data_types)*

3. 由应用程序创建的录音音频队列

4. 数组，其中包含指向由音频队列管理的音频队列缓冲区的指针

5. 一个音频文件对象，表示程序记录音频数据的文件

6. 每个音频队列缓冲区的大小（以字节为单位）。在创建音频队列之后和启动音频队列之前，在 DeriveBufferSize 函数中计算该值。参见[Write a Function to Derive Recording Audio Queue Buffer Size](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW14)

7. 要从当前音频队列缓冲区写入的第一个包的包索引

8. 记录音频队列是否在运行



## Write a Recording Audio Queue Callback

接下来，要写一个录音音频队列的回调函数。这个回调函数主要做两件事:

- 将新填充的音频队列缓冲区的内容写入正在录制的音频文件
- 将音频队列缓冲区（其内容刚刚写入磁盘）排队到缓冲队列

### The Recording Audio Queue Callback Declaration

下面展示了一个录音音频队列回调函数的示例声明，在AudioQueue.h头文件中声明为AudioQueueInputCallback

``` c
static void HandleInputBuffer (
    void                                *aqData,             // 1
    AudioQueueRef                       inAQ,                // 2
    AudioQueueBufferRef                 inBuffer,            // 3
    const AudioTimeStamp                *inStartTime,        // 4
    UInt32                              inNumPackets,        // 5
    const AudioStreamPacketDescription  *inPacketDesc        // 6
)
```

1. 通常，aqData 是一个包含音频队列状态数据的自定义结构体，见上一部分所述
2. 拥有这个回调函数的音频队列
3. 音频队列缓冲区，包含要录制的传入音频数据
4. 音频队列缓冲区中第一个样本的采样时间（简单录音不需要）
5. inPacketDesc 参数中报文描述的个数。0表示CBR数据
6. 对于需要包描述的压缩音频数据格式，由编码器为缓冲区中的包产生的包描述。

### Writing an Audio Queue Buffer to Disk

录音音频队列回调的第一个任务是将音频队列缓冲区写入磁盘。这个缓冲区是回调的音频队列刚刚用来自输入设备的新音频数据填充的缓冲区。使用AudioFile.h头文件中的 AudioFileWritePackets 函数写入文件

``` c
AudioFileWritePackets (                     // 1
    pAqData->mAudioFile,                    // 2
    false,                                  // 3
    inBuffer->mAudioDataByteSize,           // 4
    inPacketDesc,                           // 5
    pAqData->mCurrentPacket,                // 6
    &inNumPackets,                          // 7
    inBuffer->mAudioData                    // 8
);
```

1. AudioFileWritePackets 函数在头文件AudioFile.h中声明，它将缓冲区的内容写入音频数据文件中
2. 音频文件对象（AudioFileID类型）表示要写入的音频文件
3. 使用false值表示函数在写数据时不应该缓存数据
4. 正在写入的音频数据的字节数。inBuffer变量表示音频队列传递给回调的音频队列缓冲区
5. 音频数据的数据包描述数组。NULL表示不需要数据包描述(如CBR音频数据)
6. 要写入的第一个包的包索引
7. 在输入时，要写入的数据包数。在输出中，实际写入的包数
8. 写入音频文件的新音频数据

### Enqueuing an Audio Queue Buffer

现在音频队列缓冲区中的音频数据已经写入音频文件，回调将对缓冲区重新进行排队。一旦回到缓冲队列，缓冲就在队列中并准备接收新传入的音频数据

``` c
AudioQueueEnqueueBuffer (                    // 1
    pAqData->mQueue,                         // 2
    inBuffer,                                // 3
    0,                                       // 4
    NULL                                     // 5
);
```

1. AudioQueueEnqueueBuffer 函数将音频队列缓冲区添加到音频队列的缓冲队列中
2. 要向其中添加音频缓冲区的音频队列
3. 用于排队的音频队列缓冲区
4. 音频队列缓冲区数据中的包描述数。设置为0，因为该参数不用于录音
5. 描述音频队列缓冲区数据的数据包描述数组。设置为NULL，因为该参数不用于录音

### A Full Recording Audio Queue Callback

``` c
static void HandleInputBuffer (
    void                                 *aqData,
    AudioQueueRef                        inAQ,
    AudioQueueBufferRef                  inBuffer,
    const AudioTimeStamp                 *inStartTime,
    UInt32                               inNumPackets,
    const AudioStreamPacketDescription   *inPacketDesc
) {
    AQRecorderState *pAqData = (AQRecorderState *) aqData;               // 1
 
    if (inNumPackets == 0 &&                                             // 2
          pAqData->mDataFormat.mBytesPerPacket != 0)
       inNumPackets =
           inBuffer->mAudioDataByteSize / pAqData->mDataFormat.mBytesPerPacket;
 
    if (AudioFileWritePackets (                                          // 3
            pAqData->mAudioFile,
            false,
            inBuffer->mAudioDataByteSize,
            inPacketDesc,
            pAqData->mCurrentPacket,
            &inNumPackets,
            inBuffer->mAudioData
        ) == noErr) {
            pAqData->mCurrentPacket += inNumPackets;                     // 4
    }
   if (pAqData->mIsRunning == 0)                                         // 5
      return;
 
    AudioQueueEnqueueBuffer (                                            // 6
        pAqData->mQueue,
        inBuffer,
        0,
        NULL
    );
}
```

1. 初始化时传入的自定义结构体
2. 如果音频队列缓冲区包含CBR数据，计算缓冲区中的包数。这个数字=缓冲区中数据的总字节数/每个包的(常量)字节数。对于VBR数据，音频队列在调用回调时提供缓冲区中的包数。
3. 将缓冲区的内容写入音频数据文件
4. 如果成功写入音频数据，则增加音频数据文件的包索引，为写入下一个缓冲区的音频数据做好准备
5. 如果音频队列已停止，则返回
6. 将刚刚把内容写入文件中的音频缓冲区放入音频队列中排队



## Write a Function to Derive Recording Audio Queue Buffer Size

Audio Queue Services希望你的应用程序为你使用的音频队列缓冲区指定大小。

这里的计算考虑到您录制的音频数据格式。格式包括可能影响缓冲区大小的所有因素，例如音频通道的数量。

``` c
void DeriveBufferSize (
    AudioQueueRef                audioQueue,                  // 1
    AudioStreamBasicDescription  &ASBDescription,             // 2
    Float64                      seconds,                     // 3
    UInt32                       *outBufferSize               // 4
) {
    static const int maxBufferSize = 0x50000;                 // 5
 
    int maxPacketSize = ASBDescription.mBytesPerPacket;       // 6
    if (maxPacketSize == 0) {                                 // 7
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty (
                audioQueue,
                kAudioQueueProperty_MaximumOutputPacketSize,
                // in Mac OS X v10.5, instead use
                //   kAudioConverterPropertyMaximumOutputPacketSize
                &maxPacketSize,
                &maxVBRPacketSize
        );
    }
 
    Float64 numBytesForTime =
        ASBDescription.mSampleRate * maxPacketSize * seconds; // 8
    *outBufferSize =
    UInt32 (numBytesForTime < maxBufferSize ?
        numBytesForTime : maxBufferSize);                     // 9
}
```

1. 要指定大小缓冲区所在的音频队列

2. 音频队列的AudioStreamBasicDescription结构体

3. 您为每个音频队列缓冲区指定的大小，以音频秒数为单位

4. 在输出时，每个音频队列缓冲区的大小，以字节为单位

5. 音频队列缓冲区大小的上限，以字节为单位。在本例中，上限设置为320kb。（0x50000转为十进制=327680 / 1024 = 320kb）这相当于大约5秒的立体声，24位音频的采样率为96 kHz

6. 对于CBR音频数据，从AudioStreamBasicDescription结构体获取(常量)数据包大小。使用此值作为最大数据包大小。
   这种分配的副作用是决定要记录的音频数据是CBR还是VBR。如果是VBR，音频队列的AudioStreamBasicDescription结构将每包字节数的值列为0

7. 对于VBR音频数据，查询音频队列获得估算的最大包大小

8. 导出缓冲区大小，以字节为单位

9. 根据计算设置缓冲区大小，不能超过最大值

   

## Set a Magic Cookie for an Audio File

一些有损压缩的音频格式，如MPEG 4 AAC，利用了包含音频元数据的结构体。这些结构体被称为 **magic cookies**。当您使用Audio Queue Services以这种格式录制时，您必须从音频队列中获取**magic cookies**，并在开始录制之前将其添加到音频文件中。

下面展示了如何从音频队列中获取一个**magic cookies**并将其应用到音频文件中。您的代码将在录制之前调用这样的函数，然后在录制之后再次调用。当录制停止时，一些编解码器会更新**magic cookies**数据

``` c
OSStatus SetMagicCookieForFile (
    AudioQueueRef inQueue,                                      // 1
    AudioFileID   inFile                                        // 2
) {
    OSStatus result = noErr;                                    // 3
    UInt32 cookieSize;                                          // 4
 
    if (
            AudioQueueGetPropertySize (                         // 5
                inQueue,
                kAudioQueueProperty_MagicCookie,
                &cookieSize
            ) == noErr
    ) {
        char* magicCookie =
            (char *) malloc (cookieSize);                       // 6
        if (
                AudioQueueGetProperty (                         // 7
                    inQueue,
                    kAudioQueueProperty_MagicCookie,
                    magicCookie,
                    &cookieSize
                ) == noErr
        )
            result =    AudioFileSetProperty (                  // 8
                            inFile,
                            kAudioFilePropertyMagicCookieData,
                            cookieSize,
                            magicCookie
                        );
        free (magicCookie);                                     // 9
    }
    return result;                                              // 10
}
```

1. 用于录音的音频队列
2. 存储录音的音频文件
3. 指示此函数成功或失败的结果变量
4. 保存magic cookie数据大小的变量
5. 从音频队列中获取魔术magic cookie的数据大小，并将其存储在cookieSize变量中
6. 分配一个字节数组来保存magic cookie信息
7. 通过查询音频队列的kAudioQueueProperty_MagicCookie属性获取magic cookie
8. 设置保存录音的音频文件的magic cookie。AudioFileSetProperty函数在AudioFile.h中声明
9. 释放临时cookie变量的内存
10. 返回此函数的成功或失败



## Set Up an Audio Format for Recording

本节描述如何为音频队列设置音频数据格式。音频队列使用这种格式录制到文件中。

- Audio data format type（音频数据格式类型），例如 linear PCM，AAC等
- 采样率，例如 44.1 kHz
- 音频声道数，例如 2，stereo
- 位深度，例如 16位
- Frames per packet（每个数据包的帧数），例如，linear PCM使用每个数据包一个帧
- Audio file type（音频文件类型），例如 CAF、AIFF等
- 文件类型所需的音频数据格式的详细信息

下面演示了如何设置录音的音频格式，为每个属性使用固定的选择。在产品代码中，你通常会允许用户指定音频格式的某些或所有方面。这两种方法的目标都是填充 AQRecorderState 自定义结构体中的 mDataFormat 字段， [Define a Custom Structure to Manage State](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW15)

``` c
AQRecorderState aqData;                                       // 1
 
aqData.mDataFormat.mFormatID         = kAudioFormatLinearPCM; // 2
aqData.mDataFormat.mSampleRate       = 44100.0;               // 3
aqData.mDataFormat.mChannelsPerFrame = 2;                     // 4
aqData.mDataFormat.mBitsPerChannel   = 16;                    // 5
aqData.mDataFormat.mBytesPerPacket   =                        // 6
   aqData.mDataFormat.mBytesPerFrame =
      aqData.mDataFormat.mChannelsPerFrame * sizeof (SInt16);
aqData.mDataFormat.mFramesPerPacket  = 1;                     // 7
 
AudioFileTypeID fileType             = kAudioFileAIFFType;    // 8
aqData.mDataFormat.mFormatFlags =                             // 9
    kLinearPCMFormatFlagIsBigEndian
    | kLinearPCMFormatFlagIsSignedInteger
    | kLinearPCMFormatFlagIsPacked;
```

1. 创建一个AQRecorderState自定义结构体的实例。该结构的mDataFormat字段包含一个体。mDataFormat字段中设置的值提供了音频队列的音频格式的初始定义—这也是您录音到文件中的音频格式
2. 将音频数据格式类型定义为 linear PCM。请参阅 *[Core Audio Data Types Reference](https://developer.apple.com/documentation/coreaudio/core_audio_data_types)* 获得可用数据格式的完整列表
3. 定义采样率为 44.1 kHz
4. 声道为2
5. 将每个声道的位深度定义为16
6. 将每个包的字节数和每帧的字节数定义为4，即 2个声道乘以每个样本的2个字节
7. 定义每个包的帧数为1
8. 将文件类型定义为 AIFF。请参阅 AudioFile.h 头文件中的音频文件类型枚举，以获得可用文件类型的完整列表。您可以指定任何已安装编解码器的文件类型，如[Using Codecs and Audio Data Formats](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AboutAudioQueues/AboutAudioQueues.html#//apple_ref/doc/uid/TP40005343-CH5-SW14)中所述
9. 设置指定文件类型所需的格式flags



### Creating a Recording Audio Queue

演示如何创建录音音频队列。请注意，AudioQueueNewInput函数使用了在前面步骤中配置的回调函数、自定义结构体和音频数据格式。

``` c
AudioQueueNewInput (                              // 1
    &aqData.mDataFormat,                          // 2
    HandleInputBuffer,                            // 3
    &aqData,                                      // 4
    NULL,                                         // 5
    kCFRunLoopCommonModes,                        // 6
    0,                                            // 7
    &aqData.mQueue                                // 8
);
```

1. AudioQueueNewInput函数创建一个新的录音音频队列
2. 用于录音的音频数据格式。参见 [Set Up an Audio Format for Recording](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW4)
3. 用于音频队列的回调函数。参见 [Write a Recording Audio Queue Callback](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW24)
4. 录音音频队列的自定义数据结构体。请参阅 [Define a Custom Structure to Manage State](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW15)
5. 回调函数将在哪个runloop上调用。如果传NULL，回调函数将在音频队列内部的线程上被调用
6. runloop modes。通常使用 kCFRunLoopCommonModes 常量
7. 保留参数。传0
8. 返回时，该变量包含一个指向新创建的录音音频队列的指针对象



### Getting the Full Audio Format from an Audio Queue

当音频队列出现时(请参见[Creating a Recording Audio Queue](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW25))，它可能已经比您更完整地填充了 AudioStreamBasicDescription 结构体结构，特别是对于压缩格式。要获得完整的格式描述，调用 AudioQueueGetProperty 函数

```c
UInt32 dataFormatSize = sizeof (aqData.mDataFormat);       // 1
 
AudioQueueGetProperty (                                    // 2
    aqData.mQueue,                                         // 3
    kAudioQueueProperty_StreamDescription,                 // 4
    // in Mac OS X, instead use
    //    kAudioConverterCurrentInputStreamDescription
    &aqData.mDataFormat,                                   // 5
    &dataFormatSize                                        // 6
);
```

1. 获取在查询音频队列的音频数据格式时要使用的预期属性值大小
2.  AudioQueueGetProperty函数获取音频队列中指定属性的值。
3. 要从中获取音频数据格式的音频队列。
4. 用于获取音频队列数据格式值的属性ID。
5. 以AudioStreamBasicDescription结构形式从音频队列获得的完整音频数据格式
6. 传入AudioStreamBasicDescription结构体的预期大小。返回实际大小。录音不需要使用这个值



## Create an Audio File

创建并配置好音频队列之后，就可以创建将音频数据记录到其中的音频文件。音频文件使用以前存储在音频队列自定义结构中的数据格式和文件格式规范。

``` c
CFURLRef audioFileURL =
    CFURLCreateFromFileSystemRepresentation (            // 1
        NULL,                                            // 2
        (const UInt8 *) filePath,                        // 3
        strlen (filePath),                               // 4
        false                                            // 5
    );
 
AudioFileCreateWithURL (                                 // 6
    audioFileURL,                                        // 7
    fileType,                                            // 8
    &aqData.mDataFormat,                                 // 9
    kAudioFileFlags_EraseFile,                           // 10
    &aqData.mAudioFile                                   // 11
);
```

1. 在头文件CFURL.h中声明的CFURLCreateFromFileSystemRepresentation函数创建一个CFURL对象，该对象表示要记录的文件。
2. 使用NULL (或kCFAllocatorDefault) 来使用当前的默认内存分配器。
3. 要转换为CFURL对象的文件系统路径。在生产代码中，您通常会从用户那里获得filePath的值。
4. 文件系统路径中的字节数。
5. 当值为false时，表示filePath表示文件，而不是目录。
6. AudioFileCreateWithURL函数（AudioFile.h头文件中），创建一个新的音频文件或初始化一个现有的文件。
7. 用于创建新音频文件的URL，或用于初始化现有文件的URL。URL来自第1步中的CFURLCreateFromFileSystemRepresentation。
8. 文件类型。在本章的示例代码中，它之前通过 kAudioFileAIFFType 文件类型常量被设置为AIFF。参见 [Set Up an Audio Format for Recording](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW4)
9. 将录音到文件中的音频的数据格式，指定为 AudioStreamBasicDescription 结构体。在本章的示例代码中，这也是在 [Set Up an Audio Format for Recording](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW4) 设置的
10. 如果文件已经存在，则擦除该文件。
11. 返回一个音频文件对象（类型为 AudioFileID），表示要录音的音频文件



## Set an Audio Queue Buffer Size

在准备录音使用音频队列缓冲区之前，请使用前面编写的 DeriveBufferSize 函数 (请参阅 [Write a Function to Derive Recording Audio Queue Buffer Size](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW14))。将此大小分配给正在使用的录音音频队列

``` c
DeriveBufferSize (                               // 1
    aqData.mQueue,                               // 2
    aqData.mDataFormat,                          // 3
    0.5,                                         // 4
    &aqData.bufferByteSize                       // 5
);
```

1. 在 [Write a Function to Derive Recording Audio Queue Buffer Size](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW14) 中描述的 DeriveBufferSize 函数，设置了一个适当的音频队列缓冲区大小
2. 设置缓冲大小的音频队列
3. 正在录制的文件的音频数据格式。参见  [Set Up an Audio Format for Recording](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW4)
4. 每个音频队列缓冲区应保存的音频秒数。就像这里设置的那样，半秒通常是个不错的选择
5. 返回每个音频队列缓冲区的大小，以字节为单位。这个值被放置在音频队列的自定义结构体中



## Prepare a Set of Audio Queue Buffers

现在请求为已创建的音频队列（[Create a Recording Audio Queue](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW2)）准备一组音频队列缓冲区

``` c
for (int i = 0; i < kNumberBuffers; ++i) {           // 1
    AudioQueueAllocateBuffer (                       // 2
        aqData.mQueue,                               // 3
        aqData.bufferByteSize,                       // 4
        &aqData.mBuffers[i]                          // 5
    );
 
    AudioQueueEnqueueBuffer (                        // 6
        aqData.mQueue,                               // 7
        aqData.mBuffers[i],                          // 8
        0,                                           // 9
        NULL                                         // 10
    );
}
```

1. 迭代以 分配 和 排队 每个音频队列缓冲区，kNumberBuffers为之前设置的音频队列个数
2. AudioQueueAllocateBuffer函数请求音频队列去分配一个音频队列缓冲区
3. 音频队列
4. 分配给音频队列缓冲区的大小(以字节为单位)。参见 [Write a Function to Derive Recording Audio Queue Buffer Size](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW14)
5. 新分配的音频队列缓冲区。指向缓冲区的指针
6. AudioQueueEnqueueBuffer函数将音频队列缓冲区添加到缓冲队列的末尾
7. 音频队列
8. 需要排队的音频队列缓冲区
9. 当将缓冲区排队用于录音时，此参数不使用
10. 当将缓冲区排队用于录音时，此参数不使用



## Record Audio

```c
aqData.mCurrentPacket = 0;                           // 1
aqData.mIsRunning = true;                            // 2
 
AudioQueueStart (                                    // 3
    aqData.mQueue,                                   // 4
    NULL                                             // 5
);
// Wait, on user interface thread, until user stops the recording
AudioQueueStop (                                     // 6
    aqData.mQueue,                                   // 7
    true                                             // 8
);
 
aqData.mIsRunning = false;                           // 9
```

1. 初始化packet索引为0以在音频文件开始时开始录音。
2. 在自定义结构体中设置 mIsRunning=true ，表示音频队列正在运行。这个标志被录音音频队列回调使用。
3. AudioQueueStart 函数在它自己的线程上启动音频队列。
4. 要启动的音频队列。
5. 使用 NULL 表示音频队列应该立即开始录制。
6. AudioQueueStop 功能停止并重置录音音频队列。
7. 要停止的音频队列
8. 使用true来使用同步停止。有关同步和异步停止的解释，请参阅音频队列控制和状态。
   - Synchronous 停止立即发生，而不考虑以前缓冲的音频数据
   - Asynchronous 在所有排队缓冲区已经播放或记录后停止
9. 设置自定义结构体中的 mIsRunning=false ，表示音频队列未运行



## Clean Up After Recording

当你完成录制后，释放音频队列并关闭音频文件

``` c
AudioQueueDispose (                                 // 1
    aqData.mQueue,                                  // 2
    true                                            // 3
);
 
AudioFileClose (aqData.mAudioFile);                 // 4
```

1. AudioQueueDispose 函数会释放音频队列及其所有资源，包括它的缓冲区
2. 要释放的音频队列
3. 使用 true 以同步方式(即立即)释放音频队列
4. 关闭用于录音的音频文件。AudioFileClose函数在 AudioFile.h 中声明



[Recording Audio](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQRecord/RecordingAudio.html#//apple_ref/doc/uid/TP40005343-CH4-SW1)

