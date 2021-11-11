from PIL import Image
import PIL.ImageOps    



img1 = Image.open("card_2.png")
img2 = Image.open("bean.png")
inverted_image = PIL.ImageOps.invert(img2)

img1.paste(inverted_image, (2350,3700))

img1.show()
