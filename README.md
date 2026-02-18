# Dotfiles

CachyOS configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Setup

```bash
git clone git@github.com:wafflewaldo/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow env bash zsh fish niri noctalia alacritty kitty gtk-qt micro
```

## Packages

| Package     | Contents                                               | Activate           | Deactivate           |
|-------------|--------------------------------------------------------|--------------------|-----------------------|
| `env`       | `.profile` (shared env vars)                           | `stow env`         | `stow -D env`         |
| `bash`      | `.bashrc`, `.bash_profile`                             | `stow bash`        | `stow -D bash`        |
| `zsh`       | `.zshrc`                                               | `stow zsh`         | `stow -D zsh`         |
| `fish`      | `.config/fish/config.fish`                             | `stow fish`        | `stow -D fish`        |
| `niri`      | `config.kdl` + 8 modular cfg files                     | `stow niri`        | `stow -D niri`        |
| `noctalia`  | `settings.json`, `colors.json`, `plugins.json`         | `stow noctalia`    | `stow -D noctalia`    |
| `alacritty` | `alacritty.toml` + `themes/noctalia.toml`              | `stow alacritty`   | `stow -D alacritty`   |
| `kitty`     | `themes/noctalia.conf`                                 | `stow kitty`       | `stow -D kitty`       |
| `gtk-qt`    | GTK 3/4 settings, qt5ct, Kvantum                       | `stow gtk-qt`      | `stow -D gtk-qt`      |
| `micro`     | `settings.json`                                        | `stow micro`       | `stow -D micro`       |

## Adding a new tool

```bash
mkdir -p ~/dotfiles/newtool/.config/newtool/
mv ~/.config/newtool/config.toml ~/dotfiles/newtool/.config/newtool/
cd ~/dotfiles && stow newtool
```

## Removing a tool

```bash
cd ~/dotfiles && stow -D toolname
```

Symlinks are removed but the package stays in git history.

## Alternative themes

Extra theme files live in `extras/themes/`. To try one:

```bash
cp extras/themes/alacritty/gruvbox.toml alacritty/.config/alacritty/themes/noctalia.toml
```

To revert: `git checkout -- alacritty/.config/alacritty/themes/noctalia.toml`
