_roc_start() {
    local cur prev words cword
    _init_completion || return
    
    local global_opts=(
        "-v --verbosity"
        "-h --help"
        "-V --version"
    )
    
    local subcommands=(update upgrade app package config)
    
    case "${COMP_WORDS[1]}" in
        update)
            COMPREPLY=( $(compgen -W "-k --packages -f --platforms -s --scripts -t --themes ${global_opts[*]}" -- "$cur") )
            ;;
        upgrade)
            COMPREPLY=( $(compgen -W "-i --in -p --platform ${global_opts[*]}" -- "$cur") )
            ;;
        app)
            COMPREPLY=( $(compgen -W "-f --force -o --out -p --platform ${global_opts[*]}" -- "$cur") )
            ;;
        package)
            COMPREPLY=( $(compgen -W "-f --force ${global_opts[*]}" -- "$cur") )
            ;;
        config)
            COMPREPLY=( $(compgen -W "--set-theme --set-verbosity --set-default-platform ${global_opts[*]}" -- "$cur") )
            ;;
        *)
            COMPREPLY=( $(compgen -W "${subcommands[*]} ${global_opts[*]}" -- "$cur") )
            ;;
    esac
}

complete -F _roc_start roc-start
