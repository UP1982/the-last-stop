"""Small lossless PNG codec for asset checks/imports; Python standard library only.

Supports the pack's 8-bit non-interlaced RGB and RGBA PNGs. RGB is expanded
to RGBA with alpha 255. Validates chunk CRCs and all five PNG row filters.
"""
import struct
import zlib


def read_png(path):
    raw = path.read_bytes()
    if raw[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('Not a PNG: %s' % path)
    pos, compressed, header, ended = 8, bytearray(), None, False
    while pos < len(raw):
        if pos + 12 > len(raw):
            raise ValueError('Truncated PNG chunk')
        size = struct.unpack('>I', raw[pos:pos+4])[0]
        kind, data = raw[pos+4:pos+8], raw[pos+8:pos+8+size]
        end = pos + 12 + size
        if end > len(raw) or zlib.crc32(kind + data) & 0xffffffff != struct.unpack('>I', raw[end-4:end])[0]:
            raise ValueError('Truncated chunk or CRC mismatch: %s' % path)
        if kind == b'IHDR':
            header = struct.unpack('>IIBBBBB', data)
        elif kind == b'IDAT':
            compressed.extend(data)
        elif kind == b'IEND':
            ended = True
            break
        elif kind[:1].isupper() and kind != b'PLTE':
            raise ValueError('Unsupported critical PNG chunk: %r' % kind)
        pos = end
    if not header or not ended:
        raise ValueError('Missing PNG header/end')
    w, h, depth, color, compression, filtering, interlace = header
    if not (w > 0 and h > 0 and depth == 8 and color in (2, 6) and compression == filtering == interlace == 0):
        raise ValueError('Expected noninterlaced 8-bit RGB/RGBA PNG')
    channels = 4 if color == 6 else 3
    stride = w * channels
    decoded = zlib.decompress(compressed)
    if len(decoded) != h * (stride + 1):
        raise ValueError('Wrong PNG scanline length')
    pixels, previous = bytearray(), bytearray(stride)
    for y in range(h):
        offset = y * (stride + 1)
        mode, row = decoded[offset], bytearray(decoded[offset+1:offset+1+stride])
        if mode > 4:
            raise ValueError('Unknown PNG filter')
        for x in range(stride):
            a = row[x-channels] if x >= channels else 0
            b = previous[x]
            c = previous[x-channels] if x >= channels else 0
            if mode == 4:
                p = a + b - c
                da, db, dc = abs(p-a), abs(p-b), abs(p-c)
                delta = a if da <= db and da <= dc else b if db <= dc else c
            else:
                delta = (0, a, b, (a+b)//2)[mode]
            row[x] = (row[x] + delta) & 255
        if channels == 4:
            pixels.extend(row)
        else:
            for x in range(0, stride, 3):
                pixels.extend(row[x:x+3] + b'\xff')
        previous = row
    return w, h, pixels


def write_png(path, image):
    w, h, pixels = image
    if len(pixels) != w * h * 4:
        raise ValueError('Wrong RGBA length')
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    rows = b''.join(b'\x00' + pixels[y*w*4:(y+1)*w*4] for y in range(h))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))
