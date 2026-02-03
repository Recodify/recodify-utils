sudo apt update
sudo apt install wslu
echo -e "[interop]\nenabled=true\nappendWindowsPath=true" | sudo tee /etc/wsl.conf > /dev/null
sudo update-alternatives --config x-www-browser