# Starter Environment

این پوشه فقط برای شروع کار است و solution تمرین را در اختیار شما نمی‌گذارد.

## Files

- `p4/warmup_example.p4`: یک نمونه‌ی بسیار کوچک P4 که فقط ساختار کلی header، parser، control و deparser را نشان می‌دهد و compile می‌شود.
- `topology/topology.py`: توپولوژی Mininet با یک BMv2 switch و شش host.
- `scripts/compile.sh`: compile کردن یک فایل P4 به BMv2 JSON.
- `scripts/run_mininet.sh`: اجرای topology با JSON انتخاب‌شده.
- `scripts/capture.sh`: کمک برای گرفتن packet capture.
- `scripts/smoke_test.sh`: بررسی سریع اینکه محیط و topology قابل اجرا هستند.
- `config/`: محل پیشنهادی برای فایل‌های runtime configuration شما.

## What Is Not Provided

موارد زیر عمدا در starter وجود ندارند:

- پیاده‌سازی IPv4 router
- tableها و actionهای forwarding
- classifier، firewall یا QoS pipeline
- ruleهای آماده‌ی `simple_switch_CLI`
- پاسخ طراحی یا diagram pipeline

طراحی واقعی data plane، ترتیب stageها، metadata، tableها و testها بخشی از تمرین شماست.

## Suggested First Steps

```bash
starter/scripts/compile.sh starter/p4/warmup_example.p4
starter/scripts/run_mininet.sh starter/p4/warmup_example.json
```

پس از اطمینان از کارکرد محیط، فایل P4 خودتان را در یک مسیر جداگانه بسازید و به تدریج parser، forwarding، classification، QoS و policy را اضافه کنید.
