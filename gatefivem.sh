#!/bin/bash

# ==============================================================================
# SKRIP FINAL - INSTALASI PROXY NGINX UNTUK FIVEM DI UBUNTU 20.04
# Dibuat untuk memastikan semua prompt input bekerja dengan benar.
# ==============================================================================

# -- FUNGSI UNTUK MENCETAK PESAN --
print_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

print_success() {
    echo -e "\e[32m[SUKSES]\e[0m $1"
}

print_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
1>&2
}

# Fungsi untuk mengubah target IP server FiveM
change_server_target() {
    print_info "Mode: Mengubah Target Server FiveM"
    
    # Cek apakah Nginx sudah terinstall
    if ! command -v nginx &> /dev/null; then
        print_error "Nginx belum terinstall. Jalankan instalasi lengkap terlebih dahulu."
        exit 1
    fi
    
    # Cek apakah file konfigurasi ada
    if [ ! -f "/etc/nginx/nginx.conf" ] || [ ! -f "/etc/nginx/stream.conf" ] || [ ! -f "/etc/nginx/web.conf" ]; then
        print_error "File konfigurasi Nginx tidak ditemukan. Jalankan instalasi lengkap terlebih dahulu."
        exit 1
    fi
    
    echo ""
    print_info "Mengubah target server FiveM..."
    
    echo -e "--> Masukkan alamat IP (dengan port) server FiveM yang baru (Contoh: 1.1.1.1:30120)"
    read -p "    Alamat IP & Port Server Baru: " new_ip
    
    if [ -z "$new_ip" ]; then
        print_error "IP server tidak boleh kosong!"
        exit 1
    fi
    
    print_info "Membackup konfigurasi lama..."
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
    cp /etc/nginx/stream.conf /etc/nginx/stream.conf.backup.$(date +%Y%m%d_%H%M%S)
    
    print_info "Menerapkan konfigurasi server baru..."
    
    # Download ulang file konfigurasi template
    wget -q https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/nginx.conf -O /etc/nginx/nginx.conf
    wget -q https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/stream.conf -O /etc/nginx/stream.conf
    
    # Terapkan IP baru
    sed -i "s/ip_goes_here/$new_ip/g" /etc/nginx/nginx.conf
    sed -i "s/ip_goes_here/$new_ip/g" /etc/nginx/stream.conf
    
    print_info "Memulai ulang Nginx..."
    systemctl restart nginx
    
    if [ $? -eq 0 ]; then
        print_success "Target server berhasil diubah ke: $new_ip"
        SERVER_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
        echo "Anda sekarang dapat terhubung menggunakan: connect $SERVER_IP"
    else
        print_error "Gagal memulai ulang Nginx. Cek konfigurasi atau log error."
        exit 1
    fi
    
    exit 0
}

# 1. Verifikasi hak akses root
if [ "$(id -u)" != "0" ]; then
   print_error "Skrip ini harus dijalankan sebagai root. Gunakan 'sudo bash nama_skrip.sh'"
   exit 1
fi

# Menu pilihan
echo ""
print_info "=== NGINX PROXY UNTUK FIVEM ==="
echo "Pilih mode operasi:"
echo "1. Instalasi lengkap Nginx + Proxy (untuk pertama kali)"
echo "2. Ubah target server FiveM (jika sudah terinstall)"
echo ""
read -p "Masukkan pilihan (1 atau 2): " choice

case $choice in
    1)
        print_info "Mode: Instalasi Lengkap"
        ;;
    2)
        change_server_target
        ;;
    *)
        print_error "Pilihan tidak valid. Gunakan 1 atau 2."
        exit 1
        ;;
esac

# 2. Instalasi Nginx dari repositori resmi
install_nginx() {
    print_info "Memulai instalasi Nginx..."
    
    # Instal dependensi dasar
    apt-get update >/dev/null 2>&1
    apt-get install -y gnupg2 lsb-release software-properties-common wget curl >/dev/null 2>&1
    
    OS_CODENAME=$(lsb_release -cs)
    
    # Tambahkan kunci GPG resmi Nginx (Otomatis menimpa file yang ada)
    print_info "Menambahkan kunci GPG Nginx..."
    curl -fsSL http://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
    
    # Tambahkan repositori Nginx
    print_info "Menambahkan repositori Nginx..."
    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu/ $OS_CODENAME nginx" | tee /etc/apt/sources.list.d/nginx.list >/dev/null

    # Instal Nginx
    print_info "Menginstal Nginx..."
    apt-get update >/dev/null 2>&1
    apt-get install -y nginx >/dev/null 2>&1
    systemctl enable nginx >/dev/null 2>&1
    systemctl start nginx
    
    print_success "Instalasi Nginx selesai."
}

# Jalankan fungsi instalasi Nginx
install_nginx

# 3. Konfigurasi Firewall UFW
print_info "Mengkonfigurasi firewall UFW..."
ufw --force enable >/dev/null 2>&1
ufw allow 22/tcp >/dev/null 2>&1
ufw allow 80/tcp >/dev/null 2>&1
ufw allow 443/tcp >/dev/null 2>&1
ufw allow 30120/tcp >/dev/null 2>&1
ufw allow 30120/udp >/dev/null 2>&1
print_success "Konfigurasi firewall selesai."

# 4. Bersihkan konfigurasi Nginx sebelumnya
print_info "Membersihkan konfigurasi default Nginx..."
rm -f /etc/nginx/conf.d/default.conf
mkdir -p /etc/nginx/ssl

# ==============================================================================
# BAGIAN INPUT DATA PENGGUNA - HARAP PERHATIKAN DI SINI
# ==============================================================================
echo ""
print_info "Sekarang, harap masukkan data konfigurasi Anda."

echo -e "--> Masukkan alamat IP (dengan port) dari server FiveM Anda (Contoh: 1.1.1.1:30120)"
read -p "    Alamat IP & Port Server: " ip
echo ""
# ==============================================================================

# 5. Unduh file konfigurasi Nginx
print_info "Mengunduh file konfigurasi proxy..."
wget -q https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/nginx.conf -O /etc/nginx/nginx.conf
wget -q https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/stream.conf -O /etc/nginx/stream.conf
wget -q https://raw.githubusercontent.com/MathiAs2Pique/Fivem-Proxy-Install.sh/main/files/web.conf -O /etc/nginx/web.conf

# 6. Ganti placeholder di file konfigurasi dengan input pengguna
print_info "Menerapkan konfigurasi kustom..."
sed -i "s/ip_goes_here/$ip/g" /etc/nginx/nginx.conf
sed -i "s/ip_goes_here/$ip/g" /etc/nginx/stream.conf
# Menggunakan IP server sebagai server_name (tanpa domain)
SERVER_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
sed -i "s/server_name_goes_here/$SERVER_IP/g" /etc/nginx/web.conf

# 7. Mulai ulang Nginx untuk menerapkan semua perubahan
print_info "Memulai ulang Nginx untuk menerapkan semua perubahan..."
systemctl restart nginx

# 8. Selesai
echo ""
print_success "--- INSTALASI SELESAI! ---"
SERVER_IP=$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
echo "Anda sekarang dapat terhubung ke server Anda menggunakan: connect $SERVER_IP"
echo "Atau menggunakan HTTP: connect http://$SERVER_IP"

exit 0
