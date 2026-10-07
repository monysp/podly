import SwiftUI
import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

// MARK: - Tag Service (mutagen through Python)

/// Reads and writes tags, lyrics and cover art with Python's `mutagen`,
/// which is already installed as a dependency of spotDL.
enum TagService {
    private static let python: String? = resolvePython()

    static var installCommand: String {
        "\(python ?? "python3") -m pip install mutagen"
    }

    /// Uses the same interpreter that spotDL runs on (read from its shebang line).
    private static func resolvePython() -> String? {
        if let spotdl = SpotDLService.findExecutable(),
           let handle = FileHandle(forReadingAtPath: spotdl) {
            let head = handle.readData(ofLength: 512)
            try? handle.close()

            if let text = String(data: head, encoding: .utf8),
               let line = text.split(separator: "\n").first,
               line.hasPrefix("#!") {
                let path = line.dropFirst(2).split(separator: " ").first.map(String.init) ?? ""

                if !path.isEmpty,
                   !path.hasSuffix("/env"),
                   FileManager.default.isExecutableFile(atPath: path) {
                    return path
                }
            }
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "command -v python3"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let result = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return result.isEmpty ? nil : result
    }

    /// Blocking. Call from a background queue (or use `runAsync`).
    static func run(_ request: [String: Any]) -> [String: Any] {
        guard let interpreter = python else {
            return ["error": "Couldn’t find Python. Install spotDL first."]
        }

        guard let payload = try? JSONSerialization.data(withJSONObject: request) else {
            return ["error": "Couldn’t build the request."]
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: interpreter)
        process.arguments = ["-c", script]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONIOENCODING"] = "utf-8"
        environment["PYTHONUTF8"] = "1"
        process.environment = environment

        do {
            try process.run()
        } catch {
            return ["error": "Couldn’t start Python: \(error.localizedDescription)"]
        }

        try? input.fileHandleForWriting.write(contentsOf: payload)
        try? input.fileHandleForWriting.close()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return ["error": "Python didn’t return an answer."]
        }

        if json["missingModule"] != nil {
            json["error"] = "mutagen isn’t installed. Run: \(installCommand)"
        }

        return json
    }

    static func runAsync(_ request: [String: Any]) async -> [String: Any] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: run(request))
            }
        }
    }

    private static let script = #"""
import sys, json, os, hashlib

AUDIO_EXTS = (".mp3", ".m4a", ".flac", ".ogg", ".opus", ".wav")
KINDS = {".mp3": "mp3", ".m4a": "m4a", ".flac": "flac", ".ogg": "ogg", ".opus": "ogg"}
TEXT_KEYS = ("title", "artist", "album", "albumartist", "year", "track", "genre")


def first(v):
    if v is None:
        return ""
    if isinstance(v, (list, tuple)):
        return str(v[0]) if len(v) else ""
    return str(v)


def kind_of(path):
    return KINDS.get(os.path.splitext(path)[1].lower())


def mime_of(data):
    return "image/png" if data[:8] == b"\x89PNG\r\n\x1a\n" else "image/jpeg"


def blank(path, kind):
    return {
        "path": path, "kind": kind or "", "title": "", "artist": "", "album": "",
        "albumartist": "", "year": "", "track": "", "genre": "", "lyrics": "",
        "hasCover": False, "hasLyrics": False, "cover": "", "duration": 0,
        "bitrate": 0, "editable": kind is not None,
    }


