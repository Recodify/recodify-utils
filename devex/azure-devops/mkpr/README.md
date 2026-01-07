# Create a PR from terminal TFS/Azure-Devops

## Setup
Add the following to your ~/.bashrc

```bash
export UTILS_ROOT='/home/shiles/code/recodify-utils/devex'

if [ -f $UTILS_ROOT/azure-devops/mkpr/mkpr.sh ]; then
    . $UTILS_ROOT/azure-devops/mkpr/mkpr.sh    
    alias mkpr='mkpr_azdo'
fi
```

## Usage

```bash
git push origin <branch>
mkpr
```

### Notes

If using WSL this command will likely launch a firefox instance. If you want to choose another browser
see: ./devex/wsl/bash/set-default-browser.sh in this repo.