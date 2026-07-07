from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "ui" / "title"
PREVIEW = ROOT / "tmp" / "title_preview"
FONT_PATH = "/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf"

GOLD = (255, 222, 92, 255)
GOLD_LIGHT = (255, 248, 184, 230)
GOLD_DARK = (154, 88, 22, 255)
PURPLE_DARK = (19, 8, 31, 255)
PURPLE_MID = (68, 24, 94, 255)
PURPLE_HI = (126, 58, 168, 255)
INK = (16, 8, 25, 255)


def pixelate(image: Image.Image, factor: int = 2) -> Image.Image:
    small = image.resize((max(1, image.width // factor), max(1, image.height // factor)), Image.Resampling.BOX)
    return small.resize(image.size, Image.Resampling.NEAREST)


def draw_pixel_text(text: str, filename: str, low_font_size: int, final_size: tuple[int, int], scale: int = 3) -> None:
    low_size = (final_size[0] // scale, final_size[1] // scale)
    low = Image.new("RGBA", low_size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(low)
    font = ImageFont.truetype(FONT_PATH, low_font_size)
    bbox = draw.textbbox((0, 0), text, font=font, stroke_width=1)
    x = (low.width - (bbox[2] - bbox[0])) // 2 - bbox[0]
    y = (low.height - (bbox[3] - bbox[1])) // 2 - bbox[1]

    draw.text((x + 1, y + 1), text, font=font, fill=(0, 0, 0, 150), stroke_width=2, stroke_fill=(0, 0, 0, 150))
    draw.text((x, y), text, font=font, fill=GOLD, stroke_width=2, stroke_fill=(20, 8, 31, 255))
    draw.text((x, y - 1), text, font=font, fill=GOLD_LIGHT)

    high = low.resize(final_size, Image.Resampling.NEAREST)
    high.save(OUT / filename)


def draw_button_frame() -> None:
    size = (392, 124)
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    draw.rectangle((28, 32, 382, 116), fill=(8, 5, 14, 180))
    draw.rectangle((18, 10, 366, 100), fill=INK)
    draw.rectangle((24, 16, 360, 94), fill=GOLD_DARK)
    draw.rectangle((30, 22, 354, 88), fill=PURPLE_DARK)
    draw.rectangle((38, 30, 346, 80), fill=PURPLE_MID)
    draw.rectangle((44, 36, 340, 74), fill=(36, 15, 55, 255))
    draw.line((42, 32, 342, 32), fill=(236, 196, 74, 230), width=3)
    draw.line((42, 78, 342, 78), fill=(9, 4, 16, 240), width=4)
    draw.line((31, 23, 31, 87), fill=(255, 241, 132, 200), width=2)
    draw.line((353, 23, 353, 87), fill=(37, 14, 55, 240), width=3)

    for x in range(50, 320, 22):
        top_color = PURPLE_HI if (x // 22) % 2 else (91, 38, 126, 255)
        draw.rectangle((x, 18, x + 12, 24), fill=top_color)
        draw.rectangle((x, 86, x + 12, 92), fill=(21, 8, 33, 255))

    for x in (31, 353):
        draw.polygon([(x, 27), (x + 24, 55), (x, 83), (x - 24, 55)], fill=(255, 180, 29, 255), outline=INK)
        draw.polygon([(x, 39), (x + 12, 55), (x, 71), (x - 12, 55)], fill=(255, 245, 119, 220))

    cracks = [
        [(91, 37), (104, 48), (98, 59), (119, 73)],
        [(252, 31), (238, 45), (258, 55), (246, 70), (267, 78)],
        [(306, 39), (296, 50), (308, 62)],
    ]
    for crack in cracks:
        draw.line(crack, fill=(11, 5, 18, 230), width=3)
        draw.line([(x + 1, y) for x, y in crack], fill=(219, 178, 82, 100), width=1)

    image = pixelate(image, 2)
    image.save(OUT / "title_button_frame.png")


def draw_floor_tile() -> None:
    image = Image.new("RGBA", (48, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((1, 3, 46, 30), fill=(48, 22, 71, 255), outline=(13, 7, 22, 255))
    draw.line((3, 5, 44, 5), fill=(112, 54, 151, 255), width=2)
    draw.line((4, 28, 44, 28), fill=(18, 8, 31, 255), width=2)
    draw.rectangle((5, 7, 23, 17), fill=(65, 31, 94, 255))
    draw.rectangle((25, 8, 42, 18), fill=(57, 26, 83, 255))
    draw.rectangle((8, 19, 29, 27), fill=(58, 27, 85, 255))
    draw.line((31, 13, 36, 17, 33, 23), fill=(23, 9, 34, 220), width=2)
    draw.line((12, 9, 17, 12, 15, 16), fill=(132, 66, 175, 160), width=1)
    pixelate(image, 2).save(OUT / "title_floor_tile.png")


def draw_settings_panel() -> None:
    image = Image.new("RGBA", (560, 330), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((22, 26, 548, 324), fill=(7, 4, 13, 180))
    draw.rectangle((10, 8, 536, 306), fill=INK)
    draw.rectangle((18, 16, 528, 298), fill=GOLD_DARK)
    draw.rectangle((26, 24, 520, 290), fill=(24, 10, 37, 245))
    draw.rectangle((40, 42, 506, 274), fill=(43, 18, 63, 238))
    draw.line((36, 36, 510, 36), fill=(255, 236, 114, 220), width=3)
    draw.line((38, 278, 510, 278), fill=(10, 5, 17, 230), width=5)
    for x in range(58, 470, 34):
        draw.rectangle((x, 25, x + 18, 32), fill=(128, 58, 170, 255))
        draw.rectangle((x, 282, x + 18, 289), fill=(18, 7, 29, 255))
    pixelate(image, 2).save(OUT / "title_settings_panel.png")


def draw_slider_assets() -> None:
    frame = Image.new("RGBA", (330, 36), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    draw.rectangle((8, 12, 322, 28), fill=INK)
    draw.rectangle((14, 15, 316, 25), fill=(39, 16, 57, 255), outline=GOLD_DARK)
    draw.line((16, 17, 314, 17), fill=(108, 50, 145, 255), width=2)
    pixelate(frame, 2).save(OUT / "title_slider_frame.png")

    fill = Image.new("RGBA", (300, 10), (0, 0, 0, 0))
    fill_draw = ImageDraw.Draw(fill)
    fill_draw.rectangle((0, 0, 299, 9), fill=(255, 187, 41, 255))
    fill_draw.line((0, 1, 299, 1), fill=(255, 249, 137, 230), width=2)
    fill_draw.line((0, 8, 299, 8), fill=(138, 74, 20, 230), width=2)
    pixelate(fill, 2).save(OUT / "title_slider_fill.png")

    knob = Image.new("RGBA", (34, 42), (0, 0, 0, 0))
    knob_draw = ImageDraw.Draw(knob)
    knob_draw.rectangle((11, 3, 25, 37), fill=INK)
    knob_draw.rectangle((7, 8, 29, 32), fill=GOLD_DARK)
    knob_draw.rectangle((11, 12, 25, 28), fill=GOLD)
    knob_draw.line((12, 13, 24, 13), fill=GOLD_LIGHT, width=2)
    pixelate(knob, 2).save(OUT / "title_slider_knob.png")


def make_preview() -> None:
    preview = Image.new("RGBA", (960, 540), (9, 10, 18, 255))
    logo = Image.open(OUT / "rebite_title_logo.png").convert("RGBA")
    logo.thumbnail((720, 310), Image.Resampling.LANCZOS)
    preview.alpha_composite(logo, ((preview.width - logo.width) // 2, 18))

    tile = Image.open(OUT / "title_floor_tile.png").convert("RGBA")
    for y in range(432, 540, 32):
        for x in range(-16, 976, 48):
            preview.alpha_composite(tile, (x, y))

    frame = Image.open(OUT / "title_button_frame.png").convert("RGBA")
    play = Image.open(OUT / "title_text_play.png").convert("RGBA")
    options = Image.open(OUT / "title_text_options.png").convert("RGBA")
    for y, text_img in [(322, play), (432, options)]:
        x = (preview.width - frame.width) // 2
        preview.alpha_composite(frame, (x, y))
        preview.alpha_composite(text_img, (x + (frame.width - text_img.width) // 2, y + (frame.height - text_img.height) // 2 - 2))

    PREVIEW.mkdir(parents=True, exist_ok=True)
    preview.convert("RGB").save(PREVIEW / "title_layout_asset_preview.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    draw_button_frame()
    draw_floor_tile()
    draw_settings_panel()
    draw_slider_assets()
    make_preview()


if __name__ == "__main__":
    main()
