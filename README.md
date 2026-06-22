# P4 Data Plane Homework Package

این مخزن بسته‌ی تمرین عملی درس شبکه‌های کامپیوتری برای مبحث Network Layer - Data Plane است. متن اصلی تمرین در فایل [handout/homework.tex](/Users/parmis/Desktop/books/TA/CN-SadeghZade-2026-spring/handout/homework.tex) و نسخه‌ی PDF، پس از کامپایل LaTeX، در `handout/homework.pdf` قرار می‌گیرد.

هدف تمرین طراحی و ارزیابی data plane یک سوئیچ برنامه‌پذیر با P4، BMv2، Mininet و Docker است. این مخزن starter code کامل یا solution ندارد.

## Clone

پس از انتشار نسخه‌ی نهایی، دانشجویان باید از release tag استفاده کنند:

```bash
git clone https://github.com/promise2-4/CN2026-HW3-P4-Dataplane.git
cd <repo-name>
git checkout v1.0
```

## Build Docker Image

Recommended command for Linux, macOS Intel, macOS Apple Silicon, and Windows/WSL2:

```bash
docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .
```

اجرای محیط:

```bash
docker run --rm -it --platform linux/amd64 --privileged -v "$PWD":/workspace p4-dataplane-hw
```

گزینه‌ی `--privileged` معمولا برای Mininet لازم است، چون Mininet namespace، virtual Ethernet interface و تنظیمات شبکه‌ی داخل container را مدیریت می‌کند.

packageهای آماده‌ی p4lang برای `amd64` منتشر شده‌اند؛ به همین دلیل command بالا حتی روی Apple Silicon هم image را با emulation اجرا می‌کند. در macOS و Windows، Docker Desktop همه‌ی رفتارهای شبکه‌ی Linux را دقیقا مثل یک ماشین Linux واقعی نشان نمی‌دهد. اگر Mininet یا packet capture درست کار نکرد، همان image را داخل یک Linux VM اجرا کنید یا از محیط رسمی P4 tutorials/VM استفاده کنید.

## Verify Environment

داخل container:

```bash
docker/verify-env.sh
```

این script وجود ابزارهای اصلی مانند `p4c`، `simple_switch`، `simple_switch_CLI`، `mn`، `python3`، `tcpdump` و `tshark` را بررسی می‌کند.

## Compile A P4 File

نمونه‌ی warmup:

```bash
starter/scripts/compile.sh starter/p4/warmup_example.p4
```

خروجی پیش‌فرض در کنار فایل P4 و با پسوند `.json` ساخته می‌شود.

## Start Mininet

ابتدا P4 program را compile کنید، سپس:

```bash
starter/scripts/run_mininet.sh starter/p4/warmup_example.json
```

این topology فقط برای شروع و آزمایش محیط است. رفتار کامل خواسته‌شده در تمرین باید توسط دانشجو طراحی و پیاده‌سازی شود.

## Capture Traffic

```bash
starter/scripts/capture.sh h1-eth0
starter/scripts/capture.sh h5-eth0 "ip"
```

برای DSCP می‌توانید از `tcpdump -vv` یا `tshark` استفاده کنید.

## Cleanup

```bash
starter/scripts/cleanup.sh
```

## Submission

دانشجو باید موارد زیر را تحویل دهد:

- کد P4 و فایل‌های configuration لازم
- جدول test و خروجی terminal برای testهای خواسته‌شده
- packet capture برای DSCP و حداقل چند سناریوی allowed/blocked
- `report.pdf` شامل خلاصه طراحی، جدول test، شواهد packet و روش اجرای کد
- demo video با زمان ۵ تا ۸ دقیقه

جزئیات کامل در handout آمده است.

## Publishing Workflow For Instructor

Commitهای پیشنهادی:

1. Initial repository structure and LaTeX template integration
2. Add Docker-based P4 development environment
3. Add starter topology and warmup example
4. Add Persian homework handout
5. Add verification scripts and instructor checklist
6. Final release cleanup

دستورات پیشنهادی:

```bash
git init
git add .
git commit -m "Initial P4 dataplane homework package"
git branch -M main
git remote add origin https://github.com/promise2-4/CN2026-HW3-P4-Dataplane.git
git push -u origin main
```

Release tag:

```bash
git tag v1.0
git push origin v1.0
```

پیش از انتشار، درستی نشانی GitHub را در فایل‌ها بررسی کنید:
`https://github.com/promise2-4/CN2026-HW3-P4-Dataplane.git`
