# AGENTS.md — راهنمای agent بعدی

این سند برای agent‌ای نوشته شده که قرار است **در همین محیط موقت** ادامه دهد.
محیط هر لحظه ممکن است از بین برود؛ پس اول محدودیت‌ها را بخوان، بعد دست به کار شو.

---

## ۰. اولین قدم: `sh scripts/restore.sh`

اگر این مخزن را تازه import کرده‌ای، **هیچ‌چیز را دستی نصب نکن**. یک دستور کل
فرایند را از صفر تا «live mode در حال اجرا» برمی‌گرداند و هر قدم دلیلش را داخل
خودش مستند کرده است:

```sh
sh scripts/restore.sh            # بازسازی کامل
sh scripts/restore.sh --status   # فقط گزارش، چیزی را عوض نمی‌کند
```

`README.md` خلاصه‌ی سریع است؛ این فایل جزئیات و دلیل‌ها.

---

## ۱. محیط: سه محدودیتی که اگر ندانی، کارت را خراب می‌کند

### ۱.۱ سقف حافظه ۱ گیگابایت — مهم‌ترین محدودیت

```
/sys/fs/cgroup/memory/memory.limit_in_bytes  →  1073741824  (1024 MB)
```

هزینه‌ی ثابت یک VS Code Server متصل، **حتی با ۶ افزونه**، حدود ۷۵۰ MB است:

| پروسه | RSS |
|---|---|
| `agentHost` | ~168 MB |
| `server-main.js` (connection token) | ~136 MB |
| `extensionHost` | ~126 MB |
| `server-main.js` (socket) | ~99 MB |
| `node_modules` سرور | ~94 MB |
| `ptyHost` | ~67 MB |
| `fileWatcher` | ~54 MB |

با ۳۶ افزونه‌ی پیش‌فرض این عدد به ۸۱۶ MB و **۱۶ پروسه** می‌رسد و کل کانتینر
OOM می‌شود — در بدترین حالت حتی `echo ok` هم با `spawn ENOMEM` شکست می‌خورد و
همه‌چیز (از جمله ابزارهای خودت) از کار می‌افتد.

**قاعده‌ها:**
- قبل از هر بار اتصال تونل، `sh scripts/trim-extensions.sh status` را اجرا کن.
- هرگز اجازه نده چند تب vscode.dev همزمان وصل شوند. هر اتصال مجدد یک
  `extensionHost` جدید می‌سازد که هیچ‌وقت آزاد نمی‌شود؛ دقیقاً همین باعث سقوط‌های
  پیاپی شد (۷ کانال همزمان → ۱۶ پروسه).
- بخشی از عدد `memory.usage_in_bytes` **page cache** است و قابل بازیافت. عدد خام
  را با فاجعه اشتباه نگیر؛ `cache` را از `memory.stat` بخوان و کم کن.

### ۱.۲ مسیر `/home/user` از پروسه‌های spawn‌شده قابل اتکا نیست

این عجیب‌ترین و پرهزینه‌ترین نکته‌ی محیط است. یک پروسه‌ی detached یا اسکریپت:

- **می‌تواند** فایل‌های `/home/user/...` را بخواند و حتی exec کند؛
- **نمی‌تواند** به‌طور قابل اتکا در آنجا فایل **بسازد** (`cannot create …: Directory nonexistent`)؛
- گاهی `cd /home/user/...` با ENOENT شکست می‌خورد، حتی وقتی shell تعاملی همان `cd` را موفق انجام می‌دهد؛
- `ls /home` گاهی `user` را نشان نمی‌دهد، در حالی که `ls /home/user` کار می‌کند (bind-mount).

**قاعده‌ها:**
- هر چیزی که یک پروسه‌ی پس‌زمینه می‌نویسد — pidfile، لاگ، سوکت — را در **`/tmp`** بگذار.
- `sed -i` روی فایل‌های `/home/user` قابل اتکا نیست: گاهی خروجی ۰ می‌دهد ولی فایل
  عوض نمی‌شود. به‌جایش کل فایل را از نو بنویس.
