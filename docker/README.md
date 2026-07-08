# Docker Environment

این image یک محیط آموزشی برای P4، BMv2 و Mininet می‌سازد. مسیر اصلی نصب از packageهای `p4lang-p4c` و `p4lang-bmv2` در repository رسمی p4lang روی OpenSUSE Build Service استفاده می‌کند. این مسیر سبک‌تر و قابل نگهداری‌تر از build کامل source داخل Docker است.

## Build

مناسب برای همه‌ پلتفرم ها:

```bash
docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .
```

## Run

```bash
docker run --rm -it --platform linux/amd64 --privileged -v "$PWD":/workspace p4-dataplane-hw
```

`--privileged`:
برای Mininet لازم است، چون Mininet باید network namespace، veth pair و interfaceهای مجازی بسازد و تغییر دهد.

## Verify

داخل container:

```bash
docker/verify-env.sh
```

این script ابزارهای زیر را بررسی می‌کند:

- `p4c`
- `simple_switch`
- `simple_switch_CLI`
- `mn`
- `python3`
- `tcpdump`
- `tshark`
- `ip`
- `ping`
- `ifconfig`
- `scapy`

## Platform Notes

محیط Linux x86_64 معمولا کم‌دردسرترین است. روی Linux x86_64، اگر `docker buildx` در دسترس نبود، `docker build -t p4-dataplane-hw .` نیز معمولا کافی است.

اما macOS Intel و macOS Apple Silicon با Docker Desktop قابل استفاده‌اند، اما Mininet در container روی Docker Desktop همیشه رفتاری کاملا مشابه Linux native ندارد. packageهای p4lang در این Dockerfile برای `amd64` استفاده می‌شوند؛ بنابراین روی Apple Silicon حتما image را با `--platform linux/amd64` بسازید و اجرا کنید:

```bash
docker buildx build --platform linux/amd64 --load -t p4-dataplane-hw .
docker run --rm -it --platform linux/amd64 --privileged -v "$PWD":/workspace p4-dataplane-hw
```

در Windows بهتر است Docker Desktop را با WSL2 backend اجرا کنید. برای آزمایش‌های packet capture و Mininet، اجرای همین image داخل یک Linux VM پایدارتر است.

## Fallback

اگر Docker Desktop اجازه‌ی اجرای درست Mininet را نداد، از یکی از این مسیرها استفاده کنید:

- اجرای همین image روی Linux native یا داخل Linux VM
- استفاده از VM رسمی/راهنمای P4 tutorials
- نصب ابزارها روی Ubuntu 22.04 یا Ubuntu 24.04 مطابق مستندات p4lang

## Troubleshooting

اگر `mn` با خطای namespace یا interface شکست خورد، container را با `--privileged` اجرا کرده‌اید یا نه بررسی کنید.

اگر `simple_switch` اجرا شد ولی hostها ارتباط ندارند، ابتدا مطمئن شوید P4 JSON درست compile شده و table entryهای لازم را خودتان وارد کرده‌اید.

اگر `tshark` هنگام build درباره‌ی capture برای کاربران non-root سوال پرسید، Dockerfile از حالت noninteractive استفاده می‌کند و مقدار پیش‌فرض package پذیرفته می‌شود.
