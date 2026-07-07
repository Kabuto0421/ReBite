from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "ui" / "title" / "title_text_imagen_sheet_source.png"
OUT = ROOT / "assets" / "ui" / "title"

OUTPUTS = {
    "PLAY": ("title_text_play.png", (160, 62)),
    "OPTIONS": ("title_text_options.png", (228, 62)),
    "CLOSE": ("title_text_back.png", (166, 60)),
    "BGM": ("title_text_bgm.png", (96, 44)),
    "SE": ("title_text_se.png", (62, 44)),
    "BITE": ("title_text_bite_hint.png", (68, 34)),
}


def is_green(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _a = pixel
    return g > 120 and g > r * 1.45 and g > b * 1.45


def find_components(image: Image.Image) -> list[tuple[int, int, int, int]]:
    pixels = image.load()
    width, height = image.size
    visited = bytearray(width * height)
    boxes: list[tuple[int, int, int, int]] = []
    for y in range(height):
        for x in range(width):
            index = y * width + x
            if visited[index] or is_green(pixels[x, y]):
                visited[index] = 1
                continue
            queue = deque([(x, y)])
            visited[index] = 1
            min_x = max_x = x
            min_y = max_y = y
            count = 0
            while queue:
                cx, cy = queue.popleft()
                count += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    next_index = ny * width + nx
                    if visited[next_index]:
                        continue
                    visited[next_index] = 1
                    if not is_green(pixels[nx, ny]):
                        queue.append((nx, ny))
            if count > 200:
                boxes.append((min_x, min_y, max_x + 1, max_y + 1))
    return boxes


def merge_nearby_boxes(boxes: list[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
    merged: list[tuple[int, int, int, int]] = []
    for box in boxes:
        x1, y1, x2, y2 = box
        added = False
        for i, other in enumerate(merged):
            ox1, oy1, ox2, oy2 = other
            same_row = abs(((y1 + y2) / 2.0) - ((oy1 + oy2) / 2.0)) < 120
            close_x = x1 <= ox2 + 80 and ox1 <= x2 + 80
            if same_row and close_x:
                merged[i] = (min(x1, ox1), min(y1, oy1), max(x2, ox2), max(y2, oy2))
                added = True
                break
        if not added:
            merged.append(box)
    if len(merged) != len(boxes):
        return merge_nearby_boxes(merged)
    return merged


def remove_green(crop: Image.Image) -> Image.Image:
    result = crop.convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            r, g, b, a = pixels[x, y]
            if is_green((r, g, b, a)):
                pixels[x, y] = (0, 0, 0, 0)
    return result


def fit(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    scale = min(max_size[0] / image.width, max_size[1] / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(size, Image.Resampling.LANCZOS)


def main() -> None:
    image = Image.open(SOURCE).convert("RGBA")
    boxes = merge_nearby_boxes(find_components(image))
    boxes.sort(key=lambda b: (b[1] // 260, b[0]))
    labels = ["PLAY", "OPTIONS", "CLOSE", "BGM", "SE", "BITE"]
    if len(boxes) < len(labels):
        raise RuntimeError(f"Expected at least {len(labels)} text boxes, got {len(boxes)}")

    for label, box in zip(labels, boxes[: len(labels)]):
        x1, y1, x2, y2 = box
        pad = 16
        x1 = max(0, x1 - pad)
        y1 = max(0, y1 - pad)
        x2 = min(image.width, x2 + pad)
        y2 = min(image.height, y2 + pad)
        crop = remove_green(image.crop((x1, y1, x2, y2)))
        filename, max_size = OUTPUTS[label]
        fit(crop, max_size).save(OUT / filename)
        print(label, OUT / filename)


if __name__ == "__main__":
    main()
