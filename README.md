# Практичне заняття 5. GitHub Actions для Node.js

`index.js` виводить `Hello world`. Команда `npm run build` запускає esbuild і записує збірку у `dist/index.js`.

## Локальна перевірка

Відкрий термінал у папці проєкту з Node.js 24 і виконай команди.

```bash
npm install
npm run build
node dist/index.js
```

Очікуваний вивід останньої команди — `Hello world`.

## Перевірка на GitHub

Пайплайн визначено у `.github/workflows/ci.yml`. Він запускається після кожного `push` до гілки `main` і збирає проєкт в Ubuntu з Node.js 24.

Відкрий **Actions → Node.js CI → build**. У кроках **Install dependencies** і **Build** видно вивід `npm install` та `npm run build`. Крок **Verify build** перевіряє, чи створено файл і чи він виводить `Hello world`. На сторінці успішного запуску в розділі **Artifacts** буде архів `node-build` із файлом `index.js`.

