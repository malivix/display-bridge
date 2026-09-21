// SPDX-License-Identifier: MIT
import Foundation

func runSizeReviewTests() {
    func decode(_ report:[String:Any])->SizeReview? {
        let data=try! JSONSerialization.data(withJSONObject:report)
        return SizeReview.decode(String(decoding:data,as:UTF8.self))
    }
    precondition(decode(demoSizeReview("size-report-error"))==nil)
    let fixture=demoSizeReview("ready")
    let valid=decode(fixture)!
    precondition(valid.rotation==90 && valid.choices.count==4 && valid.presets.count==2)
    precondition(valid.durations==[20,40] && valid.notes.first!.contains("Landscape"))
    precondition(valid.choices[0].arguments(seconds:20)==["preview-start","--size","current","--fingerprint",String(repeating:"a",count:64)])
    precondition(valid.choices.last!.arguments(seconds:40)==["preview-start","--preset","Reading","--fingerprint",String(repeating:"a",count:64),"--preview-seconds","40"])
    var older=fixture;older.removeValue(forKey:"preview_seconds");older.removeValue(forKey:"presets")
    precondition(decode(older)?.durations==[20] && decode(older)?.presets.isEmpty==true)
    let damaged=decode(demoSizeReview("presets-error"))!
    precondition(damaged.presetError != nil && damaged.presets.isEmpty && damaged.choices.count==3)
    precondition(damaged.notes.first!.contains("original file was preserved"))
    for key in ["rotation","read_only","options"] {
        var bad=fixture;bad.removeValue(forKey:key);precondition(decode(bad)==nil)
    }
    for rotation:Any in [true,-1,180,"90",90.5] {
        var bad=fixture;bad["rotation"]=rotation;precondition(decode(bad)==nil)
    }
    for marker:Any in [false,1,"true"] {
        var bad=fixture;bad["read_only"]=marker;precondition(decode(bad)==nil)
    }
    for durations:Any in [[20,20],[40],[20,60],[true],"20"] {
        var bad=fixture;bad["preview_seconds"]=durations;precondition(decode(bad)==nil)
    }
    for key in ["size","label","fingerprint","modes"] {
        var bad=fixture;var options=fixture["options"] as! [[String:Any]]
        options[0].removeValue(forKey:key);bad["options"]=options;precondition(decode(bad)==nil)
    }
    for (key,value) in [("size","unknown"),("fingerprint","demo"),("fingerprint",String(repeating:"a",count:64)+"\n"),("label","")] {
        var bad=fixture;var options=fixture["options"] as! [[String:Any]]
        options[0][key]=value;bad["options"]=options;precondition(decode(bad)==nil)
    }
    for dimensions:Any in [true,0,-1,32769,1920.5] {
        var bad=fixture;var options=fixture["options"] as! [[String:Any]]
        var modes=options[0]["modes"] as! [String:[String:Any]]
        modes["pg"]!["width"]=dimensions;options[0]["modes"]=modes;bad["options"]=options
        precondition(decode(bad)==nil)
    }
    let options=fixture["options"] as! [[String:Any]]
    for invalid in [[],[[:]],Array(options.dropFirst()),options+[options[0]]] {
        var bad=fixture;bad["options"]=invalid;precondition(decode(bad)==nil)
    }
    var nullPresets=fixture;nullPresets["presets"]=NSNull();precondition(decode(nullPresets)==nil)
    let presets=fixture["presets"] as! [[String:Any]]
    for (key,value):(String,Any) in [("name",""),("available",1),("rotation",0),("revision","bad"),("fingerprint","bad"),("physical_size_percent",true)] {
        var bad=fixture;var rows=presets;rows[0][key]=value;bad["presets"]=rows
        precondition(decode(bad)==nil)
    }
    for key in ["fingerprint","modes"] {
        var bad=fixture;var rows=presets;rows[0].removeValue(forKey:key);bad["presets"]=rows
        precondition(decode(bad)==nil)
    }
    var bad=fixture;bad["presets"]=presets+[presets[0]];precondition(decode(bad)==nil)
    bad=fixture;bad["preset_error"]="Damaged presets";precondition(decode(bad)==nil)
    var unavailable=presets;unavailable[1].removeValue(forKey:"reason")
    bad=fixture;bad["presets"]=unavailable;precondition(decode(bad)==nil)
    precondition(SizeReview.decode("{}") == nil && SizeReview.decode("not JSON") == nil)
    print("PASS validated size reports, preset isolation and canonical preview arguments")
}
