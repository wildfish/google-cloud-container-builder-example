FROM wildfish/django-base:node-lts

RUN groupadd -r django && useradd -r -d /home/django -g django django
RUN mkdir /home/django
RUN chown -R django:django /home/django

# Upgrade pip
RUN pip install pip -U

COPY requirements.txt /usr/src/app/
RUN pip install --no-cache-dir -r /usr/src/app/requirements.txt

WORKDIR /usr/src/app

COPY package.json /usr/src/app/
RUN npm install

COPY . /usr/src/app

RUN chown django:django -R /usr/src/app/
USER django

RUN python manage.py collectstatic --noinput

CMD ["scripts/entrypoint.sh"]

EXPOSE 8000