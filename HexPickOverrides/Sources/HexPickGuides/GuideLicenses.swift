import Foundation

public enum GuideLicenses {
    public static var mayhempedia: String {
        guard let url = Bundle.module.url(forResource: "Mayhempedia-LICENSE", withExtension: "txt", subdirectory: "Resources"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "许可证文件不可用。完整文本：https://github.com/boxsbraindump/Mayhempedia/blob/main/LICENSE"
        }
        return text
    }
}
