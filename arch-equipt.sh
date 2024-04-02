#!/usr/bin/env bash

confirm()
{
    [[ -z "$1" ]] && echo "No prompt given." >&2 && return 1

    read -rp "$1" ret
    [[  -n "$ret" && "$ret" =~ [N|n] ]] && return 1
    return 0
}

setup_dotfiles()
{
    confirm "Setup dotfiles? (y|n)?: " || return

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
    confirm "Setup AUR with paru? (y|n)?: " || return

    paru_git='/tmp/paru'
    git clone 'https://aur.archlinux.org/paru.git' "$paru_git" &&
	cd "$paru_git" && yes | makepkg -sirc && rm -rf "$paru_git"
}

symlink_etc_conf()
{
    confirm "Setup /etc symlinks? (y|n)?: " || return

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
    confirm "Install cron_file (y|n)?: " || return

    cron_file="${XDG_CONFIG_HOME:-$HOME/.config}/cron/cron_file"
    [[  -n "$ret" && "$ret" =~ [N|n] ]] && return

    [[ -f "$cron_file" ]] && sudo crontab -u "$(whoami)" "$cron_file" &&
	echo "Cron file installed"
}

install_dropbox()
{
    confirm "Install dropbox (y|n)?: " || return
    pacman -Q dropbox &> /dev/null && echo "Dropbox already installed" >&2 && return

    paru -S --noconfirm dropbox &&
	rm -rf ~/.dropbox-dist && install -dm0 ~/.dropbox-dist &&
	echo "Dropbox installed" && return
    echo "Dropbox installation failed" >&2 && return 1
}

install_pkg()
{
    confirm "Install packages from list (y|n)?: " || return

    native_pkg_list=$HOME/.config/misc/Qqen
    foreign_pkg_list=$HOME/.config/misc/Qqem

    [[ ! -f $native_pkg_list ]] || [[ ! -f $foreign_pkg_list ]] && return

    vim "$native_pkg_list" && cat "$native_pkg_list" | sudo pacman -S --noconfirm -
    vim "$foreign_pkg_list" && paru -S --noconfirm - < "$foreign_pkg_list"
}

install_all()
{
    setup_dotfiles
    setup_aur
    symlink_etc_conf
    install_cron
    install_dropbox
    install_pkg
}

main()
{
    [[ "$#" -eq 0 ]] && install_all

    while getopts ":dascbp" opt; do
	case ${opt} in
	    d)
		install_dropbox
		;;
	    a)
		setup_aur
		;;
	    s)
		symlink_etc_conf
		;;
	    c)
		install_cron
		;;
	    b)
		install_dropbox
		;;
	    p)
		install_pkg
		;;
	    \?)
		echo "Invalid option: -$OPTARG" >&2
		exit 1
		;;
	esac
    done

    shift $((OPTIND -1))
}

main "$@"