- اسکریپت‌ها را طوری بنویس که به مسیر مطلق نیاز نداشته باشند: از `$PWD` استفاده کن
  و `git -C` را با احتیاط به کار ببر (گاهی همان هم ENOENT می‌گیرد).
- **هرگز** فایل‌های کاری را «موقتاً» تغییر نده تا بعد برگردانی. یک بار این کار
  باعث شد تگ‌های live-mode پاک شوند و برگرداندنشان شکست بخورد.

### ۱.۳ `curl` و `wget` وجود ندارند

فقط `python3` (با `urllib`)، `git`، `node` و `tar`. هر دانلودی باید با Python انجام
شود. لانچرِ impeccable هم برای دانلود انجین به curl/wget نیاز دارد و شکست می‌خورد —
`scripts/setup.sh` این را با Python و **راستی‌آزمایی sha256** انجام می‌دهد.

---

## ۲. اسکریپت‌ها

همه در `scripts/` و idempotent هستند:

| اسکریپت | کار |
|---|---|
| `restore.sh` | **نقطه‌ی ورود اصلی.** بازسازی کامل از «تازه clone شده» تا «live mode در حال اجرا»: حافظه، CLI، انجین با sha256، کانفیگ، trim افزونه‌ها، پروکسی، live boot، و دستورالعمل تونل. با `--status` فقط گزارش می‌دهد. چهار تله‌ی بخش ۹٫۵ داخلش هندل شده. |
| `setup.sh` | نسخه‌ی قدیمی‌ترِ همان کار. `restore.sh` را ترجیح بده. |
| `trim-extensions.sh` | `{status\|trim\|restore}` — افزونه‌های سرور VS Code را به ۶ مورد لازم کم می‌کند. **چیزی حذف نمی‌شود**؛ به `/tmp/vsc-extensions-backup` منتقل می‌شوند. |
| `tunnel-service.sh` | `{start\|stop\|restart\|status\|log}` — جایگزین `code tunnel service install`. |
| `auto-commit.sh` | commit تغییرات پذیرفته‌شده بدون وارد کردن تگ موقت live-mode. |
| `liveproxy.py` | پروکسی same-origin که live mode را روی HTTPS ممکن می‌کند (بخش ۴). |

---

## ۳. چرا `code tunnel service install` کار نمی‌کند

چون systemd و dbus وجود ندارد — PID 1 یک پروسه‌ی node است:

```
error Error creating dbus session. This command uses systemd for managing
services... The error encountered was: I/O error: No such file or directory
```

`systemctl` نصب نیست و `/run/systemd/system` وجود ندارد. بنابراین
`tunnel status` همیشه `service_installed: false` می‌ماند و این **طبیعی** است.

`scripts/tunnel-service.sh` همان تضمین‌ها را دستی می‌دهد: detached با `setsid`،
راه‌اندازی مجدد خودکار هر ۵ ثانیه، لاگ در `/tmp/vscode-tunnel.log`، و pidfile به
عنوان سیگنال توقف. همچنین `NODE_OPTIONS=--max-old-space-size=192` را ست می‌کند.

### نکته‌ی مهم درباره‌ی auth

اعتبارنامه‌ی GitHub در `/tmp/.vscode/cli/token.json` است. اسکریپت
`VSCODE_CLI_DATA_DIR=/tmp/.vscode/cli` را pin می‌کند تا از همان استفاده شود و
سرورِ trim‌شده دوباره دانلود نشود.

**اما این توکن با سقوط‌های مکرر از بین می‌رود.** علامتش این است که لاگ به‌جای
`➜ Tunnel:` یک کد دستگاه می‌دهد:

```
To grant access to the server, please log into https://github.com/login/device and use code XXXX-XXXX
```

در این حالت هیچ کاری از دست agent برنمی‌آید — **کاربر باید** آن URL را باز کند و کد
را بزند. کد حدود ۱۵ دقیقه اعتبار دارد. بعد از restart حتماً `tunnel status` را
بگیر و تا وقتی `"tunnel":"Connected"` ندیده‌ای، ادعا نکن تونل برقرار است. این اشتباه
یک بار باعث شد به کاربر بگوییم «منتظرم» در حالی که تونل اصلاً ثبت نشده بود.

---

