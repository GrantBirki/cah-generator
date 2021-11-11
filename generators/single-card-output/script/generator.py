import os
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont


def get_cards(path):
    with open(path, 'r') as file_contents:
        cards_raw = file_contents.readlines()

    cards = []
    for card in cards_raw:
        cards.append(card.strip())

    return cards

def create_card(card, color):

    command = ["php", "generator.php", f"batch-id=cards&card-text={card}&card-color={color}&icon=none"]
    process = subprocess.Popen(command, stdout=subprocess.PIPE)
    output, error = process.communicate()

    # print(output.decode("utf-8"))

def move_to_output(color, suffix_number):
    source = "files/cards/cards_0.png"
    dest = f"/app/output/{color}/card_{suffix_number}.png"
    command = f"mv {source} {dest}"
    process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
    output, error = process.communicate()

    print(f'   + Created: {color}/card_{suffix_number}.png')

def create_zip_package():
    zip_name = "game-package"
    shutil.make_archive(zip_name, 'zip', "output")
    source = f"{zip_name}.zip"
    dest = f"/app/output/{zip_name}.zip"
    command = f"mv {source} {dest}"
    process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
    output, error = process.communicate()

    print(f'\n+ Bundled all cards into: output/single-card/game-package.zip')

def add_custom_game_name(game_name, invert=False):
    # Open an Image
    img = Image.open("files/cards/cards_0.png")
    draw = ImageDraw.Draw(img)

    # create blank white rectangle to cover CAH word logo
    shape = (3000, 5000, 800, 3700)
    if invert:
        draw.rectangle(shape, fill="#000000")
    else:
        draw.rectangle(shape, fill="#FFFFFF")

    # Add custom text to image
    font = ImageFont.truetype('fonts/NimbusSanL-Bol.otf', size=92)
    if invert:
        draw.text((840, 3900), game_name, font=font, fill="#FFFFFF")
    else:
        draw.text((840, 3900), game_name, font=font, fill="#000000")
    
    # Save the edited image
    img.save("files/cards/cards_0.png")

def check_game_info_file():
    with open('cards/info.txt') as info_file:
        info = info_file.readlines()
    data = []
    for line in info:
        data.append(line.strip())
    
    if len(data) != 3:
        return False, False

    if data[0].strip() == "none":
        game_name = False
    else:
        game_name = data[0].strip()
    if data[2].strip() == "none":
        game_version = False
    else:
        game_version = data[2].strip()
    
    return game_name, game_version

def add_custom_deck_version(version):
    # Open an Image
    img = Image.open("files/cards/cards_0.png")
    draw = ImageDraw.Draw(img)

    # Add custom text to image
    font = ImageFont.truetype('fonts/NimbusSanL-Bol.otf', size=92)
    draw.text((650, 3900), version, font=font, fill=(0, 0, 0))
    
    # Save the edited image
    img.save("files/cards/cards_0.png")

def generate_card(card, color, game_name, game_version, counter):
    create_card(card, color)
    if game_name:
        if color == "black":
            add_custom_game_name(game_name, invert=True)
        else:
            add_custom_game_name(game_name)
    if game_version:
        add_custom_deck_version(game_version)
    move_to_output(color, counter)

def main():
    white_cards = get_cards("cards/white.txt")
    black_cards = get_cards("cards/black.txt")

    game_name, game_version = check_game_info_file()

    print("[i] Attempting to generate the following:")
    print(f" # Cards")
    print(f"   # White cards: {len(white_cards)}")
    print(f"   # Black cards: {len(black_cards)}")
    print(f"   # Total cards: {len(white_cards + black_cards)}")
    print(f" # Zip Game Bundles: 1")
    print(f" # Total Files: {len(white_cards + black_cards) + 1}\n")
    if game_name:
        print(f"[i] Custom Game Name Enabled: {game_name}")
    if game_version:
        print(f"[i] Custom Game Version Enabled: {game_version}")
    print(f"\n # Generating Cards...")

    counter = 0
    for card in white_cards:
        generate_card(card, "white", game_name, game_version, counter)
        counter += 1

    counter = 0
    for card in black_cards:
        generate_card(card, "black", game_name, game_version, counter)
        counter += 1

    create_zip_package()

    file_count = sum(len(files) for _, _, files in os.walk('/app/output'))

    print(f'\n[i] Total files created: {file_count}')

    print('[i] Done!')

if __name__ == '__main__':
    main()
