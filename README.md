# Практичні заняття 5, 6 і 9. Node.js, CI/CD та Docker

`index.js` виводить `Hello world`. Команда `npm run build` запускає esbuild і записує збірку у `dist/index.js`. З аргументом `--serve` збірка запускає HTTP-сервер на `127.0.0.1:3000` і відповідає `Hello world`.

## Локальна перевірка

Відкрий термінал у папці проєкту з Node.js 24 і виконай команди.

```bash
npm install
npm run build
node dist/index.js
```

Щоб перевірити HTTP-режим, запусти `node dist/index.js --serve`, а в іншому терміналі виконай `curl -fsS http://127.0.0.1:3000/`. В обох режимах результат — `Hello world`.

## Перевірка на GitHub

Пайплайн `.github/workflows/ci.yml` запускається після `push` до `main`. У GitHub відкрий **Actions → Node.js CI/CD → build**. Кроки `npm install`, `npm run build` і `Verify build` встановлюють залежності, збирають застосунок і перевіряють його в обох режимах. Артефакт `node-build` містить зібраний `index.js`.

## Навчальний деплой без AWS-акаунта

За замовчуванням завдання `deploy` створює тимчасовий Linux-контейнер на runner GitHub. Воно завантажує артефакт `node-build`, передає збірку через SSH, запускає її через PM2 та перевіряє HTTP-відповідь. Після перевірки GitHub Actions видаляє контейнер і тимчасові ключі. У цьому режимі GitHub Secrets і платіжна картка не потрібні.

