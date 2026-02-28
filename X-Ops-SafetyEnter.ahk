#Requires AutoHotkey v2.0
#SingleInstance Force

global targetApp := ""
global groupName := "SafeChatGroup"
global iniFile := A_ScriptDir "\settings.ini"

InitSettings()
SetupTrayMenu()

; ==========================================
; 【UI構築：X-Ops SafetyEnter HUD】
; ==========================================
global Overlay := Gui("-Caption +AlwaysOnTop +ToolWindow")
Overlay.BackColor := "202225"
Overlay.MarginX := 15
Overlay.MarginY := 15

WinSetTransparent(245, Overlay)
Overlay.SetFont("s10 cWhite", "Meiryo")
global EditBox := Overlay.Add("Edit", "w600 r4.5 vInputText +WantReturn -VScroll -E0x200 Background2B2D31 cWhite")

Line := Overlay.Add("Text", "x15 y+10 w600 h1 Background40444B") 

Overlay.SetFont("s9 bold", "Meiryo")
global btnCancel := Overlay.Add("Text", "x335 y+10 w120 h30 Center 0x200 Background4E5058 cWhite", "キャンセル (Esc)")
global btnSend   := Overlay.Add("Text", "x+10 yp w150 h30 Center 0x200 Background5865F2 cWhite", "送信 (Ctrl+Enter)")

btnCancel.OnEvent("Click", (*) => Overlay.Hide())
btnSend.OnEvent("Click", (*) => SendToApp())

; ==========================================
; 【グローバルホットキー】
; ==========================================
^+e::ToggleCurrentApp()

; ==========================================
; 【HUD内の専用ホットキー】
; ==========================================
#HotIf WinActive("ahk_id " Overlay.Hwnd)

^Enter::SendToApp()
Esc::Overlay.Hide()

#HotIf

; ==========================================
; 【HUDの呼び出しホットキー】
; ==========================================
#HotIf WinActive("ahk_group " groupName)

^Space::SummonOverlay()

#HotIf

; ==========================================
; コア機能：HUDの表示と転送
; ==========================================
SummonOverlay() {
    global targetApp := WinGetID("A")
    WinGetPos(&X, &Y, &W, &H, targetApp)

    Overlay.Show("Hide")
    Overlay.GetPos(,, &guiW, &guiH)
    
    posX := X + (W / 2) - (guiW / 2)
    posY := Y + H - guiH - 50 

    Overlay.Show("x" posX " y" posY)
    
    EditBox.Focus()
    SendMessage(0x00B1, 0, -1, EditBox.Hwnd)
}

SendToApp() {
    global targetApp
    textToSend := EditBox.Value

    if (textToSend = "") {
        Overlay.Hide()
        return
    }

    Overlay.Hide()

    if WinExist("ahk_id " targetApp) {
        
        ; 💡 改善点: AHKの内部改行(`n)をWindows標準の改行(`r`n)に強制変換する
        formattedText := StrReplace(StrReplace(textToSend, "`r`n", "`n"), "`n", "`r`n")

        A_Clipboard := ""
        A_Clipboard := formattedText
        ClipWait(1)

        WinActivate("ahk_id " targetApp)
        Sleep(50)
        Send("^v")
        Sleep(50)
        Send("{Enter}")

        EditBox.Value := ""

    } else {
        ShowOSD("⚠️ 送信先が見つかりません")
    }
}

; ==========================================
; 管理用関数
; ==========================================
InitSettings() {
    if !FileExist(iniFile) {
        IniWrite("1", iniFile, "ChatApps", "Discord.exe")
        IniWrite("1", iniFile, "ChatApps", "LINE.exe")
        IniWrite("1", iniFile, "ChatApps", "Teams.exe")
        IniWrite("1", iniFile, "ChatApps", "slack.exe")
    }
    try {
        content := IniRead(iniFile, "ChatApps")
        Loop Parse, content, "`n", "`r" {
            if (A_LoopField != "") {
                exe := StrSplit(A_LoopField, "=")[1]
                GroupAdd(groupName, "ahk_exe " exe)
            }
        }
    }
}

ToggleCurrentApp(*) {
    try {
        activeExe := WinGetProcessName("A")
    } catch {
        return
    }
    if (activeExe = "explorer.exe" || activeExe = "") {
        ShowOSD("対象外です")
        return
    }
    isReg := IniRead(iniFile, "ChatApps", activeExe, "0")
    if (isReg = "1") {
        IniDelete(iniFile, "ChatApps", activeExe)
        ShowOSD("❌ 除外: " activeExe)
    } else {
        IniWrite("1", iniFile, "ChatApps", activeExe)
        ShowOSD("✅ 追加: " activeExe)
    }
    Sleep(1500)
    Reload()
}

ShowOSD(text) {
    osd := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20 +Border")
    osd.BackColor := "2B2D31"
    osd.MarginX := 25
    osd.MarginY := 15
    osd.SetFont("s11 bold cWhite", "Meiryo")
    osd.Add("Text", "Center", text)
    WinSetTransparent(230, osd)
    
    osd.Show("Hide")
    osd.GetPos(,, &gW, &gH)
    
    try {
        WinGetPos(&X, &Y, &W, &H, "A")
        if (W = "" || H = "") {
            throw Error("Window size not found")
        }
        osd.Show("x" (X + W/2 - gW/2) " y" (Y + H/2 - gH/2) " NoActivate")
    } catch {
        osd.Show("NoActivate Center")
    }
    SetTimer(() => osd.Destroy(), -1500)
}

SetupTrayMenu() {
    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add("アプリを追加/除外", (*) => ToggleCurrentApp())
    Tray.Add()
    Tray.Add("設定を開く", (*) => (FileExist(iniFile) ? Run(iniFile) : ""))
    Tray.Add("一時停止", (n, p, m) => (Suspend(-1), ShowOSD(A_IsSuspended ? "⚠️ 一時停止" : "▶️ 再開")))
    Tray.Add("終了", (*) => ExitApp())
}