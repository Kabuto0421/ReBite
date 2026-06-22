from pathlib import Path
from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SOURCE = PROJECT_ROOT / "assets/ui/memory_text/source/memory_text_actions_source.png"
OUT_DIRS = [
    PROJECT_ROOT / "assets/ui/memory_text",
    PROJECT_ROOT / "previews/text_sprites",
]

LABELS = [
    ("memory_text_dash_left.png", (0, 0)),
    ("memory_text_hop_up.png", (1, 0)),
    ("memory_text_bite.png", (0, 1)),
    ("memory_text_shoot_left.png", (1, 1)),
]

TARGET_SIZE = (72, 18)
CONTENT_SIZE = (66, 14)
KEY_COLOR = (0, 255, 0)


def remove_green_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            green_distance = abs(r - KEY_COLOR[0]) + abs(g - KEY_COLOR[1]) + abs(b - KEY_COLOR[2])
            if g > 180 and r < 90 and b < 90 and green_distance < 180:
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def crop_alpha(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return image
    return image.crop(bbox)


def fit_to_tag(image: Image.Image) -> Image.Image:
    cropped = crop_alpha(image)
    scale = min(CONTENT_SIZE[0] / cropped.width, CONTENT_SIZE[1] / cropped.height)
    new_size = (
        max(1, int(round(cropped.width * scale))),
        max(1, int(round(cropped.height * scale))),
    )
    resized = cropped.resize(new_size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((TARGET_SIZE[0] - resized.width) // 2, (TARGET_SIZE[1] - resized.height) // 2))
    return canvas


def main() -> None:
    source = remove_green_background(Image.open(SOURCE))
    cell_w = source.width // 2
    cell_h = source.height // 2
    processed = []
    for file_name, (col, row) in LABELS:
        cell = source.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
        sprite = fit_to_tag(cell)
        processed.append((file_name, sprite))
        for out_dir in OUT_DIRS:
            out_dir.mkdir(parents=True, exist_ok=True)
            sprite.save(out_dir / file_name)

    sheet = Image.new("RGBA", (TARGET_SIZE[0] * 2 + 16, TARGET_SIZE[1] * 2 + 16), (8, 10, 16, 255))
    for index, (_file_name, sprite) in enumerate(processed):
        x = (index % 2) * (TARGET_SIZE[0] + 16)
        y = (index // 2) * (TARGET_SIZE[1] + 16)
        sheet.alpha_composite(sprite, (x, y))
    for out_dir in OUT_DIRS:
        sheet.save(out_dir / "memory_text_preview_sheet.png")


if __name__ == "__main__":
    main()
