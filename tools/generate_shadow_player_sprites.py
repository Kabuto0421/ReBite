#!/usr/bin/env python3
"""Generate black shadow-player sprites from the existing player frames."""

from pathlib import Path
from PIL import Image
from collections import deque


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "assets" / "player"
OUTPUT_ROOT = ROOT / "assets" / "player_shadow"
ANIMATIONS = ("walk", "bite")
BODY_COLOR = (4, 3, 10)
EDGE_COLOR = (20, 54, 92)
EDGE_HIGHLIGHT_COLOR = (38, 88, 138)
EYE_COLOR = (255, 18, 12)


def find_eye_pixels(image: Image.Image) -> set[tuple[int, int]]:
    pixels = image.load()
    width, height = image.size
    candidates: set[tuple[int, int]] = set()

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if not (a > 180 and r < 70 and g < 70 and b < 85):
                continue
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or nx >= width or ny < 0 or ny >= height or pixels[nx, ny][3] == 0:
                    edge = True
                    break
            if not edge:
                candidates.add((x, y))

    components = []
    while candidates:
        start = candidates.pop()
        queue = deque([start])
        points = [start]
        while queue:
            x, y = queue.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                point = (x + dx, y + dy)
                if point in candidates:
                    candidates.remove(point)
                    queue.append(point)
                    points.append(point)
        xs = [point[0] for point in points]
        ys = [point[1] for point in points]
        bbox = (min(xs), min(ys), max(xs), max(ys))
        width_px = bbox[2] - bbox[0] + 1
        height_px = bbox[3] - bbox[1] + 1
        if len(points) <= 4 and width_px <= 3 and height_px <= 3 and bbox[1] < image.size[1] * 0.58:
            center = (sum(xs) / len(xs), sum(ys) / len(ys))
            components.append({"points": points, "center": center, "bbox": bbox})

    best_pair = None
    best_score = 999999.0
    for i, left in enumerate(components):
        for right in components[i + 1:]:
            lx, ly = left["center"]
            rx, ry = right["center"]
            if lx > rx:
                lx, ly, rx, ry = rx, ry, lx, ly
                left, right = right, left
            dx = rx - lx
            dy = abs(ry - ly)
            if dx < 6.0 or dx > 13.0 or dy > 4.0:
                continue
            center_x = (lx + rx) * 0.5
            center_y = (ly + ry) * 0.5
            score = center_y * 2.0 + abs(center_x - 26.5) * 0.45 + abs(dx - 9.0) * 1.4 + dy * 1.8
            if score < best_score:
                best_score = score
                best_pair = (left, right)

    if best_pair == None:
        return set()
    return set(best_pair[0]["points"] + best_pair[1]["points"])


def convert_frame(source_path: Path, output_path: Path) -> None:
    image = Image.open(source_path).convert("RGBA")
    eye_pixels = find_eye_pixels(image)
    pixels = image.load()
    width, height = image.size

    alpha_mask = [[pixels[x, y][3] > 0 for x in range(width)] for y in range(height)]
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            brightness = (r + g + b) / 765.0
            edge = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or nx >= width or ny < 0 or ny >= height or not alpha_mask[ny][nx]:
                    edge = True
                    break
            base = EDGE_COLOR if edge else BODY_COLOR
            shade = int(18 * brightness)
            pixels[x, y] = (
                min(255, base[0] + shade),
                min(255, base[1] + shade),
                min(255, base[2] + shade),
                a,
            )

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            touches_empty = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if nx < 0 or nx >= width or ny < 0 or ny >= height or pixels[nx, ny][3] == 0:
                    touches_empty = True
                    break
            if touches_empty:
                pixels[x, y] = (*EDGE_HIGHLIGHT_COLOR, a)

    if not eye_pixels:
        raise RuntimeError(f"Could not find eye pixels in {source_path}")
    for x, y in eye_pixels:
        pixels[x, y] = (*EYE_COLOR, pixels[x, y][3])

    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)


def main() -> None:
    for animation in ANIMATIONS:
        for source_path in sorted((SOURCE_ROOT / animation).glob("*.png")):
            convert_frame(source_path, OUTPUT_ROOT / animation / source_path.name)
    print(f"Generated shadow sprites under {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
