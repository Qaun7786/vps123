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
  ];

  services.docker.enable = true;

  idx.workspace.onStart = {
    arch = ''
      set -e

      echo "🚀 Starting Arch noVNC..."

      mkdir -p ~/vps
      cd ~/vps

      if ! docker ps -a --format '{{.Names}}' | grep -q arch-novnc; then

        echo "📦 Pulling Arch image..."
        docker pull archlinux:latest

        echo "📦 Creating Arch container..."

        docker run -d \
          --name arch-novnc \
          --shm-size=1g \
          -p 10000:10000 \
          archlinux:latest \
          bash -c "

          pacman -Syu --noconfirm &&
          pacman -S xfce4 xfce4-goodies tigervnc novnc websockify xterm --noconfirm &&

          mkdir -p ~/.vnc &&
          echo '12345678' | vncpasswd -f > ~/.vnc/passwd &&
          chmod 600 ~/.vnc/passwd &&

          echo '#!/bin/bash
startxfce4 &' > ~/.vnc/xstartup &&
          chmod +x ~/.vnc/xstartup &&

          vncserver :1 &&
          websockify --web=/usr/share/novnc/ 10000 localhost:5901
          "

      else
        docker start arch-novnc || true
      fi


      echo "⏳ Waiting VNC..."

      until nc -z localhost 10000; do
        sleep 1
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
      echo " ARCH VPS READY "
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
