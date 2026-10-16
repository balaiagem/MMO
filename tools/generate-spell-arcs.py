"""Build segmented spell-slot lanes from Tibia's original mana arc."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "client/data/images/game/spellslots"
SOURCE = ROOT / "client/data/images/game/healthcircle/right_full.png"


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)


def read_rgba_png(path: Path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    offset, compressed = 8, bytearray()
    width = height = bit_depth = color_type = None
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        chunk = data[offset + 8:offset + 8 + length]
        offset += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", chunk)
            if bit_depth != 8 or color_type != 6 or interlace != 0:
                raise ValueError("The Tibia mana arc must be a non-interlaced RGBA PNG")
        elif kind == b"IDAT":
            compressed.extend(chunk)
        elif kind == b"IEND":
            break
    if not width or not height:
        raise ValueError(f"Missing PNG dimensions: {path}")

    raw = zlib.decompress(compressed)
    stride, bpp = width * 4, 4
    rows, previous, cursor = [], bytearray(width * 4), 0
    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row = bytearray(raw[cursor:cursor + stride])
        cursor += stride
        for index in range(stride):
            left = row[index - bpp] if index >= bpp else 0
            above = previous[index]
            upper_left = previous[index - bpp] if index >= bpp else 0
            if filter_type == 1:
                row[index] = (row[index] + left) & 255
            elif filter_type == 2:
                row[index] = (row[index] + above) & 255
            elif filter_type == 3:
                row[index] = (row[index] + ((left + above) // 2)) & 255
            elif filter_type == 4:
                p = left + above - upper_left
                pa, pb, pc = abs(p - left), abs(p - above), abs(p - upper_left)
                predictor = left if pa <= pb and pa <= pc else above if pb <= pc else upper_left
                row[index] = (row[index] + predictor) & 255
            elif filter_type != 0:
                raise ValueError(f"Unsupported PNG filter: {filter_type}")
        rows.append(row)
        previous = row
    return width, height, rows


def write_png(path: Path, width: int, height: int, pixels) -> None:
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for pixel in pixels[y * width:(y + 1) * width]:
            rows.extend(pixel)
    data = b"\x89PNG\r\n\x1a\n"
    data += png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    data += png_chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    data += png_chunk(b"IEND", b"")
    path.write_bytes(data)


def make_lane(source_rows, width: int, height: int, level: int, capacity: int, available: int) -> None:
    colors = {
        1: ((63, 146, 234), (28, 63, 103)),
        2: ((155, 100, 205), (76, 48, 99)),
        3: ((221, 112, 177), (103, 48, 78)),
    }
    filled, spent = colors[level]
    output = [(0, 0, 0, 0)] * (width * height)

    for y, source_row in enumerate(source_rows):
        occupied = [x for x in range(width) if source_row[x * 4 + 3] > 0]
        if not occupied:
            continue
        left, right = occupied[0], occupied[-1]
        span = max(1, right - left + 1)

        # Let the upper tip finish as a clean level-one cap before the three
        # narrow color lanes separate; otherwise pixel rounding leaves a jagged seam.
        if y < 6 and span < 16:
            if level == 1:
                slot_color = filled if available > 0 else spent
                for x in occupied:
                    i = x * 4
                    red, green, blue, alpha = source_row[i:i + 4]
                    color = (8, 15, 20) if max(red, green, blue) < 80 else slot_color
                    output[y * width + x] = (*color, alpha)
            continue

        for x in occupied:
            source_index = x * 4
            red, green, blue, alpha = source_row[source_index:source_index + 4]
            lane = min(2, (x - left) * 3 // span)
            if lane != level - 1:
                continue

            # Retain Tibia's original dark outline pixels and tint its exact arc mask.
            if max(red, green, blue) < 80:
                color = (8, 15, 20)
            else:
                slot = min(capacity - 1, y * capacity // height)
                color = filled if slot < available else spent
            output[y * width + x] = (*color, alpha)

        # Divide each level lane with subtle horizontal slot marks, like the source arc.
        for boundary in range(1, capacity):
            if y != round(boundary * height / capacity):
                continue
            for x in occupied:
                lane = min(2, (x - left) * 3 // span)
                if lane == level - 1:
                    source_index = x * 4
                    alpha = source_row[source_index + 3]
                    if alpha:
                        output[y * width + x] = (8, 15, 20, alpha)

    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / f"spellbar-l{level}-c{capacity}-a{available}.png", width, height, output)


def main() -> None:
    width, height, rows = read_rgba_png(SOURCE)
    for level, capacity in ((1, 4), (2, 3), (3, 2)):
        for available in range(capacity + 1):
            make_lane(rows, width, height, level, capacity, available)
    print(f"Generated segmented spell arcs from Tibia's mana bar in {OUT}")


if __name__ == "__main__":
    main()
