# rubik.sh

Feeling your eyelids droop during that never-ending meeting? Or maybe you're on your server, bored out of your mind?

rubik.sh is here for you!

```
curl https://raw.githubusercontent.com/psykulsk/rubik.sh/refs/heads/main/rubik.sh -o rubik.sh && \
bash rubik.sh
```

Requires `bash --version` >= 4.0. **Warning**, MacOS is distributed with bash 3 by default. Check the [instructions](#upgrading-bash-on-macos) on how to upgrade it.

### Other bash games
* [tetri.sh](https://github.com/psykulsk/tetri.sh)
* [shnake](https://github.com/psykulsk/shnake)

### Demo
![](demo.gif)

### Upgrading bash on MacOS

* Install a new version of bash using brew: `brew install bash`
* Add `/opt/homebrew/bin/bash` to  `/etc/shells`
* Set is as default with `chsh -s /usr/local/bin/bash`
