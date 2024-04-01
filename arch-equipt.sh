#!/usr/bin/env bash

setup_dotfiles()
{
    read -rp "Setup dotfiles? (y|n)?: " ret
    [[  -n "$ret" && "$ret" =~ [N|n] ]] && return

    [ -d "$HOME"/.dotfiles ] && echo "dotfiles already exist" && return
    src="$HOME"/dotfiles.tmp
    git clone --separate-git-dir="$HOME"/.dotfiles \
	git@github.com:zijian-x/.dotfiles.git "$src" &&
	find "$src" -mindepth 1 -maxdepth 1 -exec cp -rf {} "$HOME" \; &&
	rm -rf "$src" &&
	git --git-dir="$HOME"/.dotfiles --work-tree="$HOME" \
	config --local status.showUntrackedFiles no

    # extra config for alcty-padding
    cp -f "$HOME/.config/alacritty/window.toml.template" "$HOME/.config/alacritty/window.toml"
}

setup_aur()
{
    read -rp "Setup AUR with paru? (y|n)?: " ret
    [[  -n "$ret" && "$ret" =~ [N|n] ]] && return

    paru_git='/tmp/paru'
    git clone 'https://aur.archlinux.org/paru.git' "$paru_git" &&
	cd "$paru_git" && yes | makepkg -sirc && rm -rf "$paru_git"
}

symlink_etc_conf()
{
    read -rp "Setup /etc symlinks? (y|n)?: " ret
    [[  -n "$ret" && "$ret" =~ [N|n] ]] && return

    [ ! -f /etc/udev/rules.d/95-battery.rules ] &&
	sudo cp ~/.local/bin/polybar/95-battery.rules /etc/udev/rules.d/

    path="$HOME/.config/etc"
    configs=$(find "$path" -type f)

    for src in $configs; do
	target="$(echo "$src" | sed "s;$HOME/.config;;")"
	dir="$(dirname "$target")"
	[ ! -d "$dir" ] && sudo mkdir "$dir" &&
	    echo "=> mkdir $dir"
	echo "=> force symlink $src to $target"
	sudo ln -sf "$src" "$target"
    done
}

install_cron()
{
    cron_file="${XDG_CONFIG_HOME:-$HOME/.config}/cron/cron_file"
    read -rp "Install cron_file (y|n)?: " ret
    [[  -n "$ret" && "$ret" =~ [N|n] ]] && return

    [[ -f "$cron_file" ]] && sudo crontab -u "$(whoami)" "$cron_file"
}

setup_dropbox()
{
    read -rp "Install dropbox (y|n)?: " ret
    [[  -n "$ret" && "$ret" =~ [N|n] ]] && return
    pacman -Q dropbox || paru -S --noconfirm dropbox || return

    rm -rf ~/.dropbox-dist
    install -dm0 ~/.dropbox-dist
}

install_pkg()
{
    native_pkg_list=$HOME/.config/misc/Qqen
    foreign_pkg_list=$HOME/.config/misc/Qqem

    read -rp "Install packages from list (y|n)?: " ret
    [[  -n "$ret" && "$ret" =~ [N|n] ]] ||
	[[ ! -f $native_pkg_list ]] || 
	[[ ! -f $foreign_pkg_list ]] && return

    vim "$native_pkg_list" && cat "$native_pkg_list" | sudo pacman -S -
    vim "$foreign_pkg_list" && paru -S - < "$foreign_pkg_list"
}

setup_dotfiles
setup_aur
symlink_etc_conf
install_cron
setup_dropbox
install_pkg
