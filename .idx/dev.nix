{ pkgs, ... }: {

  channel = "stable-24.11";

  packages = with pkgs; [
    docker
    cloudflared
    socat
    coreutils
    gnugrep
    sudo
    wget
    netcat
    unzip
    git
  ];

  services.docker.enable = true;

  idx.workspace.onStart = {
    arch = ''
      set -e

      echo "🚀 Starting Arch noVNC (FINAL BUILD)..."

      mkdir -p ~/vps
      cd ~/vps

      docker rm -f arch-novnc 2>/dev/null || true

      docker run -d \
        --name arch-novnc \
        --shm-size=1g \
        -p 10000:10000 \
        archlinux:latest \
        bash -c "

        echo '📦 Update...'
        pacman -Syu --noconfirm

        echo '📦 Install base...'
        pacman -S --noconfirm xfce4 xfce4-goodies tigervnc xterm git python dbus

        echo '📥 Install noVNC...'
        git clone https://github.com/novnc/noVNC.git /opt/novnc
        git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

        echo '🔧 Setup VNC...'
        mkdir -p ~/.vnc
        echo '12345678' | vncpasswd -f > ~/.vnc/passwd
        chmod 600 ~/.vnc/passwd

        echo '#!/bin/bash
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p \$XDG_RUNTIME_DIR
dbus-daemon --system &
dbus-launch startxfce4 &' > ~/.vnc/xstartup

        chmod +x ~/.vnc/xstartup

        echo '🖥️ Start VNC...'
        vncserver :1

        echo '🌐 Start noVNC...'
        /opt/novnc/utils/websockify/run 10000 localhost:5901 --web /opt/novnc
        "


      echo "⏳ Waiting noVNC ready..."

      for i in {1..60}; do
        if nc -z localhost 10000; then
          echo "✅ noVNC ready!"
          break
        fi
        sleep 2
      done


      echo "☁️ Starting Cloudflare Tunnel..."

      pkill cloudflared || true

      nohup cloudflared tunnel --no-autoupdate --url http://localhost:10000 \
      > tunnel.log 2>&1 &


      echo "🔎 Getting link..."

      URL=""

      for i in {1..30}; do
        URL=$(grep -oE 'https://[-a-z0-9]*\.trycloudflare\.com' tunnel.log | head -n1)
        if [ -n "$URL" ]; then
          break
        fi
        sleep 2
      done


      echo ""
      echo "================================="
      echo " ARCH DESKTOP READY 😎"
      echo ""
      echo " LINK: $URL"
      echo " PASSWORD: 12345678"
      echo "================================="

      while true; do
        sleep 60
      done
    '';
  };


  idx.previews = {
    enable = true;

    previews = {
      novnc = {
        manager = "web";

        command = [
          "bash"
          "-lc"
          "socat TCP-LISTEN:$PORT,fork,reuseaddr TCP:127.0.0.1:10000"
        ];
      };
    };
  };

}
