;混合映射按键
;按下keyParent键后如果在triggerTime时间内松开则执行一次keyParent按键, 否则视为按下keyChild键
;如 keyParent =  A , keyChild = Ctrl , triggerTime = 200, 当按下A键超过200ms后视为按下Ctrl键
MixedMappingKkey(keyParent, keyChild, triggerTime)
{
    release := KeyWait(keyParent, "T" triggerTime)
    if (release) 
    {
        Send(Format("{{}blind{}}{}", keyParent))
        return
    }
    Send(Format("{{}blind{}}{{}{} Down{}}",keyChild))
    KeyWait(keyParent) 
    Send(Format("{{}blind{}}{{}{} Up{}}",keyChild))
}