def read(path, cover_dir=None):
    from mutagen import File

    k = kind_of(path)
    d = blank(path, k)
    if k is None:
        return d
    f = File(path)
    if f is None:
        d["editable"] = False
        return d

    info = getattr(f, "info", None)
    d["duration"] = int(getattr(info, "length", 0) or 0)
    d["bitrate"] = int((getattr(info, "bitrate", 0) or 0) / 1000)

    tags = f.tags
    pic = None

    if k == "mp3":
        def tx(key):
            fr = tags.get(key) if tags is not None else None
            try:
                return str(fr.text[0]) if fr is not None and fr.text else ""
            except Exception:
                return ""

        d["title"] = tx("TIT2")
        d["artist"] = tx("TPE1")
        d["album"] = tx("TALB")
        d["albumartist"] = tx("TPE2")
        d["year"] = (tx("TDRC") or tx("TYER"))[:4]
        d["track"] = tx("TRCK")
        d["genre"] = tx("TCON")
        if tags is not None:
            us = tags.getall("USLT")
            if us:
                d["lyrics"] = us[0].text
            ap = tags.getall("APIC")
            if ap:
                best = next((a for a in ap if a.type == 3), ap[0])
                pic = best.data

    elif k == "m4a":
        def g(key):
            return first(tags.get(key)) if tags is not None else ""

        d["title"] = g("\xa9nam")
        d["artist"] = g("\xa9ART")
        d["album"] = g("\xa9alb")
        d["albumartist"] = g("aART")
        d["year"] = g("\xa9day")[:4]
        d["genre"] = g("\xa9gen")
        d["lyrics"] = g("\xa9lyr")
        trk = tags.get("trkn") if tags is not None else None
        if trk:
            n, t = trk[0]
            d["track"] = ("%d/%d" % (n, t)) if t else str(n)
        cv = tags.get("covr") if tags is not None else None
        if cv:
            pic = bytes(cv[0])

    else:
        def g(key):
            return first(tags.get(key)) if tags is not None else ""

        d["title"] = g("title")
        d["artist"] = g("artist")
        d["album"] = g("album")
        d["albumartist"] = g("albumartist")
        d["year"] = g("date")[:4]
        d["track"] = g("tracknumber")
        d["genre"] = g("genre")
        d["lyrics"] = g("lyrics") or g("unsyncedlyrics")
        if k == "flac" and getattr(f, "pictures", None):
            pic = f.pictures[0].data

    d["hasLyrics"] = bool(str(d["lyrics"]).strip())
    if pic:
        d["hasCover"] = True
        if cover_dir:
            os.makedirs(cover_dir, exist_ok=True)
            key = "%s-%d" % (path, int(os.path.getmtime(path)))
            name = hashlib.md5(key.encode("utf-8")).hexdigest()
            name += ".png" if mime_of(pic) == "image/png" else ".jpg"
            out = os.path.join(cover_dir, name)
            if not os.path.isfile(out):
                with open(out, "wb") as fh:
                    fh.write(pic)
            d["cover"] = out
    return d


def scan(folder, cover_dir=None):
    out = []
    if not os.path.isdir(folder):
        return out
    for name in os.listdir(folder):
        if name.startswith("."):
            continue
        p = os.path.join(folder, name)
        if not os.path.isfile(p) or os.path.splitext(name)[1].lower() not in AUDIO_EXTS:
            continue
        try:
            d = read(p, cover_dir)
        except ImportError:
            raise
        except Exception:
            d = blank(p, None)
        d["lyrics"] = ""
        stat = os.stat(p)
        d["added"] = getattr(stat, "st_birthtime", stat.st_mtime)
        d["mtime"] = stat.st_mtime
        out.append(d)
    out.sort(key=lambda x: -x["mtime"])
    return out


