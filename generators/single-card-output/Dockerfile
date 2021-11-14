FROM php:8.1.0RC5-buster

WORKDIR /app

RUN apt update
RUN apt install zip imagemagick -y

# Install python
COPY requirements.txt /app/
RUN apt install python3 -y
RUN apt install python3-pip -y
RUN pip3 install -r requirements.txt


COPY . .

RUN mv /app/policy.xml /etc/ImageMagick-6/policy.xml

RUN mkdir -p /app/files/cards
RUN mkdir -p /app/output/black
RUN mkdir -p /app/output/white

CMD ["python3", "script/generator.py"]
