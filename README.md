# Dotfiles

CachyOS + niri + noctalia-shell configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

Inspired by [linuxmobile/shin](https://github.com/linuxmobile/shin).

## Setup

```bash
git clone git@github.com:wafflewaldo/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow env bash zsh fish niri noctalia alacritty ghostty foot kitty gtk-qt micro starship fastfetch yazi nvim nvim-lazy zellij
```

### Dependencies

```bash
paru -S --needed niri ghostty foot alacritty starship zoxide fzf bat atuin yazi \
  cliphist wl-clipboard swww apple-fonts ttf-nerd-fonts-symbols noto-fonts-emoji \
  bibata-cursor-theme whitesur-icon-theme spotify-launcher \
  neovim zellij fnm uv cmake clang python-pip
flatpak install flathub org.nickvision.cavalier
```

## Packages

| Package      | Contents                                               | Activate            | Deactivate            |
|--------------|--------------------------------------------------------|---------------------|-----------------------|
| `env`        | `.profile` (shared env vars)                           | `stow env`          | `stow -D env`         |
| `bash`       | `.bashrc`, `.bash_profile`                             | `stow bash`         | `stow -D bash`        |
| `zsh`        | `.zshrc`                                               | `stow zsh`          | `stow -D zsh`         |
| `fish`       | `.config/fish/config.fish`                             | `stow fish`         | `stow -D fish`        |
| `niri`       | `config.kdl` + 8 modular cfg files                     | `stow niri`         | `stow -D niri`        |
| `noctalia`   | `settings.json`, `colors.json`, `plugins.json`         | `stow noctalia`     | `stow -D noctalia`    |
| `ghostty`    | `config` + `themes/noctalia` (SF Mono, noctalia)       | `stow ghostty`      | `stow -D ghostty`     |
| `foot`       | `foot.ini` + `themes/noctalia` (SF Mono, transparent)  | `stow foot`         | `stow -D foot`        |
| `alacritty`  | `alacritty.toml` + `themes/noctalia.toml`              | `stow alacritty`    | `stow -D alacritty`   |
| `kitty`      | `themes/noctalia.conf`                                 | `stow kitty`        | `stow -D kitty`       |
| `starship`   | `starship.toml` (minimal prompt)                       | `stow starship`     | `stow -D starship`    |
| `fastfetch`  | `config.jsonc` + `logo.png` (sixel image logo)         | `stow fastfetch`    | `stow -D fastfetch`   |
| `yazi`       | `yazi.toml` + `theme.toml`                             | `stow yazi`         | `stow -D yazi`        |
| `gtk-qt`     | GTK 3/4 settings, qt5ct, Kvantum                       | `stow gtk-qt`       | `stow -D gtk-qt`      |
| `micro`      | `settings.json`                                        | `stow micro`        | `stow -D micro`       |
| `nvim`       | `init.lua` (minimal, no plugins)                       | `stow nvim`         | `stow -D nvim`        |
| `nvim-lazy`  | LazyVim IDE config (Python/TS/Svelte/C++)              | `stow nvim-lazy`    | `stow -D nvim-lazy`   |
| `zellij`     | `config.kdl` + `layouts/code.kdl`                      | `stow zellij`       | `stow -D zellij`      |

## Theming

- **Color scheme**: Noctalia (Material You dark, `#131316` base)
- **Cursor**: Bibata-Original-Ice (size 20)
- **Icons**: WhiteSur
- **Font (UI)**: SF Pro Display
- **Font (terminal)**: SF Mono (Foot/Ghostty), JetBrains Mono (Alacritty)
- **GTK theme**: adw-gtk3-dark

## Keybinds (niri)

| Key                  | Action                    |
|----------------------|---------------------------|
| `Mod+Return`         | Open Foot                 |
| `Mod+Shift+Return`   | Open Ghostty              |
| `Mod+D`              | App launcher              |
| `Mod+V`              | Clipboard history         |
| `Mod+Q`              | Close window              |
| `Mod+Space`           | Toggle floating            |
| `Mod+S`              | Cycle preset widths       |
| `Mod+1/2/3/4`        | Set column 25/50/75/100%  |
| `Mod+Comma`          | Consume into column       |
| `Mod+Shift+Period`    | Expel from column         |
| `Mod+W`              | Toggle tabbed display     |
| `Print`              | Screenshot (screen)       |
| `Mod+Shift+S`        | Screenshot (region)       |

## Neovim configs

Multiple configs via `NVIM_APPNAME`:

| Command      | Config         | Description                          |
|-------------|----------------|--------------------------------------|
| `nvim`      | `~/.config/nvim` | Minimal baseline (no plugins)       |
| `nvim-lazy` | `~/.config/nvim-lazy` | LazyVim IDE (full LSP/formatting) |

Adding a new config (e.g., AstroNvim):
```bash
git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim-astro
# Add alias to fish: alias nvim-astro="NVIM_APPNAME=nvim-astro nvim"
# Optionally stow it into dotfiles
```

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
