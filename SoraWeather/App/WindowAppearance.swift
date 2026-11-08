import SwiftUI
import UIKit

@MainActor enum SkyAppearance {
    static func colors(condition: String, night: Bool) -> [Color] {
        if night { return [Color(red: 0.025, green: 0.055, blue: 0.14), Color(red: 0.12, green: 0.22, blue: 0.36)] }
        if condition.contains("雪") { return [Color(red: 0.51, green: 0.62, blue: 0.71), Color(red: 0.72, green: 0.77, blue: 0.81)] }
        if condition.contains("曇") || condition.contains("くもり") || condition.contains("雨") || condition.isEmpty { return [Color(red: 0.44, green: 0.53, blue: 0.62), Color(red: 0.59, green: 0.67, blue: 0.74)] }
        return [Color(red: 0.06, green: 0.35, blue: 0.65), Color(red: 0.36, green: 0.64, blue: 0.83)]
    }
    // One immutable raster texture, shared by city cards and pages. No display-link or per-frame Canvas work.
    static let stars: UIImage = {
        let format = UIGraphicsImageRendererFormat(); format.opaque = false; format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 512, height: 1024), format: format).image { context in
            for i in 0..<70 {
                let x = CGFloat((i*73+19)%997)/997*512; let y = CGFloat((i*137+41)%769)/769*1024
                let r: CGFloat = i%7 == 0 ? 1.1 : 0.6
                UIColor.white.withAlphaComponent(i%3 == 0 ? 0.6 : 0.28).setFill()
                context.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: r*2, height: r*2))
            }
        }
    }()
}
struct WindowSkyBackground: UIViewRepresentable {
    let color: Color
    final class Backing: UIView {
        var sky: UIColor = UIColor(named: "LaunchBackground") ?? .darkGray
        override func didMoveToWindow() { super.didMoveToWindow(); window?.backgroundColor = sky }
    }
    func makeUIView(context: Context) -> Backing { let view = Backing(); view.isUserInteractionEnabled = false; view.sky = UIColor(color); return view }
    func updateUIView(_ view: Backing, context: Context) { view.sky = UIColor(color); view.window?.backgroundColor = view.sky }
}
