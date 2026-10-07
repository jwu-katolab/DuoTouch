import UniformTypeIdentifiers

extension UTType {
    /// DXF（AutoCAD）のUTType。既存定義がない環境向けに importedAs を利用。
    static var dxf: UTType {
        // 拡張子ベースで見つかる場合はそれを優先、なければ UTI をインポート
        UTType(filenameExtension: "dxf") ?? UTType(importedAs: "com.autodesk.dxf")
    }
}
