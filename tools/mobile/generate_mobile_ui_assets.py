from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "mobile"
SOURCE = OUT / "bite_button_source.png"


def remove_black_background(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            r, g, b, a = pixels[x, y]
            brightness = max(r, g, b)
            if brightness < 10:
                pixels[x, y] = (0, 0, 0, 0)
            elif brightness < 30:
                pixels[x, y] = (r, g, b, int(a * (brightness - 10) / 20.0))
    return result


def save_bite_button() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    transparent = remove_black_background(source)
    bbox = transparent.getbbox()
    cropped = transparent.crop(bbox)
    cropped.thumbnail((128, 128), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (150, 150), (0, 0, 0, 0))
    canvas.alpha_composite(cropped, ((canvas.width - cropped.width) // 2, (canvas.height - cropped.height) // 2))
    canvas.save(OUT / "mobile_bite_button.png")

    pressed = canvas.resize((136, 136), Image.Resampling.LANCZOS)
    pressed_canvas = Image.new("RGBA", (150, 150), (0, 0, 0, 0))
    glow = Image.new("RGBA", canvas.size, (255, 216, 73, 0))
    glow.putalpha(canvas.getchannel("A").filter(ImageFilter.GaussianBlur(7)))
    pressed_canvas.alpha_composite(glow)
    pressed_canvas.alpha_composite(pressed, (7, 7))
    pressed_canvas.save(OUT / "mobile_bite_button_pressed.png")


def draw_circle_button(filename: str, symbol: str, size: int = 124) -> None:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((8, 8, size - 8, size - 8), fill=(18, 9, 30, 174), outline=(238, 176, 44, 225), width=5)
    draw.ellipse((19, 19, size - 19, size - 19), fill=(54, 23, 76, 154), outline=(126, 60, 166, 190), width=3)
    draw.ellipse((31, 31, size - 31, size - 31), fill=(15, 8, 24, 110))
    if symbol == "jump":
        points = [(62, 27), (31, 68), (50, 68), (50, 92), (74, 92), (74, 68), (93, 68)]
    else:
        points = [(62, 31), (88, 46), (88, 77), (62, 94), (36, 77), (36, 46)]
    draw.polygon(points, fill=(255, 224, 96, 245), outline=(25, 10, 31, 255))
    image.save(OUT / filename)

    pressed = image.resize((112, 112), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow = Image.new("RGBA", (size, size), (255, 214, 70, 0))
    glow.putalpha(image.getchannel("A").filter(ImageFilter.GaussianBlur(6)))
    canvas.alpha_composite(glow)
    canvas.alpha_composite(pressed, (6, 6))
    canvas.save(OUT / filename.replace(".png", "_pressed.png"))


def draw_move_pad() -> None:
    base = Image.new("RGBA", (210, 150), (0, 0, 0, 0))
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle((12, 28, 198, 122), radius=46, fill=(16, 8, 28, 120), outline=(236, 176, 48, 150), width=4)
    draw.line((48, 75, 162, 75), fill=(255, 219, 88, 120), width=4)
    draw.polygon([(54, 52), (28, 75), (54, 98)], fill=(255, 219, 88, 150), outline=(20, 8, 28, 160))
    draw.polygon([(156, 52), (182, 75), (156, 98)], fill=(255, 219, 88, 150), outline=(20, 8, 28, 160))
    base.save(OUT / "mobile_move_pad_base.png")

    knob = Image.new("RGBA", (74, 74), (0, 0, 0, 0))
    knob_draw = ImageDraw.Draw(knob)
    knob_draw.ellipse((5, 5, 69, 69), fill=(38, 17, 58, 188), outline=(248, 190, 52, 210), width=4)
    knob_draw.ellipse((18, 18, 56, 56), fill=(121, 55, 158, 170))
    knob_draw.line((24, 37, 50, 37), fill=(255, 225, 96, 200), width=4)
    knob.save(OUT / "mobile_move_pad_knob.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    save_bite_button()
    draw_circle_button("mobile_jump_button.png", "jump")
    draw_circle_button("mobile_replay_button.png", "replay", 96)
    draw_move_pad()


if __name__ == "__main__":
    main()
