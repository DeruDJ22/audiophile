import 'dart:io';
import 'dart:typed_data';

class CoverArtService {
  static final Map<String, Uint8List?> _artCache = {};

  /// Asynchronously extracts embedded album art (JPEG/PNG) from an audio file.
  static Future<Uint8List?> getCoverArt(String filePath) async {
    if (_artCache.containsKey(filePath)) {
      return _artCache[filePath];
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _artCache[filePath] = null;
        return null;
      }

      final length = await file.length();
      // Read first 1MB of file for metadata tags
      final readLength = length < 1048576 ? length : 1048576;
      final raf = await file.open(mode: FileMode.read);
      final bytes = await raf.read(readLength);
      await raf.close();

      Uint8List? art = _extractFlacPicture(bytes) ??
          _extractID3v2Apic(bytes) ??
          _scanImageMagicBytes(bytes);

      _artCache[filePath] = art;
      return art;
    } catch (e) {
      _artCache[filePath] = null;
      return null;
    }
  }

  /// Extract FLAC Picture block (Block type 6)
  static Uint8List? _extractFlacPicture(Uint8List bytes) {
    if (bytes.length < 4) return null;
    // Check 'fLaC' signature
    if (bytes[0] != 0x66 || bytes[1] != 0x4C || bytes[2] != 0x61 || bytes[3] != 0x43) {
      return null;
    }

    int pos = 4;
    while (pos + 4 < bytes.length) {
      final headerByte = bytes[pos];
      final isLast = (headerByte & 0x80) != 0;
      final blockType = headerByte & 0x7F;
      final blockLen = (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3];
      pos += 4;

      if (pos + blockLen > bytes.length) break;

      if (blockType == 6) {
        // Picture block
        try {
          int p = pos + 4; // skip picture type (4 bytes)
          final mimeLen = _readUint32BE(bytes, p);
          p += 4 + mimeLen; // skip mime
          final descLen = _readUint32BE(bytes, p);
          p += 4 + descLen; // skip desc
          p += 16; // skip width, height, depth, colors (4*4 = 16 bytes)
          final dataLen = _readUint32BE(bytes, p);
          p += 4;

          if (p + dataLen <= pos + blockLen) {
            return bytes.sublist(p, p + dataLen);
          }
        } catch (_) {}
      }

      pos += blockLen;
      if (isLast) break;
    }
    return null;
  }

  /// Extract ID3v2 APIC frame
  static Uint8List? _extractID3v2Apic(Uint8List bytes) {
    if (bytes.length < 10) return null;
    // Check 'ID3' signature
    if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) return null;

    final version = bytes[3];
    final tagSize = _readSynchsafeInt(bytes, 6);
    if (tagSize <= 0) return null;

    int pos = 10;
    final maxPos = (pos + tagSize < bytes.length) ? pos + tagSize : bytes.length;

    while (pos + 10 < maxPos) {
      String frameId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      int frameSize = 0;
      if (version == 4) {
        frameSize = _readSynchsafeInt(bytes, pos + 4);
      } else {
        frameSize = _readUint32BE(bytes, pos + 4);
      }

      pos += 10;
      if (frameSize <= 0 || pos + frameSize > maxPos) break;

      if (frameId == 'APIC') {
        try {
          int p = pos;
          final encoding = bytes[p++];
          // Skip MIME type string
          while (p < pos + frameSize && bytes[p] != 0) {
            p++;
          }
          p++; // skip null terminator
          p++; // skip picture type

          // Skip Description string
          if (encoding == 1 || encoding == 2) {
            // UTF-16
            while (p + 1 < pos + frameSize && (bytes[p] != 0 || bytes[p + 1] != 0)) {
              p += 2;
            }
            p += 2;
          } else {
            // ISO-8859-1 or UTF-8
            while (p < pos + frameSize && bytes[p] != 0) {
              p++;
            }
            p++;
          }

          if (p < pos + frameSize) {
            return bytes.sublist(p, pos + frameSize);
          }
        } catch (_) {}
      }

      pos += frameSize;
    }
    return null;
  }

  /// Scan binary header for JPEG or PNG magic bytes as fallback
  static Uint8List? _scanImageMagicBytes(Uint8List bytes) {
    for (int i = 0; i < bytes.length - 8; i++) {
      // PNG header: 89 50 4E 47 0D 0A 1A 0A
      if (bytes[i] == 0x89 &&
          bytes[i + 1] == 0x50 &&
          bytes[i + 2] == 0x4E &&
          bytes[i + 3] == 0x47 &&
          bytes[i + 4] == 0x0D &&
          bytes[i + 5] == 0x0A &&
          bytes[i + 6] == 0x1A &&
          bytes[i + 7] == 0x0A) {
        // Find PNG IEND chunk to determine end
        for (int j = i + 8; j < bytes.length - 4; j++) {
          if (bytes[j] == 0x49 && bytes[j + 1] == 0x45 && bytes[j + 2] == 0x4E && bytes[j + 3] == 0x44) {
            return bytes.sublist(i, j + 8);
          }
        }
        return bytes.sublist(i);
      }

      // JPEG header: FF D8 FF
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8 && bytes[i + 2] == 0xFF) {
        // Find JPEG EOI (FF D9)
        for (int j = i + 2; j < bytes.length - 1; j++) {
          if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) {
            return bytes.sublist(i, j + 2);
          }
        }
        // Limit max JPEG slice if EOI truncated
        int maxLen = bytes.length - i;
        if (maxLen > 524288) maxLen = 524288;
        return bytes.sublist(i, i + maxLen);
      }
    }
    return null;
  }

  static int _readUint32BE(Uint8List b, int offset) {
    return (b[offset] << 24) | (b[offset + 1] << 16) | (b[offset + 2] << 8) | b[offset + 3];
  }

  static int _readSynchsafeInt(Uint8List b, int offset) {
    return (b[offset] & 0x7F) << 21 |
        (b[offset + 1] & 0x7F) << 14 |
        (b[offset + 2] & 0x7F) << 7 |
        (b[offset + 3] & 0x7F);
  }
}
