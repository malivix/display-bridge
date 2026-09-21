// SPDX-License-Identifier: MIT
import Foundation
import CoreFoundation

struct MonitorSetting {
    let value:Int
    let maximum:Int
    let percent:Int
    init?(_ object:Any?) {
        guard let fields=object as? [String:Any],
              let value=monitorInteger(fields["value"],0...65535),
              let maximum=monitorInteger(fields["maximum"],1...65535),value<=maximum,
              let percent=monitorInteger(fields["percent"],0...100),
              percent==Int((Double(value)*100/Double(maximum)).rounded(.toNearestOrEven)) else{return nil}
        self.value=value;self.maximum=maximum;self.percent=percent
    }
}

private func monitorInteger(_ value:Any?,_ range:ClosedRange<Int>)->Int? {
    guard let number=value as? NSNumber,CFGetTypeID(number) != CFBooleanGetTypeID(),
          number.doubleValue.isFinite,number.doubleValue.rounded()==number.doubleValue,
          number.doubleValue>=Double(range.lowerBound),number.doubleValue<=Double(range.upperBound) else{return nil}
    return number.intValue
}
private func monitorBoolean(_ value:Any?)->Bool? {
    guard let number=value as? NSNumber,CFGetTypeID(number)==CFBooleanGetTypeID() else{return nil}
    return number.boolValue
}

enum MonitorResponse {
    case snapshot(role:String,brightness:MonitorSetting,volume:MonitorSetting)
    case adjustment(role:String,feature:String,setting:MonitorSetting)

    static let commands:Set<String>=["monitor-settings","monitor-adjust","brightness-apply"]
    static func decode(_ response:CommandResult,arguments:[String])->MonitorResponse? {
        func option(_ name:String)->String? {
            let positions=arguments.indices.filter{arguments[$0]==name}
            guard positions.count==1,let index=positions.first,index+1<arguments.count else{return nil}
            return arguments[index+1]
        }
        guard response.code==0,response.output.utf8.count<=1_048_576,
              let action=arguments.first,commands.contains(action),
              let role=option("--monitor"),["pg","benq"].contains(role),
              let data=response.output.data(using:.utf8),
              let report=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
              report["monitor"] as? String==role else{return nil}
        if action=="monitor-settings" {
            guard monitorBoolean(report["read_only"])==true,
                  let settings=report["settings"] as? [String:Any],
                  let brightness=MonitorSetting(settings["luminance"]),
                  let volume=MonitorSetting(settings["volume"]) else{return nil}
            return .snapshot(role:role,brightness:brightness,volume:volume)
        }
        guard let feature=(action=="brightness-apply" ? "luminance":option("--feature")),
              ["luminance","volume"].contains(feature),report["feature"] as? String==feature,
              let setting=MonitorSetting(report),
              let before=monitorInteger(report["before"],0...setting.maximum),
              let changed=monitorBoolean(report["changed"]),changed==(before != setting.value) else{return nil}
        return .adjustment(role:role,feature:feature,setting:setting)
    }
    var role:String {
        switch self {case .snapshot(let role,_,_),.adjustment(let role,_,_):return role}
    }
    func summary(at date:Date)->String {
        let monitor=role=="pg" ? "PG42UQ":"BenQ RD280UG"
        switch self {
        case .snapshot(_,let brightness,let volume):
            return "Read-only snapshot · \(monitor)\nRead at \(date.formatted(date:.abbreviated,time:.standard))\nBrightness: \(brightness.percent)% (\(brightness.value) / \(brightness.maximum))\nSpeaker volume: \(volume.percent)% (\(volume.value) / \(volume.maximum))\n\nThese are monitor hardware settings. Speaker volume does not select the macOS audio output. Nothing was changed."
        case .adjustment(_,let feature,let setting):
            let name=feature=="luminance" ? "Brightness":"Speaker volume"
            return "\(monitor) · \(name): \(setting.percent)%\nConfirmed at \(date.formatted(date:.omitted,time:.standard)). Refresh after using the monitor's own controls."
        }
    }
}

// Session-only observations are kept per target. A failed BenQ request must
// never reuse PG's reading, and returning to a target must not imply a new read.
struct MonitorReadings {
    private var readings:[String:String]=[:]
    mutating func accept(_ response:MonitorResponse,at date:Date)->String {
        let summary=response.summary(at:date)
        readings[response.role]=summary
        return summary
    }
    func previous(for role:String)->String? {
        readings[role].map{"Previous reading (not refreshed):\n"+$0}
    }
}
