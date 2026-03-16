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

      echo "Starting Ubuntu noVNC VPS..."

      mkdir -p ~/vps
      cd ~/vps

      # Start container
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


      echo "Waiting for VNC..."

      until nc -z localhost 10000; do
        sleep 1
      done


      echo "Installing Chrome..."

      docker exec ubuntu-novnc bash -c "

        apt update
        apt remove -y firefox || true

        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O chrome.deb
        apt install -y ./chrome.deb
        rm chrome.deb
      "


      echo "Starting Cloudflare Tunnel..."

      pkill cloudflared || true

      nohup cloudflared tunnel --no-autoupdate --url http://localhost:10000 \
      > cloudflared.log 2>&1 &


      echo "Getting tunnel URL..."

      URL=""

      for i in {1..30}; do

        URL=$(grep -oE 'https://[-a-z0-9]*\.trycloudflare\.com' cloudflared.log | head -n1)

        if [ -n "$URL" ]; then
          break
        fi

        sleep 2

      done


      echo ""
      echo "======================================"
      echo " Ubuntu Web Desktop Ready "
      echo ""
      echo " Link: $URL"
      echo " Password: 12345678"
      echo "======================================"

      echo "VPS running..."

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
