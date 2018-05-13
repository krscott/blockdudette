; Simulate Pico-8 inputs

#NoEnv
#Persistent
#SingleInstance, Force
SendMode, Input

picoBtnArray := ["Left", "Right", "Up", "Down", "z", "x"]

filename := "inputs.txt"

PicoReset() {
    Send ^r
    Sleep, 1000
}

PicoBtn(i) {
    local btn := picoBtnArray[i+1]
    Send, {%btn% down}
    Sleep, 40
    Send, {%btn% up}
    ;Sleep, 10
}


if (Not WinExist("PICO-8")) {
    ExitApp
}

WinActivate

PicoReset()

Loop, Read, %filename%
{
    if (Not WinActive("PICO-8")) {
        ExitApp
    }

    i := 0
    any := false
    Loop, Parse, A_LoopReadLine, CSV
    {
        if (InStr(A_LoopField, "true")) {
            PicoBtn(i)
            any := true
        }
        i := i+1
    }

    if (not any) {
        Sleep, 1
    }
}

;MsgBox, "Done!"
ExitApp

