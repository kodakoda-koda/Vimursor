import AppKit
import os

/// メニューバーアイコンの読み込みロジック。
/// StatusBarController から分離することで単体テスト可能にする。
struct MenuBarIconLoader {

    private static let logger = Logger(subsystem: "com.vimursor.app", category: "MenuBarIconLoader")

    /// メニューバーアイコンの表示サイズ（pt）。
    static let menuBarIconSize: CGFloat = 18

    /// Bundle リソースから MenuBarIcon.png を読み込む。
    /// @2x 表現も登録し、isTemplate = true を設定する。
    /// - Parameter bundle: 検索対象の Bundle（デフォルトは Bundle.main）。
    /// - Returns: 読み込み成功時は NSImage、失敗時は nil。
    static func loadFromBundle(_ bundle: Bundle = .main) -> NSImage? {
        guard let url1x = bundle.url(forResource: "MenuBarIcon", withExtension: "png") else {
            logger.debug("MenuBarIcon.png が Bundle に見つかりません（デバッグビルド等では正常）")
            return nil
        }

        guard let data1x = try? Data(contentsOf: url1x),
              let rep1x = NSBitmapImageRep(data: data1x),
              let rep1xCopy = rep1x.copy() as? NSBitmapImageRep
        else {
            logger.warning("MenuBarIcon.png の読み込みに失敗しました: \(url1x.path)")
            return nil
        }

        let targetSize = NSSize(width: menuBarIconSize, height: menuBarIconSize)
        let icon = NSImage(size: targetSize)

        // @1x 表現を追加
        rep1xCopy.size = targetSize
        icon.addRepresentation(rep1xCopy)

        // @2x 表現が存在すれば追加
        if let url2x = bundle.url(forResource: "MenuBarIcon@2x", withExtension: "png"),
           let data2x = try? Data(contentsOf: url2x),
           let rep2x = NSBitmapImageRep(data: data2x),
           let rep2xCopy = rep2x.copy() as? NSBitmapImageRep {
            rep2xCopy.size = targetSize
            icon.addRepresentation(rep2xCopy)
        }

        icon.size = targetSize
        icon.isTemplate = true
        return icon
    }

    /// カスタムアイコンが読み込めない場合の SF Symbol フォールバック。
    static func fallbackIcon() -> NSImage? {
        guard let icon = NSImage(
            systemSymbolName: "keyboard",
            accessibilityDescription: "Vimursor"
        ) else {
            logger.warning("SF Symbol 'keyboard' の読み込みに失敗しました")
            return nil
        }
        icon.isTemplate = true
        return icon
    }
}