## ۴. چرا `liveproxy.py` ضروری است (مهم‌ترین نکته‌ی فنی)

`live.js` آدرس هلپر را **hardcode** می‌کند:

```js
evtSource = new EventSource('http://localhost:' + PORT + '/events?token=' + TOKEN + ...)
```

۲۲ بار. روی یک origin از نوع `https://<id>-8080.asse.devtunnels.ms` این **دو بار**
شکست می‌خورد:

1. **mixed content** — صفحه‌ی `https:` نمی‌تواند `http:` بارگذاری کند؛
2. **میزبان اشتباه** — `localhost` ماشین خود کاربر است، نه sandbox.

Forward کردن پورت ۸۴۰۰ هم کمکی نمی‌کند، چون آدرس از origin صفحه گرفته نمی‌شود.
Cross-origin هم راه فرار نیست: هلپر `Access-Control-Allow-Methods` و
`Allow-Headers` می‌فرستد ولی **`Access-Control-Allow-Origin` نمی‌فرستد**.

### راه‌حل

`liveproxy.py` یک origin واحد می‌سازد که سه کار می‌کند:

1. فایل‌های استاتیک را از ریشه‌ی مخزن سرو می‌کند؛
2. همه‌ی endpoint‌های هلپر را به `127.0.0.1:8400` پروکسی می‌کند
   (`/live.js`, `/events` با SSE بدون buffer, `/source`, `/status`, `/annotation`,
   `/agent-target-claim`, `/agent-target-result`, `/manual-edit-*`,
   `/design-system*`, `/detect.js`, `/modern-screenshot.js`, `/params.json`)؛
3. **در حین سرو کردن** آدرس‌های hardcode‌شده‌ی `live.js` را به مسیر نسبی same-origin
   تبدیل می‌کند (۲۲ → ۱؛ آن یکی باقی‌مانده داخل یک کامنت است) و `<script src>`
   تگِ inject‌شده را هم بازنویسی می‌کند.

نتیجه: **فایل‌های روی دیسک دست‌نخورده می‌مانند** و `live-inject` مثل قبل کار می‌کند.

**پس فقط پورت ۸۰۸۰ را forward کن.** ۸۴۰۰ لازم نیست.

⚠️ یک باگ که هنگام نوشتنش خوردم و باید بدانی: اگر template literal را به
single-quote تبدیل کنی، `` `/design-system.json?token=${TOKEN}` `` دیگر interpolate
نمی‌شود. هنگام بازنویسی **backtick را نگه دار**.

---

## ۵. گردش کار impeccable live

مخزن از قبل configure شده: `.impeccable/live/config.json` با
`files: ["*.html"]` و `cspChecked: true` (چون `detect-csp` شکل `null` می‌دهد —
این پروژه هیچ CSP ندارد).

ترتیب درست:

```sh
sh scripts/setup.sh                       # همه‌چیز
sh scripts/tunnel-service.sh start        # بعد از trim، نه قبل
# کاربر: پورت 8080 را forward کند و صفحه را باز کند
IMPECCABLE_HOME=$PWD/.impeccable-engine \
  .agents/skills/impeccable/scripts/impeccable live-poll
```

**انجین را باید خودت دانلود کنی** — فقط باینری ویندوز داخل مخزن است
(`scripts/bin/windows-x64/`). `setup.sh` نسخه‌ی linux-x64 را با راستی‌آزمایی
sha256 از release sidecar می‌گیرد. `IMPECCABLE_HOME` را به
`$PWD/.impeccable-engine` تنظیم کن چون `HOME=/tmp` است.

نکته‌های قرارداد (از `reference/live.md`):

- `_instructions` در خروجی هر دستور **معتبرترین** راهنمای قدم بعدی است.
- بعد از هر event یا `--reply` فوراً دوباره poll کن.
- اگر `scaffold` در event بود، **دوباره `live-wrap` را اجرا نکن**؛ ولی وقتی
  `sourceWritten: false` است باید `wrapperBlock` را خودت در `insertLine` بنویسی.
- بعد از `accept` با `carbonize: true`، پاک‌سازی **اجباری** است و تا انجام نشود
  poll نکن. `live-complete` تا وقتی اثری باقی باشد با `source_dirty` رد می‌کند.
