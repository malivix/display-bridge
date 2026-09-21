// SPDX-License-Identifier: MIT
import Foundation

// One synthetic report shared by UI inspection and boundary regression tests.
func demoSizeReview(_ scenario:String)->[String:Any] {
    let modes:[String:Any] = ["pg":["width":1920,"height":1080,"pixelWidth":3840,"pixelHeight":2160],"benq":["width":1280,"height":1920,"pixelWidth":2560,"pixelHeight":3840]]
    var report:[String:Any] = ["read_only":true,"preview_seconds":[20,40],"rotation":90,"options":[["label":"Current size","size":"current","fingerprint":String(repeating:"a",count:64),"modes":modes],["label":"Larger interface","size":"larger","fingerprint":String(repeating:"a",count:64),"modes":["pg":["width":1536,"height":864,"pixelWidth":3072,"pixelHeight":1728],"benq":["width":1024,"height":1536,"pixelWidth":2048,"pixelHeight":3072]]]],
        "presets":[["name":"Reading","rotation":90,"revision":String(repeating:"b",count:64),"physical_size_percent":154.3,"available":true,"fingerprint":String(repeating:"a",count:64),"modes":modes],
           ["name":"Reading","rotation":0,"revision":String(repeating:"b",count:64),"available":false,"reason":"Preset belongs to the other orientation"]]]
    if var options=report["options"] as? [[String:Any]] {
        options[0]["physical_size_percent"]=154.3
        options.append(["label":"Match PG size to BenQ","size":"match-benq","fingerprint":String(repeating:"a",count:64),"physical_size_percent":98.5,
            "modes":["pg":["width":3008,"height":1692,"pixelWidth":6016,"pixelHeight":3384],"benq":modes["benq"]!]])
        report["options"]=options
    }
    if scenario=="presets-error" {report["presets"]=[];report["preset_error"]="Saved presets are unreadable. The original file was preserved. Ordinary size previews remain available."}
    if scenario=="size-report-error" {report.removeValue(forKey:"rotation")}
    return report
}
