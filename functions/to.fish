# Display general usage
function __to_usage
  echo 'Usage:'
  echo ' to (BOOKMARK|DIR)         Go to BOOKMARK or DIR'
  echo ' to add [BOOKMARK] [DEST]  Create a BOOKMARK for DEST'
  echo '                             Default BOOKMARK: name of current directory'
  echo '                             Default DEST: path to current directory'
  echo ' to ls                     List all bookmarks'
  echo ' to mv OLD NEW             Change the name of a bookmark from OLD to NEW'
  echo ' to rm BOOKMARK            Remove BOOKMARK'
  echo ' to clean                  Remove bookmarks that have a missing destination'
  echo ' to resolve BOOKMARK       Print the destination of a bookmark'
  echo ' to help                   Show this message'
  echo
  echo "Bookmarks are stored in: $TO_DIR"
  echo 'To change, run: set -U TO_DIR <dir>'
  return 1
end

function __to_dir
  if test -z "$TO_DIR"
    echo ~/.tofish
  else
    echo $TO_DIR
  end
end

function __to_bm_path
  set -l dir (__to_dir)
  echo "$dir/$argv"
end

function __to_resolve
  readlink (__to_bm_path $argv)
end

function __to_print
  __to_resolve $argv | string replace -r "^$HOME" "~"
end

function __to_ls
  set -l dir (__to_dir)
  if test -d "$dir"
    for bm in $dir/.* $dir/*
      echo (basename $bm)
    end
  end
end

function __to_rm
  rm (__to_bm_path $argv[1]); or return $status
  __to_update_bookmark_completions
end

function __to_update_bookmark_completions
  complete -e -c to
  complete -c to -k -x -a '(__fish_complete_directories)' -d 'Directory'
  # FIXME: don't show directories for "mv rm ls clean resolve"
  # FIXME: no argument completions for "clean ls help add"
  complete -c to -k -x -s h -d 'Show Help'
  complete -c to -k -n '__fish_use_subcommand' -f -a "help" -d 'Show help'
  complete -c to -k -n '__fish_use_subcommand' -x -a "resolve" -d 'Print bookmark destination'
  complete -c to -k -n '__fish_use_subcommand' -x -a "clean" -d 'Remove bad bookmarks'
  complete -c to -k -n '__fish_use_subcommand' -x -a "mv" -d 'Rename bookmark'
  complete -c to -k -n '__fish_use_subcommand' -x -a "rm" -d 'Remove bookmark'
  complete -c to -k -n '__fish_use_subcommand' -f -a "ls" -d 'List bookmarks'
  complete -c to -k -n '__fish_use_subcommand' -x -a "add" -d 'Create bookmark'
  complete -c to -k -n '__fish_seen_subcommand_from rm' -x -a '(__to_ls)' -d 'Bookmark'

  for bm in (__to_ls | sort -r)
    complete -c to -k -x -a (echo $bm | string escape) -d (__to_print $bm)
  end

end

function to -d 'Bookmarking tool'
  set -l dir (__to_dir)

  # Create tofish directory
  if not test -d "$dir"
    if mkdir "$dir"
      echo "Created bookmark directory: $dir"
    else
      echo "Failed to Create bookmark directory: $dir"
      return 1
    end
  end

  # Catch usage errors
  set -l cmd $argv[1]
  set -l numargs (count $argv)
  switch $cmd
    # subcommands that don't take an argument
    case ls help clean
      if not test $numargs -eq 1
        echo "Usage: to $cmd"
        return 1
      end

    # subcommands that require an argument
    case rm resolve
      if not test $numargs -eq 2
        echo "Usage: to $cmd BOOKMARK"
        return 1
      end

    # add has 2 optional arguments
    case add
      if not test $numargs -ge 1 -a $numargs -le 3
        echo "Usage: to add [BOOKMARK] [DEST]"
        return 1
      end

    # subcommands that require 2 arguments
    case mv
      if not test $numargs -eq 3
        echo "Usage: to mv OLD NEW"
        return 1
      end
  end

  switch $cmd
    # Add a bookmark
    case add
      set -l bm
      set -l dest
      if test -z "$argv[3]"
        set dest (pwd)
      else
        set dest "$argv[3]"
      end

      if test -z "$argv[2]"
        set bm (basename "$dest")
      else
        set bm "$argv[2]"
      end

      if test -z (__to_resolve $bm)
        switch (uname)
          case Darwin
            ln -s "$dest" (__to_bm_path $bm); or return $status
          case '*'
            ln -sT "$dest" (__to_bm_path $bm); or return $status
          end
        echo $bm "->" (__to_print $bm)
      else
        echo ERROR: Bookmark exists: $bm "->" (__to_resolve $bm)
        return 1
      end

      __to_update_bookmark_completions

    # Remove a bookmark
    case rm
      __to_rm $argv[2]

    # List all bookmarks
    case ls
      for bm in (__to_ls)
        set -l dest (__to_print $bm)
        echo "$bm -> $dest"
      end

    # Rename a bookmark
    case mv
      set -l old $argv[2]
      set -l new $argv[3]
      if test -z (__to_resolve $old)
        echo "ERROR: Bookmark not found: $old"
        return 1
      else if test -n (__to_resolve $old)
        echo "ERROR: Bookmark already exists: $new"
        return 1
      end

      mv -n (__to_bm_path $old) (__to_bm_path $new); or return $status
      __to_update_bookmark_completions

    # Clean
    case clean
      for bm in (__to_ls)
        set -l dest (__to_expand $bm)
        if not test -d "$dest"
          rm -v (__to_bm_path $bm)
        end
      end

    # Resolve
    case resolve
      __to_resolve "$argv[2]"

    # Help
    case -h --help help
      __to_usage
      return 0

    # Default
    case '*'
      set -l bm $argv[1]
      set -l dest (__to_resolve $bm)
      if test -z "$bm"
        __to_usage
        return 1
      else if test -n "$dest"
        echo "cd \"$dest\"" | source -
      else
        echo "cd \"$bm\"" | source -
      end
  end
end