- `discard` ترمینال است؛ خودِ poll همه‌کار را می‌کند.
- هیچ‌وقت اسکریپت inject‌شده را commit نکن. `auto-commit.sh` این را حل می‌کند.

### یک باگ واقعی در carbonize که دیدم

بلوک carbonize‌ی تولیدشده، CSS **همان نسخه‌ای که پذیرفته شده** را تضمین نمی‌کند:
در session `5d3b39f5` نسخه‌ی ۲ پذیرفته شد ولی `<style>` داخل بلوک حاوی CSS نسخه‌ی ۱
بود. پس **کپی نکن**؛ CSS نسخه‌ی پذیرفته‌شده را از منبع اصلی (فایل staged خودت یا
دوباره از روی markup) بازسازی کن و بعد migrate کن.

---

## ۶. وضعیت GitHub — کاری که ناتمام مانده

```
remote: https://github.com/flowebco/rewind
branch: main — جلوتر از origin/main
credential helper: (تنظیم نشده)
~/.git-credentials: ندارد      ~/.netrc: ندارد      env token: ندارد
```

`git ls-remote` موفق است، یعنی دسترسی **عمومی و فقط‌خواندنی** کار می‌کند.
ولی **push نمی‌شود** چون هیچ اعتبارنامه‌ای وجود ندارد.

### برای اینکه push کار کند، کاربر باید یکی از این‌ها را بدهد

```sh
# گزینه ۱: PAT در URL (ساده‌ترین)
git -C <repo> remote set-url origin https://<USER>:<PAT>@github.com/flowebco/rewind

# گزینه ۲: credential store
git config --global credential.helper store
echo 'https://<USER>:<PAT>@github.com' >> ~/.git-credentials
```

⚠️ توجه: مسیرهای credential در snapshot این محیط **ذخیره نمی‌شوند**
(`.git/config`, `.git-credentials`, `.netrc` مستثنی هستند). یعنی حتی اگر تنظیم
کنی، ممکن است در session بعدی از بین رفته باشد. پس push را **بلافاصله بعد از
تنظیم** انجام بده و به ماندگاری‌اش اعتماد نکن.

**هرگز بدون اجازه‌ی صریح کاربر push نکن.**

---

## ۷. ترجیح‌های کاربر (از steerهای دریافتی)

این‌ها را کاربر صریحاً گفته؛ رعایتشان اجباری است:

1. **فارسی صحبت کن.** گزارش‌ها و توضیح‌ها به فارسی.
2. **فعلاً دارک مود استفاده نکن.**
3. **ایده‌ی گلس خوب بود** — ولی باید **روی سطح روشن** پیاده شود، نه پایه‌ی تیره.

درباره‌ی گلس روشن یک واقعیت فنی که باید بدانی: `backdrop-filter: blur()` روی زمینه‌ی
تقریباً یکدست `#e5edf5` **تأثیر بصری محسوسی ندارد**، چون چیز متفاوتی پشت شیشه نیست.
برای اینکه گلسِ روشن خوانده شود باید تنوع رنگیِ زیر شیشه باشد — بهترین گزینه
استفاده از همان `conic-gradient(from var(--ai-angle))` چرخان است که **موتیف امضای
خود سایت** است (در `css/blog.css:1163` و `css/styles.css:552` و `:723`).

### کنتراست — عدد حدس نزن، حساب کن

اگر روزی سطح تیره لازم شد، این‌ها اندازه‌گیری‌شده هستند:

| رنگ متن | روی `#2d3748` |
|---|---|
| `#e5edf5` | 10.14:1 (AAA) |
| `#ffb27a` | 6.79:1 (AA) |
| `#e75a08` (`--accent`) | 3.35:1 (فقط AA-large) |
| `#c95e00` (`--accent-darken`) | **2.90:1 — FAIL** |

یعنی `--accent-darken` روی سطح تیره به‌عنوان متن **غیرقابل استفاده** است.
و برای شیشه با alpha روی زمینه‌ی روشن: در `alpha 0.88` متن `#e5edf5` می‌شود
6.87:1 و اکسنت `#ffb27a` می‌شود 4.61:1 (AA)؛ در `alpha 0.80` اکسنت به 3.88:1
می‌افتد و **رد می‌شود**. پس alpha را زیر ۰.۸۵ نبر.