У запуску №7 GitHub Actions успішно виконав `build` і **Deploy to Linux container**. Крок **Start app and verify HTTP** підтвердив відповідь `HTTP health check passed: Hello world`. [Переглянути успішний запуск](https://github.com/Ki11Gor/sydorenko-node-ci/actions/runs/43611315437)

Щоб перевірити нову збірку, відкрий **Actions → Node.js CI/CD → останній запуск → Deploy to Linux container**. Для розгортання на Amazon EC2 потрібен доступ до інстанса.

## Підготовка EC2

У практичній №9 на EC2 застосунок запускає Docker Compose. Розділ **Деплой Docker Compose на EC2** описує встановлення Docker, вимкнення PM2 та запуск нового образу. Команди встановлення Node.js і PM2 нижче стосуються практичної №6.

Для запуску потрібні налаштований AWS CLI, Ubuntu AMI, SSH-пара ключів і Security Group у `us-east-1`. У прикладі використано стандартний VPC, `t3.micro` і x86-64 AMI. Для практичної №9 вибери Ubuntu 24.04 LTS, який підтримує актуальний Docker Engine. Перевір умови свого тарифу AWS перед запуском.

Підстав ID свого AMD64-образу Ubuntu від Canonical, ім’я пари ключів і ID групи безпеки. Для SSH група має дозволяти TCP 22 з адрес клієнтів, які підключаються. `My IP` відкриває доступ лише з твоєї адреси, а GitHub-hosted runner отримує окрему, динамічну адресу. Порт 3000 для перевірки HTTP доступний всередині сервера.

```bash
AMI_ID='ami-REPLACE_ME'
KEY_NAME='devops-key'
SG_ID='sg-REPLACE_ME'

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --count 1 \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --associate-public-ip-address \
  --metadata-options HttpTokens=required \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sydorenko-node-ci}]' \
  --region us-east-1 \
  --query 'Instances[0].InstanceId' --output text)

aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID" --region us-east-1
EC2_HOST=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region us-east-1 \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
```

У консолі AWS відкрий системний журнал інстанса через **Actions → Monitor and troubleshoot → Get system log**. Під час першого SSH-підключення звір відбиток ED25519 із журналом інстанса.

```bash
chmod 600 devops-key.pem
ssh -o HostKeyAlgorithms=ssh-ed25519 -i devops-key.pem "ubuntu@$EC2_HOST"
```

У SSH-сесії під користувачем `ubuntu` один раз установи Node.js 24, PM2 та `curl`. Зчитай публічний ключ самого сервера для перевірки його ідентичності в CI/CD.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
curl -fsSL https://deb.nodesource.com/setup_24.x -o /tmp/nodesource-setup.sh
sudo bash /tmp/nodesource-setup.sh
sudo apt-get install -y nodejs
sudo npm install --global pm2@7.1.2
node --version
pm2 --version
cat /etc/ssh/ssh_host_ed25519_key.pub
```

## GitHub Secrets і запуск

У **Settings → Secrets and variables → Actions → Secrets** створи `EC2_HOST` з публічною IP-адресою та `EC2_USER` зі значенням `ubuntu`. Для `EC2_SSH_KEY_B64` скопіюй закодований ключ до буфера у WSL і встав його в поле Secret.

```bash
base64 -w 0 devops-key.pem | clip.exe
```

У вкладці **Variables** створи `EC2_HOST_KEY` зі значенням публічного ключа сервера з попереднього кроку (`ssh-ed25519 AAAA…`). Ця змінна вмикає **Deploy Compose to Amazon EC2**. Зберігай `.pem` і його копію в Base64 поза репозиторієм.

Для розгортання на EC2 використовуй workflow **Docker CI/CD** і кроки з практичної №9 нижче.

## Практична №9. Dockerfile і Docker Compose

`Dockerfile` бере офіційний `node:lts`, спочатку копіює `package*.json` і встановлює залежності через `npm install --omit=dev`. Потім копіює код і запускає застосунок на порту 3000 під користувачем `node`. `.dockerignore` виключає `node_modules`, `.env`, `.git` і збірки.

### Збірка та запуск образу

Виконай у Linux або WSL з Docker у папці клонованого репозиторію.

```bash
IMAGE_TAG=$(git rev-parse --short=12 HEAD)
export IMAGE_TAG
docker build -t "nodeapp:$IMAGE_TAG" .
docker run --rm -d --name nodeapp -p 127.0.0.1:3000:3000 "nodeapp:$IMAGE_TAG"
curl -fsS http://127.0.0.1:3000/
docker stop nodeapp
```

### Node.js і PostgreSQL через Compose

Compose запускає `app` із цього Dockerfile та `db` з образу `postgres:15`. `depends_on` чекає готовності БД. Том `postgres-data` зберігає дані між запусками. У `.env` зберігається пароль БД. Збережи цей файл для повторних запусків із тим самим томом.

```bash
if [ ! -s .env ]; then
  (umask 077 && printf 'POSTGRES_PASSWORD=%s\n' "$(openssl rand -hex 24)" > .env)
fi
docker compose up -d --build --wait
docker compose ps
docker compose logs app
curl -fsS http://127.0.0.1:3000/health
docker compose down
```

У журналі `app` і у відповіді `/health` очікується `PostgreSQL connected`. Сторінка `/` повертає `Hello world`.

### Docker Hub у GitHub Actions

Workflow **Docker CI/CD** збирає образ і запускає обидва сервіси для перевірки. Він формує два теги, скорочений хеш коміту і назву гілки з префіксом `branch-`, наприклад `branch-main`.

1. Створи публічний репозиторій `nodeapp` у своєму Docker Hub.
2. Створи Docker Hub Personal Access Token із правом запису. У GitHub додай `DOCKERHUB_USERNAME` і `DOCKERHUB_TOKEN` у **Settings → Secrets and variables → Actions → Secrets**.
3. Запусти **Actions → Docker CI/CD → Run workflow** або зроби `push`. З обома секретами workflow завантажує теги в `<ім’я-Docker-Hub>/nodeapp`. Публічний образ доступний EC2 для завантаження.

### Деплой Docker Compose на EC2

Установи Docker Engine і плагін Compose за [інструкцією Docker для Ubuntu](https://docs.docker.com/engine/install/ubuntu). Користувач з `EC2_USER` має запускати `docker compose version` і `docker info` у SSH-сесії.

Якщо PM2 установлювався на цьому EC2 для практичної №6, виконай під тим самим користувачем, щоб звільнити порт 3000.

```bash
pm2 unstartup
pm2 kill
sudo npm uninstall --global pm2
```

Якщо `pm2 unstartup` виведе команду з `sudo`, виконай її перед видаленням PM2. Після цього вкажи `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY_B64` і `EC2_HOST_KEY`, як описано вище. Workflow завантажує образ із Docker Hub за тегом `IMAGE_TAG` поточного коміту. На EC2 він виконує `docker rm -f nodeapp || true` для старого окремого контейнера, запускає Compose і перевіряє `/health`. Для доступу до застосунку з ПК можна використати SSH-тунель із перенаправленням локального порту на `127.0.0.1:3000` інстанса.

