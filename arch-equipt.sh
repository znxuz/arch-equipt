#!/usr/bin/env bash

print_help()
{
	cat <<EOF
Usage: $(basename "$0") [-dascbph]

Options:
  -d     Setup dotfiles
  -a     Setup AUR with Paru
  -s     Setup /etc config files
  -c     Install cron jobs
  -b     Install Dropbox
  -p     Install packages from lists
  -h     Display this help message
EOF
}

prompt()
{
	[[ -z "$1" ]] && echo "No prompt given." >&2 && return 1

	read -rp "$1 (y|n)?: " ret
	[[  -n "$ret" && "$ret" =~ [N|n] ]] && return 1
	return 0
}

setup_dotfiles()
{
	prompt "Setup dotfiles" || return

	[ -d "$HOME"/.dotfiles ] && echo "dotfiles already exist" && return
	src="$HOME"/dotfiles.tmp
	git clone --separate-git-dir="$HOME"/.dotfiles \
		git@github.com:zijian-x/.dotfiles.git "$src" &&
		find "$src" -mindepth 1 -maxdepth 1 -exec cp -rf {} "$HOME" \; &&
		rm -rf "$src" &&
		git --git-dir="$HOME"/.dotfiles --work-tree="$HOME" \
		config --local status.showUntrackedFiles no

	# extra config for alcty-padding
	[[ $? -eq 0 ]] &&
		cp -f "$HOME/.config/alacritty/window.toml.template" \
		"$HOME/.config/alacritty/window.toml"
}

enable_systemctl_services()
{
	prompt "Enable systemctl services" || return

	unit_files="$HOME/.config/misc/systemd-unit-files"
	tail -n+2 "$unit_files" | head -n-2 | awk '{print $1}' |
			while read -r service; do
				systemctl is-active --quiet "$service" && continue
				expect <<- DONE
			set timeout -1
			spawn systemctl enable --now "$service"
			expect "*?assword:*"
			send -- "$(pass user-z)"
			send -- "\r"
			expect eof
		DONE
	done
}

setup_aur()
{
	prompt "Setup AUR with paru" || return

	paru_git='/tmp/paru'
	sudo rm -rf "$paru_git"
	git clone 'https://aur.archlinux.org/paru.git' "$paru_git" &&
		cd "$paru_git" && makepkg -sirc --noconfirm && rm -rf "$paru_git"
}

cp_etc_conf()
{
	prompt "Setup /etc config files" || return

	path="$HOME/.config/etc"
	configs=$(find "$path" -type f)

	for src in $configs; do
		target="${src//$HOME\/.config/}"
		dir="$(dirname "$target")"
		[ ! -d "$dir" ] && sudo mkdir -p "$dir" && echo "=> mkdir -p $dir"
		if [ -f "$target" ]; then
			if prompt "$target exists, still proceed?"; then
				sudo mv "$target" "$target.arch-equipt.bak"
			else
				continue
			fi
		fi

		sudo cp "$src" "$target" && echo "=> copied $src to $target"
	done
}

install_cron()
{
	prompt "Install cron_file" || return

	cron_file="${XDG_CONFIG_HOME:-$HOME/.config}/cron/cron_file"
	[[  -n "$ret" && "$ret" =~ [N|n] ]] && return

	[[ -f "$cron_file" ]] && sudo crontab -u "$(whoami)" "$cron_file" &&
		echo "Cron file installed"
}

install_pkg()
{
	prompt "Install packages from list" || return

	native_pkg_list=$HOME/.config/misc/Qqen
	foreign_pkg_list=$HOME/.config/misc/Qqem

	[[ ! -f $native_pkg_list ]] || [[ ! -f $foreign_pkg_list ]] && return

	vim "$native_pkg_list" && cat "$native_pkg_list" | sudo pacman -S --noconfirm --needed -
	vim "$foreign_pkg_list" && paru -S --noconfirm --needed - < "$foreign_pkg_list"
}

install_dropbox()
{
	prompt "Install dropbox" || return
	if pacman -Q dropbox &> /dev/null; then
		echo "Dropbox already installed" >&2
		prompt "Setup dropbox attributes" || return
	else
		if ! paru -S --noconfirm dropbox; then
			echo "Installing Dropbox failed" >&2
			return
		fi
		echo "Dropbox installed" && return
	fi

	rm -rf ~/.dropbox-dist; install -dm0 ~/.dropbox-dist
	ignore_dirs=(\
		"$HOME/Dropbox/books/Audiobooks" \
		"$HOME/Dropbox/Documents/WeChat_Data" \
	)

	for dir in "${ignore_dirs[@]}"; do
		[[ ! -d "$dir" ]] && mkdir -p "$dir"
		attr -s com.dropbox.ignored -V 1 "$dir"
	done
}

install_all()
{
    setup_dotfiles
    cp_etc_conf
    enable_systemctl_services
    setup_aur
    install_dropbox
    install_pkg
    install_cron
}

main()
{
    [[ "$#" -eq 0 ]] && install_all

    while getopts ":dascbph" opt; do
	case ${opt} in
	    h)
		print_help; exit
		;;
	    d)
		setup_dotfiles
		;;
	    a)
		setup_aur
		;;
	    s)
		cp_etc_conf
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