---

## ۸. کارهای انجام‌شده تا اینجا

| commit | محتوا |
|---|---|
| `e295a01` | کانفیگ live mode، `.gitignore`، untrack کردن `server.json`، `chmod +x` لانچر |
| `9d349cd` | هیرو به «میز مطالعه‌ی وسط‌چین» (از session `4e3b18bf`) |
| `cccb388` | هیرو به «مسیر خواندن + ریل اقدام» (از session `5d3b39f5`) |
| `d7ae072` | `scripts/` و `AGENTS.md` |
| (بعدی) | `README.md` به‌عنوان نقطه‌ی ورود، `scripts/restore.sh`، و بخش ۹٫۵ |

دو round هم **رد** شد: `delight` روی هیرو، و `bolder` با گلس تیره روی CTA.

**جابجایی مخزن:** کار ابتدا در `/home/node/rewind` شروع شد، بعد به
`"$ARENA_WORKSPACE"/rewind` منتقل شد چون داخل workspace پایدار و ریشه‌ی تونل بود — و بعد
**دوباره به `/home/node/rewind` برگشت**، چون کشف شد `"$ARENA_WORKSPACE"` در `ls /home`
ظاهر نمی‌شود و VS Code Server هم نمی‌تواند ببیندش (بخش ۹٫۵ الف). کپی قدیمیِ
`/home/node/rewind` به `/home/node/rewind-STALE-2026-10-17` منتقل شد و از تاریخچه‌ی
git آن در `/tmp/rewind-node-OLD-git-backup.tgz` پشتیبان گرفته شد. هیچ کار محصولی
در آن کپی نبود که از دست برود.

⚠️ اگر یک کپی در `"$ARENA_WORKSPACE"/rewind` هم دیدی، **کهنه است**. مسیر زنده
`/home/node/rewind` است.

اسکن `detect --json --scope layout` الان **۰ finding** است. قبلاً یک
`nested-cards` («Card inside card (search)») داشت که با حذف border/background/
padding/`--pressed-deep` از `.hero-well` برطرف شد — حالا تنها لایه‌ی عمق در هیرو
خودِ input است.

---

## ۹. یک بدهیِ مستندسازی که باید بدانی

`DESIGN.md` می‌گوید «Avoid hard outlines and black shadows» و «Don't use black or
hard-offset shadows, unrelated card backgrounds, or sharp borders» و شعاع‌ها را از
`8px` شروع می‌کند. **هیچ primitive شیشه یا blur در آن تعریف نشده.**

تا وقتی کاربر دارک مود را رد کرده، این تضاد فعال نیست. ولی اگر روزی یک سطح تیره یا
گلس پذیرفته شد، `DESIGN.md` **باید** در همان commit به‌روز شود — وگرنه pass بعدیِ
impeccable آن بخش را به‌عنوان نقص می‌بیند و برمی‌گرداند.

یک ایراد مستقل هم هست که هنوز دست‌نخورده مانده: `.blog-hero h1` مقدار
`font-size: clamp(2rem, 3.2vw, 3.2rem)` دارد. وسط `clamp()` باید یک length با واحد
نسبی مثل `vw+rem` باشد؛ `3.2vw` اینجا نادیده گرفته می‌شود و عملاً `3.2vw` اعمال
می‌گردد — یعنی همان «viewport-width-scaled typography» که `DESIGN.md` منع کرده.

---

## ۹٫۵. چهار تله‌ای که بعداً کشف شدند

این‌ها را دیر یاد گرفتم و هر کدام یک بار کار را خراب کرد.

### الف) `"$ARENA_WORKSPACE"` اصلاً در `/home` فهرست نمی‌شود

```
os.listdir('/home')          → ['node']     ← فقط node
os.path.isdir('"$ARENA_WORKSPACE"')  → True         ← ولی با مسیر مطلق می‌شود رسید
is symlink                   → False
inode "$ARENA_WORKSPACE" = 1506  <  inode /home = 1334133   ← از فایل‌سیستم دیگری mount شده
```

