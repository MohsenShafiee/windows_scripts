#Requires AutoHotkey v2.0

class AnimationService {
    __New(config, logger) {
        this.config := config
        this.logger := logger
    }

    PlaySwap(monitorMap) {
        if !this.config.GetBool("General", "EnableSwapAnimation", true)
            return

        duration := Max(120, Min(500, this.config.GetInt("General", "AnimationDurationMs", 220)))
        overlays := []
        try {
            overlays.Push(this.CreateOverlay(monitorMap.a.work))
            overlays.Push(this.CreateOverlay(monitorMap.b.work))

            steps := Max(6, Round(duration / 20))
            Loop steps {
                progress := A_Index / steps
                eased := 1 - ((1 - progress) ** 3)
                leftX := Round(25 + (70 * eased))
                rightX := Round(95 - (70 * eased))
                alpha := A_Index <= 2
                    ? Round(235 * A_Index / 2)
                    : (A_Index > steps - 2 ? Round(235 * (steps - A_Index + 1) / 2) : 235)

                for overlay in overlays {
                    overlay.left.Move(leftX)
                    overlay.right.Move(rightX)
                    WinSetTransparent(alpha, "ahk_id " overlay.hwnd)
                }
                Sleep(Round(duration / steps))
            }
        } finally {
            for overlay in overlays {
                try overlay.gui.Destroy()
            }
        }
    }

    CreateOverlay(workArea) {
        width := 144
        height := 58
        x := workArea.l + Round((workArea.w - width) / 2)
        y := workArea.t + Round((workArea.h - height) / 2)

        panel := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        panel.BackColor := "171A24"
        panel.MarginX := 0
        panel.MarginY := 0
        panel.SetFont("s17 Bold", "Segoe UI Symbol")
        leftDot := panel.AddText("x25 y12 w24 h34 Center c62D9FF BackgroundTrans", "●")
        rightDot := panel.AddText("x95 y12 w24 h34 Center cFF77AE BackgroundTrans", "●")
        panel.SetFont("s16 Bold", "Segoe UI Symbol")
        panel.AddText("x54 y13 w36 h32 Center cF4F6FF BackgroundTrans", "⇄")
        panel.Show("NA x" x " y" y " w" width " h" height)
        WinSetRegion("0-0 w" width " h" height " r18-18", "ahk_id " panel.Hwnd)
        WinSetTransparent(0, "ahk_id " panel.Hwnd)

        return {gui: panel, hwnd: panel.Hwnd, left: leftDot, right: rightDot}
    }
}
