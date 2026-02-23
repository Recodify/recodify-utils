
wget https://github.com/source-foundry/Hack/releases/download/v3.003/Hack-v3.003-ttf.zip
sudo cp Hack-BoldItalic.ttf /usr/share/fonts
sudo cp Hack-Bold.ttf /usr/share/fonts
sudo cp Hack-Italic.ttf.ttf /usr/share/fonts
sudo cp Hack-Italic.ttf /usr/share/fonts
sudo cp Hack-Regular.ttf /usr/share/fonts
sudo cp 45-Hack.conf /etc/fonts/conf.d/

wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip
unzip Hack.zip
cd Hack
sudo cp -r *.ttf /usr/share/fonts
cp 99--nerd-font.conf /etc/fonts/conf.d/
fc-cache -f -v



