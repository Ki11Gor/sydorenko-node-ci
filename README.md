# Практичні заняття 5–6. CI/CD для Node.js та Amazon EC2

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

Для запуску потрібні налаштований AWS CLI, дійсний Ubuntu 20.04 AMI, SSH-пара ключів і Security Group у `us-east-1`. У прикладі використано стандартний VPC, `t3.micro` і відповідні йому x86-64 AMI. Перевір умови свого тарифу AWS перед запуском.

Команди нижче використовують AMI з методички. Якщо він недоступний, знайди AMD64-образ Ubuntu 20.04 від Canonical у регіоні `us-east-1` і підстав його ID. У WSL підстав імена своєї пари ключів і групи безпеки. Для SSH група має дозволяти TCP 22 з адрес клієнтів, які підключаються. `My IP` відкриває доступ лише з твоєї адреси, а GitHub-hosted runner отримує окрему, динамічну адресу. Порт 3000 для перевірки HTTP доступний всередині сервера.

```bash
AMI_ID='ami-021bf0bba3a411792'
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

У вкладці **Variables** створи `EC2_HOST_KEY` зі значенням публічного ключа сервера з попереднього кроку (`ssh-ed25519 AAAA…`). Ця змінна перемикає ціль завдання `deploy` на EC2. Зберігай `.pem` і його копію в Base64 поза репозиторієм.

Після налаштування виконай новий `push` до `main` або вибери **Actions → Node.js CI/CD → Run workflow → main**. Після збірки завдання `deploy` готує SSH-з’єднання, копіює перевірений артефакт у `~/nodeapp/dist` і запускає або перезапускає застосунок через PM2. У режимі EC2 журнал покаже `Deployment target: Amazon EC2`, а крок **Start app and verify HTTP** підтвердить відповідь `HTTP health check passed: Hello world`.