یعنی workspace پایدارِ agent یک mount جداست که در فهرست والد دیده نمی‌شود.
**VS Code Server هم در همان namespace است، پس کاربر هرگز نمی‌تواند آن را ببیند.**
نتیجه: اگر کاربر باید فایل‌ها را در VS Code ببیند و ویرایش کند، مخزن باید زیر
`/home/node/...` باشد، نه `"$ARENA_WORKSPACE"/...`. تونل می‌تواند URL یک مسیر
`"$ARENA_WORKSPACE"` را چاپ کند (چون CLI همان‌جا اجرا شده) ولی آن پوشه در explorer کاربر
باز نمی‌شود.

### ب) `server.json` کهنه باعث می‌شود `impeccable live` دروغ بگوید

اگر `.impeccable/live/server.json` به pid مرده اشاره کند، `impeccable live`
خروجی `ok: true` و `serverPort: 8400` می‌دهد **بدون اینکه واقعاً هلپری بالا
بیاورد**. بعد پورت ۸۴۰۰ بسته است و پروکسی `502 helper unreachable` برمی‌گرداند.
راه‌حل: قبل از boot، اگر pid داخل `server.json` در `/proc` نبود، فایل را پاک کن.
`restore.sh` این را خودش انجام می‌دهد.

### پ) دو تونل همزمان = توکن برای همیشه باطل

اگر دو پروسه‌ی تونل با یک نام همزمان ثبت‌نام کنند، سمت سرویس نشست باطل می‌شود.
علامتش: `token.json` هنوز ۱۴۲ بایت است و سر جایش، ولی `tunnel user show` می‌گوید
`not logged in`. تنها راه نجات، authorize کردن یک کد دستگاه جدید است.

و بدتر: **الگوی تشخیص پروسه‌ی خودم باعث این مشکل شد.** `case` روی رشته‌ی کامل
cmdline با الگوی `*code*tunnel*` نوشته بودم، و چون دستور بررسیِ خودم هم آن رشته
را در خود داشت، پروسه‌ی موقتِ bash خودم را «تونل رقیب» تشخیص می‌دادم و می‌کشتم.
تشخیص درست بر اساس argv است:

```sh
a0=$(tr '\0' '\n' < /proc/$pid/cmdline | head -1)
a1=$(tr '\0' '\n' < /proc/$pid/cmdline | sed -n 2p)
case "$a0" in */code) [ "$a1" = tunnel ] && echo "تونل واقعی $pid" ;; esac
```

### ت) ترتیب تونل: اول authorize، بعد URL

تا وقتی `"tunnel":"Connected"` را در `tunnel status` **با چشم ندیده‌ای**، آدرس
`https://vscode.dev/tunnel/<name>/<path>` را به کاربر نده. قبل از ثبت‌نام، آن URL
به هیچ چیز اشاره نمی‌کند و کاربر می‌گوید «لینک کانکت نشد». ترتیب درست:

1. `tunnel-service.sh start`
2. کد دستگاه را از لاگ بخوان و به کاربر بده
3. کاربر authorize کند
4. `tunnel status` → باید `"tunnel":"Connected"` و `name`/`tunnel_id` غیر null باشد
5. **حالا** URL را بده

---

## ۱۰. چک‌لیست شروع

```sh
sh scripts/restore.sh --status        # وضعیت فعلی، چیزی را عوض نمی‌کند
sh scripts/setup.sh --status          # (قدیمی‌تر؛ restore.sh را ترجیح بده)
sh scripts/trim-extensions.sh status  # باید ۶ فعال باشد
sh scripts/tunnel-service.sh status   # باید Connected باشد
sh scripts/auto-commit.sh --dry-run   # چه چیزی commit می‌شد
```

اگر `tunnel-service.sh status` گفت `STOPPED` یا لاگ کد دستگاه داد، به کاربر بگو
دستگاه را authorize کند — خودت نمی‌توانی.

و یادت باشد: **قبل از اینکه بگویی چیزی آماده است، `tunnel status` را بگیر و
`"tunnel":"Connected"` را با چشم ببین.**
