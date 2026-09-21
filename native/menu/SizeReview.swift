// SPDX-License-Identifier: MIT
import Foundation

// Decode once at the CLI boundary. The chooser may format dictionaries, but request
// construction uses only validated targets and fingerprints from this model.
struct SizeReviewChoice {
    enum Target {
        case relative(String)
        case preset(String)
    }
    let target:Target
    let fingerprint:String
    let presentation:[String:Any]

    func arguments(seconds:Int)->[String] {
        let selection:[String]
        switch target {
        case .relative(let name): selection=["--size",name]
        case .preset(let name): selection=["--preset",name]
        }
        return ["preview-start"]+selection+["--fingerprint",fingerprint]+(seconds==20 ? []:["--preview-seconds",String(seconds)])
    }
}

struct SizeReview {
    let rotation:Int
    let choices:[SizeReviewChoice]
    let current:[String:Any]
    let presets:[[String:Any]]
    let notes:[String]
    let presetError:String?
    let durations:[Int]

    static func decode(_ json:String)->SizeReview? {
        guard let data=json.data(using:.utf8),data.count<=1_048_576,
              let report=try? JSONDecoder().decode(Report.self,from:data),
              report.read_only, [0,90].contains(report.rotation),
              !report.options.isEmpty,report.options.count<=9,
              report.presets.count<=20 else{return nil}
        var choices:[SizeReviewChoice]=[],presets:[[String:Any]]=[],notes:[String]=[]
        var keys=Set<String>(),presetKeys=Set<String>()
        let supported:Set<String>=["current","larger","more-space","match-pg","match-benq","match-pg-larger","match-pg-smaller","match-benq-larger","match-benq-smaller"]
        for option in report.options {
            guard supported.contains(option.size),keys.insert(option.size).inserted,
                  validDigest(option.fingerprint),validText(option.label),
                  let modes=validModes(option.modes),validEstimate(option.physical_size_percent) else{return nil}
            var item:[String:Any]=["size":option.size,"label":option.label,"fingerprint":option.fingerprint,"modes":modes]
            if let estimate=option.physical_size_percent {item["physical_size_percent"]=estimate}
            choices.append(SizeReviewChoice(target:.relative(option.size),fingerprint:option.fingerprint,presentation:item))
        }
        guard let current=choices.first(where:{$0.presentation["size"] as? String == "current"})?.presentation else{return nil}
        if let error=report.preset_error {
            guard validText(error),report.presets.isEmpty else{return nil}
            notes.append("Saved presets unavailable\n"+error)
        }
        var unavailable:[String]=[]
        for preset in report.presets {
            guard presetNameError(preset.name)==nil,[0,90].contains(preset.rotation),
                  validDigest(preset.revision),presetKeys.insert("\(preset.rotation):\(preset.name)").inserted else{return nil}
            let identity:[String:Any]=["name":preset.name,"rotation":preset.rotation,"revision":preset.revision]
            presets.append(identity)
            if preset.available {
                guard preset.rotation==report.rotation,let fingerprint=preset.fingerprint,validDigest(fingerprint),
                      let rawModes=preset.modes,let modes=validModes(rawModes),validEstimate(preset.physical_size_percent) else{return nil}
                var item:[String:Any]=["preset":preset.name,"label":"Preset: "+preset.name,"fingerprint":fingerprint,"modes":modes]
                if let estimate=preset.physical_size_percent {item["physical_size_percent"]=estimate}
                choices.append(SizeReviewChoice(target:.preset(preset.name),fingerprint:fingerprint,presentation:item))
            } else {
                guard let reason=preset.reason,validText(reason) else{return nil}
                unavailable.append(preset.name+" — "+(preset.rotation==90 ? "Portrait":"Landscape")+": "+reason)
            }
        }
        if !unavailable.isEmpty {notes.append("Unavailable presets\n"+unavailable.joined(separator:"\n"))}
        // Older reports omit durations; existing preview behavior was 20 seconds.
        let durations=report.preview_seconds ?? [20]
        guard !durations.isEmpty,durations.count<=2,Set(durations).count==durations.count,
              durations.contains(20),durations.allSatisfy({[20,40].contains($0)}) else{return nil}
        return SizeReview(rotation:report.rotation,choices:choices,current:current,presets:presets,
                          notes:notes,presetError:report.preset_error,durations:durations.sorted())
    }

    private static func validDigest(_ text:String)->Bool {
        text.utf8.count==64 && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    private static func validText(_ text:String)->Bool {
        !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && text.utf8.count<=4096 &&
        !text.unicodeScalars.contains {CharacterSet.controlCharacters.contains($0)}
    }
    private static func validEstimate(_ value:Double?)->Bool {
        value.map{$0.isFinite && $0>0 && $0<=10000} ?? true
    }
    private static func validModes(_ modes:[String:Mode])->[String:[String:Int]]? {
        guard Set(modes.keys)==["pg","benq"] else{return nil}
        var result:[String:[String:Int]]=[:]
        for (role,mode) in modes {
            guard [mode.width,mode.height,mode.pixelWidth,mode.pixelHeight].allSatisfy({(1...32768).contains($0)}),
                  mode.pixelWidth==2*mode.width,mode.pixelHeight==2*mode.height else{return nil}
            result[role]=["width":mode.width,"height":mode.height,"pixelWidth":mode.pixelWidth,"pixelHeight":mode.pixelHeight]
        }
        return result
    }
    private struct Mode:Decodable {let width:Int,height:Int,pixelWidth:Int,pixelHeight:Int}
    private struct Option:Decodable {
        let size:String,label:String,fingerprint:String,modes:[String:Mode]
        let physical_size_percent:Double?
    }
    private struct Preset:Decodable {
        let name:String,rotation:Int,revision:String,available:Bool
        let fingerprint:String?,modes:[String:Mode]?,physical_size_percent:Double?,reason:String?
    }
    private struct Report:Decodable {
        let read_only:Bool,rotation:Int,options:[Option],presets:[Preset]
        let preset_error:String?,preview_seconds:[Int]?
        private enum CodingKeys:String,CodingKey {case read_only,rotation,options,presets,preset_error,preview_seconds}
        init(from decoder:Decoder) throws {
            let fields=try decoder.container(keyedBy:CodingKeys.self)
            read_only=try fields.decode(Bool.self,forKey:.read_only)
            rotation=try fields.decode(Int.self,forKey:.rotation)
            options=try fields.decode([Option].self,forKey:.options)
            // Pre-preset controllers omitted this field. A supplied invalid value
            // is not treated as an empty preset store.
            presets=try fields.contains(.presets) ? fields.decode([Preset].self,forKey:.presets):[]
            preset_error=try fields.decodeIfPresent(String.self,forKey:.preset_error)
            preview_seconds=try fields.decodeIfPresent([Int].self,forKey:.preview_seconds)
        }
    }
}
