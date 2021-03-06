#! /usr/bin/env bash
#
# Author: Bert Van Vreckem <bert.vanvreckem@gmail.com>
#
#/ Usage: get-stuff-done [work|play|-h|--help]
#/
#/ Overwrites the system hosts file in order to block certain websites that
#/ distract you from doing actual work.
#/
#/ COMMANDS/OPTIONS
#/   work         Block distracting websites
#/   play         Enable blocked websites
#/   -h, --help   Print this help message
#/
#/ EXAMPLES
#/
#/ $ get-stuff-done work
#/ $ get-stuff-done play
#/
#/ CONFIGURATION
#/
#/ Settings like the list of websites to be blocked are kept in the file
#/ ~/.config/get-stuff-done.conf. The first time this script is run, a default
#/ config file will be created.
#/
#/ The default hosts file (used in "play" mode) is kept in the file
#/ ~/.config/get-stuff-done.hosts. Initially, it is a backup of the system
#/ hosts file. If you want to add entries to the hosts file, you need to add
#/ them here first and execute "get-stuff-done play". If you edit /etc/hosts
#/ directly, it will be overwritten the next time you execute this command.


#{{{ Bash settings
# abort on nonzero exitstatus
set -o errexit
# abort on unbound variable
set -o nounset
# don't hide errors within pipes
set -o pipefail
#}}}
#{{{ Variables
readonly script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
readonly script_name=$(basename "${0}")
IFS=$'\t\n'   # Split on newlines and tabs (but not on spaces)

readonly config_file="${HOME}/.config/get-stuff-done.conf"
readonly default_hosts="${HOME}/.config/get-stuff-done.hosts"
readonly system_hosts=/etc/hosts
readonly banner="# Generated by get-stuff-done. Execute get-stuff-done -h for info"

# Default values for configuration settings, can be overridden in config file.
verbosity=verbose
blocked_sites=( )
#}}}

main() {
  ensure_config_exists
  # shellcheck source=/dev/null
  source "${config_file}"
  execute_command "${@}"
}

#{{{ Helper functions

# Usage: ensure_config_exists
# Creates the configuration file and backup of the system hosts file if
# necessary.
ensure_config_exists() {
  if [ ! -f "${config_file}" ]; then
    log "Creating config file ${config_file}"
    cat > "${config_file}" << _EOF_
# Config for get-stuff-done script. Execute get-stuff-done -h for info.
# verbosity (silent or verbose)
verbosity=verbose
# list of sites to be blocked
blocked_sites=( 'twitter.com' 'reddit.com' )
_EOF_
  fi

  if [ ! -f "${default_hosts}" ]; then
    log "Making a backup of the system hosts file to ${default_hosts}"
    # Add a banner to the hosts file indicating it was generated by this script
    if ! grep --silent "${banner}" "${system_hosts}"; then
      printf "%s\n" "${banner}" > "${default_hosts}"
    fi
    cat "${system_hosts}" >> "${default_hosts}"
  fi
}

execute_command() {
  if [ "$#" -eq 0 ]; then
    usage
    exit 0
  elif [ "$#" -gt 1 ]; then
    error "Too many arguments. Got $#, expected 1"
    usage
    exit 2
  fi
  local command="${1}"

  case "${command}" in
    -h|--help)
      usage
      exit 0
      ;;
    work)
      block_sites
      ;;
    play)
      log "Copying ${default_hosts} to ${system_hosts}"
      sudo cp "${default_hosts}" "${system_hosts}"
      ;;
    *)
      log "Unrecognized command: ${command}"
      usage
      exit 2
      ;;
  esac
}

block_sites() {
  # Create a temp file for new hosts entries
  local block_file
  block_file=$(mktemp)

  log "Going into work mode, blocking distracting sites:"
  log "${blocked_sites[@]}"

  # Start with the default hosts file
  cp "${default_hosts}" "${block_file}"

  # Add comment
  printf "\n# Blocked sites:\n\n" >> "${block_file}"

  for site in "${blocked_sites[@]}"; do
    printf '127.0.0.1  %s\n' "${site}" >> "${block_file}"
  done

  # Overwrite current hosts file with the newly created one
  sudo cp "${block_file}" "${system_hosts}"

  rm "${block_file}"
}

# Print usage message on stdout by parsing start of script comments
usage() {
  grep '^#/' "${script_dir}/${script_name}" | sed 's/^#\/\s*//'
}

# Usage: log [ARG]...
#
# Prints all arguments on the standard output stream
log() {
  if [ "${verbosity}" = 'verbose' ]; then
    printf '\e[0;33m>>> %s\e[0m\n' "${*}"
  fi
}

# Usage: error [ARG]...
#
# Prints all arguments on the standard error stream
error() {
  printf '\e[0;31m!!! %s\e[0m\n' "${*}" 1>&2
}

#}}}

main "${@}"