def write(path, e):
    k = kind_of(path)
    if k is None:
        raise ValueError("This file format can't be edited")

    ca = e.get("coverAction", "keep")
    cover = None
    if ca == "set":
        with open(e["coverPath"], "rb") as fh:
            cover = fh.read()

    text = {}
    for key in TEXT_KEYS:
        if key in e:
            text[key] = (e.get(key) or "").strip()
    lyrics = None
    if "lyrics" in e:
        lyrics = (e.get("lyrics") or "").replace("\r\n", "\n").strip()

    result = {"ok": True}

    if k == "mp3":
        from mutagen.id3 import (ID3, ID3NoHeaderError, TIT2, TPE1, TALB, TPE2,
                                 TDRC, TRCK, TCON, USLT, APIC)
        try:
            tags = ID3(path)
        except ID3NoHeaderError:
            tags = ID3()

        frames = (("title", TIT2, "TIT2"), ("artist", TPE1, "TPE1"),
                  ("album", TALB, "TALB"), ("albumartist", TPE2, "TPE2"),
                  ("year", TDRC, "TDRC"), ("track", TRCK, "TRCK"),
                  ("genre", TCON, "TCON"))
        for key, cls, frame_id in frames:
            if key in text:
                tags.delall(frame_id)
                if key == "year":
                    tags.delall("TYER")
                if text[key]:
                    tags.add(cls(encoding=1, text=[text[key]]))
        if lyrics is not None:
            tags.delall("USLT")
            if lyrics:
                thai = any("\u0e00" <= c <= "\u0e7f" for c in lyrics)
                tags.add(USLT(encoding=1, lang="tha" if thai else "eng",
                              desc="", text=lyrics))
        if ca in ("set", "remove"):
            tags.delall("APIC")
        if ca == "set":
            tags.add(APIC(encoding=0, mime=mime_of(cover), type=3,
                          desc="Cover", data=cover))
        tags.save(path, v2_version=3)

    elif k == "m4a":
        from mutagen.mp4 import MP4, MP4Cover
        f = MP4(path)
        if f.tags is None:
            f.add_tags()
        t = f.tags

        def setk(key, val):
            if val:
                t[key] = [val]
            elif key in t:
                del t[key]

        names = {"title": "\xa9nam", "artist": "\xa9ART", "album": "\xa9alb",
                 "albumartist": "aART", "year": "\xa9day", "genre": "\xa9gen"}
        for key, atom in names.items():
            if key in text:
                setk(atom, text[key])
        if "track" in text:
            tr = text["track"]
            if tr:
                parts = tr.split("/")
                try:
                    n = int(parts[0])
                    total = int(parts[1]) if len(parts) > 1 and parts[1] else 0
                    t["trkn"] = [(n, total)]
                except ValueError:
                    pass
            elif "trkn" in t:
                del t["trkn"]
        if lyrics is not None:
            setk("\xa9lyr", lyrics)
        if ca in ("set", "remove") and "covr" in t:
            del t["covr"]
        if ca == "set":
            fmt = MP4Cover.FORMAT_PNG if mime_of(cover) == "image/png" else MP4Cover.FORMAT_JPEG
            t["covr"] = [MP4Cover(cover, imageformat=fmt)]
        f.save()

    else:
        from mutagen import File
        f = File(path)
        if f is None:
            raise ValueError("Unreadable file")
        if f.tags is None:
            f.add_tags()
        t = f.tags

        def setv(key, val):
            if val:
                t[key] = [val]
            elif key in t:
                del t[key]

        names = {"title": "title", "artist": "artist", "album": "album",
                 "albumartist": "albumartist", "year": "date",
                 "track": "tracknumber", "genre": "genre"}
        for key, field in names.items():
            if key in text:
                setv(field, text[key])
        if lyrics is not None:
            setv("lyrics", lyrics)
            if "unsyncedlyrics" in t:
                del t["unsyncedlyrics"]
        if k == "flac":
            if ca in ("set", "remove"):
                f.clear_pictures()
            if ca == "set":
                from mutagen.flac import Picture
                pic = Picture()
                pic.type = 3
                pic.mime = mime_of(cover)
                pic.desc = "Cover"
                pic.data = cover
                f.add_picture(pic)
        elif ca != "keep":
            result["warning"] = "Cover art isn't supported for OGG/Opus files"
        f.save()

    return result


def main():
    try:
        req = json.loads(sys.stdin.buffer.read().decode("utf-8"))
        action = req.get("action")
        if action == "ping":
            res = {"ok": True}
        elif action == "scan":
            res = {"files": scan(req["folder"], req.get("coverDir"))}
        elif action == "read":
            res = {"file": read(req["path"], req.get("coverDir"))}
        elif action == "write":
            res = write(req["path"], req["edits"])
        else:
            res = {"error": "Unknown action"}
    except ImportError:
        res = {"error": "The Python package mutagen is not installed", "missingModule": True}
    except Exception as ex:
        res = {"error": "%s: %s" % (type(ex).__name__, ex)}
    sys.stdout.write(json.dumps(res, ensure_ascii=True))
    sys.stdout.flush()


main()
"""#
}

