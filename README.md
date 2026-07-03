My personal repo for using codex and claude in a sandboxed (docker) container.

See the Justfile `just` for the functions one can do.

Basically:

- Contains docker files for creating sandboxed m2 development
- Done using `docker compose`
- The home directory is not part of this repo
- Firewall locks down most egress
- No sudo
- Ubuntu image containing latest M2 as well
- Includes simple emacs too.

Use at your own risk!  I rebase onto this typically, so doing `git pull` might fail 
in an inscrutable list of conflicts...

This was created with the assistance of chatgpt and claude.

