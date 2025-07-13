# FRP Professional Manager 🚀

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/mmdbay/frp-manager)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-red.svg)](https://www.linux.org/)

---

## 🇮🇷 فارسی

### 🎯 درباره این پروژه

این اسکریپت یک ابزار حرفه‌ای و کامل برای مدیریت FRP (Fast Reverse Proxy) است که به شما امکان نصب، پیکربندی و مدیریت آسان سرویس‌های FRP را می‌دهد. با این ابزار می‌توانید سرورهای ایران و خارج از کشور را به راحتی مدیریت کنید.

### ✨ ویژگی‌های کلیدی

- 🚀 **نصب خودکار**: نصب کامل FRP با یک کلیک
- 🔧 **پیکربندی پیشرفته**: تنظیمات حرفه‌ای برای بهینه‌سازی عملکرد
- 📊 **مانیتورینگ**: نمایش وضعیت و لاگ‌های زنده
- 🔒 **امنیت**: پشتیبانی از رمزنگاری و فشرده‌سازی
- 🎛️ **مدیریت آسان**: منوی تعاملی و کاربرپسند
- 🗑️ **حذف کامل**: پاکسازی کامل سیستم

### 📋 پیش‌نیازها

- سیستم عامل: Ubuntu 18.04+, Debian 9+, CentOS 7+, RHEL 7+
- دسترسی root
- اتصال اینترنت
- حداقل 512MB RAM
- حداقل 1GB فضای دیسک

### 🛠️ نصب و راه‌اندازی

```bash
# دانلود اسکریپت
wget https://raw.githubusercontent.com/mmdbay/frp-manager/main/frp.sh

# اعطای مجوز اجرا
chmod +x frp.sh

# اجرای اسکریپت
sudo ./frp.sh
```

### 🎮 نحوه استفاده

#### 1. نصب سرور (ایران)
```bash
# انتخاب گزینه 1 از منو
# وارد کردن اطلاعات پورت و رمز عبور
# نصب خودکار Nginx و تنظیمات firewall
```

#### 2. نصب کلاینت (خارج از کشور)
```bash
# انتخاب گزینه 2 از منو
# وارد کردن IP سرور و توکن
# پیکربندی خودکار سرویس
```

#### 3. تنظیمات پیشرفته
```bash
# گزینه 11: ویرایش تنظیمات پیشرفته سرور
# گزینه 12: ویرایش تنظیمات پیشرفته کلاینت
# گزینه 13: Wizard بهینه‌سازی کانکشن
```

### 🔧 تنظیمات بهینه

#### برای عملکرد بالا:
- Heartbeat Interval: 5-10 ثانیه
- Max Pool Count: 20-25
- Compression: فعال
- Encryption: فعال

#### برای پایداری بالا:
- Heartbeat Interval: 60-90 ثانیه
- Max Pool Count: 8-10
- Compression: غیرفعال
- Max Retry Count: 15

### 📊 مانیتورینگ

```bash
# نمایش وضعیت سرویس‌ها
systemctl status frps
systemctl status frpc

# مشاهده لاگ‌های زنده
journalctl -u frps -f
journalctl -u frpc -f

# بررسی اتصالات
ss -tuln | grep :7000
```

### 🗑️ حذف و پاکسازی

```bash
# حذف کامل
sudo ./frp.sh
# انتخاب گزینه 9 -> گزینه 3

# حذف اتمی (تمام چیزها)
sudo ./frp.sh
# انتخاب گزینه 9 -> گزینه 4 -> تایپ "NUCLEAR"
```

### 🐛 عیب‌یابی

#### مشکل اتصال:
1. بررسی توکن سرور و کلاینت
2. بررسی firewall rules
3. تست connectivity با ping
4. بررسی لاگ‌های خطا

#### مشکل عملکرد:
1. استفاده از Wizard بهینه‌سازی
2. تنظیم heartbeat intervals
3. فعال‌سازی compression
4. بررسی منابع سیستم

### 📞 پشتیبانی

- 📧 ایمیل: muhammadhasanbeygi@gmail.com
- 💬 تلگرام: @Aq_Qoyunlu
- 🐛 گزارش باگ: [Issues](https://github.com/mmdbay/frp-manager/issues)

---

## 🇺🇸 English

### 🎯 About This Project

This script is a professional and comprehensive tool for managing FRP (Fast Reverse Proxy) that allows you to easily install, configure, and manage FRP services. With this tool, you can easily manage servers in Iran and abroad.

### ✨ Key Features

- 🚀 **Auto Installation**: Complete FRP installation with one click
- 🔧 **Advanced Configuration**: Professional settings for performance optimization
- 📊 **Monitoring**: Live status and log display
- 🔒 **Security**: Support for encryption and compression
- 🎛️ **Easy Management**: Interactive and user-friendly menu
- 🗑️ **Complete Removal**: Full system cleanup
- 🌐 **Multi-language Support**: Persian and English

### 📋 Requirements

- OS: Ubuntu 18.04+, Debian 9+, CentOS 7+, RHEL 7+
- Root access
- Internet connection
- Minimum 512MB RAM
- Minimum 1GB disk space

### 🛠️ Installation & Setup

```bash
# Download script
wget https://raw.githubusercontent.com/mmdbay/frp-manager/main/frp.sh

# Make executable
chmod +x frp.sh

# Run script
sudo ./frp.sh
```

### 🎮 How to Use

#### 1. Server Installation (Iran)
```bash
# Select option 1 from menu
# Enter port and password information
# Automatic Nginx installation and firewall configuration
```

#### 2. Client Installation (Abroad)
```bash
# Select option 2 from menu
# Enter server IP and token
# Automatic service configuration
```

#### 3. Advanced Settings
```bash
# Option 11: Edit advanced server configuration
# Option 12: Edit advanced client configuration
# Option 13: Connection optimization wizard
```

### 🔧 Optimal Settings

#### For High Performance:
- Heartbeat Interval: 5-10 seconds
- Max Pool Count: 20-25
- Compression: Enabled
- Encryption: Enabled

#### For High Stability:
- Heartbeat Interval: 60-90 seconds
- Max Pool Count: 8-10
- Compression: Disabled
- Max Retry Count: 15

### 📊 Monitoring

```bash
# Check service status
systemctl status frps
systemctl status frpc

# View live logs
journalctl -u frps -f
journalctl -u frpc -f

# Check connections
ss -tuln | grep :7000
```

### 🗑️ Removal & Cleanup

```bash
# Complete removal
sudo ./frp.sh
# Select option 9 -> option 3

# Nuclear removal (everything)
sudo ./frp.sh
# Select option 9 -> option 4 -> type "NUCLEAR"
```

### 🐛 Troubleshooting

#### Connection Issues:
1. Check server and client tokens
2. Verify firewall rules
3. Test connectivity with ping
4. Check error logs

#### Performance Issues:
1. Use optimization wizard
2. Adjust heartbeat intervals
3. Enable compression
4. Check system resources

### 📞 Support

- 📧 Email: muhammadhasanbeygi@gmail.com
- 💬 Telegram: @Aq_Qoyunlu
- 🐛 Bug Report: [Issues](https://github.com/mmdbay/frp-manager/issues)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

We welcome contributions! Please feel free to submit a Pull Request.

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=mmdbay/frp-manager&type=Date)](https://star-history.com/#mmdbay/frp-manager&Date)

---

<div align="center">

**Made with ❤️ for the mmdbay**

[![GitHub stars](https://img.shields.io/github/stars/mmdbay/frp-manager?style=social)](https://github.com/mmdbay/frp-manager)
[![GitHub forks](https://img.shields.io/github/forks/mmdbay/frp-manager?style=social)](https://github.com/mmdbay/frp-manager)
[![GitHub issues](https://img.shields.io/github/issues/mmdbay/frp-manager)](https://github.com/mmdbay/frp-manager/issues)

</div>