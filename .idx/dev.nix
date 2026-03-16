{ pkgs, ... }: {

  channel = "stable-24.11";

  packages = with pkgs; [
    docker
    cloudflared
    socat
    coreutils
    gnugrep
    sudo
    apt
    systemd
    unzip
    netcat
    wget
  ];

  services.docker.enable = true;

  idx.workspace.onStart = {
    novnc = ''
      set -e

      echo "Starting VPS setup..."

      mkdir -p ~/vps
      cd ~/vps

      # Cleanup (run once)
      if [ ! -f ~/.cleanup_done ]; then
        echo "Cleaning workspace..."
        rm -rf ~/.gradle/* ~/.emu/* || true
        find ~ -mindepth 1 -maxdepth 1 ! -name 'idx-ubuntu22-gui' ! -name '.*' -exec rm -rf {} +
        touch ~/.cleanup_done
      fi

      echo "Checking Docker container..."

      if ! docker ps -a --format '{{.Names}}' | grep -q ubuntu-novnc; then

        docker pull thuonghai2711/ubuntu-novnc-pulseaudio:22.04

        docker run -d \
          --name ubuntu-novnc \
          --shm-size=1g \
          --cap-add=SYS_ADMIN \
          -p 10000:10000 \
          -e VNC_PASSWD=12345678 \
          -e PORT=10000 \
          -e SCREEN_WIDTH=1024 \
          -e SCREEN_HEIGHT=768 \
          -e SCREEN_DEPTH=24 \
          thuonghai2711/ubuntu-novnc-pulseaudio:22.04

      else
        docker start ubuntu-novnc || true
      fi


      echo "Waiting for VNC Web..."

      until nc -z localhost 10000; do
        sleep 1
      done

      echo "Installing Chrome inside container..."

      docker exec ubuntu-novnc bash -lc "

        sudo apt update
        sudo apt remove -y firefox || true

        wget -O /tmp/chrome.deb \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

        sudo apt install -y /tmp/chrome.deb
        rm -f /tmp/chrome.deb
      "


      echo "Starting Cloudflare tunnel..."

      nohup cloudflared tunnel --no-autoupdate \
        --url http://localhost:10000 \
        > /tmp/cloudflared.log 2>&1 &


      echo "Getting public URL..."

      URL=""

      for i in {1..20}; do
        URL=$(grep -o 'https://[a-z0-9.-]*trycloudflare.com' /tmp/cloudflared.log | head -n1)
        [ -n "$URL" ] && break
        sleep 1
      done


      echo ""
      echo "========================================="
      echo "   VPS Web Desktop Ready"
      echo ""
      echo "   Link: $URL"
      echo "   Password: 12345678"
      echo "========================================="


      echo "Keeping workspace alive..."

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
