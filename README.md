
## Installing Unity7 on Manjaro Linux

Insert the following lines right above [extra] in /etc/pacman.conf:

```
   [unity7]
   SigLevel = Required DatabaseOptional
   https://manjaro.github.io/unity-for-manjaro/x86_64/
```

Install Unity:

```
   sudo sh -c "pacman -Syyu; pacman -S unity-meta"
```

Switch to LightDM as the default display manager after disabling the current display manager:

```
   sudo systemctl enable --now lightdm
```

Voila! You should now see Unity in the session list, and be able to log into it.

