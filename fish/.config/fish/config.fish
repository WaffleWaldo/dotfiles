source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
set -x BROWSER google-chrome

export PATH="$HOME/.local/bin:$PATH"

# ─── Starship prompt ───
if command -q starship
    set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
    set -gx STARSHIP_LOG "error"
    starship init fish | source
end

# ─── Zoxide (smart cd) ───
if command -q zoxide
    zoxide init fish | source
end

# ─── Atuin (shell history) ───
if command -q atuin
    atuin init fish | source
end

# ─── Aliases ───
alias cat="bat --paging=never"
alias l="eza -lF --time-style=long-iso --icons"
alias ll="eza -h --git --icons --color=auto --group-directories-first -s extension"
alias tree="eza --tree --icons"
alias cavalier="setsid flatpak run org.nickvision.cavalier &>/dev/null &"
alias spotify="setsid spotify-launcher &>/dev/null &"

# ─── Yazi file manager (cd on exit) ───
function fm
    set -l tmp (mktemp -t "yazi-cwd.XXXXX")
    yazi $argv --cwd-file $tmp
    set -l cwd (cat $tmp)
    if test -n "$cwd" -a "$cwd" != "$PWD"
        cd $cwd
    end
    rm -f $tmp
end
