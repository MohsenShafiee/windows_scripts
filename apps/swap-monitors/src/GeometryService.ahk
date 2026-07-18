#Requires AutoHotkey v2.0

class GeometryService {
    static IntersectionArea(a, b) {
        width := Max(0, Min(a.r, b.r) - Max(a.l, b.l))
        height := Max(0, Min(a.b, b.b) - Max(a.t, b.t))
        return width * height
    }

    static PointInRect(x, y, rect) => x >= rect.l && x < rect.r && y >= rect.t && y < rect.b

    static MapRect(rect, source, destination) {
        if source.w <= 0 || source.h <= 0
            throw Error("Source monitor has an invalid work area")
        if source.w = destination.w && source.h = destination.h {
            mapped := this.MakeRect(rect.l + destination.l - source.l,
                rect.t + destination.t - source.t, rect.w, rect.h)
        } else {
            x := destination.l + Round((rect.l - source.l) * destination.w / source.w)
            y := destination.t + Round((rect.t - source.t) * destination.h / source.h)
            w := Max(120, Round(rect.w * destination.w / source.w))
            h := Max(80, Round(rect.h * destination.h / source.h))
            mapped := this.MakeRect(x, y, Min(w, destination.w), Min(h, destination.h))
        }
        return this.Clamp(mapped, destination)
    }

    static Clamp(rect, area) {
        titleVisible := Min(64, Max(16, rect.w))
        w := Min(Max(rect.w, 120), Max(area.w, 120))
        h := Min(Max(rect.h, 80), Max(area.h, 80))
        x := Min(rect.l, area.r - titleVisible)
        x := Max(x, area.l - w + titleVisible)
        y := Min(rect.t, area.b - 32)
        y := Max(y, area.t)
        return this.MakeRect(Round(x), Round(y), Round(w), Round(h))
    }

    static MakeRect(x, y, w, h) {
        return {l: x, t: y, r: x + w, b: y + h, x: x, y: y, w: w, h: h}
    }

    static WithinTolerance(actual, expected, tolerance) {
        return Abs(actual.l - expected.l) <= tolerance
            && Abs(actual.t - expected.t) <= tolerance
            && Abs(actual.w - expected.w) <= tolerance
            && Abs(actual.h - expected.h) <= tolerance
    }
}
