#!/bin/sh

rebuild_config () {
    config="$1"
    hookdir="$2"
    if [ $# != 2 ]; then
      echo "BUG: rebuild_config called by $0 with incorrect # of parameters" >&2
      return 1
    fi

    magic_string="# Autogenerated from $0"

    if [ -L "$config" ]; then
        echo "Error: $config is a symlink; won't overwrite." >&2
        return 1
    fi

    if [ -e "$config" ] && ! grep -q "^$magic_string" "$config"; then
        cat <<EOF >&2
Error: can't find '$magic_string' in $config
Presumably hand-written so won't overwrite; please break into parts.
EOF
        return 1
    fi

    echo "# Rebuilding $config ..."

    cat <<EOF > "$config"
# Autogenerated from $0 at `date`

EOF

    # Ensure we have $ZDOT_FIND_HOOKS; if this is being invoked from
    # be.sh then we probably don't.
    source $ZDOTDIR/.shared_env 

    $ZDOT_FIND_HOOKS "$hookdir" | while read conf; do
        echo "#   Appending $conf"
        echo "# Include of $conf follows:" >> "$config"
        # Allow for executable hooks, for generating content dynamically,
        # triggered by including a magic cookie in the hook file.
        if grep -q '%% Executable hook %%' "$conf"; then
            "$conf" >> "$config"
        else
            cat "$conf" >> "$config"
        fi
        echo >> "$config"
    done
}
