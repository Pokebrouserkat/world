#!/usr/bin/env python3
"""Generate 16x16 pixel-art critter sprites for Valley game."""

from PIL import Image
import os

GRAPHICS_DIR = os.path.join(os.path.dirname(__file__), "..", "graphics")


def create_rabbit():
    """Create a small rabbit sprite - side view, white/gray."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()

    # Body (light gray)
    body = (210, 205, 200, 255)
    for x in range(4, 11):
        for y in range(9, 13):
            px[x, y] = body

    # Head
    for x in range(10, 14):
        for y in range(8, 12):
            px[x, y] = body

    # Ears (tall, thin)
    ear = (190, 185, 180, 255)
    ear_inner = (220, 170, 170, 255)
    # Left ear
    px[11, 5] = ear
    px[11, 6] = ear
    px[11, 7] = ear
    px[12, 6] = ear_inner
    px[12, 7] = ear_inner
    # Right ear
    px[13, 6] = ear
    px[13, 7] = ear

    # Eye
    px[12, 9] = (40, 30, 30, 255)

    # Nose
    px[14, 10] = (220, 160, 160, 255)

    # Tail (small puff)
    px[3, 9] = (230, 225, 220, 255)
    px[3, 10] = (230, 225, 220, 255)

    # Legs
    leg = (180, 175, 170, 255)
    px[5, 13] = leg
    px[6, 13] = leg
    px[9, 13] = leg
    px[10, 13] = leg

    img.save(os.path.join(GRAPHICS_DIR, "rabbit.png"))
    print("Created rabbit.png")


def create_butterfly():
    """Create a small butterfly sprite - top-down view, colorful."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()

    # Body (thin vertical line)
    body_color = (60, 40, 30, 255)
    for y in range(6, 12):
        px[7, y] = body_color
        px[8, y] = body_color

    # Left wing (orange/yellow)
    wing_outer = (230, 140, 50, 255)
    wing_inner = (250, 200, 80, 255)
    wing_spot = (60, 40, 100, 255)
    # Upper left wing
    for x in range(3, 7):
        for y in range(5, 9):
            px[x, y] = wing_outer
    px[4, 6] = wing_inner
    px[5, 7] = wing_inner
    px[4, 7] = wing_spot
    # Lower left wing
    for x in range(4, 7):
        for y in range(9, 12):
            px[x, y] = wing_outer
    px[5, 10] = wing_inner

    # Right wing (mirror)
    for x in range(9, 13):
        for y in range(5, 9):
            px[x, y] = wing_outer
    px[11, 6] = wing_inner
    px[10, 7] = wing_inner
    px[11, 7] = wing_spot
    for x in range(9, 12):
        for y in range(9, 12):
            px[x, y] = wing_outer
    px[10, 10] = wing_inner

    # Antennae
    ant = (80, 60, 50, 255)
    px[6, 4] = ant
    px[5, 3] = ant
    px[9, 4] = ant
    px[10, 3] = ant

    img.save(os.path.join(GRAPHICS_DIR, "butterfly.png"))
    print("Created butterfly.png")


def create_bat():
    """Create a small bat sprite - wings spread, dark colors."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()

    # Body (dark brown/gray)
    body = (60, 50, 55, 255)
    for x in range(6, 10):
        for y in range(6, 11):
            px[x, y] = body

    # Head
    head = (70, 60, 65, 255)
    for x in range(6, 10):
        for y in range(4, 7):
            px[x, y] = head

    # Ears (pointed)
    ear = (80, 70, 75, 255)
    px[6, 3] = ear
    px[9, 3] = ear

    # Eyes (red-ish glow)
    px[7, 5] = (200, 60, 60, 255)
    px[8, 5] = (200, 60, 60, 255)

    # Left wing (dark membrane)
    wing = (50, 40, 48, 255)
    wing_edge = (40, 32, 38, 255)
    # Wing struts and membrane
    for x in range(1, 6):
        px[x, 7] = wing_edge
    for x in range(2, 6):
        px[x, 8] = wing
        px[x, 6] = wing
    for x in range(3, 6):
        px[x, 9] = wing
    px[1, 8] = wing_edge
    px[2, 9] = wing_edge
    px[1, 6] = wing_edge

    # Right wing (mirror)
    for x in range(10, 15):
        px[x, 7] = wing_edge
    for x in range(10, 14):
        px[x, 8] = wing
        px[x, 6] = wing
    for x in range(10, 13):
        px[x, 9] = wing
    px[14, 8] = wing_edge
    px[13, 9] = wing_edge
    px[14, 6] = wing_edge

    # Feet
    feet = (50, 40, 45, 255)
    px[7, 11] = feet
    px[8, 11] = feet

    img.save(os.path.join(GRAPHICS_DIR, "bat.png"))
    print("Created bat.png")


if __name__ == "__main__":
    os.makedirs(GRAPHICS_DIR, exist_ok=True)
    create_rabbit()
    create_butterfly()
    create_bat()
    print("All critter sprites generated!")
