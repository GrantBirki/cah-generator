import os
import re
import shutil
import subprocess
from sys import stdout

import PIL.ImageOps
from PIL import Image, ImageDraw, ImageFont

DECK = os.environ['DECK']

def get_cards(path):
    with open(path, 'r') as file_contents:
        cards_raw = file_contents.readlines()

    cards = []
    for card in cards_raw:
        cards.append(card.strip())

    return cards

def create_card(card, color):

    command = ["php", "generator.php", f"batch-id=cards&card-text={card}&card-color={color}&icon=none&mechanic=none"]
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
    stdout.flush()

def create_zip_package():

    # Create the src folder for the .txt files which are the source of the cards
    command = f"mkdir /app/output/src"
    process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
    output, error = process.communicate()

    # Copy the .txt files to the src folder
    command = f"cp -r /app/cards/deck_{DECK}/. /app/output/src/"
    process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
    output, error = process.communicate()

    zip_name = f"deck_{DECK}"
    
    # Remove the current zip file if it exists
    if os.path.exists(f"output/{zip_name}.zip"):
        os.remove(f"output/{zip_name}.zip")

    shutil.make_archive(zip_name, 'zip', "output")
    source = f"{zip_name}.zip"
    dest = f"/app/decks/{zip_name}.zip"
    command = f"mv {source} {dest}"
    process = subprocess.Popen(command.split(), stdout=subprocess.PIPE)
    output, error = process.communicate()

    print(f'\n+ Bundled all cards into: decks/deck_{DECK}.zip')
    stdout.flush()

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
    with open(f'cards/deck_{DECK}/info.txt') as info_file:
        info = info_file.readlines()
    data = []
    for line in info:
        data.append(line.strip())

    # Core game info
    if data[0].split('=')[1].strip() == "none":
        game_name = False
    else:
        game_name = data[0].split('=')[1].strip()
    if data[1].split('=')[1].strip() == "none":
        short_name = False
    else:
        short_name = data[1].split('=')[1].strip()
    if data[2].split('=')[1].strip() == "none":
        game_version = False
    else:
        game_version = data[2].split('=')[1].strip()

    # Custom game images
    custom_img_1 = data[3].split('=')[1].strip()
    custom_img_2 = data[4].split('=')[1].strip()
    custom_img_3 = data[5].split('=')[1].strip()
    custom_img_4 = data[6].split('=')[1].strip()
    custom_img_5 = data[7].split('=')[1].strip()

    game_info = {
        "game_name": game_name,
        "short_name": short_name,
        "game_version": game_version,
        "custom_img_1": custom_img_1,
        "custom_img_2": custom_img_2,
        "custom_img_3": custom_img_3,
        "custom_img_4": custom_img_4,
        "custom_img_5": custom_img_5
    }
    
    return game_info

def add_custom_deck_version(version):
    # Open an Image
    img = Image.open("files/cards/cards_0.png")
    draw = ImageDraw.Draw(img)

    # Add custom text to image
    font = ImageFont.truetype('fonts/NimbusSanL-Bol.otf', size=92)
    draw.text((650, 3900), version, font=font, fill=(0, 0, 0))
    
    # Save the edited image
    img.save("files/cards/cards_0.png")

def check_for_custom_img_tag(card):
    search = r"{{(\d)}}"
    result = re.search(search, card)
    if result:
        return result.group(1)
    else:
        return False

def add_black_card_info_image(card):
    if "[[2]]" in card:
        img = Image.open("files/cards/cards_0.png")
        add_image = Image.open("img/p2.png")
        img.paste(add_image, (2150,3740))
        img.save("files/cards/cards_0.png")
    elif "[[3]]" in card:
        img = Image.open("files/cards/cards_0.png")
        add_image = Image.open("img/d2p3.png")
        img.paste(add_image, (2150,3625))
        img.save("files/cards/cards_0.png")
    elif "[[gears]]" in card:
        img = Image.open("files/cards/cards_0.png")
        add_image = Image.open("img/gears.png")
        img.paste(add_image, (2350,3500))
        img.save("files/cards/cards_0.png")

def add_custom_img(image, invert=False):
    # Open the card image
    img = Image.open("files/cards/cards_0.png")

    # Add the new image onto the original image
    add_image = Image.open(image)
    if invert:
        add_image = PIL.ImageOps.invert(add_image)
    img.paste(add_image, (2200,3650))

    # Save the edited image
    img.save("files/cards/cards_0.png")

def format_card_text(card):
    fmt_card = card

    # Replace all the custom image tags with nothing
    fmt_card = re.sub(r"\{\{(\d)\}\}", r"", fmt_card)
    # Replace all the built-in image tags with nothing
    fmt_card = re.sub(r"\[\[.*\]\]", r"", fmt_card)

    return fmt_card

def generate_card(card, color, game_info, counter):
    try:
        # Format the card text
        fmt_card = format_card_text(card)

        # Create the card
        create_card(fmt_card, color)

        # Add the custom game name if there is one
        if game_info["game_name"]:
            if color == "black":
                add_custom_game_name(game_info["game_name"], invert=True)
            else:
                add_custom_game_name(game_info["game_name"])

        # Add a custom game version if there is one
        if game_info["game_version"]:
            add_custom_deck_version(game_info["game_version"])

        # Add a custom image if there is one
        image_tag = check_for_custom_img_tag(card)
        if color == "black":
            if image_tag:
                add_custom_img("custom_img/" + game_info["custom_img_" + str(image_tag)], invert=True)
            add_black_card_info_image(card)
        else:
            if image_tag:
                add_custom_img("custom_img/" + game_info["custom_img_" + str(image_tag)])

        # Move the file to the output folder because we're done with it
        move_to_output(color, counter)
    except:
        print("[!] Error generating card: " + card + " - " + color)
        stdout.flush()

def main():
    white_cards = get_cards(f"cards/deck_{DECK}/white.txt")
    black_cards = get_cards(f"cards/deck_{DECK}/black.txt")

    game_info = check_game_info_file()

    print("[i] Attempting to generate the following:")
    print(f" # Cards")
    print(f"   # White cards: {len(white_cards)}")
    print(f"   # Black cards: {len(black_cards)}")
    print(f"   # Total cards: {len(white_cards + black_cards)}")
    print(f" # Zip Game Bundles: 1")
    print(f" # Total Files: {len(white_cards + black_cards) + 1}\n")
    if game_info["game_name"]:
        print(f"[i] Custom Game Name Enabled: {game_info['game_name']}")
    if game_info["short_name"]:
        print(f"[i] Custom Short Name Enabled: {game_info['short_name']}")
    if game_info["game_version"]:
        print(f"[i] Custom Game Version Enabled: {game_info['game_version']}")
    print(f"\n # Generating Cards...")
    stdout.flush()

    counter = 0
    for card in white_cards:
        generate_card(card, "white", game_info, counter)
        counter += 1

    counter = 0
    for card in black_cards:
        generate_card(card, "black", game_info, counter)
        counter += 1

    create_zip_package()

    file_count = sum(len(files) for _, _, files in os.walk('/app/output'))

    print(f'\n[i] Total files bundled: {file_count}')
    stdout.flush()

    print('[i] Done!')
    stdout.flush()

if __name__ == '__main__':
    main()
