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
    novnc = ''
      set -e

      echo "Starting Ubuntu noVNC..."

      mkdir -p ~/vps
      cd ~/vps

      if ! docker ps -a --format '{{.Names}}' | grep -q ubuntu-novnc; then

        docker pull thuonghai2711/ubuntu-novnc-pulseaudio:22.04

        docker run -d \
          --name ubuntu-novnc \
          --shm-size=1g \
          --cap-add=SYS_ADMIN \
          -p 10000:10000 \
          -e VNC_PASSWD=12345678 \
          -e PORT=10000 \
          -e SCREEN_WIDTH=1280 \
          -e SCREEN_HEIGHT=800 \
          -e SCREEN_DEPTH=24 \
          thuonghai2711/ubuntu-novnc-pulseaudio:22.04

      else
        docker start ubuntu-novnc || true
      fi


      echo "Waiting VNC..."

      until nc -z localhost 10000; do
        sleep 1
      done


      echo "Installing Chrome + VSCode..."

      docker exec -u root ubuntu-novnc bash -c "

      apt-get update

      apt-get install -y wget gpg

      # Chrome
      wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
      apt-get install -y /tmp/chrome.deb

      # VS Code
      wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/ms.gpg
      echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/ms.gpg] https://packages.microsoft.com/repos/vscode stable main' > /etc/apt/sources.list.d/vscode.list
      apt-get update
      apt-get install -y code

      rm -f /tmp/chrome.deb
      "


      echo "Starting Cloudflare Tunnel..."

      pkill cloudflared || true

      nohup cloudflared tunnel --no-autoupdate --url http://localhost:10000 \
      > tunnel.log 2>&1 &


      echo "Getting link..."

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
      echo " VPS READY "
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
