import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFont

def create_mac_icon(output_icns_paths=None):
    if output_icns_paths is None:
        output_icns_paths = ["Mac Video Loader.app/Contents/Resources/AppIcon.icns"]

    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # macOS squircle box
    margin = 100
    radius = 185
    box = [margin, margin, size - margin, size - margin]

    # Create mask for squircle
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(box, radius=radius, fill=255)

    # Base gradient image (Deep Sapphire Blue to Royal Indigo / Purple)
    grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad_draw = ImageDraw.Draw(grad)
    for y in range(margin, size - margin):
        t = (y - margin) / float(size - 2 * margin)
        # Gradient: Top = (25, 115, 235) -> Bottom = (70, 20, 145)
        r = int(25 * (1 - t) + 70 * t)
        g = int(115 * (1 - t) + 20 * t)
        b = int(235 * (1 - t) + 145 * t)
        grad_draw.line([(margin, y), (size - margin, y)], fill=(r, g, b, 255))

    icon_base = Image.composite(grad, img, mask)
    overlay_draw = ImageDraw.Draw(icon_base)

    # Outer highlight border
    overlay_draw.rounded_rectangle(box, radius=radius, outline=(255, 255, 255, 45), width=4)

    cx = size // 2
    cy = size // 2

    # Draw a stylized glowing circular background plate
    disc_radius = 260
    disc_box = [cx - disc_radius, cy - 20 - disc_radius, cx + disc_radius, cy - 20 + disc_radius]
    overlay_draw.ellipse(disc_box, fill=(255, 255, 255, 18), outline=(255, 255, 255, 40), width=3)

    # Draw Modern Download Arrow
    # Arrow Stem
    stem_w = 34
    stem_top = cy - 145
    stem_bottom = cy + 65
    overlay_draw.rounded_rectangle(
        [cx - stem_w, stem_top, cx + stem_w, stem_bottom],
        radius=14,
        fill=(255, 255, 255, 250)
    )

    # Arrow Head (Downward Triangle with rounded appearance)
    head_points = [
        (cx - 135, cy + 50),
        (cx + 135, cy + 50),
        (cx, cy + 165)
    ]
    overlay_draw.polygon(head_points, fill=(255, 255, 255, 250))

    # Download Base Tray
    tray_y = cy + 185
    tray_w = 175
    tray_h = 28
    overlay_draw.rounded_rectangle(
        [cx - tray_w, tray_y, cx + tray_w, tray_y + tray_h],
        radius=14,
        fill=(255, 255, 255, 240)
    )

    # Draw MVL Badge at top center
    badge_w = 100
    badge_h = 36
    badge_y = margin + 55
    overlay_draw.rounded_rectangle(
        [cx - badge_w, badge_y, cx + badge_w, badge_y + badge_h],
        radius=12,
        fill=(255, 255, 255, 25),
        outline=(255, 255, 255, 60),
        width=2
    )

    # Draw "MVL" text inside badge if font available or basic geometric lines
    # Let's try to load system font Helvetica / Arial or fall back to default
    font_loaded = False
    for font_path in [
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/System/Library/Fonts/SFCompact.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Helvetica.ttf"
    ]:
        if os.path.exists(font_path):
            try:
                font = ImageFont.truetype(font_path, 22)
                overlay_draw.text((cx, badge_y + 18), "MVL", font=font, fill=(255, 255, 255, 230), anchor="mm")
                font_loaded = True
                break
            except Exception:
                continue

    if not font_loaded:
        overlay_draw.text((cx - 18, badge_y + 10), "MVL", fill=(255, 255, 255, 230))

    # Create iconset directory
    iconset_dir = "MacVideoLoader.iconset"
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for filename, s in sizes:
        resized = icon_base.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename))

    temp_icns = "AppIcon.icns"
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", temp_icns], check=True)

    for target_path in output_icns_paths:
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        subprocess.run(["cp", temp_icns, target_path], check=True)
        print(f"AppIcon.icns erstellt unter: {target_path}")

    # Clean up iconset and temp icns
    subprocess.run(["rm", "-rf", iconset_dir, temp_icns])

if __name__ == "__main__":
    create_mac_icon([
        "Mac Video Loader.app/Contents/Resources/AppIcon.icns"
    ])
