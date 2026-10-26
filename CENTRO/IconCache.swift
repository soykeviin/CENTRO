//
//  IconCache.swift
//  CENTRO
//
//  Íconos de proyecto cargados fuera del hilo principal y en miniatura.
//  Antes cada tarjeta leía el archivo del disco en cada redibujado; como
//  ~/Documents está en iCloud, un ícono "solo en la nube" frenaba la app
//  hasta que se descargaba (el buscador se colgaba casi un minuto).
//

import AppKit
import ImageIO

nonisolated final class IconCache: @unchecked Sendable {
    static let shared = IconCache()

    private let cache = NSCache<NSString, NSImage>()
    private let missing = NSCache<NSString, NSNumber>()

    /// Ícono ya cargado (instantáneo, seguro para usar en `body`).
    func cached(_ path: String) -> NSImage? { cache.object(forKey: path as NSString) }

    /// Carga en segundo plano. Devuelve nil si el archivo no está descargado de iCloud.
    func load(_ path: String) async -> NSImage? {
        if let img = cached(path) { return img }
        if missing.object(forKey: path as NSString) != nil { return nil }
        let img = await Task.detached(priority: .utility) { Self.thumbnail(path) }.value
        if let img { cache.setObject(img, forKey: path as NSString) }
        else { missing.setObject(1, forKey: path as NSString) }
        return img
    }

    private static func thumbnail(_ path: String) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        // Archivo solo en iCloud: no forzar descarga (bloquea y gasta red).
        if let st = try? FileManager.default.attributesOfItem(atPath: path),
           (st[.size] as? Int ?? 0) > 0,
           isDataless(path) { return nil }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 128,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    private static func isDataless(_ path: String) -> Bool {
        var st = stat()
        guard stat(path, &st) == 0 else { return false }
        return (st.st_flags & UInt32(SF_DATALESS)) != 0
    }
}
