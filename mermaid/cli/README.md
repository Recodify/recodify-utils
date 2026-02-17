watch

```bash
sudo apt install entr
find docs -name '*.md' | entr -c ./render-mermaid-svgs.sh docs
```
