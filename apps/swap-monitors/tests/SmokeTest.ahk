#Requires AutoHotkey v2.0

#Include "..\src\Win32.ahk"
#Include "..\src\GeometryService.ahk"

Assert(condition, message) {
    if !condition
        throw Error(message)
}

source := GeometryService.MakeRect(0, 0, 1920, 1032)
destination := GeometryService.MakeRect(1920, 0, 1920, 1032)
window := GeometryService.MakeRect(-2, 5, 1425, 413)
mapped := GeometryService.MapRect(window, source, destination)
Assert(mapped.l = 1918 && mapped.t = 5 && mapped.w = 1425 && mapped.h = 413,
    "Equal-size monitor translation failed")

smallDestination := GeometryService.MakeRect(0, 0, 1280, 720)
scaled := GeometryService.MapRect(GeometryService.MakeRect(960, 516, 480, 258), source, smallDestination)
Assert(scaled.l = 640 && scaled.t = 360 && scaled.w = 320 && scaled.h = 180,
    "Relative geometry scaling failed")

a := GeometryService.MakeRect(0, 0, 100, 100)
b := GeometryService.MakeRect(50, 50, 100, 100)
Assert(GeometryService.IntersectionArea(a, b) = 2500, "Intersection area failed")

clamped := GeometryService.MapRect(GeometryService.MakeRect(-5000, -5000, 300, 200), source, destination)
Assert(clamped.t >= destination.t && clamped.l + clamped.w >= destination.l,
    "Off-screen clamp failed")

FileAppend("Smoke tests passed.`n", "*")
