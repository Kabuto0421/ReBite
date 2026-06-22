# 2026-06-19: 小さく生成したSTOMP/SMASH画像から緑背景だけを抜く。
from pathlib import Path
from PIL import Image


SOURCE_FILES = {
    "memory_text_stomp_down.png": Path("work/memory_bite_stage1/assets/ui/memory_text/source/memory_text_stomp_direct_source.png"),
    "memory_text_smash.png": Path("work/memory_bite_stage1/assets/ui/memory_text/source/memory_text_smash_direct_source.png"),
}
OUT_DIRS = [
    Path("work/memory_bite_stage1/assets/ui/memory_text"),
    Path("outputs/memory_bite_stage1/assets/ui/memory_text"),
    Path("outputs/memory_bite_stage1/previews/text_sprites"),
]
TARGET_SIZE = (72, 18)
EXISTING_PREVIEW_ORDER = [
    "memory_text_dash_left.png",
    "memory_text_dash_right.png",
    "memory_text_hop_up.png",
    "memory_text_bite.png",
    "memory_text_shoot_left.png",
    "memory_text_shoot_right.png",
    "memory_text_stomp_down.png",
    "memory_text_smash.png",
]


def is_green_background(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a <= 0:
        return False
    return g > 120 and g > r * 2.8 and g > b * 2.8


def remove_green_background(image: Image.Image) -> Image.Image:
    output = image.convert("RGBA")
    if output.size != TARGET_SIZE:
        output = output.resize(TARGET_SIZE, Image.Resampling.NEAREST)
    pixels = output.load()
    for y in range(output.height):
        for x in range(output.width):
            if is_green_background(pixels[x, y]):
                pixels[x, y] = (0, 0, 0, 0)
    return output


def shift_content(image: Image.Image, offset: tuple[int, int]) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return image
    cropped = image.crop(bbox)
    x = min(max(0, (TARGET_SIZE[0] - cropped.width) // 2 + offset[0]), TARGET_SIZE[0] - cropped.width)
    y = min(max(0, (TARGET_SIZE[1] - cropped.height) // 2 + offset[1]), TARGET_SIZE[1] - cropped.height)
    output = Image.new("RGBA", TARGET_SIZE, (0, 0, 0, 0))
    output.alpha_composite(cropped, (x, y))
    return output


def make_preview_sheet() -> Image.Image:
    sprites: list[Image.Image] = []
    for file_name in EXISTING_PREVIEW_ORDER:
        path = Path("work/memory_bite_stage1/assets/ui/memory_text") / file_name
        sprites.append(Image.open(path).convert("RGBA"))

    sheet = Image.new("RGBA", (TARGET_SIZE[0] * 2 + 16, TARGET_SIZE[1] * 4 + 16 * 3), (8, 10, 16, 255))
    for index, sprite in enumerate(sprites):
        x = (index % 2) * (TARGET_SIZE[0] + 16)
        y = (index // 2) * (TARGET_SIZE[1] + 16)
        sheet.alpha_composite(sprite, (x, y))
    return sheet


def make_on_tag_preview(stomp: Image.Image, smash: Image.Image) -> Image.Image:
    plaque = Image.open("work/memory_bite_stage1/assets/ui/memory_tag_plaque.png").convert("RGBA")
    plaque = plaque.resize((round(plaque.width * 0.05), round(plaque.height * 0.05)), Image.Resampling.NEAREST)
    preview = Image.new("RGBA", (plaque.width * 2 + 18, plaque.height), (8, 10, 16, 255))
    for index, sprite in enumerate([stomp, smash]):
        base = plaque.copy()
        text = sprite.resize((round(TARGET_SIZE[0] * 0.7), round(TARGET_SIZE[1] * 0.7)), Image.Resampling.NEAREST)
        base.alpha_composite(text, ((base.width - text.width) // 2, (base.height - text.height) // 2))
        preview.alpha_composite(base, (index * (plaque.width + 18), 0))
    return preview


def main() -> None:
    sprites = {
        file_name: remove_green_background(Image.open(source_path))
        for file_name, source_path in SOURCE_FILES.items()
    }
    sprites["memory_text_smash.png"] = shift_content(sprites["memory_text_smash.png"], (2, 0))

    for out_dir in OUT_DIRS:
        out_dir.mkdir(parents=True, exist_ok=True)
        for file_name, sprite in sprites.items():
            sprite.save(out_dir / file_name)

    preview_sheet = make_preview_sheet()
    on_tag_preview = make_on_tag_preview(sprites["memory_text_stomp_down.png"], sprites["memory_text_smash.png"])
    for out_dir in OUT_DIRS:
        preview_sheet.save(out_dir / "memory_text_preview_sheet.png")
    Path("outputs/memory_bite_stage1/previews/text_sprites").mkdir(parents=True, exist_ok=True)
    on_tag_preview.save("outputs/memory_bite_stage1/previews/text_sprites/memory_text_stomp_smash_on_tag_preview.png")


if __name__ == "__main__":
    main()
